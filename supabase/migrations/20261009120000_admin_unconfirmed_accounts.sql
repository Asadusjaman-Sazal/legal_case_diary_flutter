-- admin_list_unconfirmed_accounts() / admin_delete_unconfirmed_account():
-- the Admin Panel's **Non-verified Accounts** page.
--
-- Why this exists. A sign-up that never confirms its address is invisible to
-- every client: `email_confirmed_at` lives in `auth.users`, which no client may
-- read, and the `profiles` row carries no confirmation flag (the sign-up trigger
-- creates it before any confirmation, so an unconfirmed account has an ordinary
-- profile row). Abandoned sign-ups therefore accumulate where nobody can see
-- them. These two functions are the administrator's window on them: one lists
-- them, one removes one.
--
-- The test for "may be removed" is the **same** guard `discard_unconfirmed_signup()`
-- uses — unconfirmed, and having done nothing at all: no firm, no membership, no
-- invite, no payment or approval, no administrator rights, no sync receipt and no
-- authored row of any kind. It is factored into `is_provisional_account()` so the
-- list and the delete can never disagree about which accounts qualify; the list
-- reports it as `can_delete`, so the panel disables the action rather than
-- letting an administrator press it and be refused.
--
-- Nothing here is reachable by a non-administrator: both functions raise
-- `admin_required` unless `is_admin()` answers true, and both are SECURITY
-- DEFINER reading `auth.users` as the owner — which is the point, since no client
-- policy grants access to that table.

-- ---------------------------------------------------------------------------
-- is_provisional_account() — may this account still be removed?
-- ---------------------------------------------------------------------------

-- True when the account has done nothing that its removal would destroy. The
-- tables below are exactly `discard_unconfirmed_signup()`'s list: each is either
-- a row whose loss would be a loss of work, or a reference that does not cascade
-- from `auth.users` — which is also why the deletion below cannot fail on a
-- foreign key.
--
-- SECURITY DEFINER so it may read those tables from inside the admin functions
-- whichever role is calling; it is not granted to any client role.
create or replace function public.is_provisional_account(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select not exists (
    select 1
      from (
        select 1 from public.firms f where f.owner_id = p_user_id
        union all select 1 from public.firm_members m where m.user_id = p_user_id
        union all select 1 from public.firm_invites i where i.created_by = p_user_id
        union all select 1 from public.payment_submissions s where s.user_id = p_user_id
        union all select 1 from public.payment_approval_events e
         where e.user_id = p_user_id or e.approved_by = p_user_id
        union all select 1 from public.app_admins a where a.user_id = p_user_id
        union all select 1 from public.mutation_receipts r where r.actor_id = p_user_id
        union all select 1 from public.cases c where c.user_id = p_user_id
        union all select 1 from public.case_history h where h.user_id = p_user_id
        union all select 1 from public.notes n where n.user_id = p_user_id
        union all select 1 from public.case_references r where r.user_id = p_user_id
        union all select 1 from public.delete_requests d
         where d.requested_by = p_user_id or d.reviewed_by = p_user_id
        union all select 1 from public.conflict_log l where l.user_id = p_user_id
        union all select 1 from public.courts x where x.user_id = p_user_id
        union all select 1 from public.court_categories x where x.user_id = p_user_id
        union all select 1 from public.case_categories x where x.user_id = p_user_id
        union all select 1 from public.steps x where x.user_id = p_user_id
        union all select 1 from public.case_types x where x.user_id = p_user_id
        union all select 1 from public.on_behalfs x where x.user_id = p_user_id
      ) activity
  );
$$;

comment on function public.is_provisional_account(uuid) is
  'True when the account has done nothing (no firm, membership, invite, payment, approval, admin rights, sync receipt or authored row). The shared test behind admin_delete_unconfirmed_account() and the panel''s can_delete flag; the same guard discard_unconfirmed_signup() applies.';

-- ---------------------------------------------------------------------------
-- admin_list_unconfirmed_accounts() — the sign-ups that never confirmed
-- ---------------------------------------------------------------------------

create or replace function public.admin_list_unconfirmed_accounts()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
begin
  if not public.is_admin() then
    raise exception 'admin_required' using errcode = '42501';
  end if;

  -- Newest first. `email` prefers the profile's copy (which mirrors the account
  -- address) and falls back to `auth.users` for a profile row that has not been
  -- written yet; `full_name` is empty until the account fills it in.
  return (
    select coalesce(
             jsonb_agg(
               jsonb_build_object(
                 'id', u.id,
                 'email', coalesce(nullif(p.email, ''), u.email),
                 'full_name', coalesce(p.full_name, ''),
                 'created_at', u.created_at,
                 'last_sign_in_at', u.last_sign_in_at,
                 'can_delete', public.is_provisional_account(u.id)
               )
               order by u.created_at desc
             ),
             '[]'::jsonb
           )
      from auth.users u
      left join public.profiles p on p.id = u.id
     where u.email_confirmed_at is null
  );
end;
$$;

comment on function public.admin_list_unconfirmed_accounts() is
  'Admin-only list of every account that has never confirmed its address, joined to its profile for the name and the mirrored email. Newest first; each row carries can_delete, the shared provisional test, so the panel can disable an action that would be refused.';

-- ---------------------------------------------------------------------------
-- admin_delete_unconfirmed_account() — remove one abandoned sign-up
-- ---------------------------------------------------------------------------

create or replace function public.admin_delete_unconfirmed_account(
  p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user auth.users%rowtype;
begin
  if not public.is_admin() then
    raise exception 'admin_required' using errcode = '42501';
  end if;

  select u.* into v_user from auth.users u where u.id = p_user_id;
  if not found then
    return jsonb_build_object('status', 'refused', 'reason', 'not_found');
  end if;

  -- A confirmed address is a real account, however empty: the administrator's
  -- way to deal with it is not this function.
  if v_user.email_confirmed_at is not null then
    return jsonb_build_object('status', 'refused', 'reason', 'confirmed');
  end if;

  -- Re-run the guard even though the list reported it: the account may have
  -- done something between the two calls.
  if not public.is_provisional_account(p_user_id) then
    return jsonb_build_object('status', 'refused', 'reason', 'has_activity');
  end if;

  -- Removing the account cascades the profile, the preference rows, the invite
  -- attempts and the sessions — nothing else references it, which the guard
  -- above has just established.
  delete from auth.users u where u.id = p_user_id;

  return jsonb_build_object('status', 'removed');
end;
$$;

comment on function public.admin_delete_unconfirmed_account(uuid) is
  'Admin-only removal of an account that has never confirmed its address and has done nothing. Refuses an unknown, confirmed or non-provisional account. Returns {"status":"removed"} or {"status":"refused","reason":"not_found"|"confirmed"|"has_activity"}.';

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

-- Supabase's default privileges grant EXECUTE on a new function in `public`
-- directly to `anon` and `authenticated`, and a direct grant outlives a revoke
-- aimed at PUBLIC — so every function here is re-asserted explicitly. The shared
-- guard is granted to no client role: only the SECURITY DEFINER functions above
-- call it, as the owner.
revoke all on function public.is_provisional_account(uuid) from public, anon;

revoke all on function public.admin_list_unconfirmed_accounts()
  from public, anon;
grant execute on function public.admin_list_unconfirmed_accounts()
  to authenticated;

revoke all on function public.admin_delete_unconfirmed_account(uuid)
  from public, anon;
grant execute on function public.admin_delete_unconfirmed_account(uuid)
  to authenticated;
