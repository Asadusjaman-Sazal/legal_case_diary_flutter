-- A delete request whose record someone else deleted closes itself.
--
-- The gap this closes: a request is a request to delete *a record*, but nothing
-- watched the record. A member holding `can_delete` could delete the case a
-- colleague had already asked about, and the request stayed `pending` for ever.
-- It then sat in every reviewer's queue as something that could never succeed:
-- an approval found the target already tombstoned and answered
-- `already_resolved` while leaving the request exactly as it was, so the row
-- came straight back to the queue, and the requester's own list still said
-- "waiting". The only way out was to **reject** it, which recorded a decision
-- that never happened.
--
-- The rule below is the honest one: when a record a request names is tombstoned,
-- the request is answered by that fact. It becomes `already_deleted`, which is a
-- terminal state (the client reads it as a decided request, so it leaves the
-- queue and the requester is told), and the write happens in the same
-- transaction as the deletion, so every device learns it through the ordinary
-- pull whether or not anyone opens the review screen.
--
-- It is a trigger rather than another branch inside `push_changes_core` because
-- that function is regenerated whole by each migration that touches it, and this
-- rule belongs to the table, not to one RPC: a deletion made by any path — the
-- app's push, a direct admin edit, a future RPC — closes the request the same
-- way. The approval path keeps working untouched: an approval tombstones the
-- target *before* it writes `status = 'approved'`, so the approval's own write is
-- the last one and the request ends approved, not already_deleted.
--
-- Proven by `supabase/tests/delete_request_closure_test.sql`.

create or replace function public.close_delete_requests_for_deleted_target()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_entity_type text;
  v_ms bigint;
begin
  -- An AFTER trigger that only cares about a tombstone being created.
  if not (old.is_deleted = false and new.is_deleted = true) then
    return null;
  end if;

  -- The singular entity type a request stores for the table that changed. The
  -- four tables are the only ones `delete_requests` may name.
  v_entity_type := case tg_table_name
    when 'cases' then 'case'
    when 'case_history' then 'case_history'
    when 'notes' then 'note'
    when 'case_references' then 'reference'
  end;

  if v_entity_type is null then
    return null;
  end if;

  v_ms := (extract(epoch from clock_timestamp()) * 1000)::bigint;

  -- Only requests still open are closed; a decided one is audit history and is
  -- never rewritten. The firm comparison keeps the rule inside the chamber that
  -- owns the record, exactly as the approval branch does.
  update public.delete_requests r
     set status = 'already_deleted',
         version = r.version + 1,
         updated_at = v_ms,
         last_modified_by = coalesce(new.last_modified_by, r.last_modified_by)
   where r.entity_type = v_entity_type
     and r.entity_id = new.id
     and r.is_deleted = false
     and r.status in ('pending', 'stale_review_required')
     and r.firm_id is not distinct from new.firm_id;

  return null;
end;
$$;

comment on function public.close_delete_requests_for_deleted_target() is
  'AFTER UPDATE OF is_deleted on the four records a delete request may name: closes every still-open request for that row as already_deleted, in the same transaction as the tombstone, so a request never outlives its record. A decided request is never rewritten, and an approved request still ends approved because the approval writes last.';

revoke all on function public.close_delete_requests_for_deleted_target()
  from public, anon, authenticated;

drop trigger if exists cases_close_delete_requests on public.cases;
create trigger cases_close_delete_requests
  after update of is_deleted on public.cases
  for each row
  execute function public.close_delete_requests_for_deleted_target();

drop trigger if exists case_history_close_delete_requests
  on public.case_history;
create trigger case_history_close_delete_requests
  after update of is_deleted on public.case_history
  for each row
  execute function public.close_delete_requests_for_deleted_target();

drop trigger if exists notes_close_delete_requests on public.notes;
create trigger notes_close_delete_requests
  after update of is_deleted on public.notes
  for each row
  execute function public.close_delete_requests_for_deleted_target();

drop trigger if exists case_references_close_delete_requests
  on public.case_references;
create trigger case_references_close_delete_requests
  after update of is_deleted on public.case_references
  for each row
  execute function public.close_delete_requests_for_deleted_target();

-- Requests already left hanging by the old behaviour: the record it names is
-- tombstoned, so close them now rather than waiting for a reviewer to press a
-- button that cannot work.
--
-- A tombstoned row is required rather than a merely absent one. A request can be
-- pushed before the record it names (two queue entries, no ordering between
-- them), so "the row is not here" is not proof that it was deleted — only
-- `is_deleted = true` is.
update public.delete_requests r
   set status = 'already_deleted',
       version = r.version + 1,
       updated_at = (extract(epoch from clock_timestamp()) * 1000)::bigint
 where r.is_deleted = false
   and r.status in ('pending', 'stale_review_required')
   and (
     (r.entity_type = 'case'
       and exists (
         select 1 from public.cases t
          where t.id = r.entity_id and t.is_deleted = true
       ))
     or (r.entity_type = 'case_history'
       and exists (
         select 1 from public.case_history t
          where t.id = r.entity_id and t.is_deleted = true
       ))
     or (r.entity_type = 'note'
       and exists (
         select 1 from public.notes t
          where t.id = r.entity_id and t.is_deleted = true
       ))
     or (r.entity_type = 'reference'
       and exists (
         select 1 from public.case_references t
          where t.id = r.entity_id and t.is_deleted = true
       ))
   );

-- One open request per record. Two colleagues asking about the same case used to
-- create two rows for one deletion: the first approval removed the record and the
-- second became permanently pointless. Partial (not a table constraint) because
-- decided and withdrawn rows are history and may repeat.
create unique index if not exists delete_requests_one_open_per_target
  on public.delete_requests (entity_type, entity_id)
  where is_deleted = false
    and status in ('pending', 'stale_review_required');

comment on index public.delete_requests_one_open_per_target is
  'At most one open (pending or stale) delete request per record; decided and withdrawn rows are audit history and are not constrained.';
