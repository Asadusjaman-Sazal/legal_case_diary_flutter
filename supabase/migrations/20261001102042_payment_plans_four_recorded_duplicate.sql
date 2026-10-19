-- Recorded duplicate — `payment_plans_four`, applied under a connector version.
--
-- `supabase_migrations.schema_migrations` holds version `20261001102042` with
-- the exact `approve_payment` body below: it is the four-plan ladder that
-- `20261001010000_payment_plans_four.sql` also ships, applied again through a
-- connector that generated its own timestamp instead of using the file's
-- version. No SQL was missing from the repository, but the project's own
-- history had a statement with no file behind it.
--
-- This file is that statement verbatim, so the recorded history and the
-- migration set agree and the applier's drift warning has nothing to report.
-- It is superseded by every later approval migration (the discounted prices,
-- the ten-plan ladder and the six-tier ladder); on a fresh project it runs in
-- filename order before them and changes nothing that survives. Version
-- `20261001102042` is already recorded on the live project, so the applier
-- skips it there.
--
-- Table class: `payment_submissions` / `payment_approval_events` stay
-- server-managed; only the function body is restated.

create or replace function public.approve_payment(payment_submission_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
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

  if v_submission.plan_type not in (
    'monthly', 'quarterly', 'half_yearly', 'annual'
  ) then
    return jsonb_build_object('status', 'invalid_plan');
  end if;

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

revoke all on function public.approve_payment(uuid) from public, anon;
grant execute on function public.approve_payment(uuid) to authenticated;
