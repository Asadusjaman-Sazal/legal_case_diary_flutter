-- Task 12's Manage Account actions, built (0.0.411) — delete_my_account():
-- the account holder's own, complete removal of their account.
--
-- Why this exists. Manage Account's **Delete Account** card was the last Part A
-- placeholder on the Settings surface: it warned nothing and did nothing. Making
-- it real cannot be a client query — an account is made of server rows —
-- `profiles`, the domain rows it authored, its preferences, its payment
-- submissions and the `auth.users` row itself — and no client may write any of
-- them (AGENTS.md rule 12). So it is a `SECURITY DEFINER` function, exactly like
-- `abandon_provisional_account()`, with one difference that shapes everything
-- below: that one may only remove an account that provably never did anything,
-- while this one removes an account that has *done* everything, and must leave
-- no residue of it behind.
--
-- Table classes (AGENTS.md rule 4). The function writes across four of them, and
-- gives each the treatment that class requires:
--   * **push/pull domain** (`cases`, `case_history`, `notes`,
--     `case_references`, `conflict_log`, `delete_requests`, and the caller's
--     custom rows in the six editable reference tables) — hard-deleted, because
--     a soft delete is exactly the residue this is for. Nothing is queued and
--     nothing is broadcast: the account is going away, so there is no other
--     device to tell (any device still holding its own copy is wiped on its own
--     next launch, by the sign-out the client runs after this returns).
--   * **pull-only cache** (`profiles`, `firm_members`) — removed with the
--     account.
--   * **per-user preference** (`user_preferences`,
--     `case_notification_preferences`) and **server-managed** (`invite_attempts`,
--     `app_admins`, `mutation_receipts`, `payment_submissions`,
--     `payment_approval_events`) — removed too; row by row where the class allows
--     it, and by `on delete cascade` from `auth.users` where it does not.
--   * **server-managed, and kept**: nothing. "No residue" is the requirement.
--
-- What is refused, and why it must be. Two kinds of account hold rows that are
-- not only theirs, and the client cannot tell them apart from the rest, so the
-- server answers and the screen words the answer:
--   * **a firm account** (`profiles.firm_id`, or owning a `firms` row): the
--     domain rows a firm shares belong to the firm, and deleting them would take
--     a colleague's diary with them. The owner has to remove the account from
--     the firm first (the roster and its remove action are Task 20's), and this
--     function says so instead of guessing.
--   * **an app administrator**: their rows include other people's payment
--     ledger.
-- Both refusals change nothing at all — they are checked before the first
-- `delete`.
--
-- What removal means, in order. Everything that references `auth.users` without
-- `on delete cascade` has to go first, children before parents, because those
-- foreign keys are what would otherwise refuse the final statement:
--   * `delete_requests` requested by the caller; a request they merely
--     **reviewed** is somebody else's row, so only its `reviewed_by` link is
--     cleared (the column is nullable for exactly this kind of case);
--   * `conflict_log`, `case_history` (authored, or about a case of theirs),
--     `notes`, `case_references`;
--   * `case_notification_preferences`, then `cases` — which cascades the
--     remaining history and per-case preferences;
--   * the caller's **custom** reference rows, children before parents: `steps`,
--     `case_types`, `on_behalfs`, `courts`, `case_categories`, then
--     `court_categories`. Seeded rows carry `user_id is null` and are untouched,
--     so the shared baseline every account reads survives;
--   * money: the approval ledger first, whose `payment_submission_id` FK is
--     `on delete restrict` — and which is otherwise immutable, so the trigger is
--     switched off for exactly the two statements that need it (see below) —
--     then the caller's own `payment_submissions`, then their
--     `mutation_receipts` (deleted after the domain rows, since a receipt is the
--     record of a mutation those rows carried);
--   * `firm_invites` the caller issued and `firm_members` rows of theirs (the
--     latter also cascade, but stating it keeps the read honest);
--   * and finally `delete from auth.users`, which cascades `profiles`,
--     `user_preferences`, `case_notification_preferences`, `invite_attempts`,
--     `app_admins` and `firm_members` — and with them the account's sessions and
--     refresh tokens, so nothing can be resumed afterwards.
--
-- The ledger's trigger, switched off on purpose. `payment_approval_events` is an
-- immutable audit ledger: `trg_payment_approval_events_immutable` raises on any
-- UPDATE or DELETE, for every role ("for every role that does not first disable
-- the trigger deliberately" — its own comment). Removing an account means the
-- ledger rows naming it have to go: they are `not null` references, they cannot
-- be anonymized in place, and its `payment_submission_id` FK is
-- `on delete restrict`, so the submission could not go either. The two
-- statements below are the deliberate exception the trigger's comment allows.
-- They run inside this transaction with their `delete`, so the trigger can never
-- be left disabled — a failure rolls the whole thing back, trigger included.
--
-- Returns the project's usual envelope: `{"status":"removed"}`,
-- `{"status":"refused","reason":"firm"|"administrator"}`, or
-- `{"status":"unauthenticated"}`.

create or replace function public.delete_my_account()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_firm_id uuid;
  v_refusal text;
begin
  if v_user_id is null then
    return jsonb_build_object('status', 'unauthenticated');
  end if;

  -- Refusal 1: a firm account. Checked against both halves of "belongs to a
  -- firm" — the profile's own firm link (what the app calls firm mode) and
  -- ownership of a firm row, which is what the domain rows are shared through.
  select p.firm_id into v_firm_id from public.profiles p where p.id = v_user_id;

  if v_firm_id is not null
     or exists (select 1 from public.firms f where f.owner_id = v_user_id) then
    v_refusal := 'firm';
  end if;

  -- Refusal 2: an administrator. `app_admins` is server-internal, and an admin's
  -- rows include the payment ledger of every other account.
  if v_refusal is null
     and exists (select 1 from public.app_admins a where a.user_id = v_user_id)
  then
    v_refusal := 'administrator';
  end if;

  if v_refusal is not null then
    return jsonb_build_object('status', 'refused', 'reason', v_refusal);
  end if;

  -- --- Domain rows: everything the caller authored, children before parents. ---

  -- The caller's own requests go. A request they reviewed belongs to somebody
  -- else, so the reviewer link is the only part of it that is theirs.
  update public.delete_requests
     set reviewed_by = null
   where reviewed_by = v_user_id;
  delete from public.delete_requests where requested_by = v_user_id;

  delete from public.conflict_log where user_id = v_user_id;

  -- Authored history, plus any history of a case of theirs (the rest cascades
  -- from `cases` below).
  delete from public.case_history
   where user_id = v_user_id or created_by = v_user_id;

  delete from public.notes where user_id = v_user_id;
  delete from public.case_references where user_id = v_user_id;
  delete from public.case_notification_preferences where user_id = v_user_id;

  -- Cases last among the case data: `court_id`, `case_category_id` and
  -- `on_behalf_id` point at the reference rows deleted below.
  delete from public.cases where user_id = v_user_id;

  -- Custom reference rows. Seeded rows have `user_id is null`, so the baseline
  -- every account reads is untouched. Steps, case types and on-behalfs point at
  -- a court category, case types may point at a case category, and courts point
  -- at a court category: children first, `court_categories` last.
  delete from public.steps where user_id = v_user_id;
  delete from public.case_types where user_id = v_user_id;
  delete from public.on_behalfs where user_id = v_user_id;
  delete from public.courts where user_id = v_user_id;
  delete from public.case_categories where user_id = v_user_id;
  delete from public.court_categories where user_id = v_user_id;

  -- --- Money and audit rows. ---

  -- The deliberate exception described in the header: the ledger refuses deletes
  -- for every role, and this is the one legitimate reason to switch it off. Both
  -- statements and the delete are in this transaction, so the trigger is never
  -- left disabled.
  alter table public.payment_approval_events
    disable trigger trg_payment_approval_events_immutable;
  delete from public.payment_approval_events
   where user_id = v_user_id or approved_by = v_user_id;
  alter table public.payment_approval_events
    enable trigger trg_payment_approval_events_immutable;

  delete from public.payment_submissions where user_id = v_user_id;

  -- After the domain rows: a receipt is the record of a mutation they carried.
  delete from public.mutation_receipts where actor_id = v_user_id;

  -- --- Firm links the callers of a refused account cannot have; stated anyway. ---

  delete from public.firm_invites where created_by = v_user_id;
  delete from public.firm_members where user_id = v_user_id;

  -- --- The account itself. ---
  --
  -- One statement, and it cannot fail on a foreign key: every reference that does
  -- not cascade has been removed above, and the ones that do — `profiles`,
  -- `user_preferences`, `case_notification_preferences`, `invite_attempts`,
  -- `app_admins`, `firm_members` — go with it, along with the Auth sessions.
  delete from auth.users u where u.id = v_user_id;

  return jsonb_build_object('status', 'removed');
end;
$$;

comment on function public.delete_my_account() is
  'The account holder''s own complete deletion: removes every row of the caller''s account — domain rows, preferences, payment submissions and their approval events, sync receipts, firm links, and the Auth account itself — leaving no residue. Refuses, changing nothing, for a firm account (profiles.firm_id or firms.owner_id) and for an app administrator, returning {"status":"refused","reason":…}; otherwise {"status":"removed"}. Takes no arguments: it can only ever act on auth.uid().';

-- A direct EXECUTE grant from Supabase's default privileges outlives a revoke of
-- PUBLIC, so `anon` is named explicitly — the same reason join_firm,
-- approve_payment, abandon_provisional_account and ensure_firm do it.
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
