-- Firm mode permission-boundary test — proves `20261016100000_firm_mode_permission_boundary.sql`.
--
-- Self-contained: six throwaway accounts are created inside one transaction that
-- is rolled back, so no fixture survives. Each account is impersonated the way
-- PostgREST does it — `set local role authenticated` plus a `request.jwt.claims`
-- setting, which is what `auth.uid()` reads — so the policies and the new
-- trigger are actually evaluated rather than skipped by the owner's privileges.
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/firm_mode_permission_boundary_test.sql
--
-- The file opens its own transaction and ends in `rollback`, so it is safe run
-- bare as above; the wrapped form the firm-mode proofs use works too.
--
-- What it pins, in order:
--
--   1. All ten gated tables, **enumerated by name**, carry both new triggers,
--      and the trigger function is SECURITY INVOKER while `can_add_firm` is
--      SECURITY DEFINER — the two deliberate choices.
--   2. A member with `can_add = false` is refused an INSERT on **every one of
--      the ten**, through direct PostgREST *and* through `push_changes`, with
--      nothing written either way.
--   3. A member with `can_edit = false` is refused an UPDATE on their **own
--      authored** chamber row through both paths, and the row is unchanged —
--      the author exception the shipped policy keeps does not survive here.
--   4. Positive controls: the owner and a fully-permitted member may add and
--      edit chamber data, so a proof that refused everything could not pass.
--   5. The built-in reference baseline stays immutable to a member who may
--      otherwise edit chamber config.
--   6. A member who may delete but not edit can still tombstone their own row,
--      so `can_edit = false` does not narrow `can_delete`; and a member with
--      neither is still refused a delete.
--   7. A client may not change a row's `firm_id` — to null or to another
--      chamber — nor create a firm-less row while it holds a chamber.
--   8. An individual's own firm-less diary stays readable and writable.

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
    raise exception 'PERMISSION FAIL: %', p_message;
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
  execute 'reset role';
  return v_rows;
end;
$$;

-- A statement run as p_user that must raise, with p_message in the error. The
-- refusal here is an error (the trigger) rather than an empty result (the
-- policy), so both shapes are pinned deliberately.
create or replace function pg_temp.assert_raises_as(
  p_user uuid,
  p_sql text,
  p_message text
)
returns void
language plpgsql
as $$
declare
  v_error text;
begin
  perform pg_temp.as_user('authenticated', p_user);
  begin
    execute p_sql;
  exception when others then
    v_error := sqlerrm;
  end;
  execute 'reset role';
  if v_error is null then
    raise exception 'PERMISSION FAIL: % did not raise', p_sql;
  end if;
  if position(p_message in v_error) = 0 then
    raise exception 'PERMISSION FAIL: raised "%", expected "%"', v_error, p_message;
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
  execute 'reset role';
  return v_out;
end;
$$;

-- ---------------------------------------------------------------------------
-- Fixtures: a chamber with an owner and four associates holding every flag
-- combination, one of them in no chamber at all, plus one ledger row each
-- ---------------------------------------------------------------------------

-- `text`, not `uuid`: the reference tables' ids are text keys.
create temporary table pb_fixtures (
  name text primary key,
  id text not null
) on commit drop;

-- The ten gated tables, each with the statement a client would run and the
-- mutation a queued push would carry. Enumerating them here is what makes the
-- proof cover all ten by name rather than spot-check two.
create temporary table pb_gated (
  table_name text primary key,
  entity_type text not null,
  entity_id text not null,
  direct_sql text not null,
  payload jsonb not null
) on commit drop;

do $$
declare
  c_owner uuid := gen_random_uuid();
  c_full uuid := gen_random_uuid();
  c_no_add uuid := gen_random_uuid();
  c_no_edit uuid := gen_random_uuid();
  c_deleter uuid := gen_random_uuid();
  c_solo uuid := gen_random_uuid();
  c_firm uuid := gen_random_uuid();
  c_other_firm uuid := gen_random_uuid();
  v_now_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_category text;
  v_builtin_court text;
  v_on_behalf text;
