-- RPC smoke test — approve_payment(), join_firm(), ensure_firm() and
-- remove_firm_member().
--
-- Usage (needs two real auth users; their profiles exist because of the
-- sign-up trigger):
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
--     -v admin_id=<uuid-of-an-admin-user> \
--     -v user_id=<uuid-of-an-ordinary-user> \
--     -f supabase/tests/rpc_smoke_test.sql
--
-- The whole script runs in one transaction that is rolled back at the end: it
-- spends no real money, consumes no real invite and leaves no fixtures behind.
-- `admin_id` does not need to be in app_admins beforehand — the test grants it
-- inside the transaction.
--
-- Every check reports "SMOKE FAIL: ..." through a raised exception, so
-- ON_ERROR_STOP makes a failure exit non-zero.

begin;

-- psql variables are not GUCs: publish them where SQL can read them, and fail
-- early with a usable message when one was not supplied.
select set_config('test.admin_id', :'admin_id', true);
select set_config('test.user_id', :'user_id', true);

do $$
begin
  if coalesce(current_setting('test.admin_id', true), '') !~* '^[0-9a-f-]{36}$'
     or coalesce(current_setting('test.user_id', true), '') !~* '^[0-9a-f-]{36}$'
  then
    raise exception
      'SMOKE FAIL: run with -v admin_id=<uuid> -v user_id=<uuid>';
  end if;
end;
$$;

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

-- Runs p_sql and requires it to fail with an error mentioning p_message.
create or replace function pg_temp.assert_raises(p_sql text, p_message text)
returns void
language plpgsql
as $$
begin
  begin
    execute p_sql;
  exception
    when others then
      if position(p_message in sqlerrm) = 0 then
        raise exception 'SMOKE FAIL: expected an error mentioning %, got: %',
          p_message, sqlerrm;
      end if;
      return;
  end;
  raise exception
    'SMOKE FAIL: expected an error mentioning %, but the call succeeded',
    p_message;
end;
$$;

-- Runs p_sql and returns its single value as text (jsonb comes back quoted).
create or replace function pg_temp.scalar(p_sql text)
returns text
language plpgsql
as $$
declare
  v_result text;
begin
  execute 'select (' || p_sql || ')::text' into v_result;
  return v_result;
end;
$$;

-- Puts the session back the way it was found: the role **and** the claims
-- setting. Clearing the claim is not tidiness. Since firm mode's permission
-- trigger reads `auth.uid()`, `reset role` restores the role but leaves
-- `request.jwt.claims` behind — so a fixture staged afterwards is judged as
-- that member's write and refused `add_not_permitted`.
create or replace function pg_temp.as_server()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', '', true);
  execute 'reset role';
end;
$$;

-- Impersonates p_user for the next calls: the claims first, then the role. Pair
-- it with `as_server()`, which clears both.
create or replace function pg_temp.as_user(p_user uuid)
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', p_user::text, 'role', 'authenticated')::text,
    true
  );
  execute 'set local role authenticated';
end;
$$;

-- ---------------------------------------------------------------------------
-- Fixtures (all inside the transaction)
-- ---------------------------------------------------------------------------

do $$
begin
  if not exists (select 1 from public.profiles where id
                 = current_setting('test.admin_id')::uuid) then
    raise exception 'SMOKE FAIL: no profile for admin_id';
  end if;
  if not exists (select 1 from public.profiles where id
                 = current_setting('test.user_id')::uuid) then
    raise exception 'SMOKE FAIL: no profile for user_id';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- approve_payment
-- ---------------------------------------------------------------------------

do $$
declare
  v_firm_id uuid;
  v_submission_id uuid;
  v_other_submission_id uuid;
