-- Shared case references test — proves `20261031100000_shared_case_references.sql`.
--
-- Self-contained: two throwaway accounts are created inside one transaction that
-- is rolled back, so no fixture survives. Accounts are impersonated the way
-- PostgREST does it — `set local role authenticated` plus a `request.jwt.claims`
-- setting, which is what `auth.uid()` reads.
--
--   printf 'begin;\n' | cat - supabase/tests/shared_case_references_scope_test.sql <(echo rollback;) \
--     | psql "$SUPABASE_URL" -v ON_ERROR_STOP=1 --file=-
--
-- What it proves, in order:
--
--   1. The client privileges: `authenticated` holds the four write privileges
--      the RLS policies gate, and `anon` has nothing at all.
--   2. An administrator can insert a citation, and every signed-in account reads
--      it — the library is shared, not per account.
--   3. A non-admin's insert is refused by RLS, and their update and delete
--      touch no row: the admin policy is the boundary, not a UI rule.
--   4. An administrator can update and delete; the update is visible to a
--      non-admin and the delete removes it from their read.
--   5. The delta index the pull pages on exists.

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
    raise exception 'SHARED REFS FAIL: %', p_message;
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

do $$
declare
  c_admin uuid := gen_random_uuid();
  c_user uuid := gen_random_uuid();
  v_count integer;
  v_title text;
begin
  -- -------------------------------------------------------------------------
  -- 1. Privileges: the client reaches the table, `anon` does not.
  --    The write privileges are held so the admin policies can be consulted;
  --    they are not the boundary.
  -- -------------------------------------------------------------------------

  perform pg_temp.assert_true(
    has_table_privilege('authenticated', 'public.shared_case_references', 'select')
      and has_table_privilege('authenticated', 'public.shared_case_references', 'insert')
      and has_table_privilege('authenticated', 'public.shared_case_references', 'update')
      and has_table_privilege('authenticated', 'public.shared_case_references', 'delete'),
    'authenticated cannot reach the shared library its policies gate'
  );
  perform pg_temp.assert_true(
    not has_table_privilege('anon', 'public.shared_case_references', 'select'),
    'anon can read the shared library'
  );

  -- -------------------------------------------------------------------------
  -- 2. Fixtures: one administrator, one ordinary account.
  -- -------------------------------------------------------------------------

  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  )
  values
    (c_admin, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'shared-refs-admin@example.test',
     extensions.crypt('x', extensions.gen_salt('bf')), now(), now(), now()),
    (c_user, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'shared-refs-user@example.test',
     extensions.crypt('x', extensions.gen_salt('bf')), now(), now(), now());

  insert into public.app_admins (user_id) values (c_admin)
  on conflict (user_id) do nothing;

  -- -------------------------------------------------------------------------
  -- 3. The administrator publishes a citation.
  -- -------------------------------------------------------------------------

  perform pg_temp.as_user('authenticated', c_admin);
  insert into public.shared_case_references (
    id, reference_and_page_no, statute, section_or_article,
    title_and_description, comments_notes
  )
  values (
    'shared-ref-test-1', '29 DLR (AD) 69', 'The Penal Code, 1860',
    'Section 54', 'Preventive detention.', 'Published by the library test.'
  );
  reset role;

  -- -------------------------------------------------------------------------
  -- 4. Any signed-in account reads it, whether or not it wrote it.
  -- -------------------------------------------------------------------------

  perform pg_temp.as_user('authenticated', c_user);
  select count(*) into v_count
    from public.shared_case_references
   where id = 'shared-ref-test-1';
  perform pg_temp.assert_true(
    v_count = 1,
    'an ordinary account cannot read the citation the admin published'
  );

  -- -------------------------------------------------------------------------
  -- 5. That account can write nothing: an insert is refused by the policy, and
  --    an update or delete reaches no row (RLS filters them out silently,
  --    which is what PostgREST reports as a zero-row write).
  -- -------------------------------------------------------------------------

  begin
    insert into public.shared_case_references (id, reference_and_page_no)
    values ('shared-ref-test-2', '12 BLC 99');
    raise exception 'SHARED REFS FAIL: a non-admin inserted a citation';
  exception when insufficient_privilege then
    null;
  end;

  update public.shared_case_references
     set title_and_description = 'Rewritten by a non-admin'
   where id = 'shared-ref-test-1';
  get diagnostics v_count = row_count;
  perform pg_temp.assert_true(
    v_count = 0,
    'a non-admin updated a citation'
  );

  delete from public.shared_case_references where id = 'shared-ref-test-1';
  get diagnostics v_count = row_count;
  perform pg_temp.assert_true(
    v_count = 0,
    'a non-admin deleted a citation'
  );

  reset role;

  -- -------------------------------------------------------------------------
  -- 6. The administrator edits and removes it; the client sees both.
  -- -------------------------------------------------------------------------

  perform pg_temp.as_user('authenticated', c_admin);
  update public.shared_case_references
     set title_and_description = 'Revised by the library admin'
   where id = 'shared-ref-test-1';
  reset role;

  perform pg_temp.as_user('authenticated', c_user);
  select title_and_description into v_title
    from public.shared_case_references
   where id = 'shared-ref-test-1';
  perform pg_temp.assert_true(
    v_title = 'Revised by the library admin',
    'an admin''s edit did not reach the ordinary account'
  );
  reset role;

  perform pg_temp.as_user('authenticated', c_admin);
  delete from public.shared_case_references where id = 'shared-ref-test-1';
  reset role;

  perform pg_temp.as_user('authenticated', c_user);
  select count(*) into v_count
    from public.shared_case_references
   where id = 'shared-ref-test-1';
  perform pg_temp.assert_true(
    v_count = 0,
    'a citation the admin deleted is still readable'
  );
  reset role;

  -- -------------------------------------------------------------------------
  -- 7. The delta index the pull pages on exists.
  -- -------------------------------------------------------------------------

  perform pg_temp.assert_true(
    exists (
      select 1 from pg_indexes
       where schemaname = 'public'
         and tablename = 'shared_case_references'
         and indexname = 'shared_case_references_delta_idx'
    ),
    'the delta index is missing; a pull would sort the whole table'
  );

  raise notice 'SHARED REFS OK';
end;
$$;
