-- Smoke test — admin_list_unconfirmed_accounts() / admin_delete_unconfirmed_account().
--
-- Usage (self-contained: it creates its own auth users, and rolls back):
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
--     -f supabase/tests/admin_unconfirmed_accounts_test.sql
--
-- One transaction, rolled back at the end, so no account, court or admin row
-- survives. It exercises the contract the Admin Panel's **Non-verified Accounts**
-- page depends on: the list is admin-only, it returns only never-confirmed
-- accounts that have sat that way for **over 72 hours** (newest first, with their
-- profile's name/email), a fresh sign-up is neither listed nor deletable
-- (`too_recent`), `can_delete` is true only for an account that has done nothing,
-- deleting refuses a confirmed or used account, an unknown id is refused as
-- not_found, and a genuinely abandoned sign-up is removed with no residue.
--
-- Every check raises "SMOKE FAIL: ...", so ON_ERROR_STOP turns a failure into a
-- non-zero exit.

begin;

-- ---------------------------------------------------------------------------
-- Tiny assertion helpers
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

create or replace function pg_temp.assert_raises(p_sql text, p_contains text)
returns void
language plpgsql
as $$
begin
  begin
    execute p_sql;
  exception when others then
    if position(p_contains in sqlerrm) > 0 then
      return;
    end if;
    raise exception 'SMOKE FAIL: raised "%", expected "%"', sqlerrm, p_contains;
  end;
  raise exception 'SMOKE FAIL: % did not raise', p_sql;
end;
$$;

-- Runs one scalar select as a bare statement (used to read a jsonb function's
-- answer through EXECUTE).
create or replace function pg_temp.scalar(p_sql text)
returns text
language plpgsql
as $$
declare v_out text;
begin
  execute p_sql into v_out;
  return v_out;
end;
$$;

do $$
declare
  c_admin constant uuid := gen_random_uuid();
  c_plain constant uuid := gen_random_uuid();
  c_waiting uuid := gen_random_uuid();
  c_fresh uuid := gen_random_uuid();
  c_confirmed uuid := gen_random_uuid();
  c_used uuid := gen_random_uuid();
  v_category text;
  v_out jsonb;
  v_str text;
begin
  if to_regprocedure('public.admin_list_unconfirmed_accounts()') is null then
    raise exception
      'SMOKE FAIL: public.admin_list_unconfirmed_accounts() does not exist';
  end if;
  if to_regprocedure(
       'public.admin_delete_unconfirmed_account(uuid)'
     ) is null then
    raise exception
      'SMOKE FAIL: public.admin_delete_unconfirmed_account(uuid) does not exist';
  end if;

  -- Three unconfirmed accounts that are past the 72-hour window (one of which
  -- has done something), one unconfirmed account that is **inside** it, and one
  -- confirmed account that must never appear in the list. The ages are chosen so
  -- the two the page lists still differ in order (the four-day-old account leads
  -- the five-day-old one read newest-first, so `c_used` older than `c_waiting`
  -- would invert the check), and so the fresh one sits well on the hidden side of
  -- the horizon whatever clock the project runs on.
  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  )
  values
    (c_used, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'smoke-admin-used@example.test',
     extensions.crypt('x', extensions.gen_salt('bf')), null,
     now() - interval '4 days', now()),
    (c_waiting, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'smoke-admin-waiting@example.test',
     extensions.crypt('x', extensions.gen_salt('bf')), null,
     now() - interval '5 days', now()),
    (c_fresh, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'smoke-admin-fresh@example.test',
     extensions.crypt('x', extensions.gen_salt('bf')), null,
     now() - interval '1 hour', now()),
    (c_confirmed, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'smoke-admin-confirmed@example.test',
     extensions.crypt('x', extensions.gen_salt('bf')), now(), now(), now());

  -- The account that has done something: one court of its own.
  select c.id into v_category from public.court_categories c order by c.id limit 1;
  insert into public.courts (
    id, court_name, higher_lower_courts, court_category_id, user_id, updated_at
  )
  values (
    'smoke-admin-court', 'Smoke Admin Court', 'Lower Court', v_category,
    c_used, 0
  );

  -- A caller who is not an administrator is refused, whatever the role says.
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', c_plain, 'role', 'authenticated')::text,
    true
  );
  set local role authenticated;
  perform pg_temp.assert_raises(
    'select public.admin_list_unconfirmed_accounts()', 'admin_required'
  );
  perform pg_temp.assert_raises(
    format(
      'select public.admin_delete_unconfirmed_account(%L::uuid)', c_waiting
    ),
    'admin_required'
  );
  reset role;

  -- Now as an administrator. `app_admins.user_id` references `auth.users`, so
  -- the administrator is a real (confirmed) account of its own.
  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  )
  values (
    c_admin, '00000000-0000-0000-0000-000000000000', 'authenticated',
    'authenticated', 'smoke-admin-admin@example.test',
    extensions.crypt('x', extensions.gen_salt('bf')), now(), now(), now()
  );
  insert into public.app_admins (user_id) values (c_admin)
  on conflict (user_id) do nothing;
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', c_admin, 'role', 'authenticated')::text,
    true
  );
  set local role authenticated;

  -- 1. The list holds the two unconfirmed accounts and not the confirmed one,
  --    newest first, each carrying its profile's identity.
  --
  --    Everything here is asserted **about the fixtures**, never about the
  --    length of the whole answer: this runs against a live project, which may
  --    hold other never-confirmed sign-ups — the very thing the page exists to
  --    show — so a total count would fail on data the test does not own.
  v_str := pg_temp.scalar('select public.admin_list_unconfirmed_accounts()::text');
  v_out := v_str::jsonb;
  perform pg_temp.assert_true(
    exists (
      select 1 from jsonb_array_elements(v_out) e
       where e->>'id' = c_waiting::text
    ),
    'an unconfirmed account past the 72-hour window is listed'
  );
  perform pg_temp.assert_true(
    not exists (
      select 1 from jsonb_array_elements(v_out) e
       where e->>'id' = c_fresh::text
    ),
    'a sign-up inside the 72-hour window is not listed'
  );
  perform pg_temp.assert_true(
    not exists (
      select 1 from jsonb_array_elements(v_out) e
       where e->>'id' = c_confirmed::text
    ),
    'a confirmed account is never listed'
  );
  perform pg_temp.assert_true(
    (select count(*) from jsonb_array_elements(v_out) e
      where e->>'id' = c_used::text) = 1,
    'an unconfirmed account with work is still listed'
  );
  -- Newest first, checked among the fixtures rather than at the head of the
  -- answer: the four-day-old account must come before the five-day-old one.
  perform pg_temp.assert_true(
    (
      select e_used.idx < e_waiting.idx
        from (select idx from jsonb_array_elements(v_out) with ordinality as t(e, idx)
               where e->>'id' = c_used::text) e_used,
             (select idx from jsonb_array_elements(v_out) with ordinality as t(e, idx)
               where e->>'id' = c_waiting::text) e_waiting
    ),
    'newest first: the four-day-old account leads the five-day-old one'
  );
  perform pg_temp.assert_true(
    exists (
      select 1 from jsonb_array_elements(v_out) e
       where e->>'id' = c_waiting::text
         and e->>'email' = 'smoke-admin-waiting@example.test'
    ),
    'a listed account carries its address'
  );

  -- 2. can_delete separates the abandoned sign-up from the one with work.
  perform pg_temp.assert_true(
    exists (
      select 1 from jsonb_array_elements(v_out) e
       where e->>'id' = c_waiting::text and (e->>'can_delete')::boolean
    ),
    'an account that has done nothing may be deleted'
  );
  perform pg_temp.assert_true(
    exists (
      select 1 from jsonb_array_elements(v_out) e
       where e->>'id' = c_used::text and not (e->>'can_delete')::boolean
    ),
    'an account with work may not be deleted'
  );

  -- 3. Deleting refuses a confirmed account and an account with work.
  v_str := pg_temp.scalar(
    format('select public.admin_delete_unconfirmed_account(%L::uuid)::text',
           c_confirmed)
  );
  perform pg_temp.assert_true(
    (v_str::jsonb)->>'reason' = 'confirmed',
    'a confirmed account is refused as confirmed'
  );
  v_str := pg_temp.scalar(
    format('select public.admin_delete_unconfirmed_account(%L::uuid)::text',
           c_used)
  );
  perform pg_temp.assert_true(
    (v_str::jsonb)->>'reason' = 'has_activity',
    'an account with work is refused as having activity'
  );
  -- `auth.users` is readable by the owner, not by `authenticated`, so the
  -- proof that nothing was removed is taken as the owner.
  reset role;
  perform pg_temp.assert_true(
    exists (select 1 from auth.users u where u.id = c_used),
    'the refused account stays'
  );
  set local role authenticated;

  -- 4. An unknown id is refused.
  v_str := pg_temp.scalar(
    format('select public.admin_delete_unconfirmed_account(%L::uuid)::text',
           gen_random_uuid())
  );
  perform pg_temp.assert_true(
    (v_str::jsonb)->>'reason' = 'not_found',
    'an unknown account is refused as not_found'
  );

  -- 4b. A sign-up inside the 72-hour window is refused as too_recent — its own
  --     reason, not has_activity: it has done nothing, it is simply young. The
  --     window the list hides it behind is enforced on the delete too.
  v_str := pg_temp.scalar(
    format('select public.admin_delete_unconfirmed_account(%L::uuid)::text',
           c_fresh)
  );
  perform pg_temp.assert_true(
    (v_str::jsonb)->>'reason' = 'too_recent',
    'a sign-up inside the 72-hour window is refused as too_recent'
  );
  reset role;
  perform pg_temp.assert_true(
    exists (select 1 from auth.users u where u.id = c_fresh),
    'the too-recent account stays'
  );
  set local role authenticated;

  -- 5. The abandoned sign-up is removed, with no residue.
  v_str := pg_temp.scalar(
    format('select public.admin_delete_unconfirmed_account(%L::uuid)::text',
           c_waiting)
  );
  perform pg_temp.assert_true(
    (v_str::jsonb)->>'status' = 'removed', 'an abandoned sign-up is removed'
  );

  -- The list is asked as the administrator (it is admin-gated)…
  v_str := pg_temp.scalar('select public.admin_list_unconfirmed_accounts()::text');
  perform pg_temp.assert_true(
    not exists (
      select 1 from jsonb_array_elements(v_str::jsonb) e
       where e->>'id' = c_waiting::text
    ),
    'the removed sign-up is no longer listed'
  );

  -- …and the residue is checked as the owner, which is the role that may read
  -- `auth.users`.
  reset role;
  perform pg_temp.assert_true(
    not exists (select 1 from auth.users u where u.id = c_waiting),
    'the account is gone'
  );
  perform pg_temp.assert_true(
    not exists (select 1 from public.profiles p where p.id = c_waiting),
    'the cascade removed its profile'
  );
end;
$$;

rollback;