begin
  -- The admin registry decides, not the database role.
  insert into public.app_admins (user_id)
  values (current_setting('test.admin_id')::uuid)
  on conflict (user_id) do nothing;

  -- A firm owned by the paying user, so the owner->firm mirror has a target.
  insert into public.firms (name, owner_id)
  values ('Smoke Test Chambers', current_setting('test.user_id')::uuid)
  returning id into v_firm_id;

  update public.profiles
     set firm_id = v_firm_id, role = 'owner'
   where id = current_setting('test.user_id')::uuid;

  -- The paying user starts with a lapsed-but-expired clause to exercise the
  -- GREATEST() base: 30 days ago.
  update public.profiles
     set subscription_expiry = now() - interval '30 days',
         subscription_status = 'free'
   where id = current_setting('test.user_id')::uuid;

  insert into public.payment_submissions (
    user_id, plan_type, amount, mfs_provider, sender_number,
    transaction_id, created_at, updated_at
  )
  values (
    current_setting('test.user_id')::uuid, 'monthly', 100, 'bkash',
    '01700000000', 'SMOKE-TRX-1', 0, 0
  )
  returning id into v_submission_id;

  perform set_config('test.firm_id', v_firm_id::text, true);
  perform set_config('test.submission_id', v_submission_id::text, true);
end;
$$;

-- A caller who is not in app_admins is refused, whatever the role grant says.
select pg_temp.as_user(current_setting('test.user_id')::uuid);
select pg_temp.assert_raises(
  'select public.approve_payment(current_setting(''test.submission_id'')::uuid)',
  'admin_required'
);
select pg_temp.as_server();

-- The administrator approves it.
select pg_temp.as_user(current_setting('test.admin_id')::uuid);
select pg_temp.assert_true(
  pg_temp.scalar(
    'select public.approve_payment(current_setting(''test.submission_id'')::uuid)'
  ) like '%"status": "approved"%',
  'approval did not report approved'
);

-- Retries are idempotent: the same call returns already_approved...
select pg_temp.assert_true(
  pg_temp.scalar(
    'select public.approve_payment(current_setting(''test.submission_id'')::uuid)'
  ) like '%"already_approved"%',
  'a retry did not report already_approved'
);
select pg_temp.as_server();

-- ...and the expiry moved exactly one month from the lapsed base, once.
do $$
declare
  v_expiry timestamptz;
  v_previous timestamptz;
  v_events integer;
begin
  select subscription_expiry into v_expiry
    from public.profiles
   where id = current_setting('test.user_id')::uuid;

  select previous_expiry, count(*) over () into v_previous, v_events
    from public.payment_approval_events
   where payment_submission_id = current_setting('test.submission_id')::uuid;

  perform pg_temp.assert_true(
    v_previous is not null,
    'no audit event was written'
  );
  perform pg_temp.assert_true(v_events = 1, 'audit events are not one-per-submission');
  perform pg_temp.assert_true(
    abs(extract(epoch from (v_expiry - (now() + interval '1 month')))) < 120,
    'expiry is not now() + 1 month for a lapsed subscription'
  );
  perform pg_temp.assert_true(
    (select subscription_status from public.profiles
      where id = current_setting('test.user_id')::uuid) = 'premium',
    'display status was not updated'
  );
  perform pg_temp.assert_true(
    (select status from public.payment_submissions
      where id = current_setting('test.submission_id')::uuid) = 'approved',
    'submission was not marked approved'
  );
  -- The firm mirror is the only writer of firms.subscription_expiry.
  perform pg_temp.assert_true(
    (select subscription_expiry from public.firms
      where id = current_setting('test.firm_id')::uuid)
      = v_expiry,
    'the owner subscription was not mirrored to the firm'
  );
end;
$$;

-- A rejected/absent submission cannot be approved. The caller must be an
-- administrator, or the answer would be `admin_required` instead.
do $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', current_setting('test.admin_id'), 'role',
    'authenticated')::text,
    true
  );
end;
$$;
select pg_temp.assert_true(
  pg_temp.scalar(
    'select public.approve_payment(gen_random_uuid())'
  ) like '%"not_found"%',
  'an unknown submission did not report not_found'
);
select pg_temp.as_server();

-- The audit ledger cannot be rewritten.
select pg_temp.assert_raises(
  'update public.payment_approval_events set amount = 1',
  'immutable'
);
select pg_temp.assert_raises(
  'delete from public.payment_approval_events',
  'immutable'
);

-- The 5-per-24h trigger (raised from three in 0.0.509): four more submissions
-- are accepted, the sixth is refused, and a client-supplied submitted_at is
-- overwritten with server time.
do $$
declare
  v_index integer;
