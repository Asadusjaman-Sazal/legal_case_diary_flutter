-- Task 22 — the six-tier subscription ladder (user ruling, 2026-10-19).
--
-- The paywall now sells a ladder of six tiers, and the server must agree with
-- the client on every fact it validates or enforces:
--
--   Free        50 cases, offline only                                    ৳0
--   Starter    500 cases, one device              1/3/6/12 months  ৳60/180/300/600
--   Pro      1,000 cases, two devices             1/3/6/12 months  ৳120/360/600/1,200
--   Firm     2,500 cases, 5 members               3/6/12 months    ৳750/1,250/2,500
--   Firm Plus 6,000 cases, 12 members             3/6/12 months    ৳1,500/2,500/5,000
--   Enterprise  unlimited cases and members       3/6/12 months    ৳4,500/7,500/15,000
--
-- What this migration changes, in the order it has to:
--
--   1. **The stored tier vocabulary** gains `starter` and `enterprise`, and the
--      rows written under the old ladder are renamed: the old ten-plan ladder's
--      `pro` tier (৳100–৳1,000) is the new **Starter** tier, because the new Pro
--      is a different, higher rung. Expiry and pending pairs are untouched, so
--      no entitlement moves — only the name of the rung it sits on.
--   2. **The ladder's order** (`tier_rank`) is restated for six rungs.
--   3. **The ceilings** (`tier_case_ceiling`, `tier_lapse_allowance`) are stated
--      once, for the SQL paths that enforce them.
--   4. **Adding a case** is checked against the tier's ceiling, not only the
--      50-case free wall: a paid tier sells a case ceiling, and the client's Add
--      Case gate is UX, not the boundary.
--   5. **`approve_payment`** accepts the seventeen sellable keys (and the four
--      legacy keys, so an old pending submission can still be resolved) at their
--      own prices and durations, and it now queues **any different tier** bought
--      while the current plan is running: the paid term starts when the current
--      period ends, the tier in force is never overwritten mid-term, and only
--      one change may wait. A same-tier purchase is a renewal that pushes a
--      waiting change's start later by the term bought.
--   6. **The seat caps** follow the ladder: Firm 5, Firm Plus 12, Enterprise
--      unlimited, Starter/Pro 0. Chamber creation therefore needs the Firm tier
--      (rank 3), not the old Pro rung.
--   7. **The readable plan names** (`plan_name`) cover every key, old and new.
--
-- Table classes: `profiles`, `firms`, `payment_submissions`,
-- `payment_approval_events` and `subscription_cancellations` are server-managed
-- or pull-only caches on the device; no client write policy changes here. The
-- controlled admin write paths below are the only writers of a tier, a ceiling
-- answer or an approval.
--
-- APPLIED to the live project `lsthasywrdrhuuxnykau` on 2026-10-19, in file
-- order after `20261017120000_firm_mode_retention_window.sql`, and recorded in
-- `supabase_migrations.schema_migrations`, so `supabase db push` skips it.
--
-- Proven by `supabase/tests/subscription_ladder_test.sql`, run against the
-- applied project inside one rolled-back transaction (it prints `LADDER OK`):
-- every rung, a first purchase, a renewal, a queued change, the third-plan
-- refusal, a legacy key, a wrong amount, both generated names, the three seat
-- caps, the creation gate, and a Starter account filled to its 500-case ceiling
-- with the 501st insert refused. The applied project was then read back: the tier
-- CHECK lists the six keys, `approve_payment` carries the new keys,
-- `enforce_free_case_limit` is gone, `plan_name` is back on both ledgers, and no
-- row is left on the old `pro` rung.

-- ---------------------------------------------------------------------------
-- 1. The tier vocabulary: six keys, and the old ladder's rung renamed.
-- ---------------------------------------------------------------------------

-- Drop the old CHECKs before renaming `pro`, because the rename's target
-- (`starter`) is a key the old constraint does not accept.
alter table public.profiles drop constraint if exists profiles_tier_check;
alter table public.profiles drop constraint if exists profiles_tier_pending_check;
alter table public.firms drop constraint if exists firms_tier_check;
alter table public.firms drop constraint if exists firms_tier_pending_check;

