-- Law-list scope test — proves `20261030120000_laws_table.sql` and the seed it
-- carries in `20261030121000_laws_reference_data.sql`.
--
-- Self-contained: five throwaway accounts and two chambers are created inside one
-- transaction that is rolled back, so no fixture survives. Accounts are
-- impersonated the way PostgREST does it — `set local role authenticated` plus a
-- `request.jwt.claims` setting, which is what `auth.uid()` reads — and writes go
-- through `push_changes`, so the RPC's own mapping, permission verdict and
-- triggers all run for real.
--
--   printf 'begin;\n' | cat - supabase/tests/laws_scope_test.sql <(echo rollback;) \
--     | psql "$DATABASE_URL" -v ON_ERROR_STOP=1 --file=-
--
-- What it proves, in order:
--
--   1. The seed: 57 built-in rows, all seven categories used, order 0…56 unique,
--      every row unmodified and unsynced.
--   2. An individual's own law is personal — readable by its author, invisible to
--      another individual and to a chamber.
--   3. A chamber's law is shared — an insert by the owner lands in the chamber
--      and the associate reads it, while another chamber does not.
--   4. A rename by a member is visible to the whole chamber; a member without
--      `can_delete` cannot tombstone it, and the owner can.
--   5. A payload cannot name somebody else as the law's author, and neither a
--      payload's `firm_id` nor `scope_owner_id` is obeyed.
--   6. The push path maps the entity: `sync_entity_table('law') = 'laws'` and
--      `sync_dependency_rank('law') = 0`.

begin;

-- ---------------------------------------------------------------------------
-- Assertion helpers (the shape the other scope tests use)
-- ---------------------------------------------------------------------------

create or replace function pg_temp.assert_true(p_condition boolean, p_message text)
returns void
language plpgsql
as $$
begin
  if p_condition is not true then
    raise exception 'LAWS FAIL: %', p_message;
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

-- One `law` mutation pushed as p_user; returns its single result object.
create or replace function pg_temp.push_law(
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
    'entity_type', 'law',
    'entity_id', p_id,
    'operation', p_operation,
    'base_version', p_base_version,
    'payload', p_payload
  )));
  execute 'reset role';
  return v_out -> 'results' -> 0;
end;
$$;

-- How many laws p_user can read, through RLS.
create or replace function pg_temp.visible_law_count(p_user uuid)
returns integer
language plpgsql
as $$
declare
  v_count integer;
begin
  perform pg_temp.as_user('authenticated', p_user);
  select count(*) into v_count from public.laws;
  execute 'reset role';
  return v_count;
end;
$$;

-- Whether p_user can read one law id, through RLS.
create or replace function pg_temp.can_read_law(p_user uuid, p_id text)
returns boolean
language plpgsql
as $$
declare
  v_found boolean;
begin
  perform pg_temp.as_user('authenticated', p_user);
  select exists (select 1 from public.laws l where l.id = p_id)
    into v_found;
  execute 'reset role';
  return v_found;
end;
$$;

-- The stored name p_user reads for one law id, through RLS (null when hidden).
create or replace function pg_temp.read_law_name(p_user uuid, p_id text)
returns text
language plpgsql
as $$
declare
  v_name text;
begin
  perform pg_temp.as_user('authenticated', p_user);
  select l.name into v_name from public.laws l where l.id = p_id;
  execute 'reset role';
  return v_name;
end;
$$;

-- ---------------------------------------------------------------------------
-- Fixtures: two chambers, two individuals
-- ---------------------------------------------------------------------------

create temporary table laws_fixtures (
  name text primary key,
  id text not null
) on commit drop;

do $$
declare
  c_solo_a uuid := gen_random_uuid();
  c_solo_b uuid := gen_random_uuid();
  c_owner uuid := gen_random_uuid();
  c_assoc uuid := gen_random_uuid();
  c_outsider uuid := gen_random_uuid();
  c_firm uuid := gen_random_uuid();
  c_other_firm uuid := gen_random_uuid();
  v_now_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
