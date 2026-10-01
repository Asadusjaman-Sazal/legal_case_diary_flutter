-- Task 20 Phase 2 — removing an associate, and telling the firm about it.
--
-- Three things have to happen together and they are all server-side, which is
-- why this is one `SECURITY DEFINER` function rather than three client calls:
--
--   * the `firm_members` row goes (the membership itself);
--   * `profiles.firm_id` / `profiles.role` are relinked to individual mode —
--     and that single statement is what actually revokes access, because every
--     guard in the schema reads `firm_id`: `current_firm_id()` scopes every RLS
--     policy, `can_edit_firm()` / `can_delete_firm()` gate `sync_can_write()`,
--     and `can_read_topic()` authorizes the `firm:{id}` Realtime topic. A
--     removed member can therefore write nothing, see nothing and subscribe to
--     nothing from the moment this commits, with **no** session revocation
--     needed (this project has no service-role key, so the auth session itself
--     is left alone on purpose — see the task file's Phase 2 item 5);
--   * the removal is announced, so a connected device enforces it immediately
--     rather than at its next launch.
--
-- Authored records are deliberately untouched: `cases`, `notes` and
-- `case_references` keep their `user_id` (immutable audit attribution) and their
-- `firm_id` (they belong to the firm), and nothing is reassigned to the owner.
-- That is the Addendum's rule verbatim.
--
-- Owner-only: `firms.owner_id` is the single source of truth, and the client
-- cannot even ask for another firm's member because the function resolves the
-- firm from the caller rather than from a parameter.

create or replace function public.remove_firm_member(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor uuid := auth.uid();
  v_firm_id uuid;
  v_locked boolean;
begin
  if v_actor is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;

  if p_user_id is null then
    return jsonb_build_object('status', 'invalid_request');
  end if;

  -- The caller's own firm, and only if they own it. A non-owner gets an answer
  -- rather than an error: it is a state the UI can word, not a bug.
  select f.id into v_firm_id
    from public.firms f
   where f.owner_id = v_actor;

  if v_firm_id is null then
    return jsonb_build_object('status', 'not_owner');
  end if;

  if p_user_id = v_actor then
    -- A firm is not transferable in this task, so removing the owner would
    -- leave `firms.owner_id` pointing at a non-member and the firm with nobody
    -- who may administer it.
    return jsonb_build_object('status', 'cannot_remove_self');
  end if;

  -- Locked, so two concurrent removals cannot both claim the same row and one
  -- of them cannot report `removed` for a membership it did not delete.
  select true into v_locked
    from public.firm_members m
   where m.firm_id = v_firm_id
     and m.user_id = p_user_id
   for update;

  if not found then
    return jsonb_build_object('status', 'not_found');
  end if;

  delete from public.firm_members m
   where m.firm_id = v_firm_id
     and m.user_id = p_user_id;

  -- The revocation, in one statement: `firm_id` is what every access helper
  -- reads, so nulling it ends RLS access, Realtime topic authorization and
  -- every queued `push_changes` write at once. `role` follows it back to the
  -- individual default rather than being left as `associate` with no firm.
  update public.profiles p
     set firm_id = null,
         role = 'individual'
   where p.id = p_user_id;

  -- Two audiences, two topics — both as the trigger's own `row_change` event,
  -- so the client needs no second decoder:
  --
  --   * `user:{removed}` reaches the removed account's own devices at once,
  --     whatever topic they were joined to (`can_read_topic` always allows a
  --     caller their own user topic, including after the relink above);
  --   * `firm:{firm}` refreshes every remaining member's roster view.
  --
  -- The DELETE above fires no row trigger — the broadcast trigger is
  -- INSERT/UPDATE only — so this announcement is explicit rather than implied.
  perform realtime.send(
    jsonb_build_object('table', 'firm_members', 'id', p_user_id),
    'row_change',
    'user:' || p_user_id::text,
    true
  );
  perform realtime.send(
    jsonb_build_object('table', 'firm_members', 'id', p_user_id),
    'row_change',
    'firm:' || v_firm_id::text,
    true
  );

  return jsonb_build_object(
    'status', 'removed',
    'user_id', p_user_id,
    'firm_id', v_firm_id
  );
end;
$$;

comment on function public.remove_firm_member(uuid) is
  'Owner-only: ends a membership, relinks the member to individual mode and announces the removal. Never reassigns authored records.';

revoke all on function public.remove_firm_member(uuid) from public, anon;
grant execute on function public.remove_firm_member(uuid) to authenticated;

-- `firm_members` joins the broadcast list, for the half of this phase that is
-- not a removal: a permission toggle or a new membership must reach the member
-- it affects. The trigger reuses `broadcast_row_change()` unchanged, so the
-- ping goes to `firm:{firm_id}` (the payload's first scoping column), which is
-- the topic every member of that firm is already authorized for.
drop trigger if exists trg_firm_members_broadcast on public.firm_members;
create trigger trg_firm_members_broadcast
  after insert or update on public.firm_members
  for each row execute function public.broadcast_row_change();
