-- Task 20 audit closure — `sync_can_write` now requires firm membership for a
-- firm-scoped write, not authorship alone.
--
-- Phase 2 item 5 says removing an associate must "reject and never merge that
-- member's queued mutations". `remove_firm_member` relinks `profiles.firm_id` to
-- NULL, and EVERY guard in the schema was assumed to read `firm_id` afterwards.
-- They do — except one: `sync_can_write`'s author clause, `user_id = auth.uid()`,
-- which is checked *before* any firm helper. `cases`, `notes` and
-- `case_references` rows keep their author's `user_id` (that is the "preserve
-- immutable audit attribution" rule), so a removed member could still push an
-- **update** to a firm record they happened to author.
--
-- There were really **two** defects, and the second is why the first went
-- unnoticed. The author clause was only half the problem; the firm comparison
-- itself was written `firm_id = current_firm_id()`. Once removal makes
-- `current_firm_id()` NULL, that comparison evaluates to NULL, not false — and
-- `if not (<NULL>) then return false` does not fire in PL/pgSQL, because
-- `NOT NULL` is NULL and a NULL condition is treated as "do not branch". So the
-- guard was permissive in exactly the case it existed for: a caller with no firm
-- writing a row that has one. Both INSERT and UPDATE paths shared it.
--
-- The fix is therefore twofold, applied together:
--
--   * **`is not distinct from`** replaces `=` for every firm comparison. A row's
--     firm must be *the same non-null firm* as the caller's; a NULL on either side
--     is now a definite "no" rather than a slipped-through NULL. The
--     `firm_id is null` disjunct that follows still lets a personal row through.
--   * **authorship no longer outlives membership.** A firm-scoped row may be
--     written by its author only while that firm is still their firm
--     (`firm_id is not distinct from current_firm_id()`). The rule RLS has always
--     expressed — an author may edit their own row, even without `can_edit` —
--     is kept for current members; what changes is that it stops at removal. A
--     `firm_id`-less (personal) row is unaffected, so a removed member keeps
--     their own diary. `can_edit_firm(firm_id)` still covers a teammate editing
--     rows they did not author.
--
-- The same two corrections apply to the other places that trusted authorship:
-- a custom **reference** in a firm, and a requester's own **pending delete
-- request**, were both writable on `user_id` / `requested_by` alone. Reviews
-- (`can_delete`) are untouched.
--
-- Only `sync_can_write` changes; `push_changes` already calls it, so no RPC is
-- replaced. The function stays `stable security definer`.

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
         );
    else
      return coalesce((p_row ->> 'user_id')::uuid, null) = v_actor
         and (
           p_row ->> 'firm_id' is null
           or coalesce((p_row ->> 'firm_id')::uuid, null)
                is not distinct from public.current_firm_id()
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
  'Explicit write re-check for push_changes: same rules as the Phase 4 RLS policies, evaluated on the row that would be written. A firm comparison uses `is not distinct from`, because `=` against a NULL current_firm_id would yield NULL and slip past an `if not`. Authorship of a firm-scoped row is honoured only while the row''s firm is still the caller''s firm, so a removed member cannot merge a queued write.';
