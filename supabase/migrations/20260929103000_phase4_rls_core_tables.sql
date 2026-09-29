-- Phase 4 (1/3) — RLS for the case-data half of the push/pull domain.
--
-- The matrix, verbatim from the plan's Row-Level Security Strategy table:
--
--   cases / case_history  SELECT own or same-firm; INSERT own; UPDATE own or a
--                         firm member with can_edit (coarse — the can_delete
--                         transition is the Phase 3 trigger's job); DELETE
--                         never, because deletion is a soft delete.
--   notes / case_references  same shape.
--   delete_requests       firm members SELECT/INSERT; the requester may edit
--                         their own pending request, a can_delete reviewer may
--                         act on it; never DELETE (audit trail).
--   conflict_log          own rows only; never DELETE.
--
-- RLS `WITH CHECK` sees only the NEW row, so nothing here tries to express the
-- delete transition — see `enforce_delete_transition()`.

alter table public.cases enable row level security;
alter table public.case_history enable row level security;
alter table public.notes enable row level security;
alter table public.case_references enable row level security;
alter table public.delete_requests enable row level security;
alter table public.conflict_log enable row level security;

-- ---------------------------------------------------------------------------
-- cases
-- ---------------------------------------------------------------------------

drop policy if exists cases_select_scoped on public.cases;
create policy cases_select_scoped on public.cases
  for select to authenticated
  using (
    user_id = auth.uid()
    or firm_id = public.current_firm_id()
  );

drop policy if exists cases_insert_own on public.cases;
create policy cases_insert_own on public.cases
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and (firm_id is null or firm_id = public.current_firm_id())
  );

drop policy if exists cases_update_scoped on public.cases;
create policy cases_update_scoped on public.cases
  for update to authenticated
  using (
    user_id = auth.uid()
    or public.can_edit_firm(firm_id)
  )
  with check (
    user_id = auth.uid()
    or public.can_edit_firm(firm_id)
  );

-- No DELETE policy on purpose: deletion is `is_deleted = true`.

-- ---------------------------------------------------------------------------
-- case_history (user_id/firm_id are denormalized, so no join is needed)
-- ---------------------------------------------------------------------------

drop policy if exists case_history_select_scoped on public.case_history;
create policy case_history_select_scoped on public.case_history
  for select to authenticated
  using (
    user_id = auth.uid()
    or firm_id = public.current_firm_id()
  );

drop policy if exists case_history_insert_own on public.case_history;
create policy case_history_insert_own on public.case_history
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and (firm_id is null or firm_id = public.current_firm_id())
  );

drop policy if exists case_history_update_scoped on public.case_history;
create policy case_history_update_scoped on public.case_history
  for update to authenticated
  using (
    user_id = auth.uid()
    or public.can_edit_firm(firm_id)
  )
  with check (
    user_id = auth.uid()
    or public.can_edit_firm(firm_id)
  );

-- ---------------------------------------------------------------------------
-- notes
-- ---------------------------------------------------------------------------

drop policy if exists notes_select_scoped on public.notes;
create policy notes_select_scoped on public.notes
  for select to authenticated
  using (
    user_id = auth.uid()
    or firm_id = public.current_firm_id()
  );

drop policy if exists notes_insert_own on public.notes;
create policy notes_insert_own on public.notes
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and (firm_id is null or firm_id = public.current_firm_id())
  );

drop policy if exists notes_update_scoped on public.notes;
create policy notes_update_scoped on public.notes
  for update to authenticated
  using (
    user_id = auth.uid()
    or public.can_edit_firm(firm_id)
  )
  with check (
    user_id = auth.uid()
    or public.can_edit_firm(firm_id)
  );

-- ---------------------------------------------------------------------------
-- case_references
-- ---------------------------------------------------------------------------

drop policy if exists case_references_select_scoped on public.case_references;
create policy case_references_select_scoped on public.case_references
  for select to authenticated
  using (
    user_id = auth.uid()
    or firm_id = public.current_firm_id()
  );

drop policy if exists case_references_insert_own on public.case_references;
create policy case_references_insert_own on public.case_references
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and (firm_id is null or firm_id = public.current_firm_id())
  );

drop policy if exists case_references_update_scoped on public.case_references;
create policy case_references_update_scoped on public.case_references
  for update to authenticated
  using (
    user_id = auth.uid()
    or public.can_edit_firm(firm_id)
  )
  with check (
    user_id = auth.uid()
    or public.can_edit_firm(firm_id)
  );

-- ---------------------------------------------------------------------------
-- delete_requests
-- ---------------------------------------------------------------------------

drop policy if exists delete_requests_select_firm on public.delete_requests;
create policy delete_requests_select_firm on public.delete_requests
  for select to authenticated
  using (firm_id = public.current_firm_id());

drop policy if exists delete_requests_insert_firm on public.delete_requests;
create policy delete_requests_insert_firm on public.delete_requests
  for insert to authenticated
  with check (
    requested_by = auth.uid()
    and firm_id = public.current_firm_id()
  );

-- The requester edits their own still-pending request; a reviewer with
-- can_delete acts on it. Anything else is refused.
drop policy if exists delete_requests_update_scoped on public.delete_requests;
create policy delete_requests_update_scoped on public.delete_requests
  for update to authenticated
  using (
    (requested_by = auth.uid() and status = 'pending')
    or public.can_delete_firm(firm_id)
  )
  with check (
    requested_by = auth.uid()
    or public.can_delete_firm(firm_id)
  );

-- Never DELETE: the request queue is an audit trail, and a resolved request
-- stays visible after the target is tombstoned.

-- ---------------------------------------------------------------------------
-- conflict_log (own rows only; the mirror exists for cross-device portability)
-- ---------------------------------------------------------------------------

drop policy if exists conflict_log_select_own on public.conflict_log;
create policy conflict_log_select_own on public.conflict_log
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists conflict_log_insert_own on public.conflict_log;
create policy conflict_log_insert_own on public.conflict_log
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and (firm_id is null or firm_id = public.current_firm_id())
  );

drop policy if exists conflict_log_update_own on public.conflict_log;
create policy conflict_log_update_own on public.conflict_log
  for update to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and (firm_id is null or firm_id = public.current_firm_id())
  );
