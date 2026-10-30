/// Assembles `supabase/AllSupabaseSql.md` — the single ordered record of every
/// SQL statement this project has ever run against Supabase (AGENTS.md rule 13).
///
///   dart run tool/generate_all_supabase_sql.dart          # writes the ledger
///   dart run tool/generate_all_supabase_sql.dart --check  # fails if it is stale
///
/// One section per file in `supabase/migrations/`, in filename (= creation)
/// order, grouped by the app version that was current when the phase landed.
/// Each section carries a labelled comment above the verbatim migration text, so
/// a reader never has to open the migration to know what it does.
///
/// A bootstrap section leads the file: the statements the applier
/// (`tool/apply_supabase_migrations.dart`) runs that are not migration files.
/// AGENTS.md rule 13 covers every statement, not only the versioned ones.
///
/// The output is deterministic on purpose — the version and label of each
/// migration live in [_sections] below, not in the file mtime — so `--check` is
/// a real guard. Line endings are always LF; the drift test normalizes CRLF
/// checkouts before comparing.
library;

import 'dart:io';

import 'apply_supabase_migrations.dart';

// The migration folder is defined once, in the applier: the two tools must read
// the same files, and a second copy of the path is a second thing to drift.
export 'apply_supabase_migrations.dart' show manualDir, migrationsDir;

/// The generated ledger, relative to the project root.
const String ledgerPath = 'supabase/AllSupabaseSql.md';

/// One migration file's entry in the ledger.
class LedgerSection {
  const LedgerSection({
    required this.file,
    required this.version,
    required this.label,
  });

  /// File name inside [migrationsDir] (its timestamp prefix is creation order).
  final String file;

  /// App version recorded by `tool/record_version.py` when this phase landed.
  final String version;

  /// What this section does and why, shown above its SQL.
  final String label;

  /// `20260929100000_phase1_core_schema.sql` -> `2026-09-29`.
  String get created {
    final match = RegExp(r'^(\d{4})(\d{2})(\d{2})').firstMatch(file);
    if (match == null) {
      throw StateError('Migration "$file" has no yyyyMMdd timestamp prefix.');
    }
    return '${match.group(1)}-${match.group(2)}-${match.group(3)}';
  }
}

