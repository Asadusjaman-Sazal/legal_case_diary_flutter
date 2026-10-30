/// Law-name grouping tests.
///
/// The picker, the Case Reference screen and Settings → Law Names all build
/// their headings from one function, [groupLaws], so this pins that function's
/// rules: the seven categories in seed order, each group sorted by its own
/// `order_index` then name, and any row whose category is blank or unknown kept
/// in ONE trailing **Other** group instead of vanishing from every list.
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

    test('one group per seeded category, in seed order', () async {
      final groups = groupLaws(await repo.listAll());

      expect(
        groups.map((group) => group.categoryId).toList(),
        seedLawCategories.map((category) => category.id).toList(),
      );
      // Every seeded name appears exactly once and in the document's order.
      expect(
        groups.expand((group) => group.laws).map((law) => law.name).toList(),
        seedLaws.map((law) => law.name).toList(),
      );
    });

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
      // The seven known headings are untouched.
      expect(
        groups.take(seedLawCategories.length).map((group) => group.categoryId),
        seedLawCategories.map((category) => category.id),
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
