-- Firm Mode Phase 7 — the stored subscription tier — together with Phase 8's
-- ten-plan ladder, which cannot land after it (see Phase 7's hazard in
-- `docs/firm_mode_blueprint.md`: no Firm plan key exists until the ladder does,
-- and the gate this phase's sibling migration adds is unsafe without one).
--
-- Two things land together because they cannot be separated: `approve_payment`
-- is rebuilt to accept the ladder's ten plan keys, and it is the write path that
-- records **which tier** the purchase bought. Before this migration the tier was
-- derived from `is_premium()` and from nothing else, so the lapse allowance
-- (§5.2) and the join-time seat check (§5.4) had no source for "the tier it last
-- held" and neither rule was expressible.
--
-- What the ladder is (Task 21's ruling, from `docs/firm_mode_blueprint.md` §5.3):
--
--   Pro        1 / 3 / 6 / 12 months at ৳100 / ৳285 / ৳540 / ৳1,000
--   Firm                     3 / 6 / 12 months at ৳855 / ৳1,620 / ৳3,000
--   Firm Plus                3 / 6 / 12 months at ৳1,710 / ৳3,240 / ৳6,000
--
-- Ten keys, at flat prices: the percentage-discount story is withdrawn, so Pro's
-- annual moves from the shipped ৳960 to ৳1,000 as a **deliberate price rise** and
-- every other price is simply its price.
--
-- Why the tier is stored rather than derived:
--
--   * the tier in force must survive a lapse, because the allowance a lapsed
--     account falls back to is *the tier it last held* (Pro 100, Firm 500,
--     Firm Plus 1,000 cases) — a derived value would read Free the moment
--     expiry passed and every lapsed account would fall to the 50-case wall;
--   * a mid-term downgrade must not overwrite the tier that was paid for, so a
--     lower-tier purchase writes `tier_pending` / `tier_pending_from` instead and
--     every reader takes the **effective** tier.
--
-- Client **update** writes to the new columns are closed by construction:
-- `20260929102500_phase3_column_privileges.sql` grants only `update (full_name)`
-- on `profiles` and `update (name)` on `firms`, and the default is to deny any
-- column a later migration adds. Client **insert** writes were not: both tables
-- carry a *table-level* `insert` for `authenticated` and `anon`
-- (`{anon=ardDxtm/postgres,authenticated=ardDxtm/postgres}`), and a table-level
-- grant reaches every column added afterwards. With `firms_insert_owner`
-- (`with check (owner_id = auth.uid())`) that was enough for any signed-in
-- account to mint a chamber whose stored tier said `firm_plus` without paying —
-- through the front door the gate below exists to hold shut. Section 2 therefore
-- narrows both grants to the columns that were public before this migration; the
-- only writer of `tier` is then the controlled admin path below.
--
-- Table class: `profiles` and `firms` remain **pull-only caches** on the device
-- and server-owned rows here; `payment_submissions` / `payment_approval_events`
-- remain **server-managed** (no client write policy exists for either). This
-- migration runs as the controlled admin write that re-issuing a function under
-- its existing grants requires.
--
-- APPLIED to the live project `lsthasywrdrhuuxnykau` on 2026-10-16, in file
-- order after `20261016110000_firm_mode_reference_in_use_guard.sql` and before
-- `20261016130000_firm_mode_seat_cap_and_creation_gate.sql`, and recorded in
-- `supabase_migrations.schema_migrations`, so `supabase db push` skips it.
--
-- Proven by `supabase/tests/firm_mode_stored_tier_test.sql`, which was run
-- against the applied project: the ladder prices all ten keys, the stored tier
-- follows them, a lapse keeps the tier, a downgrade waits its turn, and the
-- creation gate is Firm or above.

-- ---------------------------------------------------------------------------
-- 1. The stored tier, on both the account and the chamber.
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column if not exists tier text not null default 'free',
  add column if not exists tier_pending text,
  add column if not exists tier_pending_from timestamptz;

comment on column public.profiles.tier is
  'The subscription tier this account holds: free / pro / firm / firm_plus. Written at approval and never cleared by expiry, so it is the record of the last tier held — which is the allowance a lapse falls back to.';
comment on column public.profiles.tier_pending is
  'The tier a mid-term downgrade will fall to when the paid period ends, or null when no downgrade is waiting. The tier in force is never overwritten mid-term.';
comment on column public.profiles.tier_pending_from is
  'The expiry instant at which tier_pending starts. Readers take the effective tier — tier until this moment, then tier_pending.';

alter table public.firms
  add column if not exists tier text not null default 'free',
  add column if not exists tier_pending text,
  add column if not exists tier_pending_from timestamptz;

comment on column public.firms.tier is
  'The chamber tier, mirrored from its owner''s plan. The seat cap reads this (Pro 0, Firm 5, Firm Plus 20) and a lapsed member falls back to its allowance.';
comment on column public.firms.tier_pending is
  'The tier a mid-term downgrade will fall to, mirrored from the owner.';
comment on column public.firms.tier_pending_from is
  'The expiry instant at which firms.tier_pending starts.';

-- The stored value is a key, so it is constrained to the ladder's own keys. A
-- CHECK rather than an enum: a later tier is one migration, not a type change.
alter table public.profiles
  drop constraint if exists profiles_tier_check;
alter table public.profiles
  add constraint profiles_tier_check
  check (tier in ('free', 'pro', 'firm', 'firm_plus'));
alter table public.profiles
  drop constraint if exists profiles_tier_pending_check;
alter table public.profiles
  add constraint profiles_tier_pending_check
  check (tier_pending is null or tier_pending in ('free', 'pro', 'firm', 'firm_plus'));

alter table public.firms
  drop constraint if exists firms_tier_check;
alter table public.firms
  add constraint firms_tier_check
  check (tier in ('free', 'pro', 'firm', 'firm_plus'));
alter table public.firms
  drop constraint if exists firms_tier_pending_check;
alter table public.firms
  add constraint firms_tier_pending_check
  check (tier_pending is null or tier_pending in ('free', 'pro', 'firm', 'firm_plus'));

-- ---------------------------------------------------------------------------
-- 2. The new columns are not client-writable, at insert as well as at update.
-- ---------------------------------------------------------------------------
--
-- `revoke` first, then grant the column list back: a column-level `revoke`
-- cannot take a privilege away from a role that holds it at table level, so the
-- only reliable order is to drop the table-level grant and re-grant the exact
-- set that was writable before these columns existed. Nothing that worked before
-- stops working — an insert that named one of these columns still names it — and
-- no column added by a later migration inherits a write grant.
--
-- The three tier columns are absent from both lists deliberately.
revoke insert on public.profiles from authenticated, anon;
grant insert (
  id, full_name, firm_id, role, subscription_status, subscription_expiry,
  created_at, last_successful_sync_at, email, bar_association, membership_no,
  office_address, mobile_no
) on public.profiles to authenticated, anon;

revoke insert on public.firms from authenticated, anon;
grant insert (
  id, name, owner_id, created_at, subscription_status, subscription_expiry
) on public.firms to authenticated, anon;

-- ---------------------------------------------------------------------------
-- 3. The effective tier, as one function.
-- ---------------------------------------------------------------------------

-- "The tier in force right now", which is `tier` until the instant a waiting
-- downgrade starts and `tier_pending` from that instant on. Every reader takes
-- this rather than the raw column, so no gate re-implements the waiting rule.
--
-- `stable`, not `immutable`, and the label is load-bearing: the body reads
-- `now()`, so the same arguments do **not** always give the same answer. Marking
-- it immutable would let the planner fold one call at plan time and reuse that
-- answer for the rest of the statement — the exact mid-term flip this function
-- exists to express, frozen.
create or replace function public.effective_tier(p_tier text, p_pending text, p_from timestamptz)
returns text
language sql
stable
as $$
  select case
    when p_pending is null then coalesce(p_tier, 'free')
    when p_from is not null and now() >= p_from then p_pending
    else coalesce(p_tier, 'free')
  end;
$$;

comment on function public.effective_tier(text, text, timestamptz) is
  'The subscription tier in force right now: the stored tier until a waiting downgrade starts, the pending tier from that instant on. One definition, so no gate re-implements the mid-term rule.';

-- The ladder's order, so "is this an upgrade?" is one comparison rather than a
-- chain of inequalities repeated in every write path. Defined here, before
-- `approve_payment` below uses it.
create or replace function public.tier_rank(p_tier text)
returns integer
language sql
immutable
as $$
  select case coalesce(p_tier, 'free')
    when 'pro' then 1
    when 'firm' then 2
    when 'firm_plus' then 3
    else 0
  end;
$$;

comment on function public.tier_rank(text) is
  'The ladder''s order: free 0, pro 1, firm 2, firm_plus 3. Used to decide upgrade versus downgrade in one comparison.';

-- ---------------------------------------------------------------------------
-- 4. `approve_payment` rebuilt to the ten keys, writing the tier.
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
  c_pro_monthly_bdt constant integer := 100;
  c_pro_quarterly_bdt constant integer := 285;
  c_pro_half_yearly_bdt constant integer := 540;
  c_pro_annual_bdt constant integer := 1000;
  c_firm_quarterly_bdt constant integer := 855;
  c_firm_half_yearly_bdt constant integer := 1620;
  c_firm_annual_bdt constant integer := 3000;
  c_firm_plus_quarterly_bdt constant integer := 1710;
  c_firm_plus_half_yearly_bdt constant integer := 3240;
  c_firm_plus_annual_bdt constant integer := 6000;

  v_submission public.payment_submissions%rowtype;
  v_profile public.profiles%rowtype;
  v_event public.payment_approval_events%rowtype;
  v_previous_expiry timestamptz;
  v_new_expiry timestamptz;
  v_plan_amount integer;
  v_plan_months integer;
  v_tier text;
  v_effective text;
begin
  -- A GRANT to `authenticated` is not authorization: every caller shares that
  -- database role, so the registry itself decides.
  if not public.is_admin() then
    raise exception 'admin_required' using errcode = '42501';
  end if;

  -- Missing rows return a status without revealing anything about other users.
  select * into v_submission
    from public.payment_submissions s
   where s.id = payment_submission_id
   for update;

  if not found then
    return jsonb_build_object('status', 'not_found');
  end if;

  -- The parameter has the same name as the column, and `payment_approval_events`
  -- has that column, so the reference must be qualified: unqualified it is
  -- ambiguous and the function fails with "It could refer to either a PL/pgSQL
  -- variable or a table column" the first time it is called.
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
    -- A rejected submission needs a separately audited reset; approval is not
    -- a back door around that.
    return jsonb_build_object('status', 'already_resolved');
  end if;

  -- The ladder's ten keys and nothing else. Each `case` below is written over
  -- this same set, so a key cannot be accepted for its price but have no
  -- duration, or name a tier that does not exist.
  if v_submission.plan_type not in (
    'monthly', 'quarterly', 'half_yearly', 'annual',
    'firm_quarterly', 'firm_half_yearly', 'firm_annual',
    'firm_plus_quarterly', 'firm_plus_half_yearly', 'firm_plus_annual'
  ) then
    return jsonb_build_object('status', 'invalid_plan');
  end if;

  -- Each plan's own amount. The CASE is parenthesized because plpgsql reads an
  -- IF condition up to the first top-level `then`; an unwrapped CASE ends it at
  -- its own `when ... then` and the function then fails to compile with
  -- "syntax error at end of input".
  v_plan_amount := (case v_submission.plan_type
    when 'monthly' then c_pro_monthly_bdt
    when 'quarterly' then c_pro_quarterly_bdt
    when 'half_yearly' then c_pro_half_yearly_bdt
    when 'annual' then c_pro_annual_bdt
    when 'firm_quarterly' then c_firm_quarterly_bdt
    when 'firm_half_yearly' then c_firm_half_yearly_bdt
    when 'firm_annual' then c_firm_annual_bdt
    when 'firm_plus_quarterly' then c_firm_plus_quarterly_bdt
    when 'firm_plus_half_yearly' then c_firm_plus_half_yearly_bdt
    else c_firm_plus_annual_bdt
  end);

  if v_submission.amount <> v_plan_amount then
    return jsonb_build_object('status', 'invalid_amount');
  end if;

  -- Each plan's own duration, so the interval can never disagree with the
  -- amount validated above. A chamber buys 3, 6 or 12 months: there is no
  -- one-month Firm key to reach this CASE.
  v_plan_months := (case v_submission.plan_type
    when 'monthly' then 1
    when 'quarterly' then 3
    when 'half_yearly' then 6
    when 'annual' then 12
    when 'firm_quarterly' then 3
    when 'firm_half_yearly' then 6
    when 'firm_annual' then 12
    when 'firm_plus_quarterly' then 3
    when 'firm_plus_half_yearly' then 6
    else 12
  end);

  -- Which tier the purchase bought, from the key alone.
  v_tier := (case
    when v_submission.plan_type in ('monthly', 'quarterly', 'half_yearly', 'annual')
      then 'pro'
    when v_submission.plan_type in ('firm_quarterly', 'firm_half_yearly', 'firm_annual')
      then 'firm'
    else 'firm_plus'
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
  v_new_expiry := greatest(coalesce(v_previous_expiry, now()), now())
    + make_interval(months => v_plan_months);

  -- The tier in force, as it stands *before* this approval: a waiting downgrade
  -- that has started already counts, so buying during it does not resurrect the
  -- older tier.
  v_effective := public.effective_tier(
    v_profile.tier, v_profile.tier_pending, v_profile.tier_pending_from
  );

  -- The tier story, as one rule set (§5.4):
  --
  --   * an **upgrade or renewal at or above the tier in force** takes effect
  --     immediately and clears any waiting downgrade;
  --   * a **downgrade** never overwrites the tier that was paid for: it writes
  --     the pending pair, starting when the current period ends, and the tier in
  --     force is untouched.
  --
  -- Free is ranked below every paid tier, so an account whose first purchase is
  -- Pro is an upgrade, not a downgrade.
  if public.tier_rank(v_tier) >= public.tier_rank(v_effective) then
    update public.profiles p
       set subscription_expiry = v_new_expiry,
           subscription_status = 'premium',
           tier = v_tier,
           tier_pending = null,
           tier_pending_from = null
     where p.id = v_submission.user_id;
  else
    update public.profiles p
       set subscription_expiry = v_new_expiry,
           subscription_status = 'premium',
           tier_pending = v_tier,
           tier_pending_from = v_new_expiry
     where p.id = v_submission.user_id;
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
    'tier', v_tier
  );
end;
$$;

comment on function public.approve_payment(uuid) is
  'Approves one pending payment and extends the buyer''s subscription by the plan''s own duration. Task 21''s ten-plan ladder: Pro 1/3/6/12 months, Firm and Firm Plus 3/6/12. Writes the stored tier — immediately for an upgrade or renewal, as a pending downgrade otherwise. Idempotent: a repeat call never extends expiry twice.';

-- ---------------------------------------------------------------------------
-- 5. The mirror carries the tier to the chamber.
-- ---------------------------------------------------------------------------

-- `mirror_owner_subscription_to_firm` fired on `subscription_expiry` changes
-- only and copied two columns, so a **tier-only** change would never reach the
-- firm and the seat cap would read a stale value. Both its `of` list and its
-- `when` are widened here.
--
-- `tier_rank` is defined above `approve_payment` uses it and before this
-- function is replaced, so the whole file applies in one pass in order.
create or replace function public.mirror_owner_subscription_to_firm()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_tier text;
begin
  if new.firm_id is null then
    return new;
  end if;

  -- The tier the account actually holds, mid-term downgrade included.
  v_tier := public.effective_tier(new.tier, new.tier_pending, new.tier_pending_from);

  update public.firms f
     set subscription_status = new.subscription_status,
         subscription_expiry = new.subscription_expiry,
         tier = v_tier,
         tier_pending = new.tier_pending,
         tier_pending_from = new.tier_pending_from
   where f.owner_id = new.id;

  return new;
end;
$$;

comment on function public.mirror_owner_subscription_to_firm() is
  'Mirrors the owner''s subscription onto the chamber they own: status, expiry and the effective tier (with the pending pair), so the seat cap and a member''s allowance read the chamber''s own row.';

-- The live trigger is `trg_profiles_mirror_owner_subscription`, firing on
-- `update of subscription_expiry` **and** guarded by a `when` clause that only
-- let an expiry change through. Both halves had to be widened, and the trigger
-- is therefore replaced rather than edited: a tier-only change would otherwise
-- never reach the firm and the seat cap would read a stale tier.
--
-- Both names are dropped because the shipped name is the `trg_profiles_` one and
-- an earlier draft of this migration used the other; dropping both leaves
-- exactly one trigger, whichever name applied. A `when` clause is deliberately
-- omitted: the wider `of` list is the gate, and a row where none of those five
-- columns changed is not reached in the first place.
drop trigger if exists trg_profiles_mirror_owner_subscription on public.profiles;
drop trigger if exists trg_mirror_owner_subscription_to_firm on public.profiles;
create trigger trg_profiles_mirror_owner_subscription
  after update of
    subscription_status, subscription_expiry,
    tier, tier_pending, tier_pending_from
  on public.profiles
  for each row
  execute function public.mirror_owner_subscription_to_firm();

-- ---------------------------------------------------------------------------
-- 6. The readable plan names, extended to the ladder.
-- ---------------------------------------------------------------------------

-- `plan_name` is a GENERATED column, so its CASE cannot be altered in place:
-- the column is dropped and re-added with the wider CASE. That is safe here
-- because nothing writes it (it derives from `plan_type` on every read), so
-- every existing row is recomputed from its key and no value is lost.
alter table public.payment_submissions drop column if exists plan_name;
alter table public.payment_submissions
  add column plan_name text
  generated always as (
    case plan_type
      when 'monthly' then 'Pro · 1 Month'
      when 'quarterly' then 'Pro · 3 Months'
      when 'half_yearly' then 'Pro · 6 Months'
      when 'annual' then 'Pro · 1 Year'
      when 'firm_quarterly' then 'Firm · 3 Months'
      when 'firm_half_yearly' then 'Firm · 6 Months'
      when 'firm_annual' then 'Firm · 1 Year'
      when 'firm_plus_quarterly' then 'Firm Plus · 3 Months'
      when 'firm_plus_half_yearly' then 'Firm Plus · 6 Months'
      when 'firm_plus_annual' then 'Firm Plus · 1 Year'
      else plan_type
    end
  ) stored;

comment on column public.payment_submissions.plan_name is
  'Readable name of the plan the submission pays for, derived from plan_type (Pro · 1 Month through Firm Plus · 1 Year). Generated, so it cannot disagree with the key; the app localizes its own labels from plan_type.';

alter table public.payment_approval_events drop column if exists plan_name;
alter table public.payment_approval_events
  add column plan_name text
  generated always as (
    case plan_type
      when 'monthly' then 'Pro · 1 Month'
      when 'quarterly' then 'Pro · 3 Months'
      when 'half_yearly' then 'Pro · 6 Months'
      when 'annual' then 'Pro · 1 Year'
      when 'firm_quarterly' then 'Firm · 3 Months'
      when 'firm_half_yearly' then 'Firm · 6 Months'
      when 'firm_annual' then 'Firm · 1 Year'
      when 'firm_plus_quarterly' then 'Firm Plus · 3 Months'
      when 'firm_plus_half_yearly' then 'Firm Plus · 6 Months'
      when 'firm_plus_annual' then 'Firm Plus · 1 Year'
      else plan_type
    end
  ) stored;

comment on column public.payment_approval_events.plan_name is
  'Readable name of the plan this approval event recorded, derived from plan_type. Generated, so the immutable ledger carries a name that can never disagree with its key.';

-- ---------------------------------------------------------------------------
-- 7. Grants, unchanged in shape.
-- ---------------------------------------------------------------------------

-- `approve_payment` is re-issued under its existing grants: CREATE OR REPLACE
-- preserves them, and `effective_tier` / `tier_rank` are helpers for the
-- definer-owned paths, so they are not exposed to `authenticated`.
revoke all on function public.effective_tier(text, text, timestamptz) from public;
revoke all on function public.tier_rank(text) from public;

-- ---------------------------------------------------------------------------
-- 8. The one-time backfill: the tier an existing account already holds.
-- ---------------------------------------------------------------------------

-- The columns arrive with `default 'free'`, which is the right answer for an
-- account that never paid and the wrong one for the account that is paying
-- right now: every existing row would read `free`, so a chamber that answers 5
-- seats today would answer **no cap at all** — `firm_seat_cap` reads its tier,
-- and `join_firm` skips its whole seat check when that answer is null — and
-- §5.2's lapse allowance would read `free` for an account whose last tier was
-- Pro. The stored tier is a fact about the past that the schema has only just
-- learned how to record, so it is reconstructed rather than defaulted.
--
-- Two sources, in the order that matters: the payment ledger says what was
-- bought (`approve_payment` below writes exactly this reading for every future
-- purchase), and `is_premium()` covers a live entitlement the ledger has no row
-- for, such as a period granted from the dashboard. An account whose period has
-- run out *and* whose submission is in the ledger keeps `pro` — that is what
-- "the tier it last held" means, and it is why the ledger is read and not only
-- the live expiry. Nothing higher can pre-exist this migration: no Firm or Firm
-- Plus key was ever purchasable before it, so `pro` is the only paid tier an
-- existing row can be owed.
update public.profiles p
   set tier = 'pro'
 where p.tier = 'free'
   and (
     public.is_premium(p.id)
     or exists (
       select 1
         from public.payment_submissions s
        where s.user_id = p.id
          and s.status = 'approved'
          and s.plan_type in ('monthly', 'quarterly', 'half_yearly', 'annual')
     )
   );

-- The chamber's copy, by the rule the mirror uses: the tier in force. Written
-- out here rather than left to `mirror_owner_subscription_to_firm()` for two
-- reasons — the mirror returns early for a profile with no `firm_id`, and a
-- backfill must not depend on a trigger reading the row it has just changed.
update public.firms f
   set tier = public.effective_tier(p.tier, p.tier_pending, p.tier_pending_from)
  from public.profiles p
 where f.owner_id = p.id;
