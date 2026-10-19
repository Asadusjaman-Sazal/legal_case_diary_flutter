-- Subscription History — cancelling a live plan, reconstructed from the live
-- project on 2026-10-19.
--
-- **Why this file exists, and why it is a reconstruction.** The cancellation
-- table, its own-row policy and `cancel_subscription()` were applied to the
-- writable project `lsthasywrdrhuuxnykau` on 2026-10-18 under version
-- `20261018100000`, but that version was recorded **without its statements**
-- and no migration file was committed. The app therefore called an RPC that no
-- file in this repository defined, and `tool/apply_supabase_migrations.dart`
-- reported the version as drift. This file is that missing record: the table,
-- policy, grants and function are copied from the applied project's own
-- catalogs (`pg_get_functiondef`, `information_schema`, `pg_policies`,
-- `pg_class`) rather than invented from the client's call sites. The function's
-- logic is byte-for-byte the live one; only its lapse-allowance comment was
-- updated from the old Pro/Firm/Firm Plus numbers to the six-tier ladder's.
--
-- The version in the filename is the version the live project already holds, so
-- the applier skips it there and its history stays truthful. Every statement is
-- idempotent (`if not exists`, `create or replace`, `drop policy if exists`), so
-- a fresh project can apply this file and re-running it changes nothing.
--
-- Table class: `subscription_cancellations` is **server-managed**. Only
-- `cancel_subscription()` writes it, and a signed-in client may select its own
-- rows under RLS; there is deliberately no insert, update or delete policy.
--
-- Proven on 2026-10-19 by running this file inside a rolled-back transaction on
-- the applied project (it re-created the same objects with no error) and by the
-- client's own cancellation cases in
-- `test/features/subscription_details_screen_test.dart`.

-- ---------------------------------------------------------------------------
-- 1. The ledger row.
-- ---------------------------------------------------------------------------

create table if not exists public.subscription_cancellations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  -- The plan that was running and what was actually paid for it. Both are
  -- nullable because a period granted outside the ladder has no purchase row to
  -- name; the cancellation still happened and its expiry is still a fact.
  plan_type text,
  amount integer,
  -- The expiry that was ended, and the instant it was ended. Both required:
  -- a cancellation without either cannot be reconciled against a statement.
  previous_expiry timestamptz not null,
  cancelled_at timestamptz not null default now()
);

comment on table public.subscription_cancellations is
  'Server-managed. One row per cancelled paid plan: the plan that was running, what was paid for it, the expiry that was ended and the instant it was cancelled. Written only by cancel_subscription(); the client may read its own rows.';

-- One account's ledger, newest first — the read the Subscription History list
-- makes.
create index if not exists subscription_cancellations_user_cancelled_at_idx
  on public.subscription_cancellations (user_id, cancelled_at desc);

-- ---------------------------------------------------------------------------
-- 2. Read your own rows, and nothing else.
-- ---------------------------------------------------------------------------

alter table public.subscription_cancellations enable row level security;

-- RLS is a second fence, not the first: the table-level grants are narrowed to
-- the one verb a client needs, so even a mistake in a policy cannot let a
-- client write this ledger.
revoke all on table public.subscription_cancellations from public, anon, authenticated;
grant select on table public.subscription_cancellations to authenticated;
grant all on table public.subscription_cancellations to service_role;

drop policy if exists subscription_cancellations_select_own
  on public.subscription_cancellations;
create policy subscription_cancellations_select_own
  on public.subscription_cancellations
  for select
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 3. The one write path.
-- ---------------------------------------------------------------------------

create or replace function public.cancel_subscription()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  -- The account is the session's own, never a parameter: this ends the caller's
  -- plan or nothing.
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_plan_type text;
  v_amount integer;
  v_now timestamptz := now();
  v_previous_expiry timestamptz;
  v_cancelled_at timestamptz;
begin
  if v_user_id is null then
    return jsonb_build_object('status', 'unauthenticated');
  end if;

  select * into v_profile
    from public.profiles p
   where p.id = v_user_id
   for update;

  if not found then
    return jsonb_build_object('status', 'not_found');
  end if;

  -- A member's plan is the chamber's (§5.1), so their own row is not where their
  -- entitlement lives and ending it would change nothing while silently
  -- discarding paid time they keep for later. Refused instead. The owner is not
  -- a member: his own row *is* the chamber's plan, and the existing
  -- `mirror_owner_subscription_to_firm()` carries the new expiry to it.
  if v_profile.firm_id is not null
     and v_profile.role in ('associate', 'viewer') then
    return jsonb_build_object('status', 'firm_member');
  end if;

  -- Only a live paid period can be cancelled, and the test is the same derived
  -- rule every gate reads, so this cannot disagree with `is_premium()` about
  -- whether anything is running.
  if v_profile.subscription_expiry is null
     or v_profile.subscription_expiry + interval '48 hours' <= v_now then
    return jsonb_build_object('status', 'no_active_plan');
  end if;

  v_previous_expiry := v_profile.subscription_expiry;

  -- The plan that is running is the newest approved purchase — the same rule the
  -- app's Current Plan uses — and the amount recorded is what was actually paid
  -- for it rather than today's price list.
  select s.plan_type, s.amount
    into v_plan_type, v_amount
    from public.payment_submissions s
   where s.user_id = v_user_id
     and s.status = 'approved'
   order by coalesce(s.approved_at, s.submitted_at) desc
   limit 1;

  -- Backdated past the 48-hour grace, with an hour of cushion at the boundary,
  -- so the next entitlement check is false rather than true for two more days.
  -- The stored tier is deliberately untouched: it is the record of the last tier
  -- held, and it is what gives the account its lapse allowance (Starter 100,
  -- Pro 250, Firm 500, Firm Plus 1,000, Enterprise 2,000) instead of dropping it
  -- to Free.
  update public.profiles p
     set subscription_expiry = v_now - interval '49 hours',
         subscription_status = 'cancelled'
   where p.id = v_user_id;

  insert into public.subscription_cancellations (
    user_id, plan_type, amount, previous_expiry, cancelled_at
  )
  values (v_user_id, v_plan_type, v_amount, v_previous_expiry, v_now)
  returning cancelled_at into v_cancelled_at;

  return jsonb_build_object(
    'status', 'cancelled',
    'plan_type', v_plan_type,
    'amount', v_amount,
    'previous_expiry', v_previous_expiry,
    'cancelled_at', v_cancelled_at
  );
end;
$$;

comment on function public.cancel_subscription() is
  'Ends the caller''s own live paid plan: backdates subscription_expiry past the 48-hour grace so entitlement is false at once, records one subscription_cancellations row (plan, amount, the expiry ended, the instant) and leaves the stored tier alone so the account lands on its lapse allowance. Answers status firm_member for an associate or viewer (the chamber holds the plan), no_active_plan for a free or lapsed account, not_found without a profile row, and unauthenticated without a session.';

-- The RPC is for signed-in callers only. `create or replace` preserves an ACL,
-- but stating it here is what makes this file a complete record: a fresh project
-- gets the same answer as the live one.
revoke all on function public.cancel_subscription() from public, anon;
grant execute on function public.cancel_subscription() to authenticated;
grant execute on function public.cancel_subscription() to service_role;
