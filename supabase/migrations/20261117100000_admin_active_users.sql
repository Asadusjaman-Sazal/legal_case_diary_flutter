-- Admin Panel — Active Users (0.0.835).
--
-- The Admin Panel's newest page lists every account whose e-mail address is
-- confirmed and whose `auth.users` row still exists, oldest account first. A
-- deleted account cannot appear: deleting the auth row cascades the profile, and
-- this function reads the auth row as its anchor. There is deliberately no
-- activity window — an account that confirmed its address belongs here even if
-- it has not opened the app for months.
--
-- One call returns the whole page: identity and contact fields, the chamber's
-- name and the member's role, joining and last-active instants, the current
-- plan, its expiry and whether entitlement is live, the account's own work
-- counts, its active-device summary, and the five newest entries of its
-- subscription ledger. The server caps the ledger at five, so the client never
-- makes one request per card.
--
-- What "last active" means: this app has no "online now" flag. The later of the
-- server's `auth.users.last_sign_in_at` and the newest device heartbeat
-- (`user_devices.last_seen_at`, including a device that has since been revoked)
-- is the last evidence of the account being used. The page never claims more.
--
-- What "current plan" means: the 48-hour grace and effective tier are the app's
-- existing rules. `has_sync_entitlement()` supplies the live/lapsed answer, while
-- the effective tier comes from the chamber for a member and from the profile for
-- an individual. The plan key is the newest **approved** purchase of that tier
-- by the account that pays for it — the chamber owner for a member — so a queued
-- discount or a pending upgrade is not shown as the current plan.
--
-- Work counts are the account's own non-deleted rows only, never the chamber's
-- shared work. Device count and platforms are the active slots only; the
-- heartbeat behind `last_active_at` may come from a revoked device, because it
-- is still evidence that the account was used.
--
-- No table, policy or grant is widened. The function is SECURITY DEFINER,
-- admin-gated in its own body, executable by `authenticated` only, and performs
-- no writes. Applied once to `lsthasywrdrhuuxnykau` after
-- `supabase/tests/admin_active_users_test.sql` proved the contract.