/// Every migration, in creation order. A new migration MUST be added here or
/// [buildAllSupabaseSql] throws and both the tool's `--check` and
/// `test/supabase/all_supabase_sql_test.dart` fail.
const List<LedgerSection> _sections = <LedgerSection>[
  LedgerSection(
    file: '20260929100000_phase1_core_schema.sql',
    version: '0.0.289',
    label:
        'Creates every Supabase table at once — 12 push/pull domain, 3 '
        'pull-only cache, 2 per-user preference and 2 server-managed — mirroring '
        'the shipped Drift columns. RLS is switched on in the same statement that '
        'creates each table.',
  ),
  LedgerSection(
    file: '20260929100100_phase1_signup_profile_trigger.sql',
    version: '0.0.289',
    label:
        'handle_new_user() and its on_auth_user_created trigger: each new '
        'auth user gets an individual, free, firm-less profiles row. The only '
        'INSERT path for profiles.',
  ),
  LedgerSection(
    file: '20260929100200_phase1_seed_reference_data.sql',
    version: '0.0.289',
    label:
        'Generated built-in reference data — 1,442 rows over six editable '
        'tables, under the same stable IDs the client seeds — upserted so a '
        'customized row is never overwritten.',
  ),
  LedgerSection(
    file: '20260929101000_phase2_server_internal_tables.sql',
    version: '0.0.290',
    label:
        'The four server-internal ledgers (invite_attempts, '
        'mutation_receipts, app_admins, payment_approval_events) with deny-all '
        'RLS, two immutability triggers and the rate-limit index.',
  ),
  LedgerSection(
    file: '20260929102000_phase3_access_helpers.sql',
    version: '0.0.291',
    label:
        'Access helpers (1/6): current_firm_id, is_firm_owner, can_edit_firm, '
        'can_delete_firm, is_premium, is_admin, can_read_topic and sha256_hex, '
        'all SECURITY DEFINER so policies cannot recurse.',
  ),
  LedgerSection(
    file: '20260929102100_phase3_sync_and_guard_triggers.sql',
    version: '0.0.291',
    label:
        'Sync and write guards (2/6): server_updated_at stamping, the delete '
        'transition and resurrection rules, the free-tier 50-case ceiling and the '
        'payment submission rate limit, on the domain tables only.',
  ),
  LedgerSection(
    file: '20260929102200_phase3_payment_approval.sql',
    version: '0.0.291',
    label:
        'approve_payment(uuid) (3/6): admin-only, atomic lock-validate-extend-'
        'mirror-audit path, plus mirror_owner_subscription_to_firm().',
  ),
  LedgerSection(
    file: '20260929102300_phase3_join_firm.sql',
    version: '0.0.291',
    label:
        'join_firm(code) (4/6): rate-limited, sha256-normalized invite '
        'redemption that creates the membership, relinks the profile and consumes '
        'the invite.',
  ),
  LedgerSection(
    file: '20260929102400_phase3_realtime_broadcast.sql',
    version: '0.0.291',
    label:
        'Realtime notification (5/6): one {table, id} Broadcast ping per '
        'change to the firm or user topic, with the can_read_topic policy on '
        'realtime.messages.',
  ),
  LedgerSection(
    file: '20260929102500_phase3_column_privileges.sql',
    version: '0.0.291',
    label:
        'Column privileges (6/6): REVOKEs so the fields only the server may '
        'write — approval state, entitlement, firm ownership — cannot be set by '
        'a client even inside a permitted UPDATE.',
  ),
  LedgerSection(
    file: '20260929103000_phase4_rls_core_tables.sql',
    version: '0.0.292',
    label:
        'RLS for the case-data half (1/3): cases, case_history, notes, '
        'case_references, delete_requests and conflict_log scoped to self or '
        'same-firm, with no DELETE policy anywhere.',
  ),
  LedgerSection(
    file: '20260929103100_phase4_rls_reference_tables.sql',
    version: '0.0.292',
    label:
        'RLS for the six editable reference tables (2/3): built-in rows '
        'readable by every authenticated user, custom rows scoped to creator or '
        'firm, soft delete only.',
  ),
  LedgerSection(
    file: '20260929103200_phase4_rls_account_payment_tables.sql',
    version: '0.0.292',
    label:
        'RLS for account, firm, preference and payment tables (3/3), and the '
        'closing statement that RLS is enabled on every table in the schema.',
  ),
  LedgerSection(
    file: '20260929104000_phase5_indexes_and_tombstone_purge.sql',
    version: '0.0.293',
    label:
        'Delta-pull and payment indexes for every scoped cursor read, plus '
        'purge_tombstones(365 days) scheduled daily through pg_cron.',
  ),
  LedgerSection(
    file: '20260929105000_profiles_last_successful_sync_at.sql',
    version: '0.0.300',
    label:
        'Closes the audit\'s last column-level gap: adds the plan\'s '
        '`profiles.last_successful_sync_at`, admin analytics only, with a '
        'comment stating that the extended-offline reset stays per-device in '
        'the local `sync_metadata`.',
  ),
  LedgerSection(
    file: '20260929110000_phase5_owner_firm_establishment.sql',
    version: '0.0.305',
    label:
        'ensure_firm(name) — the idempotent owner-side conversion from '
        'individual to firm: creates the owner\'s firm, relinks '
        '`profiles.firm_id`/`role` (both server-owned by the column privileges) '
        'and upserts the owner\'s `firm_members` row, so the invite generator '
        'has a firm to invite into.',
  ),
  LedgerSection(
    file: '20260929120000_abandon_provisional_account.sql',
    version: '0.0.307',
    label:
        'abandon_provisional_account() — the protected cleanup for an '
        'abandoned join-firm onboarding: removes the caller\'s own Auth account '
        'when it is provably provisional (no firm, individual role, no '
        'subscription, no authored rows, no firm/payment/admin/sync activity) '
        'and refuses with the reason otherwise, so an unfinished sign-up is '
        'treated as never created.',
  ),
  LedgerSection(
    file: '20260929130000_profiles_personal_details.sql',
    version: '0.0.310',
    label:
        'The account holder\'s own details on the profile row: '
        '`email` (mirrored from `auth.users` by the sign-up and e-mail-change '
        'triggers) plus `bar_association`, `membership_no`, `office_address` and '
        '`mobile_no`, granted column-wise for the caller\'s own row so the '
        'Profile screen writes them through PostgREST and a re-install never '
        'asks for them again.',
  ),
  LedgerSection(
    file: '20260930140000_push_changes.sql',
    version: '0.0.311',
    label:
        '`push_changes(rows jsonb)` — the single atomic push pipeline: '
        'entity-type/dependency-rank helpers, the firm-aware entitlement '
        'derivation and the write re-check, then one transaction with a '
        'savepoint per mutation, optimistic concurrency, idempotent '
        '`mutation_receipts`, authoritative `case_history` on a changed '
        '`next_date`, cascade soft-deletes and one result per mutation_id.',
  ),
  LedgerSection(
    file: '20260930150000_sync_server_time.sql',
    version: '0.0.313',
    label:
        '`sync_server_time()` — the server clock as a plain stable SQL '
        'function, granted to `authenticated` only, so a successful sync can '
        'compare device and server time and record the offset past two minutes.',
  ),
  LedgerSection(
    file: '20260930160000_conflict_mergeable_column.sql',
    version: '0.0.318',
    label:
        '`conflict_log.mergeable_conflict` — the detecting client\'s '
        'three-way verdict on the conflict, carried on the mirrored row so a '
        'second device reads the same answer instead of recomputing one from '
        'its own copy. `not null default false` reads an old or absent value as '
        '"needs a person".',
  ),
  LedgerSection(
    file: '20260930170000_push_changes_created_at_guard.sql',
    version: '0.0.318',
    label:
        '`push_changes` again, with one corrected guard: the insert-time '
        '`created_at` fallback now fills only an epoch-ms **integer** column, '
        'so `conflict_log`\'s server-owned `timestamptz` keeps its own default '
        'instead of receiving the client\'s milliseconds (which raised `22007` '
        'and made every conflict mirror a permanent rejection — found by '
        'running the smoke test with a `conflict_log` row in it).',
  ),
  LedgerSection(
    file: '20260930180000_ensure_firm_premium_gate.sql',
    version: '0.0.324',
    label:
        '`ensure_firm` again, with Task 20 Phase 1\'s two refusals: the '
        'individual -> firm-owner transition now requires a derived premium '
        'entitlement (plan §6 — the free plan is strictly individual and '
        'single-device; lapsed owners keep the firm they already have), and a '
        'member of somebody else\'s firm can no longer create a second one and '
        'relink their profile away from the rows they authored.',
  ),
  LedgerSection(
    file: '20260930190000_remove_firm_member.sql',
    version: '0.0.325',
    label:
        'Task 20 Phase 2\'s `remove_firm_member(uuid)`: owner-only, '
        '`SECURITY DEFINER`, it deletes the membership row and relinks the '
        'member\'s `profiles.firm_id` / `role` to individual — which is what '
        'revokes RLS access, Realtime topic authorization and every queued '
        'write at once, without touching the auth session (this project has no '
        'service-role key). Authored records keep their attribution and are '
        'never reassigned; the removal is announced to the removed account\'s '
        'own topic and to the firm\'s. The same migration attaches the '
        'existing broadcast trigger to `firm_members`, so a permission toggle '
        'reaches the member it affects.',
  ),
  LedgerSection(
    file: '20260930200000_push_changes_delete_review.sql',
    version: '0.0.327',
    label:
        'Task 20 Phase 4\'s delete-review branch: `push_changes` replaces '
        'whole to teach an approval (a `delete_requests` update setting '
        '`status = \'approved\'`) what it means server-side. The request is '
        'locked (already) and the target is locked next, always in that order '
        'so concurrent approvals cannot deadlock; only a member with '
        '`can_delete` may review; a target at a different version than the '
        'request\'s `target_base_version` becomes `target_conflict`, parking the '
        'request as `stale_review_required` with the version the reviewer just '
        'saw so a reconfirm re-decides against the row that exists; an already '
        'soft-deleted target becomes `already_resolved` with its tombstone and '
        'records no decision; and an unchanged target is tombstoned atomically '
        'with its `case_history` cascade and the request resolved beside it, '
        'all inside the per-mutation savepoint that already produces idempotent '
        'receipts.',
  ),
  LedgerSection(
    file: '20260930210000_sync_can_write_firm_membership.sql',
    version: '0.0.330',
    label:
        'Task 20 audit closure: `sync_can_write` again, so authorship of a '
        'firm-scoped row only counts while the row\'s firm is still the '
        'caller\'s firm (`firm_id = current_firm_id()`). Removing an associate '
        'relinks `profiles.firm_id` to NULL, but the author clause checked '
        '`user_id = auth.uid()` before any firm helper, so a removed member '
        'could still merge a queued **update** to a firm record they happened '
        'to author. The narrowing is applied to the same three places that '
        'trusted authorship: ordinary rows, custom references, and a '
        'requester\'s own pending delete request. A `firm_id`-less personal row '
        'is unaffected, and `can_edit_firm` / `can_delete_firm` still cover '
        'teammates and reviewers.',
  ),
  LedgerSection(
    file: '20260930220000_rls_firm_membership.sql',
    version: '0.0.332',
    label:
        'Task 20 audit follow-up: the same membership rule, applied to RLS. '
        '`sync_can_write` closed the *app* path in 0.0.330, but the table '
        'policies still said `user_id = auth.uid()` on a firm-scoped row, so a '
        'removed associate could still write their authored firm rows through '
        'PostgREST directly — rewriting one, or detaching it from the firm by '
        'nulling `firm_id`. Every INSERT and UPDATE policy that trusts '
        'authorship now requires the row to be personal (`firm_id is null`) or '
        'still the caller\'s firm (`is not distinct from current_firm_id()`), '
        'across the ten tables that share one shape plus `conflict_log` and the '
        'requester\'s own pending `delete_requests` row. SELECT policies and '
        'table privileges are deliberately untouched.',
  ),
  LedgerSection(
    file: '20261001000000_payment_configuration.sql',
    version: '0.0.333',
    label:
        'Task 21 Phase 1\'s payments configuration: a read-only server '
        'table (`provider`, `receiving_number`, `is_active`, `updated_at`) that '
        'holds the MFS receiving numbers, authenticated SELECT only and no '
        'client write policy at all. It exists so a receiving number can rotate '
        'without a release (Rev 2.4 §5); it is not seeded, and the client falls '
        'back to validated build defaults until an admin inserts a row.',
  ),
  LedgerSection(
    file: '20261001010000_payment_plans_four.sql',
    version: '0.0.339',
    label:
        'Task 21 follow-up\'s four-plan approval: replaces `approve_payment` '
        'so the subscription knows `monthly`, `quarterly`, `half_yearly` and '
        '`annual`, validates ৳100/৳285/৳550/৳1,000 and extends by 1/3/6/12 '
        'months — the admin gate, lock, idempotency, firm mirror and audit '
        'event are unchanged.',
  ),
  LedgerSection(
    file: '20261001020000_seed_payment_configuration.sql',
    version: '0.0.339',
    label:
        'Task 21 follow-up\'s seeded receiving numbers: one idempotent row '
        'per provider (`bkash`, `nagad`, `rocket`) in `payment_configuration` '
        'with the firm\'s single MFS account in local 11-digit form, so the '
        'checkout shows a real number instead of falling back to build '
        'defaults.',
  ),
  LedgerSection(
    file: '20261001102042_payment_plans_four_recorded_duplicate.sql',
    version: '0.0.339',
    label:
        'Recorded duplicate — the four-plan approval re-applied under a '
        'connector-generated version (`20261001102042`). The SQL is the same '
        '`approve_payment` body `20261001010000` ships; keeping it as a file is '
        'what makes the project\'s recorded history match the migration set, so '
        'the applier no longer reports a version with no local file. Superseded '
        'by every later approval migration.',
  ),
  LedgerSection(
    file: '20261001102048_seed_payment_configuration_recorded_duplicate.sql',
    version: '0.0.339',
    label:
        'Recorded duplicate — the receiving-number seed re-applied under a '
        'connector-generated version (`20261001102048`). The SQL is the same '
        'idempotent upsert `20261001020000` ships; keeping it as a file makes '
        'the recorded history match the migration set.',
  ),
  LedgerSection(
    file: '20261002100000_payment_prices_discounted.sql',
    version: '0.0.349',
    label:
        'Discounted 6 Months and 1 Year plans: replaces `approve_payment` '
        'so it validates ৳100/৳285/৳540/৳960 — the two longer plans priced '
        'against the ৳100 monthly rate (10% and 20% off) instead of ৳550 and '
        '৳1,000. Only the four price constants move; the gate, lock, '
        'idempotency, intervals, firm mirror and audit event are unchanged.',
  ),
  LedgerSection(
    file: '20261002110000_admin_panel.sql',
    version: '0.0.354',
    label:
        'Task 23 Admin Panel: `app_admins` gains hand-filled `full_name` and '
        '`email`, `payment_submissions` gains `rejected_by`/`rejected_at`, and '
        'three admin-gated RPCs arrive — `is_app_admin()` (the only way a client '
        'learns its own status), `admin_list_payment_submissions()` (every '
        'submission joined to the payer profile) and `admin_reject_payment()`. '
        'Approval needs no new code; `profiles` stays self-or-firm.',
  ),
  LedgerSection(
    file: '20261005120000_payment_plan_name.sql',
    version: '0.0.385',
    label:
        'Readable plan names on both payment ledgers: `plan_type` stays the '
        'machine key and `payment_submissions` / `payment_approval_events` '
        'each gain a generated `plan_name` (`1 Month` / `3 Months` / '
        '`6 Months` / `1 Year`), so the raw tables read plainly without '
        'touching the approval path or either table\'s write privileges.',
  ),
  LedgerSection(
    file: '20261008100000_delete_my_account.sql',
    version: '0.0.411',
    label:
        'Task 12\'s Manage Account actions, built: delete_my_account(), the '
        'account holder'
        's own complete removal — every domain row, custom '
        'reference row, preference, payment submission and approval event, sync '
        'receipt, firm link and finally the Auth account — so no residue of it '
        'remains. Refuses, changing nothing, for a firm account and for an app '
        'administrator, and names the reason.',
  ),
  LedgerSection(
    file: '20261008110000_discard_unconfirmed_signup.sql',
    version: '0.0.413',
    label:
        'The Check Your Email screen, extended: discard_unconfirmed_signup(), '
        'the password-checked removal of a sign-up that never confirmed its '
        'address — the only way to correct a mistyped one, since an unconfirmed '
        'account cannot sign in and abandon_provisional_account() needs a '
        'session it can never have. Rate-limited per address in the new '
        'server-managed signup_discard_attempts ledger, and granted to anon '
        'because this caller has no session at all.',
  ),
  LedgerSection(
    file: '20261009120000_admin_unconfirmed_accounts.sql',
    version: '0.0.459',
    label:
        'The Admin Panel, extended: the Non-verified Accounts page\'s two '
        'admin-gated RPCs. admin_list_unconfirmed_accounts() lists every account '
        'that has never confirmed its address — invisible to clients, since '
        'email_confirmed_at lives in auth.users and profiles carries no '
        'confirmation flag — and admin_delete_unconfirmed_account() removes one. '
        'Both share is_provisional_account(), the same "has this account done '
        'anything?" guard discard_unconfirmed_signup() applies, so the list\'s '
        'can_delete flag and the delete can never disagree.',
  ),
  LedgerSection(
    file: '20261009130000_revoke_provisional_guard.sql',
    version: '0.0.459',
    label:
        'Closing a grant the default privileges opened: taking EXECUTE on '
        'is_provisional_account() back from `authenticated`. Revoking `public` '
        'and `anon` does not cover it, because Supabase grants a new function '
        'in `public` directly to `authenticated` as well — so the internal '
        'guard was callable by any signed-in account, one boolean at a time '
        'about an account it already knew the id of.',
  ),
  LedgerSection(
    file: '20261012100000_unconfirmed_accounts_72h_window.sql',
    version: '0.0.495',
    label:
        'The Non-verified Accounts page waits 72 hours before it calls a '
        'sign-up abandoned: admin_list_unconfirmed_accounts() returns only an '
        'account created over 72 hours ago, and '
        'admin_delete_unconfirmed_account(uuid) refuses a younger one as '
        'too_recent before its activity test, so the window is enforced and not '
        'merely hidden. is_provisional_account() is untouched — age and activity '
        'are different questions — and the grants stay as the previous '
        'migration left them.',
  ),
  LedgerSection(
    file: '20261012120000_admin_payment_alerts.sql',
    version: '0.0.498',
    label:
        'The server half of the admin push notification: device_tokens (one row '
        'per device, self-only under RLS, deleted by its own device on the way '
        'out of an account), the per-user payment_alerts_enabled toggle on '
        'user_preferences (default on), the two reads the sender runs — the '
        'pending-payment count and the fan-set — revoked from every client role, '
        'and pg_net plus two triggers on payment_submissions that post the change '
        'to the send-admin-payment-alerts Edge Function with the Vault-held '
        'shared secret.',
  ),
  LedgerSection(
    file: '20261013120000_payment_rate_limit_five.sql',
    version: '0.0.509',
    label:
        'The daily payment submission limit rises to five: replaces '
        'enforce_payment_rate_limit() with the same body and one changed '
        'constant (3 -> 5), so the server\'s BEFORE INSERT gate matches the '
        'client\'s best-effort warning. The trigger, the server-time stamp, the '
        'exception and its errcode are unchanged.',
  ),
  LedgerSection(
    file: '20261015100000_firm_mode_read_scope.sql',
    version: '0.0.520',
    label:
        'Firm mode: the read side is scoped. scope_owner_id lands on the '
        'eleven ledger tables and the SELECT policies are rewritten, so a '
        'removed member loses the chamber rows they authored — `user_id = '
        'auth.uid()` alone no longer grants them — while a dissolve keeps the '
        'ledger readable to its owner. conflict_log takes the membership '
        'condition only, and the column is server-only: the table-level write '
        'grants are dropped and every other column granted back.',
  ),
  LedgerSection(
    file: '20261015110000_firm_mode_creation_and_scope.sql',
    version: '0.0.522',
    label:
        'Firm mode: creation shares the owner\'s diary and the scope columns '
        'become the server\'s. ensure_firm stamps every firm-less ledger row '
        'its creator authored — all four case-data tables, the six reference '
        'tables\' custom rows and pending delete requests, tombstones included '
        '— with the new firm_id, a version bump and a refreshed updated_at, and '
        'push_changes derives an insert\'s firm_id from current_firm_id() '
        '(so a member\'s whole-row payload no longer lands a personal case '
        'inside a chamber), leaves an existing row\'s firm untouched, and never '
        'takes scope_owner_id from a payload.',
  ),
  LedgerSection(
    file: '20261015120000_firm_mode_join_gate.sql',
    version: '0.0.523',
    label:
        'Firm mode: a seat must be empty and the chamber must have one. '
        'join_firm refuses an account holding its own diary — counting the '
        'individual cases its answer quotes and restoring the row in the same '
        'transaction, so the count is atomic with the check (the restore is '
        'the \'has_own_diary\' bug fix: without it a refused join lost the '
        'caller\'s own row) — refuses past the tier\'s seat cap, and joins '
        'with §3.1\'s defaults (associate, can_add and can_edit in, '
        'can_delete out) and both freshness stamps while retiring an '
        'already-member\'s code as revoked rather than used. '
        'holds_own_diary and individual_diary_cases, the two helpers the gate '
        'and the screens share, are granted to authenticated alone so a '
        'signed-out caller cannot probe another account\'s diary count.',
  ),
  LedgerSection(
    file: '20261015160000_firm_removal_clears_device_tokens.sql',
    version: '0.0.524',
    label:
        'Firm mode: removing a member clears that member\'s push tokens. '
        'remove_firm_member deleted the membership but left the removed '
        'member\'s device_tokens rows in place, so the chamber\'s other '
        'members kept addressing notifications to a device that is no longer '
        'in the chamber — the removal was silent on the one channel it needed '
        'to be heard on, and the removed member kept the firm\'s topics. The '
        'tokens are deleted for the removed member alone, in the same '
        'transaction as the membership, so a device that is no longer a '
        'member cannot be sent the firm\'s notices, and the row the removed '
        'member authored keeps its author untouched.',
  ),
  LedgerSection(
    file: '20261016100000_firm_mode_permission_boundary.sql',
    version: '0.0.529',
    label:
        'Firm mode: a member\'s flags become a boundary on the server. '
        'can_add_firm joins its two siblings and enforce_member_permission() '
        'is attached BEFORE INSERT and BEFORE UPDATE to the ten gated tables '
        'in one loop, so can_add gates a create and can_edit every '
        'non-tombstone update — including the author\'s own chamber row, which '
        'is deliberately stricter than the shipped policy, because in a '
        'chamber most rows a member touches are ones they authored. The '
        'tombstone transition keeps can_delete\'s own gate rather than '
        'duplicating it. The function is SECURITY INVOKER on purpose: the '
        'permission rule is keyed on auth.uid() so both the direct-PostgREST '
        'and the push_changes door are bound while a migration, a fixture or a '
        'nightly job steps aside, and the scope rule is keyed on current_user '
        'so ensure_firm and the dissolve may still move a scope. §3.3\'s '
        'scope-column ruling lands here too: a client may not change a row\'s '
        'firm_id nor create a firm-less row while it holds a chamber — firm_id '
        'was still in the column grants after the scope_owner_id work, so a '
        'member could drop a chamber case into their own diary by direct '
        'update. sync_can_write is replaced with only its INSERT branch '
        'changed, in both the reference and the general branch, so the RPC '
        'refuses a create cleanly; its update branch, delete_requests and '
        'every RLS policy are untouched.',
  ),
  LedgerSection(
    file: '20261016110000_firm_mode_reference_in_use_guard.sql',
    version: '0.0.530',
    label:
        'Firm mode: the in-use guard for reference rows. '
        'enforce_reference_not_in_use() is attached BEFORE UPDATE to the four '
        'tables the nine foreign keys point at — court_categories, '
        'case_categories, courts and on_behalfs — and refuses the tombstone '
        'transition while a **live** dependent still names the row, raising '
        'reference_in_use as 23503 so push_changes rejects that one mutation '
        'instead of aborting the batch. steps and case_types deliberately take '
        'no trigger: cases.case_type and cases.last_step are free text, so '
        'nothing references either and no server guard can protect them. '
        'purge_tombstones() is rewritten to delete one candidate at a time and '
        'skip a row a dependent still names — one blocked tombstone used to '
        'abort the whole nightly purge — with the retention argument, the '
        'children-first order and the returned count unchanged.',
  ),
  LedgerSection(
    file: '20261016120000_firm_mode_stored_tier.sql',
    version: '0.0.531',
    label:
        'Firm mode: the stored subscription tier and the ten-plan ladder. '
        'profiles and firms each gain tier, tier_pending and tier_pending_from, '
        'so which tier applies to an account or a chamber is a stored fact '
        'rather than something each screen infers from a payment row. '
        'effective_tier() answers which tier is in force — a pending change '
        'takes hold on its own date and not before, so an approval still being '
        'settled does not open a gate early and a mid-term downgrade is '
        'honoured when it is due — and tier_rank() gives the ladder one order '
        '(free 0, pro 1, firm 2, firm_plus 3) for every comparison to share. '
        'The plan approval is rebuilt around the ten flat prices, so the '
        'withdrawn discount model no longer decides what a plan costs, and the '
        'plan-name columns are rebuilt for the ten keys. profiles and firms each '
        'carried a table-level insert grant for authenticated and anon, which '
        'reaches a column added later, so both are narrowed to the columns that '
        'were writable before; the tier is not client-writable at insert either.',
  ),
  LedgerSection(
    file: '20261016130000_firm_mode_seat_cap_and_creation_gate.sql',
    version: '0.0.532',
    label:
        'Firm mode: the seat cap reads the stored tier, and a chamber needs '
        'Firm. firm_seat_cap() previously asked is_premium(owner) and answered '
        '5 for anyone premium, so a Firm Plus chamber was capped at the Firm '
        'number and a Pro owner had a chamber nobody could join; it now reads '
        'the tier in force — Firm 5, Firm Plus 20, Pro 0 — through '
        'effective_tier, so the cap a mid-downgrade chamber enforces is the one '
        'it has paid for. ensure_firm()\'s creation gate moves from '
        'is_premium() to Firm or above, because Pro\'s cap of 0 means a chamber '
        'on Pro could never take a member; the refusal keeps the status shape '
        'the client already handles but names the reason firm_tier_required, '
        'so a paying Pro user is not told they are not premium. A newly '
        'created chamber starts on its owner\'s tier, because the cap reads that '
        'row and a chamber left at the column default would answer null — no cap '
        'enforced — for every join. A seat cap binds new joins only: neither '
        'function removes a member, and no membership row is touched.',
  ),
  LedgerSection(
    file: '20261017100000_firm_mode_member_no_plan.sql',
    version: '0.0.534',
    label:
        'Firm mode: a member has no plan of their own. '
        'has_sync_entitlement() counted the caller\'s own expiry OR the '
        'chamber\'s, so a member who had bought a plan before joining kept '
        'pushing through the chamber\'s lapse; it now counts the chamber\'s '
        'mirrored expiry alone once profiles.firm_id is set, and the caller\'s '
        'own only while it is null. payment_submissions_insert_own becomes a '
        'member\'s refusal — user_id = auth.uid() plus no firm, or a firm the '
        'caller owns — so an associate or viewer cannot buy a personal plan. '
        'The owner is deliberately exempt: the owner\'s purchase is the '
        'chamber\'s renewal, and the two entries this phase removes from a '
        'member are the owner\'s only routes to it.',
  ),
  LedgerSection(
    file: '20261017110000_firm_mode_dissolution.sql',
    version: '0.0.536',
    label:
        'Firm mode: dissolution. dissolve_firm() refuses while the roster '
        'holds anyone but the owner and carries the count in the refusal, '
        'decided before the first write so a refusal retires no invite and '
        'moves no row. Once the roster is empty it retires the open invites, '
        'then unscopes the eleven ledger tables — firm_id out, the owner in as '
        'scope_owner_id, tombstones included — so he keeps a complete ordinary '
        'diary while attribution, contents and the sync columns stay exactly as '
        'they were. conflict_log is the one exception: its firm_id is cleared, '
        'because the foreign key has no cascade and the firms delete would be '
        'refused otherwise, and no scope owner is written, so a colleague\'s '
        'merge diagnostics stay with their author. The firms row goes with its '
        'memberships and invites, the owner\'s profile returns to individual '
        'mode (which unblocks delete_my_account), and his plan is untouched.',
  ),
  LedgerSection(
    file: '20261017120000_firm_mode_retention_window.sql',
    version: '0.0.537',
    label:
        'Firm mode: the retention and recovery window. purge_tombstones() '
        'keeps a tombstone 365 days instead of 180, so the device-side '
        'extended-offline rule can be 335 days with the same 30-day buffer '
        'between them: a device that comes back inside its window still finds '
        'every deletion it missed, and one away longer is rebuilt rather than '
        'trusted. Only the default and the comments change — the scheduled job '
        'calls the function with no argument, and the body (cutoff, children-'
        'first order, one-row-at-a-time delete, blocked-tombstone skip) is the '
        'shipped one verbatim. mutation_receipts\' documented retention is '
        'corrected to at least 400 days in the same pass, because the old '
        '210-day invariant was written for a 150-day window.',
  ),
  LedgerSection(
    file: '20261018100000_subscription_cancellation.sql',
    version: '0.0.543',
    label:
        'Subscription History — cancelling a live plan, reconstructed. The '
        'install that shipped cancellation on 2026-10-18 recorded its version '
        'without statements and committed no file, so the app called an RPC the '
        'repository could not define and the applier reported it as drift. This '
        'section is the table, its own-row SELECT policy, its narrowed grants '
        'and cancel_subscription() copied from the applied project\'s catalogs, '
        'kept idempotent so the live project skips it and a fresh project can '
        'apply it.',
  ),
  LedgerSection(
    file: '20261019100000_subscription_ladder_six_tiers.sql',
    version: '0.0.546',
    label:
        'Task 22 — The six-tier subscription ladder. The stored tier vocabulary '
        'gains starter and enterprise, and the old ladder\'s pro rung is renamed '
        'starter without moving any expiry. tier_rank, the case ceilings and the '
        'lapse allowances are restated for the six rungs; adding a case is '
        'checked against the diary\'s tier ceiling, not only the free wall; '
        'approve_payment accepts the seventeen sellable keys plus the four '
        'legacy ones at their own prices and durations, queues any different '
        'tier bought while a plan is running, renews a same-tier purchase and '
        'pushes a waiting change back by the term bought, and refuses a third '
        'plan behind a queued one; the seat caps become Firm 5, Firm Plus 12 '
        'and Enterprise unlimited, so chamber creation needs the Firm rung; and '
        'the generated plan names cover every key, old and new.',
  ),
  LedgerSection(
    file: '20261020100000_payment_ladder_v2_prices.sql',
    version: '0.0.552',
    label:
        'Task 22 — The 2026-10-20 price ladder. Seven ladder prices move and a '
        'Firm one-month plan joins the eighteen sellable keys, so a chamber can '
        'try firm mode without buying a quarter. Only the ladder inside '
        'approve_payment changes — its price constants, key allow-list, amount, '
        'duration and tier CASEs — and the two generated plan names gain the '
        'Firm month; the gate, the row lock, the queue and the audit insert are '
        'unchanged.',
  ),
  LedgerSection(
    file: '20261020110000_enterprise_limits_and_firm_plus_seats.sql',
    version: '0.0.553',
    label:
        'Task 22 — Enterprise limits, and Firm Plus down to ten seats. Two '
        'functions, no prices: tier_case_ceiling answers 20,000 for enterprise '
        'instead of null, so the Add Case trigger, which returned early on a '
        'null ceiling, now counts a real number on every sold tier; and '
        'firm_seat_cap answers Firm Plus 10 (was 12) and Enterprise 20 (was '
        'null, which every join gate read as uncapped), leaving Firm 5, Starter '
        'and Pro 0 untouched. A cap binds new joins only, so a chamber already '
        'holding eleven or twelve members keeps them.',
  ),
  LedgerSection(
    file: '20261022100000_device_limit_registry.sql',
    version: '0.0.565',
    label:
        'Task 22 — The device limit\'s registry. Every paid card promises a '
        'number of devices signed in at once and nothing enforced it. '
        'tier_device_cap states the number per rung (Pro 2, every other rung '
        '1) and device_cap answers the caller\'s own allowance, holding a '
        'chamber member — the owner included — to one whatever the chamber '
        'buys; user_devices keeps one row per sign-in, keyed by the session_id '
        'claim in the access token that a client cannot forge, with the '
        'install\'s device_key beside it so a re-login reuses its own slot; '
        'register_device is the decision table — re-registering is idempotent, '
        'a free slot is taken, at the cap the least recently seen spare is '
        'evicted only when it has been idle seven days or more and the plan is '
        'live, and a registration past the cap is admitted and flagged '
        'grandfathered until the 2026-11-21 roll-out end; device_state is the '
        'launch check, revoke_device frees a slot the lawyer picks and refuses '
        'a device revoking itself, ack_device_wipe records that a revoked '
        'device flushed its work and erased, device_trim_surplus revokes the '
        'surplus after a ceiling falls and revokes nothing without a live '
        'plan, and device_tokens gains the device_key a revocation deletes by.',
  ),
  LedgerSection(
    file: '20261022110000_device_limit_enforcement.sql',
    version: '0.0.565',
    label:
        'Task 22 — Enforcing the device limit. A limit a client can ignore by '
        'never registering is not a limit, so three gates: device_may_push '
        'admits an active device, a revoked device inside its 14-day flush '
        'window — the window is what lets unsent work reach the account before '
        'the device erases — and a caller carrying no session at all (psql, the '
        'service role); device_may_read admits only an active device, plus an '
        'unregistered session until the same roll-out end so an install that '
        'has not updated yet keeps working; and push_changes keeps its body — '
        'renamed push_changes_core with its grants, never re-typed — behind a '
        'wrapper that refuses a revoked session past its window with '
        'device_revoked. The eleven ledger tables and conflict_log gain '
        'device_may_read() in their SELECT policies, which is the same '
        'condition a Realtime subscription reads. profiles, the billing tables '
        'and the firm roster stay readable on purpose: a revoked device needs '
        'its own profile to explain itself, and it erases at its next contact '
        'anyway.',
  ),
  LedgerSection(
    file: '20261022120000_device_trim_counts_the_caller.sql',
    version: '0.0.566',
    label:
        'Task 22 — Device trim counts the caller only when it holds a slot. '
        'The proof caught the first run of the limit admitting a third '
        'sign-in on a two-device plan and revoking one of the two devices '
        'already there as lapse: device_trim_surplus kept cap-minus-one '
        'devices other than the caller, which is right only while the caller '
        'already occupies a slot, and register_device trims before it knows. '
        'It now asks user_devices whether the caller holds an active row and '
        'subtracts one only then; a new device leaves the whole cap to the '
        'devices present, so a full plan answers device_limit_reached, and an '
        'account already above its cap is still trimmed back to it.',
  ),
  LedgerSection(
    file: '20261022130000_device_push_rollout_window.sql',
    version: '0.0.567',
    label:
        'Task 22 — Writes get the roll-out window reads already had. The '
        'enforcement migration admitted an unregistered session to READ until '
        'the 2026-11-21 roll-out end and gave it no such allowance to WRITE, so '
        'an install that had not updated could pull the diary down and could '
        'not hand one edit back up: its first push was refused as '
        'device_revoked, and because a refusal is not retryable the client '
        'blocked every queued change. device_may_push now admits a session '
        'with no user_devices row at all until the same date; a revoked device '
        'is unaffected because revocation stamps revoked_at on a row rather '
        'than deleting it, so the branch is reachable only by a session that '
        'never registered, and both gates close on one date.',
  ),
  LedgerSection(
    file: '20261022140000_payment_party_identity.sql',
    version: '0.0.590',
    label:
        'Payment support — both payment ledgers carry the payer. '
        'payment_submissions and payment_approval_events gain full_name and '
        'email snapshots, filled from profiles by a BEFORE INSERT trigger that '
        'overrides any client text; existing rows are backfilled from the '
        'profile they already point at, so troubleshooting no longer needs a '
        'join to identify who paid.',
  ),
  LedgerSection(
    file: '20261022150000_device_no_grace.sql',
    version: '0.0.592',
    label:
        'Device limit — the grace period is closed. The roll-out row is '
        'removed: a third device at the cap is refused unless an idle spare '
        'may be evicted, an unregistered session reads and pushes nothing, and '
        'a revoked device loses the 14-day flush. register_device now returns '
        'the active-device list, and two RPCs are added: sign_out_device for '
        'the third-device window (reason signed_out) and touch_device for the '
        'real-use heartbeat. One-time cleanup revokes any row above its cap and '
        'clears the obsolete grandfathered flag.',
  ),
  LedgerSection(
    file: '20261022160000_device_install_secret.sql',
    version: '0.0.595',
    label:
        'Device limit — a session belongs to its install. Every install mints '
        'a 32-byte secret kept in this-device-only secure storage and sends it '
        'as x-install-secret (and p_install_secret); user_devices stores only '
        'its sha256. A known session presented with a different secret answers '
        'session_in_use, no secret at all answers invalid_install_secret, and '
        'replaced now needs the same device key and the same secret, so a '
        'restored backup is a new device. Push and heartbeat fail closed on a '
        'mismatch; reads keep a permissive fallback when no secret is present '
        'because Realtime does not reliably forward custom headers.',
  ),
  LedgerSection(
    file: '20261023100000_device_identity_and_collision_guard.sql',
    version: '0.0.600',
    label:
        'Device registry — unique install keys and support identity. '
        'user_devices gains full_name and email, filled from profiles by a '
        'BEFORE INSERT trigger and backfilled for existing rows. The client '
        'now keys Android installs by a persisted UUID because '
        'device_info_plus\'s Android id is the build ID, which two identical '
        'phones share; register_device answers a key already held by another '
        'active device with device_limit_reached instead of raising 23505 on '
        'user_devices_active_device_idx, and a known session never rewrites '
        'its device_key to a key another active row holds.',
  ),
  LedgerSection(
    file: '20261023110000_device_revocation_broadcast.sql',
    version: '0.0.602',
    label:
        'Device revocation — the server tells the device over the channel it '
        'already holds. A guarded AFTER UPDATE trigger on user_devices, only on '
        'the null-to-non-null revoked_at transition, sends the existing '
        'row_change {table,id} ping to firm:<firm_id> for a chamber member or '
        'user:<user_id> for an individual, so a signed-out phone discards '
        'immediately without polling; a Realtime failure is swallowed and the '
        'revocation still commits.',
  ),
  LedgerSection(
    file: '20261023120000_user_devices_retention.sql',
    version: '0.0.604',
    label:
        'Device registry retention — six months of revoked rows, plus the '
        'newest revoked row per (user_id, device_key) forever. A partial '
        '(user_id, device_key, revoked_at desc) index supports the lookup; '
        'public.prune_user_devices(interval default 6 months) deletes only old '
        'rows with a strictly newer revoked row for the same key, never active '
        'rows, and is internal-only (revoked from public, anon, authenticated). '
        'A guarded pg_cron job, prune-user-devices, runs daily at 03:45 after '
        'purge-tombstones.',
  ),
  LedgerSection(
    file: '20261025120000_firm_logo_storage.sql',
    version: '0.0.629',
    label:
        'Chamber logo storage — a private, 50 KB, JPEG-only `firm-avatars` '
        'bucket holding one flat `{firm_id}.jpg` per chamber. Any member of a '
        'chamber may read its logo; only its owner, and only while the '
        'chamber plan is live, may write it; the owner may always delete it. '
        'public.can_write_firm_logo() carries both halves of the write rule '
        'because has_sync_entitlement is revoked from clients. `firms` gains '
        'the server-managed logo_path and logo_version, and a trigger on '
        'storage.objects bumps them on every write or delete.',
  ),
  LedgerSection(
    file: '20261025180000_profile_avatar_storage.sql',
    version: '0.0.630',
    label:
        'Profile-picture storage — a private, 50 KB, JPEG-only '
        '`individual-avatars` '
        'bucket holding one flat `{user_id}.jpg` per account. The holder reads '
        'and deletes their own file; only a premium individual or a premium '
        'chamber owner may insert or replace it, through '
        'public.can_write_profile_avatar() because has_sync_entitlement is '
        'revoked from clients. `profiles` gains the server-managed avatar_path '
        'and avatar_version, and a trigger on storage.objects keeps them in '
        'step. Account deletion removes the object through the delete-account '
        'Edge Function, because Storage deletes must use the Storage API.',
  ),
  LedgerSection(
    file: '20261026100000_payment_downgrade_after_grace.sql',
    version: '0.0.635',
    label:
        'A queued downgrade now starts 48 hours after the paid period it '
        'replaces ends, so the old plan\'s capacity covers the whole grace. '
        'approve_payment gains the grace-aware start, applies a lower tier '
        'bought inside the grace as a pending pair, applies a higher tier after '
        'a started pending immediately, and refuses Starter/Pro for a chamber '
        'owner (tier_seat_cap is defined here and reused by the capacity '
        'migration). Existing queued downgrades are backfilled by 48h through '
        'profiles only, because the mirror trigger copies the value to firms.',
  ),
  LedgerSection(
    file: '20261026110000_firm_shared_capacity.sql',
    version: '0.0.635',
    label:
        'Chamber capacity is shared: associates plus the owner\'s own devices '
        'must fit the tier\'s slots (Firm 5, Firm Plus 10, Enterprise 20, owner '
        'included). Adds joined_at and capacity_signed_out_at to firm_members, '
        'closes its direct INSERT/UPDATE/DELETE bypass, adds the capacity '
        'helpers, makes device_cap dynamic for an owner and 0 for a signed-out '
        'associate, rebuilds join_firm/register_device/remove_firm_member under '
        'one firm lock order, adds owner sign-out/admit RPCs, and rebalances a '
        'chamber only after a started lower-tier shrink (owner devices first, '
        'then the newest associates), every 15 minutes by pg_cron.',
  ),
  LedgerSection(
    file: '20261026130000_owner_designate_device_slots.sql',
    version: '0.0.645',
    label:
        'A chamber-tier account with no chamber — a Firm, Firm Plus or '
        'Enterprise owner-designate — now keeps the tier\'s full seat cap for '
        'its own devices (5 / 10 / 20) instead of falling to the one-per-member '
        'cap. A chamber owner still reads the slots left after associates; a '
        'seated associate 1; a capacity-signed-out associate 0; a non-chamber '
        'tier its own cap.',
  ),
  LedgerSection(
    file: '20261026140000_delete_requests_requester_name.sql',
    version: '0.0.675',
    label:
        'A delete request now carries the requester\'s name inside the row, so '
        'a reviewer reads who asked offline and from the first review instead '
        'of falling back to a neutral label when that colleague\'s profile is '
        'not in the reviewer\'s pull-only cache. The value is server-derived: a '
        'trigger fills requester_name from the profile of the row\'s own '
        'requested_by on both write paths, keeps the client\'s value only while '
        'that profile still holds no name, and the column is granted exactly '
        'like the rest of the row.',
  ),
  LedgerSection(
    file: '20261027100000_delete_request_review_firm_scope.sql',
    version: '0.0.684',
    label:
        'The delete-request rule reads the firm the row actually has. '
        '`push_changes` subtracts the scope columns from the row it hands '
        '`sync_can_write`, which is harmless for every other table (a trigger '
        'gates can_edit on the ten gated tables, and '
        '`enforce_delete_transition()` reads `old.firm_id`), but '
        '`delete_requests` has no permission trigger, so a reviewer\'s '
        'rejection, a requester\'s snapshot refresh and a withdrawal were all '
        'judged against a null firm and refused with `permission_denied` — the '
        'client rolled each one back and claimed the user\'s permissions had '
        'changed. The rule now reads the stored request\'s own firm_id when the '
        'row names none; nothing else in the function changes.',
  ),
  LedgerSection(
    file: '20261027110000_delete_request_withdrawal_exit.sql',
    version: '0.0.684',
    label:
        'A requester may withdraw their own pending delete request. The '
        'ordinary tombstone gate demands can_delete in the row\'s firm, and the '
        'member who raises a delete request is exactly the member without it, '
        'so the app\'s **Withdraw** action could never be applied once the '
        'request had reached the server. `enforce_delete_transition()` now '
        'excepts one carrying row — a delete request whose status is still '
        'pending and whose requested_by is the caller — which is the rule '
        '`delete_requests_update_scoped` already states; a decided request '
        'still cannot be withdrawn.',
  ),
  LedgerSection(
    file: '20261027120000_delete_request_withdrawal_field_guard.sql',
    version: '0.0.684',
    label:
        'The withdrawal exit reads its two fields only on the table that has '
        'them. `20261027110000` wrote the exception as one condition, and '
        '`old.status` is resolved at run time on a generic record — so the '
        'other eleven tables the trigger guards, which have no `status` '
        'column, raised on every tombstone and could not delete at all. The '
        'rule is unchanged; the two `delete_requests` fields are read inside '
        'the table test, where nothing else can reach them. Caught by the two '
        'proofs that tombstone a case and a reference row.',
  ),
  LedgerSection(
    file: '20261027130000_push_changes_check_row_firm.sql',
    version: '0.0.684',
    label:
        'The permission verdict is weighed on the row as it exists. '
        '`push_changes_core` subtracts the scope columns before the write, and '
        'handed that same stripped row to `sync_can_write`, so every rule that '
        'needs the firm was weighed against a row with no firm: '
        '`can_edit_firm(null)` is false and the authorship clause decided '
        'alone — a chamber member could not edit a case, note or reference a '
        'colleague had authored, including the firm\'s owner, while '
        '`enforce_member_permission()` allows it because it reads '
        '`new.firm_id`. The check now receives `v_final` with the stored firm '
        'restored; the write still omits `firm_id`, so no payload can move a '
        'row between scopes. The body is the newest shipped one with that one '
        'statement changed.',
  ),
  LedgerSection(
    file: '20261028100000_delete_request_target_closure.sql',
    version: '0.0.685',
    label:
        'A delete request whose record someone else deleted closes itself. '
        'Nothing watched the record: a member with `can_delete` could delete '
        'the case a colleague had already asked about, and the request stayed '
        'pending for ever — in every reviewer\'s queue as work that could never '
        'succeed, in the requester\'s list as "waiting", clearable only by '
        'rejecting it, which records a decision that never happened. A trigger '
        'function on the four tables a request may name (`cases`, '
        '`case_history`, `notes`, `case_references`) now closes every still-open '
        'request for a tombstoned row as `already_deleted`, in the same '
        'transaction as the deletion, stamped by the deleter; an approval still '
        'ends approved because it writes after the tombstone it causes. The same '
        'migration backfills requests already left hanging and adds a partial '
        'unique index for at most one open request per record, so two '
        'colleagues can no longer queue two rows that end in one deletion and '
        'one pointless approval.',
  ),
  LedgerSection(
    file: '20261029100000_firm_device_list.sql',
    version: '0.0.713',
    label:
        'The chamber owner can see every device sharing the firm\'s slots. '
        '`device_state()` answers for the caller\'s own session, so the owner\'s '
        'Devices screen could only list the owner\'s phones while the other '
        'holders of the shared slots stayed invisible to the one person who '
        'manages them — and `user_devices` grants no read to any client role. '
        '`firm_device_list()` returns the chamber\'s slots, its associate count '
        'and every active device whose profile still points at that chamber, '
        'each with the member\'s current profile name, the registration '
        'snapshot as the fallback, `is_owner` and `is_current`. Owner-only: an '
        'associate or an individual reads `not_owner`, and nothing here writes.',
  ),
  LedgerSection(
    file: '20261030100000_default_table_privileges.sql',
    version: '0.0.714',
    label:
        'Future public tables keep the Data API access the app relies on. '
        'Supabase stops granting new tables in `public` to the API roles on '
        '2026-10-30, so a table a later migration creates would be unreachable '
        'to `authenticated` until something granted it \u2014 as would a preview '
        'branch or a replayed schema. The statements set the default privileges '
        'for tables created by the migration role from now on: the four DML '
        'verbs to `authenticated` (every screen is behind sign-in, and RLS still '
        'scopes the rows) and to `service_role`; `anon` is deliberately left out '
        'because this app has no unauthenticated table access. No existing '
        'table\'s privileges change, and a new table that needs narrower rights '
        'still states them in its own migration.',
  ),
  LedgerSection(
    file: '20261030110000_default_table_privileges_no_anon.sql',
    version: '0.0.715',
    label:
        'Future public tables are closed to unauthenticated callers. Supabase\'s '
        'own default still grants `anon` every table privilege (`arwdDxtm`) on a '
        'new table in `public`; the app never calls the Data API without a '
        'session, so that grant is a leftover. The statement revokes the whole '
        'set from `anon` for tables created by the migration role from now on \u2014 '
        'the four DML verbs are not enough, because truncate, references, '
        'trigger and maintain are part of the same legacy grant. Existing tables '
        'keep their grants (a default privilege cannot touch an existing '
        'object), and `authenticated` and `service_role` keep the four DML verbs '
        'from the previous migration.',
  ),
  LedgerSection(
    file: '20261030120000_laws_table.sql',
    version: '0.0.745',
    label:
        'The statute list becomes a shared row set. `public.laws` is the seventh '
        'push/pull domain reference table: the phone\'s law names, their seven '
        'categories and their order, plus the two server-owned columns every '
        'domain table carries (`server_updated_at` and the firm-mode '
        '`scope_owner_id`). It takes the reference-table RLS matrix \u2014 built-in '
        'rows readable by every install, a custom row only by its own firm-less '
        'diary, its chamber or its dissolve scope owner \u2014 the table-level '
        'revoke plus column grant that keeps `scope_owner_id` server-only, the '
        'sync, delete, resurrection, permission and broadcast triggers, and the '
        'three delta indexes. Eight functions are re-created with `laws` in the '
        'list each one holds: `sync_entity_table` and `sync_dependency_rank` for '
        'the push path, `sync_can_write` for the verdict on a law write, '
        '`ensure_firm` so a chamber takes the owner\'s custom names at creation, '
        '`holds_own_diary` so a custom law counts as the author\'s own diary, '
        '`dissolve_firm` so they pass back to the owner, `purge_tombstones` so a '
        'law tombstone finally ages out, and `delete_my_account` so an account\'s '
        'custom names go with its other rows.',
  ),
  LedgerSection(
    file: '20261030121000_laws_reference_data.sql',
    version: '0.0.745',
    label:
        'The 57 built-in law names, generated from '
        '`lib/core/constants/pre_seeded_data.dart` by '
        '`tool/generate_supabase_seed.dart`: the list and order of '
        '`docs/seed_data_test/LawsOfBangladesh.md`, under its seven category IDs, '
        'with the same stable IDs the phone\'s `seed_v3` migration writes. The '
        'upsert refreshes a built-in name and leaves a row the user or their '
        'chamber renamed untouched, exactly as the six reference tables\' seed '
        'does.',
  ),
];

