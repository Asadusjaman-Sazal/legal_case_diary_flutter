-- Dissolve scope-owner write proof — proves
-- `20261101160000_dissolve_scope_owner_write.sql`.
--
-- Self-contained: throwaway accounts and rows are created inside one
-- transaction that is rolled back, so no fixture survives. The direct probes
-- run as `authenticated` with `request.jwt.claims` set, and the RPC verdict is
-- read from `sync_can_write` with the same claims, so both write doors are
-- exercised as a phone uses them.
--
-- Runs as it stands:
--
--   psql "$URL" -v ON_ERROR_STOP=1 -f supabase/tests/dissolve_scope_owner_write_test.sql
--
-- Five checks, in order:
--
--   * **the dissolved chamber's owner can delete an inherited case** — the row
--     names the associate as `user_id` and the owner as `scope_owner_id`, which
--     is exactly what `dissolve_firm()` writes;
--   * **the owner can edit an inherited custom reference row** — the same scope
--     key, a non-tombstone update;
--   * **the old author cannot write it** — the row's author is refused once a
--     scope owner owns it, and the row keeps the owner's value;
--   * **an unrelated account cannot write it** — the scope key is not a grant;
--   * **`sync_can_write` gives the same verdicts** for the owner and the author,
--     and a normal own row still writes, so the fix did not widen every row.

begin;

-- ---------------------------------------------------------------------------
-- Assertion and impersonation helpers
-- ---------------------------------------------------------------------------

create or replace function pg_temp.assert_true(p_condition boolean, p_message text)
returns void
language plpgsql
as $$
begin
  if p_condition is not true then
    raise exception 'SCOPE OWNER FAIL: %', p_message;
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

-- The RPC verdict is read with the caller's claims, as push_changes does.
create or replace function pg_temp.can_write(
  p_user uuid,
  p_table text,
  p_row jsonb,
  p_operation text
)
returns boolean
language plpgsql
as $$
declare
  v_ok boolean;
begin
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', p_user::text, 'role', 'authenticated')::text,
    true
  );
  v_ok := public.sync_can_write(p_table, p_row, p_operation);
  perform set_config('request.jwt.claims', '', true);
  return v_ok;
end;
$$;

-- ---------------------------------------------------------------------------
-- Fixtures: an owner, the associate whose row the dissolve hands over, and
-- one unrelated account. The scope pair is written by hand because this test
-- does not need a whole firm to prove the write rules.
-- ---------------------------------------------------------------------------

do $$
declare
  v_owner uuid := pg_temp.sign_up('scope-owner@test.local');
  v_author uuid := pg_temp.sign_up('scope-author@test.local');
  v_other uuid := pg_temp.sign_up('scope-other@test.local');
  v_court text;
  v_on_behalf text;
