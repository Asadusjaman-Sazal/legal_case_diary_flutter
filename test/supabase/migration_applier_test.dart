/// Guards the applier `tool/apply_supabase_migrations.dart`, the only thing in
/// this repo that writes to Postgres.
///
/// Two classes of mistake matter here and neither is visible by reading the tool
/// once: applying to the wrong project (AGENTS.md rule 12 — one project is
/// writable, another is live and untouchable) and recording a version in a shape
/// the Supabase CLI does not read, which would make `supabase db push` re-apply
/// migrations that are already there. Both are pinned below, along with the
/// file-name parsing the version recording depends on.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/apply_supabase_migrations.dart';

void main() {
  group('migration file names', () {
    test('a timestamped file yields the version and name the CLI records', () {
      final record = parseMigrationFile('20260929100000_phase1_core_schema.sql');

      expect(record.version, '20260929100000');
      expect(record.name, 'phase1_core_schema');
      expect(record.fileName, '20260929100000_phase1_core_schema.sql');
    });

    test('anything the CLI would not read as a migration is refused', () {
      for (final name in <String>[
        'phase1_core_schema.sql', // no version
        '202609291000_short.sql', // 13 digits
        '20260929100000.sql', // no name
        '20260929100000_.sql', // empty name
        '20260929100000_phase1_core_schema.SQL', // wrong extension case
        '20260929100000_phase1_core_schema.sql.bak', // not a .sql file
      ]) {
        expect(
          () => parseMigrationFile(name),
          throwsA(isA<ToolFailure>()),
          reason: '$name must not be treated as a migration',
        );
      }
    });

    test('a name that cannot be inlined into SQL is refused', () {
      for (final name in <String>[
        "20260929100000_it's_fine.sql",
        '20260929100000_two words.sql',
      ]) {
        expect(() => parseMigrationFile(name), throwsA(isA<ToolFailure>()));
      }
    });

    test('the real folder lists its migrations in version order', () {
      final migrations = listMigrations();
      final versions = migrations.map((m) => m.version).toList();

      expect(
        versions,
        hasLength(41),
        reason: 'Task 16 shipped fourteen files; the audit closure added one, '
            'Task 17 Phase 5 added ensure_firm, Task 17\'s audit added the '
            'abandoned-onboarding cleanup, the Profile details follow-up added '
            'the self-service profile columns, Task 18 Phase 1 added '
            'push_changes, Task 18 Phase 3 added sync_server_time, Task 19 '
            'Phase 3 added the conflict verdict column and the created_at '
            'fallback guard, Task 20 Phase 1 added the ensure_firm '
            'premium gate, Task 20 Phase 2 added remove_firm_member, '
            'Task 20 Phase 4 added the push_changes delete-review branch, and '
            'the Task 20 audit closure added the sync_can_write firm '
            'membership guard, and its RLS follow-up added the firm-membership '
            'policies, Task 21 Phase 1 added the payments configuration '
            'table, and the four-plan pricing follow-up added the four-plan '
            'approval and the seeded receiving numbers, the discount '
            'follow-up added the discounted plan prices, Task 23 added '
            'the admin panel RPCs, the plan-name follow-up added the '
            'generated name columns, Task 12\'s account deletion added '
            'delete_my_account, the Check Your Email follow-up added the '
            'password-checked discard_unconfirmed_signup cleanup, and the '
            'Admin Panel follow-up added the unconfirmed-accounts list and '
            'its removal, and closed the EXECUTE that left its internal guard '
            'callable by any signed-in account, and the Non-verified '
            'Accounts follow-up added the 72-hour age window to that list and '
            'its delete, and the admin payment-alert server half added '
            'device_tokens, the per-user push toggle, the two reads only the '
            'server may run and the pg_net webhook that calls the FCM sender, '
            'and the daily payment-limit follow-up raised the submission rate '
            'limit to five, and firm mode\'s first phase scoped the read side '
            'with scope_owner_id and the scoped SELECT policies',
      );

      expect(versions.toSet(), hasLength(41), reason: 'versions must be unique');
      expect(
        versions,
        List<String>.from(versions)..sort(),
        reason: 'apply order is version order',
      );
      expect(versions.first, '20260929100000');
      expect(versions.last, '20261015100000');

      // Nothing on disk is skipped or invented: the tool applies the folder.
      final onDisk = Directory(migrationsDir)
          .listSync()
          .whereType<File>()
          .map((file) => file.uri.pathSegments.last)
          .where((name) => name.endsWith('.sql'))
          .toList()
        ..sort();
      expect(migrations.map((m) => m.fileName).toList(), onDisk);
    });
  });

  group('connection string', () {
    test('the URL is read out of the env file, quotes and comments ignored', () {
      const env = '''
# a comment
OTHER=value
$dbUrlVariable="postgresql://postgres.lsthasywrdrhuuxnykau:pw@host:5432/postgres"
''';
      expect(
        readConnectionUrl(env),
        'postgresql://postgres.lsthasywrdrhuuxnykau:pw@host:5432/postgres',
      );
    });

    test('a missing line is reported with what to put there', () {
      expect(() => readConnectionUrl('# nothing here\n'), throwsA(isA<ToolFailure>()));
    });

    test('the project comes from the pooler user or the direct host', () {
      expect(
        projectRefFromConnectionUrl(
          'postgresql://postgres.$writableProjectRef:pw@aws-0-ap-south-1.pooler.supabase.com:5432/postgres',
        ),
        writableProjectRef,
      );
      expect(
        projectRefFromConnectionUrl(
          'postgresql://postgres:pw@db.$writableProjectRef.supabase.co:5432/postgres',
        ),
        writableProjectRef,
      );
      expect(
        () => projectRefFromConnectionUrl('postgresql://localhost:5432/postgres'),
        throwsA(isA<ToolFailure>()),
      );
    });

    test('the password never reaches the run log', () {
      final masked = maskConnectionUrl(
        'postgresql://postgres.$writableProjectRef:sup3r-secret@aws-0-ap-south-1.pooler.supabase.com:5432/postgres',
      );

      expect(masked, isNot(contains('sup3r-secret')));
      expect(masked, contains(writableProjectRef));
      expect(masked, contains('aws-0-ap-south-1.pooler.supabase.com'));
    });

    test('the writable project is approved and the live one is refused', () {
      expect(
        assertProjectInScope(
          'postgresql://postgres.$writableProjectRef:pw@aws-0-ap-south-1.pooler.supabase.com:5432/postgres',
        ),
        writableProjectRef,
      );

      // The refusal has to name the project by both ref and name, so an operator
      // who hits it cannot mistake it for a parsing failure.
      expect(
        () => assertProjectInScope(
          'postgresql://postgres.$offLimitsProjectRef:pw@aws-0-ap-south-1.pooler.supabase.com:5432/postgres',
        ),
        throwsA(
          isA<ToolFailure>().having(
            (failure) => failure.message,
            'message',
            allOf(
              contains(offLimitsProjectRef),
              contains(offLimitsProjectName),
              contains('must never be touched'),
            ),
          ),
        ),
      );

      // Any other ref is refused too: the allow-list has exactly one entry.
      expect(
        () => assertProjectInScope(
          'postgresql://postgres.someotherref:pw@aws-0-ap-south-1.pooler.supabase.com:5432/postgres',
        ),
        throwsA(isA<ToolFailure>()),
      );
    });
  });

  group('psql output', () {
    test('status tags and re-run notices are counted, not reprinted', () {
      final summary = renderPsqlOutput(
        'CREATE TABLE\nALTER TABLE\nINSERT 0 1442\n',
        'psql:<stdin>:40: NOTICE:  trigger "trg_x" for relation "public.t" does '
            'not exist, skipping\n'
            'psql:<stdin>:9: NOTICE:  extension "pgcrypto" already exists, skipping\n',
      );

      expect(summary, contains('5 expected psql lines hidden'));
      expect(summary, isNot(contains('CREATE TABLE')));
    });

    test('a notice that matters survives the filter', () {
      // This is the one NOTICE the operator must not lose: pg_cron missing means
      // the tombstone purge is never scheduled.
      const notice = 'NOTICE:  pg_cron is not available on this project; '
          'purge_tombstones() is not scheduled.';
      const error = 'ERROR:  syntax error at end of input';

      final summary = renderPsqlOutput('', '$notice\n$error\n');

      expect(summary, contains(notice));
      expect(summary, contains(error));
      expect(summary, isNot(contains('hidden')));
    });
  });

  group('CLI-compatible version recording', () {
    test('the version row is the CLI upsert, with statements left NULL', () {
      final sql = upsertVersionRowSql(version: '20260929100000', name: 'phase1');

      expect(
        sql,
        "INSERT INTO supabase_migrations.schema_migrations(version, name, statements) "
        "VALUES ('20260929100000', 'phase1', NULL) "
        'ON CONFLICT (version) DO UPDATE SET name = EXCLUDED.name, '
        'statements = EXCLUDED.statements',
      );
    });

    test('values that could break out of the literal are refused', () {
      expect(
        () => upsertVersionRowSql(version: '1', name: "x' or 1=1 --"),
        throwsA(isA<ToolFailure>()),
      );
    });

    test('the bootstrap is the CLI DDL, in the CLI order, all idempotent', () {
      expect(
        supabaseBootstrapStatements.map((s) => s.sql).toList(),
        <String>[
          'CREATE SCHEMA IF NOT EXISTS supabase_migrations',
          'CREATE TABLE IF NOT EXISTS '
              'supabase_migrations.schema_migrations (version text NOT NULL PRIMARY KEY)',
          'ALTER TABLE supabase_migrations.schema_migrations '
              'ADD COLUMN IF NOT EXISTS statements text[]',
          'ALTER TABLE supabase_migrations.schema_migrations '
              'ADD COLUMN IF NOT EXISTS name text',
        ],
      );
      expect(
        supabaseBootstrapStatements.every((s) => s.sql.contains('IF NOT EXISTS')),
        isTrue,
      );
    });

    test('a rendered script labels and terminates every statement', () {
      final script = renderSqlScript(supabaseBootstrapStatements);

      expect(script.split(';').length, supabaseBootstrapStatements.length + 1);
      for (final statement in supabaseBootstrapStatements) {
        expect(script, contains('-- ${statement.label}\n${statement.sql};'));
      }
    });
  });
}
