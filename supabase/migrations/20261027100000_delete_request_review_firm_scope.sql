-- The delete-request rule reads the firm the row actually has.
--
-- `push_changes` subtracts the scope columns from the row it hands
-- `sync_can_write` (§3.3's "an existing row keeps the firm it has"). For every
-- other table that is harmless: `enforce_member_permission()` gates `can_edit`
-- on the ten gated tables, and `enforce_delete_transition()` reads `old.firm_id`
-- for the tombstone gate, so neither rule needs the firm in the row.
--
-- `delete_requests` has no permission trigger — raising a request must stay open
-- to every member, so `20261016100000` deliberately left the table out — which
-- made its update/delete branch the one rule the subtracted firm decided. Read
-- against a null firm, `can_delete_firm(null)` is false and the requester's own
-- `firm_id is not distinct from current_firm_id()` comparison is false too, so
-- **a reviewer's rejection, a requester's snapshot refresh and a withdrawal were
-- all refused with `permission_denied`** — the client rolls such a mutation back
-- from its pre-mutation snapshot, so the request returned to the review queue
-- and the app raised its "Your firm permissions changed" notice even though no
-- permission had changed. An approval was unaffected: that branch validates
-- `v_existing -> firm_id` and builds its own `v_final` with the firm intact.
--
-- The fix is one lookup: when the row names no firm, read the stored request's
-- own `firm_id` before answering. The comparison is by `id::text` against the
-- lower-cased id, so a malformed value cannot raise a cast error and the lookup
-- cannot become the thing that refuses a valid write. Everything else in the
-- function is the shipped body verbatim (`20261016100000`, which is the newest
-- of its three definitions), still SECURITY DEFINER with a pinned search_path.
--
-- Proven by `supabase/tests/delete_request_review_test.sql`, which drives all
-- four decisions through `push_changes` as the roles the app uses.

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
  -- The firm a delete-request rule weighs: the row's own when it carries one,
  -- otherwise the stored request's.
  v_request_firm uuid;
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
    --
    -- A review reaches this function without the firm in the row (see the file
    -- header), so the firm is taken from the request the payload names when the
    -- row itself has none. An update that names no such request — an id this
    -- table does not hold — stays unfirm and is refused, which is the safe
    -- direction: no caller may delete in a firm that cannot be read.
    v_request_firm := nullif(p_row ->> 'firm_id', '')::uuid;
    if v_request_firm is null then
      select d.firm_id into v_request_firm
        from public.delete_requests d
       where d.id::text = lower(nullif(p_row ->> 'id', ''));
    end if;

    return (
      coalesce((p_row ->> 'requested_by')::uuid, null) = v_actor
      and (p_row ->> 'status') = 'pending'
      and v_request_firm is not distinct from public.current_firm_id()
    ) or public.can_delete_firm(v_request_firm);
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
  'Explicit write re-check for push_changes: same rules as the Phase 4 RLS policies, evaluated on the row that would be written, plus the Phase 5 can_add gate on a create. A firm comparison uses `is not distinct from`, because `=` against a NULL current_firm_id would yield NULL and slip past an `if not`. Authorship of a firm-scoped row is honoured only while the row''s firm is still the caller''s firm, so a removed member cannot merge a queued write. An update is not gated here: enforce_member_permission() is the enforcement for can_edit, and it can be, because push_changes subtracts firm_id from the row it passes here — a rule that cannot see the firm cannot weigh can_edit. The one update rule that needs the firm anyway — delete_requests, whose table carries no permission trigger — reads the stored request''s firm_id when the row itself names none, so a review and a withdrawal are judged against the firm the request belongs to.';

-- The RPC's helper stays reachable by no client role directly: push_changes is
-- the only entry point, and it calls this as owner. `create or replace` keeps
-- the existing ACL; the revoke is restated so this file records the posture.
revoke all on function public.sync_can_write(text, jsonb, text)
  from public, anon, authenticated;
