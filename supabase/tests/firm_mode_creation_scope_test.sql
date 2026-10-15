-- Firm mode creation-and-scope test — proves
-- `20261015110000_firm_mode_creation_and_scope.sql`.
--
-- Self-contained: five throwaway accounts are created inside one transaction
-- that is rolled back, so no fixture survives. Accounts are impersonated the way
-- PostgREST does it — `set local role authenticated` plus a `request.jwt.claims`
-- setting, which is what `auth.uid()` reads — and `push_changes` is called as the
-- authenticated role it is granted to, so the RPC's own guards run for real.
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/firm_mode_creation_scope_test.sql
--
-- Two halves, in order:
--
--   * **creation shares the owner's diary** — every firm-less ledger row the
--     creator authored (all four case-data tables, all six reference tables'
--     custom rows, a pending delete request, tombstones included) takes the new
--     firm_id with a version bump, while a row of the creator's that already
--     belongs to another firm, the built-in baseline, and a resolved delete
--     request are left alone, and a second `ensure_firm` call is not a second
--     stamping;
--   * **the scope columns belong to the server** — a member's insert lands in
--     their chamber even though the client's whole-row payload says `firm_id`
--     null (the defect this phase exists for), a payload naming another firm is
--     corrected rather than obeyed, an update cannot move a row out of its
--     chamber or name a scope owner, and an individual's insert stays personal.

begin;

-- ---------------------------------------------------------------------------
-- Assertion helpers (the shape the other smoke tests use)
-- ---------------------------------------------------------------------------

create or replace function pg_temp.assert_true(p_condition boolean, p_message text)
returns void
language plpgsql
as $$
begin
  if p_condition is not true then
    raise exception 'CREATION FAIL: %', p_message;
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

-- Pushes one `case` mutation as p_user and returns its single result object.
create or replace function pg_temp.push_case(
  p_user uuid,
  p_id text,
  p_operation text,
  p_base_version integer,
  p_payload jsonb
)
returns jsonb
language plpgsql
as $$
declare
  v_out jsonb;
begin
  perform pg_temp.as_user('authenticated', p_user);
  v_out := public.push_changes(jsonb_build_array(jsonb_build_object(
    'mutation_id', gen_random_uuid()::text,
    'entity_type', 'case',
    'entity_id', p_id,
    'operation', p_operation,
    'base_version', p_base_version,
    'payload', p_payload
  )));
  execute 'reset role';
  return v_out -> 'results' -> 0;
end;
$$;

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

-- `text`, not `uuid`: the reference tables' ids are text keys, and the account
-- and firm ids cast in on the way through.
create temporary table scope2_fixtures (
  name text primary key,
  id text not null
) on commit drop;

do $$
declare
  c_creator uuid := gen_random_uuid();
  c_other uuid := gen_random_uuid();
  c_firm_owner uuid := gen_random_uuid();
  c_assoc uuid := gen_random_uuid();
  c_solo uuid := gen_random_uuid();
  c_other_firm uuid := gen_random_uuid();
  c_firm uuid := gen_random_uuid();
  v_now_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_category text;
  v_builtin_court text;
  v_builtin_on_behalf text;
