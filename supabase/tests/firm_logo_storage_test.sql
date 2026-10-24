-- Firm-logo storage test — proves 20261025120000_firm_logo_storage.sql.
--
-- Self-contained: two throwaway chambers and their accounts are created in one
-- transaction that is rolled back, so no fixture survives. The object paths run
-- the way PostgREST/Storage does it — `set local role authenticated` plus
-- `request.jwt.claims`, which is what `auth.uid()` reads — so the bucket's
-- policies are exercised for real, not simulated.
--
-- Run against the project:
--
--   psql "$URL" -v ON_ERROR_STOP=1 -f supabase/tests/firm_logo_storage_test.sql
--
-- What it proves, in order:
--
--   * the `firm-avatars` bucket is private, 50 KB, JPEG only;
--   * `firms.logo_path` / `logo_version` exist and are not client-writable;
--   * the storage trigger stamps them on insert/update/delete;
--   * a member of the chamber may read its logo, and nobody else can;
--   * only the owner may write, only while the chamber's plan is live;
--   * the owner may delete after a lapse;
--   * another chamber's owner cannot write this chamber's object.

begin;

create or replace function pg_temp.assert_true(p_condition boolean, p_message text)
returns void
language plpgsql
as $$
begin
  if p_condition is not true then
    raise exception 'FIRM LOGO FAIL: %', p_message;
  end if;
end;
$$;

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

create or replace function pg_temp.as_owner()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', '', true);
  execute 'reset role';
end;
$$;

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

create or replace function pg_temp.raises_as(p_user uuid, p_sql text, p_message text)
returns void
language plpgsql
as $$
begin
  perform pg_temp.as_user('authenticated', p_user);
  begin
    execute p_sql;
  exception
    when others then
      perform pg_temp.as_owner();
      if position(p_message in sqlerrm) = 0 then
        raise exception 'FIRM LOGO FAIL: expected an error mentioning %, got: %',
          p_message, sqlerrm;
      end if;
      return;
  end;
  perform pg_temp.as_owner();
  raise exception
    'FIRM LOGO FAIL: expected an error mentioning %, but the statement succeeded',
    p_message;
end;
$$;

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

do $$
declare
  c_owner uuid := pg_temp.sign_up('firm-logo-owner@test.local');
  c_member uuid := pg_temp.sign_up('firm-logo-member@test.local');
  c_other_owner uuid := pg_temp.sign_up('firm-logo-other@test.local');
  v_firm uuid := gen_random_uuid();
  v_other_firm uuid := gen_random_uuid();
  v_object_id uuid;
  v_path text;
  v_rows bigint;
  v_path_after text;
  v_version_after integer;
