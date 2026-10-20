-- ===========================================================================
-- 2026-10-20 — The price ladder, second pass.
--
-- **Why.** The six-tier ladder's prices were replaced (user ruling, 2026-10-20).
-- Starter and Pro rise at the monthly and annual rungs, the 6-month rung moves on
-- both, Firm's 6-month rung rises, and a **Firm one-month plan** joins the ladder
-- so a chamber can try firm mode without buying a quarter. Firm Plus and
-- Enterprise keep selling 3, 6 and 12 months.
--
-- **What changes.** Only the ladder inside `approve_payment` — its eighteen
-- sellable price constants, the key allow-list, the amount `CASE`, the duration
-- `CASE`, the tier `CASE` — and the two generated `plan_name` columns, which gain
-- the Firm one-month name. The gate, the row lock, the idempotency checks, the
-- queued-change rules, the firm mirror, the audit insert and the returned JSON
-- are byte-identical to `20261019100000`.
--
-- **Why it must ship with the app.** The client quotes these amounts and then
-- submits one; the server compares it with its own constant and refuses a
-- mismatch as `invalid_amount`. A price on one side only is a paying user's
-- submission that no admin can approve.
--
-- No grants are touched: `create or replace` preserves the ACLs
-- `20261019100000` left on `approve_payment`, and the generated columns carry
-- their table's.
--
-- **Prices.** Starter 80/180/300/540, Pro 150/360/660/1200, Firm 300/750/1350/
-- 2500, Firm Plus 1500/2700/5000, Enterprise 4500/8000/15000. Firm's one month
-- is deliberately dearer per month than its three-month rate, which is what
-- keeps the card's first two rows from reading as the same offer.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. `approve_payment`: eighteen sellable keys, four legacy keys, and a queue.
-- ---------------------------------------------------------------------------