begin
  for v_index in 2..5 loop
    insert into public.payment_submissions (
      user_id, plan_type, amount, mfs_provider, sender_number,
      transaction_id, created_at, updated_at, submitted_at
    )
    values (
      current_setting('test.user_id')::uuid, 'monthly', 100, 'bkash',
      '01700000000', 'SMOKE-TRX-' || v_index, 0, 0,
      now() - interval '10 days'  -- must be overwritten, not honoured
    );
  end loop;

  perform pg_temp.assert_true(
    (select count(*) from public.payment_submissions
      where user_id = current_setting('test.user_id')::uuid
        and submitted_at > now() - interval '1 hour') = 5,
    'the trigger did not stamp server time on every submission'
  );
end;
$$;

select pg_temp.assert_raises(
  'insert into public.payment_submissions (user_id, plan_type, amount, '
  'mfs_provider, sender_number, transaction_id, created_at, updated_at) '
  'values (''' || current_setting('test.user_id') || ''', ''monthly'', 100, '
  '''bkash'', ''01700000000'', ''SMOKE-TRX-6'', 0, 0)',
  'payment_submission_limit_reached'
);

-- ---------------------------------------------------------------------------
-- join_firm
-- ---------------------------------------------------------------------------

do $$
declare
  v_firm_id uuid;
  v_invite_id uuid;
begin
  insert into public.firms (name, owner_id)
  values ('Smoke Test Invite Firm', current_setting('test.admin_id')::uuid)
  returning id into v_firm_id;

  insert into public.firm_invites (firm_id, code_hash, created_by, created_at)
  values (
    v_firm_id,
    public.sha256_hex(upper(btrim('SMOKE-CODE-1'))),
    current_setting('test.admin_id')::uuid,
    0
  )
  returning id into v_invite_id;

  perform set_config('test.invite_firm_id', v_firm_id::text, true);
  perform set_config('test.invite_id', v_invite_id::text, true);
end;
$$;

select pg_temp.as_user(current_setting('test.user_id')::uuid);

-- A wrong code returns a status (it does not raise) and records an attempt.
select pg_temp.assert_true(
  pg_temp.scalar('select public.join_firm(''WRONG-CODE'')') like '%"invalid_code"%',
  'a wrong code did not report invalid_code'
);
select pg_temp.as_server();
select pg_temp.assert_true(
  (select count(*) from public.invite_attempts
    where user_id = current_setting('test.user_id')::uuid) = 1,
  'a failed attempt was not recorded (was it raised instead of returned?)'
);

select pg_temp.as_user(current_setting('test.user_id')::uuid);
-- The hash must be of the normalized code, so a lowercase/padded code works.
-- The answer is captured once, so a failure can name the status it returned
-- instead of only saying the join did not happen.
do $$
declare
  v_out text;
begin
  v_out := pg_temp.scalar('select public.join_firm(''  smoke-code-1  '')');
  perform pg_temp.assert_true(
    v_out like '%"joined"%',
    'a valid code did not join (got ' || coalesce(v_out, 'null') || ')'
  );
end;
$$;
select pg_temp.as_server();

do $$
begin
  perform pg_temp.assert_true(
    (select count(*) from public.firm_members
      where firm_id = current_setting('test.invite_firm_id')::uuid
        and user_id = current_setting('test.user_id')::uuid) = 1,
    'membership was not created'
  );
  perform pg_temp.assert_true(
    (select firm_id from public.profiles
      where id = current_setting('test.user_id')::uuid)
      = current_setting('test.invite_firm_id')::uuid,
    'the profile was not relinked to the firm'
  );
  perform pg_temp.assert_true(
    (select role from public.profiles
      where id = current_setting('test.user_id')::uuid) = 'associate',
    'the profile role was not set to associate'
  );
  perform pg_temp.assert_true(
    (select used_by from public.firm_invites
      where id = current_setting('test.invite_id')::uuid)
      = current_setting('test.user_id')::uuid,
    'the invite was not consumed'
  );
  perform pg_temp.assert_true(
    (select count(*) from public.invite_attempts
      where user_id = current_setting('test.user_id')::uuid) = 0,
    'a successful join must clear the caller''s attempts'
  );
end;
$$;

