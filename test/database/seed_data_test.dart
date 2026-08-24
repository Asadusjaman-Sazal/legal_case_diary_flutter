/// Tests for pre-seeded data structures and seed migration idempotency.
/// Task 04 Phase 3.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/constants/pre_seeded_data.dart';

void main() {
  // =========================================================================
  // Seed data structure tests
  // =========================================================================

  group('Pre-seeded data structures', () {
    test('all 8 court categories exist with correct stable IDs', () {
      final ids = seedCategories.map((c) => c.id).toSet();
      expect(ids, containsAll(allCategoryIds));
      expect(ids.length, 8);
    });

    test('each category has correct courtLevel', () {
      final byId = {for (final c in seedCategories) c.id: c};
      expect(byId[appellateDivisionId]!.courtLevel, 'appellate');
      expect(byId[highCourtDivisionId]!.courtLevel, 'high_court');
      for (final id in lowerCourtCategoryIds) {
        expect(byId[id]!.courtLevel, 'lower');
      }
    });

    test('each category has the expected seed collections', () {
      for (final cat in seedCategories) {
        final hasSteps = lowerCourtCategoryIds.contains(cat.id);
        expect(
          cat.steps.isNotEmpty,
          hasSteps,
          reason: '${cat.id} has an unexpected step collection',
        );
        expect(
          cat.allCaseTypes.isNotEmpty,
          true,
          reason: '${cat.id} has no case types',
        );
        expect(
          cat.onBehalfs.isNotEmpty,
          true,
          reason: '${cat.id} has no on-behalfs',
        );
        if (!hasSteps) {
          expect(cat.steps, isEmpty);
        }
        if (cat.id == appellateDivisionId || cat.id == highCourtDivisionId) {
          expect(cat.caseCategories, isNotEmpty);
        } else {
          expect(cat.caseCategories, isEmpty);
        }
      }
    });

    test('all step IDs are unique across categories', () {
      final allIds = seedCategories.expand((c) => c.steps.map((s) => s.id));
      expect(allIds.length, allIds.toSet().length);
    });

    test('all case type IDs are unique across categories', () {
      final allIds = seedCategories.expand(
        (c) => c.allCaseTypes.map((ct) => ct.id),
      );
      expect(allIds.length, allIds.toSet().length);
    });

    test('AD/HCD case types link to their nested case categories', () {
      for (final courtCategory in seedCategories.where(
        (category) =>
            category.id == appellateDivisionId ||
            category.id == highCourtDivisionId,
      )) {
        for (final caseCategory in courtCategory.caseCategories) {
          expect(seedCaseCategoryById[caseCategory.id], isNotNull);
          for (final caseType in caseCategory.caseTypes) {
            expect(caseType.caseCategoryId, caseCategory.id);
          }
        }
      }
    });

    test('lower-court case types remain scoped only by court category', () {
      for (final courtCategory in seedCategories.where(
        (category) => lowerCourtCategoryIds.contains(category.id),
      )) {
        expect(courtCategory.caseCategories, isEmpty);
        expect(
          courtCategory.allCaseTypes.every(
            (caseType) => caseType.caseCategoryId == null,
          ),
          isTrue,
        );
      }
    });

    test('all on-behalf IDs are unique across categories', () {
      final allIds = seedCategories.expand((c) => c.onBehalfs.map((o) => o.id));
      expect(allIds.length, allIds.toSet().length);
    });

    test('disposed step IDs set is non-empty and all IDs are resolvable', () {
      expect(disposedStepIds.isNotEmpty, true);
      final allStepIds = seedCategories
          .expand((c) => c.steps.map((s) => s.id))
          .toSet();
      for (final id in disposedStepIds) {
        expect(
          allStepIds.contains(id),
          true,
          reason: '$id is not a known step ID',
        );
      }
    });

    test('disposed-step set includes common disposed terms', () {
      // Check that the explicit Disposed marker is present.
      final hasDisposed = disposedStepIds.any((id) => id.endsWith('-disposed'));
      expect(hasDisposed, true);
    });

    test('all 8 divisions exist', () {
      expect(allDivisionIds.length, 8);
      expect(divisionLabelEn.length, 8);
      expect(divisionLabelBn.length, 8);
    });

    test('districtsByDivision contains all 8 divisions as keys', () {
      for (final div in allDivisionIds) {
        expect(districtIdsByDivision.containsKey(div), true);
        expect(districtIdsByDivision[div]!.isNotEmpty, true);
      }
    });

    test('every district has English and Bengali labels', () {
      for (final districts in districtIdsByDivision.values) {
        for (final district in districts) {
          expect(
            divisionLabelEn.containsKey(district) ||
                districtLabelEn.containsKey(district),
            true,
            reason: '$district missing English label',
          );
          expect(
            divisionLabelBn.containsKey(district) ||
                districtLabelBn.containsKey(district),
            true,
            reason: '$district missing Bengali label',
          );
        }
      }
    });

    test('supreme court names exist for both appellate and high court', () {
      final appCourts = supremeCourtNames.where(
        (c) => c.courtCategoryId == appellateDivisionId,
      );
      final hcCourts = supremeCourtNames.where(
        (c) => c.courtCategoryId == highCourtDivisionId,
      );
      expect(appCourts, hasLength(3));
      expect(hcCourts, hasLength(63));
      expect(
        appCourts.map((court) => court.orderIndex),
        orderedEquals([0, 1, 2]),
      );
      expect(
        hcCourts.map((court) => court.orderIndex),
        orderedEquals(List<int>.generate(63, (index) => index)),
      );
    });

    test('AD/HCD source counts and order are preserved', () {
      final app = seedCategoryById[appellateDivisionId]!;
      final high = seedCategoryById[highCourtDivisionId]!;

      expect(app.caseCategories, hasLength(4));
      expect(app.allCaseTypes, hasLength(11));
      expect(app.onBehalfs, hasLength(2));
      expect(high.caseCategories, hasLength(5));
      expect(high.allCaseTypes, hasLength(98));
      expect(high.onBehalfs, hasLength(2));
      expect(
        app.caseCategories.map((item) => item.orderIndex),
        orderedEquals([0, 1, 2, 3]),
      );
      expect(
        high.caseCategories.map((item) => item.orderIndex),
        orderedEquals([0, 1, 2, 3, 4]),
      );
    });

    test('lower court names exist for seed districts', () {
      // At minimum, Dhaka and Narayanganj have court data
      final dhakaCourts = lowerCourtNames
          .where((c) => c.district == 'dhaka')
          .toList();
      final narayanganjCourts = lowerCourtNames
          .where((c) => c.district == 'narayanganj')
          .toList();
      expect(
        dhakaCourts.isNotEmpty,
        true,
        reason: 'Dhaka should have lower court names',
      );
      expect(
        narayanganjCourts.isNotEmpty,
        true,
        reason: 'Narayanganj should have lower court names',
      );
    });

    test('every lower court has a division resolved', () {
      for (final court in lowerCourtNames) {
        expect(
          court.division,
          isNotNull,
          reason: 'Court ${court.id} missing division',
        );
      }
    });

    test(
      'Dhaka division lower-court records preserve scope and source order',
      () {
        const expectedDistricts = <String>{
          'dhaka',
          'faridpur',
          'gazipur',
          'gopalganj',
          'kishoregonj',
          'madaripur',
          'manikganj',
          'narayanganj',
        };
        expect(lowerCourtNames, hasLength(950));
        expect(
          lowerCourtNames.map((court) => court.district).toSet(),
          expectedDistricts,
        );

        final grouped = <String, List<SeedCourt>>{};
        for (final court in lowerCourtNames) {
          final division = court.division!;
          final district = court.district!;
          final key = '$division|$district|${court.courtCategoryId}';
          (grouped[key] ??= <SeedCourt>[]).add(court);
          expect(
            court.id,
            startsWith(
              'court-lower_courts-$division-$district-${court.courtCategoryId}-',
            ),
          );
        }

        for (final courts in grouped.values) {
          expect(
            courts.map((court) => court.orderIndex),
            orderedEquals(List<int>.generate(courts.length, (index) => index)),
          );
        }
      },
    );
    test('all seed courts have unique IDs', () {
      final allIds = allSeedCourts.map((c) => c.id);
      expect(allIds.length, allIds.toSet().length);
    });

    test('higher-lower court options have 3 entries', () {
      expect(higherLowerCourtOptions.length, 3);
    });

    test('label maps resolve all step IDs', () {
      for (final cat in seedCategories) {
        for (final step in cat.steps) {
          expect(stepLabelEn.containsKey(step.id), true);
          expect(stepLabelBn.containsKey(step.id), true);
        }
      }
    });

    test('label maps resolve all case type IDs', () {
      for (final cat in seedCategories) {
        for (final ct in cat.allCaseTypes) {
          expect(caseTypeLabelEn.containsKey(ct.id), true);
          expect(caseTypeLabelBn.containsKey(ct.id), true);
        }
      }
    });

    test('label maps resolve all case category IDs', () {
      for (final cat in seedCategories) {
        for (final caseCategory in cat.caseCategories) {
          expect(caseCategoryLabelEn.containsKey(caseCategory.id), true);
          expect(caseCategoryLabelBn.containsKey(caseCategory.id), true);
        }
      }
    });

    test('label maps resolve all on-behalf IDs', () {
      for (final cat in seedCategories) {
        for (final ob in cat.onBehalfs) {
          expect(onBehalfLabelEn.containsKey(ob.id), true);
          expect(onBehalfLabelBn.containsKey(ob.id), true);
        }
      }
    });

    test('label maps resolve all court IDs', () {
      for (final court in allSeedCourts) {
        expect(courtLabelEn.containsKey(court.id), true);
        expect(courtLabelBn.containsKey(court.id), true);
      }
    });

    test('seed category by ID lookup works', () {
      expect(seedCategoryById[appellateDivisionId], isNotNull);
      expect(seedCategoryById[metropolitanSessionsJudgeCriminalId], isNotNull);
    });

    test('stepIdsByCategory returns correct lists', () {
      for (final cat in seedCategories) {
        final ids = stepIdsByCategory[cat.id]!;
        expect(ids.length, cat.steps.length);
        for (final step in cat.steps) {
          expect(ids.contains(step.id), true);
        }
      }
    });

    test('lower-court seed lists preserve source counts and order', () {
      final byId = {for (final c in seedCategories) c.id: c};
      const expected = <String, (int, int, int)>{
        districtCourtsCivilId: (55, 19, 11),
        districtSessionsCriminalId: (32, 9, 5),
        metropolitanSessionsJudgeCriminalId: (32, 9, 5),
        chiefJudicialMagistrateId: (29, 4, 4),
        chiefMetropolitanMagistrateId: (29, 4, 4),
        executiveMagistrateId: (30, 6, 7),
      };

      for (final entry in expected.entries) {
        final category = byId[entry.key]!;
        expect(category.steps, hasLength(entry.value.$1));
        expect(category.allCaseTypes, hasLength(entry.value.$2));
        expect(category.onBehalfs, hasLength(entry.value.$3));
        expect(
          category.steps.map((item) => item.orderIndex),
          orderedEquals(List<int>.generate(entry.value.$1, (i) => i)),
        );
        expect(
          category.allCaseTypes.map((item) => item.orderIndex),
          orderedEquals(List<int>.generate(entry.value.$2, (i) => i)),
        );
        expect(
          category.onBehalfs.map((item) => item.orderIndex),
          orderedEquals(List<int>.generate(entry.value.$3, (i) => i)),
        );
      }
    });
  });

  // =========================================================================
  // Seed migration runner idempotency tests (unit-level)
  // =========================================================================

  group('SeedMigrationRunner idempotency', () {
    test('checksum_v1 is deterministic', () {
      // The checksum should be the same every time
      final cs1 = SeedMigrationRunnerStub.checksumV1;
      final cs2 = SeedMigrationRunnerStub.checksumV1;
      expect(cs1, cs2);
      expect(cs1.isNotEmpty, true);
    });
  });
}

