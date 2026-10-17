-- Firm mode member-plan test — proves `20261017100000_firm_mode_member_no_plan.sql`.
--
-- Self-contained: throwaway accounts and a chamber are created inside one
-- transaction that is rolled back, so no fixture survives. The client paths are
-- exercised the way PostgREST does it — `set local role authenticated` plus
-- `request.jwt.claims`, which is what `auth.uid()` reads — so the insert policy
-- and `push_changes`'s own entitlement gate run for real rather than being
-- simulated.
--
-- Runs as it stands, because it opens and closes its own transaction:
--
--   psql "$URL" -v ON_ERROR_STOP=1 -f supabase/tests/firm_mode_member_no_plan_test.sql
--
-- The file needs no psql meta-commands, so the same body also runs through the
-- Supabase connector, transaction intact. It printed its OK marker against
-- `lsthasywrdrhuuxnykau` on 2026-10-17.
--
-- Six checks, in order:
--
--   * **a member is not entitled through their own plan** — the member holds a
--     live paid period of their own while the chamber is lapsed past its grace,
--     which is exactly the state the entitlement gate used to accept;
--   * **the member's submission is refused by the policy** — not merely hidden
--     in the app, and the refusal is the RLS policy's own error;
--   * **the owner may still submit** — the chamber's renewal is the owner's
--     purchase, so the refusal is a member's alone;
--   * **an individual is unaffected** — their own live plan entitles them and
--     their submission is accepted;
--   * **the chamber entitles its member when it is live** — the member's own
--     period is then lapsed, so only the chamber's expiry can be doing the work;
--   * **a lapsed chamber's member is rejected by push_changes**, and once the
--     member is individual again their own paid time counts — preserved, not
--     destroyed.

begin;

-- ---------------------------------------------------------------------------
-- Assertion and impersonation helpers (the shape the other firm-mode tests use)
-- ---------------------------------------------------------------------------

create or replace function pg_temp.assert_true(p_condition boolean, p_message text)
returns void
language plpgsql
as $$
begin
  if p_condition is not true then
    raise exception 'MEMBER PLAN FAIL: %', p_message;
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

-- Puts the session back the way it was found: the role **and** the claims
-- setting, which `reset role` leaves behind.
create or replace function pg_temp.as_owner()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', '', true);
  execute 'reset role';
end;
$$;

-- Rows touched by a statement run as p_user. A refused insert raises, which is
-- what `raises_as` below is for; a 0 here would mean the policy silently
-- filtered the row instead.
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

-- Runs p_sql as p_user and requires it to fail with a message mentioning
-- p_message.
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
        raise exception 'MEMBER PLAN FAIL: expected an error mentioning %, got: %',
          p_message, sqlerrm;
      end if;
      return;
  end;
  perform pg_temp.as_owner();
  raise exception
    'MEMBER PLAN FAIL: expected an error mentioning %, but the statement succeeded',
    p_message;
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
-- Fixtures: an owner, one associate with a leftover plan, one individual
-- ---------------------------------------------------------------------------

do $$
declare
  c_owner uuid := pg_temp.sign_up('member-plan-owner@test.local');
  c_member uuid := pg_temp.sign_up('member-plan-member@test.local');
  c_individual uuid := pg_temp.sign_up('member-plan-individual@test.local');
  v_firm uuid := gen_random_uuid();
begin
  -- The chamber is lapsed past the 48-hour grace; its owner's own expiry is the
  -- same value, because the mirror keeps the two equal in a real chamber.
  insert into public.firms (
    id, name, owner_id, subscription_status, subscription_expiry, tier
  )
  values (
    v_firm, 'Member Plan Chamber', c_owner, 'free',
    now() - interval '3 days', 'firm'
  );

  update public.profiles
     set firm_id = v_firm,
         role = 'owner',
         subscription_status = 'free',
         subscription_expiry = now() - interval '3 days'
   where id = c_owner;

  -- The member's own plan is live: the state a planner reaches by buying Pro
  -- and then joining an empty-diary chamber, which the gate used to honour.
  update public.profiles
     set firm_id = v_firm,
         role = 'associate',
         subscription_status = 'premium',
         subscription_expiry = now() + interval '30 days'
   where id = c_member;

  -- The individual is a control: no firm, the same live plan.
  update public.profiles
     set subscription_status = 'premium',
         subscription_expiry = now() + interval '30 days'
   where id = c_individual;

  insert into public.firm_members (firm_id, user_id, role, can_add, can_edit, can_delete)
  values
    (v_firm, c_owner, 'owner', true, true, true),
    (v_firm, c_member, 'associate', true, true, true);

  perform set_config('test.owner', c_owner::text, true);
  perform set_config('test.member', c_member::text, true);
  perform set_config('test.individual', c_individual::text, true);
  perform set_config('test.firm', v_firm::text, true);
end;
$$;

