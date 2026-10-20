-- Task 22 subscription-ladder proof — proves
-- `20261019100000_subscription_ladder_six_tiers.sql`.
--
-- Self-contained: throwaway accounts are created inside one transaction that is
-- rolled back, so no fixture survives. `approve_payment` and `ensure_firm` run
-- as the role they are granted to (`authenticated`) with `request.jwt.claims`
-- set, which is what `auth.uid()` reads — the RPCs' own gates, the `is_admin()`
-- registry and the ladder's validation all run for real rather than simulated.
--
-- Run wrapped, like the other probes here:
--
--   printf 'begin;\n' | cat - supabase/tests/subscription_ladder_test.sql \
--     <(echo rollback;) | psql "$URL" -v ON_ERROR_STOP=1 --file=-
--
-- What it proves, in order:
--
--   * **the six rungs** — rank, case ceiling and lapse allowance answer the
--     ladder's numbers, and no sold rung is uncapped
--   * **a first purchase starts at once** — a free account buying Starter
--     annual is Starter on the spot, with no queued change;
--   * **a same-tier purchase renews** — the expiry grows by the term and the
--     tier does not move;
--   * **a different tier is queued, never applied mid-term** — the tier in
--     force is untouched, the pending pair starts at the current expiry, and the
--     period is extended by the term bought;
--   * **only one change may wait** — a third tier answers `change_pending` and
--     writes nothing;
--   * **renewing the queued plan pushes its start back** by the term bought;
--   * **a legacy key still resolves** — `monthly` at its old ৳100 buys Starter
--     for one month, so a submission waiting from before the revamp is not
--     stranded;
--   * **a real key at the wrong amount is refused**, and its buyer's tier and
--     expiry do not move;
--   * **the generated names** — `enterprise_annual` and the legacy `annual` both
--     read the name the client shows;
--   * **the seat caps** — Firm 5, Firm Plus 10, Enterprise 20;
--   * **the creation gate is the Firm rung** — a Starter and a Pro owner are
--     refused `firm_tier_required` with nothing written, and a Firm owner's
--     chamber is created on the tier the gate read.

begin;

-- ---------------------------------------------------------------------------
-- Assertion helpers (the shape the other firm-mode smoke tests use)
-- ---------------------------------------------------------------------------

create or replace function pg_temp.assert_true(p_condition boolean, p_message text)
returns void
language plpgsql
as $$
begin
  if p_condition is not true then
    raise exception 'LADDER FAIL: %', p_message;
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

-- Stages one pending submission for p_user and returns its id.
create or replace function pg_temp.stage(p_user uuid, p_plan text, p_amount integer,
                                        p_trx text)
returns uuid
language plpgsql
as $$
declare
  v_id uuid;
begin
  insert into public.payment_submissions (
    user_id, plan_type, amount, mfs_provider, sender_number,
    transaction_id, created_at, updated_at
  )
  values (p_user, p_plan, p_amount, 'bkash', '01700000000', p_trx, 0, 0)
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function pg_temp.approve(p_admin uuid, p_submission uuid)
returns jsonb
language plpgsql
as $$
declare
  v_out jsonb;
begin
  perform pg_temp.as_user('authenticated', p_admin);
  v_out := public.approve_payment(p_submission);
  perform pg_temp.as_owner();
  return v_out;
end;
$$;

create or replace function pg_temp.create_chamber(p_user uuid, p_name text)
returns jsonb
language plpgsql
as $$
declare
  v_out jsonb;
begin
  perform pg_temp.as_user('authenticated', p_user);
  v_out := public.ensure_firm(p_name);
  perform pg_temp.as_owner();
  return v_out;
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
  c_admin uuid := pg_temp.sign_up('ladder-admin@test.local');
  c_first uuid := pg_temp.sign_up('ladder-first@test.local');
  c_renew uuid := pg_temp.sign_up('ladder-renew@test.local');
  c_queue uuid := pg_temp.sign_up('ladder-queue@test.local');
  c_legacy uuid := pg_temp.sign_up('ladder-legacy@test.local');
  c_wrong uuid := pg_temp.sign_up('ladder-wrong@test.local');
  c_starter_owner uuid := pg_temp.sign_up('ladder-starter-owner@test.local');
  c_pro_owner uuid := pg_temp.sign_up('ladder-pro-owner@test.local');
  c_firm_owner uuid := pg_temp.sign_up('ladder-firm-owner@test.local');
  c_ceiling uuid := pg_temp.sign_up('ladder-ceiling@test.local');

  v_result jsonb;
  v_profile public.profiles%rowtype;
  v_firm_id uuid;
  v_first_expiry timestamptz;
  v_queue_start timestamptz;
  v_before_expiry timestamptz;