/// One SQL file that the migration role cannot run, applied through the
/// Supabase dashboard and recorded in the ledger's manual section.
class ManualSection {
  const ManualSection({
    required this.file,
    required this.created,
    required this.label,
  });

  /// File name inside [manualDir].
  final String file;

  /// The date it was written and applied.
  final String created;

  /// What it does and why it is manual.
  final String label;
}

/// Manual SQL, in creation order. Every file here must exist in [manualDir].
const List<ManualSection> _manualSections = <ManualSection>[
  ManualSection(
    file: 'storage_policies.sql',
    created: '2026-10-25',
    label:
        'The eight storage policies for the profile-picture and chamber-logo '
        'buckets. `storage.objects` is owned by `supabase_storage_admin`, which '
        'the migration role is not a member of, so these are created once in '
        'the Supabase Storage policy editor instead.',
  ),
];

/// Heading text per version group, so the groups read as phases rather than as
/// bare version numbers.
const Map<String, String> _groupTitles = <String, String>{
  '0.0.745': 'Law List — The Statute List On The Server',
  '0.0.715': 'Data API — New Tables Closed To Anonymous Callers',
  '0.0.714': 'Data API — New Tables Keep Their Access',
  '0.0.713': 'Firm Devices — The Owner Sees Every Slot In Use',
  '0.0.685': 'Delete Requests — A Request No Longer Outlives Its Record',
  '0.0.684':
      'Delete Requests — A Rejection, A Refresh And A Withdrawal That Land',
  '0.0.604': 'Device Retention — Six Months Of Revoked Rows',
  '0.0.602': 'Device Revocation — A Realtime Push Instead Of Polling',
  '0.0.600': 'Device Registry — Unique Install Keys And Support Identity',
  '0.0.595': 'Device Limit — A Session Belongs To Its Install',
  '0.0.592': 'Device Limit — The Grace Period Is Closed',
  '0.0.590': 'Payment Support — The Payer\'s Name And E-mail On Both Ledgers',
  '0.0.567': 'Task 22 — The Device Limit, Rolled Out On Both Sides',
  '0.0.566': 'Task 22 — The Device Limit, Made Correct',
  '0.0.565': 'Task 22 — The Device Limit',
  '0.0.289':
      'Task 16 Phase 1 — Core Schema, Sign-Up Trigger And Reference Seed',
  '0.0.290': 'Task 16 Phase 2 — Server-Internal Ledgers',
  '0.0.291':
      'Task 16 Phase 3 — Helpers, Guards, RPCs, Realtime And Column '
      'Privileges',
  '0.0.292': 'Task 16 Phase 4 — Row Level Security',
  '0.0.293': 'Task 16 Phase 5 — Indexes And The Tombstone Purge',
  '0.0.300': 'Task 16 Audit Closure — The Analytics Column',
  '0.0.305': 'Task 17 Phase 5 — Owner Firm Establishment',
  '0.0.307': 'Task 17 Audit Follow-Up — Abandoned Onboarding Cleanup',
  '0.0.310': 'Task 17 Follow-Up — The Account Holder\'s Own Details',
  '0.0.311': 'Task 18 Phase 1 — The Atomic Push Pipeline',
  '0.0.313': 'Task 18 Phase 3 — Server Clock For Skew Detection',
  '0.0.318': 'Task 19 Phase 3 — The Conflict Verdict On The Mirrored Row',
  '0.0.324': 'Task 20 Phase 1 — The Premium Gate On Firm Establishment',
  '0.0.325': 'Task 20 Phase 2 — Removing An Associate',
  '0.0.327': 'Task 20 Phase 4 — Delete Requests: Review',
  '0.0.330': 'Task 20 Audit Closure — A Removed Member Cannot Merge A Write',
  '0.0.332':
      'Task 20 Audit Follow-Up — The Policies Refuse The Same Write As The RPC',
  '0.0.333': 'Task 21 Phase 1 — The MFS Configuration Table',
  '0.0.339': 'Task 21 Follow-Up — Four Plans And The Receiving Number',
  '0.0.349': 'Task 21 Follow-Up — Discounted Six-Month And Annual Plans',
  '0.0.354': 'Task 23 Phase 1 — The Admin Panel On The Server',
  '0.0.385': 'Task 21 Follow-Up — Readable Plan Names On The Payment Ledgers',
  '0.0.411': 'Task 12 — Deleting The Account Itself',
  '0.0.413': 'Task 17 — Correcting A Mistyped Sign-Up Address',
  '0.0.459': 'Task 23 Follow-Up — The Admin Panel\'s Non-Verified Accounts',
  '0.0.495': 'Task 23 Follow-Up — Non-Verified Accounts Waits 72 Hours',
  '0.0.498': 'Admin Payment Alerts Phase 2 — The Push Server Half',
  '0.0.509': 'Task 21 Follow-Up — Five Payment Submissions A Day',
  '0.0.520': 'Firm Mode Phase 1 — The Read Side Is Scoped',
  '0.0.522':
      'Firm Mode Phase 2 — Creation Shares The Diary, And The Scope Columns '
      'Belong To The Server',
  '0.0.630': 'Profile Pictures — A 50 KB Cap And A Premium Cloud Copy',
  '0.0.635':
      'Shared Chamber Capacity — Slots Cover Associates And The Owner\'s '
      'Devices, And A Shrink Waits For The Grace',
  '0.0.645':
      'Owner-Designate Seats — A Chamber-Tier Buyer Keeps The Slots Before The '
      'Firm Exists',
  '0.0.629': 'Firm Identity — The Chamber Logo And The Side Menu',
  '0.0.524': 'Firm Mode Phase 4 — Removing A Member Clears Their Push Tokens',
  '0.0.523':
      'Firm Mode Phase 3 — A Seat Must Be Empty, And The Chamber Must '
      'Have One',
  '0.0.529': 'Firm Mode Phase 5 — The Permission Boundary',
  '0.0.530': 'Firm Mode Phase 6 — The In-Use Guard For Reference Rows',
  '0.0.531': 'Firm Mode Phase 7 — The Stored Tier And The Ten-Plan Ladder',
  '0.0.532':
      'Firm Mode Phase 8 — The Seat Cap Reads The Tier, And A Chamber Needs Firm',
  '0.0.534': 'Firm Mode Phase 9 — A Member Has No Plan Of Their Own',
  '0.0.536': 'Firm Mode Phase 11 — Dissolution Keeps The Ledger',
  '0.0.537': 'Firm Mode Phase 12 — Retention And The Recovery Window',
  '0.0.543': 'Subscription History — Cancelling A Live Plan',
  '0.0.546': 'Task 22 — The Six-Tier Subscription Ladder',
  '0.0.552': 'Task 22 — The 2026-10-20 Price Ladder',
  '0.0.553': 'Task 22 — Enterprise Limits And Ten Firm Plus Seats',
  '0.0.675': 'Delete Requests — The Requester\'s Name Travels With The Request',
};

