-- Smoke test — admin_list_verified_accounts().
--
-- Usage (self-contained: it creates its own auth users, and rolls back):
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
--     -f supabase/tests/admin_active_users_test.sql
--
-- One transaction, rolled back at the end, so no account, case, device, payment
-- or admin row survives. It proves the contract the Admin Panel's **Active
-- Users** page depends on: the query is admin-only; it lists confirmed accounts
-- and not unconfirmed ones; it keeps oldest-first order; profile identity wins
-- over auth metadata; Last Active uses the latest heartbeat even from a revoked
-- device; own work counts exclude deleted rows; an individual's plan comes from
-- their profile, while a chamber member takes the chamber's tier, plan and
-- expiry; a newer purchase of a different tier is not the current plan; and the
-- ledger carries at most five newest entries, including cancellations and every
-- purchase status, in newest-first order.
--
-- Fixed fixture ids are safe because everything rolls back. A failed earlier run
-- rolls back with the transaction too, so the same ids cannot survive to collide.
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

-- Runs one scalar select as a bare statement.
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
  c_admin constant uuid := '00000000-0000-0000-0000-00000000a001';
  c_plain constant uuid := '00000000-0000-0000-0000-00000000a002';
  c_individual constant uuid := '00000000-0000-0000-0000-00000000a010';
  c_member constant uuid := '00000000-0000-0000-0000-00000000a011';
  c_owner constant uuid := '00000000-0000-0000-0000-00000000a012';
  c_free constant uuid := '00000000-0000-0000-0000-00000000a013';
  c_unconfirmed constant uuid := '00000000-0000-0000-0000-00000000a014';
  c_firm constant uuid := '00000000-0000-0000-0000-00000000a020';

  v_court text;
  v_on_behalf text;
  v_out jsonb;
  v_individual jsonb;
  v_member jsonb;
  v_free jsonb;
  v_str text;