begin
  insert into scope2_fixtures (name, id) values
    ('creator', c_creator::text),
    ('other', c_other::text),
    ('firm_owner', c_firm_owner::text),
    ('assoc', c_assoc::text),
    ('solo', c_solo::text),
    ('other_firm', c_other_firm::text),
    ('firm', c_firm::text);

  -- The sign-up trigger creates one profiles row per account.
  insert into auth.users (
    id, instance_id, aud, role, email, email_confirmed_at, created_at, updated_at
  )
  values
    (c_creator, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'scope2-creator@example.test', now(), now(), now()),
    (c_other, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'scope2-other@example.test', now(), now(), now()),
    (c_firm_owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'scope2-firm-owner@example.test', now(), now(), now()),
    (c_assoc, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'scope2-assoc@example.test', now(), now(), now()),
    (c_solo, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'scope2-solo@example.test', now(), now(), now());

  -- The creator and the individual are premium; the chamber's own expiry is what
  -- entitles its members.
  update public.profiles
     set subscription_expiry = now() + interval '30 days'
   where id in (c_creator, c_solo);

  -- A chamber that already exists, owned by somebody else, so a row of the
  -- creator's that already belongs to a firm can be proved untouched.
  insert into public.firms (
    id, name, owner_id, subscription_status, subscription_expiry
  )
  values
    (c_other_firm, 'Other Chambers', c_other, 'active',
     now() + interval '30 days'),
    (c_firm, 'Scope Two Chambers', c_firm_owner, 'active',
     now() + interval '30 days');

  update public.profiles
     set firm_id = c_other_firm, role = 'owner'
   where id = c_other;
  update public.profiles
     set firm_id = c_firm, role = 'owner'
   where id = c_firm_owner;
  update public.profiles
     set firm_id = c_firm, role = 'associate'
   where id = c_assoc;

  insert into public.firm_members (
    firm_id, user_id, role, can_add, can_edit, can_delete,
    synced_at, permissions_synced_at
  )
  values
    (c_firm, c_firm_owner, 'owner', true, true, true, v_now_ms, v_now_ms),
    (c_firm, c_assoc, 'associate', true, true, false, v_now_ms, v_now_ms);

  select id into v_category from public.court_categories limit 1;
  select id into v_builtin_court
    from public.courts where is_custom = false order by id limit 1;
  -- `cases.on_behalf_id` is a real foreign key, so a fixture cannot invent one.
  select id into v_builtin_on_behalf from public.on_behalfs limit 1;

  insert into scope2_fixtures (name, id) values
    ('category', v_category),
    ('builtin_court', v_builtin_court),
    ('builtin_on_behalf', v_builtin_on_behalf);

  -- -------------------------------------------------------------------------
  -- The creator's firm-less diary: one row of every kind the stamp covers
  -- -------------------------------------------------------------------------

  insert into public.cases (
    id, user_id, firm_id, case_number, case_type, court_id, petitioner,
    respondent, on_behalf_id, created_at, updated_at
  )
  values
    ('scope2-case', c_creator, null, 'SCOPE2-1', 'civil', v_builtin_court,
     'A', 'B', v_builtin_on_behalf, v_now_ms, v_now_ms),
    -- A tombstone is stamped too: the chamber's ledger still names the row.
    ('scope2-case-tomb', c_creator, null, 'SCOPE2-2', 'civil', v_builtin_court,
     'C', 'D', v_builtin_on_behalf, v_now_ms, v_now_ms),
    -- A row of the creator's that already has a firm is not the creator's to
    -- share, and must not be moved.
    ('scope2-case-foreign', c_creator, c_other_firm, 'SCOPE2-3', 'civil',
     v_builtin_court, 'E', 'F', v_builtin_on_behalf, v_now_ms, v_now_ms);

  update public.cases set is_deleted = true where id = 'scope2-case-tomb';

  insert into public.case_history (
    id, case_id, user_id, firm_id, hearing_date, created_by,
    source_mutation_id, base_case_version, result_case_version, updated_at
  )
  values (
    'scope2-history', 'scope2-case', c_creator, null, v_now_ms, c_creator,
    'scope2-mutation-1', 1, 2, v_now_ms
  );

  insert into public.notes (
    id, user_id, firm_id, title, body, created_at, updated_at
  )
  values (
    'scope2-note', c_creator, null, 'Individual note', 'body', v_now_ms,
    v_now_ms
  );

  insert into public.case_references (
    id, user_id, firm_id, reference_and_page_no, created_at, updated_at
  )
  values (
    'scope2-reference', c_creator, null, 'AIR 2021 SC 9', v_now_ms, v_now_ms
  );

  insert into public.court_categories (
    id, name_key, court_level, order_index, is_custom, user_id, updated_at
  )
  values ('scope2-court-category', 'scope2_key', 'lower', 99, true, c_creator,
          v_now_ms);

  insert into public.case_categories (
    id, court_category_id, name, order_index, is_custom, user_id, updated_at
  )
  values ('scope2-case-category', v_category, 'Scope2 Category', 99, true,
          c_creator, v_now_ms);

  insert into public.courts (
    id, court_name, higher_lower_courts, court_category_id, is_custom,
    user_id, updated_at
  )
  values ('scope2-court', 'Scope2 Court', 'lower', v_category, true, c_creator,
          v_now_ms);

  insert into public.steps (
    id, court_category_id, step_name, order_index, is_custom, user_id,
    updated_at
  )
  values ('scope2-step', v_category, 'Scope2 Step', 99, true, c_creator,
          v_now_ms);

  insert into public.case_types (
    id, court_category_id, name, order_index, is_custom, user_id, updated_at
  )
  values ('scope2-case-type', v_category, 'Scope2 Type', 99, true, c_creator,
          v_now_ms);

  insert into public.on_behalfs (
    id, court_category_id, name, order_index, is_custom, user_id, updated_at
  )
  values ('scope2-on-behalf', v_category, 'Scope2 On Behalf', 99, true,
          c_creator, v_now_ms);

  -- A pending request follows the owner into his chamber; a resolved one is
  -- audit history and stays where it is.
  insert into public.delete_requests (
    id, entity_type, entity_id, entity_snapshot, target_base_version,
    requested_by, firm_id, status, created_at, updated_at
  )
  values
    ('scope2-request-pending', 'case', 'scope2-case', '{}', 1, c_creator, null,
     'pending', v_now_ms, v_now_ms),
    ('scope2-request-resolved', 'case', 'scope2-case', '{}', 1, c_creator, null,
     'approved', v_now_ms, v_now_ms);
