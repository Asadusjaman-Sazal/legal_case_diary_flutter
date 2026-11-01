-- District case types test — proves `20261101120000_district_case_types.sql`.
--
-- Self-contained: the probes run inside one transaction that is rolled back, so
-- no fixture survives. Client reads and writes are exercised the way PostgREST
-- does it — `set local role authenticated` plus `request.jwt.claims`, which is
-- what `auth.uid()` reads — so the reference-table policies run for real.
--
-- Runs as it stands, because it opens and closes its own transaction:
--
--   psql "$URL" -v ON_ERROR_STOP=1 -f supabase/tests/district_case_types_test.sql
--
-- Four checks, in order:
--
--   * **the seven Narayanganj CJM rows exist as built-ins** — every expected id
--     carries its English and Bengali names, `district = narayanganj` and its
--     seed position; none is user-created or user-modified;
--   * **no other category received them** — all seven are in CJM, and the
--     category's original district-free defaults are still there;
--   * **every account can read them** — an authenticated account with no
--     related row reads all seven through the built-in branch of the reference
--     RLS policy;
--   * **a custom scoped type stays private** — its creator reads it with the new
--     columns intact, and a second account cannot see it.

begin;

-- ---------------------------------------------------------------------------
-- Assertion and impersonation helpers (the shape the other probes use)
-- ---------------------------------------------------------------------------

create or replace function pg_temp.assert_true(p_condition boolean, p_message text)
returns void
language plpgsql
as $$
begin
  if p_condition is not true then
    raise exception 'DISTRICT CASE TYPES FAIL: %', p_message;
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

-- Puts the session back the way it was found: the role and the claims setting.
create or replace function pg_temp.as_owner()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', '', true);
  execute 'reset role';
end;
$$;

-- Registers one account and returns its id, the way sign-up does it.
create or replace function pg_temp.sign_up(p_email text)
returns uuid
language plpgsql
as $$
declare
  v_id uuid := gen_random_uuid();
begin
  insert into auth.users (id, email, email_confirmed_at, created_at, updated_at,
                          is_sso_user, is_anonymous)
  values (v_id, p_email, now(), now(), now(), false, false);
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 1. The seven built-in rows
-- ---------------------------------------------------------------------------

do $$
declare
  v_names text[] := array[
    'Narayanganj-', 'Fatulla-', 'Rupganj-', 'Araihajar-',
    'Sonargaon-', 'Bandar-', 'Siddhirganj-'
  ];
  v_bengali text[] := array[
    'নারায়ণগঞ্জ-', 'ফতুল্লা-', 'রুপগঞ্জ-', 'আড়াইহাজার-',
    'সোনারাগাঁও-', 'বন্দর-', 'সিদ্ধিরগঞ্জ-'
  ];
  v_slugs text[] := array[
    'narayanganj', 'fatulla', 'rupganj', 'araihajar',
    'sonargaon', 'bandar', 'siddhirganj'
  ];
  v_count integer;
  v_index integer;
begin
  select count(*) into v_count
  from public.case_types
  where court_category_id = 'chief_judicial_magistrate'
    and district = 'narayanganj';
  perform pg_temp.assert_true(v_count = 7, 'expected 7 Narayanganj CJM rows');

  for v_index in 1..7 loop
    perform pg_temp.assert_true(
      exists (
        select 1 from public.case_types
        where id = 'casetype-chief_judicial_magistrate-' || v_slugs[v_index]
          and court_category_id = 'chief_judicial_magistrate'
          and name = v_names[v_index]
          and name_bn = v_bengali[v_index]
          and district = 'narayanganj'
          and order_index = v_index + 3
          and is_custom = false
          and is_user_modified = false
          and is_deleted = false
      ),
      'row ' || v_index || ' (' || v_names[v_index] || ') is wrong'
    );
  end loop;

  -- The category's original district-free defaults are untouched.
  select count(*) into v_count
  from public.case_types
  where court_category_id = 'chief_judicial_magistrate'
    and district is null
    and is_custom = false
    and is_deleted = false;
  perform pg_temp.assert_true(
    v_count > 0,
    'the CJM category lost its district-free defaults'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. The two new columns are writable by the app's own role
-- ---------------------------------------------------------------------------

do $$
begin
  perform pg_temp.assert_true(
    has_column_privilege(
      'authenticated', 'public.case_types', 'name_bn', 'INSERT'
    ),
    'authenticated cannot insert name_bn'
  );
  perform pg_temp.assert_true(
    has_column_privilege(
      'authenticated', 'public.case_types', 'district', 'UPDATE'
    ),
    'authenticated cannot update district'
  );
  perform pg_temp.assert_true(
    has_column_privilege(
      'authenticated', 'public.case_types', 'name_bn', 'SELECT'
    ),
    'authenticated cannot read name_bn'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Every account reads the built-ins
-- ---------------------------------------------------------------------------

do $$
declare
  v_reader uuid := gen_random_uuid();
  v_count integer;
begin
  perform pg_temp.as_user('authenticated', v_reader);
  select count(*) into v_count
  from public.case_types
  where court_category_id = 'chief_judicial_magistrate'
    and district = 'narayanganj';
  perform pg_temp.as_owner();

  perform pg_temp.assert_true(
    v_count = 7,
    'an unrelated authenticated account saw ' || v_count || ' built-in rows'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. A custom scoped type stays private, with both new columns intact
-- ---------------------------------------------------------------------------

do $$
declare
  v_owner uuid := pg_temp.sign_up('district-type-owner@test.local');
  v_other uuid;
  v_count integer;
  v_name_bn text;
  v_district text;
begin
  v_other := pg_temp.sign_up('district-type-other@test.local');
  perform pg_temp.as_user('authenticated', v_owner);
  insert into public.case_types (
    id, court_category_id, name, name_bn, district, order_index,
    is_custom, is_user_modified, user_id, firm_id, updated_at, version,
    is_deleted, last_modified_by
  ) values (
    'casetype-district-proof', 'chief_judicial_magistrate', 'Proof Type',
    'প্রমাণ ধরন', 'dhaka', 90,
    true, false, v_owner, null,
    (extract(epoch from clock_timestamp()) * 1000)::bigint, 1,
    false, v_owner::text
  );

  select name_bn, district into v_name_bn, v_district
  from public.case_types
  where id = 'casetype-district-proof';
  perform pg_temp.assert_true(
    v_name_bn = 'প্রমাণ ধরন' and v_district = 'dhaka',
    'the custom row did not keep its Bengali name and district'
  );
  perform pg_temp.as_owner();

  perform pg_temp.as_user('authenticated', v_other);
  select count(*) into v_count
  from public.case_types
  where id = 'casetype-district-proof';
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(
    v_count = 0,
    'another account could see the custom scoped row'
  );
end;
$$;

select 'OK district case types' as result;

rollback;