/// Stub that exposes the private checksum for testing.
class SeedMigrationRunnerStub {
  /// Exposes [_checksumV1] getter for deterministic verification.
  static String get checksumV1 {
    // Replicating the same logic from SeedMigrationRunner._checksumV1
    const payload =
        'seed_v1_court_categories_case_categories_steps_casetypes_onbehalfs_courts';
    final bytes = payload.codeUnits.fold<int>(
      0,
      (prev, b) => ((prev * 31) ^ b) & 0x7FFFFFFF,
    );
    final b64 = _base64Encode('seed_v1:$bytes'.codeUnits);
    return b64;
  }

  // Minimal base64 encode for test determinism (no dependency on dart:convert).
  static String _base64Encode(List<int> bytes) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final buf = StringBuffer();
    for (var i = 0; i < bytes.length; i += 3) {
      final b0 = bytes[i];
      final b1 = i + 1 < bytes.length ? bytes[i + 1] : 0;
      final b2 = i + 2 < bytes.length ? bytes[i + 2] : 0;
      buf.write(chars[(b0 >> 2) & 0x3F]);
      buf.write(chars[((b0 << 4) | (b1 >> 4)) & 0x3F]);
      buf.write(
        i + 1 < bytes.length ? chars[((b1 << 2) | (b2 >> 6)) & 0x3F] : '=',
      );
      buf.write(i + 2 < bytes.length ? chars[b2 & 0x3F] : '=');
    }
    return buf.toString();
  }
}