-- A second, unused invite for the same firm reports already_member instead of
-- creating a duplicate membership (and is still consumed: single-use).
do $$
begin
  insert into public.firm_invites (firm_id, code_hash, created_by, created_at)
  values (
    current_setting('test.invite_firm_id')::uuid,
    public.sha256_hex(upper(btrim('SMOKE-CODE-2'))),
    current_setting('test.admin_id')::uuid,
    0
  );
end;
$$;
select pg_temp.as_user(current_setting('test.user_id')::uuid);
select pg_temp.assert_true(
  pg_temp.scalar('select public.join_firm(''SMOKE-CODE-2'')')
    like '%"already_member"%',
  'a repeat join did not report already_member'
);
select pg_temp.as_server();
select pg_temp.assert_true(
  (select count(*) from public.firm_members
    where firm_id = current_setting('test.invite_firm_id')::uuid
      and user_id = current_setting('test.user_id')::uuid) = 1,
  'a repeat join created a duplicate membership'
);

-- Five failures in the window, then the sixth call is refused outright.
select pg_temp.as_user(current_setting('test.user_id')::uuid);
do $$
declare
  v_index integer;
begin
  for v_index in 1..5 loop
    perform pg_temp.assert_true(
      pg_temp.scalar('select public.join_firm(''STILL-WRONG'')')
        like '%"invalid_code"%',
      'failure ' || v_index || ' did not report invalid_code'
    );
  end loop;
end;
$$;
select pg_temp.as_user(current_setting('test.user_id')::uuid);
select pg_temp.assert_raises(
  'select public.join_firm(''STILL-WRONG'')',
  'Too many attempts'
);
select pg_temp.as_server();

-- The free-tier ceiling: 50 live cases are allowed for a free owner and the
-- 51st insert is refused (soft-deleted rows would not count).
do $$
declare
  v_court text;
  v_on_behalf text;
  v_index integer;
  -- A throwaway account of its own: the variables' real accounts may hold cases
  -- from their own diary, and the free wall needs a diary that starts empty.
  v_user uuid := gen_random_uuid();
begin
  select id into v_court from public.courts where is_deleted = false limit 1;
  select id into v_on_behalf
    from public.on_behalfs where is_deleted = false limit 1;

  perform pg_temp.assert_true(
    v_court is not null and v_on_behalf is not null,
    'the built-in seed data is missing; apply the seed migration first'
  );

  insert into auth.users (id, email, email_confirmed_at, created_at, updated_at,
                          is_sso_user, is_anonymous)
  values (v_user, 'smoke-ceiling@test.local', now(), now(), now(), false, false);

  perform pg_temp.assert_true(
    not public.is_premium(v_user),
    'the ceiling fixture must be on a free entitlement'
  );

  for v_index in 1..50 loop
    insert into public.cases (
      id, user_id, court_id, case_type, case_number, petitioner, respondent,
      on_behalf_id, created_at, updated_at
    )
    values (
      'smoke-case-' || v_index,
      v_user,
      v_court, 'Smoke Type', 'SMOKE-' || v_index, 'Petitioner', 'Respondent',
      v_on_behalf, 0, 0
    );
  end loop;

  perform set_config('test.ceiling_user', v_user::text, true);
  perform set_config('test.court_id', v_court, true);
  perform set_config('test.on_behalf_id', v_on_behalf, true);
end;
$$;

select pg_temp.assert_raises(
  'insert into public.cases (id, user_id, court_id, case_type, case_number, '
  'petitioner, respondent, on_behalf_id, created_at, updated_at) values ('
  '''smoke-case-51'', ''' || current_setting('test.ceiling_user') || ''', '''
  || current_setting('test.court_id') || ''', ''Smoke Type'', ''SMOKE-51'', '
  '''Petitioner'', ''Respondent'', ''' || current_setting('test.on_behalf_id')
  || ''', 0, 0)',
  'case_limit_reached'
);

-- Soft-deleting one case frees a slot: the ceiling counts live rows only.
update public.cases set is_deleted = true where id = 'smoke-case-1';
insert into public.cases (
  id, user_id, court_id, case_type, case_number, petitioner, respondent,
  on_behalf_id, created_at, updated_at
)
values (
  'smoke-case-51', current_setting('test.ceiling_user')::uuid,
  current_setting('test.court_id'), 'Smoke Type', 'SMOKE-51', 'Petitioner',
  'Respondent', current_setting('test.on_behalf_id'), 0, 0
);

