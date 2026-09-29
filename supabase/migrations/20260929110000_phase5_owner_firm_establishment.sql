-- Task 17 Phase 5 — ensure_firm(name): the one path that turns an individual
-- account into a firm owner.
--
-- Why this is a server function and not a client insert. Revision 2.4's
-- onboarding rule is that an individual "converts to Firm automatically when an
-- associate is added": the owner generates the invite, so the firm has to exist
-- before the code does. The client cannot do it itself, by design:
--   * `20260929102500_phase3_column_privileges.sql` revoked UPDATE on
--     `profiles` from `authenticated` and granted back only `full_name`, so
--     `profiles.role` and `profiles.firm_id` are server-owned — a user cannot
--     promote themselves to owner or relink themselves to another firm's id;
--   * `current_firm_id()` reads `profiles.firm_id` and nothing else, so an owner
--     who merely inserted a `firms` row would still have no firm scope: every
--     firm-scoped policy would ignore them.
-- So the conversion needs SECURITY DEFINER privileges, and that is what this
-- function is.
--
-- Idempotent by design: one firm per owner. Calling it again returns the firm
-- that already exists (renaming it only when a different name is given, which is
-- the same self-service rename `firms_update_owner` + the `firms.name` column
-- grant already allow), and repairs the owner's `firm_members` row rather than
-- creating a second one.
--
-- The new firm starts with the owner's own subscription values, which is the
-- state `mirror_owner_subscription_to_firm()` maintains from then on.

create or replace function public.ensure_firm(p_name text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_now bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_name text := pg_catalog.btrim(coalesce(p_name, ''));
  v_firm public.firms%rowtype;
begin
  if v_user_id is null then
    return jsonb_build_object('status', 'unauthenticated');
  end if;

  -- The name is the UI's, not this function's: a server-side default would be
  -- user-facing copy living outside the ARB, so an empty name is refused.
  if v_name = '' then
    raise exception 'ensure_firm: a firm name is required'
      using errcode = 'P0001';
  end if;

  select * into v_firm
    from public.firms f
   where f.owner_id = v_user_id
   order by f.created_at
   limit 1;

  if not found then
    -- `created_at` is a server instant (`timestamptz`) and takes the column
    -- default: the bigint `v_now` below is epoch ms for the client-facing
    -- `firm_members` stamps only, and the first apply proved the difference by
    -- refusing the value here.
    insert into public.firms (
      name, owner_id, subscription_status, subscription_expiry
    )
    select
      v_name,
      v_user_id,
      p.subscription_status,
      p.subscription_expiry
      from public.profiles p
     where p.id = v_user_id
    returning * into v_firm;

    if not found then
      -- No profile row: the sign-up trigger creates one, so this is a bug state,
      -- never something to explain to a user. Raising here rolls the firm back.
      raise exception 'ensure_firm: no profiles row for the caller'
        using errcode = 'P0001';
    end if;
  elsif v_name is distinct from v_firm.name then
    update public.firms f
       set name = v_name
     where f.id = v_firm.id
    returning * into v_firm;
  end if;

  -- The conversion itself: firm scope for every policy, owner role for the app.
  update public.profiles p
     set firm_id = v_firm.id,
         role = 'owner'
   where p.id = v_user_id;

  -- The owner holds every permission explicitly, so `can_edit_firm` /
  -- `can_delete_firm` and the client's cached flags agree with the role.
  insert into public.firm_members (
    firm_id, user_id, role, can_add, can_edit, can_delete,
    synced_at, permissions_synced_at
  )
  values (
    v_firm.id, v_user_id, 'owner', true, true, true, v_now, v_now
  )
  on conflict (firm_id, user_id) do update
    set role = 'owner',
        can_add = true,
        can_edit = true,
        can_delete = true,
        synced_at = excluded.synced_at,
        permissions_synced_at = excluded.permissions_synced_at;

  return jsonb_build_object(
    'status', 'ready',
    'firm_id', v_firm.id,
    'name', v_firm.name
  );
end;
$$;

comment on function public.ensure_firm(text) is
  'Idempotent owner-side firm establishment: creates the caller''s firm, relinks profiles.firm_id/role and upserts the owner''s firm_members row. The invite generator (and therefore the app) has no other way to reach firm scope.';

-- A direct EXECUTE grant from Supabase's default privileges outlives a revoke of
-- PUBLIC, so `anon` is named explicitly — the same reason join_firm and
-- approve_payment do it.
revoke all on function public.ensure_firm(text) from public, anon;
grant execute on function public.ensure_firm(text) to authenticated;
