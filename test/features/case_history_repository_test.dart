/// Repository tests for Task 10 Phase 2: case-history write pipeline.
///
/// Verifies end-to-end (through `LocalCaseRepository`, never via direct UI or
/// direct history creation for the rule under test) that only the Quick Update
/// transaction may create automatic history, and that the new
/// `LocalCaseHistoryRepository` routes edits and soft deletes through the
/// sync-ready write path (sync columns + `sync_queue`).
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/cases/data/case_history_repository.dart';
import 'package:legal_case_diary/features/cases/data/case_repository.dart';
import 'package:legal_case_diary/features/cases/data/local/case_history_dao.dart';
import 'package:legal_case_diary/features/cases/data/local/cases_dao.dart';
import 'package:legal_case_diary/sync/sync_queue_dao.dart';
import 'package:legal_case_diary/sync/sync_write_helper.dart';

void main() {
  group('Task 10 Phase 2 — Case History writes', () {
    late AppDatabase db;
    late LocalIdentityService identity;
    late SyncWriteHelper syncHelper;
    late CaseHistoryDao historyDao;
    late LocalCaseRepository caseRepo;
    late LocalCaseHistoryRepository historyRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
      final prefs = await SharedPreferences.getInstance();
      identity = LocalIdentityService(prefs);
      syncHelper = SyncWriteHelper(SyncQueueDao(db), identity);
      historyDao = CaseHistoryDao(db);
      caseRepo = LocalCaseRepository(CasesDao(db), historyDao, syncHelper);
      historyRepo = LocalCaseHistoryRepository(historyDao, syncHelper);
      await _seedReferenceRows(db);
    });

    tearDown(() async => db.close());

    Future<String> insertCase({
      required int nextDateMs,
      String? lastStep = 'Hearing',
      String? notesResults = 'Witness present.',
      String? result,
    }) =>
        caseRepo.insertCase(
          CasesCompanion(
            caseNumber: const Value('991/2026'),
            caseType: const Value('Civil Suit'),
            petitioner: const Value('Alice'),
            respondent: const Value('Bob'),
            courtId: const Value('court-test'),
            onBehalfId: const Value('onbehalf-test-respondent'),
            nextDate: Value(nextDateMs),
            lastStep: Value(lastStep),
            notesResults: Value(notesResults),
            result: Value(result),
          ),
        );

    // -----------------------------------------------------------------------
    // Automatic history is created only by the Quick Update transaction.
    // -----------------------------------------------------------------------

    test(
      'quick update changing next_date saves the previous snapshot exactly once',
      () async {
        final id = await insertCase(
          nextDateMs: 1000,
          lastStep: 'Hearing',
          notesResults: 'Witness present.',
        );

        // Simultaneous step/note changes must not create extra entries.
        await caseRepo.updateCase(
          CasesCompanion(
            id: Value(id),
            nextDate: const Value(2000),
            lastStep: const Value('Argument'),
            notesResults: const Value('Adjourned.'),
          ),
          isQuickUpdate: true,
        );

        final history = await historyDao.getByCaseId(id);
        expect(history, hasLength(1));
        final entry = history.single;
        expect(entry.hearingDate, 1000); // previous next date
        expect(entry.lastStep, 'Hearing'); // previous step
        expect(entry.noteResult, 'Witness present.'); // previous note
        expect(entry.nextDate, 2000); // the new date set at that hearing
      },
    );

    test('quick update snapshot keeps the AD/HCD result', () async {
      final id = await insertCase(
        nextDateMs: 1000,
        lastStep: null, // AD/HCD cases have no Steps
        notesResults: 'Witness present.',
        result: 'Rule discharged',
      );

      await caseRepo.updateCase(
        CasesCompanion(
          id: Value(id),
          nextDate: const Value(2000),
          result: const Value('Adjourned'),
        ),
        isQuickUpdate: true,
      );

      final history = await historyDao.getByCaseId(id);
      expect(history, hasLength(1));
      final entry = history.single;
      expect(entry.hearingDate, 1000); // previous next date
      expect(entry.lastStep, isNull);
      expect(entry.result, 'Rule discharged'); // previous result
      expect(entry.noteResult, 'Witness present.');
      expect(entry.nextDate, 2000);
    });

    test('step/note-only quick update (date unchanged) creates no history',
        () async {
      final id = await insertCase(nextDateMs: 1000);

      await caseRepo.updateCase(
        CasesCompanion(
          id: Value(id),
          nextDate: const Value(1000), // date untouched
          lastStep: const Value('Argument'),
          notesResults: const Value('Heard both sides.'),
        ),
        isQuickUpdate: true,
      );

      expect(await historyDao.getByCaseId(id), isEmpty);
    });

    test('ordinary edit save (not a quick update) creates no history',
        () async {
      final id = await insertCase(nextDateMs: 1000);

      await caseRepo.updateCase(
        CasesCompanion(id: Value(id), nextDate: const Value(2000)),
        isQuickUpdate: false,
      );

      expect(await historyDao.getByCaseId(id), isEmpty);
    });

    test('entries are ordered by next_date descending', () async {
      final id = await insertCase(nextDateMs: 1000);
      await caseRepo.updateCase(
        CasesCompanion(id: Value(id), nextDate: const Value(2000)),
        isQuickUpdate: true,
      );
      await caseRepo.updateCase(
        CasesCompanion(id: Value(id), nextDate: const Value(3000)),
        isQuickUpdate: true,
      );

      final history = await historyDao.getByCaseId(id);
      expect(history, hasLength(2));
      expect(history.first.nextDate, 3000);
      expect(history.last.nextDate, 2000);
    });

    // -----------------------------------------------------------------------
    // History edits and deletes flow through the sync-ready write pipeline.
    // -----------------------------------------------------------------------

    test('history edit updates the row and enqueues a sync update', () async {
      final caseId = await insertCase(nextDateMs: 1000);
      await caseRepo.updateCase(
        CasesCompanion(id: Value(caseId), nextDate: const Value(2000)),
        isQuickUpdate: true,
      );
      final entry = (await historyDao.getByCaseId(caseId)).single;

      await historyRepo.updateHistory(
        CaseHistoryCompanion(
          id: Value(entry.id),
          hearingDate: const Value(1500),
          lastStep: const Value('Revised Step'),
          noteResult: const Value('Edited note.'),
          result: const Value('Heard in part'),
        ),
        baseEntry: entry,
      );

      final updated = await historyRepo.getById(entry.id);
      expect(updated, isNotNull);
      expect(updated!.hearingDate, 1500);
      expect(updated.lastStep, 'Revised Step');
      expect(updated.noteResult, 'Edited note.');
      expect(updated.result, 'Heard in part');
      expect(updated.lastModifiedBy, identity.getId());
      expect(updated.updatedAt, greaterThan(entry.updatedAt));

      final queue = SyncQueueDao(db);
      // The still-pending quick-update insert compacts with the edit into one
      // insert carrying the latest snapshot (insert+update matrix rule).
      final rows = await queue.getByEntity('case_history', entry.id);
      expect(rows, hasLength(1));
      expect(rows.single.operation, 'insert');
      final payload = jsonDecode(rows.single.payload) as Map<String, dynamic>;
      expect(payload['hearing_date'], 1500);
      expect(payload['last_step'], 'Revised Step');
      expect(payload['note_result'], 'Edited note.');
      expect(payload['result'], 'Heard in part');
      final changed = jsonDecode(rows.single.changedFields) as List<dynamic>;
      expect(
        changed.cast<String>(),
        containsAll(['hearing_date', 'last_step', 'note_result', 'result']),
      );
    });

    test('history delete soft-deletes and cancels an unsynced insert',
        () async {
      final caseId = await insertCase(nextDateMs: 1000);
      await caseRepo.updateCase(
        CasesCompanion(id: Value(caseId), nextDate: const Value(2000)),
        isQuickUpdate: true,
      );
      final entry = (await historyDao.getByCaseId(caseId)).single;
      final queue = SyncQueueDao(db);
      // The quick-update insert is still pending at this point.
      expect(await queue.getByEntity('case_history', entry.id), isNotEmpty);

      await historyRepo.deleteHistory(entry);

      // Row is soft-deleted: hidden from reads and flagged in storage.
      expect(await historyRepo.getById(entry.id), isNull);
      expect(await historyDao.getByCaseId(caseId), isEmpty);
      final raw = await (db.select(db.caseHistory)
            ..where((row) => row.id.equals(entry.id)))
          .getSingle();
      expect(raw.isDeleted, isTrue);
      expect(raw.lastModifiedBy, identity.getId());

      // Insert + delete compact to nothing: the server never needed the row.
      expect(await queue.getByEntity('case_history', entry.id), isEmpty);
    });

    test('history delete enqueues a delete when no pending insert exists',
        () async {
      final caseId = await insertCase(nextDateMs: 1000);
      // Fixture row created directly so the queue holds no insert for it.
      const fixtureId = 'history-fixture-delete';
      await historyDao.insertHistoryEntry(
        CaseHistoryCompanion(
          id: const Value(fixtureId),
          caseId: Value(caseId),
          userId: Value(identity.getId()),
          hearingDate: const Value(1000),
          nextDate: const Value(2000),
          lastStep: const Value('Hearing'),
          createdBy: Value(identity.getId()),
          sourceMutationId: const Value('mutation-fixture-delete'),
          baseCaseVersion: const Value(0),
          resultCaseVersion: const Value(1),
          updatedAt: const Value(1),
        ),
      );
      final fixture = await (db.select(db.caseHistory)
            ..where((row) => row.id.equals(fixtureId)))
          .getSingle();

      await historyRepo.deleteHistory(fixture);

      final queue = SyncQueueDao(db);
      final rows = await queue.getByEntity('case_history', fixtureId);
      expect(rows, hasLength(1));
      expect(rows.single.operation, 'delete');
      final payload = jsonDecode(rows.single.payload) as Map<String, dynamic>;
      expect(payload['is_deleted'], isTrue);
      expect(payload['id'], fixtureId);
    });
  });
}

// ---------------------------------------------------------------------------
// Seed helpers (reference rows required by the cases table foreign keys).
// ---------------------------------------------------------------------------

Future<void> _seedReferenceRows(AppDatabase db) async {
  await db.into(db.courtCategories).insert(
    const CourtCategoriesCompanion(
      id: Value('test-category'),
      nameKey: Value('test_category'),
      courtLevel: Value('lower'),
      orderIndex: Value(1),
      updatedAt: Value(1),
    ),
  );
  await db.into(db.courts).insert(
    const CourtsCompanion(
      id: Value('court-test'),
      courtName: Value('Test Court'),
      higherLowerCourts: Value('lower_courts'),
      courtCategoryId: Value('test-category'),
      orderIndex: Value(0),
      updatedAt: Value(1),
    ),
  );
  await db.into(db.onBehalfs).insert(
    const OnBehalfsCompanion(
      id: Value('onbehalf-test-respondent'),
      courtCategoryId: Value('test-category'),
      name: Value('Respondent'),
      orderIndex: Value(1),
      updatedAt: Value(1),
    ),
  );
}