begin
  if to_regprocedure('public.admin_list_verified_accounts()') is null then
    raise exception
      'SMOKE FAIL: public.admin_list_verified_accounts() does not exist';
  end if;

  -- Structural contract: SECURITY DEFINER, authenticated-only, and no table
  -- read opened to clients by this migration.
  perform pg_temp.assert_true(
    (select p.prosecdef from pg_proc p
      where p.oid = 'public.admin_list_verified_accounts()'::regprocedure),
    'the query is SECURITY DEFINER'
  );
  perform pg_temp.assert_true(
    has_function_privilege(
      'authenticated', 'public.admin_list_verified_accounts()', 'EXECUTE'
    ),
    'authenticated may execute the query'
  );
  perform pg_temp.assert_true(
    not has_function_privilege(
      'anon', 'public.admin_list_verified_accounts()', 'EXECUTE'
    ),
    'anon may not execute the query'
  );
  perform pg_temp.assert_true(
    not has_table_privilege('authenticated', 'auth.users', 'SELECT'),
    'the query does not open auth.users to authenticated'
  );
  perform pg_temp.assert_true(
    not has_table_privilege('authenticated', 'public.user_devices', 'SELECT'),
    'the query does not open user_devices to authenticated'
  );

  -- -------------------------------------------------------------------------
  -- Fixtures
  -- -------------------------------------------------------------------------

  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at, raw_user_meta_data
  )
  values
    (c_individual, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'smoke-active-individual@example.test',
     extensions.crypt('x', extensions.gen_salt('bf')),
     now() - interval '59 days', now() - interval '60 days', now(),
     '{"full_name":"Metadata Name That Must Not Win"}'::jsonb),
    (c_member, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'smoke-active-member@example.test',
     extensions.crypt('x', extensions.gen_salt('bf')),
     now() - interval '29 days', now() - interval '30 days', now(), null),
    (c_owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'smoke-active-owner@example.test',
     extensions.crypt('x', extensions.gen_salt('bf')),
     now() - interval '39 days', now() - interval '40 days', now(), null),
    (c_free, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'smoke-active-free@example.test',
     extensions.crypt('x', extensions.gen_salt('bf')),
     now() - interval '9 days', now() - interval '10 days', now(), null),
    (c_unconfirmed, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'smoke-active-unconfirmed@example.test',
     extensions.crypt('x', extensions.gen_salt('bf')),
     null, now() - interval '90 days', now(), null),
    (c_admin, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'smoke-active-admin@example.test',
     extensions.crypt('x', extensions.gen_salt('bf')),
     now(), now() - interval '1 day', now(), null);

  insert into public.firms (
    id, name, owner_id, subscription_status, subscription_expiry,
    tier, created_at
  )
  values (
    c_firm, 'Smoke Active Chamber', c_owner, 'premium',
    now() + interval '30 days', 'firm', now() - interval '40 days'
  );

  insert into public.profiles (
    id, full_name, email, bar_association, mobile_no, role,
    tier, subscription_status, subscription_expiry, firm_id
  )
  values
    (c_individual, 'Profile Name A', 'profile-a@example.test',
     'Dhaka Bar Association', '01710000001', 'individual',
     'pro', 'premium', now() + interval '20 days', null),
    (c_member, 'Member Name B', 'profile-b@example.test',
     'Chattogram Bar Association', '01710000002', 'associate',
     'pro', 'premium', null, c_firm),
    (c_owner, 'Owner Name C', 'profile-c@example.test',
     'Supreme Court Bar Association', '01710000003', 'owner',
     'firm', 'premium', now() + interval '30 days', c_firm),
    (c_free, 'Free Name E', 'profile-e@example.test',
     '', '', 'individual', 'free', 'free', null, null)
  on conflict (id) do update set
    full_name = excluded.full_name,
    email = excluded.email,
    bar_association = excluded.bar_association,
    mobile_no = excluded.mobile_no,
    role = excluded.role,
    tier = excluded.tier,
    subscription_status = excluded.subscription_status,
    subscription_expiry = excluded.subscription_expiry,
    firm_id = excluded.firm_id;

  -- Work owned by the individual. One row of each kind is deleted and must not
  -- be counted; the other two cases, one note and two references are live.
  select c.id into v_court from public.courts c order by c.id limit 1;
  select o.id into v_on_behalf from public.on_behalfs o order by o.id limit 1;
  if v_court is null or v_on_behalf is null then
    raise exception 'SMOKE FAIL: the built-in courts/on-behalf seed is missing';
  end if;

  insert into public.cases (
    id, user_id, court_id, case_type, case_number, petitioner, respondent,
    on_behalf_id, created_at, updated_at, is_deleted
  )
  values
    ('smoke-active-case-1', c_individual, v_court, 'civil', 'SMOKE-1',
     'Petitioner One', 'Respondent One', v_on_behalf, 1000, 1000, false),
    ('smoke-active-case-2', c_individual, v_court, 'civil', 'SMOKE-2',
     'Petitioner Two', 'Respondent Two', v_on_behalf, 1001, 1001, false),
    ('smoke-active-case-3', c_individual, v_court, 'civil', 'SMOKE-3',
     'Petitioner Three', 'Respondent Three', v_on_behalf, 1002, 1002, true);

  insert into public.notes (
    id, user_id, title, body, created_at, updated_at, is_deleted
  )
  values
    ('smoke-active-note-1', c_individual, 'Live Note', 'Body', 1000, 1000, false),
    ('smoke-active-note-2', c_individual, 'Deleted Note', 'Body', 1001, 1001, true);

  insert into public.case_references (
    id, user_id, reference_and_page_no, statute, created_at, updated_at,
    is_deleted
  )
  values
    ('smoke-active-ref-1', c_individual, '1 Smoke Reference', 'Smoke Act',
     1000, 1000, false),
    ('smoke-active-ref-2', c_individual, '2 Smoke Reference', 'Smoke Act',
     1001, 1001, false),
    ('smoke-active-ref-3', c_individual, '3 Smoke Reference', 'Smoke Act',
     1002, 1002, true);

  -- One active and one revoked device. The revoked device has the newest
  -- heartbeat, so it must win Last Active while the active count stays at one
  -- and the platform list names only Android.
  insert into public.user_devices (
    user_id, session_id, device_key, platform, label, last_seen_at,
    revoked_at, revoked_reason
  )
  values
    (c_individual, '00000000-0000-0000-0000-00000000b001',
     'smoke-active-android', 'android', 'Smoke Android',
     now() - interval '1 hour', null, null),
    (c_individual, '00000000-0000-0000-0000-00000000b002',
     'smoke-active-windows', 'windows', 'Smoke Windows',
     now() - interval '30 minutes', now() - interval '20 minutes', 'user');

  -- Five purchases (the rate limit's ceiling) and two cancellations: six ledger
  -- entries, of which exactly the newest five are returned.
  insert into public.payment_submissions (
    id, user_id, plan_type, amount, mfs_provider, sender_number,
    transaction_id, status, created_at, updated_at
  )
  values
    ('00000000-0000-0000-0000-00000000c001', c_individual,
     'pro_monthly', 1001, 'bkash', '01710000001', 'SMOKE-A-1',
     'approved', 1000, 1000),
    ('00000000-0000-0000-0000-00000000c002', c_individual,
     'pro_quarterly', 1002, 'bkash', '01710000001', 'SMOKE-A-2',
     'approved', 1001, 1001),
    ('00000000-0000-0000-0000-00000000c003', c_individual,
     'pro_annual', 1003, 'bkash', '01710000001', 'SMOKE-A-3',
     'approved', 1002, 1002),
    ('00000000-0000-0000-0000-00000000c004', c_individual,
     'starter_annual', 1004, 'bkash', '01710000001', 'SMOKE-A-4',
     'rejected', 1003, 1003),
    ('00000000-0000-0000-0000-00000000c005', c_individual,
     'starter_monthly', 1005, 'bkash', '01710000001', 'SMOKE-A-5',
     'pending', 1004, 1004),
    -- The chamber owner has an older Firm purchase and a newer Starter purchase.
    -- The newer one is approved but belongs to a different tier, so it is queued
    -- and must not be named as the current plan.
    ('00000000-0000-0000-0000-00000000c006', c_owner,
     'firm_annual', 3001, 'nagad', '01710000003', 'SMOKE-C-1',
     'approved', 1005, 1005),
    ('00000000-0000-0000-0000-00000000c007', c_owner,
     'starter_annual', 3002, 'nagad', '01710000003', 'SMOKE-C-2',
     'approved', 1006, 1006);

  -- The rate-limit trigger stamps every insert with `now()`; move the fixture
  -- times afterwards so ordering is deterministic without exceeding the limit.
  update public.payment_submissions
     set submitted_at = now() - interval '40 days',
         approved_at = now() - interval '39 days'
   where transaction_id = 'SMOKE-A-1';
  update public.payment_submissions
     set submitted_at = now() - interval '30 days',
         approved_at = now() - interval '29 days'
   where transaction_id = 'SMOKE-A-2';
  update public.payment_submissions
     set submitted_at = now() - interval '20 days',
         approved_at = now() - interval '19 days'
   where transaction_id = 'SMOKE-A-3';
  update public.payment_submissions
     set submitted_at = now() - interval '5 days'
   where transaction_id = 'SMOKE-A-4';
  update public.payment_submissions
     set submitted_at = now() - interval '1 day'
   where transaction_id = 'SMOKE-A-5';
  update public.payment_submissions
     set submitted_at = now() - interval '10 days',
         approved_at = now() - interval '9 days'
   where transaction_id = 'SMOKE-C-1';
  update public.payment_submissions
     set submitted_at = now() - interval '3 days',
         approved_at = now() - interval '2 days'
   where transaction_id = 'SMOKE-C-2';

  insert into public.subscription_cancellations (
    user_id, plan_type, amount, previous_expiry, cancelled_at
  )
  values
    (c_individual, 'pro_annual', 2001, now() + interval '20 days',
     now() - interval '3 hours'),
    (c_individual, 'pro_annual', 2002, now() + interval '20 days',
     now() - interval '2 hours');

  insert into public.app_admins (user_id) values (c_admin)
  on conflict (user_id) do nothing;

  -- -------------------------------------------------------------------------
  -- 1. A non-admin is refused, whatever the role says
  -- -------------------------------------------------------------------------

  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', c_plain, 'role', 'authenticated')::text,
    true
  );
  set local role authenticated;
  perform pg_temp.assert_raises(
    'select public.admin_list_verified_accounts()', 'admin_required'
  );
  reset role;

  -- -------------------------------------------------------------------------
  -- 2. The admin gets the list
  -- -------------------------------------------------------------------------

  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', c_admin, 'role', 'authenticated')::text,
    true
  );
  set local role authenticated;

  v_str := pg_temp.scalar(
    'select public.admin_list_verified_accounts()::text'
  );
  v_out := v_str::jsonb;

  perform pg_temp.assert_true(
    jsonb_typeof(v_out) = 'array', 'the answer is a jsonb array'
  );
  perform pg_temp.assert_true(
    exists (
      select 1 from jsonb_array_elements(v_out) e
       where e->>'id' = c_admin::text
    ),
    'the confirmed administrator is listed'
  );
  perform pg_temp.assert_true(
    not exists (
      select 1 from jsonb_array_elements(v_out) e
       where e->>'id' = c_unconfirmed::text
    ),
    'an unconfirmed account is never listed'
  );

  select e into v_individual
    from jsonb_array_elements(v_out) e
   where e->>'id' = c_individual::text;
  select e into v_member
    from jsonb_array_elements(v_out) e
   where e->>'id' = c_member::text;
  select e into v_free
    from jsonb_array_elements(v_out) e
   where e->>'id' = c_free::text;

  perform pg_temp.assert_true(v_individual is not null, 'the individual is listed');
  perform pg_temp.assert_true(v_member is not null, 'the chamber member is listed');
  perform pg_temp.assert_true(v_free is not null, 'the free account is listed');

  -- Oldest first among the fixtures, regardless of other live accounts.
  perform pg_temp.assert_true(
    (select idx from jsonb_array_elements(v_out) with ordinality t(e, idx)
      where e->>'id' = c_individual::text)
    <
    (select idx from jsonb_array_elements(v_out) with ordinality t(e, idx)
      where e->>'id' = c_member::text),
    'the older individual leads the newer member'
  );
  perform pg_temp.assert_true(
    (select idx from jsonb_array_elements(v_out) with ordinality t(e, idx)
      where e->>'id' = c_member::text)
    <
    (select idx from jsonb_array_elements(v_out) with ordinality t(e, idx)
      where e->>'id' = c_free::text),
    'the member leads the newer free account'
  );

  -- -------------------------------------------------------------------------
  -- 3. Identity, activity, work and devices for the individual
  -- -------------------------------------------------------------------------

  perform pg_temp.assert_true(
    v_individual->>'full_name' = 'Profile Name A',
    'the profile full name is used, not auth metadata'
  );
  perform pg_temp.assert_true(
    v_individual->>'bar_association' = 'Dhaka Bar Association',
    'the bar association is returned'
  );
  perform pg_temp.assert_true(
    v_individual->>'email' = 'profile-a@example.test',
    'the profile email is returned'
  );
  perform pg_temp.assert_true(
    v_individual->>'mobile_no' = '01710000001',
    'the mobile number is returned'
  );
  perform pg_temp.assert_true(
    v_individual->>'role' = 'individual'
    and v_individual->>'firm_name' is null,
    'an account without a chamber reads as an individual'
  );
  perform pg_temp.assert_true(
    (v_individual->>'joined_at')::timestamptz
      between now() - interval '61 days' and now() - interval '59 days',
    'the joining instant is the auth account creation time'
  );
  perform pg_temp.assert_true(
    (v_individual->>'last_active_at')::timestamptz
      > now() - interval '45 minutes',
    'Last Active uses the revoked device''s newest heartbeat'
  );
  perform pg_temp.assert_true(
    (v_individual->>'case_count')::int = 2,
    'live cases are counted and deleted cases are excluded'
  );
  perform pg_temp.assert_true(
    (v_individual->>'note_count')::int = 1,
    'live notes are counted and deleted notes are excluded'
  );
  perform pg_temp.assert_true(
    (v_individual->>'reference_count')::int = 2,
    'live references are counted and deleted references are excluded'
  );
  perform pg_temp.assert_true(
    (v_individual->>'device_count')::int = 1,
    'only the active device counts toward Device Count'
  );
  perform pg_temp.assert_true(
    v_individual->'platforms' = '["android"]'::jsonb,
    'the platform list comes from active devices only'
  );

  -- -------------------------------------------------------------------------
  -- 4. The individual's plan and its five-entry ledger
  -- -------------------------------------------------------------------------

  perform pg_temp.assert_true(
    v_individual->>'current_tier' = 'pro',
    'the individual holds their own effective tier'
  );
  perform pg_temp.assert_true(
    (v_individual->>'plan_active')::boolean,
    'a future expiry is active'
  );
  perform pg_temp.assert_true(
    v_individual->>'current_plan_key' = 'pro_annual',
    'the current plan is the newest approved purchase of the tier in force'
  );
  perform pg_temp.assert_true(
    (v_individual->>'plan_expiry')::timestamptz
      between now() + interval '19 days' and now() + interval '21 days',
    'the individual expiry is returned'
  );

  perform pg_temp.assert_true(
    jsonb_array_length(v_individual->'subscription_history') = 5,
    'the ledger is capped at five entries'
  );
  perform pg_temp.assert_true(
    v_individual->'subscription_history'->0->>'status' = 'cancelled'
    and v_individual->'subscription_history'->0->>'amount' = '2002',
    'the newest entry is the newest cancellation'
  );
  perform pg_temp.assert_true(
    v_individual->'subscription_history'->1->>'status' = 'cancelled'
    and v_individual->'subscription_history'->1->>'amount' = '2001',
    'the second entry is the older cancellation'
  );
  perform pg_temp.assert_true(
    v_individual->'subscription_history'->2->>'status' = 'pending'
    and v_individual->'subscription_history'->2->>'amount' = '1005',
    'a pending purchase is ordered by its submission time'
  );
  perform pg_temp.assert_true(
    v_individual->'subscription_history'->3->>'status' = 'rejected'
    and v_individual->'subscription_history'->3->>'amount' = '1004',
    'a rejected purchase is ordered by its submission time'
  );
  perform pg_temp.assert_true(
    v_individual->'subscription_history'->4->>'status' = 'approved'
    and v_individual->'subscription_history'->4->>'amount' = '1003',
    'an approved purchase is ordered by its approval time'
  );
  perform pg_temp.assert_true(
    not exists (
      select 1 from jsonb_array_elements(v_individual->'subscription_history') e
       where e->>'amount' in ('1001', '1002')
    ),
    'the two purchases below the cap are absent'
  );

  -- -------------------------------------------------------------------------
  -- 5. A chamber member reads the chamber's plan, not their own tier
  -- -------------------------------------------------------------------------

  perform pg_temp.assert_true(
    v_member->>'firm_name' = 'Smoke Active Chamber'
    and v_member->>'role' = 'associate',
    'the member carries the chamber name and role'
  );
  perform pg_temp.assert_true(
    v_member->>'current_tier' = 'firm',
    'a member takes the chamber tier, not their own stored tier'
  );
  perform pg_temp.assert_true(
    (v_member->>'plan_active')::boolean,
    'a member is active on the chamber expiry'
  );
  perform pg_temp.assert_true(
    v_member->>'current_plan_key' = 'firm_annual',
    'a member names the chamber owner''s oldest approved Firm plan, not a newer other-tier purchase'
  );
  perform pg_temp.assert_true(
    (v_member->>'plan_expiry')::timestamptz
      between now() + interval '29 days' and now() + interval '31 days',
    'a member takes the chamber expiry'
  );
  perform pg_temp.assert_true(
    (v_member->>'case_count')::int = 0
    and (v_member->>'note_count')::int = 0
    and (v_member->>'reference_count')::int = 0,
    'a member counts only their own work, not the chamber''s'
  );

  -- -------------------------------------------------------------------------
  -- 6. A free account is listed, but has no live plan
  -- -------------------------------------------------------------------------

  perform pg_temp.assert_true(
    v_free->>'current_tier' = 'free'
    and not (v_free->>'plan_active')::boolean
    and v_free->>'current_plan_key' is null,
    'a free account reads free, inactive and unnamed'
  );
  perform pg_temp.assert_true(
    v_free->'subscription_history' = '[]'::jsonb,
    'a free account with no purchases has an empty ledger'
  );

  reset role;
end;
$$;

rollback;
