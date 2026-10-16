-- Firm mode in-use guard test — proves
-- `20261016110000_firm_mode_reference_in_use_guard.sql`.
--
-- Self-contained: throwaway accounts, a throwaway chamber and its reference rows
-- are created inside one transaction that is rolled back, so no fixture
-- survives. The accounts are impersonated the way PostgREST does it —
-- `set local role authenticated` plus a `request.jwt.claims` setting, which is
-- what `auth.uid()` reads.
--
--   printf 'begin;\n' | cat - supabase/tests/firm_mode_reference_in_use_guard_test.sql \
--     <(echo rollback;) | psql "$URL" -v ON_ERROR_STOP=1 --file=-
--
-- The file opens its own transaction and ends in `rollback`, so the bare
-- `psql -f` form is safe too; the wrapped form above is the one the other
-- firm-mode proofs use and works either way.
--
-- What it pins, in order:
--
--   1. The guard exists where a guard can exist: exactly four `BEFORE UPDATE`
--      triggers, one on each parent of the nine foreign keys, with the function
--      SECURITY DEFINER — and **none** on `steps` and `case_types`, which have no
--      referencing column (`cases.case_type` and `cases.last_step` are free text),
--      so no server guard can protect them.
--   2. A tombstone of each of the four parents with a live dependent is refused
--      `reference_in_use` through direct PostgREST *and* through `push_changes`,
--      and the row is left untouched either way.
--   3. A member is refused the same write, so the rule is about the data rather
--      than about who is writing.
--   4. Dependents that are themselves tombstones do **not** hold a parent back.
--   5. `steps` and `case_types` tombstone freely while a case still carries their
--      wording as text — the honest limit, asserted rather than claimed.
--   6. The built-in baseline stays undeletable for the owner and the member alike.
--   7. `purge_tombstones()` completes over a tombstone a live case still names
--      instead of aborting — and the superseded set-based statement really does
--      abort on the very same fixture, which is what makes the skip the fix.
--   8. A dependent that has itself been tombstoned is purged first, and its parent
--      then purges on the next run.

begin;

-- ---------------------------------------------------------------------------
-- Assertion helpers (the shape the other firm-mode proofs use)
-- ---------------------------------------------------------------------------

create or replace function pg_temp.assert_true(p_condition boolean, p_message text)
returns void
language plpgsql
as $$
begin
  if p_condition is not true then
    raise exception 'INUSE FAIL: %', p_message;
  end if;
end;
$$;

-- Makes auth.uid() resolve to p_user, as the given role.
create or replace function pg_temp.as_user(p_role text, p_user uuid)
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', p_user::text, 'role', p_role)::text,
    true
  );
  execute format('set local role %I', p_role);
end;
$$;

-- Puts the session back the way it found it. `reset role` alone leaves
-- `request.jwt.claims` behind, so a fixture staged after an impersonation would
-- be judged as that member's write.
create or replace function pg_temp.as_owner()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', '', true);
  execute 'reset role';
end;
$$;

-- Rows touched by a statement run as p_user (0 means it was refused silently).
create or replace function pg_temp.rows_as(p_user uuid, p_sql text)
returns bigint
language plpgsql
as $$
declare
  v_rows bigint;
begin
  perform pg_temp.as_user('authenticated', p_user);
  execute p_sql;
  get diagnostics v_rows = row_count;
  perform pg_temp.as_owner();
  return v_rows;
end;
$$;

-- A statement run as p_user that must raise, with p_message in the error and
-- optionally p_state as its SQLSTATE. The guard's refusal is an error (the
-- trigger) rather than an empty result (a policy), so this shape is deliberate.
create or replace function pg_temp.assert_raises_as(
  p_user uuid,
  p_sql text,
  p_message text,
  p_state text default null
)
returns void
language plpgsql
as $$
declare
  v_error text;
  v_state text;
