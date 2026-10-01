-- Task 20 Phase 1 — `ensure_firm(name)` gains the premium gate the task requires.
--
-- Phase 1 item 2: "Firm mode requires an active premium subscription … Block
-- adding the first associate on a free entitlement." The client blocks it and
-- routes to the Paywall (Task 20's Manage Associates screen); this is the same
-- rule enforced where it cannot be bypassed, because the client also cannot be
-- trusted with it — `ensure_firm` is the only path from individual to owner, and
-- it runs as SECURITY DEFINER.
--
-- Entitlement is DERIVED, never read from `subscription_status` (plan §6): the
-- same `subscription_expiry + 48h grace > now()` rule that `is_premium()` and
-- `push_changes` already use, so the gate here cannot disagree with the one the
-- sync engine applies a moment later.
--
-- The gate sits at the **creation** moment only. Plan §6's "Lapsed-Premium Users
-- Keep Everything" promises that an owner whose subscription expires keeps the
-- firm and every case in it, so this function's idempotent paths — returning the
-- existing firm, renaming it, repairing the owner's `firm_members` row — must
-- keep working for a lapsed owner rather than locking them out of their own
-- firm. A free account therefore cannot *become* a firm; it does not lose one it
-- already has.
--
-- The second guard is a correctness one, and it is why the client never has to
-- be trusted about who may call this: a member of somebody else's firm is not an
-- individual who can become an owner. Without this check an associate calling
-- the RPC would create a second firm, relink their `profiles.firm_id` to it and
-- leave every row they authored pointing at the firm they just left — invisible
-- to them, because every firm-scoped policy reads `current_firm_id()`.
--
-- Nothing else in `ensure_firm` changes; the function is replaced whole because
-- that is the only write path a plpgsql body has.

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
  v_has_firm boolean;
begin
  if v_user_id is null then
    return jsonb_build_object('status', 'unauthenticated');
  end if;

  select * into v_firm
    from public.firms f
   where f.owner_id = v_user_id
   order by f.created_at
   limit 1;
  -- Captured immediately: `FOUND` belongs to the most recent SQL statement, and
  -- the membership guard below runs one of its own.
  v_has_firm := found;

  -- Membership guard: refuse to become the owner of a new firm while the
  -- caller's profile points at a firm they do not own. Returned rather than
  -- raised so the answer is a value the client can report; nothing is written.
  if exists (
    select 1
      from public.profiles p
     where p.id = v_user_id
       and p.firm_id is not null
       and (not v_has_firm or p.firm_id is distinct from v_firm.id)
  ) then
    return jsonb_build_object('status', 'member_of_another_firm');
  end if;

  if not v_has_firm then
    -- The transition to firm mode is the premium-gated step (Phase 1 item 2).
    if not public.is_premium(v_user_id) then
      return jsonb_build_object('status', 'premium_required');
    end if;

    -- `created_at` is a server instant (`timestamptz`) and takes the column
    -- default: the bigint `v_now` below is epoch ms for the client-facing
    -- `firm_members` stamps only.
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
  'Idempotent owner-side firm establishment: creates the caller''s firm (premium-gated at the creation moment), relinks profiles.firm_id/role and upserts the owner''s firm_members row. Refuses a member of another firm. The invite generator (and therefore the app) has no other way to reach firm scope.';

-- A direct EXECUTE grant from Supabase's default privileges outlives a revoke of
-- PUBLIC, so `anon` is named explicitly — the same reason join_firm and
-- approve_payment do it.
revoke all on function public.ensure_firm(text) from public, anon;
grant execute on function public.ensure_firm(text) to authenticated;