begin
  insert into pb_fixtures (name, id) values
    ('owner', c_owner::text),
    ('full', c_full::text),
    ('no_add', c_no_add::text),
    ('no_edit', c_no_edit::text),
    ('deleter', c_deleter::text),
    ('solo', c_solo::text),
    ('firm', c_firm::text),
    ('other_firm', c_other_firm::text);

  -- The sign-up trigger creates one profiles row per account.
  insert into auth.users (
    id, instance_id, aud, role, email, email_confirmed_at, created_at, updated_at
  )
  values
    (c_owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'pb-owner@example.test', now(), now(), now()),
    (c_full, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'pb-full@example.test', now(), now(), now()),
    (c_no_add, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'pb-noadd@example.test', now(), now(), now()),
    (c_no_edit, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'pb-noedit@example.test', now(), now(), now()),
    (c_deleter, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'pb-deleter@example.test', now(), now(), now()),
    (c_solo, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'pb-solo@example.test', now(), now(), now());

  insert into public.firms (
    id, name, owner_id, subscription_status, subscription_expiry
  )
  values
    (c_firm, 'PB Chambers', c_owner, 'active', now() + interval '30 days'),
    -- A second chamber nobody in the fixture belongs to: the target of the
    -- "point it at another firm" case.
    (c_other_firm, 'PB Other Chambers', c_owner, 'active',
     now() + interval '30 days');

  -- Every chamber account is entitled, so a refusal can never be the
  -- entitlement gate wearing a permission error's clothes.
  update public.profiles
     set firm_id = c_firm,
         role = case when id = c_owner then 'owner' else 'associate' end,
         subscription_expiry = now() + interval '30 days'
   where id in (c_owner, c_full, c_no_add, c_no_edit, c_deleter);

  -- `solo` stays in no chamber: the individual whose own diary must be
  -- untouched by any of this.
  update public.profiles
     set firm_id = null, role = 'individual'
   where id = c_solo;

  insert into public.firm_members (
    firm_id, user_id, role, can_add, can_edit, can_delete,
    synced_at, permissions_synced_at
  )
  values
    (c_firm, c_owner, 'owner', true, true, true, v_now_ms, v_now_ms),
    (c_firm, c_full, 'associate', true, true, true, v_now_ms, v_now_ms),
    (c_firm, c_no_add, 'associate', false, true, false, v_now_ms, v_now_ms),
    (c_firm, c_no_edit, 'associate', true, false, false, v_now_ms, v_now_ms),
    -- The combination that proves the two permissions are separate.
    (c_firm, c_deleter, 'associate', false, false, true, v_now_ms, v_now_ms);

  select id into v_category from public.court_categories order by id limit 1;
  select id into v_builtin_court
    from public.courts where is_custom = false order by id limit 1;
  -- `cases.on_behalf_id` is a real foreign key, so a fixture cannot invent one.
  select id into v_on_behalf from public.on_behalfs order by id limit 1;

  if v_category is null or v_builtin_court is null or v_on_behalf is null then
    raise exception 'PERMISSION FAIL: the seeded reference baseline is missing';
  end if;

  insert into pb_fixtures (name, id) values
    ('category', v_category),
    ('builtin_court', v_builtin_court),
    ('on_behalf', v_on_behalf);

  -- Ledger rows. `pb-case-noedit` is the row the author-exception case turns
  -- on: it was authored by the member whose edits are switched off.
  insert into public.cases (
    id, user_id, firm_id, court_id, case_type, case_number, petitioner,
    respondent, on_behalf_id, created_at, updated_at
  )
  values
    ('pb-case-noedit', c_no_edit, c_firm, v_builtin_court, 'civil',
     'PB-1', 'A', 'B', v_on_behalf, v_now_ms, v_now_ms),
    ('pb-case-deleter', c_deleter, c_firm, v_builtin_court, 'civil',
     'PB-2', 'C', 'D', v_on_behalf, v_now_ms, v_now_ms),
    ('pb-case-personal', c_solo, null, v_builtin_court, 'civil',
     'PB-3', 'E', 'F', v_on_behalf, v_now_ms, v_now_ms);

  insert into pb_fixtures (name, id) values
    ('case_noedit', 'pb-case-noedit'),
    ('case_deleter', 'pb-case-deleter'),
    ('case_personal', 'pb-case-personal');

  -- -------------------------------------------------------------------------
  -- The ten gated tables: one direct statement and one queued mutation each
  -- -------------------------------------------------------------------------

  insert into pb_gated (table_name, entity_type, entity_id, direct_sql, payload)
  values
  (
    'cases', 'case', 'pb-add-cases',
    format(
      'insert into public.cases (id, user_id, firm_id, court_id, case_type, '
      'case_number, petitioner, respondent, on_behalf_id, created_at, updated_at) '
      'values (%L, %L, %L, %L, %L, %L, %L, %L, %L, 0, 0)',
      'pb-add-cases', c_no_add, c_firm, v_builtin_court, 'civil', 'PB-9',
      'X', 'Y', v_on_behalf
    ),
    jsonb_build_object(
      'id', 'pb-add-cases', 'user_id', c_no_add, 'firm_id', c_firm,
      'court_id', v_builtin_court, 'case_type', 'civil', 'case_number', 'PB-9',
      'petitioner', 'X', 'respondent', 'Y', 'on_behalf_id', v_on_behalf,
      'created_at', 0, 'updated_at', 0
    )
  ),
  (
    'case_history', 'case_history', 'pb-add-history',
    format(
      'insert into public.case_history (id, case_id, user_id, firm_id, '
      'hearing_date, created_by, source_mutation_id, base_case_version, '
      'result_case_version, updated_at) '
      'values (%L, %L, %L, %L, 0, %L, %L, 1, 2, 0)',
      'pb-add-history', 'pb-case-noedit', c_no_add, c_firm, c_no_add,
      'pb-add-history-direct'
    ),
    jsonb_build_object(
      'id', 'pb-add-history', 'case_id', 'pb-case-noedit', 'user_id', c_no_add,
      'firm_id', c_firm, 'hearing_date', 0, 'created_by', c_no_add,
      'source_mutation_id', 'pb-add-history-rpc',
      'base_case_version', 1, 'result_case_version', 2, 'updated_at', 0
    )
  ),
  (
    'notes', 'note', 'pb-add-notes',
    format(
      'insert into public.notes (id, user_id, firm_id, title, body, created_at, '
      'updated_at) values (%L, %L, %L, %L, %L, 0, 0)',
      'pb-add-notes', c_no_add, c_firm, 'PB note', 'body'
    ),
    jsonb_build_object(
      'id', 'pb-add-notes', 'user_id', c_no_add, 'firm_id', c_firm,
      'title', 'PB note', 'body', 'body', 'created_at', 0, 'updated_at', 0
    )
  ),
  (
    'case_references', 'reference', 'pb-add-reference',
    format(
      'insert into public.case_references (id, user_id, firm_id, '
      'reference_and_page_no, created_at, updated_at) '
      'values (%L, %L, %L, %L, 0, 0)',
      'pb-add-reference', c_no_add, c_firm, 'AIR 2020 SC 1'
    ),
    jsonb_build_object(
      'id', 'pb-add-reference', 'user_id', c_no_add, 'firm_id', c_firm,
      'reference_and_page_no', 'AIR 2020 SC 1', 'created_at', 0, 'updated_at', 0
    )
  ),
  (
    'court_categories', 'court_category', 'pb-add-court-categories',
    format(
      'insert into public.court_categories (id, name_key, court_level, '
      'order_index, is_custom, user_id, firm_id, updated_at) '
      'values (%L, %L, %L, 0, true, %L, %L, 0)',
      'pb-add-court-categories', 'pb_court_category', 'lower', c_no_add, c_firm
    ),
    jsonb_build_object(
      'id', 'pb-add-court-categories', 'name_key', 'pb_court_category',
      'court_level', 'lower', 'order_index', 0, 'is_custom', true,
      'user_id', c_no_add, 'firm_id', c_firm, 'updated_at', 0
    )
  ),
  (
    'case_categories', 'case_category', 'pb-add-case-categories',
    format(
      'insert into public.case_categories (id, court_category_id, name, '
      'order_index, is_custom, user_id, firm_id, updated_at) '
      'values (%L, %L, %L, 0, true, %L, %L, 0)',
      'pb-add-case-categories', v_category, 'PB category', c_no_add, c_firm
    ),
    jsonb_build_object(
      'id', 'pb-add-case-categories', 'court_category_id', v_category,
      'name', 'PB category', 'order_index', 0, 'is_custom', true,
      'user_id', c_no_add, 'firm_id', c_firm, 'updated_at', 0
    )
  ),
  (
    'courts', 'court', 'pb-add-courts',
    format(
      'insert into public.courts (id, court_name, higher_lower_courts, '
      'court_category_id, order_index, is_custom, user_id, firm_id, updated_at) '
      'values (%L, %L, %L, %L, 0, true, %L, %L, 0)',
      'pb-add-courts', 'PB Court', 'lower', v_category, c_no_add, c_firm
    ),
    jsonb_build_object(
      'id', 'pb-add-courts', 'court_name', 'PB Court',
      'higher_lower_courts', 'lower', 'court_category_id', v_category,
      'order_index', 0, 'is_custom', true, 'user_id', c_no_add,
      'firm_id', c_firm, 'updated_at', 0
    )
  ),
  (
    'steps', 'step', 'pb-add-steps',
    format(
      'insert into public.steps (id, court_category_id, step_name, order_index, '
      'is_custom, user_id, firm_id, updated_at) '
      'values (%L, %L, %L, 0, true, %L, %L, 0)',
      'pb-add-steps', v_category, 'PB step', c_no_add, c_firm
    ),
    jsonb_build_object(
      'id', 'pb-add-steps', 'court_category_id', v_category,
      'step_name', 'PB step', 'order_index', 0, 'is_custom', true,
      'user_id', c_no_add, 'firm_id', c_firm, 'updated_at', 0
    )
  ),
  (
    'case_types', 'case_type', 'pb-add-case-types',
    format(
      'insert into public.case_types (id, court_category_id, name, order_index, '
      'is_custom, user_id, firm_id, updated_at) '
      'values (%L, %L, %L, 0, true, %L, %L, 0)',
      'pb-add-case-types', v_category, 'PB type', c_no_add, c_firm
    ),
    jsonb_build_object(
      'id', 'pb-add-case-types', 'court_category_id', v_category,
      'name', 'PB type', 'order_index', 0, 'is_custom', true,
      'user_id', c_no_add, 'firm_id', c_firm, 'updated_at', 0
    )
  ),
  (
    'on_behalfs', 'on_behalf', 'pb-add-on-behalfs',
    format(
      'insert into public.on_behalfs (id, court_category_id, name, order_index, '
      'is_custom, user_id, firm_id, updated_at) '
      'values (%L, %L, %L, 0, true, %L, %L, 0)',
      'pb-add-on-behalfs', v_category, 'PB on behalf', c_no_add, c_firm
    ),
    jsonb_build_object(
      'id', 'pb-add-on-behalfs', 'court_category_id', v_category,
      'name', 'PB on behalf', 'order_index', 0, 'is_custom', true,
      'user_id', c_no_add, 'firm_id', c_firm, 'updated_at', 0
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- The proof
-- ---------------------------------------------------------------------------

do $$
declare
  c_owner uuid := (select id::uuid from pb_fixtures where name = 'owner');
  c_full uuid := (select id::uuid from pb_fixtures where name = 'full');
  c_no_add uuid := (select id::uuid from pb_fixtures where name = 'no_add');
  c_no_edit uuid := (select id::uuid from pb_fixtures where name = 'no_edit');
  c_deleter uuid := (select id::uuid from pb_fixtures where name = 'deleter');
  c_solo uuid := (select id::uuid from pb_fixtures where name = 'solo');
  c_firm uuid := (select id::uuid from pb_fixtures where name = 'firm');
  c_other_firm uuid := (select id::uuid from pb_fixtures where name = 'other_firm');
  c_category text := (select id from pb_fixtures where name = 'category');
  c_builtin_court text := (select id from pb_fixtures where name = 'builtin_court');
  v_gated record;
  v_out jsonb;
  v_missing text;
  v_rows bigint;
begin
  -- 1. All twenty triggers exist on the ten named tables, are BEFORE ROW
  --    triggers, and both helpers carry the security posture this migration
  --    chose. A table missed by the attach loop cannot pass by silence.
  select string_agg(g.table_name || ' (' || k.kind || ')', ', ')
    into v_missing
    from pb_gated g
    cross join (values ('add_permission'), ('edit_permission')) as k(kind)
   where not exists (
     select 1
       from pg_catalog.pg_trigger t
      where t.tgrelid = format('public.%I', g.table_name)::regclass
        and t.tgname = 'trg_' || g.table_name || '_' || k.kind
        and not t.tgisinternal
        -- tgtype bits: 2 = BEFORE, 1 = FOR EACH ROW.
        and (t.tgtype & 2) = 2
        and (t.tgtype & 1) = 1
   );

  perform pg_temp.assert_true(
    v_missing is null,
    'missing or mis-shaped permission trigger on: ' || coalesce(v_missing, '')
  );

  perform pg_temp.assert_true(
    (select count(*) from pb_gated) = 10,
    'the gated-table list must name exactly ten tables'
  );

  perform pg_temp.assert_true(
    not (
      select p.prosecdef from pg_catalog.pg_proc p
        join pg_catalog.pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public'
         and p.proname = 'enforce_member_permission'
    ),
    'enforce_member_permission must be SECURITY INVOKER, or current_user '
    || 'becomes the owner and the scope rule stops applying'
  );

  perform pg_temp.assert_true(
    (
      select p.prosecdef from pg_catalog.pg_proc p
        join pg_catalog.pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public' and p.proname = 'can_add_firm'
    ),
    'can_add_firm must read other accounts'' membership, so it must be DEFINER'
  );

  -- 2. `can_add = false` is refused on every one of the ten, by both doors, and
  --    writes nothing.
  for v_gated in
    select * from pb_gated order by table_name
  loop
    perform pg_temp.assert_raises_as(
      c_no_add,
      v_gated.direct_sql,
      'add_not_permitted'
    );
  end loop;

  -- The row counts are read in a second pass, so a failure names the table in
  -- its own message rather than only inside the generated statement.
  for v_gated in
    select * from pb_gated order by table_name
  loop
    execute format(
      'select count(*) from public.%I where id = %L',
      v_gated.table_name, v_gated.entity_id
    ) into v_rows;
    perform pg_temp.assert_true(
      v_rows = 0,
      format(
        'a refused direct insert still wrote a %s row', v_gated.table_name
      )
    );

    v_out := pg_temp.push_as(
      c_no_add,
      jsonb_build_array(jsonb_build_object(
        'mutation_id', gen_random_uuid()::text,
        'entity_type', v_gated.entity_type,
        'entity_id', v_gated.entity_id,
        'operation', 'insert',
        'payload', v_gated.payload
      ))
    );
    perform pg_temp.assert_true(
      v_out #>> '{results,0,status}' = 'rejected'
        and v_out #>> '{results,0,error_code}' = 'permission_denied',
      format(
        'a can_add = false member was not refused a push insert on %s (got %s / %s)',
        v_gated.table_name,
        coalesce(v_out #>> '{results,0,status}', 'nothing'),
        coalesce(v_out #>> '{results,0,error_code}', 'nothing')
      )
    );

    execute format(
      'select count(*) from public.%I where id = %L',
      v_gated.table_name, v_gated.entity_id
    ) into v_rows;
    perform pg_temp.assert_true(
      v_rows = 0,
      format(
        'a refused push insert still wrote a %s row', v_gated.table_name
      )
    );
  end loop;

  -- 3. `can_edit = false` is refused on the member's OWN authored row, by both
  --    doors, and the row is unchanged.
  perform pg_temp.assert_raises_as(
    c_no_edit,
    'update public.cases set case_remarks = ''direct edit'' '
    || 'where id = ''pb-case-noedit''',
    'edit_not_permitted'
  );

  v_out := pg_temp.push_as(
    c_no_edit,
    jsonb_build_array(jsonb_build_object(
      'mutation_id', gen_random_uuid()::text,
      'entity_type', 'case',
      'entity_id', 'pb-case-noedit',
      'operation', 'update',
      'base_version', 1,
      'payload', jsonb_build_object(
        'id', 'pb-case-noedit', 'user_id', c_no_edit, 'firm_id', c_firm,
        'case_remarks', 'push edit'
      )
    ))
  );
  perform pg_temp.assert_true(
    v_out #>> '{results,0,status}' = 'rejected'
      and v_out #>> '{results,0,error_code}' = 'permission_denied',
    format(
      'a can_edit = false author was not refused a push update (got %s / %s)',
      coalesce(v_out #>> '{results,0,status}', 'nothing'),
      coalesce(v_out #>> '{results,0,error_code}', 'nothing')
    )
  );

  perform pg_temp.assert_true(
    (
      select c.case_remarks is null
        from public.cases c where c.id = 'pb-case-noedit'
    ),
    'a refused update changed the row anyway'
  );

  -- 4. Positive controls: the owner and a fully-permitted member are unaffected.
  perform pg_temp.assert_true(
    pg_temp.rows_as(
      c_owner,
      'update public.cases set case_remarks = ''owner edit'' '
      || 'where id = ''pb-case-noedit'''
    ) = 1,
    'the owner cannot edit a chamber row'
  );
  perform pg_temp.assert_true(
    (
      select c.case_remarks = 'owner edit'
        from public.cases c where c.id = 'pb-case-noedit'
    ),
    'the owner''s edit did not land'
  );

  perform pg_temp.assert_true(
    pg_temp.rows_as(
      c_full,
      'update public.cases set case_remarks = ''member edit'' '
      || 'where id = ''pb-case-noedit'''
    ) = 1,
    'a member with can_edit cannot edit a chamber row they did not author'
  );

  perform pg_temp.assert_true(
    pg_temp.rows_as(
      c_owner,
      format(
        'insert into public.notes (id, user_id, firm_id, title, body, '
        'created_at, updated_at) values (%L, %L, %L, %L, %L, 0, 0)',
        'pb-note-owner', c_owner, c_firm, 'Owner note', 'body'
      )
    ) = 1,
    'the owner cannot add a chamber note'
  );

  -- The same create through the RPC, accepted — so the refusal above cannot be
  -- "this path refuses everything".
  v_out := pg_temp.push_as(
    c_full,
    jsonb_build_array(jsonb_build_object(
      'mutation_id', gen_random_uuid()::text,
      'entity_type', 'note',
      'entity_id', 'pb-note-full',
      'operation', 'insert',
      'payload', jsonb_build_object(
        'id', 'pb-note-full', 'user_id', c_full, 'firm_id', c_firm,
        'title', 'Member note', 'body', 'body', 'created_at', 0, 'updated_at', 0
      )
    ))
  );
  perform pg_temp.assert_true(
    v_out #>> '{results,0,status}' = 'accepted',
    format(
      'a fully-permitted member was refused a push insert (got %s / %s)',
      coalesce(v_out #>> '{results,0,status}', 'nothing'),
      coalesce(v_out #>> '{results,0,error_code}', 'nothing')
    )
  );

  -- 5. Chamber config: a member with both flags may add and edit their own
  --    custom reference row, and may not touch the built-in baseline.
  perform pg_temp.assert_true(
    pg_temp.rows_as(
      c_full,
      format(
        'insert into public.courts (id, court_name, higher_lower_courts, '
        'court_category_id, order_index, is_custom, user_id, firm_id, updated_at) '
        'values (%L, %L, %L, %L, 0, true, %L, %L, 0)',
        'pb-court-custom', 'PB Custom Court', 'lower', c_category, c_full, c_firm
      )
    ) = 1,
    'a member with can_add cannot add a custom court to the chamber'
  );
  perform pg_temp.assert_true(
    pg_temp.rows_as(
      c_full,
      'update public.courts set court_name = ''PB Renamed Court'' '
      || 'where id = ''pb-court-custom'''
    ) = 1,
    'a member with can_edit cannot edit the chamber''s custom court'
  );
  perform pg_temp.assert_true(
    pg_temp.rows_as(
      c_full,
      format(
        'update public.courts set court_name = ''Hijacked'' where id = %L',
        c_builtin_court
      )
    ) = 0,
    'the built-in reference baseline was edited'
  );

  -- 6. can_delete is not narrowed by can_edit: the member whose edits are off
  --    can still tombstone — their own row, which is the row the policy lets
  --    them reach, so the trigger's tombstone exemption is what is measured.
  perform pg_temp.assert_true(
    pg_temp.rows_as(
      c_deleter,
      'update public.cases set is_deleted = true where id = ''pb-case-deleter'''
    ) = 1,
    'can_edit = false narrowed a member who holds can_delete'
  );
  perform pg_temp.assert_true(
    (
      select c.is_deleted from public.cases c where c.id = 'pb-case-deleter'
    ),
    'the tombstone did not land'
  );

  -- And the member with neither is still refused a delete.
  perform pg_temp.assert_raises_as(
    c_no_edit,
    'update public.cases set is_deleted = true where id = ''pb-case-noedit''',
    'delete_not_permitted'
  );

  -- 7. The scope columns are the server's: not to null, not to another chamber,
  --    and a member may not create a row outside their chamber.
  perform pg_temp.assert_raises_as(
    c_full,
    'update public.cases set firm_id = null where id = ''pb-case-noedit''',
    'scope_change_not_permitted'
  );
  perform pg_temp.assert_raises_as(
    c_full,
    format(
      'update public.cases set firm_id = %L where id = ''pb-case-noedit''',
      c_other_firm
    ),
    'scope_change_not_permitted'
  );
  perform pg_temp.assert_raises_as(
    c_full,
    format(
      'insert into public.notes (id, user_id, firm_id, title, body, created_at, '
      'updated_at) values (%L, %L, null, %L, %L, 0, 0)',
      'pb-note-firmless', c_full, 'Orphan note', 'body'
    ),
    'scope_change_not_permitted'
  );
  perform pg_temp.assert_true(
    (
      select c.firm_id = c_firm from public.cases c where c.id = 'pb-case-noedit'
    ),
    'a refused scope change moved the row anyway'
  );

  -- 8. An individual's own firm-less diary is untouched by any of this.
  perform pg_temp.assert_true(
    pg_temp.rows_as(
      c_solo,
      'update public.cases set case_remarks = ''solo edit'' '
      || 'where id = ''pb-case-personal'''
    ) = 1,
    'an individual could not edit their own firm-less case'
  );
  perform pg_temp.assert_true(
    pg_temp.rows_as(
      c_solo,
      format(
        'insert into public.notes (id, user_id, firm_id, title, body, '
        'created_at, updated_at) values (%L, %L, null, %L, %L, 0, 0)',
        'pb-note-solo', c_solo, 'Solo note', 'body'
      )
    ) = 1,
    'an individual could not add a firm-less note'
  );
end;
$$;

rollback;

\echo 'PERMISSION OK: can_add gates a create and can_edit every non-tombstone update on all ten tables through both doors, the owner is unaffected, and the scope columns are the server''s.'