begin
  perform set_config('test.scope_owner', v_owner::text, true);
  perform set_config('test.scope_author', v_author::text, true);
  perform set_config('test.scope_other', v_other::text, true);

  select id into v_court from public.courts where is_deleted = false limit 1;
  select id into v_on_behalf from public.on_behalfs where is_deleted = false limit 1;
  perform pg_temp.assert_true(
    v_court is not null and v_on_behalf is not null,
    'the reference rows a case needs are missing'
  );
  perform set_config('test.scope_court', v_court, true);
  perform set_config('test.scope_on_behalf', v_on_behalf, true);

  insert into public.cases (
    id, user_id, firm_id, scope_owner_id, court_id, on_behalf_id,
    case_type, case_number, petitioner, respondent, next_date,
    created_at, updated_at, version, is_deleted, last_modified_by
  ) values
    ('scope-case-owner-delete', v_author, null, v_owner, v_court, v_on_behalf,
     'Election Petition-', '10/22', 'Petitioner', 'Respondent', 1000,
     1, 1, 1, false, v_author::text),
    ('scope-case-author-write', v_author, null, v_owner, v_court, v_on_behalf,
     'Election Petition-', '11/22', 'Petitioner', 'Respondent', 1000,
     1, 1, 1, false, v_author::text),
    ('scope-case-own-row', v_owner, null, null, v_court, v_on_behalf,
     'Election Petition-', '12/22', 'Petitioner', 'Respondent', 1000,
     1, 1, 1, false, v_owner::text);

  insert into public.court_categories (
    id, name_key, court_level, order_index, is_custom, user_id, scope_owner_id,
    updated_at, version, is_deleted
  ) values (
    'scope-category-inherited', 'owner_before', 'lower', 900, true, v_author,
    v_owner, 1, 1, false
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 1. The owner deletes an inherited case and edits an inherited category
-- ---------------------------------------------------------------------------

do $$
declare
  v_owner uuid := current_setting('test.scope_owner')::uuid;
  v_rows integer;
begin
  perform pg_temp.as_user('authenticated', v_owner);
  update public.cases set is_deleted = true, version = version + 1
   where id = 'scope-case-owner-delete';
  get diagnostics v_rows = row_count;
  perform pg_temp.assert_true(
    v_rows = 1,
    'the scope owner could not delete the inherited case'
  );

  update public.court_categories set name_key = 'owner_after'
   where id = 'scope-category-inherited';
  get diagnostics v_rows = row_count;
  perform pg_temp.assert_true(
    v_rows = 1,
    'the scope owner could not edit the inherited reference row'
  );
  perform pg_temp.as_owner();
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. The old author and an unrelated account cannot write the inherited rows
-- ---------------------------------------------------------------------------

do $$
declare
  v_author uuid := current_setting('test.scope_author')::uuid;
  v_other uuid := current_setting('test.scope_other')::uuid;
  v_rows integer;
  v_name text;
begin
  perform pg_temp.as_user('authenticated', v_author);
  update public.cases set case_number = 'author-changed'
   where id = 'scope-case-author-write';
  get diagnostics v_rows = row_count;
  perform pg_temp.assert_true(
    v_rows = 0,
    'the old author could still write the inherited case'
  );

  update public.court_categories set name_key = 'author_after'
   where id = 'scope-category-inherited';
  get diagnostics v_rows = row_count;
  perform pg_temp.assert_true(
    v_rows = 0,
    'the old author could still write the inherited reference row'
  );
  perform pg_temp.as_owner();

  select name_key into v_name
    from public.court_categories
   where id = 'scope-category-inherited';
  perform pg_temp.assert_true(
    v_name = 'owner_after',
    'the old author overwrote the owner''s reference row'
  );

  perform pg_temp.as_user('authenticated', v_other);
  update public.cases set case_number = 'other-changed'
   where id = 'scope-case-author-write';
  get diagnostics v_rows = row_count;
  perform pg_temp.assert_true(
    v_rows = 0,
    'an unrelated account could write the inherited case'
  );
  perform pg_temp.as_owner();
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. The RPC verdict matches the policies, and an ordinary own row still works
-- ---------------------------------------------------------------------------

do $$
declare
  v_owner uuid := current_setting('test.scope_owner')::uuid;
  v_author uuid := current_setting('test.scope_author')::uuid;
  v_other uuid := current_setting('test.scope_other')::uuid;
  v_case jsonb;
  v_category jsonb;
  v_rows integer;
begin
  select to_jsonb(t) into v_case from public.cases t
   where t.id = 'scope-case-author-write';
  select to_jsonb(t) into v_category from public.court_categories t
   where t.id = 'scope-category-inherited';

  perform pg_temp.assert_true(
    pg_temp.can_write(v_owner, 'cases', v_case, 'delete'),
    'sync_can_write refused the scope owner''s case delete'
  );
  perform pg_temp.assert_true(
    pg_temp.can_write(v_owner, 'court_categories', v_category, 'update'),
    'sync_can_write refused the scope owner''s category edit'
  );
  perform pg_temp.assert_true(
    not pg_temp.can_write(v_author, 'cases', v_case, 'delete'),
    'sync_can_write accepted the old author''s case delete'
  );
  perform pg_temp.assert_true(
    not pg_temp.can_write(v_author, 'court_categories', v_category, 'update'),
    'sync_can_write accepted the old author''s category edit'
  );
  perform pg_temp.assert_true(
    not pg_temp.can_write(v_other, 'cases', v_case, 'delete'),
    'sync_can_write accepted an unrelated account''s case delete'
  );

  -- A normal own row has no scope owner and remains writable by its author.
  perform pg_temp.as_user('authenticated', v_owner);
  update public.cases set case_number = 'owner-own-row'
   where id = 'scope-case-own-row';
  get diagnostics v_rows = row_count;
  perform pg_temp.assert_true(
    v_rows = 1,
    'the fix broke an ordinary own-row write'
  );
  perform pg_temp.as_owner();

  -- An insert may not name the server-owned scope column.
  perform pg_temp.assert_true(
    not pg_temp.can_write(
      v_owner,
      'cases',
      jsonb_build_object(
        'id', 'scope-case-forged',
        'user_id', v_owner,
        'firm_id', null,
        'scope_owner_id', v_owner,
        'is_deleted', false
      ),
      'insert'
    ),
    'sync_can_write accepted a forged scope_owner_id on insert'
  );
end;
$$;

select 'OK dissolve scope owner write' as result;

rollback;
