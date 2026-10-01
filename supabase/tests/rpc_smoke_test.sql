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
do $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', current_setting('test.user_id'), 'role',
    'authenticated')::text,
    true
  );
end;
$$;
set local role authenticated;
select pg_temp.assert_raises(
  'select public.approve_payment(current_setting(''test.submission_id'')::uuid)',
  'admin_required'
);
reset role;

-- The administrator approves it.
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
set local role authenticated;
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
reset role;

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

-- A rejected/absent submission cannot be approved.
select pg_temp.assert_true(
  pg_temp.scalar(
    'select public.approve_payment(gen_random_uuid())'
  ) like '%"not_found"%',
  'an unknown submission did not report not_found'
);

-- The audit ledger cannot be rewritten.
select pg_temp.assert_raises(
  'update public.payment_approval_events set amount = 1',
  'immutable'
);
select pg_temp.assert_raises(
  'delete from public.payment_approval_events',
  'immutable'
);

-- The 3-per-24h trigger: two more submissions are accepted, the fourth is
-- refused, and a client-supplied submitted_at is overwritten with server time.
do $$
declare
  v_index integer;
begin
  for v_index in 2..3 loop
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
        and submitted_at > now() - interval '1 hour') = 3,
    'the trigger did not stamp server time on every submission'
  );
end;
$$;

select pg_temp.assert_raises(
  'insert into public.payment_submissions (user_id, plan_type, amount, '
  'mfs_provider, sender_number, transaction_id, created_at, updated_at) '
  'values (''' || current_setting('test.user_id') || ''', ''monthly'', 100, '
  '''bkash'', ''01700000000'', ''SMOKE-TRX-4'', 0, 0)',
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

do $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', current_setting('test.user_id'), 'role',
    'authenticated')::text,
    true
  );
end;
$$;
set local role authenticated;

-- A wrong code returns a status (it does not raise) and records an attempt.
select pg_temp.assert_true(
  pg_temp.scalar('select public.join_firm(''WRONG-CODE'')') like '%"invalid_code"%',
  'a wrong code did not report invalid_code'
);
reset role;
select pg_temp.assert_true(
  (select count(*) from public.invite_attempts
    where user_id = current_setting('test.user_id')::uuid) = 1,
  'a failed attempt was not recorded (was it raised instead of returned?)'
);

set local role authenticated;
-- The hash must be of the normalized code, so a lowercase/padded code works.
select pg_temp.assert_true(
  pg_temp.scalar('select public.join_firm(''  smoke-code-1  '')')
    like '%"joined"%',
  'a valid code did not join'
);
reset role;

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
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', current_setting('test.user_id'), 'role',
    'authenticated')::text,
    true
  );
end;
$$;
set local role authenticated;
select pg_temp.assert_true(
  pg_temp.scalar('select public.join_firm(''SMOKE-CODE-2'')')
    like '%"already_member"%',
  'a repeat join did not report already_member'
);
reset role;
select pg_temp.assert_true(
  (select count(*) from public.firm_members
    where firm_id = current_setting('test.invite_firm_id')::uuid
      and user_id = current_setting('test.user_id')::uuid) = 1,
  'a repeat join created a duplicate membership'
);

-- Five failures in the window, then the sixth call is refused outright.
do $$
declare
  v_index integer;
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', current_setting('test.user_id'), 'role',
    'authenticated')::text,
    true
  );
  for v_index in 1..5 loop
    perform pg_temp.assert_true(
      pg_temp.scalar('select public.join_firm(''STILL-WRONG'')')
        like '%"invalid_code"%',
      'failure ' || v_index || ' did not report invalid_code'
    );
  end loop;
end;
$$;
set local role authenticated;
select pg_temp.assert_raises(
  'select public.join_firm(''STILL-WRONG'')',
  'Too many attempts'
);
reset role;

-- The free-tier ceiling: 50 live cases are allowed for a free owner and the
-- 51st insert is refused (soft-deleted rows would not count).
do $$
declare
  v_court text;
  v_on_behalf text;
  v_index integer;
