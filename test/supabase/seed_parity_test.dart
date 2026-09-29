/// Guards the generated Supabase reference-data seed migration.
///
/// The client seeds Drift from `lib/core/constants/pre_seeded_data.dart`, and
/// Supabase must be seeded from the same constants or the two sides disagree
/// about built-in IDs — which would duplicate courts on the next pull and
/// orphan `cases.court_id` values. So the committed migration is compared to the
/// generator's output byte for byte (after line-ending normalization).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/constants/pre_seeded_data.dart';

import '../../tool/check_supabase_seed.dart';
import '../../tool/generate_supabase_seed.dart';

void main() {
  group('Supabase seed migration', () {
    test('the committed migration matches the app seed constants', () {
      final file = File(seedMigrationPath);
      expect(
        file.existsSync(),
        isTrue,
        reason: 'missing $seedMigrationPath — run '
            '`dart run tool/generate_supabase_seed.dart`',
      );
      expect(
        normalizeSql(file.readAsStringSync()),
        normalizeSql(buildReferenceSeedSql()),
        reason: 'the seed migration is stale — run '
            '`dart run tool/generate_supabase_seed.dart`',
      );
    });

    test('every built-in row is seeded under its stable ID', () {
      final sql = normalizeSql(buildReferenceSeedSql());

      // Categories, steps, case types and roles are addressed by their own
      // stable tags; spot-check the first and last of each family so a broken
      // ID helper cannot slip through as "some rows were emitted".
      for (final category in seedCategories) {
        expect(sql, contains("('${category.id}',"));
      }
      // The first category that actually carries steps (Appellate Division
      // seeds none), so the sample is never empty.
      final firstCategory =
          seedCategories.firstWhere((category) => category.steps.isNotEmpty);
      expect(sql, contains("('${firstCategory.steps.first.id}',"));
      expect(sql, contains("('${firstCategory.allCaseTypes.first.id}',"));
      expect(sql, contains("('${firstCategory.onBehalfs.first.id}',"));
      expect(sql, contains("('${allSeedCourts.first.id}',"));
      expect(sql, contains("('${allSeedCourts.last.id}',"));

      // Every built-in row is unmodified, unsynced and server-version 1.
      expect(
        RegExp(r'\(.*false, false, null, null, 1767225600000, 1, null, false, null\)')
            .allMatches(sql)
            .length,
        greaterThan(1200),
      );
    });

    test('rows are upserted idempotently and a customized row is preserved', () {
      final sql = normalizeSql(buildReferenceSeedSql());
      final inserts =
          RegExp(r'insert into public\.\w+').allMatches(sql).length;
      final conflicts =
          RegExp(r'on conflict \(id\) do update set').allMatches(sql).length;
      final guards = RegExp(r'where \w+\.is_user_modified = false;')
          .allMatches(sql)
          .length;

      expect(inserts, 6, reason: 'six reference tables are seeded');
      expect(conflicts, inserts);
      expect(guards, inserts);
      // A seed never removes data and never hard-deletes.
      expect(sql.toLowerCase(), isNot(contains('delete from')));
      expect(sql.toLowerCase(), isNot(contains('drop table')));
    });

    test('the generator is deterministic', () {
      expect(buildReferenceSeedSql(), buildReferenceSeedSql());
    });

    test('the reference data is the size the server was seeded with', () {
      // Pins the size of the built-in data. Trimming the constants without
      // regenerating the migration (or the reverse) fails here, and the live
      // comparison for every table is `dart run tool/check_supabase_seed.dart`.
      expect(
        <String, int>{
          for (final seeded in expectedSeedCounts())
            seeded.table: seeded.appCount,
        },
        <String, int>{
          'court_categories': 8,
          'case_categories': 9,
          'courts': 1016,
          'steps': 209,
          'case_types': 160,
          'on_behalfs': 40,
        },
        reason: 'the six editable reference tables, as seeded',
      );
    });
  });
}