begin
  -- The chamber's plan is live; the owner is covered through the chamber.
  insert into public.firms (id, name, owner_id, subscription_status, subscription_expiry, tier)
  values (v_firm, 'Logo Chamber', c_owner, 'premium', now() + interval '30 days', 'firm');

  update public.profiles
     set firm_id = v_firm, role = 'owner', subscription_status = 'premium',
         subscription_expiry = now() + interval '30 days'
   where id = c_owner;

  update public.profiles
     set firm_id = v_firm, role = 'associate'
   where id = c_member;

  -- Another chamber, for the "not your object" check.
  insert into public.firms (id, name, owner_id, subscription_status, subscription_expiry, tier)
  values (v_other_firm, 'Other Logo Chamber', c_other_owner, 'premium',
           now() + interval '30 days', 'firm');

  update public.profiles
     set firm_id = v_other_firm, role = 'owner', subscription_status = 'premium',
         subscription_expiry = now() + interval '30 days'
   where id = c_other_owner;

  v_path := v_firm::text || '.jpg';

  -- -------------------------------------------------------------------------
  -- The bucket's contract.
  -- -------------------------------------------------------------------------

  perform pg_temp.assert_true(
    exists (
      select 1 from storage.buckets b
       where b.id = 'firm-avatars'
         and b.public = false
         and b.file_size_limit = 51200
         and b.allowed_mime_types = array['image/jpeg']
    ),
    'the firm-avatars bucket is private, 50 KB and JPEG only'
  );

  perform pg_temp.assert_true(
    exists (
      select 1 from information_schema.columns
       where table_schema = 'public' and table_name = 'firms'
         and column_name = 'logo_path'
    )
    and exists (
      select 1 from information_schema.columns
       where table_schema = 'public' and table_name = 'firms'
         and column_name = 'logo_version'
    ),
    'firms carries logo_path and logo_version'
  );

  perform pg_temp.assert_true(
    not has_column_privilege('authenticated', 'public.firms', 'logo_path', 'UPDATE')
    and not has_column_privilege('authenticated', 'public.firms', 'logo_version', 'UPDATE'),
    'a client cannot write the logo fields'
  );

  -- -------------------------------------------------------------------------
  -- The trigger, exercised as the migration's own role (RLS bypassed).
  -- -------------------------------------------------------------------------

  insert into storage.objects (id, bucket_id, name, owner, created_at, updated_at)
  values (gen_random_uuid(), 'firm-avatars', v_path, c_owner, now(), now())
  returning id into v_object_id;

  select logo_path, logo_version into v_path_after, v_version_after
    from public.firms where id = v_firm;
  perform pg_temp.assert_true(
    v_path_after = v_path and v_version_after = 1,
    'an insert stamps the path and bumps the version'
  );

  update storage.objects set updated_at = now() where id = v_object_id;
  select logo_version into v_version_after from public.firms where id = v_firm;
  perform pg_temp.assert_true(v_version_after = 2, 'a replace bumps the version');

  delete from storage.objects where id = v_object_id;
  select logo_path, logo_version into v_path_after, v_version_after
    from public.firms where id = v_firm;
  perform pg_temp.assert_true(
    v_path_after is null and v_version_after = 3,
    'a delete clears the path and bumps the version'
  );

  -- -------------------------------------------------------------------------
  -- The policies, as the clients that will call them.
  -- -------------------------------------------------------------------------

  -- A stored logo, made as the owner: the row must exist for the read tests.
  insert into storage.objects (id, bucket_id, name, owner, created_at, updated_at)
  values (gen_random_uuid(), 'firm-avatars', v_path, c_owner, now(), now())
  returning id into v_object_id;

  v_rows := pg_temp.rows_as(
    c_member,
    format('select 1 from storage.objects where bucket_id = %L and name = %L',
           'firm-avatars', v_path)
  );
  perform pg_temp.assert_true(v_rows = 1, 'a member can read the chamber logo');

  v_rows := pg_temp.rows_as(
    pg_temp.sign_up('firm-logo-outsider@test.local'),
    format('select 1 from storage.objects where bucket_id = %L and name = %L',
           'firm-avatars', v_path)
  );
  perform pg_temp.assert_true(v_rows = 0, 'an outsider cannot read it');

  -- The member is not the owner: even a valid name is refused.
  perform pg_temp.raises_as(
    c_member,
    format(
      'insert into storage.objects (id, bucket_id, name, owner, created_at, updated_at) values (%L, %L, %L, %L, now(), now())',
      gen_random_uuid()::text, 'firm-avatars', v_path, c_member::text
    ),
    'row-level security'
  );

  -- Another chamber's owner cannot write this chamber's object.
  perform pg_temp.raises_as(
    c_other_owner,
    format(
      'insert into storage.objects (id, bucket_id, name, owner, created_at, updated_at) values (%L, %L, %L, %L, now(), now())',
      gen_random_uuid()::text, 'firm-avatars', v_path, c_other_owner::text
    ),
    'row-level security'
  );

  -- Delete the row as the session role, then prove the owner may create it.
  delete from storage.objects where id = v_object_id;

  v_rows := pg_temp.rows_as(
    c_owner,
    format(
      'insert into storage.objects (id, bucket_id, name, owner, created_at, updated_at) values (%L, %L, %L, %L, now(), now())',
      gen_random_uuid()::text, 'firm-avatars', v_path, c_owner::text
    )
  );
  perform pg_temp.assert_true(v_rows = 1, 'a live owner may upload');

  -- The chamber lapses: the same owner may no longer write.
  update public.firms
     set subscription_expiry = now() - interval '3 days'
   where id = v_firm;

  perform pg_temp.raises_as(
    c_owner,
    format('update storage.objects set updated_at = now() where name = %L', v_path),
    'row-level security'
  );

  -- ... but can still remove the logo.
  v_rows := pg_temp.rows_as(
    c_owner,
    format('delete from storage.objects where bucket_id = %L and name = %L',
           'firm-avatars', v_path)
  );
  perform pg_temp.assert_true(v_rows = 1, 'a lapsed owner may remove the logo');

  perform pg_temp.assert_true(
    (select logo_path is null from public.firms where id = v_firm),
    'the delete cleared the path'
  );
end;
$$;

rollback;

select 'FIRM LOGO OK' as result;