begin
  select id into v_court from public.courts where is_deleted = false limit 1;
  select id into v_on_behalf
    from public.on_behalfs where is_deleted = false limit 1;

  perform pg_temp.assert_true(
    v_court is not null and v_on_behalf is not null,
    'the built-in seed data is missing; apply the seed migration first'
  );

  -- The admin fixture user is still free (only test.user_id was approved).
  perform pg_temp.assert_true(
    not public.is_premium(current_setting('test.admin_id')::uuid),
    'the admin fixture user must be on a free entitlement'
  );

  for v_index in 1..50 loop
    insert into public.cases (
      id, user_id, court_id, case_type, case_number, petitioner, respondent,
      on_behalf_id, created_at, updated_at
    )
    values (
      'smoke-case-' || v_index,
      current_setting('test.admin_id')::uuid,
      v_court, 'Smoke Type', 'SMOKE-' || v_index, 'Petitioner', 'Respondent',
      v_on_behalf, 0, 0
    );
  end loop;

  perform set_config('test.court_id', v_court, true);
  perform set_config('test.on_behalf_id', v_on_behalf, true);
end;
$$;

select pg_temp.assert_raises(
  'insert into public.cases (id, user_id, court_id, case_type, case_number, '
  'petitioner, respondent, on_behalf_id, created_at, updated_at) values ('
  '''smoke-case-51'', ''' || current_setting('test.admin_id') || ''', '''
  || current_setting('test.court_id') || ''', ''Smoke Type'', ''SMOKE-51'', '
  '''Petitioner'', ''Respondent'', ''' || current_setting('test.on_behalf_id')
  || ''', 0, 0)',
  'free_case_limit_reached'
);

-- Soft-deleting one case frees a slot: the ceiling counts live rows only.
update public.cases set is_deleted = true where id = 'smoke-case-1';
insert into public.cases (
  id, user_id, court_id, case_type, case_number, petitioner, respondent,
  on_behalf_id, created_at, updated_at
)
values (
  'smoke-case-51', current_setting('test.admin_id')::uuid,
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
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', current_setting('test.user_id'), 'role',
    'authenticated')::text,
    true
  );
  update public.profiles
     set subscription_status = 'free',
         subscription_expiry = null,
         firm_id = null,
         role = 'individual'
   where id = current_setting('test.user_id')::uuid;
end;
$$;
set local role authenticated;

-- Phase 1 item 2: becoming a firm owner requires a derived premium entitlement.
select pg_temp.assert_true(
  pg_temp.scalar('select public.ensure_firm(''Smoke Free Firm'')')
    like '%"premium_required"%',
  'a free account was allowed to become a firm owner'
);
reset role;
select pg_temp.assert_true(
  (select count(*) from public.firms
    where owner_id = current_setting('test.user_id')::uuid) = 0,
  'the premium refusal created a firm anyway'
);

-- The same account, now premium: the transition succeeds exactly once.
do $$
begin
  update public.profiles
     set subscription_status = 'premium',
         subscription_expiry = now() + interval '30 days'
   where id = current_setting('test.user_id')::uuid;
end;
$$;
set local role authenticated;
select pg_temp.assert_true(
  pg_temp.scalar('select public.ensure_firm(''Smoke Premium Firm'')')
    like '%"ready"%',
  'a premium individual was not allowed to create a firm'
);
reset role;
do $$
declare
  v_firm_id uuid;
begin
  select id into v_firm_id
    from public.firms
   where owner_id = current_setting('test.user_id')::uuid;

  perform pg_temp.assert_true(
    v_firm_id is not null,
    'the premium transition created no firm'
  );
  perform pg_temp.assert_true(
    (select firm_id from public.profiles
      where id = current_setting('test.user_id')::uuid) = v_firm_id,
    'the transition did not relink profiles.firm_id'
  );
  perform pg_temp.assert_true(
    (select role from public.profiles
      where id = current_setting('test.user_id')::uuid) = 'owner',
    'the transition did not set the owner role'
  );
  perform pg_temp.assert_true(
    exists (
      select 1 from public.firm_members m
       where m.firm_id = v_firm_id
         and m.user_id = current_setting('test.user_id')::uuid
         and m.role = 'owner'
         and m.can_add and m.can_edit and m.can_delete
    ),
    'the transition did not give the owner every permission'
  );
