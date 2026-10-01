-- Task 20 follow-up (RLS) — authorship of a firm-scoped row is a membership
-- claim, not a permanent one.
--
-- The 0.0.330 migration closed this hole in `sync_can_write`, which is the path
-- the app itself uses. It could not close it in the *policies*, and the audit
-- left that open deliberately rather than silently: a table policy still said
-- `user_id = auth.uid()` on a firm-scoped row, so a removed associate — whose
-- authored rows keep their `user_id`, because attribution is immutable — could
-- still write those rows straight through PostgREST, without the sync RPC ever
-- being consulted. It is not a theoretical gap: `cases_update_scoped`'s `with
-- check` asked only that the NEW row keep `user_id = auth.uid()`, so a removed
-- member could rewrite a firm record or move it out of the firm by nulling
-- `firm_id`.
--
-- This migration makes the policies say what `sync_can_write` now says, in the
-- same places that trust authorship:
--
--   * ordinary push/pull rows — cases, case_history, notes, case_references;
--   * the six editable reference tables — only the author clause moves, the
--     `is_custom` handling stays exactly as Task 16 wrote it;
--   * a requester's own still-pending `delete_requests` row, which is the one
--     place the author column is named `requested_by`;
--   * `conflict_log`, whose policies were already own-rows-only and gain the
--     membership condition and nothing else.
--
-- Three deliberate limits, so this stays a security fix and not a redesign:
---   1. **Only INSERT and UPDATE policies change.** The SELECT policies compare
--      the row's firm to the caller's with a plain equality, and a NULL on
--      either side makes that comparison NULL — which is not true, so a caller
--      with no firm already reads nothing from a firm row. `is not distinct
--      from` would be exactly equivalent there; rewriting a read policy for no
--      behavioural gain is risk without reward.
--   2. **Privileges are untouched.** The client writes these tables only through
--      `push_changes` (a `security definer` function, so it runs with the
--      migration owner's privileges and is unaffected by any grant the
--      `authenticated` role holds), while the pull is SELECT-only. Revoking
--      INSERT/UPDATE/DELETE from `authenticated` would close the direct path
--      too, but it was put to the user and declined in favour of fixing the
--      policies themselves — so the direct path is now refused *by policy*.
--   3. **A personal row (`firm_id is null`) stays entirely its author's**, before
--      and after removal. That is the individual diary AGENTS.md rule 3
--      protects: an associate who leaves a firm keeps it, and the firm never
--      gains a claim on it.
--
-- `can_edit_firm` / `can_delete_firm` are unchanged and still cover teammates
-- and reviewers; their NULL-safe `p_firm_id is not null` guard is what makes the
-- disjunct harmless for a caller with no firm.

-- ---------------------------------------------------------------------------
-- The ten tables that share one author-clause shape.
--
-- `cases`, `case_history`, `notes` and `case_references` are the case-data half
-- of the push/pull domain; the six reference tables are the editable
-- configuration half. Both halves name the same policy patterns
-- (`<table>_insert_own`, `<table>_update_scoped`), so one loop keeps the twelve
-- spellings from drifting apart.
-- ---------------------------------------------------------------------------

do $$
declare
  v_table text;
  v_tables text[] := array[
    'cases', 'case_history', 'notes', 'case_references',
    'court_categories', 'case_categories', 'courts', 'steps', 'case_types',
    'on_behalfs'
  ];
begin
  foreach v_table in array v_tables loop
    -- INSERT: as yourself, into your own firm or into no firm at all.
    execute format(
      'drop policy if exists %1$s_insert_own on public.%1$I',
      v_table
    );
    execute format(
      'create policy %1$s_insert_own on public.%1$I for insert to '
      'authenticated with check (user_id = auth.uid() and (firm_id is null or '
      'firm_id is not distinct from public.current_firm_id()))',
      v_table
    );

    -- UPDATE: your own row while its firm is still your firm, or a firm member
    -- with `can_edit`. USING and WITH CHECK say the same thing, which is what
    -- stops a row being updated *into* a state its writer could not have
    -- created — the previous asymmetry let a removed author detach a firm row
    -- by nulling `firm_id`.
    execute format(
      'drop policy if exists %1$s_update_scoped on public.%1$I',
      v_table
    );
    execute format(
      'create policy %1$s_update_scoped on public.%1$I for update to '
      'authenticated using ((user_id = auth.uid() and (firm_id is null or '
      'firm_id is not distinct from public.current_firm_id())) or '
      'public.can_edit_firm(firm_id)) with check ((user_id = auth.uid() and '
      '(firm_id is null or firm_id is not distinct from '
      'public.current_firm_id())) or public.can_edit_firm(firm_id))',
      v_table
    );
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- conflict_log — own rows only, and now only while that authorship is current.
--
-- No `can_edit_firm` disjunct, exactly as before: a conflict log is a device's
-- own record of a merge it performed (the mirror exists so the same conflict can
-- be read on another device), and a firm member has no business writing a
-- colleague's. The policies were already `user_id = auth.uid()` on both sides
-- and change only by gaining the membership condition.
-- ---------------------------------------------------------------------------

drop policy if exists conflict_log_insert_own on public.conflict_log;
create policy conflict_log_insert_own on public.conflict_log
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and (firm_id is null or firm_id is not distinct from public.current_firm_id())
  );

drop policy if exists conflict_log_update_own on public.conflict_log;
create policy conflict_log_update_own on public.conflict_log
  for update to authenticated
  using (
    user_id = auth.uid()
    and (firm_id is null or firm_id is not distinct from public.current_firm_id())
  )
  with check (
    user_id = auth.uid()
    and (firm_id is null or firm_id is not distinct from public.current_firm_id())
  );

-- ---------------------------------------------------------------------------
-- delete_requests — the requester's own still-pending request.
--
-- A request is always firm-scoped (the insert policy has never allowed a
-- `firm_id`-less one), so there is no personal-row case here and every firm
-- comparison is `is not distinct from`. The requester may refresh the snapshot
-- or withdraw the request while it is pending *and* the firm is still theirs; a
-- reviewer with `can_delete` decides it. Nothing else is writable, and the
-- `with check` deliberately does not repeat `status = 'pending'`: a decision
-- moves the row out of that state, and only the reviewer's disjunct may do it.
-- ---------------------------------------------------------------------------

drop policy if exists delete_requests_insert_firm on public.delete_requests;
create policy delete_requests_insert_firm on public.delete_requests
  for insert to authenticated
  with check (
    requested_by = auth.uid()
    and firm_id is not distinct from public.current_firm_id()
  );

drop policy if exists delete_requests_update_scoped on public.delete_requests;
create policy delete_requests_update_scoped on public.delete_requests
  for update to authenticated
  using (
    (
      requested_by = auth.uid()
      and status = 'pending'
      and firm_id is not distinct from public.current_firm_id()
    )
    or public.can_delete_firm(firm_id)
  )
  with check (
    (
      requested_by = auth.uid()
      and firm_id is not distinct from public.current_firm_id()
    )
    or public.can_delete_firm(firm_id)
  );