create or replace function public.approve_payment(payment_submission_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  -- Configured plan prices, in BDT, one named constant per plan. A price change
  -- is then one migration, and the RPC validates the amount the server believes
  -- rather than the amount the client sent.
  c_starter_monthly_bdt constant integer := 80;
  c_starter_quarterly_bdt constant integer := 180;
  c_starter_half_yearly_bdt constant integer := 300;
  c_starter_annual_bdt constant integer := 540;
  c_pro_monthly_bdt constant integer := 150;
  c_pro_quarterly_bdt constant integer := 360;
  c_pro_half_yearly_bdt constant integer := 660;
  c_pro_annual_bdt constant integer := 1200;
  c_firm_monthly_bdt constant integer := 300;
  c_firm_quarterly_bdt constant integer := 750;
  c_firm_half_yearly_bdt constant integer := 1350;
  c_firm_annual_bdt constant integer := 2500;
  c_firm_plus_quarterly_bdt constant integer := 1500;
  c_firm_plus_half_yearly_bdt constant integer := 2700;
  c_firm_plus_annual_bdt constant integer := 5000;
  c_enterprise_quarterly_bdt constant integer := 4500;
  c_enterprise_half_yearly_bdt constant integer := 8000;
  c_enterprise_annual_bdt constant integer := 15000;

  -- The four keys the old ten-plan ladder sold. They are never offered again,
  -- but a submission made before the revamp may still be waiting, and refusing
  -- it would strand a payer's money with no way to resolve it. Their tier is
  -- Starter, because that is the rung their stored `pro` became.
  c_legacy_monthly_bdt constant integer := 100;
  c_legacy_quarterly_bdt constant integer := 285;
  c_legacy_half_yearly_bdt constant integer := 540;
  c_legacy_annual_bdt constant integer := 1000;

  v_submission public.payment_submissions%rowtype;
  v_profile public.profiles%rowtype;
  v_event public.payment_approval_events%rowtype;
  v_now timestamptz := now();
  v_previous_expiry timestamptz;
  v_new_expiry timestamptz;
  v_plan_amount integer;
  v_plan_months integer;
  v_tier text;
  v_effective text;
  v_active boolean;
  v_pending_live boolean;
  v_queue_start timestamptz;
  v_queued boolean := false;
begin
  -- A GRANT to `authenticated` is not authorization: every caller shares that
  -- database role, so the registry itself decides.
  if not public.is_admin() then
    raise exception 'admin_required' using errcode = '42501';
  end if;

  select * into v_submission
    from public.payment_submissions s
   where s.id = payment_submission_id
   for update;

  if not found then
    return jsonb_build_object('status', 'not_found');
  end if;

  select * into v_event
    from public.payment_approval_events e
   where e.payment_submission_id = approve_payment.payment_submission_id;

  -- Idempotent retries: a duplicate call can never extend expiry twice.
  if v_submission.status = 'approved' then
    if found then
      return jsonb_build_object(
        'status', 'already_approved',
        'new_expiry', v_event.new_expiry
      );
    end if;
    return jsonb_build_object('status', 'already_resolved');
  end if;

  if v_submission.status <> 'pending' then
    return jsonb_build_object('status', 'already_resolved');
  end if;

  -- The ladder's keys and nothing else: eighteen sellable keys plus the four
  -- legacy ones. Each `case` below is written over the same set, so a key cannot
  -- be accepted for its price but have no duration, or name a tier that does not
  -- exist.
  if v_submission.plan_type not in (
    'starter_monthly', 'starter_quarterly', 'starter_half_yearly', 'starter_annual',
    'pro_monthly', 'pro_quarterly', 'pro_half_yearly', 'pro_annual',
    'firm_monthly', 'firm_quarterly', 'firm_half_yearly', 'firm_annual',
    'firm_plus_quarterly', 'firm_plus_half_yearly', 'firm_plus_annual',
    'enterprise_quarterly', 'enterprise_half_yearly', 'enterprise_annual',
    'monthly', 'quarterly', 'half_yearly', 'annual'
  ) then
    return jsonb_build_object('status', 'invalid_plan');
  end if;

  -- Each plan's own amount. The CASE is parenthesized because plpgsql reads an
  -- IF condition up to the first top-level `then`; an unwrapped CASE ends it at
  -- its own `when ... then` and the function then fails to compile.
  v_plan_amount := (case v_submission.plan_type
    when 'starter_monthly' then c_starter_monthly_bdt
    when 'starter_quarterly' then c_starter_quarterly_bdt
    when 'starter_half_yearly' then c_starter_half_yearly_bdt
    when 'starter_annual' then c_starter_annual_bdt
    when 'pro_monthly' then c_pro_monthly_bdt
    when 'pro_quarterly' then c_pro_quarterly_bdt
    when 'pro_half_yearly' then c_pro_half_yearly_bdt
    when 'pro_annual' then c_pro_annual_bdt
    when 'firm_monthly' then c_firm_monthly_bdt
    when 'firm_quarterly' then c_firm_quarterly_bdt
    when 'firm_half_yearly' then c_firm_half_yearly_bdt
    when 'firm_annual' then c_firm_annual_bdt
    when 'firm_plus_quarterly' then c_firm_plus_quarterly_bdt
    when 'firm_plus_half_yearly' then c_firm_plus_half_yearly_bdt
    when 'firm_plus_annual' then c_firm_plus_annual_bdt
    when 'enterprise_quarterly' then c_enterprise_quarterly_bdt
    when 'enterprise_half_yearly' then c_enterprise_half_yearly_bdt
    when 'enterprise_annual' then c_enterprise_annual_bdt
    when 'monthly' then c_legacy_monthly_bdt
    when 'quarterly' then c_legacy_quarterly_bdt
    when 'half_yearly' then c_legacy_half_yearly_bdt
    else c_legacy_annual_bdt
  end);

  if v_submission.amount <> v_plan_amount then
    return jsonb_build_object('status', 'invalid_amount');
  end if;

  -- Each plan's own duration, so the interval can never disagree with the
  -- amount validated above. Firm now sells a single month; Firm Plus and
  -- Enterprise still start at three.
  v_plan_months := (case v_submission.plan_type
    when 'starter_monthly' then 1
    when 'starter_quarterly' then 3
    when 'starter_half_yearly' then 6
    when 'starter_annual' then 12
    when 'pro_monthly' then 1
    when 'pro_quarterly' then 3
    when 'pro_half_yearly' then 6
    when 'pro_annual' then 12
    when 'firm_monthly' then 1
    when 'firm_quarterly' then 3
    when 'firm_half_yearly' then 6
    when 'firm_annual' then 12
    when 'firm_plus_quarterly' then 3
    when 'firm_plus_half_yearly' then 6
    when 'firm_plus_annual' then 12
    when 'enterprise_quarterly' then 3
    when 'enterprise_half_yearly' then 6
    when 'enterprise_annual' then 12
    when 'monthly' then 1
    when 'quarterly' then 3
    when 'half_yearly' then 6
    else 12
  end);

  -- Which tier the purchase bought, from the key alone. The four legacy keys are
  -- Starter now, matching the rename in `20261019100000`.
  v_tier := (case
    when v_submission.plan_type in (
      'starter_monthly', 'starter_quarterly', 'starter_half_yearly', 'starter_annual',
      'monthly', 'quarterly', 'half_yearly', 'annual'
    ) then 'starter'
    when v_submission.plan_type in (
      'pro_monthly', 'pro_quarterly', 'pro_half_yearly', 'pro_annual'
    ) then 'pro'
    when v_submission.plan_type in (
      'firm_monthly', 'firm_quarterly', 'firm_half_yearly', 'firm_annual'
    ) then 'firm'
    when v_submission.plan_type in (
      'firm_plus_quarterly', 'firm_plus_half_yearly', 'firm_plus_annual'
    ) then 'firm_plus'
    else 'enterprise'
  end);

  select * into v_profile
    from public.profiles p
   where p.id = v_submission.user_id
   for update;

  if not found then
    return jsonb_build_object('status', 'not_found');
  end if;

  -- Server time decides the base; a lapsed-but-not-expired window is not lost.
  v_previous_expiry := v_profile.subscription_expiry;
  v_new_expiry := greatest(coalesce(v_previous_expiry, v_now), v_now)
    + make_interval(months => v_plan_months);

  -- The tier in force, as it stands *before* this approval: a waiting change
  -- that has already started counts, so buying during it does not resurrect the
  -- older tier.
  v_effective := public.effective_tier(
    v_profile.tier, v_profile.tier_pending, v_profile.tier_pending_from
  );

  -- A plan is "running" while its paid period has not ended. At or after that
  -- instant the account is free or lapsed, and a purchase starts at once.
  v_active := v_previous_expiry is not null and v_previous_expiry > v_now;

  -- A queued change only counts while its start is still in the future.
  v_pending_live :=
    v_profile.tier_pending is not null
    and v_profile.tier_pending_from is not null
    and v_profile.tier_pending_from > v_now;

  if not v_active then
    -- Nothing is running: the new plan starts now and replaces whatever rung the
    -- account last held. Free is below every paid rung, so a first purchase is
    -- always this branch.
    update public.profiles p
       set subscription_expiry = v_new_expiry,
           subscription_status = 'premium',
           tier = v_tier,
           tier_pending = null,
           tier_pending_from = null
     where p.id = v_submission.user_id;
  elsif v_tier = v_effective then
    -- A renewal of the plan in force. A waiting change is pushed back by the
    -- same term, because it starts when the *paid* period now ends.
    update public.profiles p
       set subscription_expiry = v_new_expiry,
           subscription_status = 'premium',
           tier_pending_from = case
             when v_pending_live then p.tier_pending_from + make_interval(months => v_plan_months)
             else p.tier_pending_from
           end
     where p.id = v_submission.user_id;
  elsif v_pending_live and v_tier = v_profile.tier_pending then
    -- A renewal of the plan already waiting: its own start moves later by the
    -- term just bought, and the running plan's period grows with it.
    update public.profiles p
       set subscription_expiry = v_new_expiry,
           subscription_status = 'premium',
           tier_pending_from = p.tier_pending_from + make_interval(months => v_plan_months)
     where p.id = v_submission.user_id;
  elsif v_pending_live then
    -- Only one change may wait. A third plan cannot be queued behind a second
    -- without deciding what the user actually wants; the client disables the
    -- action, and the server refuses the write rather than guessing.
    return jsonb_build_object(
      'status', 'change_pending',
      'pending_tier', v_profile.tier_pending,
      'pending_from', v_profile.tier_pending_from
    );
  else
    -- A different tier while a plan is running is **queued**, never applied
    -- mid-term: the tier that was paid for runs to its end, and the new term
    -- starts the instant it does. The expiry is extended by the new term now,
    -- because the payment has been taken now.
    v_queue_start := greatest(coalesce(v_previous_expiry, v_now), v_now);
    v_new_expiry := v_queue_start + make_interval(months => v_plan_months);
    update public.profiles p
       set subscription_expiry = v_new_expiry,
           subscription_status = 'premium',
           tier_pending = v_tier,
           tier_pending_from = v_queue_start
     where p.id = v_submission.user_id;
    v_queued := true;
  end if;

  update public.payment_submissions s
     set status = 'approved',
         approved_at = now(),
         approved_by = auth.uid(),
         updated_at = (extract(epoch from clock_timestamp()) * 1000)::bigint
   where s.id = payment_submission_id;

  -- Exactly one immutable event per submission (UNIQUE on the FK).
  insert into public.payment_approval_events (
    payment_submission_id, user_id, approved_by, plan_type, amount,
    previous_expiry, new_expiry
  )
  values (
    payment_submission_id, v_submission.user_id, auth.uid(),
    v_submission.plan_type, v_submission.amount,
    v_previous_expiry, v_new_expiry
  );

  return jsonb_build_object(
    'status', 'approved',
    'previous_expiry', v_previous_expiry,
    'new_expiry', v_new_expiry,
    'tier', v_tier,
    'queued', v_queued,
    'starts_at', case when v_queued then v_queue_start else null end
  );
end;
$$;

comment on function public.approve_payment(uuid) is
  'Approves one pending payment and grants the plan it names. Same-tier purchase renews and pushes any queued change back by the term; a different tier while a plan runs is queued to start when it ends; free or lapsed starts at once; only one change may wait. Validates the key, the amount and the duration on the server ladder.';

-- ---------------------------------------------------------------------------
-- 2. The readable plan names gain the Firm one-month plan.
-- ---------------------------------------------------------------------------

-- `plan_name` is GENERATED, so its CASE cannot be altered in place: the column
-- is dropped and re-added. Nothing writes it, so every row is recomputed from
-- its key and no value is lost.
alter table public.payment_submissions drop column if exists plan_name;
alter table public.payment_submissions
  add column plan_name text
  generated always as (
    case plan_type
      when 'starter_monthly' then 'Starter · 1 Month'
      when 'starter_quarterly' then 'Starter · 3 Months'
      when 'starter_half_yearly' then 'Starter · 6 Months'
      when 'starter_annual' then 'Starter · 1 Year'
      when 'pro_monthly' then 'Pro · 1 Month'
      when 'pro_quarterly' then 'Pro · 3 Months'
      when 'pro_half_yearly' then 'Pro · 6 Months'
      when 'pro_annual' then 'Pro · 1 Year'
      when 'firm_monthly' then 'Firm · 1 Month'
      when 'firm_quarterly' then 'Firm · 3 Months'
      when 'firm_half_yearly' then 'Firm · 6 Months'
      when 'firm_annual' then 'Firm · 1 Year'
      when 'firm_plus_quarterly' then 'Firm Plus · 3 Months'
      when 'firm_plus_half_yearly' then 'Firm Plus · 6 Months'
      when 'firm_plus_annual' then 'Firm Plus · 1 Year'
      when 'enterprise_quarterly' then 'Enterprise · 3 Months'
      when 'enterprise_half_yearly' then 'Enterprise · 6 Months'
      when 'enterprise_annual' then 'Enterprise · 1 Year'
      when 'monthly' then 'Starter · 1 Month'
      when 'quarterly' then 'Starter · 3 Months'
      when 'half_yearly' then 'Starter · 6 Months'
      when 'annual' then 'Starter · 1 Year'
      else plan_type
    end
  ) stored;

comment on column public.payment_submissions.plan_name is
  'Readable name of the plan the submission pays for, derived from plan_type. Generated, so it cannot disagree with the key; the app localizes its own labels from plan_type.';

alter table public.payment_approval_events drop column if exists plan_name;
alter table public.payment_approval_events
  add column plan_name text
  generated always as (
    case plan_type
      when 'starter_monthly' then 'Starter · 1 Month'
      when 'starter_quarterly' then 'Starter · 3 Months'
      when 'starter_half_yearly' then 'Starter · 6 Months'
      when 'starter_annual' then 'Starter · 1 Year'
      when 'pro_monthly' then 'Pro · 1 Month'
      when 'pro_quarterly' then 'Pro · 3 Months'
      when 'pro_half_yearly' then 'Pro · 6 Months'
      when 'pro_annual' then 'Pro · 1 Year'
      when 'firm_monthly' then 'Firm · 1 Month'
      when 'firm_quarterly' then 'Firm · 3 Months'
      when 'firm_half_yearly' then 'Firm · 6 Months'
      when 'firm_annual' then 'Firm · 1 Year'
      when 'firm_plus_quarterly' then 'Firm Plus · 3 Months'
      when 'firm_plus_half_yearly' then 'Firm Plus · 6 Months'
      when 'firm_plus_annual' then 'Firm Plus · 1 Year'
      when 'enterprise_quarterly' then 'Enterprise · 3 Months'
      when 'enterprise_half_yearly' then 'Enterprise · 6 Months'
      when 'enterprise_annual' then 'Enterprise · 1 Year'
      when 'monthly' then 'Starter · 1 Month'
      when 'quarterly' then 'Starter · 3 Months'
      when 'half_yearly' then 'Starter · 6 Months'
      when 'annual' then 'Starter · 1 Year'
      else plan_type
    end
  ) stored;

comment on column public.payment_approval_events.plan_name is
  'Readable name of the plan this approval event recorded, derived from plan_type. Generated, so the immutable ledger carries a name that can never disagree with its key.';