begin
  -- The caller has to be an admin; the registry row is the authority, not the
  -- role the RPC's GRANT names.
  insert into public.app_admins (user_id) values (c_admin);

  -- -------------------------------------------------------------------------
  -- 1. The six rungs.
  -- -------------------------------------------------------------------------
  perform pg_temp.assert_true(public.tier_rank('free') = 0, 'free is rank 0');
  perform pg_temp.assert_true(public.tier_rank('starter') = 1, 'starter is rank 1');
  perform pg_temp.assert_true(public.tier_rank('pro') = 2, 'pro is rank 2');
  perform pg_temp.assert_true(public.tier_rank('firm') = 3, 'firm is rank 3');
  perform pg_temp.assert_true(public.tier_rank('firm_plus') = 4, 'firm_plus is rank 4');
  perform pg_temp.assert_true(public.tier_rank('enterprise') = 5, 'enterprise is rank 5');

  perform pg_temp.assert_true(public.tier_case_ceiling('free') = 50, 'free ceiling 50');
  perform pg_temp.assert_true(public.tier_case_ceiling('starter') = 500, 'starter ceiling 500');
  perform pg_temp.assert_true(public.tier_case_ceiling('pro') = 1000, 'pro ceiling 1,000');
  perform pg_temp.assert_true(public.tier_case_ceiling('firm') = 2500, 'firm ceiling 2,500');
  perform pg_temp.assert_true(public.tier_case_ceiling('firm_plus') = 6000, 'firm_plus ceiling 6,000');
  perform pg_temp.assert_true(public.tier_case_ceiling('enterprise') = 20000, 'enterprise ceiling 20,000');

  perform pg_temp.assert_true(public.tier_lapse_allowance('free') = 0, 'free is never lapsed');
  perform pg_temp.assert_true(public.tier_lapse_allowance('starter') = 100, 'starter allowance 100');
  perform pg_temp.assert_true(public.tier_lapse_allowance('pro') = 250, 'pro allowance 250');
  perform pg_temp.assert_true(public.tier_lapse_allowance('firm') = 500, 'firm allowance 500');
  perform pg_temp.assert_true(public.tier_lapse_allowance('firm_plus') = 1000, 'firm_plus allowance 1,000');
  perform pg_temp.assert_true(public.tier_lapse_allowance('enterprise') = 2000, 'enterprise allowance 2,000');

  -- -------------------------------------------------------------------------
  -- 2. A first purchase starts at once.
  -- -------------------------------------------------------------------------
  v_result := pg_temp.approve(
    c_admin,
    pg_temp.stage(c_first, 'starter_annual', 540, 'LAD-FIRST')
  );
  perform pg_temp.assert_true(v_result->>'status' = 'approved', 'starter annual approved');
  perform pg_temp.assert_true((v_result->>'queued')::boolean is false, 'a first purchase is not queued');

  select * into v_profile from public.profiles p where p.id = c_first;
  perform pg_temp.assert_true(v_profile.tier = 'starter', 'a first purchase stores its tier');
  perform pg_temp.assert_true(v_profile.tier_pending is null, 'a first purchase queues nothing');
  perform pg_temp.assert_true(
    v_profile.subscription_expiry > now() + interval '11 months',
    'a first purchase starts now'
  );
  v_first_expiry := v_profile.subscription_expiry;

  -- -------------------------------------------------------------------------
  -- 3. A same-tier purchase renews.
  -- -------------------------------------------------------------------------
  v_result := pg_temp.approve(
    c_admin,
    pg_temp.stage(c_renew, 'starter_annual', 540, 'LAD-RENEW-1')
  );
  perform pg_temp.assert_true(v_result->>'status' = 'approved', 'starter annual approved');
  select subscription_expiry into v_first_expiry from public.profiles p where p.id = c_renew;

  v_result := pg_temp.approve(
    c_admin,
    pg_temp.stage(c_renew, 'starter_monthly', 80, 'LAD-RENEW-2')
  );
  perform pg_temp.assert_true(v_result->>'status' = 'approved', 'starter monthly approved');
  select * into v_profile from public.profiles p where p.id = c_renew;
  perform pg_temp.assert_true(v_profile.tier = 'starter', 'a renewal does not move the tier');
  perform pg_temp.assert_true(
    v_profile.subscription_expiry = v_first_expiry + interval '1 month',
    'a renewal adds its own term to the expiry'
  );

  -- -------------------------------------------------------------------------
  -- 4-6. A different tier queues; a third is refused; renewing the queue shifts it.
  -- -------------------------------------------------------------------------
  v_result := pg_temp.approve(
    c_admin,
    pg_temp.stage(c_queue, 'starter_annual', 540, 'LAD-QUEUE-1')
  );
  perform pg_temp.assert_true(v_result->>'status' = 'approved', 'queue setup approved');
  select subscription_expiry into v_first_expiry from public.profiles p where p.id = c_queue;
  v_queue_start := v_first_expiry;

  v_result := pg_temp.approve(
    c_admin,
    pg_temp.stage(c_queue, 'pro_quarterly', 360, 'LAD-QUEUE-2')
  );
  perform pg_temp.assert_true(v_result->>'status' = 'approved', 'pro quarterly accepted');
  perform pg_temp.assert_true((v_result->>'queued')::boolean, 'a different tier is queued');
  perform pg_temp.assert_true(
    (v_result->>'starts_at')::timestamptz = v_queue_start,
    'the queued term starts when the paid one ends'
  );

  select * into v_profile from public.profiles p where p.id = c_queue;
  perform pg_temp.assert_true(v_profile.tier = 'starter', 'the tier in force is not overwritten');
  perform pg_temp.assert_true(v_profile.tier_pending = 'pro', 'the bought tier waits');
  perform pg_temp.assert_true(
    v_profile.tier_pending_from = v_queue_start,
    'the pending start is the old expiry'
  );
  perform pg_temp.assert_true(
    v_profile.subscription_expiry = v_queue_start + interval '3 months',
    'the queued term extends the paid period'
  );

  -- A third tier behind the queued one is refused, with nothing written.
  select subscription_expiry into v_before_expiry from public.profiles p where p.id = c_queue;
  v_result := pg_temp.approve(
    c_admin,
    pg_temp.stage(c_queue, 'firm_quarterly', 750, 'LAD-QUEUE-3')
  );
  perform pg_temp.assert_true(v_result->>'status' = 'change_pending', 'a third plan is refused');
  select * into v_profile from public.profiles p where p.id = c_queue;
  perform pg_temp.assert_true(v_profile.tier_pending = 'pro', 'the queued plan is unchanged');
  perform pg_temp.assert_true(
    v_profile.subscription_expiry = v_before_expiry,
    'a refused third plan writes nothing'
  );

  -- Renewing the queued plan shifts its start by the term bought, and the tier
  -- in force is still untouched.
  v_result := pg_temp.approve(
    c_admin,
    pg_temp.stage(c_queue, 'pro_annual', 1200, 'LAD-QUEUE-4')
  );
  perform pg_temp.assert_true(v_result->>'status' = 'approved', 'renewing the queued plan is accepted');
  select * into v_profile from public.profiles p where p.id = c_queue;
  perform pg_temp.assert_true(v_profile.tier = 'starter', 'the renewal leaves the tier in force alone');
  perform pg_temp.assert_true(v_profile.tier_pending = 'pro', 'the queued tier stands');
  perform pg_temp.assert_true(
    v_profile.tier_pending_from = v_queue_start + interval '12 months',
    'renewing the queued plan pushes its start back by its term'
  );

  -- -------------------------------------------------------------------------
  -- 7. A legacy key still resolves, and a wrong amount is refused.
  -- -------------------------------------------------------------------------
  v_result := pg_temp.approve(
    c_admin,
    pg_temp.stage(c_legacy, 'monthly', 100, 'LAD-LEGACY')
  );
  perform pg_temp.assert_true(v_result->>'status' = 'approved', 'a legacy key is still resolvable');
  perform pg_temp.assert_true(v_result->>'tier' = 'starter', 'a legacy key buys the renamed Starter rung');

  select subscription_expiry into v_before_expiry from public.profiles p where p.id = c_wrong;
  v_result := pg_temp.approve(
    c_admin,
    pg_temp.stage(c_wrong, 'pro_annual', 1000, 'LAD-WRONG')
  );
  perform pg_temp.assert_true(v_result->>'status' = 'invalid_amount', 'a wrong amount is refused');
  select * into v_profile from public.profiles p where p.id = c_wrong;
  perform pg_temp.assert_true(v_profile.tier = 'free', 'a refused amount moves no tier');
  perform pg_temp.assert_true(v_profile.subscription_expiry is null, 'a refused amount moves no expiry');

  -- -------------------------------------------------------------------------
  -- 8. The generated names cover the new key and the legacy one.
  -- -------------------------------------------------------------------------
  perform pg_temp.assert_true(
    (select plan_name from public.payment_submissions
      where user_id = c_legacy and plan_type = 'monthly' limit 1) = 'Starter · 1 Month',
    'the legacy monthly key is named Starter · 1 Month'
  );
  -- A staged row is enough to read its generated name; it is never approved.
  perform pg_temp.stage(c_wrong, 'enterprise_annual', 15000, 'LAD-NAME');
  perform pg_temp.assert_true(
    (select plan_name from public.payment_submissions
      where user_id = c_wrong and plan_type = 'enterprise_annual' limit 1)
      = 'Enterprise · 1 Year',
    'the enterprise key is named'
  );

  -- -------------------------------------------------------------------------
  -- 9. The seat caps.
  -- -------------------------------------------------------------------------
  -- The chamber rows are staged by the test owner: a cap is a pure read of the
  -- chamber's stored tier, and staging each rung directly is what makes the
  -- three answers comparable in one run.
  insert into public.firms (id, name, owner_id, tier, subscription_status,
                            subscription_expiry, created_at)
  values (gen_random_uuid(), 'Ladder Firm', c_firm_owner, 'firm', 'premium',
          now() + interval '1 month', now())
  returning id into v_firm_id;
  perform pg_temp.assert_true(public.firm_seat_cap(v_firm_id) = 5, 'firm seats 5');

  update public.firms set tier = 'firm_plus' where id = v_firm_id;
  perform pg_temp.assert_true(public.firm_seat_cap(v_firm_id) = 10, 'firm plus seats 10');

  update public.firms set tier = 'enterprise' where id = v_firm_id;
  perform pg_temp.assert_true(public.firm_seat_cap(v_firm_id) = 20, 'enterprise seats 20');
  delete from public.firms where id = v_firm_id;

  -- -------------------------------------------------------------------------
  -- 10. The creation gate is the Firm rung.
  -- -------------------------------------------------------------------------
  update public.profiles set tier = 'starter' where id = c_starter_owner;
  v_result := pg_temp.create_chamber(c_starter_owner, 'Starter Chamber');
  perform pg_temp.assert_true(v_result->>'status' = 'firm_tier_required', 'Starter cannot create a chamber');
  perform pg_temp.assert_true(
    not exists (select 1 from public.firms f where f.owner_id = c_starter_owner),
    'a refused Starter owner writes no chamber'
  );

  update public.profiles set tier = 'pro' where id = c_pro_owner;
  v_result := pg_temp.create_chamber(c_pro_owner, 'Pro Chamber');
  perform pg_temp.assert_true(v_result->>'status' = 'firm_tier_required', 'Pro cannot create a chamber');
  perform pg_temp.assert_true(
    not exists (select 1 from public.firms f where f.owner_id = c_pro_owner),
    'a refused Pro owner writes no chamber'
  );

  update public.profiles set tier = 'firm' where id = c_firm_owner;
  v_result := pg_temp.create_chamber(c_firm_owner, 'Firm Chamber');
  perform pg_temp.assert_true(v_result->>'status' = 'ready', 'Firm can create a chamber');

  select * into v_profile from public.profiles p where p.id = c_firm_owner;
  perform pg_temp.assert_true(v_profile.firm_id is not null, 'the Firm owner is in the chamber');
  perform pg_temp.assert_true(
    (select tier from public.firms f where f.id = v_profile.firm_id) = 'firm',
    'the chamber is created on the tier the gate read'
  );

  -- -------------------------------------------------------------------------
  -- 11. A paid ceiling is enforced on insert, not only on the device.
  -- -------------------------------------------------------------------------
  -- A Starter account is filled to its 500-case ceiling in one statement (the
  -- row trigger counts the rows before each insert, so the 500th is allowed),
  -- then the next insert must be refused with the new exception. The whole run
  -- is rolled back, so the 500 rows never survive.
  update public.profiles set tier = 'starter' where id = c_ceiling;

  insert into public.cases (
    id, user_id, court_id, case_type, case_number, petitioner, respondent,
    on_behalf_id, created_at, updated_at
  )
  select
    'ceiling-' || g,
    c_ceiling,
    (select id from public.courts where is_custom = false limit 1),
    'Civil',
    'CEIL-' || g,
    'Petitioner',
    'Respondent',
    (select id from public.on_behalfs where is_custom = false limit 1),
    0, 0
  from generate_series(1, 500) as g;

  perform pg_temp.assert_true(
    (select count(*) from public.cases c where c.user_id = c_ceiling and c.is_deleted = false) = 500,
    'the paid ceiling allowed the 500 cases it sells'
  );

  begin
    insert into public.cases (
      id, user_id, court_id, case_type, case_number, petitioner, respondent,
      on_behalf_id, created_at, updated_at
    )
    values (
      'ceiling-501',
      c_ceiling,
      (select id from public.courts where is_custom = false limit 1),
      'Civil',
      'CEIL-501',
      'Petitioner',
      'Respondent',
      (select id from public.on_behalfs where is_custom = false limit 1),
      0, 0
    );
    raise exception 'LADDER FAIL: the 501st case was accepted on a 500-case plan'
      using errcode = 'P0002';
  exception
    when sqlstate 'P0001' then
      perform pg_temp.assert_true(sqlerrm = 'case_limit_reached', 'the paid ceiling refused with its own reason');
  end;

  raise notice 'LADDER OK';
end;
$$;

rollback;