-- The old ladder's Pro rung is the new Starter rung. This is a rename of the
-- rung, never of the entitlement: expiry, pending pairs and every case stay
-- exactly where they were.
update public.profiles set tier = 'starter' where tier = 'pro';
update public.profiles set tier_pending = 'starter' where tier_pending = 'pro';
update public.firms set tier = 'starter' where tier = 'pro';
update public.firms set tier_pending = 'starter' where tier_pending = 'pro';

alter table public.profiles
  add constraint profiles_tier_check
  check (tier in ('free', 'starter', 'pro', 'firm', 'firm_plus', 'enterprise'));
alter table public.profiles
  add constraint profiles_tier_pending_check
  check (
    tier_pending is null
    or tier_pending in ('free', 'starter', 'pro', 'firm', 'firm_plus', 'enterprise')
  );
alter table public.firms
  add constraint firms_tier_check
  check (tier in ('free', 'starter', 'pro', 'firm', 'firm_plus', 'enterprise'));
alter table public.firms
  add constraint firms_tier_pending_check
  check (
    tier_pending is null
    or tier_pending in ('free', 'starter', 'pro', 'firm', 'firm_plus', 'enterprise')
  );

comment on column public.profiles.tier is
  'The subscription tier this account holds: free / starter / pro / firm / firm_plus / enterprise. Written at approval and never cleared by expiry, so it is the record of the last tier held — which is the allowance a lapse falls back to.';
comment on column public.firms.tier is
  'The chamber tier, mirrored from its owner''s plan. The seat cap reads this (starter and pro 0, firm 5, firm_plus 12, enterprise unlimited) and a lapsed member falls back to its allowance.';

-- ---------------------------------------------------------------------------
-- 2. The ladder's order, for six rungs.
-- ---------------------------------------------------------------------------

create or replace function public.tier_rank(p_tier text)
returns integer
language sql
immutable
as $$
  select case coalesce(p_tier, 'free')
    when 'starter' then 1
    when 'pro' then 2
    when 'firm' then 3
    when 'firm_plus' then 4
    when 'enterprise' then 5
    else 0
  end;
$$;

comment on function public.tier_rank(text) is
  'The ladder''s order: free 0, starter 1, pro 2, firm 3, firm_plus 4, enterprise 5. Used to decide which rung a plan is on and to gate chamber creation.';

-- ---------------------------------------------------------------------------
-- 3. The ceilings, stated once.
-- ---------------------------------------------------------------------------

-- How many live cases a tier may hold while it is in force. `null` is
-- Enterprise's *Unlimited Cases*; every other rung, Free included, has a number.
-- A live entitlement whose stored tier is still `free` is handled by the caller
-- (a period granted from the dashboard must not invent the free wall).
create or replace function public.tier_case_ceiling(p_tier text)
returns integer
language sql
immutable
as $$
  select case coalesce(p_tier, 'free')
    when 'free' then 50
    when 'starter' then 500
    when 'pro' then 1000
    when 'firm' then 2500
    when 'firm_plus' then 6000
    else null
  end;
$$;

comment on function public.tier_case_ceiling(text) is
  'Live cases a tier may hold: free 50, starter 500, pro 1,000, firm 2,500, firm_plus 6,000, enterprise unlimited (null).';

-- How many cases, notes and references a **lapsed** holder of the tier may keep
-- writing. This is the allowance, not the ceiling — §5.2's numbers, restated on
-- the new rungs.
create or replace function public.tier_lapse_allowance(p_tier text)
returns integer
language sql
immutable
as $$
  select case coalesce(p_tier, 'free')
    when 'starter' then 100
    when 'pro' then 250
    when 'firm' then 500
    when 'firm_plus' then 1000
    when 'enterprise' then 2000
    else 0
  end;
$$;

comment on function public.tier_lapse_allowance(text) is
  'Cases, notes and references a lapsed holder may still write: starter 100, pro 250, firm 500, firm_plus 1,000, enterprise 2,000, free 0 (it is never lapsed).';

-- ---------------------------------------------------------------------------
-- 4. Adding a case is checked against the tier's ceiling.
-- ---------------------------------------------------------------------------

