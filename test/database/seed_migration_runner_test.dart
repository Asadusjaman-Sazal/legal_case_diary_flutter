/// Integration tests for the versioned seed migration runner.
///
/// Opens an in-memory Drift [AppDatabase], runs [SeedMigrationRunner], and
/// asserts that the seed data is inserted into the correct tables, that the
/// migration is idempotent, and that rows marked as user-modified are not
/// overwritten by subsequent seed migrations runs.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/constants/pre_seeded_data.dart'
    show
        appellateDivisionId,
        compareCivilLawNames,
        districtSessionsCriminalId,
        highCourtDivisionId,
        lawCategoryCivilProcedureEvidence,
        lawCategoryContractLandPropertyBusiness,
        seedCategories,
        seedDistrictCaseTypes,
        seedLawCategories,
        seedLaws,
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
      expect(applied, 6);

      final categories = await db.select(db.courtCategories).get();
      final caseCategories = await db.select(db.caseCategories).get();
      final steps = await db.select(db.steps).get();
      final caseTypes = await db.select(db.caseTypes).get();
      final onBehalfs = await db.select(db.onBehalfs).get();
      final courts = await db.select(db.courts).get();
      final laws = await db.select(db.laws).get();

      expect(categories, hasLength(seedCategories.length));
      expect(
        caseCategories,
        hasLength(
          seedCategories.fold<int>(
            0,
            (sum, category) => sum + category.caseCategories.length,
          ),
        ),
      );
      expect(
        steps,
        hasLength(
          seedCategories.fold<int>(0, (sum, c) => sum + c.steps.length),
        ),
      );
      expect(
        caseTypes,
        hasLength(
          seedCategories.fold<int>(0, (sum, c) => sum + c.allCaseTypes.length) +
              seedDistrictCaseTypes.length,
        ),
      );
      final narayanganj = caseTypes
          .where((type) => type.district == 'narayanganj')
          .toList();
      expect(
        narayanganj.map((type) => type.id).toSet(),
        seedDistrictCaseTypes.map((type) => type.id).toSet(),
      );
      expect(narayanganj.every((type) => type.nameBn != null), isTrue);
      expect(
        narayanganj.every(
          (type) => type.name.endsWith('-') && type.nameBn!.endsWith('-'),
        ),
        isTrue,
      );
      expect(
        narayanganj.every(
          (type) =>
              type.courtCategoryId ==
                  seedDistrictCaseTypes.first.courtCategoryId &&
              type.orderIndex >= 4 &&
              type.orderIndex <= 10,
        ),
        isTrue,
      );
      expect(
        caseTypes.where(
          (type) =>
              type.district != null &&
              type.courtCategoryId !=
                  seedDistrictCaseTypes.first.courtCategoryId,
        ),
        isEmpty,
      );
      expect(
        narayanganj.every((type) => !type.isCustom && !type.isUserModified),
        isTrue,
      );
      expect(
        onBehalfs,
        hasLength(
          seedCategories.fold<int>(0, (sum, c) => sum + c.onBehalfs.length),
        ),
      );
      expect(courts, hasLength(allSeedCourts.length));
      expect(laws, hasLength(seedLaws.length));

      // All seeded rows must be built-in (not custom, not user-modified).
      for (final cat in categories) {
        expect(cat.isCustom, false);
        expect(cat.isUserModified, false);
      }
      for (final step in steps) {
        expect(step.isCustom, false);
        expect(step.isUserModified, false);
      }
      for (final caseCategory in caseCategories) {
        expect(caseCategory.isCustom, false);
        expect(caseCategory.isUserModified, false);
      }
      for (final ct in caseTypes) {
        expect(ct.isCustom, false);
        expect(ct.isUserModified, false);
        if (ct.courtCategoryId == appellateDivisionId ||
            ct.courtCategoryId == highCourtDivisionId) {
          expect(ct.caseCategoryId, isNotNull);
        } else {
          expect(ct.caseCategoryId, isNull);
        }
      }
      for (final ob in onBehalfs) {
        expect(ob.isCustom, false);
        expect(ob.isUserModified, false);
      }
      for (final court in courts) {
        expect(court.isCustom, false);
        expect(court.isUserModified, false);
      }

      // Every seeded law stores one of the six categories; seed_v4 has moved
      // every contract row into Civil Law.
      final categoryIds = seedLawCategories.map((cat) => cat.id).toSet();
      for (final law in laws) {
        expect(law.isCustom, false);
        expect(law.isUserModified, false);
        expect(law.isDeleted, false);
        expect(categoryIds, contains(law.category));
      }
      expect(
        laws.where(
          (law) => law.category == lawCategoryContractLandPropertyBusiness,
        ),
        isEmpty,
      );

      // The merged Civil Law block is alphabetical after the constitution and
      // before family/criminal/tax/labour, which keep their seed order.
      final merged =
          seedLaws
              .where(
                (law) =>
                    law.categoryId == lawCategoryCivilProcedureEvidence ||
                    law.categoryId == lawCategoryContractLandPropertyBusiness,
              )
              .map((law) => law.name)
              .toList()
            ..sort(compareCivilLawNames);
      final expectedNames = <String>[];
      var mergedAdded = false;
      for (final law in seedLaws) {
        final isMerged =
            law.categoryId == lawCategoryCivilProcedureEvidence ||
            law.categoryId == lawCategoryContractLandPropertyBusiness;
        if (isMerged) {
          if (!mergedAdded) {
            expectedNames.addAll(merged);
            mergedAdded = true;
          }
          continue;
        }
        expectedNames.add(law.name);
      }
      final byOrder = laws.toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      expect(byOrder.map((law) => law.name).toList(), expectedNames);
      expect(merged, hasLength(22));
      expect(
        merged.first,
        'The Acquisition and Requisition of Immovable Property Act, 2017',
      );
      expect(merged.last, 'পাওয়ার অব অ্যাটর্নি আইন, ২০১২');

      // Migration ledger must record all six seeds.
      final migrations = await db.select(db.seedMigrations).get();
      expect(migrations, hasLength(6));
      expect(
        migrations.map((m) => m.migrationId),
        containsAll([
          'seed_v1',
          'seed_v2',
          'seed_v3',
          'seed_v4',
          'seed_v5',
          'seed_v6',
        ]),
      );
      expect(migrations.every((m) => m.checksum.isNotEmpty), true);
      expect(migrations.every((m) => m.appliedAt > 0), true);
    });

    test(
      'does not re-apply a migration already recorded in the ledger',
      () async {
        final first = await runner.runMigrations();
        expect(first, 6);

        final second = await runner.runMigrations();
        expect(second, 0);
      },
    );

    test('seed_v4 moves a legacy contract row into Civil Law', () async {
      await runner.runMigrations();

      await db
          .into(db.laws)
          .insert(
            LawsCompanion.insert(
              id: 'law-legacy-contract',
              name: 'Legacy Contract Act',
              category: const Value(lawCategoryContractLandPropertyBusiness),
              orderIndex: const Value(999),
              updatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
            ),
          );
      await db.customStatement(
        "DELETE FROM seed_migrations WHERE migration_id = 'seed_v4'",
      );

      final applied = await runner.runMigrations();
      expect(applied, 1);
      final legacy = await (db.select(
        db.laws,
      )..where((law) => law.id.equals('law-legacy-contract'))).getSingle();
      expect(legacy.category, lawCategoryCivilProcedureEvidence);
      expect(
        await (db.select(db.laws)..where(
              (law) =>
                  law.category.equals(lawCategoryContractLandPropertyBusiness),
            ))
            .get(),
        isEmpty,
      );
    });

    test('preserves user-modified rows on re-seed', () async {
      await runner.runMigrations();

      // Pick one row from each reference table to simulate user edits.
      final originalStep =
          await (db.select(db.steps)
                ..where(
                  (s) => s.courtCategoryId.equals(districtSessionsCriminalId),
                )
                ..limit(1))
              .getSingle();
      final originalCaseType =
          await (db.select(db.caseTypes)
                ..where(
                  (c) => c.courtCategoryId.equals(districtSessionsCriminalId),
                )
                ..limit(1))
              .getSingle();
      final originalOnBehalf =
          await (db.select(db.onBehalfs)
                ..where(
                  (o) => o.courtCategoryId.equals(districtSessionsCriminalId),
                )
                ..limit(1))
              .getSingle();
      final originalCourt =
          await (db.select(db.courts)
                ..where(
                  (c) => c.courtCategoryId.equals(districtSessionsCriminalId),
                )
                ..limit(1))
              .getSingle();

      // Simulate user edits.
      await db
          .update(db.steps)
          .replace(
            originalStep.copyWith(
              stepName: 'User Step Label',
              isUserModified: true,
            ),
          );
      await db
          .update(db.caseTypes)
          .replace(
            originalCaseType.copyWith(
              name: 'User Case Type Label',
              isUserModified: true,
            ),
          );
      await db
          .update(db.onBehalfs)
          .replace(
            originalOnBehalf.copyWith(
              name: 'User On Behalf Label',
              isUserModified: true,
            ),
          );
      await db
          .update(db.courts)
          .replace(
            originalCourt.copyWith(
              courtName: 'User Court Label',
              isUserModified: true,
            ),
          );

      // Force the seed migration to run again by clearing the ledger.
      await db.customStatement('DELETE FROM seed_migrations');
      await runner.runMigrations();

      // User-modified rows must retain the user's values and stay modified.
      final reStep = await (db.select(
        db.steps,
      )..where((s) => s.id.equals(originalStep.id))).getSingle();
      final reCaseType = await (db.select(
        db.caseTypes,
      )..where((c) => c.id.equals(originalCaseType.id))).getSingle();
      final reOnBehalf = await (db.select(
        db.onBehalfs,
      )..where((o) => o.id.equals(originalOnBehalf.id))).getSingle();
      final reCourt = await (db.select(
        db.courts,
      )..where((c) => c.id.equals(originalCourt.id))).getSingle();

      expect(reStep.stepName, 'User Step Label');
      expect(reStep.isUserModified, true);
      expect(reCaseType.name, 'User Case Type Label');
      expect(reCaseType.isUserModified, true);
      expect(reOnBehalf.name, 'User On Behalf Label');
      expect(reOnBehalf.isUserModified, true);
      expect(reCourt.courtName, 'User Court Label');
      expect(reCourt.isUserModified, true);

      // Unmodified rows must have been re-seeded with the canonical values.
      final untouchedStep =
          await (db.select(db.steps)..where(
                (s) => s.id.equals(
                  'step-district_sessions_criminal-framing_of_charge',
                ),
              ))
              .getSingle();
      expect(untouchedStep.isUserModified, false);
      expect(untouchedStep.stepName, 'Framing of Charge');
    });

    test('updates unmodified rows when seed migration runs again', () async {
      await runner.runMigrations();

      // Update an unmodified row in place to simulate a stale value.
      final original =
          await (db.select(db.steps)..where(
                (s) => s.id.equals(
                  'step-district_sessions_criminal-framing_of_charge',
                ),
              ))
              .getSingle();
      await db
          .update(db.steps)
          .replace(original.copyWith(stepName: 'Stale Step'));

      // Re-run the seed migration.
      await db.customStatement('DELETE FROM seed_migrations');
      await runner.runMigrations();

      final refreshed =
          await (db.select(db.steps)..where(
                (s) => s.id.equals(
                  'step-district_sessions_criminal-framing_of_charge',
                ),
              ))
              .getSingle();
      expect(refreshed.stepName, 'Framing of Charge');
      expect(refreshed.isUserModified, false);
    });
  });
}
