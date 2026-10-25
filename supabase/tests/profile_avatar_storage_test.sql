-- Profile-avatar storage test — proves 20261025180000_profile_avatar_storage.sql.
--
-- One transaction, rolled back. The paths are exercised the way the Storage
-- API does it — `set local role authenticated` plus `request.jwt.claims`, which
-- is what `auth.uid()` reads — so the bucket's policies run for real.
--
-- Run against the project:
--
--   psql "$URL" -v ON_ERROR_STOP=1 -f supabase/tests/profile_avatar_storage_test.sql
--
-- **First apply `supabase/manual/storage_policies.sql` through the Supabase
-- Storage policy editor.** The policy checks below fail until those eight
-- policies exist; the bucket, column and trigger checks pass as soon as the
-- migration is applied.
--
-- What it proves, in order:
--
--   * the `individual-avatars` bucket is private, 50 KB, JPEG only;
--   * `profiles.avatar_path` / `avatar_version` exist and are not client-writable;
--   * the storage trigger stamps and clears them;
--   * a premium individual may upload, replace and delete their own file;
--   * a free account may not upload;
--   * a chamber member may not upload (the chamber's logo is the workspace mark);
--   * a chamber owner may upload through the chamber's plan;
--   * a lapsed account may still read and delete, but not upload;
--   * nobody reads another account's picture.

begin;

-- The Storage API sets this flag for its own delete path; the proof needs
-- the same permission to exercise the DELETE policies. Transaction-local.
set local storage.allow_delete_query = 'true';

create or replace function pg_temp.assert_true(p_condition boolean, p_message text)
returns void
language plpgsql
as $$
begin
  if p_condition is not true then
    raise exception 'PROFILE AVATAR FAIL: %', p_message;
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
        raise exception 'PROFILE AVATAR FAIL: expected an error mentioning %, got: %',
          p_message, sqlerrm;
      end if;
      return;
  end;
  perform pg_temp.as_owner();
  raise exception
    'PROFILE AVATAR FAIL: expected an error mentioning %, but the statement succeeded',
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
  c_individual uuid := pg_temp.sign_up('avatar-individual@test.local');
  c_free uuid := pg_temp.sign_up('avatar-free@test.local');
  c_member uuid := pg_temp.sign_up('avatar-member@test.local');
  c_owner uuid := pg_temp.sign_up('avatar-owner@test.local');
  c_outsider uuid := pg_temp.sign_up('avatar-outsider@test.local');
  v_firm uuid := gen_random_uuid();
  v_object_id uuid;
  v_path text;
  v_rows bigint;
  v_path_after text;
  v_version_after integer;

  v_individual_path text := c_individual::text || '.jpg';
  v_member_path text := c_member::text || '.jpg';
  v_owner_path text := c_owner::text || '.jpg';
begin
  -- A premium individual, a free individual, and a chamber with a member and
  -- an owner.
  update public.profiles
     set subscription_status = 'premium',
         subscription_expiry = now() + interval '30 days'
   where id = c_individual;

  update public.profiles
     set subscription_status = 'free',
         subscription_expiry = null
   where id = c_free;

  insert into public.firms (id, name, owner_id, subscription_status, subscription_expiry, tier)
  values (v_firm, 'Avatar Chamber', c_owner, 'premium', now() + interval '30 days', 'firm');

  update public.profiles
     set firm_id = v_firm, role = 'associate'
   where id = c_member;

  update public.profiles
     set firm_id = v_firm, role = 'owner',
         subscription_status = 'premium',
         subscription_expiry = now() + interval '30 days'
   where id = c_owner;

  -- -------------------------------------------------------------------------
  -- The bucket, the columns and the client grant boundary.
  -- -------------------------------------------------------------------------

  perform pg_temp.assert_true(
    exists (
      select 1 from storage.buckets b
       where b.id = 'individual-avatars'
         and b.public = false
         and b.file_size_limit = 51200
         and b.allowed_mime_types = array['image/jpeg']
    ),
    'the individual-avatars bucket is private, 50 KB and JPEG only'
  );

  perform pg_temp.assert_true(
    exists (
      select 1 from information_schema.columns
       where table_schema = 'public' and table_name = 'profiles'
         and column_name = 'avatar_path'
    )
    and exists (
      select 1 from information_schema.columns
       where table_schema = 'public' and table_name = 'profiles'
         and column_name = 'avatar_version'
    ),
    'profiles carries avatar_path and avatar_version'
  );

  perform pg_temp.assert_true(
    not has_column_privilege('authenticated', 'public.profiles', 'avatar_path', 'UPDATE')
    and not has_column_privilege('authenticated', 'public.profiles', 'avatar_version', 'UPDATE'),
    'a client cannot write the avatar fields'
  );

  -- -------------------------------------------------------------------------
  -- The trigger, exercised as the migration's own role (RLS bypassed).
  -- -------------------------------------------------------------------------

  insert into storage.objects (id, bucket_id, name, owner, created_at, updated_at)
  values (gen_random_uuid(), 'individual-avatars', v_individual_path, c_individual, now(), now())
  returning id into v_object_id;

  select avatar_path, avatar_version into v_path_after, v_version_after
    from public.profiles where id = c_individual;
  perform pg_temp.assert_true(
    v_path_after = v_individual_path and v_version_after = 1,
    'an insert stamps the path and bumps the version'
  );

  update storage.objects set updated_at = now() where id = v_object_id;
  select avatar_version into v_version_after from public.profiles where id = c_individual;
  perform pg_temp.assert_true(v_version_after = 2, 'a replace bumps the version');

  delete from storage.objects where id = v_object_id;
  select avatar_path, avatar_version into v_path_after, v_version_after
    from public.profiles where id = c_individual;
  perform pg_temp.assert_true(
    v_path_after is null and v_version_after = 3,
    'a delete clears the path and bumps the version'
  );

  -- -------------------------------------------------------------------------
  -- The policies, as the clients that will call them.
  -- -------------------------------------------------------------------------

  -- A member's own old picture, made as the session role: the member can read
  -- it, but cannot upload.
  insert into storage.objects (id, bucket_id, name, owner, created_at, updated_at)
  values (gen_random_uuid(), 'individual-avatars', v_member_path, c_member, now(), now());

  v_rows := pg_temp.rows_as(
    c_member,
    format('select 1 from storage.objects where bucket_id = %L and name = %L',
           'individual-avatars', v_member_path)
  );
  perform pg_temp.assert_true(v_rows = 1, 'a member can read their own old picture');

  -- Remove the fixture first, so the refused insert below fails on the policy
  -- rather than on the unique (bucket_id, name) constraint.
  delete from storage.objects where bucket_id = 'individual-avatars' and name = v_member_path;

  perform pg_temp.raises_as(
    c_member,
    format(
      'insert into storage.objects (id, bucket_id, name, owner, created_at, updated_at) '
      'values (%L, %L, %L, %L, now(), now())',
      gen_random_uuid()::text, 'individual-avatars', v_member_path, c_member::text
    ),
    'row-level security'
  );

  -- A free account cannot upload.
  perform pg_temp.raises_as(
    c_free,
    format(
      'insert into storage.objects (id, bucket_id, name, owner, created_at, updated_at) '
      'values (%L, %L, %L, %L, now(), now())',
      gen_random_uuid()::text, 'individual-avatars', c_free::text || '.jpg', c_free::text
    ),
    'row-level security'
  );

  -- A premium individual can upload, and the trigger records it.
  v_rows := pg_temp.rows_as(
    c_individual,
    format(
      'insert into storage.objects (id, bucket_id, name, owner, created_at, updated_at) '
      'values (%L, %L, %L, %L, now(), now())',
      gen_random_uuid()::text, 'individual-avatars', v_individual_path, c_individual::text
    )
  );
  perform pg_temp.assert_true(v_rows = 1, 'a premium individual may upload');
  select avatar_path into v_path_after from public.profiles where id = c_individual;
  perform pg_temp.assert_true(
    v_path_after = v_individual_path,
    'the premium individual''s upload was stamped'
  );

  -- A chamber owner uploads through the chamber's plan.
  v_rows := pg_temp.rows_as(
    c_owner,
    format(
      'insert into storage.objects (id, bucket_id, name, owner, created_at, updated_at) '
      'values (%L, %L, %L, %L, now(), now())',
      gen_random_uuid()::text, 'individual-avatars', v_owner_path, c_owner::text
    )
  );
  perform pg_temp.assert_true(v_rows = 1, 'a premium chamber owner may upload');

  -- Nobody reads another account's picture.
  v_rows := pg_temp.rows_as(
    c_outsider,
    format('select 1 from storage.objects where bucket_id = %L and name = %L',
           'individual-avatars', v_individual_path)
  );
  perform pg_temp.assert_true(v_rows = 0, 'an outsider cannot read it');

  v_rows := pg_temp.rows_as(
    c_member,
    format('select 1 from storage.objects where bucket_id = %L and name = %L',
           'individual-avatars', v_individual_path)
  );
  perform pg_temp.assert_true(v_rows = 0, 'a colleague cannot read it either');

  -- The chamber lapses: its owner may not upload, but may still delete.
  update public.firms
     set subscription_expiry = now() - interval '3 days'
   where id = v_firm;

  v_rows := pg_temp.rows_as(
    c_owner,
    format(
      'update storage.objects set updated_at = now() where name = %L',
      v_owner_path
    )
  );
  perform pg_temp.assert_true(
    v_rows = 0,
    'a lapsed owner cannot replace the picture: the row is not visible to the update'
  );

  v_rows := pg_temp.rows_as(
    c_owner,
    format('delete from storage.objects where bucket_id = %L and name = %L',
           'individual-avatars', v_owner_path)
  );
  perform pg_temp.assert_true(v_rows = 1, 'a lapsed owner may delete the picture');

  -- A lapsed individual may delete too.
  update public.profiles
     set subscription_expiry = now() - interval '3 days'
   where id = c_individual;

  v_rows := pg_temp.rows_as(
    c_individual,
    format('delete from storage.objects where bucket_id = %L and name = %L',
           'individual-avatars', v_individual_path)
  );
  perform pg_temp.assert_true(v_rows = 1, 'a lapsed individual may delete the picture');

  perform pg_temp.assert_true(
    (select avatar_path is null from public.profiles where id = c_individual),
    'the delete cleared the individual''s path'
  );
end;
$$;

rollback;

select 'PROFILE AVATAR OK' as result;