const String _header = '''<!--
Generated by tool/generate_all_supabase_sql.dart — do not edit by hand.
Rebuild:  dart run tool/generate_all_supabase_sql.dart
Guard:    dart run tool/generate_all_supabase_sql.dart --check
          (also enforced by test/supabase/all_supabase_sql_test.dart)
-->

# All Supabase SQL

Every SQL statement this project **ships** to Supabase, in the order it was
created: the versioned migration set, the applier's own bootstrap, and one
labelled manual section for the SQL the migration role cannot run (the storage
policies). One section per file in `supabase/migrations/`, grouped by the app
version that was current when the phase landed; the text under each label is
that migration file **verbatim**. Two things are deliberately not here, and
neither changes the server: the assertions in `supabase/tests/*.sql` (runnable
checks that roll back) and the read-only counts
`tool/check_supabase_seed.dart` and `tool/apply_supabase_migrations.dart` issue.

- Only one project is ever in scope: `lsthasywrdrhuuxnykau` ("Legal Case Diary").
  AGENTS.md rule 12 names the live project that must never be touched.
- Server SQL is written as a migration file, then this ledger is rebuilt.
  The one exception is storage policy SQL, which the migration role cannot
  create; it lives in `supabase/manual/` and is recorded in the manual section,
  still generated rather than typed here.
- The manual section is **not applied** by `tool/apply_supabase_migrations.dart`.
  Its policies are created once in Supabase's Storage policy editor.
- Re-running the whole set is safe: creates are `if not exists`, functions are
  `create or replace`, every policy and trigger is preceded by a `drop ... if
  exists`, and all six seed inserts upsert `where <table>.is_user_modified = false`.
- One setting is dashboard-only and is not SQL: Realtime Authorization
  (`supabase/README.md`). pg_cron is installed and the tombstone purge
  scheduled by the last migration — verified on the project.
- Every **migration** version here is recorded in
  `supabase_migrations.schema_migrations` on `lsthasywrdrhuuxnykau`, so
  `supabase db push` sees the set as applied. The manual section has no
  migration row: it is applied through the dashboard.

## Index

| App Version | Created | Migration | What It Does |
|---|---|---|---|
''';