end;
$$;

-- ---------------------------------------------------------------------------
-- Part A — creation shares the diary
-- ---------------------------------------------------------------------------

do $$
declare
  c_creator uuid := (select id::uuid from scope2_fixtures where name = 'creator');
  c_other_firm uuid :=
    (select id::uuid from scope2_fixtures where name = 'other_firm');
  v_out jsonb;
  v_firm uuid;
  v_pending record;
  v_row record;
begin
  perform pg_temp.as_user('authenticated', c_creator);
  v_out := public.ensure_firm('Creator Chambers');
  execute 'reset role';

  perform pg_temp.assert_true(
    v_out ->> 'status' = 'ready',
    'ensure_firm did not create the chamber: ' || coalesce(v_out::text, 'null')
  );
  v_firm := (v_out ->> 'firm_id')::uuid;

  -- Every row the creator authored while firm-less is the chamber's now, with a
  -- version bump. `server_updated_at` is the trigger's own column and a single
  -- transaction shares one `now()`, so the version is what this pins.
  for v_pending in
    select * from (values
      ('cases', 'scope2-case'),
      ('cases', 'scope2-case-tomb'),
      ('case_history', 'scope2-history'),
      ('notes', 'scope2-note'),
      ('case_references', 'scope2-reference'),
      ('court_categories', 'scope2-court-category'),
      ('case_categories', 'scope2-case-category'),
      ('courts', 'scope2-court'),
      ('steps', 'scope2-step'),
      ('case_types', 'scope2-case-type'),
      ('on_behalfs', 'scope2-on-behalf'),
      ('delete_requests', 'scope2-request-pending')
    ) as t(table_name, row_id)
  loop
    execute format(
      'select id, firm_id, version from public.%I where id = $1',
      v_pending.table_name
    ) into v_row using v_pending.row_id;

    perform pg_temp.assert_true(
      v_row.firm_id = v_firm,
      format(
        '%s %s did not follow the creator into the chamber (firm_id %s)',
        v_pending.table_name, v_pending.row_id,
        coalesce(v_row.firm_id::text, 'null')
      )
    );
    perform pg_temp.assert_true(
      v_row.version = 2,
      format(
        '%s %s was not version-bumped for the device pull (version %s)',
        v_pending.table_name, v_pending.row_id, v_row.version
      )
    );
  end loop;

  -- What the stamp must leave alone.
  perform pg_temp.assert_true(
    (select firm_id from public.cases where id = 'scope2-case-foreign')
      = c_other_firm,
    'a row of the creator''s that already belonged to a firm was re-scoped'
  );
  perform pg_temp.assert_true(
    (select firm_id from public.delete_requests
      where id = 'scope2-request-resolved') is null,
    'a resolved delete request followed the creator into the chamber'
  );
  perform pg_temp.assert_true(
    not exists (
      select 1 from public.courts
       where is_custom = false and firm_id is not null
    ),
    'the built-in reference baseline was scoped to a firm'
  );
  perform pg_temp.assert_true(
    not exists (
      select 1 from public.on_behalfs
       where is_custom = false and firm_id is not null
    ),
    'the built-in on-behalf baseline was scoped to a firm'
  );

  -- A second call is an idempotent rename, never a second stamping.
  perform pg_temp.as_user('authenticated', c_creator);
  v_out := public.ensure_firm('Creator Chambers Renamed');
  execute 'reset role';

  perform pg_temp.assert_true(
    (v_out ->> 'firm_id')::uuid = v_firm,
    'a second ensure_firm call created another chamber'
  );
  perform pg_temp.assert_true(
    (select name from public.firms where id = v_firm)
      = 'Creator Chambers Renamed',
    'a second ensure_firm call did not rename the chamber'
  );
  perform pg_temp.assert_true(
    (select version from public.cases where id = 'scope2-case') = 2
    and (select version from public.notes where id = 'scope2-note') = 2,
    'a second ensure_firm call stamped the creator''s diary again'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Part B — the scope columns belong to the server
-- ---------------------------------------------------------------------------

do $$
declare
  c_assoc uuid := (select id::uuid from scope2_fixtures where name = 'assoc');
  c_solo uuid := (select id::uuid from scope2_fixtures where name = 'solo');
  c_firm uuid := (select id::uuid from scope2_fixtures where name = 'firm');
  c_other_firm uuid :=
    (select id::uuid from scope2_fixtures where name = 'other_firm');
  c_court text := (select id from scope2_fixtures where name = 'builtin_court');
  c_on_behalf text :=
    (select id from scope2_fixtures where name = 'builtin_on_behalf');
  v_now_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_result jsonb;
begin
  -- 1. The defect this phase exists for: a member's insert arrives with the
  --    client's own `firm_id` (null — every repository writes it that way), and
  --    it must land in the chamber all the same.
  v_result := pg_temp.push_case(
    c_assoc, 'scope2-assoc-case', 'insert', null,
    jsonb_build_object(
      'id', 'scope2-assoc-case', 'user_id', c_assoc, 'firm_id', null,
      'case_number', 'SCOPE2-10', 'case_type', 'civil', 'court_id', c_court,
      'petitioner', 'A', 'respondent', 'B', 'on_behalf_id', c_on_behalf,
      'created_at', v_now_ms, 'updated_at', v_now_ms
    )
  );
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'accepted',
    'a member''s case insert was refused: ' || coalesce(v_result::text, 'null')
  );
  perform pg_temp.assert_true(
    v_result -> 'row' ->> 'firm_id' = c_firm::text,
    'a member''s insert did not take the chamber''s scope (firm_id '
      || coalesce(v_result -> 'row' ->> 'firm_id', 'null') || ')'
  );

  -- 2. A payload naming another firm is corrected, not obeyed, and a payload
  --    naming a scope owner is ignored.
  v_result := pg_temp.push_case(
    c_assoc, 'scope2-tamper-insert', 'insert', null,
    jsonb_build_object(
      'id', 'scope2-tamper-insert', 'user_id', c_assoc,
      'firm_id', c_other_firm, 'scope_owner_id', c_assoc,
      'case_number', 'SCOPE2-11', 'case_type', 'civil', 'court_id', c_court,
      'petitioner', 'C', 'respondent', 'D', 'on_behalf_id', c_on_behalf,
      'created_at', v_now_ms, 'updated_at', v_now_ms
    )
  );
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'accepted',
    'a tampering insert was refused rather than corrected: '
      || coalesce(v_result::text, 'null')
  );
  perform pg_temp.assert_true(
    v_result -> 'row' ->> 'firm_id' = c_firm::text,
    'a payload was allowed to choose the row''s firm'
  );
  perform pg_temp.assert_true(
    v_result -> 'row' ->> 'scope_owner_id' is null,
    'a payload was allowed to name itself the scope owner'
  );

  -- 3. An update cannot move an existing row out of its chamber, nor give it a
  --    scope owner.
  v_result := pg_temp.push_case(
    c_assoc, 'scope2-assoc-case', 'update', 1,
    jsonb_build_object(
      'id', 'scope2-assoc-case', 'user_id', c_assoc, 'firm_id', null,
      'scope_owner_id', c_assoc, 'case_remarks', 'updated in the chamber'
    )
  );
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'accepted',
    'a member''s chamber update was refused: '
      || coalesce(v_result::text, 'null')
  );
  perform pg_temp.assert_true(
    v_result -> 'row' ->> 'firm_id' = c_firm::text,
    'an update moved a chamber row out of its chamber'
  );
  perform pg_temp.assert_true(
    v_result -> 'row' ->> 'scope_owner_id' is null,
    'an update named the row''s scope owner'
  );
  perform pg_temp.assert_true(
    v_result -> 'row' ->> 'case_remarks' = 'updated in the chamber',
    'the update itself did not land'
  );

  -- 4. An individual stays individual: the derived scope is null, whatever the
  --    payload claimed.
  v_result := pg_temp.push_case(
    c_solo, 'scope2-solo-case', 'insert', null,
    jsonb_build_object(
      'id', 'scope2-solo-case', 'user_id', c_solo, 'firm_id', c_firm,
      'case_number', 'SCOPE2-12', 'case_type', 'civil', 'court_id', c_court,
      'petitioner', 'E', 'respondent', 'F', 'on_behalf_id', c_on_behalf,
      'created_at', v_now_ms, 'updated_at', v_now_ms
    )
  );
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'accepted',
    'an individual''s case insert was refused: '
      || coalesce(v_result::text, 'null')
  );
  perform pg_temp.assert_true(
    v_result -> 'row' ->> 'firm_id' is null,
    'an individual''s row took a firm from the payload'
  );
end;
$$;

rollback;

\echo 'CREATION OK: creation shares the diary, and the scope columns are the server''s.'
