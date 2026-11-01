/// Law-name grouping tests.
///
/// The picker, the Case Reference screen and Settings → Law Names all build
/// their headings from one function, [groupLaws], so this pins that function's
/// rules: the six stored categories, the merged Civil Law block in its
/// alphabetical (English first, then Bengali) order, each group sorted by its
/// own `order_index` then name, and any row whose category is blank or unknown
/// kept in ONE trailing **Other** group instead of vanishing from every list.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/constants/pre_seeded_data.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/database/seed_migration_runner.dart';
import 'package:legal_case_diary/features/case_reference/presentation/law_picker.dart';
import 'package:legal_case_diary/features/case_reference/presentation/reference_library.dart';
import 'package:legal_case_diary/features/settings/data/laws_repository.dart';
import 'package:legal_case_diary/features/settings/data/local/laws_dao.dart';
import 'package:legal_case_diary/sync/sync_queue_dao.dart';
import 'package:legal_case_diary/sync/sync_write_helper.dart';

void main() {
  group('groupLaws', () {
    late AppDatabase db;
    late LocalLawsRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
      final prefs = await SharedPreferences.getInstance();
      repo = LocalLawsRepository(
        LawsDao(db),
        SyncWriteHelper(SyncQueueDao(db), LocalIdentityService(prefs)),
      );
      await SeedMigrationRunner(db).runMigrations();
    });

    tearDown(() async {
      await db.close();
    });

    test('one group per displayed category, in seed order', () async {
      final groups = groupLaws(await repo.listAll());

      expect(
        groups.map((group) => group.categoryId).toList(),
        seedLawCategories.map((category) => category.id).toList(),
      );
      // Every seeded name appears exactly once, with the Civil Law block
      // alphabetised (English first, then Bengali) and every other heading in
      // the document's order.
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
      expect(
        groups.expand((group) => group.laws).map((law) => law.name).toList(),
        expectedNames,
      );
    });

    test(
      'the merged Civil Law group holds both former lists in order',
      () async {
        final groups = groupLaws(await repo.listAll());
        final civil = groups.firstWhere(
          (group) => group.categoryId == lawCategoryCivilProcedureEvidence,
        );

        // seed_v4 stored both former headings' rows as Civil Law, and the group
        // reads alphabetically with the Bengali names last.
        expect(
          groups.where(
            (group) =>
                group.categoryId == lawCategoryContractLandPropertyBusiness,
          ),
          isEmpty,
        );
        expect(civil.laws.map((law) => law.category).toSet(), <String>{
          lawCategoryCivilProcedureEvidence,
        });
        expect(
          civil.laws.map((law) => law.name),
          containsAll(<String>[
            'The Code of Civil Procedure, 1908',
            'The Contract Act, 1872',
          ]),
        );
        expect(civil.laws, hasLength(22));
        expect(
          civil.laws.first.name,
          'The Acquisition and Requisition of Immovable Property Act, 2017',
        );
        expect(civil.laws.last.name, 'পাওয়ার অব অ্যাটর্নি আইন, ২০১২');
      },
    );

    test('a blank or unknown category lands in one trailing Other group', () async {
      // A row written before categories existed, plus one a newer release might
      // write: neither may disappear from the picker.
      await repo.insert(
        const LawsCompanion(
          name: Value('Blank Category Act'),
          category: Value(''),
        ),
      );
      await db.customStatement(
        "UPDATE laws SET category = 'future_category' WHERE name = 'Blank Category Act'",
      );

      final groups = groupLaws(await repo.listAll());

      expect(groups.last.categoryId, isEmpty);
      expect(
        groups.last.laws.map((law) => law.name),
        contains('Blank Category Act'),
      );
      // The six known headings are untouched.
      expect(
        groups.take(seedLawCategories.length).map((group) => group.categoryId),
        seedLawCategories.map((category) => category.id),
      );
    });

    test('the law list files both former headings under Civil Law', () async {
      final laws = await repo.listAll();
      final sections = lawSectionsFor(laws, [
        ReferenceRow.admin(
          id: 'row-civil',
          referenceAndPageNo: '1',
          statute: 'The Code of Civil Procedure, 1908',
        ),
        ReferenceRow.admin(
          id: 'row-contract',
          referenceAndPageNo: '2',
          statute: 'The Contract Act, 1872',
        ),
      ]);

      final civil = sections.firstWhere(
        (section) => section.categoryId == lawCategoryCivilProcedureEvidence,
      );
      expect(
        civil.rows.map((row) => row.key),
        containsAll(<String>[
          'The Code of Civil Procedure, 1908',
          'The Contract Act, 1872',
        ]),
      );
      expect(
        sections.where(
          (section) =>
              section.categoryId == lawCategoryContractLandPropertyBusiness,
        ),
        isEmpty,
      );
    });

    test('rows in a group sort by order_index, then by name', () async {
      final groups = groupLaws(await repo.listAll());
      final criminal = groups.firstWhere(
        (group) => group.categoryId == lawCategoryCriminalLaw,
      );

      final indexes = criminal.laws.map((law) => law.orderIndex).toList();
      expect(indexes, orderedEquals(List<int>.from(indexes)..sort()));

      // Ties on order_index fall back to the name, so two rows added at the
      // same slot still read A→Z.
      final tied = [
        ...criminal.laws,
        Law(
          id: 'tie-a',
          name: 'A Tied Act',
          category: lawCategoryCriminalLaw,
          orderIndex: criminal.laws.first.orderIndex,
          isCustom: true,
          isUserModified: false,
          updatedAt: 0,
          isDeleted: false,
        ),
        Law(
          id: 'tie-b',
          name: 'B Tied Act',
          category: lawCategoryCriminalLaw,
          orderIndex: criminal.laws.first.orderIndex,
          isCustom: true,
          isUserModified: false,
          updatedAt: 0,
          isDeleted: false,
        ),
      ];
      final retied = groupLaws(
        tied,
      ).firstWhere((group) => group.categoryId == lawCategoryCriminalLaw);
      final names = retied.laws.map((law) => law.name).toList();
      expect(
        names.indexOf('A Tied Act'),
        lessThan(names.indexOf('B Tied Act')),
      );
    });
  });
}
