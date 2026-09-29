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
        17,
        reason: 'Task 16 shipped fourteen; the audit closure added one, '
            'Task 17 Phase 5 added the owner-side ensure_firm conversion, and '
            'Task 17\'s audit added the abandoned-onboarding cleanup',
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