begin
  perform pg_temp.as_user('authenticated', p_user);
  begin
    execute p_sql;
  exception when others then
    v_error := sqlerrm;
    get stacked diagnostics v_state = returned_sqlstate;
  end;
  perform pg_temp.as_owner();
  if v_error is null then
    raise exception 'INUSE FAIL: % did not raise', p_sql;
  end if;
  if position(p_message in v_error) = 0 then
    raise exception 'INUSE FAIL: raised "%", expected "%"', v_error, p_message;
  end if;
  if p_state is not null and v_state <> p_state then
    raise exception 'INUSE FAIL: raised state %, expected %', v_state, p_state;
  end if;
end;
$$;

-- A statement run as the session's own user that must raise.
create or replace function pg_temp.assert_raises_here(
  p_sql text,
  p_state text,
  p_message text
)
returns void
language plpgsql
as $$
declare
  v_error text;
  v_state text;
begin
  begin
    execute p_sql;
  exception when others then
    v_error := sqlerrm;
    get stacked diagnostics v_state = returned_sqlstate;
  end;
  if v_error is null then
    raise exception 'INUSE FAIL: % did not raise', p_sql;
  end if;
  if v_state <> p_state then
    raise exception 'INUSE FAIL: raised state %, expected % (%)', v_state, p_state, v_error;
  end if;
end;
$$;

-- One `push_changes` batch, as p_user, through the RPC the app actually uses.
create or replace function pg_temp.push_as(p_user uuid, p_mutations jsonb)
returns jsonb
language plpgsql
as $$
declare
  v_out jsonb;
begin
  perform pg_temp.as_user('authenticated', p_user);
  v_out := public.push_changes(p_mutations);
  perform pg_temp.as_owner();
  return v_out;
end;
$$;

-- ---------------------------------------------------------------------------
-- Fixtures: one chamber with an owner and a fully-permitted associate, the six
-- reference rows a case depends on, and the two purge fixtures
-- ---------------------------------------------------------------------------

create temporary table ig_fixtures (
  name text primary key,
  id text not null
) on commit drop;

-- The four parents, each with the direct statement that tombstones it and the
-- mutation a queued tombstone would carry. Enumerating them here is what makes
-- the proof cover all four by name rather than spot-checking one.
create temporary table ig_parents (
  table_name text primary key,
  entity_type text not null,
  entity_id text not null,
  dependent_table text not null,
  direct_sql text not null,
  payload jsonb not null
) on commit drop;

do $$
declare
  c_owner uuid := gen_random_uuid();
  c_member uuid := gen_random_uuid();
  c_firm uuid := gen_random_uuid();
  v_now_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_builtin_on_behalf text;
