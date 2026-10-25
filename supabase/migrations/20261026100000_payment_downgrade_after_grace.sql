-- ===========================================================================
-- 2026-10-26 — A downgrade's smaller capacity waits for the 48-hour grace.
--
-- **Why.** `approve_payment` starts a queued downgrade at the instant the paid
-- period ends, while sync entitlement keeps running for another 48 hours. A
-- chamber would therefore lose devices and associates *during* the grace. The
-- user's ruling: the old plan's capacity applies for the whole grace; the lower
-- tier starts when the grace ends, and only then may an over-capacity chamber be
-- trimmed (`20261026110000_firm_shared_capacity.sql`).
--
-- **What changes, and only this:**
--
--   1. `tier_seat_cap(text)` is defined here because the new guard below needs
--      the tier's slot count. It is the one mapping (free/starter/pro 0, Firm 5,
--      Firm Plus 10, Enterprise 20) and the capacity migration reuses it.
--   2. `approve_payment` computes `v_capacity_start = old expiry + 48h` (or now,
--      when that is already past) and uses it as the queued start. The expiry
--      still grows from the old period's end, so the grace never adds 48h of
--      free paid term.
--   3. A **lower-tier purchase made inside the grace** no longer applies at
--      once: it is written as the pending pair starting at the grace's end.
--   4. An **upgrade bought after a pending change has started** is applied
--      immediately and clears the pending pair. The shipped code took the queue
--      branch and reported a future `starts_at` while the tier was already in
--      effect.
--   5. A chamber owner may no longer buy Starter or Pro (0 seats). It would sign
--      out every associate or leave the owner with one reserved device while the
--      card promises two. They must dissolve the chamber first.
--
-- **Backfill.** Existing queued downgrades get the grace too. The live code
-- writes `tier_pending_from` as the **old expiry** (not `subscription_expiry`),
-- so the predicate is "a lower pending whose start is still inside the window"
-- (`pending_from + 48h > now()`), not the old equality. Only `profiles` is
-- updated: `trg_profiles_mirror_owner_subscription` copies the new value to the
-- owner's `firms` row, and updating both would add 48h twice.
--
-- No grant changes: `create or replace` preserves the ACLs
-- `20261019100000` left on `approve_payment`.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. The tier's slot count, used by the no-zero-seat guard below.
-- ---------------------------------------------------------------------------

create or replace function public.tier_seat_cap(p_tier text)
returns integer
language sql
immutable
as $$
  select case coalesce(p_tier, 'free')
    when 'firm' then 5
    when 'firm_plus' then 10
    when 'enterprise' then 20
    else 0
  end;
$$;

comment on function public.tier_seat_cap(text) is
  'Slots a tier sells in a chamber: firm 5, firm_plus 10, enterprise 20, everything else 0 (no join may be taken).';

revoke all on function public.tier_seat_cap(text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. `approve_payment`: the grace-aware start and the zero-seat guard.
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
  -- but a submission made before the revamp may still be waiting.
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
  -- The instant the newly bought (lower) tier may start: the end of the period
  -- it replaces, plus the 48-hour grace. Never later than now.
  v_capacity_start timestamptz;
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
  -- legacy ones.
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

  -- A chamber owner cannot buy a plan with no seats. It would either sign out
  -- every associate later or leave the owner with one reserved device while the
  -- card promises two, and the chamber would be permanently useless. Dissolve
  -- first, then buy an individual plan.
  if public.tier_seat_cap(v_tier) = 0
     and exists (
       select 1
         from public.firms f
        where f.owner_id = v_submission.user_id
     ) then
    return jsonb_build_object('status', 'chamber_requires_firm_plan');
  end if;

  -- Server time decides the base; a lapsed-but-not-expired window is not lost.
  v_previous_expiry := v_profile.subscription_expiry;
  v_new_expiry := greatest(coalesce(v_previous_expiry, v_now), v_now)
    + make_interval(months => v_plan_months);

  -- The instant the newly bought tier's capacity may start. A lower tier waits
  -- for the grace that guards the period it replaces; a purchase made after the
  -- grace, or after a lapsed period, starts at once.
  v_capacity_start := case
    when v_previous_expiry is null then v_now
    when v_previous_expiry + interval '48 hours' > v_now
      then v_previous_expiry + interval '48 hours'
    else v_now
  end;

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
    -- Nothing is running. A lower tier bought **inside the grace** waits for the
    -- grace to end, so the expired plan keeps its capacity for the full 48h; a
    -- purchase after the grace replaces the tier at once.
    if public.tier_rank(v_tier) < public.tier_rank(v_effective)
       and v_capacity_start > v_now then
      update public.profiles p
         set subscription_expiry = v_new_expiry,
             subscription_status = 'premium',
             tier_pending = v_tier,
             tier_pending_from = v_capacity_start
       where p.id = v_submission.user_id;
      v_queue_start := v_capacity_start;
      v_queued := true;
    else
      update public.profiles p
         set subscription_expiry = v_new_expiry,
             subscription_status = 'premium',
             tier = v_tier,
             tier_pending = null,
             tier_pending_from = null
       where p.id = v_submission.user_id;
    end if;
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
    -- without deciding what the user actually wants; the server refuses.
    return jsonb_build_object(
      'status', 'change_pending',
      'pending_tier', v_profile.tier_pending,
      'pending_from', v_profile.tier_pending_from
    );
  else
    -- No unstarted change is waiting (a started one may still be in force). An
    -- upgrade now takes effect at once and clears the pending pair; a lower tier
    -- is queued to start when the paid period + grace ends.
    if public.tier_rank(v_tier) > public.tier_rank(v_effective) then
      update public.profiles p
         set subscription_expiry = v_new_expiry,
             subscription_status = 'premium',
             tier = v_tier,
             tier_pending = null,
             tier_pending_from = null
       where p.id = v_submission.user_id;
    else
      v_queue_start := v_capacity_start;
      -- The paid term still starts at the old period's end; the grace delays
      -- only the tier's start, never the paid time.
      v_new_expiry := greatest(coalesce(v_previous_expiry, v_now), v_now)
        + make_interval(months => v_plan_months);
      update public.profiles p
         set subscription_expiry = v_new_expiry,
             subscription_status = 'premium',
             tier_pending = v_tier,
             tier_pending_from = v_queue_start
       where p.id = v_submission.user_id;
      v_queued := true;
    end if;
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
  'Approves one pending payment and grants the plan it names. A lower tier starts 48 hours after the paid period it replaces ends; an upgrade or same-tier renewal starts at once. Refuses a Starter/Pro purchase by a chamber owner. Idempotent; validates the key, amount and duration on the server ladder.';

-- ---------------------------------------------------------------------------
-- 3. Existing queued downgrades get the same grace.
-- ---------------------------------------------------------------------------

-- `tier_pending_from` is the OLD expiry in the live code, so the predicate is
-- "the start is still inside the 48h window", not equality with the new expiry.
-- A start older than 48h is left alone (its grace has long passed); a recently
-- started one gets the remainder. Only `profiles` is written: the mirror trigger
-- copies the value to `firms`, and writing both would add 48h twice.
do $$
declare
  v_count integer;
begin
  update public.profiles p
     set tier_pending_from = p.tier_pending_from + interval '48 hours'
   where p.tier_pending is not null
     and p.tier_pending_from is not null
     and p.tier_pending_from + interval '48 hours' > now()
     and public.tier_rank(p.tier_pending) < public.tier_rank(p.tier);
  get diagnostics v_count = row_count;
  raise notice 'downgrade grace backfill: % profile(s) shifted by 48h (mirrored to firms)', v_count;
end;
$$;
