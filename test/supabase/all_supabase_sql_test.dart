/// Guards `supabase/AllSupabaseSql.md`, the single record of every Supabase SQL
/// statement (AGENTS.md rule 13).
///
/// The ledger is generated from `supabase/migrations/`, so the risk it carries is
/// drift: a migration edited, added or deleted while the ledger still shows the
/// old text — which would make the one place a human trusts silently wrong. The
/// checks below are therefore textual and complete rather than sample-based: the
/// committed file is compared to the generator's output, every migration on disk
/// is proven present verbatim, and every section is proven labelled.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/apply_supabase_migrations.dart';
import '../../tool/generate_all_supabase_sql.dart';

void main() {
  group('AllSupabaseSql ledger', () {
    test('the committed ledger matches the generator', () {
      final file = File(ledgerPath);
      expect(
        file.existsSync(),
        isTrue,
        reason: 'missing $ledgerPath — run '
            '`dart run tool/generate_all_supabase_sql.dart`',
      );
      expect(
        normalizeSql(file.readAsStringSync()),
        normalizeSql(buildAllSupabaseSql()),
        reason: 'the ledger is stale — run '
            '`dart run tool/generate_all_supabase_sql.dart`',
      );
    });

    test('every migration on disk is covered, and nothing else is claimed', () {
      final onDisk = Directory(migrationsDir)
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.sql'))
          .map((file) => file.uri.pathSegments.last)
          .toList()
        ..sort();

      // Both directions matter: a new migration missing from the ledger is the
      // drift this rule exists to catch, and a ledger row with no file behind it
      // would document SQL that no longer exists.
      expect(ledgerMigrationFiles().toSet(), onDisk.toSet());
      expect(
        ledgerMigrationFiles(),
        _sorted(ledgerMigrationFiles()),
        reason: 'the ledger must stay in creation (filename) order',
      );
      expect(
        onDisk.length,
        45,
        reason: 'Task 16 shipped fourteen; the audit closure added one, '
            'Task 17 Phase 5 added the owner-side ensure_firm conversion, '
            'Task 17\'s audit added the abandoned-onboarding cleanup, the '
            'Profile details follow-up added the self-service profile columns, '
            'Task 18 Phase 1 added push_changes, Task 18 Phase 3 added '
            'sync_server_time, Task 19 Phase 3 added the conflict verdict '
            'column and the created_at fallback guard, Task 20 Phase 1 '
            'added the ensure_firm premium gate, Task 20 Phase 2 added '
            'remove_firm_member, Task 20 Phase 4 added the push_changes '
            'delete-review branch, the Task 20 audit closure added the '
            'sync_can_write firm membership guard, its RLS follow-up added '
            'the firm-membership policies, Task 21 Phase 1 added the '
            'payments configuration table, and the four-plan pricing '
            'follow-up added the four-plan approval and the seeded '
            'receiving numbers, the discount follow-up added the '
            'discounted plan prices, Task 23 added the admin panel RPCs, '
            'the plan-name follow-up added the generated name columns, '
            'Task 12\'s account deletion added delete_my_account, the '
            'Check Your Email follow-up added the password-checked '
            'discard_unconfirmed_signup cleanup, and the Admin Panel '
            'follow-up added the unconfirmed-accounts list and its removal, and '
            'closed the EXECUTE that left its internal guard callable by any '
            'signed-in account, and the Non-verified Accounts follow-up added '
            'the 72-hour age window to that list and its delete, and the admin '
            'payment-alert server half added device_tokens, the per-user push '
            'toggle, the two reads no client role may run and the pg_net webhook '
            'that calls the FCM sender, and the daily payment-limit follow-up '
            'raised the submission rate limit to five, firm mode\'s first '
            'phase scoped the read side with scope_owner_id and the scoped '
            'SELECT policies, and its second made creation share the owner\'s '
            'diary and the scope columns the server\'s, and its third put the '
            'empty-seat and seat-cap gates on the join itself, and its fourth '
            'cleared a removed member\'s push tokens, and its fifth made the '
            'permission flags a server-side boundary with the scope-column '
            'ruling folded in beside them',
      );
    });

    test('every section carries its SQL verbatim under a labelled heading', () {
      final ledger = normalizeSql(File(ledgerPath).readAsStringSync());

      for (final section in ledgerSections()) {
        final heading = '### ${section.version} · `${section.file}`';
        expect(
          ledger,
          contains(heading),
          reason: '$heading is missing from the ledger',
        );

        // The label sits between the heading and the SQL, per the section rule.
        final afterHeading =
            ledger.substring(ledger.indexOf(heading) + heading.length);
        expect(
          afterHeading,
          startsWith(
            '\n\n> **Created ${section.created}.** ${section.label}\n\n```sql\n',
          ),
          reason: '$heading must be followed by its labelled comment',
        );

        final sql = normalizeSql(
          File('$migrationsDir/${section.file}').readAsStringSync(),
        ).trimRight();
        expect(
          ledger,
          contains('```sql\n$sql\n```'),
          reason: 'the ledger text for ${section.file} differs from the file',
        );
      }
    });

    test('sections are grouped by app version, in increasing order', () {
      final ledger = normalizeSql(File(ledgerPath).readAsStringSync());
      final versions = RegExp(r'^## App Version (\d+\.\d+\.\d+) — ', multiLine: true)
          .allMatches(ledger)
          .map((match) => match.group(1)!)
          .toList();

      expect(versions, isNotEmpty);
      expect(versions, _sorted(versions));
      // Every `###` section is under some `## App Version` group.
      final sectionCount =
          RegExp(r'^### \d+\.\d+\.\d+ · ', multiLine: true).allMatches(ledger).length;
      expect(sectionCount, ledgerMigrationFiles().length);
    });

    test('the applier bootstrap leads the ledger, labelled and complete', () {
      final ledger = normalizeSql(File(ledgerPath).readAsStringSync());
      const heading = '## Bootstrap — Applier Bookkeeping (before the first apply)';

      expect(ledger, contains(heading));
      // It leads the file because it is the first SQL that ever runs, and it
      // carries a label like every version group does.
      expect(
        ledger.indexOf(heading),
        lessThan(ledger.indexOf('## App Version ')),
      );
      expect(ledger, contains('> **Created before the first apply.**'));

      // The text is the tool's own statements, so the record cannot drift from
      // what `dart run tool/apply_supabase_migrations.dart` sends.
      for (final statement in supabaseBootstrapStatements) {
        expect(ledger, contains(statement.terminated));
      }
      expect(
        ledger,
        contains('${upsertVersionRowSql(version: '<version>', name: '<name>')};'),
      );
    });

    test('the ledger scopes itself to the one writable project', () {
      final ledger = normalizeSql(File(ledgerPath).readAsStringSync());
      expect(ledger, contains('`lsthasywrdrhuuxnykau`'));
      // Same rule as the migration contract: no credentials in committed SQL.
      expect(ledger, isNot(contains('service_role')));
      expect(ledger, isNot(contains('SUPABASE_SERVICE')));
    });
  });
}

List<String> _sorted(List<String> values) => List<String>.from(values)..sort();