-- The shipped trigger checked the 50-case free wall only. A paid tier now sells
-- a ceiling too, and the device's Add Case gate is UX rather than the boundary:
-- a second device, a reinstall or a forged push must still be refused.
--
-- The scope is the diary the case belongs to: the chamber for a firm case (its
-- members share one ceiling), the author for an individual case. Soft-deleted
-- rows never count, and a live entitlement whose stored tier is still `free`
-- keeps no wall — that is a period granted outside the ladder, and inventing the
-- free wall for it would take away what the account already has.
create or replace function public.enforce_case_ceiling()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_tier text;
  v_ceiling integer;
  v_scope uuid;
  v_existing integer;
begin
  if new.is_deleted then
    return new;
  end if;

  if new.firm_id is not null then
    select public.effective_tier(f.tier, f.tier_pending, f.tier_pending_from)
      into v_tier
      from public.firms f
     where f.id = new.firm_id;
    v_scope := new.firm_id;
  else
    select public.effective_tier(p.tier, p.tier_pending, p.tier_pending_from)
      into v_tier
      from public.profiles p
     where p.id = new.user_id;
    v_scope := new.user_id;
  end if;

  -- A tier the ladder does not name, or a chamber with no tier in force, is not
  -- a number to refuse at.
  if v_tier is null then
    return new;
  end if;

  if v_tier = 'free' and public.is_premium(new.user_id) then
    return new;
  end if;

  v_ceiling := public.tier_case_ceiling(v_tier);
  if v_ceiling is null then
    return new;
  end if;

  -- Serialize count-and-insert for this diary: under READ COMMITTED two
  -- concurrent inserts could otherwise both read one below the ceiling.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext(v_scope::text)
  );

  if new.firm_id is not null then
    select pg_catalog.count(*) into v_existing
      from public.cases c
     where c.firm_id = v_scope
       and c.is_deleted = false;
  else
    select pg_catalog.count(*) into v_existing
      from public.cases c
     where c.user_id = v_scope
       and c.firm_id is null
       and c.is_deleted = false;
  end if;

  if v_existing >= v_ceiling then
    raise exception 'case_limit_reached'
      using errcode = 'P0001',
            hint = pg_catalog.format(
              'This plan holds %s live cases; the client shows the paywall.',
              v_ceiling
            );
  end if;

  return new;
end;
$$;

comment on function public.enforce_case_ceiling() is
  'Rejects an insert past the diary''s tier ceiling — the chamber''s for a firm case, the author''s for an individual one. Enterprise is uncapped; soft-deleted cases never count.';

-- The shipped trigger name is kept where it can be, so nothing that looks for
-- `trg_cases_free_limit` starts failing; the function behind it is the wider one.
drop trigger if exists trg_cases_case_ceiling on public.cases;
drop trigger if exists trg_cases_free_limit on public.cases;
create trigger trg_cases_case_ceiling
  before insert on public.cases
  for each row
  execute function public.enforce_case_ceiling();

-- The old function is now unreferenced. Dropping it is the point of the rename:
-- a reader who finds `enforce_free_case_limit` must not keep believing the wall
-- is free-only.
drop function if exists public.enforce_free_case_limit();

