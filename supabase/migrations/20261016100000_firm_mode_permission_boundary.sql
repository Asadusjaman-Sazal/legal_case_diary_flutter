-- Firm mode Phase 5 — the permission boundary.
--
-- §3.3 rules that a member's flags are a boundary on the server, not an
-- intention in the app: a modified client, or a direct PostgREST call carrying a
-- member's own token, must not add or edit chamber data the owner has switched
-- off. What is added here, and nothing else:
--
--   1. `can_add_firm(uuid)` — the third helper beside `can_edit_firm` and
--      `can_delete_firm`. It did not exist, so both halves of the rule are new
--      work rather than the UPDATE half alone.
--   2. `enforce_member_permission()` — one BEFORE trigger function, attached
--      per table in the shape `enforce_delete_transition()` already uses.
--      INSERT is gated on `can_add`, UPDATE on `can_edit`, and the tombstone
--      transition is left to `can_delete`'s existing gate rather than
--      duplicated here (§3.3: the two permissions stay separate).
--   3. `sync_can_write` states the same rule for the RPC's door — `can_add` on a
--      create, and `can_edit` on every non-tombstone update of a firm-scoped row
--      — so a refused write is a clean per-mutation `permission_denied` rather
--      than a trigger error. The trigger covers the direct door and this covers
--      the queued one. The `can_delete` check on a tombstone, `delete_requests`,
--      `conflict_log` and every RLS policy are untouched.
--
-- §3.3's scope-column ruling is folded in at the same place, because the trigger
-- exists anyway: a client role may not move an existing row between scopes
-- (`firm_id` is the server's on every existing row), and a caller who holds a
-- chamber may not create a row outside it. `scope_owner_id` is already
-- server-only by column privilege (`20261015100000_firm_mode_read_scope.sql`);
-- `firm_id` was not, so a member could null it on their own row — dropping a
-- chamber's case into their personal diary — through a direct PostgREST update.
--
-- The trigger function is deliberately **SECURITY INVOKER**, and its two rules
-- are keyed on the two different things their cases require:
--
--   * the **scope** rule on the **role**, because what it must exclude is a
--     client write: `ensure_firm` stamps `firm_id` on a firm-less diary in the
--     transaction that creates the chamber, and the dissolve nulls it again, and
--     both run as their owner. `push_changes` derives and preserves `firm_id`
--     itself, so the RPC needs nothing from this rule.
--   * the **permission** rule on the **caller** (`auth.uid()`), because it must
--     bind the same write through both doors — a direct PostgREST write (role
--     `authenticated`) and the identical write queued through `push_changes`,
--     which is SECURITY DEFINER and so runs as its owner — while a migration, a
--     nightly job or a fixture that has impersonated nobody must step aside.
--     `auth.uid()` is precisely the thing those two have and a script does not.
--
-- Keying the permission rule on the role instead leaves the RPC door ungated, and
-- that was **measured rather than assumed**: with the role keying in place, a
-- `can_edit = false` member's queued update came back `accepted` instead of
-- `permission_denied`. The price of the caller keying is that a statement which
-- sets a claim and then writes as the database owner is judged as that caller's
-- write — which is what a claim means — so a proof must put the session back the
-- way it found it: `reset role` alone leaves `request.jwt.claims` behind, and
-- `firm_mode_join_gate_test.sql`'s `pg_temp.as_owner()` clears it for exactly
-- that reason.
--
-- Declaring this function SECURITY DEFINER would make `current_user` the owner
-- for every caller and switch the scope rule off, which is why it is not
-- declared — and it is also why the permission rule cannot be keyed on the role.
--
-- No grant is written below, on purpose. `can_add_firm` is a **new** function,
-- so Supabase's default privileges grant it EXECUTE directly to `anon` and
-- `authenticated`, exactly as they do for its two siblings: RLS policy
-- expressions run with the *caller's* privileges, so revoking would break the
-- policies that use them, and the helper answers only for the caller, so it
-- discloses nothing. `sync_can_write` is replaced rather than recreated, so its
-- existing ACL is preserved.

-- ---------------------------------------------------------------------------
-- 1. The third access helper
-- ---------------------------------------------------------------------------

-- True when the caller may add a firm-scoped row: the chamber's owner, or a
-- member whose `can_add` flag is on. A null firm (an individual account) is
-- never firm-scoped, so this is false for it — the callers' own
-- `firm_id is not null` guards are what keep a personal row unaffected.
create or replace function public.can_add_firm(p_firm_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select p_firm_id is not null
     and (
       exists (select 1 from public.firms f
                where f.id = p_firm_id and f.owner_id = auth.uid())
       or exists (select 1 from public.firm_members m
                   where m.firm_id = p_firm_id
                     and m.user_id = auth.uid()
                     and m.can_add)
     );
$$;

comment on function public.can_add_firm(uuid) is
  'True when the caller may add a firm-scoped row: the firm owner, or a member whose can_add flag is on. A null firm is never firm-scoped, so it is false for an individual account.';

-- ---------------------------------------------------------------------------
-- 2. The boundary itself, and the server's ownership of the scope columns
-- ---------------------------------------------------------------------------

create or replace function public.enforce_member_permission()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  -- The roles PostgREST sets for a request. A role outside this list is the
  -- database owner: a migration, a nightly job, or server code inside a
  -- SECURITY DEFINER function such as `ensure_firm`.
  c_client_roles constant text[] := array['authenticated', 'anon'];
begin
  -- 1. The scope columns belong to the server (§3.3): a client may not move a
  --    row between scopes. Keyed on the role, so `ensure_firm` and the dissolve
  --    — which move a scope legitimately, as their owner — are skipped.
  if current_user::text = any (c_client_roles) then
    if tg_op = 'INSERT' then
      if public.current_firm_id() is not null and new.firm_id is null then
        raise exception 'scope_change_not_permitted'
          using errcode = '42501',
                hint = 'A chamber holds chamber rows; only the server sets the scope.';
      end if;
    elsif new.firm_id is distinct from old.firm_id then
      raise exception 'scope_change_not_permitted'
        using errcode = '42501',
              hint = 'A row''s firm is derived when it is created and never changed by a client.';
    end if;
  end if;

  -- 2. The member's flags, keyed on the caller rather than the role: this is
  --    what binds the RPC's door as well as PostgREST's. A statement carrying no
  --    claim is a migration, a nightly job, or a fixture still to impersonate.
  if auth.uid() is null then
    return new;
  end if;

  -- 3. `can_add` gates a create.
  if tg_op = 'INSERT' then
    if new.firm_id is not null and not public.can_add_firm(new.firm_id) then
      raise exception 'add_not_permitted'
        using errcode = '42501',
              hint = 'Requires can_add in this firm.';
    end if;
    return new;
  end if;

  -- 4. The tombstone transition keeps `can_delete`'s own gate
  --    (`enforce_delete_transition`), so a member whose edits are switched off
  --    may still be allowed to delete, and the two permissions are not merged.
  if old.is_deleted = false and new.is_deleted = true then
    return new;
  end if;

  -- 5. `can_edit` gates every other update to a firm-scoped row — including the
  --    author's own, which is deliberately stricter than the RLS policy: in a
  --    chamber most rows a member touches are ones they authored, so an author
  --    exception would leave the owner's toggle nearly meaningless (§3.2, §3.3).
  if new.firm_id is not null and not public.can_edit_firm(new.firm_id) then
    raise exception 'edit_not_permitted'
      using errcode = '42501',
            hint = 'Requires can_edit in this firm.';
  end if;
  return new;
end;
$$;

comment on function public.enforce_member_permission() is
  'BEFORE INSERT/UPDATE on the ten permission-gated tables. The scope rule is keyed on the client role (so ensure_firm and the dissolve may move a scope) and the permission rule on the caller, auth.uid() (so a create and every non-tombstone update are gated through both the direct-PostgREST and the push_changes door, while a migration, a nightly job or an un-impersonated fixture steps aside). can_add gates a create, can_edit every non-tombstone update of a firm-scoped row, and a client may not change a row''s firm_id nor create a firm-less row while it holds a chamber. Deliberately SECURITY INVOKER: SECURITY DEFINER would make current_user the owner for every caller and switch the scope rule off.';

-- ---------------------------------------------------------------------------
-- 3. Attach the two triggers to the ten gated tables
-- ---------------------------------------------------------------------------
--
-- One loop over an explicit array, the Phase 3 shape: a table missed here cannot
-- pass unnoticed, and the proof enumerates the same ten by name.
--
-- `delete_requests` and `conflict_log` are deliberately absent. Raising a delete
-- request is how a member without `can_delete` asks for a deletion, so it must
-- stay open to every member (§3.1); `conflict_log`'s rows are per-device merge
-- diagnostics, not chamber data.

do $$
declare
  v_table text;
  v_tables text[] := array[
    'cases', 'case_history', 'notes', 'case_references', 'court_categories',
    'case_categories', 'courts', 'steps', 'case_types', 'on_behalfs'
  ];
begin
  foreach v_table in array v_tables loop
    execute format(
      'drop trigger if exists trg_%1$s_add_permission on public.%1$I',
      v_table
    );
    execute format(
      'create trigger trg_%1$s_add_permission before insert on public.%1$I '
      'for each row execute function public.enforce_member_permission()',
      v_table
    );

    execute format(
      'drop trigger if exists trg_%1$s_edit_permission on public.%1$I',
      v_table
    );
    execute format(
      'create trigger trg_%1$s_edit_permission before update on public.%1$I '
      'for each row execute function public.enforce_member_permission()',
      v_table
    );
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. sync_can_write: the INSERT branch reads can_add
-- ---------------------------------------------------------------------------
--
-- Only the two `insert` returns change. Everything else in this body — the
-- authorship rules, the `is not distinct from` firm comparisons, the reference
-- immutability rule, `delete_requests`, and the update/delete branch including
-- the `can_delete` check on a tombstone — is the shipped body verbatim
-- (`20260930210000_sync_can_write_firm_membership.sql`), so the RPC's answer and
-- the trigger's answer agree for a create and the refusal arrives as a clean
-- `permission_denied` result rather than an exception.
--
-- The `can_add` disjunct follows the shape already beside it: `firm_id is null`
-- short-circuits first, so an individual's personal row needs no flag — there is
-- no chamber in whose name it is being written.
--
-- An update is deliberately **not** gated here. `push_changes` subtracts
-- `firm_id` from the row it hands this function (§3.3's "an existing row keeps
-- the firm it has"), so on an update the row carries no firm to weigh — and a
-- rule that cannot see the firm cannot apply `can_edit`. The trigger does it
-- instead, which is why the trigger's permission rule is keyed on the caller.
create or replace function public.sync_can_write(
  p_table text,
  p_row jsonb,
  p_operation text
)
returns boolean
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor uuid := auth.uid();
  v_is_reference boolean := p_table in (
    'court_categories', 'case_categories', 'courts', 'steps', 'case_types',
    'on_behalfs'
  );
begin
  if v_actor is null then
    return false;
  end if;

  if p_operation = 'insert' then
    if p_table = 'delete_requests' then
      return coalesce((p_row ->> 'requested_by')::uuid, null) = v_actor
         and coalesce((p_row ->> 'firm_id')::uuid, null)
             is not distinct from public.current_firm_id();
    elsif v_is_reference then
      return coalesce((p_row ->> 'is_custom')::boolean, false)
         and coalesce((p_row ->> 'user_id')::uuid, null) = v_actor
         and (
           p_row ->> 'firm_id' is null
           or coalesce((p_row ->> 'firm_id')::uuid, null)
                is not distinct from public.current_firm_id()
         )
         and (
           p_row ->> 'firm_id' is null
           or public.can_add_firm(coalesce((p_row ->> 'firm_id')::uuid, null))
         );
    else
      return coalesce((p_row ->> 'user_id')::uuid, null) = v_actor
         and (
           p_row ->> 'firm_id' is null
           or coalesce((p_row ->> 'firm_id')::uuid, null)
                is not distinct from public.current_firm_id()
         )
         and (
           p_row ->> 'firm_id' is null
           or public.can_add_firm(coalesce((p_row ->> 'firm_id')::uuid, null))
         );
    end if;
  end if;

  -- update / delete
  if p_table = 'delete_requests' then
    -- The requester may edit or withdraw their own request while it is pending,
    -- but only while the request's firm is still theirs: a removed requester must
    -- not be able to touch it. A member with delete permission may still review.
    return (
      coalesce((p_row ->> 'requested_by')::uuid, null) = v_actor
      and (p_row ->> 'status') = 'pending'
      and coalesce((p_row ->> 'firm_id')::uuid, null)
            is not distinct from public.current_firm_id()
    ) or public.can_delete_firm(coalesce((p_row ->> 'firm_id')::uuid, null));
  elsif v_is_reference then
    -- A built-in row has no creator and no firm; only a custom row is writable.
    if not coalesce((p_row ->> 'is_custom')::boolean, false) then
      return false;
    end if;
    return (
        coalesce((p_row ->> 'user_id')::uuid, null) = v_actor
        and (
          p_row ->> 'firm_id' is null
          or coalesce((p_row ->> 'firm_id')::uuid, null)
               is not distinct from public.current_firm_id()
        )
      )
      or public.can_edit_firm(coalesce((p_row ->> 'firm_id')::uuid, null));
  elsif p_table = 'conflict_log' then
    return coalesce((p_row ->> 'user_id')::uuid, null) = v_actor;
  else
    -- Authorship only counts while the row's firm is still the caller's firm: a
    -- removed member keeps their own personal rows but not the firm's.
    if not (
      (
        coalesce((p_row ->> 'user_id')::uuid, null) = v_actor
        and (
          p_row ->> 'firm_id' is null
          or coalesce((p_row ->> 'firm_id')::uuid, null)
               is not distinct from public.current_firm_id()
        )
      )
      or public.can_edit_firm(coalesce((p_row ->> 'firm_id')::uuid, null))
    ) then
      return false;
    end if;
    -- The delete transition additionally needs can_delete, mirroring
    -- enforce_delete_transition().
    if p_operation = 'delete' and (p_row ->> 'firm_id') is not null then
      return public.can_delete_firm(coalesce((p_row ->> 'firm_id')::uuid, null));
    end if;
    return true;
  end if;
end;
$$;

comment on function public.sync_can_write(text, jsonb, text) is
  'Explicit write re-check for push_changes: same rules as the Phase 4 RLS policies, evaluated on the row that would be written, plus the Phase 5 can_add gate on a create. A firm comparison uses `is not distinct from`, because `=` against a NULL current_firm_id would yield NULL and slip past an `if not`. Authorship of a firm-scoped row is honoured only while the row''s firm is still the caller''s firm, so a removed member cannot merge a queued write. An update is not gated here: enforce_member_permission() is the enforcement for can_edit, and it can be, because push_changes subtracts firm_id from the row it passes here — a rule that cannot see the firm cannot weigh can_edit.';
