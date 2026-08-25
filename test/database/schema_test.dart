/// Schema verification tests for the encrypted Drift database.
/// Implemented in Task 03 Phase 4.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/cases/data/local/cases_dao.dart';

void main() {
  group('AppDatabase schema', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await _seedReferencedRows(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('contains all expected tables', () async {
      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
          )
          .get();

      final names = tables.map((row) => row.read<String>('name')).toList();

      expect(
        names,
        containsAll(<String>[
          'cases',
          'case_history',
          'case_categories',
          'court_categories',
          'courts',
          'steps',
          'case_types',
          'on_behalfs',
          'notes',
          'case_references',
          'delete_requests',
          'conflict_log',
          'firms',
          'firm_members',
          'profiles',
          'sync_queue',
          'sync_metadata',
          'seed_migrations',
          'user_preferences',
          'case_notification_preferences',
        ]),
      );
    });

    test(
      'case category and case type tables carry the new relationship',
      () async {
        final caseCategoryColumns = await _tableColumns(db, 'case_categories');
        expect(
          caseCategoryColumns,
          containsAll(<String>[
            'id',
            'court_category_id',
            'name',
            'order_index',
            'is_custom',
            'is_user_modified',
            'updated_at',
            'version',
            'synced_at',
            'is_deleted',
            'last_modified_by',
          ]),
        );

        final caseTypeColumns = await _tableColumns(db, 'case_types');
        expect(caseTypeColumns, contains('case_category_id'));

        final courtColumns = await _tableColumns(db, 'courts');
        expect(courtColumns, contains('order_index'));
      },
    );

    test('cases table has the required columns', () async {
      final columns = await _tableColumns(db, 'cases');
      expect(
        columns,
        containsAll(<String>[
          'id',
          'case_type',
          'case_category_id',
          'case_number',
          'honorable_judges',
          'tender_number',
          'previous_court_case',
          'district_of_origin',
          'petitioner',
          'respondent',
          'petitioner_lead_counsel',
          'respondent_lead_counsel',
          'party_phone',
          'on_behalf_id',
          'court_id',
          'case_title_and_section',
          'case_remarks',
          'next_date',
          'last_step',
          'notes_results',
          'result',
          'created_at',
          'updated_at',
          'version',
          'synced_at',
          'is_deleted',
          'last_modified_by',
        ]),
      );
    });

    test('sync_queue table has the required columns', () async {
      final columns = await _tableColumns(db, 'sync_queue');
      expect(
        columns,
        containsAll(<String>[
          'id',
          'entity_type',
          'entity_id',
          'operation',
          'mutation_id',
          'base_version',
          'base_payload',
          'changed_fields',
          'payload',
          'pre_mutation_payload',
          'created_at',
          'retry_count',
          'last_attempt_at',
          'state',
          'last_error',
        ]),
      );
    });

    test('activeCases query filters out deleted rows', () async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await _insertCase(db, id: 'active', isDeleted: false, updatedAt: now);
      await _insertCase(db, id: 'deleted', isDeleted: true, updatedAt: now);

      final active = await db.activeCases.get();

      expect(active, hasLength(1));
      expect(active.first.id, 'active');
    });

    test(
      'active and disposed queries handle every AD/HCD result term',
      () async {
        final now = DateTime.now().toUtc().millisecondsSinceEpoch;
        const disposedTerms = <String>[
          'Dismissed',
          'খারিজ',
          'Disposed',
          'নিষ্পত্তি',
          'Discharged',
          'অব্যহতি',
        ];
        for (var index = 0; index < disposedTerms.length; index++) {
          await _insertCase(
            db,
            id: 'disposed-$index',
            isDeleted: false,
            updatedAt: now,
            result: index == 0
                ? 'Appeal ${disposedTerms[index].toUpperCase()} by the court'
                : disposedTerms[index],
          );
        }
        await _insertCase(
          db,
          id: 'disposed-step',
          isDeleted: false,
          updatedAt: now,
          lastStep: 'Disposed',
        );
        await _insertCase(
          db,
          id: 'active-result',
          isDeleted: false,
          updatedAt: now,
          result: 'Pending hearing',
        );

        expect(await CasesDao(db).getActiveCaseCount(), 1);
        final disposed = await CasesDao(db).getDisposed();
        expect(disposed, hasLength(disposedTerms.length + 1));
        expect(
          disposed.map((item) => item.id),
          containsAll(<String>[
            ...List.generate(6, (index) => 'disposed-$index'),
            'disposed-step',
          ]),
        );
      },
    );

    test(
      'purgeSoftDeletedRecords does not remove unsynced tombstones',
      () async {
        final now = DateTime.now().toUtc().millisecondsSinceEpoch;
        // A soft-deleted, unsynced row older than 90 days must not be purged.
        final old = now - 100 * 24 * 60 * 60 * 1000;
        await _insertCase(
          db,
          id: 'unsynced-tombstone',
          isDeleted: true,
          updatedAt: old,
          syncedAt: null,
        );

        await db.purgeSoftDeletedRecords();

        final remaining = await db.select(db.cases).get();
        expect(remaining, hasLength(1));
        expect(remaining.first.isDeleted, true);
      },
    );

    test('purgeSoftDeletedRecords removes old synced tombstones', () async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final old = now - 100 * 24 * 60 * 60 * 1000;
      await _insertCase(
        db,
        id: 'synced-tombstone',
        isDeleted: true,
        updatedAt: old,
        syncedAt: old,
      );

      await db.purgeSoftDeletedRecords();

      final remaining = await db.select(db.cases).get();
      expect(remaining, isEmpty);
    });

    test('purgeSoftDeletedRecords keeps recent synced tombstones', () async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      // A synced tombstone from 5 days ago is still within retention.
      final recent = now - 5 * 24 * 60 * 60 * 1000;
      await _insertCase(
        db,
        id: 'recent-synced-tombstone',
        isDeleted: true,
        updatedAt: recent,
        syncedAt: recent,
      );

      await db.purgeSoftDeletedRecords();

      final remaining = await db.select(db.cases).get();
      expect(remaining, hasLength(1));
    });
  });
}