-- ---------------------------------------------------------------------------
-- ensure_firm (Task 20 Phase 1 — the premium gate and the membership guard)
-- ---------------------------------------------------------------------------

-- The caller's own row is what decides, so the test edits it inside the
-- transaction: a free individual first, then a premium one, then a premium one
-- who already belongs to somebody else's firm.
do $$
declare
  -- A throwaway account of its own: the variables' real accounts may already
  -- own a chamber, and this block needs an individual with no firm at all.
  v_user uuid := gen_random_uuid();
begin
  insert into auth.users (id, email, email_confirmed_at, created_at, updated_at,
                          is_sso_user, is_anonymous)
  values (v_user, 'smoke-owner@test.local', now(), now(), now(), false, false);

  update public.profiles
     set subscription_status = 'free',
         subscription_expiry = null,
         tier = 'free',
         tier_pending = null,
         tier_pending_from = null,
         firm_id = null,
         role = 'individual'
   where id = v_user;

  perform set_config('test.owner_id', v_user::text, true);
end;
$$;
select pg_temp.as_user(current_setting('test.owner_id')::uuid);

-- Firm mode Phase 7: becoming a firm owner requires the Firm tier, because
-- Pro and Starter sell no seat (`firm_seat_cap` answers 0).
select pg_temp.assert_true(
  pg_temp.scalar('select public.ensure_firm(''Smoke Free Firm'')')
    like '%"firm_tier_required"%',
  'a free account was allowed to become a firm owner'
);
select pg_temp.as_server();
select pg_temp.assert_true(
  (select count(*) from public.firms
    where owner_id = current_setting('test.owner_id')::uuid) = 0,
  'the premium refusal created a firm anyway'
);

-- The same account, now premium: the transition succeeds exactly once.
do $$
begin
  update public.profiles
     set subscription_status = 'premium',
         subscription_expiry = now() + interval '30 days',
         tier = 'firm'
   where id = current_setting('test.owner_id')::uuid;
end;
$$;
select pg_temp.as_user(current_setting('test.owner_id')::uuid);
select pg_temp.assert_true(
  pg_temp.scalar('select public.ensure_firm(''Smoke Premium Firm'')')
    like '%"ready"%',
  'a premium individual was not allowed to create a firm'
);
select pg_temp.as_server();
do $$
declare
  v_firm_id uuid;
begin
  select id into v_firm_id
    from public.firms
   where owner_id = current_setting('test.owner_id')::uuid;

  perform pg_temp.assert_true(
    v_firm_id is not null,
    'the premium transition created no firm'
  );
  perform pg_temp.assert_true(
    (select firm_id from public.profiles
      where id = current_setting('test.owner_id')::uuid) = v_firm_id,
    'the transition did not relink profiles.firm_id'
  );
  perform pg_temp.assert_true(
    (select role from public.profiles
      where id = current_setting('test.owner_id')::uuid) = 'owner',
    'the transition did not set the owner role'
  );
  perform pg_temp.assert_true(
    exists (
      select 1 from public.firm_members m
       where m.firm_id = v_firm_id
         and m.user_id = current_setting('test.owner_id')::uuid
         and m.role = 'owner'
         and m.can_add and m.can_edit and m.can_delete
    ),
    'the transition did not give the owner every permission'
  );
end;
$$;

-- Idempotent: a second call returns the same firm and creates no second one.
select pg_temp.as_user(current_setting('test.owner_id')::uuid);
do $$
declare
  v_again text;
begin
  v_again := pg_temp.scalar('select public.ensure_firm(''Smoke Premium Firm'')');
  perform pg_temp.assert_true(
    v_again like '%"ready"%',
    'the second call did not report ready'
  );
end;
$$;
select pg_temp.as_server();
select pg_temp.assert_true(
  (select count(*) from public.firms
    where owner_id = current_setting('test.owner_id')::uuid) = 1,
  'the second call created a second firm'
);

-- The membership guard: a member of somebody else's firm cannot create one of
-- their own and relink their profile away from the rows they authored.
do $$
begin
  update public.profiles
     set firm_id = current_setting('test.firm_id')::uuid,
         role = 'associate'
   where id = current_setting('test.owner_id')::uuid;