begin
  insert into laws_fixtures (name, id) values
    ('solo_a', c_solo_a::text),
    ('solo_b', c_solo_b::text),
    ('owner', c_owner::text),
    ('assoc', c_assoc::text),
    ('outsider', c_outsider::text),
    ('firm', c_firm::text),
    ('other_firm', c_other_firm::text);

  -- The sign-up trigger creates one profiles row per account.
  insert into auth.users (
    id, instance_id, aud, role, email, email_confirmed_at, created_at, updated_at
  )
  values
    (c_solo_a, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'laws-solo-a@example.test', now(), now(), now()),
    (c_solo_b, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'laws-solo-b@example.test', now(), now(), now()),
    (c_owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'laws-owner@example.test', now(), now(), now()),
    (c_assoc, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'laws-assoc@example.test', now(), now(), now()),
    (c_outsider, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'laws-outsider@example.test', now(), now(), now());

  -- Two solo accounts are premium, which push_changes requires; the chambers'
  -- own expiry is what entitles their members.
  update public.profiles
     set subscription_expiry = now() + interval '30 days'
   where id in (c_solo_a, c_solo_b, c_owner, c_outsider);

  insert into public.firms (
    id, name, owner_id, subscription_status, subscription_expiry
  )
  values
    (c_firm, 'Laws Test Chambers', c_owner, 'active',
     now() + interval '30 days'),
    (c_other_firm, 'Other Laws Chambers', c_outsider, 'active',
     now() + interval '30 days');

  update public.profiles
     set firm_id = c_firm, role = 'owner'
   where id = c_owner;
  update public.profiles
     set firm_id = c_firm, role = 'associate'
   where id = c_assoc;
  update public.profiles
     set firm_id = c_other_firm, role = 'owner'
   where id = c_outsider;

  insert into public.firm_members (
    firm_id, user_id, role, can_add, can_edit, can_delete,
    synced_at, permissions_synced_at
  )
  values
    (c_firm, c_owner, 'owner', true, true, true, v_now_ms, v_now_ms),
    -- The associate may add and edit but not delete: deletion inside a chamber
    -- is the delete-request workflow.
    (c_firm, c_assoc, 'associate', true, true, false, v_now_ms, v_now_ms),
    (c_other_firm, c_outsider, 'owner', true, true, true, v_now_ms, v_now_ms);
end;
$$;

-- ---------------------------------------------------------------------------
-- Part 1 — the seed
-- ---------------------------------------------------------------------------

do $$
declare
  v_builtins integer;
  v_categories integer;
  v_orders integer;
  v_dirty integer;