Future<void> _seedReferencedRows(AppDatabase db) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await db
      .into(db.courtCategories)
      .insert(
        CourtCategoriesCompanion(
          id: const Value('cat-1'),
          nameKey: const Value('test_category'),
          courtLevel: const Value('lower'),
          orderIndex: const Value(0),
          updatedAt: Value(now),
        ),
      );
  await db
      .into(db.courts)
      .insert(
        CourtsCompanion(
          id: const Value('court-1'),
          courtName: const Value('Test Court'),
          higherLowerCourts: const Value('lower_courts'),
          courtCategoryId: const Value('cat-1'),
          updatedAt: Value(now),
        ),
      );
  await db
      .into(db.onBehalfs)
      .insert(
        OnBehalfsCompanion(
          id: const Value('ob-1'),
          courtCategoryId: const Value('cat-1'),
          name: const Value('Plaintiff'),
          orderIndex: const Value(0),
          updatedAt: Value(now),
        ),
      );
}

Future<Set<String>> _tableColumns(AppDatabase db, String tableName) async {
  final rows = await db.customSelect('PRAGMA table_info($tableName)').get();
  return rows.map((row) => row.read<String>('name')).toSet();
}

Future<void> _insertCase(
  AppDatabase db, {
  required String id,
  required bool isDeleted,
  required int updatedAt,
  int? syncedAt,
  String? result,
  String? lastStep,
}) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await db
      .into(db.cases)
      .insert(
        CasesCompanion(
          id: Value(id),
          userId: const Value('user-1'),
          caseType: const Value('civil'),
          caseNumber: Value('case-$id'),
          petitioner: const Value('Petitioner'),
          respondent: const Value('Respondent'),
          courtId: const Value('court-1'),
          onBehalfId: const Value('ob-1'),
          result: Value(result),
          lastStep: Value(lastStep),
          createdAt: Value(now),
          updatedAt: Value(updatedAt),
          isDeleted: Value(isDeleted),
          syncedAt: syncedAt == null ? const Value.absent() : Value(syncedAt),
        ),
      );
}