end;
$$;
select pg_temp.as_user(current_setting('test.owner_id')::uuid);
select pg_temp.assert_true(
  pg_temp.scalar('select public.ensure_firm(''Smoke Second Firm'')')
    like '%"member_of_another_firm"%',
  'a member of another firm was allowed to create a second firm'
);
select pg_temp.as_server();
select pg_temp.assert_true(
  (select firm_id from public.profiles
    where id = current_setting('test.owner_id')::uuid)
      = current_setting('test.firm_id')::uuid,
  'the refusal relinked the profile anyway'
);

-- ---------------------------------------------------------------------------
-- remove_firm_member (Task 20 Phase 2 — removing an associate)
-- ---------------------------------------------------------------------------

-- Fixtures: a chamber with two throwaway accounts — its owner and an associate
-- who has authored one row in it. The removal must end the membership and the
-- access without touching the authored record.
--
-- Both accounts are throwaway rather than the two variables' real ones.
-- `remove_firm_member` resolves the caller's firm from `firms.owner_id`, so a
-- real owner account that already administers a chamber would resolve to *that*
-- chamber and the fixture's membership would never be found; and the real
-- ordinary account is already seated by the join_firm block above. A clean
-- chamber is what makes the checks mean what they say.
do $$
declare
  v_owner uuid := gen_random_uuid();
  v_user uuid := gen_random_uuid();
  v_firm uuid;
begin
  insert into auth.users (id, email, email_confirmed_at, created_at, updated_at,
                          is_sso_user, is_anonymous)
  values
    (v_owner, 'smoke-removal-owner@test.local', now(), now(), now(), false,
     false),
    (v_user, 'smoke-associate@test.local', now(), now(), now(), false, false);

  insert into public.firms (name, owner_id)
  values ('Smoke Removal Firm', v_owner)
  returning id into v_firm;

  update public.profiles
     set firm_id = v_firm, role = 'owner'
   where id = v_owner;

  update public.profiles
     set firm_id = v_firm, role = 'associate'
   where id = v_user;

  insert into public.firm_members (firm_id, user_id, role, can_add, can_edit,
                                   can_delete)
  values
    (v_firm, v_owner, 'owner', true, true, true),
    (v_firm, v_user, 'associate', true, true, false);

  perform set_config('test.remove_owner', v_owner::text, true);
  perform set_config('test.remove_user', v_user::text, true);
  perform set_config('test.remove_firm_id', v_firm::text, true);

  insert into public.cases (
    id, user_id, firm_id, court_id, case_type, case_number, petitioner,
    respondent, on_behalf_id, created_at, updated_at
  )
  values
    (
      'smoke-removal-case',
      current_setting('test.remove_user')::uuid,
      v_firm,
      current_setting('test.court_id'), 'Smoke Type', 'SMOKE-RM', 'Petitioner',
      'Respondent', current_setting('test.on_behalf_id'), 0, 0
    ),
    -- A second row in the same firm, authored by the owner: the one the
    -- removed member must no longer be able to see.
    (
      'smoke-owner-case',
      v_owner,
      v_firm,
      current_setting('test.court_id'), 'Smoke Type', 'SMOKE-OW', 'Petitioner',
      'Respondent', current_setting('test.on_behalf_id'), 0, 0
    );
end;
$$;

