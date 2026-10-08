-- Smoke test — discard_unconfirmed_signup(email, password).
--
-- Usage (self-contained: it creates its own auth users, and rolls back):
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
--     -f supabase/tests/discard_unconfirmed_signup_test.sql
--
-- One transaction, rolled back at the end, so no account, court or rate-limit
-- row survives. It exercises the contract the Check Your Email screen's
-- **Change Email Address** depends on: only the account's own password can
-- remove it, an address that is already confirmed is refused as such, an account
-- that has done something is refused, a waiting sign-up is removed with no
-- residue and its address freed, the rolling limit stops a sixth attempt, and
-- `anon` may call it at all — that caller is the reason the function exists,
-- since an unconfirmed account has no session to have.
--
-- Every check raises "SMOKE FAIL: ...", so ON_ERROR_STOP turns a failure into a
-- non-zero exit.

begin;

-- ---------------------------------------------------------------------------
-- Tiny assertion helper
-- ---------------------------------------------------------------------------

create or replace function pg_temp.assert_true(p_condition boolean, p_message text)
returns void
language plpgsql
as $$
begin
  if p_condition is not true then
    raise exception 'SMOKE FAIL: %', p_message;
  end if;
end;
$$;

do $$
declare
  c_pw constant text := 'discard-secret-123';
  v_pending uuid := gen_random_uuid();
  v_wrong uuid := gen_random_uuid();
  v_confirmed uuid := gen_random_uuid();
  v_used uuid := gen_random_uuid();
  v_category text;
  v_courts_before bigint;
  v_courts_after bigint;
  v_out jsonb;
  v_i int;
