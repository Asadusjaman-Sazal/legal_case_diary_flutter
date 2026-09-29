-- Task 17 audit follow-up — abandon_provisional_account(): the protected cleanup
-- that makes an abandoned onboarding "as if never created".
--
-- Why this exists. Task 17's Alignment Addendum asks for exactly this: a failed
-- `join_firm` keeps onboarding retryable, and if the user abandons it before a
-- successful redemption, the provisional profile/Auth account must be removed so
-- it is treated as never created. The client cannot do it — deleting an
-- `auth.users` row is beyond anything `authenticated` may do — so it has to be a
-- SECURITY DEFINER function. The interesting part is not the delete, it is the
-- guard that decides what "provisional" means.
--
-- The guard is deliberately paranoid, because the cost of a wrong deletion is a
-- lawyer's account. Every one of these refuses, and names itself as the reason:
--   * a firm in `profiles.firm_id`, a role other than `individual`, or a
--     subscription (the account has been used for something);
--   * owning a firm, holding a `firm_members` row, or having issued an invite;
--   * any row the account authored — cases, case history, notes, case
--     references, delete requests, conflict records, or custom reference data;
--   * a payment submission or approval, administrator rights, or a sync receipt.
-- Only an account with none of those is removed, which in practice means the one
-- a join-firm sign-up created moments earlier and never redeemed.
--
-- What removal means. `delete from auth.users` cascades to `profiles`,
-- `firm_members`, `user_preferences`, `case_notification_preferences`,
-- `invite_attempts` and `app_admins` — the abandoned account's failed-attempt
-- counter and its per-user preferences go with it, which is what "never created"
-- requires — and every reference that does **not** cascade (`firms.owner_id`,
-- `firm_invites.created_by`, `payment_submissions.user_id`,
-- `payment_approval_events.*`, `mutation_receipts.actor_id` and the domain rows)
-- is one the guard above has already refused. That is why the removal is a
-- single statement that cannot fail on a foreign key.

create or replace function public.abandon_provisional_account()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_reason text;
begin
  if v_user_id is null then
    return jsonb_build_object('status', 'unauthenticated');
  end if;

  -- The profile itself. A missing row is not a provisional account: the sign-up
  -- trigger creates one, so it is a bug state, and nothing is removed.
  select case
           when p.firm_id is not null then 'a firm'
           when p.role <> 'individual' then 'a role'
           when p.subscription_expiry is not null then 'a subscription'
         end
    into v_reason
    from public.profiles p
   where p.id = v_user_id;

  if not found then
    return jsonb_build_object('status', 'not_provisional', 'reason', 'no profile');
  end if;

  -- Everything the account may have done. The first table that has a row names
  -- the refusal, so a caller and a test both learn *why* without a second round
  -- trip. Each statement here is either a not-cascading reference or a row whose
  -- loss would be a loss of work.
  if v_reason is null then
    select t.reason
      into v_reason
      from (
        select 'firm ownership' as reason
          from public.firms f where f.owner_id = v_user_id
        union all select 'firm membership'
          from public.firm_members m where m.user_id = v_user_id
        union all select 'an issued invite'
          from public.firm_invites i where i.created_by = v_user_id
        union all select 'a payment'
          from public.payment_submissions s where s.user_id = v_user_id
        union all select 'an approval'
          from public.payment_approval_events e
         where e.user_id = v_user_id or e.approved_by = v_user_id
        union all select 'administrator rights'
          from public.app_admins a where a.user_id = v_user_id
        union all select 'a sync receipt'
          from public.mutation_receipts r where r.actor_id = v_user_id
        union all select 'cases'
          from public.cases c where c.user_id = v_user_id
        union all select 'case history'
          from public.case_history h where h.user_id = v_user_id
        union all select 'notes'
          from public.notes n where n.user_id = v_user_id
        union all select 'case references'
          from public.case_references r where r.user_id = v_user_id
        union all select 'delete requests'
          from public.delete_requests d
         where d.requested_by = v_user_id or d.reviewed_by = v_user_id
        union all select 'conflict records'
          from public.conflict_log l where l.user_id = v_user_id
        union all select 'custom courts'
          from public.courts x where x.user_id = v_user_id
        union all select 'custom court categories'
          from public.court_categories x where x.user_id = v_user_id
        union all select 'custom case categories'
          from public.case_categories x where x.user_id = v_user_id
        union all select 'custom steps'
          from public.steps x where x.user_id = v_user_id
        union all select 'custom case types'
          from public.case_types x where x.user_id = v_user_id
        union all select 'custom on-behalfs'
          from public.on_behalfs x where x.user_id = v_user_id
      ) t
     limit 1;
  end if;

  if v_reason is not null then
    return jsonb_build_object('status', 'not_provisional', 'reason', v_reason);
  end if;

  -- Provisional, and only then: remove the account. See the header for why this
  -- one statement is the whole removal.
  delete from auth.users u where u.id = v_user_id;

  return jsonb_build_object('status', 'removed');
end;
$$;

comment on function public.abandon_provisional_account() is
  'Owner-of-the-account cleanup for an abandoned join-firm onboarding: removes the caller''s own Auth account only when it is provably provisional (no firm, individual role, no subscription, no authored rows, no firm/payment/admin/sync activity), so it is treated as never created. Returns {"status":"removed"}, {"status":"not_provisional","reason":…} or {"status":"unauthenticated"}.';

-- A direct EXECUTE grant from Supabase's default privileges outlives a revoke of
-- PUBLIC, so `anon` is named explicitly — the same reason join_firm, approve_payment
-- and ensure_firm do it.
revoke all on function public.abandon_provisional_account() from public, anon;
grant execute on function public.abandon_provisional_account() to authenticated;
