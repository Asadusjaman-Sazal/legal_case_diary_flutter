/// Law-name list tests.
///
/// The list is one of the editable reference tables (AGENTS.md rule 10), so it
/// must obey the same three write rules as the court list — an add is custom and
/// appended, a rename marks the row user-modified, a delete refuses a built-in —
/// and it must arrive on every install with the 57 names the reference document
/// lists, each under one of the seven categories.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/constants/pre_seeded_data.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/database/seed_migration_runner.dart';
import 'package:legal_case_diary/features/settings/data/laws_repository.dart';
import 'package:legal_case_diary/features/settings/data/local/laws_dao.dart';
import 'package:legal_case_diary/sync/sync_queue_dao.dart';
import 'package:legal_case_diary/sync/sync_write_helper.dart';

void main() {
  group('LawsRepository', () {
    late AppDatabase db;
    late SyncWriteHelper syncHelper;
    late LocalLawsRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
      final prefs = await SharedPreferences.getInstance();
      syncHelper = SyncWriteHelper(
        SyncQueueDao(db),
        LocalIdentityService(prefs),
      );
      repo = LocalLawsRepository(LawsDao(db), syncHelper);
      await SeedMigrationRunner(db).runMigrations();
    });

    tearDown(() async {
      await db.close();
    });

    test('the seed lists every name once, under a known category', () async {
      final laws = await repo.listAll();

      expect(laws, hasLength(seedLaws.length));
      expect(seedLaws, hasLength(57));
      expect(
        seedLaws.map((law) => law.id).toSet(),
        hasLength(seedLaws.length),
        reason: 'a stable id names exactly one law',
      );
      expect(
        seedLaws.map((law) => law.name).toSet(),
        hasLength(seedLaws.length),
      );

      final categoryIds = seedLawCategories.map((cat) => cat.id).toSet();
      expect(categoryIds, hasLength(7));
      for (final law in laws) {
        expect(categoryIds, contains(law.category));
      }

      // Every category holds at least one name, so the grouped screens never
      // render an empty heading.
      final used = laws.map((law) => law.category).toSet();
      expect(used, categoryIds);

      // Display order is the seed order, which is also category order.
      expect(
        laws.map((law) => law.name).toList(),
        seedLaws.map((law) => law.name).toList(),
      );
      expect(
        laws.map((law) => law.category).toList(),
        seedLaws.map((law) => law.categoryId).toList(),
      );
    });

    test('a typed name is custom, lands last and queues an insert', () async {
      final id = await repo.insert(
        const LawsCompanion(
          name: Value('The Test Act, 2020'),
          category: Value(lawCategoryCriminalLaw),
        ),
      );

      final law = await repo.getById(id);
      expect(law, isNotNull);
      expect(law!.name, 'The Test Act, 2020');
      expect(law.category, lawCategoryCriminalLaw);
      expect(law.isCustom, true);
      expect(law.isUserModified, false);
      expect(
        law.orderIndex,
        seedLaws.length,
        reason: 'a new name appends after the seeded list',
      );

      final queue = await SyncQueueDao(db).getByEntity('law', id);
      expect(queue.single.operation, 'insert');
      expect(
        jsonDecode(queue.single.changedFields),
        containsAll(<String>['name', 'category', 'order_index']),
      );
    });

    test('renaming a built-in name marks it modified across re-seeds', () async {
      final id = 'law-penal-code-1860';
      final original = await repo.getById(id);
      expect(original, isNotNull);

      await repo.update(
        const LawsCompanion(
          id: Value('law-penal-code-1860'),
          name: Value('Penal Code'),
        ),
        base: original,
      );

      var law = await repo.getById(id);
      expect(law!.name, 'Penal Code');
      expect(law.isUserModified, true);
      expect(law.category, lawCategoryCriminalLaw);

      final queue = await SyncQueueDao(db).getByEntity('law', id);
      expect(queue.single.operation, 'update');
      expect(jsonDecode(queue.single.changedFields), contains('name'));

      // A later seed migration refreshes built-ins but must not overwrite what
      // the lawyer typed.
      await db.customStatement('DELETE FROM seed_migrations');
      await SeedMigrationRunner(db).runMigrations();
      law = await repo.getById(id);
      expect(law!.name, 'Penal Code');
      expect(law.isUserModified, true);
    });

    test('a built-in name cannot be deleted', () async {
      final law = await repo.getById('law-penal-code-1860');

      expect(() => repo.delete(law!), throwsA(isA<StateError>()));
      expect(await repo.getById('law-penal-code-1860'), isNotNull);
      expect(
        await SyncQueueDao(db).getByEntity('law', 'law-penal-code-1860'),
        isEmpty,
      );
    });

    test('a typed name soft-deletes and leaves no queue behind', () async {
      final id = await repo.insert(
        const LawsCompanion(
          name: Value('The Delete Me Act, 2021'),
          category: Value(lawCategoryTaxFinance),
        ),
      );
      final law = await repo.getById(id);

      await repo.delete(law!);

      expect(await repo.getById(id), isNull);
      // Insert + delete on a row the server never saw compact to nothing.
      expect(await SyncQueueDao(db).getByEntity('law', id), isEmpty);
    });
  });
}
