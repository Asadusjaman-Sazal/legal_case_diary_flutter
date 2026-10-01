-- Task 21 follow-up — the subscription sells four durations, not two.
--
-- The paywall now offers 1 Month (৳100), 3 Months (৳285), 6 Months (৳550) and
-- 1 Year (৳1,000). `approve_payment` from `20260929102200` knew only `monthly`
-- and `annual` and extended by a month or a year, so a submission for one of the
-- two new plans would have been refused `invalid_plan` and could never be
-- approved. This migration replaces the function with the four-plan version.
--
-- `plan_type` is plain `text` on `payment_submissions` (there is no check
-- constraint to alter), so the only server change is the function body: the
-- accepted keys, the amount each key must carry, and the interval each key
-- extends by. Everything else — the admin gate, the `FOR UPDATE` lock, the
-- idempotency, the owner-firm mirror and the single immutable audit event — is
-- unchanged; only the four plan facts move.
--
-- Table class: `payment_submissions` and `payment_approval_events` remain
-- server-managed (no client write policy exists for either).

create or replace function public.approve_payment(payment_submission_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  -- Configured plan prices, in BDT. Kept here as named constants so a price
  -- change is one migration, and so the RPC validates the amount the server
  -- believes rather than the amount the client sent.
  c_monthly_bdt constant integer := 100;
  c_quarterly_bdt constant integer := 285;
  c_half_yearly_bdt constant integer := 550;
  c_annual_bdt constant integer := 1000;

  v_submission public.payment_submissions%rowtype;
  v_profile public.profiles%rowtype;
  v_event public.payment_approval_events%rowtype;
  v_previous_expiry timestamptz;
  v_new_expiry timestamptz;
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

  if v_submission.plan_type not in (
    'monthly', 'quarterly', 'half_yearly', 'annual'
  ) then
    return jsonb_build_object('status', 'invalid_plan');
  end if;

  -- The CASE is parenthesized because plpgsql reads an IF condition up to the
  -- first top-level `then`; an unwrapped CASE ends it at its own `when ... then`
  -- and the function then fails to compile with "syntax error at end of input".
  if v_submission.amount <> (case v_submission.plan_type
                               when 'monthly' then c_monthly_bdt
                               when 'quarterly' then c_quarterly_bdt
                               when 'half_yearly' then c_half_yearly_bdt
                               else c_annual_bdt
                             end) then
    return jsonb_build_object('status', 'invalid_amount');
  end if;

  select * into v_profile
    from public.profiles p
   where p.id = v_submission.user_id
   for update;

  if not found then
    return jsonb_build_object('status', 'not_found');
  end if;

  -- Server time decides the base; a lapsed-but-not-expired window is not lost.
  -- The interval is the plan's own duration, so it can never disagree with the
  -- amount validated above.
  v_previous_expiry := v_profile.subscription_expiry;
  v_new_expiry := greatest(coalesce(v_previous_expiry, now()), now())
    + case v_submission.plan_type
        when 'monthly' then interval '1 month'
        when 'quarterly' then interval '3 months'
        when 'half_yearly' then interval '6 months'
        else interval '1 year'
      end;

  update public.profiles p
     set subscription_expiry = v_new_expiry,
         subscription_status = 'premium'
   where p.id = v_submission.user_id;

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
    'new_expiry', v_new_expiry
  );
end;
$$;

comment on function public.approve_payment(uuid) is
  'Admin-only atomic MFS approval: lock, validate, extend entitlement (1/3/6/12 months), mirror to the firm, one audit event.';

-- The owner must not be reachable by ordinary clients, and the grant is for the
-- shared `authenticated` role only (the app_admins check above is the real gate).
-- `from public` is not enough on Supabase: its default privileges grant EXECUTE
-- on every new function in `public` *directly* to `anon` and `authenticated`,
-- and a direct grant outlives a revoke aimed at PUBLIC.
revoke all on function public.approve_payment(uuid) from public, anon;
grant execute on function public.approve_payment(uuid) to authenticated;