end;
$$;

-- Idempotent: a second call returns the same firm and creates no second one.
set local role authenticated;
do $$
declare
  v_again text;
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', current_setting('test.user_id'), 'role',
    'authenticated')::text,
    true
  );
  v_again := pg_temp.scalar('select public.ensure_firm(''Smoke Premium Firm'')');
  perform pg_temp.assert_true(
    v_again like '%"ready"%',
    'the second call did not report ready'
  );
end;
$$;
reset role;
select pg_temp.assert_true(
  (select count(*) from public.firms
    where owner_id = current_setting('test.user_id')::uuid) = 1,
  'the second call created a second firm'
);

-- The membership guard: a member of somebody else's firm cannot create one of
-- their own and relink their profile away from the rows they authored.
do $$
begin
  update public.profiles
     set firm_id = current_setting('test.firm_id')::uuid,
         role = 'associate'
   where id = current_setting('test.user_id')::uuid;
end;
$$;
set local role authenticated;
select pg_temp.assert_true(
  pg_temp.scalar('select public.ensure_firm(''Smoke Second Firm'')')
    like '%"member_of_another_firm"%',
  'a member of another firm was allowed to create a second firm'
);
reset role;
select pg_temp.assert_true(
  (select firm_id from public.profiles
    where id = current_setting('test.user_id')::uuid)
      = current_setting('test.firm_id')::uuid,
  'the refusal relinked the profile anyway'
);

-- ---------------------------------------------------------------------------
-- remove_firm_member (Task 20 Phase 2 — removing an associate)
-- ---------------------------------------------------------------------------

-- Fixtures: `test.user_id` belongs to the firm `test.admin_id` owns, and has
-- authored one row in it. The removal must end the membership and the access
-- without touching the authored record.
do $$
begin
  update public.profiles
     set firm_id = current_setting('test.invite_firm_id')::uuid,
         role = 'associate'
   where id = current_setting('test.user_id')::uuid;

  insert into public.firm_members (firm_id, user_id, role, can_add, can_edit,
                                   can_delete)
  values (
    current_setting('test.invite_firm_id')::uuid,
    current_setting('test.user_id')::uuid,
    'associate', true, true, false
  );

  insert into public.cases (
    id, user_id, firm_id, court_id, case_type, case_number, petitioner,
    respondent, on_behalf_id, created_at, updated_at
  )
  values
    (
      'smoke-removal-case',
      current_setting('test.user_id')::uuid,
      current_setting('test.invite_firm_id')::uuid,
      current_setting('test.court_id'), 'Smoke Type', 'SMOKE-RM', 'Petitioner',
      'Respondent', current_setting('test.on_behalf_id'), 0, 0
    ),
    -- A second row in the same firm, authored by the owner: the one the
    -- removed member must no longer be able to see.
    (
      'smoke-owner-case',
      current_setting('test.admin_id')::uuid,
      current_setting('test.invite_firm_id')::uuid,
      current_setting('test.court_id'), 'Smoke Type', 'SMOKE-OW', 'Petitioner',
      'Respondent', current_setting('test.on_behalf_id'), 0, 0
    );
end;
$$;

-- A member cannot remove anybody: only the firm's owner administers membership,
-- and the function resolves the firm from the caller rather than a parameter.
do $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', current_setting('test.user_id'), 'role',
    'authenticated')::text,
    true
  );