/// The applier's own statements, which is the only SQL this project runs
/// against Supabase that is not a migration file. Generated from that tool's
/// constants, never retyped, so the record cannot drift from what runs.
String buildBootstrapSection() {
  final buffer = StringBuffer()
    ..writeln('## Bootstrap — Applier Bookkeeping (before the first apply)')
    ..writeln()
    ..writeln(
      '> **Created before the first apply.** Applies to every run of '
      '`tool/apply_supabase_migrations.dart`: it creates the migration-history '
      'objects once with the Supabase CLI\'s own DDL, then records one row per '
      'applied file through the last statement below. Everything is '
      '`if not exists` or `on conflict`, so a project the CLI already linked is '
      'left untouched.',
    )
    ..writeln()
    ..writeln('```sql');

  for (final statement in supabaseBootstrapStatements) {
    buffer
      ..writeln('-- ${statement.label}')
      ..writeln(statement.terminated);
  }

  buffer
    ..writeln()
    ..writeln(
      '-- Run once per migration file, inside that file\'s transaction,',
    )
    ..writeln('-- so a file is either fully applied and recorded, or neither.')
    ..writeln('${upsertVersionRowSql(version: '<version>', name: '<name>')};')
    ..writeln('```')
    ..writeln();

  return buffer.toString();
}

