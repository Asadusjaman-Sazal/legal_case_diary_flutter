-- The withdrawal exit reads its two fields only on the table that has them.
--
-- `20261027110000` added the requester's own-pending-request exit to
-- `enforce_delete_transition()`, but wrote it as one condition:

--     if tg_table_name = 'delete_requests'
--        and old.status = 'pending'
--        and old.requested_by = auth.uid() then

-- `old` is a generic record, so `old.status` is resolved at run time — and on
-- the other **eleven** tables the trigger guards there is no `status` column to
-- resolve, so the trigger raised `record "old" has no field "status"` on every
-- tombstone: a case, note, reference, history row or custom court could no
-- longer be deleted at all. Caught by the proofs, not by reading — the case
-- delete in `supabase/tests/push_changes_smoke_test.sql` and the reference
-- tombstones in `supabase/tests/firm_mode_reference_in_use_guard_test.sql` both
-- failed within a minute of the apply, which is exactly what those files exist
-- for.
--
-- The rule is unchanged and stays exactly as `20261027110000` states it; only
-- the way it reads the row changes: the two `delete_requests` fields are read
-- inside the table test, where nothing else can reach them.

create or replace function public.enforce_delete_transition()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if old.is_deleted = false and new.is_deleted = true then
    -- Individual rows (no firm) are the creator's own; a firm row needs either
    -- the owner or a member holding can_delete. An associate without it must go
    -- through the delete-request workflow instead — and withdrawing their own
    -- request is that workflow's own exit, so it is allowed by the caller's own
    -- row rather than by a permission they do not have. `status` and
    -- `requested_by` exist on this one table only, which is why they are read
    -- inside the test rather than in the condition above it.
    if tg_table_name = 'delete_requests' then
      if old.status = 'pending' and old.requested_by = auth.uid() then
        return new;
      end if;
    end if;

    if not public.can_delete_firm(old.firm_id)
       and old.firm_id is not null then
      raise exception 'delete_not_permitted'
        using errcode = '42501',
              hint = 'Requires can_delete in this firm; raise a delete request instead.';
    end if;
  end if;
  return new;
end;
$$;

comment on function public.enforce_delete_transition() is
  'BEFORE UPDATE on the twelve domain tables: refuses is_deleted true unless the caller may delete in the row''s firm (owner or can_delete), with one carrying row excepted — a requester''s own still-pending delete request, which the delete-request workflow lets them withdraw. The exception reads status/requested_by inside the delete_requests test, because those columns exist on no other table this trigger guards.';