create or replace function public.admin_list_verified_accounts()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
begin
  -- A grant to `authenticated` is shared by every signed-in account, so the
  -- registry itself decides whether this caller may read the page.
  if not public.is_admin() then
    raise exception 'admin_required' using errcode = '42501';
  end if;

  return (
    with accounts as (
      select
        u.id,
        coalesce(p.full_name, '') as full_name,
        coalesce(p.bar_association, '') as bar_association,
        coalesce(nullif(p.email, ''), u.email, '') as email,
        coalesce(p.mobile_no, '') as mobile_no,
        coalesce(nullif(p.role, ''), 'individual') as role,
        f.name as firm_name,
        u.created_at as joined_at,
        u.last_sign_in_at,
        -- The tier in force: a member holds the chamber's, an individual their
        -- own. `effective_tier` already accounts for a waiting downgrade.
        case
          when p.firm_id is not null then
            public.effective_tier(f.tier, f.tier_pending, f.tier_pending_from)
          else
            public.effective_tier(p.tier, p.tier_pending, p.tier_pending_from)
        end as effective_tier,
        case
          when p.firm_id is not null then f.subscription_expiry
          else p.subscription_expiry
        end as plan_expiry,
        -- Who pays for the running plan: the chamber owner for a member, the
        -- account itself for an individual.
        case
          when p.firm_id is not null then f.owner_id
          else u.id
        end as plan_owner_id
      from auth.users u
      left join public.profiles p on p.id = u.id
      left join public.firms f on f.id = p.firm_id
      where u.email_confirmed_at is not null
    ),
    with_plan as (
      select
        a.*,
        current_plan.plan_type as current_plan_key
      from accounts a
      left join lateral (
        select s.plan_type
        from public.payment_submissions s
        where s.user_id = a.plan_owner_id
          and s.status = 'approved'
          and (
            case
              when s.plan_type in (
                'monthly', 'quarterly', 'half_yearly', 'annual',
                'starter_monthly', 'starter_quarterly',
                'starter_half_yearly', 'starter_annual'
              ) then 'starter'
              when s.plan_type in (
                'pro_monthly', 'pro_quarterly',
                'pro_half_yearly', 'pro_annual'
              ) then 'pro'
              when s.plan_type in (
                'firm_monthly', 'firm_quarterly',
                'firm_half_yearly', 'firm_annual'
              ) then 'firm'
              when s.plan_type in (
                'firm_plus_quarterly',
                'firm_plus_half_yearly',
                'firm_plus_annual'
              ) then 'firm_plus'
              when s.plan_type in (
                'enterprise_quarterly',
                'enterprise_half_yearly',
                'enterprise_annual'
              ) then 'enterprise'
              else null
            end
          ) = a.effective_tier
        order by coalesce(s.approved_at, s.submitted_at) desc nulls last
        limit 1
      ) current_plan on true
    )
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', a.id,
          'full_name', a.full_name,
          'bar_association', a.bar_association,
          'email', a.email,
          'mobile_no', a.mobile_no,
          'firm_name', a.firm_name,
          'role', a.role,
          'joined_at', a.joined_at,
          'last_active_at', greatest(a.last_sign_in_at, devices.last_seen_at),
          'current_tier', a.effective_tier,
          'current_plan_key', a.current_plan_key,
          'plan_active', public.has_sync_entitlement(a.id),
          'plan_expiry', a.plan_expiry,
          'case_count', (
            select pg_catalog.count(*)
            from public.cases c
            where c.user_id = a.id and not c.is_deleted
          ),
          'note_count', (
            select pg_catalog.count(*)
            from public.notes n
            where n.user_id = a.id and not n.is_deleted
          ),
          'reference_count', (
            select pg_catalog.count(*)
            from public.case_references r
            where r.user_id = a.id and not r.is_deleted
          ),
          'device_count', coalesce(devices.active_device_count, 0),
          'platforms', coalesce(devices.platforms, '[]'::jsonb),
          'subscription_history', coalesce(history.entries, '[]'::jsonb)
        )
        order by a.joined_at asc, a.id asc
      ),
      '[]'::jsonb
    )
    from with_plan a
    left join lateral (
      select
        count(*) filter (where d.revoked_at is null) as active_device_count,
        -- A revoked device's last heartbeat still proves the account was used,
        -- which is why this maximum is taken across every device row.
        max(d.last_seen_at) as last_seen_at,
        coalesce(
          jsonb_agg(distinct d.platform order by d.platform)
            filter (where d.revoked_at is null),
          '[]'::jsonb
        ) as platforms
      from public.user_devices d
      where d.user_id = a.id
    ) devices on true
    left join lateral (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'plan_key', ledger.plan_key,
            'amount', ledger.amount,
            'status', ledger.status,
            'at', ledger.entry_at
          )
          order by ledger.entry_at desc nulls last
        ),
        '[]'::jsonb
      ) as entries
      from (
        select
          s.plan_type as plan_key,
          s.amount,
          s.status,
          case
            when s.status = 'approved'
              then coalesce(s.approved_at, s.submitted_at)
            else s.submitted_at
          end as entry_at
        from public.payment_submissions s
        where s.user_id = a.id
        union all
        select
          sc.plan_type as plan_key,
          sc.amount,
          'cancelled' as status,
          sc.cancelled_at as entry_at
        from public.subscription_cancellations sc
        where sc.user_id = a.id
        order by entry_at desc nulls last
        limit 5
      ) ledger
    ) history on true
  );
end;
$$;

comment on function public.admin_list_verified_accounts() is
  'Admin-only list of every account whose e-mail is confirmed, oldest account first. Each row carries its profile identity and chamber role, the later of last sign-in and newest device heartbeat, the live entitlement and effective tier (the chamber''s plan for a member), the account''s own non-deleted work counts, its active-device summary, and the five newest purchase/cancellation ledger entries. No writes and no widened RLS.';

-- Supabase's default privileges grant EXECUTE directly to `anon` and
-- `authenticated`; re-assert the intended grant explicitly, as the other admin
-- queries do. A signed-in account still passes through `is_admin()` above.
revoke all on function public.admin_list_verified_accounts()
  from public, anon;
grant execute on function public.admin_list_verified_accounts()
  to authenticated;