/// Builds the complete ledger text.
String buildAllSupabaseSql() {
  final buffer = StringBuffer(_header);

  // Index rows first, so the top of the file is a usable table of contents.
  buffer.writeln(
    '| — | before the first apply | `tool/apply_supabase_migrations.dart` | '
    'The applier\'s own bookkeeping: the CLI-shaped migration-history table and '
    'the version row written per applied file. |',
  );
  for (final section in _sections) {
    buffer.writeln(
      '| ${section.version} | ${section.created} | `${section.file}` | '
      '${section.label} |',
    );
  }
  for (final section in _manualSections) {
    buffer.writeln(
      '| — | ${section.created} | `$manualDir/${section.file}` | '
      'Manual: ${section.label} |',
    );
  }
  buffer.writeln();
  buffer.write(buildBootstrapSection());

  String? currentGroup;
  for (final section in _sections) {
    final group = _groupTitles[section.version];
    if (group == null) {
      throw StateError(
        'No group title for app version ${section.version} — add one to '
        '_groupTitles in tool/generate_all_supabase_sql.dart.',
      );
    }
    if (group != currentGroup) {
      currentGroup = group;
      buffer
        ..writeln('## App Version ${section.version} — $group')
        ..writeln();
    }

    final file = File('$migrationsDir/${section.file}');
    if (!file.existsSync()) {
      throw StateError(
        'Missing $migrationsDir/${section.file} — the ledger lists a migration '
        'that is not on disk.',
      );
    }
    final sql = normalizeSql(file.readAsStringSync()).trimRight();

    buffer
      ..writeln('### ${section.version} · `${section.file}`')
      ..writeln()
      // The labelled comment the section rule asks for, above its SQL.
      ..writeln('> **Created ${section.created}.** ${section.label}')
      ..writeln()
      ..writeln('```sql')
      ..writeln(sql)
      ..writeln('```')
      ..writeln();
  }

  buffer.write(buildManualSection());

  return buffer.toString();
}