begin
  insert into ig_fixtures (name, id) values
    ('owner', c_owner::text),
    ('member', c_member::text),
    ('firm', c_firm::text);

  -- The sign-up trigger creates one profiles row per account.
  insert into auth.users (
    id, instance_id, aud, role, email, email_confirmed_at, created_at, updated_at
  )
  values
    (c_owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'ig-owner@example.test', now(), now(), now()),
    (c_member, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'ig-member@example.test', now(), now(), now());

  insert into public.firms (
    id, name, owner_id, subscription_status, subscription_expiry
  )
  values (c_firm, 'IG Chambers', c_owner, 'active', now() + interval '30 days');

  -- Both accounts are entitled, so a refusal can never be the entitlement gate
  -- wearing the guard's clothes.
  update public.profiles
     set firm_id = c_firm,
         role = case when id = c_owner then 'owner' else 'associate' end,
         subscription_expiry = now() + interval '30 days'
   where id in (c_owner, c_member);

  -- The associate holds every flag, so nothing but the in-use guard can refuse
  -- their tombstone: the delete-transition gate and the permission boundary both
  -- pass, and the guard is what is measured.
  insert into public.firm_members (
    firm_id, user_id, role, can_add, can_edit, can_delete,
    synced_at, permissions_synced_at
  )
  values
    (c_firm, c_owner, 'owner', true, true, true, v_now_ms, v_now_ms),
    (c_firm, c_member, 'associate', true, true, true, v_now_ms, v_now_ms);

  -- Custom reference rows in the chamber: four parents, plus the two tables no
  -- guard can protect.
  insert into public.court_categories (
    id, name_key, court_level, order_index, is_custom, user_id, firm_id, updated_at
  )
  values ('ig-cat', 'igCourtCategory', 'lower', 1, true, c_owner, c_firm, v_now_ms);

  insert into public.case_categories (
    id, court_category_id, name, order_index, is_custom, user_id, firm_id, updated_at
  )
  values ('ig-casecat', 'ig-cat', 'IG Case Category', 1, true, c_owner, c_firm, v_now_ms);

  insert into public.courts (
    id, court_name, higher_lower_courts, court_category_id, order_index,
    is_custom, user_id, firm_id, updated_at
  )
  values
    ('ig-court', 'IG Court', 'lower', 'ig-cat', 1, true, c_owner, c_firm, v_now_ms),
    -- Authored by the **member**, so their queued tombstone passes the RPC's own
    -- authorship rule and the in-use guard is the only thing left to refuse it.
    ('ig-court-member', 'IG Member Court', 'lower', 'ig-cat', 4, true, c_member, c_firm, v_now_ms),
    -- The purge fixtures: one free, one that a live case will name.
    ('ig-purge-free', 'IG Purge Free', 'lower', 'ig-cat', 2, true, c_owner, c_firm, v_now_ms),
    ('ig-purge-blocked', 'IG Purge Blocked', 'lower', 'ig-cat', 3, true, c_owner, c_firm, v_now_ms);

  insert into public.on_behalfs (
    id, court_category_id, name, order_index, is_custom, user_id, firm_id, updated_at
  )
  values ('ig-onbehalf', 'ig-cat', 'IG On Behalf', 1, true, c_owner, c_firm, v_now_ms);

  insert into public.steps (
    id, court_category_id, step_name, order_index, is_custom, user_id, firm_id, updated_at
  )
  values ('ig-step', 'ig-cat', 'IG Step', 1, true, c_owner, c_firm, v_now_ms);

  insert into public.case_types (
    id, court_category_id, case_category_id, name, order_index,
    is_custom, user_id, firm_id, updated_at
  )
  values ('ig-casetype', 'ig-cat', 'ig-casecat', 'IG Case Type', 1, true, c_owner, c_firm, v_now_ms);

  insert into ig_fixtures (name, id) values
    ('cat', 'ig-cat'),
    ('casecat', 'ig-casecat'),
    ('court', 'ig-court'),
    ('court_member', 'ig-court-member'),
    ('case_member', 'ig-case-member'),
    ('onbehalf', 'ig-onbehalf'),
    ('step', 'ig-step'),
    ('casetype', 'ig-casetype'),
    ('purge_free', 'ig-purge-free'),
    ('purge_blocked', 'ig-purge-blocked'),
    ('case', 'ig-case'),
    ('case_block', 'ig-case-block');

  -- The blocked purge fixture is tombstoned **before** anything names it: that is
  -- the one state the guard cannot prevent, and the reason the purge needs its own
  -- half. The tombstone is staged as the chamber's owner, because a firm-scoped
  -- row cannot be tombstoned by a script with no claim (the delete-transition
  -- gate reads can_delete_firm for the caller).
  perform pg_temp.assert_true(
    pg_temp.rows_as(
      c_owner,
      'update public.courts set is_deleted = true where id = ''ig-purge-blocked'''
    ) = 1,
    'the owner could not tombstone the blocked purge fixture'
  );

  -- And a second one that nothing names, so the purge has a tombstone it must
  -- actually delete rather than only one it must keep.
  perform pg_temp.assert_true(
    pg_temp.rows_as(
      c_owner,
      'update public.courts set is_deleted = true where id = ''ig-purge-free'''
    ) = 1,
    'the owner could not tombstone the free purge fixture'
  );

  -- The case is what a live dependent means. It may name a tombstoned court: the
  -- foreign key asks only whether the row exists. The extra cases take the
  -- **seeded** on-behalf, so the chamber's one custom on-behalf has exactly one
  -- live dependent and each refusal below measures a single dependency.
  select id into v_builtin_on_behalf
    from public.on_behalfs where is_custom = false order by id limit 1;

  if v_builtin_on_behalf is null then
    raise exception 'INUSE FAIL: the seeded on-behalf baseline is missing';
  end if;

  insert into public.cases (
    id, user_id, firm_id, court_id, case_type, case_category_id, case_number,
    petitioner, respondent, on_behalf_id, last_step, created_at, updated_at
  )
  values
    ('ig-case', c_owner, c_firm, 'ig-court', 'IG Case Type', 'ig-casecat',
     'IG-1', 'A', 'B', 'ig-onbehalf', 'IG Step', v_now_ms, v_now_ms),
    ('ig-case-block', c_owner, c_firm, 'ig-purge-blocked', 'IG Case Type', null,
     'IG-2', 'C', 'D', v_builtin_on_behalf, 'IG Step', v_now_ms, v_now_ms),
    -- The live dependent of the member's own court, so their queued tombstone of
    -- it reaches the guard rather than the RPC's authorship rule.
    ('ig-case-member', c_member, c_firm, 'ig-court-member', 'IG Case Type', null,
     'IG-3', 'E', 'F', v_builtin_on_behalf, null, v_now_ms, v_now_ms);

  -- -------------------------------------------------------------------------
  -- The four parents of the nine foreign keys
  -- -------------------------------------------------------------------------

  insert into ig_parents (
    table_name, entity_type, entity_id, dependent_table, direct_sql, payload
  )
  values
  (
    'court_categories', 'court_category', 'ig-cat', 'case_categories',
    'update public.court_categories set is_deleted = true where id = ''ig-cat''',
    jsonb_build_object(
      'id', 'ig-cat', 'user_id', c_owner, 'firm_id', c_firm, 'is_custom', true
    )
  ),
  (
    'case_categories', 'case_category', 'ig-casecat', 'case_types',
    'update public.case_categories set is_deleted = true where id = ''ig-casecat''',
    jsonb_build_object(
      'id', 'ig-casecat', 'user_id', c_owner, 'firm_id', c_firm, 'is_custom', true
    )
  ),
  (
    'courts', 'court', 'ig-court', 'cases',
    'update public.courts set is_deleted = true where id = ''ig-court''',
    jsonb_build_object(
      'id', 'ig-court', 'user_id', c_owner, 'firm_id', c_firm, 'is_custom', true
    )
  ),
  (
    'on_behalfs', 'on_behalf', 'ig-onbehalf', 'cases',
    'update public.on_behalfs set is_deleted = true where id = ''ig-onbehalf''',
    jsonb_build_object(
      'id', 'ig-onbehalf', 'user_id', c_owner, 'firm_id', c_firm, 'is_custom', true
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 1. The guard exists where a guard can exist, and only there
-- ---------------------------------------------------------------------------

do $$
declare
  v_count integer;
  v_definer boolean;
  v_missing text;
begin
  select p.prosecdef into v_definer
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'enforce_reference_not_in_use';

  perform pg_temp.assert_true(
    v_definer is true,
    'enforce_reference_not_in_use must be SECURITY DEFINER: the rule is about '
    || 'the data, not about what the caller may read'
  );

  select count(*) into v_count
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and t.tgname like 'trg_%_in_use_guard'
     and not t.tgisinternal;

  perform pg_temp.assert_true(
    v_count = 4,
    format('expected exactly four in-use triggers, found %s', v_count)
  );

  -- Each of the four is BEFORE UPDATE FOR EACH ROW on its own table, and no
  -- reference table beyond them carries one.
  for v_missing in
    select unnest(array['court_categories', 'case_categories', 'courts', 'on_behalfs'])
  loop
    perform pg_temp.assert_true(
      exists (
        select 1
          from pg_trigger t
          join pg_class c on c.oid = t.tgrelid
          join pg_namespace n on n.oid = c.relnamespace
         where n.nspname = 'public'
           and c.relname = v_missing
           and t.tgname = 'trg_' || v_missing || '_in_use_guard'
           and position('BEFORE UPDATE' in pg_get_triggerdef(t.oid)) > 0
           and position('FOR EACH ROW' in pg_get_triggerdef(t.oid)) > 0
      ),
      format('%s has no BEFORE UPDATE FOR EACH ROW in-use trigger', v_missing)
    );
  end loop;

  perform pg_temp.assert_true(
    not exists (
      select 1
        from pg_trigger t
        join pg_class c on c.oid = t.tgrelid
        join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'public'
         and c.relname in ('steps', 'case_types')
         and t.tgname like 'trg_%_in_use_guard'
    ),
    'steps and case_types carry an in-use trigger, which cannot do anything: '
    || 'cases.case_type and cases.last_step are free text'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Every parent is refused a tombstone while a live dependent names it — by
--    both doors, and with the row left untouched
-- ---------------------------------------------------------------------------

do $$
declare
  v_owner uuid := (select id from ig_fixtures where name = 'owner')::uuid;
  v_member uuid := (select id from ig_fixtures where name = 'member')::uuid;
  v_parent record;
  v_out jsonb;
  v_deleted boolean;
begin
  -- Direct PostgREST: the trigger's own error, with its own SQLSTATE.
  for v_parent in select * from ig_parents order by table_name loop
    perform pg_temp.assert_raises_as(
      v_owner,
      v_parent.direct_sql,
      'reference_in_use',
      '23503'
    );
  end loop;

  -- A second pass reads the rows back, so a failure names its table rather than
  -- only reporting inside the generated statement.
  for v_parent in select * from ig_parents order by table_name loop
    execute format(
      'select is_deleted from public.%I where id = %L',
      v_parent.table_name, v_parent.entity_id
    ) into v_deleted;
    perform pg_temp.assert_true(
      v_deleted is false,
      format('a refused tombstone tombstoned the %s row anyway', v_parent.table_name)
    );
  end loop;

  -- The queued door: `push_changes` catches 23503 per mutation, so the refusal
  -- arrives as one rejected mutation rather than aborting the batch.
  for v_parent in select * from ig_parents order by table_name loop
    v_out := pg_temp.push_as(
      v_owner,
      jsonb_build_array(jsonb_build_object(
        'mutation_id', gen_random_uuid()::text,
        'entity_type', v_parent.entity_type,
        'entity_id', v_parent.entity_id,
        'operation', 'delete',
        'base_version', 1,
        'payload', v_parent.payload
      ))
    );
    perform pg_temp.assert_true(
      v_out #>> '{results,0,status}' = 'rejected'
        and v_out #>> '{results,0,error_code}' = 'validation_failed'
        and position(
          'reference_in_use' in coalesce(v_out #>> '{results,0,message}', '')
        ) > 0,
      format(
        'the queued tombstone of %s was not refused (got %s / %s / %s)',
        v_parent.table_name,
        coalesce(v_out #>> '{results,0,status}', 'nothing'),
        coalesce(v_out #>> '{results,0,error_code}', 'nothing'),
        coalesce(v_out #>> '{results,0,message}', 'nothing')
      )
    );
  end loop;

  -- 3. A member is refused the same write: the guard is keyed on nothing but the
  --    data, so the associate holding every flag is refused exactly as the owner.
  --
  --    Two shapes, deliberately. The direct update names the **owner's** court,
  --    so the refusal cannot be the RPC's own authorship rule wearing the guard's
  --    message. The queued one names the court the **member** authored, because
  --    `push_changes` subtracts `firm_id` before `sync_can_write` sees an update
  --    or a delete (an existing row keeps the firm it has), so on that door only
  --    the author passes the RPC's own check and the guard is what refuses.
  perform pg_temp.assert_raises_as(
    v_member,
    'update public.courts set is_deleted = true where id = ''ig-court''',
    'reference_in_use',
    '23503'
  );

  v_out := pg_temp.push_as(
    v_member,
    jsonb_build_array(jsonb_build_object(
      'mutation_id', gen_random_uuid()::text,
      'entity_type', 'court',
      'entity_id', 'ig-court-member',
      'operation', 'delete',
      'base_version', 1,
      'payload', jsonb_build_object(
        'id', 'ig-court-member', 'user_id', v_member, 'is_custom', true
      )
    ))
  );
  perform pg_temp.assert_true(
    v_out #>> '{results,0,status}' = 'rejected'
      and v_out #>> '{results,0,error_code}' = 'validation_failed'
      and position(
        'reference_in_use' in coalesce(v_out #>> '{results,0,message}', '')
      ) > 0,
    format(
      'a fully-permitted member was not refused an in-use tombstone (got %s / %s / %s)',
      coalesce(v_out #>> '{results,0,status}', 'nothing'),
      coalesce(v_out #>> '{results,0,error_code}', 'nothing'),
      coalesce(v_out #>> '{results,0,message}', 'nothing')
    )
  );
  perform pg_temp.assert_true(
    (
      select count(*) from public.courts
       where id in ('ig-court', 'ig-court-member') and is_deleted
    ) = 0,
    'a member''s refused tombstone left a court deleted'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 4-6. The rules the guard does **not** apply
-- ---------------------------------------------------------------------------

do $$
declare
  v_owner uuid := (select id from ig_fixtures where name = 'owner')::uuid;
  v_builtin text;
  v_rows bigint;
begin
  -- 4. Dependents that are themselves tombstones do not hold a parent back: the
  --    case that named the court and the on-behalf is tombstoned first, and the
  --    parent then goes.
  perform pg_temp.assert_true(
    pg_temp.rows_as(
      v_owner,
      'update public.cases set is_deleted = true where id = ''ig-case'''
    ) = 1,
    'the owner could not tombstone the dependent case'
  );
  perform pg_temp.assert_true(
    pg_temp.rows_as(
      v_owner,
      'update public.courts set is_deleted = true where id = ''ig-court'''
    ) = 1,
    'a court whose only dependents are tombstones is still held back'
  );
  perform pg_temp.assert_true(
    pg_temp.rows_as(
      v_owner,
      'update public.on_behalfs set is_deleted = true where id = ''ig-onbehalf'''
    ) = 1,
    'an on-behalf whose only dependent is a tombstone is still held back'
  );

  -- 5. `steps` and `case_types` tombstone freely, and the live case keeps the
  --    wording it stored as text. This is the honest limit, not a guard.
  perform pg_temp.assert_true(
    pg_temp.rows_as(
      v_owner,
      'update public.steps set is_deleted = true where id = ''ig-step'''
    ) = 1,
    'a step could not be tombstoned'
  );
  perform pg_temp.assert_true(
    pg_temp.rows_as(
      v_owner,
      'update public.case_types set is_deleted = true where id = ''ig-casetype'''
    ) = 1,
    'a case type could not be tombstoned'
  );
  perform pg_temp.assert_true(
    (
      select c.last_step = 'IG Step' and c.case_type = 'IG Case Type'
        from public.cases c where c.id = 'ig-case-block'
    ),
    'the case lost the step or case type it stores as text'
  );

  -- 6. The built-in baseline stays undeletable — for the owner and the member
  --    alike, because it is nobody's row (no author, no chamber), so no update
  --    reaches it in the first place.
  select id into v_builtin
    from public.courts where is_custom = false order by id limit 1;

  perform pg_temp.assert_true(
    v_builtin is not null,
    'the seeded reference baseline is missing'
  );

  v_rows := pg_temp.rows_as(
    v_owner,
    format('update public.courts set is_deleted = true where id = %L', v_builtin)
  );
  perform pg_temp.assert_true(
    v_rows = 0 and (
      select not c.is_deleted from public.courts c where c.id = v_builtin
    ),
    'the built-in reference baseline was tombstoned'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 7-8. The purge completes over a blocked tombstone instead of aborting
-- ---------------------------------------------------------------------------

do $$
declare
  v_owner uuid := (select id from ig_fixtures where name = 'owner')::uuid;
  v_deleted integer;
begin
  -- The blocked pair is in place: `ig-purge-blocked` is a tombstone and the live
  -- case `ig-case-block` names it, while `ig-purge-free` is a tombstone nothing
  -- names. A negative retention puts the cutoff at `now() + 1 day`, which is how
  -- a tombstone written in this same transaction comes into scope.
  perform pg_temp.assert_true(
    (
      select count(*) = 2 from public.courts
       where id in ('ig-purge-free', 'ig-purge-blocked') and is_deleted
    ),
    'the purge fixtures are not both tombstones'
  );

  v_deleted := public.purge_tombstones(-1);

  perform pg_temp.assert_true(
    v_deleted >= 1,
    format('the purge deleted nothing at all (returned %s)', v_deleted)
  );
  perform pg_temp.assert_true(
    not exists (select 1 from public.courts where id = 'ig-purge-free'),
    'a tombstone nothing names was not purged'
  );
  perform pg_temp.assert_true(
    exists (
      select 1 from public.courts
       where id = 'ig-purge-blocked' and is_deleted
    ),
    'the purge dropped a tombstone a live case still names'
  );
  perform pg_temp.assert_true(
    exists (select 1 from public.cases where id = 'ig-case-block'),
    'the purge touched the live dependent case'
  );

  -- The bite: the superseded body ran one set-based delete per table, so the very
  -- same row aborts that statement — which is what "fail as a whole" meant. The
  -- statement is reproduced here rather than the old function, and the exception
  -- leaves the table as it found it.
  perform pg_temp.assert_raises_here(
    'delete from public.courts where is_deleted = true '
    || 'and server_updated_at < now() + interval ''1 day''',
    '23503',
    'the superseded set-based purge did not abort on a blocked tombstone'
  );

  perform pg_temp.assert_true(
    exists (
      select 1 from public.courts
       where id = 'ig-purge-blocked' and is_deleted
    ),
    'the failed set-based statement was not rolled back'
  );

  -- 8. Once the dependent is a tombstone too, children go first and the parent
  --    follows in the same run.
  perform pg_temp.assert_true(
    pg_temp.rows_as(
      v_owner,
      'update public.cases set is_deleted = true where id = ''ig-case-block'''
    ) = 1,
    'the owner could not tombstone the live dependent case'
  );

  v_deleted := public.purge_tombstones(-1);

  perform pg_temp.assert_true(
    not exists (select 1 from public.cases where id = 'ig-case-block'),
    'the tombstoned dependent case was not purged'
  );
  perform pg_temp.assert_true(
    not exists (select 1 from public.courts where id = 'ig-purge-blocked'),
    'the parent was not purged after its dependent went'
  );
end;
$$;

rollback;

\echo 'INUSE OK: a reference row a live dependent still names cannot be tombstoned — refused by the trigger as 23503 and by push_changes as one rejected mutation, for member and owner alike — while dependents that are tombstones do not block, steps and case_types tombstone freely because nothing references them, the built-in baseline stays undeletable, and purge_tombstones completes over a blocked tombstone instead of aborting as a whole.'