begin
  select count(*) into v_builtins
    from public.laws where is_custom = false and is_deleted = false;
  perform pg_temp.assert_true(
    v_builtins = 57,
    format('the built-in list should hold 57 names, found %s', v_builtins)
  );

  select count(distinct category) into v_categories
    from public.laws where is_custom = false;
  perform pg_temp.assert_true(
    v_categories = 7,
    format('the seed should use all seven categories, found %s', v_categories)
  );

  select count(distinct order_index) into v_orders
    from public.laws where is_custom = false;
  perform pg_temp.assert_true(
    v_orders = 57,
    format('every seeded law needs its own order, found %s', v_orders)
  );
  perform pg_temp.assert_true(
    (select min(order_index) from public.laws where is_custom = false) = 0
    and (select max(order_index) from public.laws where is_custom = false) = 56,
    'the seed order must run 0…56'
  );

  select count(*) into v_dirty
    from public.laws
   where is_custom = false
     and (is_user_modified or is_deleted or version <> 1 or synced_at is not null);
  perform pg_temp.assert_true(
    v_dirty = 0,
    format('%s built-in rows carry user or sync state', v_dirty)
  );

  -- The first and last name of the reference document, so a seed that is the
  -- right size but the wrong list is caught.
  perform pg_temp.assert_true(
    exists (
      select 1 from public.laws
       where id = 'law-constitution-of-the-peoples-republic-of-bangladesh'
         and name = 'The Constitution of the People’s Republic of Bangladesh'
         and category = 'constitution_courts_practice'
    ),
    'the Constitution is missing or misfiled'
  );
  perform pg_temp.assert_true(
    exists (
      select 1 from public.laws
       where id = 'law-consumer-rights-protection-act-2009'
         and category = 'labour_everyday_regulation'
    ),
    'the last seeded law is missing or misfiled'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Part 2 — an individual's own law stays personal
-- ---------------------------------------------------------------------------

do $$
declare
  c_solo_a uuid := (select id::uuid from laws_fixtures where name = 'solo_a');
  c_solo_b uuid := (select id::uuid from laws_fixtures where name = 'solo_b');
  c_owner uuid := (select id::uuid from laws_fixtures where name = 'owner');
  v_now_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_result jsonb;
begin
  v_result := pg_temp.push_law(
    c_solo_a, 'laws-test-solo', 'insert', null,
    jsonb_build_object(
      'id', 'laws-test-solo', 'name', 'The Solo Test Act, 2024',
      'category', 'criminal_law', 'order_index', 57, 'is_custom', true,
      'is_user_modified', false, 'user_id', c_solo_a, 'firm_id', null,
      'updated_at', v_now_ms, 'version', null, 'synced_at', null,
      'is_deleted', false
    )
  );
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'accepted',
    'a solo account could not add a law: ' || coalesce(v_result::text, 'null')
  );
  perform pg_temp.assert_true(
    v_result -> 'row' ->> 'firm_id' is null,
    'a solo account''s law took a firm'
  );

  perform pg_temp.assert_true(
    pg_temp.can_read_law(c_solo_a, 'laws-test-solo'),
    'the author cannot read their own law'
  );
  perform pg_temp.assert_true(
    not pg_temp.can_read_law(c_solo_b, 'laws-test-solo'),
    'another individual can read somebody else''s law'
  );
  perform pg_temp.assert_true(
    not pg_temp.can_read_law(c_owner, 'laws-test-solo'),
    'a chamber member can read an individual''s law'
  );

  -- The built-in baseline is readable by everyone.
  perform pg_temp.assert_true(
    pg_temp.can_read_law(c_solo_b, 'law-penal-code-1860'),
    'an individual cannot read the built-in law list'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Part 3 — a chamber shares one law list, and only with its members
-- ---------------------------------------------------------------------------

do $$
declare
  c_owner uuid := (select id::uuid from laws_fixtures where name = 'owner');
  c_assoc uuid := (select id::uuid from laws_fixtures where name = 'assoc');
  c_outsider uuid := (select id::uuid from laws_fixtures where name = 'outsider');
  c_firm uuid := (select id::uuid from laws_fixtures where name = 'firm');
  c_other_firm uuid :=
    (select id::uuid from laws_fixtures where name = 'other_firm');
  v_now_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_result jsonb;
begin
  -- The client sends `firm_id` null on every insert; the server derives it.
  v_result := pg_temp.push_law(
    c_owner, 'laws-test-firm', 'insert', null,
    jsonb_build_object(
      'id', 'laws-test-firm', 'name', 'The Chamber Test Act, 2024',
      'category', 'contract_land_property_business', 'order_index', 58,
      'is_custom', true, 'is_user_modified', false, 'user_id', c_owner,
      'firm_id', null, 'updated_at', v_now_ms, 'version', null,
      'synced_at', null, 'is_deleted', false
    )
  );
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'accepted',
    'the owner could not add a chamber law: '
      || coalesce(v_result::text, 'null')
  );
  perform pg_temp.assert_true(
    v_result -> 'row' ->> 'firm_id' = c_firm::text,
    'a chamber law did not take the chamber''s scope'
  );

  perform pg_temp.assert_true(
    pg_temp.can_read_law(c_assoc, 'laws-test-firm'),
    'an associate cannot read the chamber''s law'
  );
  perform pg_temp.assert_true(
    not pg_temp.can_read_law(c_outsider, 'laws-test-firm'),
    'another chamber can read this chamber''s law'
  );

  -- The associate sees the 57 built-ins plus the chamber's own row, and not the
  -- other chamber's business.
  perform pg_temp.assert_true(
    pg_temp.visible_law_count(c_assoc) = 58,
    format(
      'the associate should see 58 laws, saw %s',
      pg_temp.visible_law_count(c_assoc)
    )
  );
  perform pg_temp.assert_true(
    not pg_temp.can_read_law(c_outsider, 'laws-test-firm'),
    'the other chamber can name this chamber''s law'
  );

  -- A payload naming another firm is corrected, not obeyed; a payload naming a
  -- scope owner is ignored.
  v_result := pg_temp.push_law(
    c_owner, 'laws-test-tamper', 'insert', null,
    jsonb_build_object(
      'id', 'laws-test-tamper', 'name', 'The Tamper Act, 2024',
      'category', 'tax_finance', 'order_index', 59, 'is_custom', true,
      'is_user_modified', false, 'user_id', c_owner, 'firm_id', c_other_firm,
      'scope_owner_id', c_owner, 'updated_at', v_now_ms, 'version', null,
      'synced_at', null, 'is_deleted', false
    )
  );
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'accepted',
    'a tampering law insert was refused instead of corrected: '
      || coalesce(v_result::text, 'null')
  );
  perform pg_temp.assert_true(
    v_result -> 'row' ->> 'firm_id' = c_firm::text,
    'a payload was allowed to choose a law''s firm'
  );
  perform pg_temp.assert_true(
    v_result -> 'row' ->> 'scope_owner_id' is null,
    'a payload was allowed to name a scope owner'
  );

  -- A payload cannot make somebody else the author.
  v_result := pg_temp.push_law(
    c_outsider, 'laws-test-forged', 'insert', null,
    jsonb_build_object(
      'id', 'laws-test-forged', 'name', 'The Forged Act, 2024',
      'category', 'criminal_law', 'order_index', 60, 'is_custom', true,
      'is_user_modified', false, 'user_id', c_owner, 'firm_id', null,
      'updated_at', v_now_ms, 'version', null, 'synced_at', null,
      'is_deleted', false
    )
  );
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'rejected',
    'a law written under another account''s name was accepted'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Part 4 — rename, and the delete permission