/// The manual SQL section: files the migration role cannot run.
String buildManualSection() {
  if (_manualSections.isEmpty) return '';

  final buffer = StringBuffer()
    ..writeln('## Manual SQL — Applied Outside The Migration Tool')
    ..writeln()
    ..writeln(
      '> **These statements are not applied by the migration tool.** '
      '`storage.objects` is owned by `supabase_storage_admin`, which the '
      'migration role (`postgres`) is not a member of, so a storage policy '
      'cannot be created by a migration or through the MCP. They are created '
      'once in Supabase\'s Storage policy editor, and recorded here because '
      'this ledger is the whole record of the SQL this project runs.',
    )
    ..writeln();

  for (final section in _manualSections) {
    final file = File('$manualDir/${section.file}');
    if (!file.existsSync()) {
      throw StateError(
        'Missing $manualDir/${section.file} — the ledger lists a manual file '
        'that is not on disk.',
      );
    }
    final sql = normalizeSql(file.readAsStringSync()).trimRight();

    buffer
      ..writeln('### Manual · `${section.file}`')
      ..writeln()
      ..writeln('> **Created ${section.created}.** ${section.label}')
      ..writeln()
      ..writeln('```sql')
      ..writeln(sql)
      ..writeln('```')
      ..writeln();
  }

  return buffer.toString();
}

