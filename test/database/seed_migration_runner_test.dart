/// Integration tests for the versioned seed migration runner.
///
/// Opens an in-memory Drift [AppDatabase], runs [SeedMigrationRunner], and
/// asserts that the seed data is inserted into the correct tables, that the
/// migration is idempotent, and that rows marked as user-modified are not
/// overwritten by subsequent seed migrations runs.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/constants/pre_seeded_data.dart'
    show
        seedCategories,
        allSeedCourts;
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/database/seed_migration_runner.dart';

void main() {
  group('SeedMigrationRunner integration', () {
    late AppDatabase db;
    late SeedMigrationRunner runner;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      runner = SeedMigrationRunner(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('applies seed_v1 and inserts all reference data', () async {
      final applied = await runner.runMigrations();
      expect(applied, 1);

      final categories = await db.select(db.courtCategories).get();
      final steps = await db.select(db.steps).get();
      final caseTypes = await db.select(db.caseTypes).get();
      final onBehalfs = await db.select(db.onBehalfs).get();
      final courts = await db.select(db.courts).get();

      expect(categories, hasLength(seedCategories.length));
      expect(
        steps,
        hasLength(seedCategories.fold<int>(0, (sum, c) => sum + c.steps.length)),
      );
      expect(
        caseTypes,
        hasLength(
          seedCategories.fold<int>(0, (sum, c) => sum + c.caseTypes.length),
        ),
      );
      expect(
        onBehalfs,
        hasLength(
          seedCategories.fold<int>(0, (sum, c) => sum + c.onBehalfs.length),
        ),
      );
      expect(courts, hasLength(allSeedCourts.length));

      // All seeded rows must be built-in (not custom, not user-modified).
      for (final cat in categories) {
        expect(cat.isCustom, false);
        expect(cat.isUserModified, false);
      }
      for (final step in steps) {
        expect(step.isCustom, false);
        expect(step.isUserModified, false);
      }
      for (final ct in caseTypes) {
        expect(ct.isCustom, false);
        expect(ct.isUserModified, false);
      }
      for (final ob in onBehalfs) {
        expect(ob.isCustom, false);
        expect(ob.isUserModified, false);
      }
      for (final court in courts) {
        expect(court.isCustom, false);
        expect(court.isUserModified, false);
      }

      // Migration ledger must record seed_v1.
      final migrations = await db.select(db.seedMigrations).get();
      expect(migrations, hasLength(1));
      expect(migrations.first.migrationId, 'seed_v1');
      expect(migrations.first.checksum, isNotEmpty);
      expect(migrations.first.appliedAt, isPositive);
    });

    test('does not re-apply a migration already recorded in the ledger', () async {
      final first = await runner.runMigrations();
      expect(first, 1);

      final second = await runner.runMigrations();
      expect(second, 0);
    });

    test('preserves user-modified rows on re-seed', () async {
      await runner.runMigrations();

      // Pick one row from each reference table to simulate user edits.
      final originalStep = await (db.select(db.steps)
            ..where((s) => s.id.equals('step-appellate_division-hearing')))
          .getSingle();
      final originalCaseType = await (db.select(db.caseTypes)
            ..where(
              (c) => c.id.equals('casetype-appellate_division-civil_appeal'),
            ))
          .getSingle();
      final originalOnBehalf = await (db.select(db.onBehalfs)
            ..where(
              (o) => o.id.equals('onbehalf-appellate_division-appellant'),
            ))
          .getSingle();
      final originalCourt = await (db.select(db.courts)
            ..where(
              (c) => c.id.equals('court-higher_courts-appellate_division-annex_building_2_court_5'),
            ))
          .getSingle();

      // Simulate user edits.
      await db.update(db.steps).replace(
            originalStep.copyWith(
              stepName: 'User Hearing Label',
              isUserModified: true,
            ),
          );
      await db.update(db.caseTypes).replace(
            originalCaseType.copyWith(
              name: 'User Civil Appeal Label',
              isUserModified: true,
            ),
          );
      await db.update(db.onBehalfs).replace(
            originalOnBehalf.copyWith(
              name: 'User Appellant Label',
              isUserModified: true,
            ),
          );
      await db.update(db.courts).replace(
            originalCourt.copyWith(
              courtName: 'User Court Label',
              isUserModified: true,
            ),
          );

      // Force the seed migration to run again by clearing the ledger.
      await db.customStatement('DELETE FROM seed_migrations');
      await runner.runMigrations();

      // User-modified rows must retain the user's values and stay modified.
      final reStep = await (db.select(db.steps)
            ..where((s) => s.id.equals(originalStep.id)))
          .getSingle();
      final reCaseType = await (db.select(db.caseTypes)
            ..where((c) => c.id.equals(originalCaseType.id)))
          .getSingle();
      final reOnBehalf = await (db.select(db.onBehalfs)
            ..where((o) => o.id.equals(originalOnBehalf.id)))
          .getSingle();
      final reCourt = await (db.select(db.courts)
            ..where((c) => c.id.equals(originalCourt.id)))
          .getSingle();

      expect(reStep.stepName, 'User Hearing Label');
      expect(reStep.isUserModified, true);
      expect(reCaseType.name, 'User Civil Appeal Label');
      expect(reCaseType.isUserModified, true);
      expect(reOnBehalf.name, 'User Appellant Label');
      expect(reOnBehalf.isUserModified, true);
      expect(reCourt.courtName, 'User Court Label');
      expect(reCourt.isUserModified, true);

      // Unmodified rows must have been re-seeded with the canonical values.
      final untouchedStep = await (db.select(db.steps)
            ..where((s) => s.id.equals('step-appellate_division-filed')))
          .getSingle();
      expect(untouchedStep.isUserModified, false);
      expect(untouchedStep.stepName, 'Filed');
    });

    test('updates unmodified rows when seed migration runs again', () async {
      await runner.runMigrations();

      // Update an unmodified row in place to simulate a stale value.
      final original = await (db.select(db.steps)
            ..where((s) => s.id.equals('step-appellate_division-filed')))
          .getSingle();
      await db.update(db.steps).replace(
            original.copyWith(stepName: 'Stale Filed'),
          );

      // Re-run the seed migration.
      await db.customStatement('DELETE FROM seed_migrations');
      await runner.runMigrations();

      final refreshed = await (db.select(db.steps)
            ..where((s) => s.id.equals('step-appellate_division-filed')))
          .getSingle();
      expect(refreshed.stepName, 'Filed');
      expect(refreshed.isUserModified, false);
    });
  });
}