begin
  if to_regprocedure('public.discard_unconfirmed_signup(text, text)') is null then
    raise exception
      'SMOKE FAIL: public.discard_unconfirmed_signup(text, text) does not exist';
  end if;

  select count(*) into v_courts_before from public.courts;

  -- Four accounts, each for one way the call can end. The passwords are real
  -- bcrypt hashes (`$2a$`) — the same shape GoTrue stores — so the proof under
  -- test is the production one.
  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  )
  values
    (v_pending, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'smoke-discard-pending@example.test',
     extensions.crypt(c_pw, extensions.gen_salt('bf')), null, now(), now()),
    (v_wrong, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'smoke-discard-wrong@example.test',
     extensions.crypt(c_pw, extensions.gen_salt('bf')), null, now(), now()),
    (v_confirmed, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'smoke-discard-confirmed@example.test',
     extensions.crypt(c_pw, extensions.gen_salt('bf')), now(), now(), now()),
    (v_used, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'smoke-discard-used@example.test',
     extensions.crypt(c_pw, extensions.gen_salt('bf')), null, now(), now());

  -- The sign-up trigger creates one profile per new auth user.
  perform pg_temp.assert_true(
    (select count(*)
       from public.profiles p
      where p.id in (v_pending, v_wrong, v_confirmed, v_used)) = 4,
    'the sign-up trigger created a profile for each fixture'
  );

  -- The account that has done something: one court of its own.
  select c.id into v_category from public.court_categories c order by c.id limit 1;
  insert into public.courts (
    id, court_name, higher_lower_courts, court_category_id, user_id, updated_at
  )
  values (
    'smoke-discard-court', 'Smoke Discard Court', 'Lower Court', v_category,
    v_used, 0
  );

  -- 1. A wrong password is refused, and nothing is removed.
  v_out := public.discard_unconfirmed_signup(
    'smoke-discard-wrong@example.test', 'not-the-password'
  );
  perform pg_temp.assert_true(
    v_out->>'status' = 'refused', 'a wrong password is refused'
  );
  perform pg_temp.assert_true(
    v_out->>'reason' = 'not_provisional',
    'a wrong password is answered like any other refusal'
  );
  perform pg_temp.assert_true(
    exists (select 1 from auth.users u where u.id = v_wrong),
    'a refused proof removes nothing'
  );

  -- 2. An address that is already confirmed is refused, and named as such.
  v_out := public.discard_unconfirmed_signup(
    'smoke-discard-confirmed@example.test', c_pw
  );
  perform pg_temp.assert_true(
    v_out->>'reason' = 'confirmed',
    'a confirmed address is refused as confirmed'
  );
  perform pg_temp.assert_true(
    exists (select 1 from auth.users u where u.id = v_confirmed),
    'the confirmed account stays'
  );

  -- 3. An account that has done something is refused, and keeps it.
  v_out := public.discard_unconfirmed_signup(
    'smoke-discard-used@example.test', c_pw
  );
  perform pg_temp.assert_true(
    v_out->>'status' = 'refused', 'an account with work is refused'
  );
  perform pg_temp.assert_true(
    v_out->>'reason' = 'not_provisional', 'the work refusal says not_provisional'
  );
  perform pg_temp.assert_true(
    exists (select 1 from public.courts c where c.user_id = v_used),
    'the account with work keeps its row'
  );

  -- 4. The real thing: an unconfirmed, empty account goes, and takes everything
  --    with it.
  v_out := public.discard_unconfirmed_signup(
    'smoke-discard-pending@example.test', c_pw
  );
  perform pg_temp.assert_true(
    v_out->>'status' = 'removed', 'the waiting sign-up is removed'
  );
  perform pg_temp.assert_true(
    not exists (select 1 from auth.users u where u.id = v_pending),
    'the account row is gone'
  );
  perform pg_temp.assert_true(
    not exists (select 1 from public.profiles p where p.id = v_pending),
    'its profile cascaded away'
  );
  perform pg_temp.assert_true(
    not exists (select 1 from public.user_preferences p where p.user_id = v_pending),
    'its preferences cascaded away'
  );
  perform pg_temp.assert_true(
    not exists (
      select 1 from public.signup_discard_attempts a
       where a.email = 'smoke-discard-pending@example.test'
    ),
    'a success forgets the attempts it took'
  );
  perform pg_temp.assert_true(
    not exists (
      select 1 from auth.users u
       where lower(u.email) = 'smoke-discard-pending@example.test'
    ),
    'the address can be registered again'
  );

  -- 5. The rolling limit: five failures fill the window, and the sixth call is
  --    refused before any proof is even looked at — with the right password.
  for v_i in 1..5 loop
    v_out := public.discard_unconfirmed_signup(
      'smoke-discard-rate@example.test', 'wrong'
    );
    perform pg_temp.assert_true(
      v_out->>'status' = 'refused',
      'a failed proof is refused while the window fills'
    );
  end loop;
  v_out := public.discard_unconfirmed_signup(
    'smoke-discard-rate@example.test', c_pw
  );
  perform pg_temp.assert_true(
    v_out->>'status' = 'rate_limited',
    'the sixth attempt inside the window is rate-limited'
  );

  -- 6. Nothing else moved: the seeded reference data is exactly as it was, plus
  --    the one court this fixture added.
  select count(*) into v_courts_after from public.courts;
  perform pg_temp.assert_true(
    v_courts_after = v_courts_before + 1,
    'only the fixture court was added to the reference data'
  );
  perform pg_temp.assert_true(
    v_courts_before > 1000, 'the seeded courts were there to begin with'
  );
end;
$$;

-- The account the `anon` call below removes. It has to exist before the role
-- changes: creating an auth user is not something `anon` may do.
do $$
begin
  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  )
  values (
    gen_random_uuid(), '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 'smoke-discard-anon@example.test',
    extensions.crypt('discard-secret-123', extensions.gen_salt('bf')),
    null, now(), now()
  );
end;
$$;

-- `anon` may call it. This is the caller the function exists for — the user
-- whose sign-up is waiting has no session at all — so a missing grant would make
-- the whole path unusable in production while every check above still passed.
set local role anon;

do $$
declare
  v_out jsonb;
begin
  v_out := public.discard_unconfirmed_signup(
    'smoke-discard-anon@example.test', 'discard-secret-123'
  );
  perform pg_temp.assert_true(
    v_out->>'status' = 'removed', 'anon can remove a waiting sign-up'
  );
end;
$$;

reset role;

rollback;