/// Normalizes line endings so a CRLF checkout and the generator's LF output
/// compare equal.
String normalizeSql(String sql) => sql.replaceAll('\r\n', '\n');

/// Migration file names the ledger claims to cover, in order.
List<String> ledgerMigrationFiles() =>
    _sections.map((section) => section.file).toList();

/// The ledger's sections, in creation order, for tests that verify the output.
List<LedgerSection> ledgerSections() =>
    List<LedgerSection>.unmodifiable(_sections);

/// Manual file names the ledger claims to cover, in order.
List<String> ledgerManualFiles() =>
    _manualSections.map((section) => section.file).toList();

void main(List<String> args) {
  final check = args.contains('--check');
  final generated = normalizeSql(buildAllSupabaseSql());
  final file = File(ledgerPath);

  if (check) {
    if (!file.existsSync()) {
      stderr.writeln('MISSING: $ledgerPath has not been generated.');
      exit(1);
    }
    if (normalizeSql(file.readAsStringSync()) != generated) {
      stderr.writeln(
        'STALE: $ledgerPath does not match supabase/migrations/. '
        'Run: dart run tool/generate_all_supabase_sql.dart',
      );
      exit(1);
    }
    stdout.writeln('OK: $ledgerPath is up to date.');
    return;
  }

  file.writeAsStringSync(generated);
  final bytes = file.lengthSync();
  stdout.writeln(
    'Wrote $ledgerPath — ${_sections.length} migrations, '
    '${(bytes / 1024).round()} KB.',
  );
}
