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
    label: 'Creates every Supabase table at once — 12 push/pull domain, 3 '
        'pull-only cache, 2 per-user preference and 2 server-managed — mirroring '
        'the shipped Drift columns. RLS is switched on in the same statement that '
        'creates each table.',
  ),
  LedgerSection(
    file: '20260929100100_phase1_signup_profile_trigger.sql',
    version: '0.0.289',
    label: 'handle_new_user() and its on_auth_user_created trigger: each new '
        'auth user gets an individual, free, firm-less profiles row. The only '
        'INSERT path for profiles.',
  ),
  LedgerSection(
    file: '20260929100200_phase1_seed_reference_data.sql',
    version: '0.0.289',
    label: 'Generated built-in reference data — 1,442 rows over six editable '
        'tables, under the same stable IDs the client seeds — upserted so a '
        'customized row is never overwritten.',
  ),
  LedgerSection(
    file: '20260929101000_phase2_server_internal_tables.sql',
    version: '0.0.290',
    label: 'The four server-internal ledgers (invite_attempts, '
        'mutation_receipts, app_admins, payment_approval_events) with deny-all '
        'RLS, two immutability triggers and the rate-limit index.',
  ),
  LedgerSection(
    file: '20260929102000_phase3_access_helpers.sql',
    version: '0.0.291',
    label: 'Access helpers (1/6): current_firm_id, is_firm_owner, can_edit_firm, '
        'can_delete_firm, is_premium, is_admin, can_read_topic and sha256_hex, '
        'all SECURITY DEFINER so policies cannot recurse.',
  ),
  LedgerSection(
    file: '20260929102100_phase3_sync_and_guard_triggers.sql',
    version: '0.0.291',
    label: 'Sync and write guards (2/6): server_updated_at stamping, the delete '
        'transition and resurrection rules, the free-tier 50-case ceiling and the '
        'payment submission rate limit, on the domain tables only.',
  ),
  LedgerSection(
    file: '20260929102200_phase3_payment_approval.sql',
    version: '0.0.291',
    label: 'approve_payment(uuid) (3/6): admin-only, atomic lock-validate-extend-'
        'mirror-audit path, plus mirror_owner_subscription_to_firm().',
  ),
  LedgerSection(
    file: '20260929102300_phase3_join_firm.sql',
    version: '0.0.291',
    label: 'join_firm(code) (4/6): rate-limited, sha256-normalized invite '
        'redemption that creates the membership, relinks the profile and consumes '
        'the invite.',
  ),
  LedgerSection(
    file: '20260929102400_phase3_realtime_broadcast.sql',
    version: '0.0.291',
    label: 'Realtime notification (5/6): one {table, id} Broadcast ping per '
        'change to the firm or user topic, with the can_read_topic policy on '
        'realtime.messages.',
  ),
  LedgerSection(
    file: '20260929102500_phase3_column_privileges.sql',
    version: '0.0.291',
    label: 'Column privileges (6/6): REVOKEs so the fields only the server may '
        'write — approval state, entitlement, firm ownership — cannot be set by '
        'a client even inside a permitted UPDATE.',
  ),
  LedgerSection(
    file: '20260929103000_phase4_rls_core_tables.sql',
    version: '0.0.292',
    label: 'RLS for the case-data half (1/3): cases, case_history, notes, '
        'case_references, delete_requests and conflict_log scoped to self or '
        'same-firm, with no DELETE policy anywhere.',
  ),
  LedgerSection(
    file: '20260929103100_phase4_rls_reference_tables.sql',
    version: '0.0.292',
    label: 'RLS for the six editable reference tables (2/3): built-in rows '
        'readable by every authenticated user, custom rows scoped to creator or '
        'firm, soft delete only.',
  ),
  LedgerSection(
    file: '20260929103200_phase4_rls_account_payment_tables.sql',
    version: '0.0.292',
    label: 'RLS for account, firm, preference and payment tables (3/3), and the '
        'closing statement that RLS is enabled on every table in the schema.',
  ),
  LedgerSection(
    file: '20260929104000_phase5_indexes_and_tombstone_purge.sql',
    version: '0.0.293',
    label: 'Delta-pull and payment indexes for every scoped cursor read, plus '
        'purge_tombstones(180 days) scheduled daily through pg_cron.',
  ),
];

/// Heading text per version group, so the groups read as phases rather than as
/// bare version numbers.
const Map<String, String> _groupTitles = <String, String>{
  '0.0.289': 'Task 16 Phase 1 — Core Schema, Sign-Up Trigger And Reference Seed',
  '0.0.290': 'Task 16 Phase 2 — Server-Internal Ledgers',
  '0.0.291': 'Task 16 Phase 3 — Helpers, Guards, RPCs, Realtime And Column '
      'Privileges',
  '0.0.292': 'Task 16 Phase 4 — Row Level Security',
  '0.0.293': 'Task 16 Phase 5 — Indexes And The Tombstone Purge',
};

const String _header = '''<!--
Generated by tool/generate_all_supabase_sql.dart — do not edit by hand.
Rebuild:  dart run tool/generate_all_supabase_sql.dart
Guard:    dart run tool/generate_all_supabase_sql.dart --check
          (also enforced by test/supabase/all_supabase_sql_test.dart)
-->

# All Supabase SQL

Every SQL statement this project has ever run against Supabase, in the order it
was created. One section per file in `supabase/migrations/`, grouped by the app
version that was current when the phase landed; the text under each label is that
migration file **verbatim**. The file opens with the one section that is not a
migration: the applier's own bootstrap statements, which run first.

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
    ..writeln('-- Run once per migration file, inside that file\'s transaction,')
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
List<LedgerSection> ledgerSections() => List<LedgerSection>.unmodifiable(_sections);

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
