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
export 'apply_supabase_migrations.dart' show migrationsDir;

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
        'purge_tombstones(180 days) scheduled daily through pg_cron.',
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
        'account holder''s own complete removal — every domain row, custom '
        'reference row, preference, payment submission and approval event, sync '
        'receipt, firm link and finally the Auth account — so no residue of it '
        'remains. Refuses, changing nothing, for a firm account and for an app '
        'administrator, and names the reason.',
  ),
];

/// Heading text per version group, so the groups read as phases rather than as
/// bare version numbers.
const Map<String, String> _groupTitles = <String, String>{
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
};

const String _header = '''<!--
Generated by tool/generate_all_supabase_sql.dart — do not edit by hand.
Rebuild:  dart run tool/generate_all_supabase_sql.dart
Guard:    dart run tool/generate_all_supabase_sql.dart --check
          (also enforced by test/supabase/all_supabase_sql_test.dart)
-->

# All Supabase SQL

Every SQL statement this project **ships** to Supabase, in the order it was
created: the versioned migration set, plus the applier's own bootstrap. One
section per file in `supabase/migrations/`, grouped by the app version that was
current when the phase landed; the text under each label is that migration file
**verbatim**. Two things are deliberately not here, and neither changes the
server: the assertions in `supabase/tests/*.sql` (runnable checks that roll back)
and the read-only counts `tool/check_supabase_seed.dart` and
`tool/apply_supabase_migrations.dart` issue.

- Only one project is ever in scope: `lsthasywrdrhuuxnykau` ("Legal Case Diary").
  AGENTS.md rule 12 names the live project that must never be touched.
- Server SQL is written only as a migration file, then this ledger is rebuilt.
  Nothing here is typed by hand, so the two can never disagree.
- Re-running the whole set is safe: creates are `if not exists`, functions are
  `create or replace`, every policy and trigger is preceded by a `drop ... if
  exists`, and all six seed inserts upsert `where <table>.is_user_modified = false`.
- One setting is dashboard-only and is not SQL: Realtime Authorization
  (`supabase/README.md`). pg_cron is installed and the tombstone purge
  scheduled by the last migration — verified on the project.
- Every version here is recorded in `supabase_migrations.schema_migrations` on
  `lsthasywrdrhuuxnykau`, so `supabase db push` sees the set as applied.

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