-- ---------------------------------------------------------------------------
-- 5. `approve_payment`: seventeen sellable keys, four legacy keys, and a queue.
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
  c_starter_monthly_bdt constant integer := 60;
  c_starter_quarterly_bdt constant integer := 180;
  c_starter_half_yearly_bdt constant integer := 300;
  c_starter_annual_bdt constant integer := 600;
  c_pro_monthly_bdt constant integer := 120;
  c_pro_quarterly_bdt constant integer := 360;
  c_pro_half_yearly_bdt constant integer := 600;
  c_pro_annual_bdt constant integer := 1200;
  c_firm_quarterly_bdt constant integer := 750;
  c_firm_half_yearly_bdt constant integer := 1250;
  c_firm_annual_bdt constant integer := 2500;
  c_firm_plus_quarterly_bdt constant integer := 1500;
  c_firm_plus_half_yearly_bdt constant integer := 2500;
  c_firm_plus_annual_bdt constant integer := 5000;
  c_enterprise_quarterly_bdt constant integer := 4500;
  c_enterprise_half_yearly_bdt constant integer := 7500;
  c_enterprise_annual_bdt constant integer := 15000;

  -- The four keys the old ten-plan ladder sold. They are never offered again,
  -- but a submission made before this migration may still be waiting, and
  -- refusing it would strand a payer's money with no way to resolve it. Their
  -- tier is Starter, because that is the rung their stored `pro` became.
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

  -- The ladder's keys and nothing else: seventeen sellable keys plus the four
  -- legacy ones. Each `case` below is written over the same set, so a key cannot
  -- be accepted for its price but have no duration, or name a tier that does not
  -- exist.
  if v_submission.plan_type not in (
    'starter_monthly', 'starter_quarterly', 'starter_half_yearly', 'starter_annual',
    'pro_monthly', 'pro_quarterly', 'pro_half_yearly', 'pro_annual',
    'firm_quarterly', 'firm_half_yearly', 'firm_annual',
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
  -- amount validated above. A chamber does not buy a single month: there is no
  -- one-month Firm, Firm Plus or Enterprise key.
  v_plan_months := (case v_submission.plan_type
    when 'starter_monthly' then 1
    when 'starter_quarterly' then 3
    when 'starter_half_yearly' then 6
    when 'starter_annual' then 12
    when 'pro_monthly' then 1
    when 'pro_quarterly' then 3
    when 'pro_half_yearly' then 6
    when 'pro_annual' then 12
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
  -- Starter now, matching the rename in section 1.
  v_tier := (case
    when v_submission.plan_type in (
      'starter_monthly', 'starter_quarterly', 'starter_half_yearly', 'starter_annual',
      'monthly', 'quarterly', 'half_yearly', 'annual'
    ) then 'starter'
    when v_submission.plan_type in (
      'pro_monthly', 'pro_quarterly', 'pro_half_yearly', 'pro_annual'
    ) then 'pro'
    when v_submission.plan_type in ('firm_quarterly', 'firm_half_yearly', 'firm_annual')
      then 'firm'
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
-- 6. Seat caps, and the chamber-creation gate on the Firm rung.
-- ---------------------------------------------------------------------------

-- Firm 5, Firm Plus 12, Enterprise unlimited (null), Starter and Pro 0. Pro's
-- arm is written out because `else null` would engulf it, and null means *no cap*
-- rather than *nobody joins*. A cap binds new joins only; nothing here removes a
-- member.
create or replace function public.firm_seat_cap(p_firm_id uuid)
returns integer
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select case public.effective_tier(f.tier, f.tier_pending, f.tier_pending_from)
           when 'firm' then 5
           when 'firm_plus' then 12
           when 'enterprise' then null
           when 'starter' then 0
           when 'pro' then 0
           else null
         end
    from public.firms f
   where f.id = p_firm_id;
$$;

comment on function public.firm_seat_cap(uuid) is
  'How many associates a chamber may hold: firm 5, firm_plus 12, enterprise unlimited (null), starter and pro 0 (no join may be taken), null when no paid tier is in force. Read from the chamber''s stored, effective tier.';

-- `ensure_firm` is re-issued for one line: the creation gate now needs the Firm
-- rung (rank 3) because Pro's seat cap is 0 on the new ladder. The rest of the
-- body is the version in `20261016130000`, unchanged, so a re-issue cannot
-- silently change behaviour.
create or replace function public.ensure_firm(p_name text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_now bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_name text := pg_catalog.btrim(coalesce(p_name, ''));
  v_firm public.firms%rowtype;
  v_has_firm boolean;
  v_created boolean := false;
  v_table text;
  v_case_tables text[] := array[
    'cases', 'case_history', 'notes', 'case_references'
  ];
  v_reference_tables text[] := array[
    'court_categories', 'case_categories', 'courts', 'steps', 'case_types',
    'on_behalfs'
  ];
  -- The tier required to create a chamber: Firm is rank 3 on the new ladder
  -- free 0 / starter 1 / pro 2 / firm 3 / firm_plus 4 / enterprise 5.
  c_required_tier_rank constant integer := 3;
  v_profile_tier text;
begin
  if v_user_id is null then
    return jsonb_build_object('status', 'unauthenticated');
  end if;

  select * into v_firm
    from public.firms f
   where f.owner_id = v_user_id
   order by f.created_at
   limit 1;
  v_has_firm := found;

  if exists (
    select 1
      from public.profiles p
     where p.id = v_user_id
       and p.firm_id is not null
       and (not v_has_firm or p.firm_id is distinct from v_firm.id)
  ) then
    return jsonb_build_object('status', 'member_of_another_firm');
  end if;

  if not v_has_firm then
    select public.effective_tier(p.tier, p.tier_pending, p.tier_pending_from)
      into v_profile_tier
      from public.profiles p
     where p.id = v_user_id;

    if public.tier_rank(v_profile_tier) < c_required_tier_rank then
      return jsonb_build_object('status', 'firm_tier_required');
    end if;

    insert into public.firms (
      name, owner_id, subscription_status, subscription_expiry,
      tier, tier_pending, tier_pending_from
    )
    select
      v_name,
      v_user_id,
      p.subscription_status,
      p.subscription_expiry,
      v_profile_tier,
      p.tier_pending,
      p.tier_pending_from
      from public.profiles p
     where p.id = v_user_id
    returning * into v_firm;

    if not found then
      raise exception 'ensure_firm: no profiles row for the caller'
        using errcode = 'P0001';
    end if;

    v_created := true;
  elsif v_name is distinct from v_firm.name then
    update public.firms f
       set name = v_name
     where f.id = v_firm.id
    returning * into v_firm;
  end if;

  update public.profiles p
     set firm_id = v_firm.id,
         role = 'owner'
   where p.id = v_user_id;

  insert into public.firm_members (
    firm_id, user_id, role, can_add, can_edit, can_delete,
    synced_at, permissions_synced_at
  )
  values (
    v_firm.id, v_user_id, 'owner', true, true, true, v_now, v_now
  )
  on conflict (firm_id, user_id) do update
    set role = 'owner',
        can_add = true,
        can_edit = true,
        can_delete = true,
        synced_at = excluded.synced_at,
        permissions_synced_at = excluded.permissions_synced_at;

  if v_created then
    foreach v_table in array v_case_tables loop
      execute format(
        'update public.%I t '
        '   set firm_id = $1, '
        '       version = coalesce(t.version, 1) + 1, '
        '       updated_at = $3 '
        ' where t.user_id = $2 '
        '   and t.firm_id is null',
        v_table
      ) using v_firm.id, v_user_id, v_now;
    end loop;

    foreach v_table in array v_reference_tables loop
      execute format(
        'update public.%I t '
        '   set firm_id = $1, '
        '       version = coalesce(t.version, 1) + 1, '
        '       updated_at = $3 '
        ' where t.user_id = $2 '
        '   and t.firm_id is null '
        '   and t.is_custom = true',
        v_table
      ) using v_firm.id, v_user_id, v_now;
    end loop;

    update public.delete_requests t
       set firm_id = v_firm.id,
           version = coalesce(t.version, 1) + 1,
           updated_at = v_now
     where t.requested_by = v_user_id
       and t.firm_id is null
       and t.status = 'pending';
  end if;

  return jsonb_build_object(
    'status', 'ready',
    'firm_id', v_firm.id,
    'name', v_firm.name
  );
end;
$$;

comment on function public.ensure_firm(text) is
  'Creates (or renames) the calling user''s chamber and moves them into it as owner. Requires the Firm tier or above: Starter and Pro sell no seat, so a chamber on either could never take a member. Idempotent — a re-call renames rather than re-creating, and only a first creation stamps the user''s existing rows with the firm.';

-- ---------------------------------------------------------------------------
-- 7. The readable plan names, old and new.
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

-- ---------------------------------------------------------------------------
-- 8. Grants: the new helpers are internal, the public paths keep their shape.
-- ---------------------------------------------------------------------------

revoke all on function public.tier_case_ceiling(text) from public, anon, authenticated;
revoke all on function public.tier_lapse_allowance(text) from public, anon, authenticated;
revoke all on function public.enforce_case_ceiling() from public, anon, authenticated;

-- `create or replace` preserves the ACLs of `approve_payment` and `ensure_firm`;
-- `firm_seat_cap` keeps the shape `20261016130000` gave it.
revoke all on function public.firm_seat_cap(uuid) from public, anon, authenticated;
grant execute on function public.firm_seat_cap(uuid) to authenticated;
