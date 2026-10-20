-- ===========================================================================
-- 2026-10-20 — Enterprise gets real limits, and Firm Plus drops to ten seats.
--
-- **Why.** Enterprise sold "unlimited cases and unlimited members". Neither
-- number was enforced anywhere: `tier_case_ceiling` answered null, so the Add
-- Case trigger returned early, and `firm_seat_cap` answered null, which every
-- join gate reads as "no ceiling". One buyer could therefore hand out unlimited
-- free seats and grow storage without a stop, against a paid plan whose card
-- promised nothing it could be held to. Firm Plus also promised twelve members
-- while the plan is being refined to ten (user ruling, 2026-10-20).
--
-- **What changes.** Two functions, and nothing else:
--
--   1. `tier_case_ceiling('enterprise')` — 20,000 instead of null. The ceiling
--      the Add Case trigger reads is now a number on every sold tier, so the
--      trigger's "no ceiling" early return no longer fires for Enterprise.
--   2. `firm_seat_cap` — Firm Plus 10 (was 12), Enterprise 20 (was null, i.e.
--      uncapped), Firm 5, Starter and Pro 0, unchanged.
--
-- 20,000 cases is decades of work for a twenty-lawyer chamber, so no honest
-- firm reaches it; it exists to cap the storage and sync bill an abusive
-- account can create, not to sell a smaller diary.
--
-- **What does not change.** `approve_payment` (no price or key moves),
-- `tier_lapse_allowance` (Enterprise lapses to 2,000, as before), `tier_rank`,
-- `enforce_case_ceiling`'s body (it reads the ceiling function, so it follows
-- this migration without being re-issued), `ensure_firm`'s gate, and every
-- existing membership row. A seat cap binds **new joins only**: a chamber that
-- already holds eleven or twelve members keeps them.
--
-- **Why it must ship with the app.** The card prints these numbers and the
-- Terms state them, so a client that says 10 and 20,000 against a server that
-- says 12 and "no limit" is a promise the app breaks at the first invite.
--
-- **Status.** Written, **NOT APPLIED YET**. Apply after
-- `20261020100000_payment_ladder_v2_prices.sql`; the app's Plan screen and the
-- Terms are the client half. Until it is applied, the live project still caps
-- Firm Plus at 12 seats and Enterprise at nothing, and
-- `supabase/tests/subscription_ladder_test.sql`'s new assertions will fail —
-- which is the proof that the apply is still owed, not a defect in it.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. The case ceiling: Enterprise is capped too.
-- ---------------------------------------------------------------------------

-- Enterprise's arm is written out beside the others, so `else null` now means
-- only "a tier this ladder does not name" rather than "the top tier".
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
    when 'enterprise' then 20000
    else null
  end;
$$;

comment on function public.tier_case_ceiling(text) is
  'Live cases a tier may hold: free 50, starter 500, pro 1,000, firm 2,500, firm_plus 6,000, enterprise 20,000. Null only for a tier the ladder does not name.';

-- ---------------------------------------------------------------------------
-- 2. The seat cap: Firm Plus 10, Enterprise 20.
-- ---------------------------------------------------------------------------

-- Same shape as `20261019100000`: read from the chamber's effective tier, and
-- write every arm out so `else null` cannot engulf a real number. Null still
-- means "no paid tier in force", which refuses nothing by itself; only Starter
-- and Pro's explicit 0 refuses every join.
create or replace function public.firm_seat_cap(p_firm_id uuid)
returns integer
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select case public.effective_tier(f.tier, f.tier_pending, f.tier_pending_from)
           when 'firm' then 5
           when 'firm_plus' then 10
           when 'enterprise' then 20
           when 'starter' then 0
           when 'pro' then 0
           else null
         end
    from public.firms f
   where f.id = p_firm_id;
$$;

comment on function public.firm_seat_cap(uuid) is
  'How many members a chamber may hold, owner included: firm 5, firm_plus 10, enterprise 20, starter and pro 0 (no join may be taken), null when no paid tier is in force. Read from the chamber''s stored, effective tier; binds new joins only.';

-- ---------------------------------------------------------------------------
-- 3. Grants: unchanged in shape, re-asserted because the bodies were replaced.
-- ---------------------------------------------------------------------------

revoke all on function public.tier_case_ceiling(text) from public, anon, authenticated;
revoke all on function public.firm_seat_cap(uuid) from public, anon, authenticated;
grant execute on function public.firm_seat_cap(uuid) to authenticated;