-- ---------------------------------------------------------------------------
-- 1. The member's own plan does not entitle them while the chamber is lapsed
-- ---------------------------------------------------------------------------

do $$
declare
  c_member uuid := current_setting('test.member')::uuid;
  c_individual uuid := current_setting('test.individual')::uuid;
begin
  perform pg_temp.assert_true(
    public.has_sync_entitlement(c_member) is false,
    'a member with a live own plan was entitled while the chamber was lapsed — '
      'the own-expiry OR is still in has_sync_entitlement'
  );

  perform pg_temp.assert_true(
    public.has_sync_entitlement(c_individual) is true,
    'an individual with the same live plan was not entitled'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. The member's submission is refused by the policy, not by the app
-- ---------------------------------------------------------------------------

select pg_temp.raises_as(
  current_setting('test.member')::uuid,
  'insert into public.payment_submissions (user_id, plan_type, amount, '
  'mfs_provider, sender_number, transaction_id, created_at, updated_at) '
  'values (auth.uid(), ''monthly'', 100, ''bkash'', ''01700000000'', '
  '''member-plan-trx-member'', 0, 0)',
  'row-level security policy'
);

-- ---------------------------------------------------------------------------
-- 3. The owner may still submit — the chamber's renewal is the owner's purchase
-- ---------------------------------------------------------------------------

select pg_temp.assert_true(
  pg_temp.rows_as(
    current_setting('test.owner')::uuid,
    'insert into public.payment_submissions (user_id, plan_type, amount, '
    'mfs_provider, sender_number, transaction_id, created_at, updated_at) '
    'values (auth.uid(), ''firm_annual'', 3000, ''bkash'', ''01700000000'', '
    '''member-plan-trx-owner'', 0, 0)'
  ) = 1,
  'the owner could not submit a chamber renewal — the refusal reached too far'
);

-- ---------------------------------------------------------------------------
-- 4. An individual with the same live plan is accepted
-- ---------------------------------------------------------------------------

select pg_temp.assert_true(
  pg_temp.rows_as(
    current_setting('test.individual')::uuid,
    'insert into public.payment_submissions (user_id, plan_type, amount, '
    'mfs_provider, sender_number, transaction_id, created_at, updated_at) '
    'values (auth.uid(), ''monthly'', 100, ''bkash'', ''01700000000'', '
    '''member-plan-trx-individual'', 0, 0)'
  ) = 1,
  'an individual could not submit their own plan'
);

-- ---------------------------------------------------------------------------
-- 5. The chamber alone entitles its member when it is live
-- ---------------------------------------------------------------------------

do $$
declare
  c_member uuid := current_setting('test.member')::uuid;
  v_firm uuid := current_setting('test.firm')::uuid;
begin
  -- The member's own period is now lapsed, so only the chamber's expiry can
  -- answer true below.
  update public.profiles
     set subscription_expiry = now() - interval '30 days'
   where id = c_member;

  update public.firms
     set subscription_expiry = now() + interval '30 days'
   where id = v_firm;

  perform pg_temp.assert_true(
    public.has_sync_entitlement(c_member) is true,
    'a live chamber did not entitle its member'
  );

  -- Put the chamber back to its lapsed state for the push check below.
  update public.firms
     set subscription_expiry = now() - interval '3 days'
   where id = v_firm;

  perform pg_temp.assert_true(
    public.has_sync_entitlement(c_member) is false,
    'the lapsed chamber entitled its member after the fixture was restored'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. push_changes rejects the member while the chamber is lapsed, and the
--    member's own paid time still counts once they are individual
-- ---------------------------------------------------------------------------

do $$
declare
  c_member uuid := current_setting('test.member')::uuid;
  v_out jsonb;
begin
  perform pg_temp.as_user('authenticated', c_member);
  v_out := public.push_changes(jsonb_build_array(jsonb_build_object(
    'mutation_id', 'member-plan-push',
    'entity_type', 'case',
    'entity_id', 'member-plan-case',
    'operation', 'create',
    'payload', jsonb_build_object(
      'id', 'member-plan-case',
      'case_no', 'MEMBER-PLAN-1',
      'updated_at', 1
    )
  )));
  perform pg_temp.as_owner();

  perform pg_temp.assert_true(
    v_out #>> '{results,0,status}' = 'rejected'
      and v_out #>> '{results,0,error_code}' = 'entitlement_required',
    'a member with a live own plan pushed through the chamber lapse'
  );

  -- Individual again: the paid time that was ignored in the chamber applies.
  update public.profiles
     set firm_id = null,
         role = 'individual',
         subscription_expiry = now() + interval '30 days'
   where id = c_member;

  perform pg_temp.assert_true(
    public.has_sync_entitlement(c_member) is true,
    'paid time was destroyed rather than preserved for the day the member is '
      'individual again'
  );
end;
$$;

rollback;

select 'FIRM MODE MEMBER PLAN OK' as result;