-- A member cannot remove anybody: only the firm's owner administers membership,
-- and the function resolves the firm from the caller rather than a parameter.
select pg_temp.as_user(current_setting('test.remove_user')::uuid);
select pg_temp.assert_true(
  pg_temp.scalar(
    'select public.remove_firm_member(''' || current_setting('test.remove_user')
    || '''::uuid)'
  ) like '%"not_owner"%',
  'an associate was allowed to remove a member'
);
select pg_temp.as_server();

-- The owner cannot remove themselves: the firm would be left with an owner who
-- is not a member.
select pg_temp.as_user(current_setting('test.remove_owner')::uuid);
select pg_temp.assert_true(
  pg_temp.scalar(
    'select public.remove_firm_member(''' || current_setting('test.remove_owner')
    || '''::uuid)'
  ) like '%"cannot_remove_self"%',
  'the owner was allowed to remove themselves'
);
select pg_temp.as_server();
select pg_temp.assert_true(
  (select count(*) from public.firm_members
    where firm_id = current_setting('test.remove_firm_id')::uuid
      and user_id = current_setting('test.remove_user')::uuid) = 1,
  'a refused removal deleted the membership anyway'
);

-- The removal itself: membership gone, profile relinked to individual mode.
do $$
declare
  v_result text;
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', current_setting('test.remove_owner'), 'role',
    'authenticated')::text,
    true
  );
  v_result := pg_temp.scalar(
    'select public.remove_firm_member(''' || current_setting('test.remove_user')
    || '''::uuid)'
  );
  perform pg_temp.assert_true(
    v_result like '%"removed"%',
    'the owner could not remove an associate (got '
      || coalesce(v_result, 'null') || ')'
  );
  perform pg_temp.assert_true(
    (select count(*) from public.firm_members
      where firm_id = current_setting('test.remove_firm_id')::uuid
        and user_id = current_setting('test.remove_user')::uuid) = 0,
    'the membership row survived the removal'
  );
  perform pg_temp.assert_true(
    (select firm_id from public.profiles
      where id = current_setting('test.remove_user')::uuid) is null,
    'the removed member''s profile was not relinked to individual mode'
  );
  perform pg_temp.assert_true(
    (select role from public.profiles
      where id = current_setting('test.remove_user')::uuid) = 'individual',
    'the removed member''s role was left as associate with no firm'
  );
  -- Authored records are preserved and never reassigned: the audit attribution
  -- and the firm the row belongs to both stay exactly as they were.
  perform pg_temp.assert_true(
    (select user_id from public.cases where id = 'smoke-removal-case')
      = current_setting('test.remove_user')::uuid,
    'the removal reassigned an authored record'
  );
  perform pg_temp.assert_true(
    (select firm_id from public.cases where id = 'smoke-removal-case')
      = current_setting('test.remove_firm_id')::uuid,
    'the removal took the firm''s record away from the firm'
  );
end;
$$;
select pg_temp.as_server();

-- The access really is gone, for the chamber's other rows **and** for the one
-- the member authored: since `20261015100000_firm_mode_read_scope` the select
-- policy reads `scope_owner_id` and not `user_id` alone, so a firm row leaves a
-- removed member's read scope while staying preserved and attributed (checked
-- above, as the server). Nulling `firm_id` is what revokes both RLS and the
-- Realtime topic authorization.
select pg_temp.as_user(current_setting('test.remove_user')::uuid);
select pg_temp.assert_true(
  (select count(*) from public.cases where id = 'smoke-owner-case') = 0,
  'a removed member can still read the firm''s other cases'
);
select pg_temp.assert_true(
  (select count(*) from public.cases where id = 'smoke-removal-case') = 0,
  'a removed member can still read their authored chamber record'
);
select pg_temp.assert_true(
  not public.can_read_topic('firm:' || current_setting('test.remove_firm_id')),
  'a removed member can still subscribe to the firm''s topic'
);
select pg_temp.as_server();

-- Removing again reports that there is nothing to remove, rather than deleting
-- anything else.
do $$
declare
  v_again text;
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', current_setting('test.remove_owner'), 'role',
    'authenticated')::text,
    true
  );
  v_again := pg_temp.scalar(
    'select public.remove_firm_member(''' || current_setting('test.remove_user')
    || '''::uuid)'
  );
  perform pg_temp.assert_true(
    v_again like '%"not_found"%',
    'a second removal did not report not_found'
  );
end;
$$;

-- `anon` may not execute any of the four RPCs.
set local role anon;
select pg_temp.assert_raises(
  'select public.approve_payment(gen_random_uuid())',
  'permission denied'
);
select pg_temp.assert_raises(
  'select public.join_firm(''ANY'')',
  'permission denied'
);
select pg_temp.assert_raises(
  'select public.ensure_firm(''ANY'')',
  'permission denied'
);
select pg_temp.assert_raises(
  'select public.remove_firm_member(gen_random_uuid())',
  'permission denied'
);
select pg_temp.as_server();

-- Nothing above is kept: no money was approved, no invite was spent and no firm
-- survived the rollback.
rollback;

\echo 'SMOKE OK: approve_payment, join_firm, ensure_firm and remove_firm_member behave as specified.'
