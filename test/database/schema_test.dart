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

    test('case_history table has the required columns', () async {
      final columns = await _tableColumns(db, 'case_history');
      expect(
        columns,
        containsAll(<String>[
          'id',
          'case_id',
          'user_id',
          'firm_id',
          'hearing_date',
          'last_step',
          'next_date',
          'note_result',
          'result',
          'created_by',
          'source_mutation_id',
          'base_case_version',
          'result_case_version',
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

    test('case_notification_preferences carries the per-case time', () async {
      // The Notification Time a case can set for itself; null means it follows
      // the user's default time in `user_preferences`.
      final columns = await _tableColumns(db, 'case_notification_preferences');
      expect(
        columns,
        containsAll(<String>[
          'user_id',
          'case_id',
          'enabled',
          'offsets',
          'time_minutes',
          'updated_at',
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

    test('only Disposed disposes a higher-court result', () async {
      // A higher court has no steps, so its Result field is the only signal —
      // and only Disposed / নিষ্পত্তি counts (user request, 0.0.735). Dismissed
      // and Discharged are results a live case can carry.
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      const liveResults = <String>[
        'Dismissed',
        'খারিজ',
        'Discharged',
        'অব্যহতি',
        'Pending hearing',
      ];
      for (var index = 0; index < liveResults.length; index++) {
        await _insertCase(
          db,
          id: 'live-$index',
          isDeleted: false,
          updatedAt: now,
          result: liveResults[index],
        );
      }
      await _insertCase(
        db,
        id: 'disposed-en',
        isDeleted: false,
        updatedAt: now,
        // Matched inside a longer sentence and in any case, as the SQL does.
        result: 'Appeal DISPOSED by the court',
      );
      await _insertCase(
        db,
        id: 'disposed-bn',
        isDeleted: false,
        updatedAt: now,
        result: 'নিষ্পত্তি',
      );

      expect(await CasesDao(db).getActiveCaseCount(), liveResults.length);
      final disposed = await CasesDao(db).getDisposed();
      expect(
        disposed.map((item) => item.id),
        containsAll(<String>['disposed-en', 'disposed-bn']),
      );
      expect(disposed, hasLength(2));
    });

    test('only the Disposed step disposes a lower-court case', () async {
      // Every outcome step the disposed set used to hold leaves the case live.
      const otherSteps = <String>[
        'Withdrawal',
        'Withdrawal under Section 248',
        'Dismissal',
        'Allowed',
        'Rejected',
        'Rejected Right Away',
        'Conviction',
        'Acquittal',
        'Remand',
        'Maintainance Not Necessary',
      ];
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      for (var index = 0; index < otherSteps.length; index++) {
        await _insertCase(
          db,
          id: 'step-live-$index',
          isDeleted: false,
          updatedAt: now,
          lastStep: otherSteps[index],
        );
      }
      await _insertCase(
        db,
        id: 'step-disposed',
        isDeleted: false,
        updatedAt: now,
        lastStep: 'Disposed',
      );
      await _insertCase(
        db,
        id: 'step-disposed-bn',
        isDeleted: false,
        updatedAt: now,
        lastStep: 'নিষ্পত্তি',
      );

      expect(await CasesDao(db).getActiveCaseCount(), otherSteps.length);
      final disposed = await CasesDao(db).getDisposed();
      expect(
        disposed.map((item) => item.id),
        containsAll(<String>['step-disposed', 'step-disposed-bn']),
      );
      expect(disposed, hasLength(2));
    });

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

    test('the cached chamber row carries the logo fields', () async {
      final columns = await _tableColumns(db, 'firms');
      expect(columns, containsAll(<String>['logo_path', 'logo_version']));
    });

    test('the cached profile row carries the picture fields', () async {
      final columns = await _tableColumns(db, 'profiles');
      expect(columns, containsAll(<String>['avatar_path', 'avatar_version']));
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