-- ---------------------------------------------------------------------------

do $$
declare
  c_owner uuid := (select id::uuid from laws_fixtures where name = 'owner');
  c_assoc uuid := (select id::uuid from laws_fixtures where name = 'assoc');
  v_now_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_version integer;
  v_result jsonb;
begin
  select version into v_version from public.laws where id = 'laws-test-firm';

  -- The associate has can_edit, so a rename goes through — and the whole
  -- chamber reads it, because it is one row.
  v_result := pg_temp.push_law(
    c_assoc, 'laws-test-firm', 'update', v_version,
    jsonb_build_object(
      'id', 'laws-test-firm', 'name', 'The Chamber Statute (renamed)',
      'category', 'contract_land_property_business', 'order_index', 58,
      'is_custom', true, 'is_user_modified', true, 'user_id', c_owner,
      'firm_id', null, 'updated_at', v_now_ms, 'version', null,
      'synced_at', null, 'is_deleted', false
    )
  );
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'accepted',
    'a member could not rename the chamber''s law: '
      || coalesce(v_result::text, 'null')
  );
  perform pg_temp.assert_true(
    pg_temp.read_law_name(c_owner, 'laws-test-firm') =
      'The Chamber Statute (renamed)',
    'the owner does not read the member''s rename'
  );

  -- The associate has no can_delete: the tombstone is refused.
  select version into v_version from public.laws where id = 'laws-test-firm';
  v_result := pg_temp.push_law(
    c_assoc, 'laws-test-firm', 'delete', v_version,
    jsonb_build_object(
      'id', 'laws-test-firm', 'is_deleted', true, 'updated_at', v_now_ms,
      'last_modified_by', c_assoc
    )
  );
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'rejected',
    'an associate without can_delete deleted a chamber law: '
      || coalesce(v_result::text, 'null')
  );

  -- The owner may tombstone the chamber's own row.
  select version into v_version from public.laws where id = 'laws-test-firm';
  v_result := pg_temp.push_law(
    c_owner, 'laws-test-firm', 'delete', v_version,
    jsonb_build_object(
      'id', 'laws-test-firm', 'is_deleted', true, 'updated_at', v_now_ms,
      'last_modified_by', c_owner
    )
  );
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'accepted',
    'the owner could not delete the chamber''s law: '
      || coalesce(v_result::text, 'null')
  );
  perform pg_temp.assert_true(
    (select is_deleted from public.laws where id = 'laws-test-firm'),
    'the tombstone was not written'
  );

  -- A built-in row is the globally shared baseline: nobody deletes it.
  select version into v_version
    from public.laws where id = 'law-penal-code-1860';
  v_result := pg_temp.push_law(
    c_owner, 'law-penal-code-1860', 'delete', v_version,
    jsonb_build_object(
      'id', 'law-penal-code-1860', 'is_deleted', true, 'updated_at', v_now_ms,
      'last_modified_by', c_owner
    )
  );
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'rejected',
    'a built-in law was deleted: ' || coalesce(v_result::text, 'null')
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Part 5 — the push path knows the entity
-- ---------------------------------------------------------------------------

do $$
begin
  perform pg_temp.assert_true(
    public.sync_entity_table('law') = 'laws',
    'sync_entity_table does not map `law` to `laws`'
  );
  perform pg_temp.assert_true(
    public.sync_dependency_rank('law') = 0,
    'a law must push before the cases that may cite it'
  );
  perform pg_temp.assert_true(
    public.sync_entity_table('laws') is null,
    'the plural must not be an entity type'
  );
end;
$$;

\echo 'LAWS OK'
