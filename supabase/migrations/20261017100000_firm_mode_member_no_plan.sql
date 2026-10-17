-- Firm mode Phase 9 — a member has no plan of their own.
--
-- Two changes, one rule (§5.1): an account working inside a chamber it does not
-- own is covered by that chamber's subscription, cannot buy a plan of its own,
-- and keeps any plan it bought before joining for the day it is individual
-- again. The server is the boundary; hiding a screen was never one.
--
-- 1. `has_sync_entitlement` counted *the caller's own* expiry OR the firm's.
--    That left the audit's live hole open: a member who had bought Pro before
--    joining kept pushing straight through the chamber's lapse, so the lapse
--    allowance had no server gate behind it for exactly that account. While
--    `profiles.firm_id` is set, only the chamber's mirrored expiry counts now.
--    The owner is covered by the same rule and loses nothing: the existing
--    `mirror_owner_subscription_to_firm()` keeps `firms.subscription_expiry`
--    equal to theirs, and `ensure_firm` copies it when a chamber is created.
--
-- 2. `payment_submissions_insert_own` becomes a member's refusal. The owner is
--    deliberately exempt: the owner's purchase IS the chamber's renewal (that is
--    what a Firm or Firm Plus plan buys), and the two entries Phase 9 removes
--    from a member — Settings > Subscription and the side menu's plan row — are
--    the owner's only routes to that purchase. Refusing every firm holder would
--    make a chamber impossible to renew, so the rule is "a member, not an
--    owner": `current_firm_id()` is null, or it names a chamber the caller owns.
--
-- Applied to the live project on 2026-10-17, and proved by
-- `supabase/tests/firm_mode_member_no_plan_test.sql`.

-- ---------------------------------------------------------------------------
-- 1. Entitlement: the chamber's expiry while the account holds a chamber.
-- ---------------------------------------------------------------------------

-- Same rule, same signature, same 48-hour grace. The CASE keeps the two
-- branches from ever OR-ing: a firm member never reads their own expiry, and an
-- individual never reads a firm's. Still derived, never `subscription_status`.
create or replace function public.has_sync_entitlement(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1 from public.profiles p
     where p.id = p_user_id
       and case
             when p.firm_id is not null then exists (
               select 1 from public.firms f
                where f.id = p.firm_id
                  and f.subscription_expiry is not null
                  and f.subscription_expiry + interval '48 hours' > now()
             )
             else p.subscription_expiry is not null
                  and p.subscription_expiry + interval '48 hours' > now()
           end
  );
$$;

comment on function public.has_sync_entitlement(uuid) is
  'Sync entitlement = the chamber''s subscription_expiry + 48h grace once profiles.firm_id is set, the caller''s own expiry while it is null; never reads subscription_status.';

-- ---------------------------------------------------------------------------
-- 2. A member's payment submission is refused by the policy itself.
-- ---------------------------------------------------------------------------

-- `current_firm_id()` and `is_firm_owner()` are SECURITY DEFINER (the Phase 3
-- access helpers), so this policy checks the caller's own profile and chamber
-- without recursing through either table's RLS. The insert still has to name the
-- caller, exactly as before.
drop policy if exists payment_submissions_insert_own on public.payment_submissions;
create policy payment_submissions_insert_own on public.payment_submissions
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and (
      public.current_firm_id() is null
      or public.is_firm_owner(public.current_firm_id())
    )
  );

-- No UPDATE or DELETE policy: approval is approve_payment() only.
