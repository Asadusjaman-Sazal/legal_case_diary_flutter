-- The Non-verified Accounts page shows only sign-ups that have sat unconfirmed
-- for **72 hours**, and its delete refuses anything younger.
--
-- Why this exists. `20261009120000` listed every account whose
-- `email_confirmed_at` is still null — and therefore listed a sign-up the moment
-- it was created. A user who has just registered is normally mid-verification,
-- not abandoned: they are walking to their mailbox, and a slow mail server or a
-- closed app is not a reason to show them to an administrator as a stray. A
-- window gives a genuine sign-up its chance to confirm, so the page means
-- "abandoned" rather than "started", and the side-menu badge (which counts this
-- list) stops flicking up by one every time somebody taps Sign Up.
--
-- What changes. Only the horizon, and only here:
--   * `admin_list_unconfirmed_accounts()` gains
--     `and u.created_at < now() - c_min_age`, so a fresh sign-up is not returned;
--   * `admin_delete_unconfirmed_account(uuid)` re-runs that same window before
--     the provisional test and refuses a too-young account as `too_recent`,
--     **not** as `has_activity`. Without this the window would be cosmetic: a
--     client that knew the id could still remove a sign-up the page refuses to
--     show, and `has_activity` would be a false reason for an account that has
--     done nothing at all.
--
-- The window lives in one constant per function (`c_min_age`) rather than in a
-- setting, because it is a policy of this page, not a preference: the list, the
-- badge and the delete must agree on it, and they all read it from this file's
-- definition of the two functions. `is_provisional_account()` is untouched — the
-- window is about *age*, the guard is about *activity*, and they answer
-- different questions.
--
-- Everything else is the predecessor's behaviour re-asserted unchanged: both
-- functions stay SECURITY DEFINER and admin-gated, the list stays newest-first
-- with `can_delete` per row, and the grants stay exactly as `20261009130000`
-- left them (the two entry points callable by `authenticated` and gated in the
-- body, with the internal guard reachable by no client role).

-- ---------------------------------------------------------------------------
-- admin_list_unconfirmed_accounts() — the oldest never-confirmed sign-ups
-- ---------------------------------------------------------------------------

create or replace function public.admin_list_unconfirmed_accounts()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  -- How long an unconfirmed sign-up must have sat before the page calls it
  -- abandoned. A sign-up younger than this may still be confirming.
  c_min_age constant interval := interval '72 hours';
begin
  if not public.is_admin() then
    raise exception 'admin_required' using errcode = '42501';
  end if;

  -- Newest first. `email` prefers the profile's copy (which mirrors the account
  -- address) and falls back to `auth.users` for a profile row that has not been
  -- written yet; `full_name` is empty until the account fills it in. The age
  -- window is the only addition since `20261009120000`.
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
       and u.created_at < now() - c_min_age
  );
end;
$$;

comment on function public.admin_list_unconfirmed_accounts() is
  'Admin-only list of every account that has never confirmed its address AND was created more than 72 hours ago, joined to its profile for the name and the mirrored email. Newest first; each row carries can_delete, the shared provisional test, so the panel can disable an action that would be refused. A sign-up younger than the window is deliberately absent: it may still be confirming.';

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
  -- The same window the list applies. Kept equal to it by inspection, the way
  -- the two already share `is_provisional_account()` for the activity test.
  c_min_age constant interval := interval '72 hours';
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

  -- Too young to call abandoned, so not this function's to remove yet — the
  -- same horizon the list hides it behind. Refused *before* the activity test,
  -- and with its own reason, so a fresh sign-up is never reported as an account
  -- that has done something when it has done nothing.
  if v_user.created_at >= now() - c_min_age then
    return jsonb_build_object(
      'status', 'refused', 'reason', 'too_recent'
    );
  end if;

  -- Re-run the guard even though the list reported it: the account may have
  -- done something between the two calls.
  if not public.is_provisional_account(p_user_id) then
    return jsonb_build_object('status', 'refused', 'reason', 'has_activity');
  end if;

  -- Removing the account cascades the profile, the preference rows, the invite
  -- attempts and the sessions — nothing else references it, which the guards
  -- above have just established.
  delete from auth.users u where u.id = p_user_id;

  return jsonb_build_object('status', 'removed');
end;
$$;

comment on function public.admin_delete_unconfirmed_account(uuid) is
  'Admin-only removal of an account that has never confirmed its address, was created more than 72 hours ago, and has done nothing. Refuses an unknown, confirmed, too-recent or non-provisional account. Returns {"status":"removed"} or {"status":"refused","reason":"not_found"|"confirmed"|"too_recent"|"has_activity"}.';

-- ---------------------------------------------------------------------------
-- Grants — re-asserted so this file states the whole grant picture in one place
-- ---------------------------------------------------------------------------

-- Supabase's default privileges grant EXECUTE on a new function in `public`
-- directly to `anon` and `authenticated`, and a direct grant outlives a revoke
-- aimed at PUBLIC — so every function here is re-asserted explicitly, exactly as
-- `20261009130000` left it. The internal guard is named only to keep it closed:
-- it is granted to no client role.
revoke all on function public.is_provisional_account(uuid)
  from public, anon, authenticated;

revoke all on function public.admin_list_unconfirmed_accounts()
  from public, anon;
grant execute on function public.admin_list_unconfirmed_accounts()
  to authenticated;

revoke all on function public.admin_delete_unconfirmed_account(uuid)
  from public, anon;
grant execute on function public.admin_delete_unconfirmed_account(uuid)
  to authenticated;
