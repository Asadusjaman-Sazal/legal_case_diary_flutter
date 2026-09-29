-- Phase 4 (3/3) — RLS for the account, firm, preference and payment tables,
-- and the closing statement of "RLS is enabled on every table".
--
-- Matrix (plan, Row-Level Security Strategy + Rev 2.4 §1):
--
--   profiles          readable by self AND same-firm members (Manage
--                     Associates, and the "edited by [Name]" rendering);
--                     UPDATE self only; no INSERT (the sign-up trigger owns
--                     creation); no DELETE.
--   firms             owner or member SELECT; owner INSERT/UPDATE; no DELETE.
--   firm_members      firm members SELECT; the firm owner INSERT/UPDATE/DELETE
--                     (removing an associate is how access is revoked).
--   firm_invites      owner-only everything; redemption goes exclusively
--                     through join_firm(), which is SECURITY DEFINER and never
--                     needs a client policy.
--   payment_submissions  own SELECT and INSERT (the Phase 3 trigger adds the
--                     rate limit); no ordinary UPDATE — approval is the RPC.
--   payment_approval_events  own receipt, or any event for an admin; no writes.
--   user_preferences / case_notification_preferences  self-only, never
--                     firm-shared, no DELETE.
--
-- The four server-internal tables (invite_attempts, mutation_receipts,
-- app_admins, plus payment_approval_events' write side) keep RLS enabled with
-- no policy where the plan says so.

alter table public.profiles enable row level security;
alter table public.firms enable row level security;
alter table public.firm_members enable row level security;
alter table public.firm_invites enable row level security;
alter table public.payment_submissions enable row level security;
alter table public.payment_approval_events enable row level security;
alter table public.user_preferences enable row level security;
alter table public.case_notification_preferences enable row level security;

-- Re-asserted here so "RLS is on for every table this task creates" is one
-- statement about one file, not something to reconstruct from three.
alter table public.invite_attempts enable row level security;
alter table public.mutation_receipts enable row level security;
alter table public.app_admins enable row level security;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------

drop policy if exists profiles_select_self_or_firm on public.profiles;
create policy profiles_select_self_or_firm on public.profiles
  for select to authenticated
  using (
    id = auth.uid()
    or (firm_id is not null and firm_id = public.current_firm_id())
  );

-- UPDATE self only. Which columns may move is decided by the Phase 3 column
-- revokes (role, firm_id and the entitlement pair are server-owned).
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- No INSERT policy: `handle_new_user()` creates the row as the owner.

-- ---------------------------------------------------------------------------
-- firms
-- ---------------------------------------------------------------------------

drop policy if exists firms_select_owner_or_member on public.firms;
create policy firms_select_owner_or_member on public.firms
  for select to authenticated
  using (
    owner_id = auth.uid()
    or id = public.current_firm_id()
  );

drop policy if exists firms_insert_owner on public.firms;
create policy firms_insert_owner on public.firms
  for insert to authenticated
  with check (owner_id = auth.uid());

drop policy if exists firms_update_owner on public.firms;
create policy firms_update_owner on public.firms
  for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- ---------------------------------------------------------------------------
-- firm_members
-- ---------------------------------------------------------------------------

drop policy if exists firm_members_select_firm on public.firm_members;
create policy firm_members_select_firm on public.firm_members
  for select to authenticated
  using (firm_id = public.current_firm_id());

drop policy if exists firm_members_insert_owner on public.firm_members;
create policy firm_members_insert_owner on public.firm_members
  for insert to authenticated
  with check (public.is_firm_owner(firm_id));

drop policy if exists firm_members_update_owner on public.firm_members;
create policy firm_members_update_owner on public.firm_members
  for update to authenticated
  using (public.is_firm_owner(firm_id))
  with check (public.is_firm_owner(firm_id));

drop policy if exists firm_members_delete_owner on public.firm_members;
create policy firm_members_delete_owner on public.firm_members
  for delete to authenticated
  using (public.is_firm_owner(firm_id));

-- ---------------------------------------------------------------------------
-- firm_invites (owner-only; redemption is join_firm(), not table access)
-- ---------------------------------------------------------------------------

drop policy if exists firm_invites_select_owner on public.firm_invites;
create policy firm_invites_select_owner on public.firm_invites
  for select to authenticated
  using (public.is_firm_owner(firm_id));

drop policy if exists firm_invites_insert_owner on public.firm_invites;
create policy firm_invites_insert_owner on public.firm_invites
  for insert to authenticated
  with check (
    public.is_firm_owner(firm_id)
    and created_by = auth.uid()
  );

drop policy if exists firm_invites_update_owner on public.firm_invites;
create policy firm_invites_update_owner on public.firm_invites
  for update to authenticated
  using (public.is_firm_owner(firm_id))
  with check (public.is_firm_owner(firm_id));

-- No DELETE policy: an unused code is revoked, never removed.

-- ---------------------------------------------------------------------------
-- payment_submissions
-- ---------------------------------------------------------------------------

drop policy if exists payment_submissions_select_own on public.payment_submissions;
create policy payment_submissions_select_own on public.payment_submissions
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists payment_submissions_insert_own on public.payment_submissions;
create policy payment_submissions_insert_own on public.payment_submissions
  for insert to authenticated
  with check (user_id = auth.uid());

-- No UPDATE or DELETE policy: approval is approve_payment() only.

-- ---------------------------------------------------------------------------
-- payment_approval_events
-- ---------------------------------------------------------------------------

drop policy if exists payment_approval_events_select_own_or_admin
  on public.payment_approval_events;
create policy payment_approval_events_select_own_or_admin
  on public.payment_approval_events
  for select to authenticated
  using (
    user_id = auth.uid()
    or public.is_admin()
  );

-- ---------------------------------------------------------------------------
-- per-user preferences (self-only, never firm-shared)
-- ---------------------------------------------------------------------------

drop policy if exists user_preferences_select_own on public.user_preferences;
create policy user_preferences_select_own on public.user_preferences
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists user_preferences_insert_own on public.user_preferences;
create policy user_preferences_insert_own on public.user_preferences
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists user_preferences_update_own on public.user_preferences;
create policy user_preferences_update_own on public.user_preferences
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists case_notification_preferences_select_own
  on public.case_notification_preferences;
create policy case_notification_preferences_select_own
  on public.case_notification_preferences
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists case_notification_preferences_insert_own
  on public.case_notification_preferences;
create policy case_notification_preferences_insert_own
  on public.case_notification_preferences
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists case_notification_preferences_update_own
  on public.case_notification_preferences;
create policy case_notification_preferences_update_own
  on public.case_notification_preferences
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
