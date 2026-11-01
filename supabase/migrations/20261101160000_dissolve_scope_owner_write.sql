-- Chamber dissolve (12) — the owner can write what it inherited.
--
-- The gap this closes. `dissolve_firm()` transfers every ledger row from the
-- chamber to its owner by clearing `firm_id` and setting `scope_owner_id` to
-- the owner. The read policies were extended for that transfer, so the owner
-- can see the inherited diary. Its write policies were not: `user_id` still
-- names the author, and `can_edit_firm(firm_id)` is false once the firm is
-- gone. The owner could therefore **read** an inherited case but not rename or
-- delete it. A *Delete Local & Cloud Data* run tombstoned the row locally and
-- queued the delete, `sync_can_write` refused it as `permission_denied`, and
-- the next pull restored the still-live server row — the data wipe reported
-- success while one or more inherited rows came back.
--
-- The rule now matches the read side across the twelve ledger tables that carry
-- `scope_owner_id`:
--
--   an author may write their own row only while it has no scope owner
--   (`scope_owner_id is null`), so a member removed by a dissolve cannot edit
--   the row the owner inherited;
--   a chamber member with `can_edit`/`can_delete` keeps its existing branches;
--   the dissolve's scope owner may update and delete the row.
--
-- Both doors are changed together, because either one alone leaves the bug:
-- the RLS `UPDATE` policies for direct PostgREST writes, and `sync_can_write`
-- for the `push_changes` path the app actually uses. `sync_can_write` also now
-- refuses an INSERT that names `scope_owner_id`; the column is server-owned and
-- the RPC is SECURITY DEFINER, so a hand-built payload must not be able to set
-- it. `delete_requests` keeps its pending-requester branch and adds the scope
-- owner; its review path already uses `can_delete_firm` or the scope owner.
--
-- Applied to `lsthasywrdrhuuxnykau` ("Legal Case Diary") only — rule 12.

-- ---------------------------------------------------------------------------
-- 1. The RLS update policies
-- ---------------------------------------------------------------------------

do $$
declare
  v_table text;
  -- The ten tables whose update matrix is the same shape: the four case-data
  -- tables and the six custom reference tables.
  v_tables text[] := array[
    'cases', 'case_history', 'notes', 'case_references',
    'court_categories', 'case_categories', 'courts', 'steps', 'case_types',
    'on_behalfs'
  ];
begin
  foreach v_table in array v_tables loop
    execute format(
      'drop policy if exists %1$s_update_scoped on public.%1$I',
      v_table
    );
    execute format(
      $policy$
      create policy %1$s_update_scoped on public.%1$I for update to
      authenticated using (
        (
          user_id = auth.uid()
          and scope_owner_id is null
          and (
            firm_id is null
            or firm_id is not distinct from public.current_firm_id()
          )
        )
        or public.can_edit_firm(firm_id)
        or scope_owner_id = auth.uid()
      )
      $policy$,
      v_table
    );
  end loop;
end;
$$;

drop policy if exists laws_update_scoped on public.laws;
create policy laws_update_scoped on public.laws for update to authenticated
using (
  (user_id = auth.uid() and scope_owner_id is null)
  or public.can_edit_firm(firm_id)
  or scope_owner_id = auth.uid()
);

drop policy if exists delete_requests_update_scoped on public.delete_requests;
create policy delete_requests_update_scoped on public.delete_requests
for update to authenticated
using (
  (
    requested_by = auth.uid()
    and status = 'pending'
    and scope_owner_id is null
    and firm_id is not distinct from public.current_firm_id()
  )
  or public.can_delete_firm(firm_id)
  or scope_owner_id = auth.uid()
);

-- ---------------------------------------------------------------------------
-- 2. sync_can_write: the same verdict for the push_changes door
-- ---------------------------------------------------------------------------

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
  -- The dissolve's scope key. It is absent on a normal insert, and
  -- push_changes merges it into an update from the locked server row.
  v_scope_owner uuid := coalesce((p_row ->> 'scope_owner_id')::uuid, null);
  v_is_reference boolean := p_table in (
    'court_categories', 'case_categories', 'courts', 'steps', 'case_types',
    'on_behalfs', 'laws'
  );
  -- The firm a delete-request rule weighs: the row's own when it carries one,
  -- otherwise the stored request's.
  v_request_firm uuid;
begin
  if v_actor is null then
    return false;
  end if;

  if p_operation = 'insert' then
    -- scope_owner_id is server-owned; the RPC must not let a payload set it.
    if v_scope_owner is not null then
      return false;
    end if;

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
    -- but only while the request's firm is still theirs and the row has no
    -- scope owner: a removed requester must not be able to touch a request the
    -- dissolve handed to the owner. A member with delete permission may still
    -- review, and the dissolve's owner may manage it.
    v_request_firm := nullif(p_row ->> 'firm_id', '')::uuid;
    if v_request_firm is null then
      select d.firm_id into v_request_firm
        from public.delete_requests d
       where d.id::text = lower(nullif(p_row ->> 'id', ''));
    end if;

    return (
      coalesce((p_row ->> 'requested_by')::uuid, null) = v_actor
      and v_scope_owner is null
      and (p_row ->> 'status') = 'pending'
      and v_request_firm is not distinct from public.current_firm_id()
    )
    or public.can_delete_firm(v_request_firm)
    or v_scope_owner = v_actor;
  elsif v_is_reference then
    -- A built-in row has no creator and no firm; only a custom row is writable.
    if not coalesce((p_row ->> 'is_custom')::boolean, false) then
      return false;
    end if;
    return (
        coalesce((p_row ->> 'user_id')::uuid, null) = v_actor
        and v_scope_owner is null
        and (
          p_row ->> 'firm_id' is null
          or coalesce((p_row ->> 'firm_id')::uuid, null)
               is not distinct from public.current_firm_id()
        )
      )
      or public.can_edit_firm(coalesce((p_row ->> 'firm_id')::uuid, null))
      or v_scope_owner = v_actor;
  elsif p_table = 'conflict_log' then
    return coalesce((p_row ->> 'user_id')::uuid, null) = v_actor;
  else
    -- Authorship only counts while the row has no scope owner and its firm is
    -- still the caller's firm: a removed member keeps their own personal rows
    -- but not the chamber's, and never a row the dissolve handed to the owner.
    if not (
      (
        coalesce((p_row ->> 'user_id')::uuid, null) = v_actor
        and v_scope_owner is null
        and (
          p_row ->> 'firm_id' is null
          or coalesce((p_row ->> 'firm_id')::uuid, null)
               is not distinct from public.current_firm_id()
        )
      )
      or public.can_edit_firm(coalesce((p_row ->> 'firm_id')::uuid, null))
      or v_scope_owner = v_actor
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
  'The write verdict for push_changes: an insert is the caller''s own and may not name scope_owner_id; an update/delete is the author''s while the row has no scope owner and no other firm, a chamber member''s through can_edit/can_delete, or the dissolve''s scope owner''s. Mirrors the RLS write policies for the twelve ledger tables that carry scope_owner_id.';