end;
$$;
set local role authenticated;
select pg_temp.assert_true(
  pg_temp.scalar(
    'select public.remove_firm_member(''' || current_setting('test.admin_id')
    || '''::uuid)'
  ) like '%"not_owner"%',
  'an associate was allowed to remove a member'
);
reset role;

-- The owner cannot remove themselves: the firm would be left with an owner who
-- is not a member.
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
set local role authenticated;
select pg_temp.assert_true(
  pg_temp.scalar(
    'select public.remove_firm_member(''' || current_setting('test.admin_id')
    || '''::uuid)'
  ) like '%"cannot_remove_self"%',
  'the owner was allowed to remove themselves'
);
reset role;
select pg_temp.assert_true(
  (select count(*) from public.firm_members
    where firm_id = current_setting('test.invite_firm_id')::uuid
      and user_id = current_setting('test.user_id')::uuid) = 1,
  'a refused removal deleted the membership anyway'
);

-- The removal itself: membership gone, profile relinked to individual mode.
do $$
declare
  v_result text;
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', current_setting('test.admin_id'), 'role',
    'authenticated')::text,
    true
  );
  v_result := pg_temp.scalar(
    'select public.remove_firm_member(''' || current_setting('test.user_id')
    || '''::uuid)'
  );
  perform pg_temp.assert_true(
    v_result like '%"removed"%',
    'the owner could not remove an associate'
  );
  perform pg_temp.assert_true(
    (select count(*) from public.firm_members
      where firm_id = current_setting('test.invite_firm_id')::uuid
        and user_id = current_setting('test.user_id')::uuid) = 0,
    'the membership row survived the removal'
  );
  perform pg_temp.assert_true(
    (select firm_id from public.profiles
      where id = current_setting('test.user_id')::uuid) is null,
    'the removed member\'s profile was not relinked to individual mode'
  );
  perform pg_temp.assert_true(
    (select role from public.profiles
      where id = current_setting('test.user_id')::uuid) = 'individual',
    'the removed member\'s role was left as associate with no firm'
  );
  -- Authored records are preserved and never reassigned: the audit attribution
  -- and the firm the row belongs to both stay exactly as they were.
  perform pg_temp.assert_true(
    (select user_id from public.cases where id = 'smoke-removal-case')
      = current_setting('test.user_id')::uuid,
    'the removal reassigned an authored record'
  );
  perform pg_temp.assert_true(
    (select firm_id from public.cases where id = 'smoke-removal-case')
      = current_setting('test.invite_firm_id')::uuid,
    'the removal took the firm\'s record away from the firm'
  );
end;
$$;
reset role;

-- The access really is gone for the firm's other rows — and the rows the member
-- authored are still theirs to see, which is what "preserve authored records"
-- means against an RLS shape of `user_id = auth.uid() or firm_id =
-- current_firm_id()`. Nulling `firm_id` is what revokes both RLS and the
-- Realtime topic authorization.
do $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', current_setting('test.user_id'), 'role',
    'authenticated')::text,
    true
  );
end;
$$;
set local role authenticated;
select pg_temp.assert_true(
  (select count(*) from public.cases where id = 'smoke-owner-case') = 0,
  'a removed member can still read the firm''s other cases'
);
select pg_temp.assert_true(
  (select count(*) from public.cases where id = 'smoke-removal-case') = 1,
  'a removed member lost sight of their own authored record'
);
select pg_temp.assert_true(
  not public.can_read_topic('firm:' || current_setting('test.invite_firm_id')),
  'a removed member can still subscribe to the firm''s topic'
);
reset role;

-- Removing again reports that there is nothing to remove, rather than deleting
-- anything else.
do $$
declare
  v_again text;
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', current_setting('test.admin_id'), 'role',
    'authenticated')::text,
    true
  );
  v_again := pg_temp.scalar(
    'select public.remove_firm_member(''' || current_setting('test.user_id')
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
reset role;

-- Nothing above is kept: no money was approved, no invite was spent and no firm
-- survived the rollback.
rollback;

\echo 'SMOKE OK: approve_payment, join_firm, ensure_firm and remove_firm_member behave as specified.'
