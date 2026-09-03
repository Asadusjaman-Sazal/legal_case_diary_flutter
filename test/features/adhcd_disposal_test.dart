/// Regression tests for AD/HCD case disposal classification.
///
/// Higher-court (Appellate Division / High Court Division) cases never carry a
/// `lastStep`, so the step disposal check evaluates as NULL. The old
/// `_stepIsDisposed` expression left that NULL unguarded (`NULL | resultCheck`),
/// which propagated through `_isDisposed` and its negation, hiding every AD/HCD
/// case from both the Active/Upcoming/Overdue/Daily screens AND the Disposed
/// screen. Guarding the step check with `lastStep IS NOT NULL` restores correct
/// behavior: a higher-court case is disposed only when its free-text `result`
/// contains a disposal term, and is otherwise active.
///
/// These tests assert that both AD and HCD cases with a non-disposal `result`
/// appear on the active screens but not in Disposed, while a disposal `result`
/// still classifies them as disposed.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/constants/pre_seeded_data.dart'
    show appellateDivisionId, highCourtDivisionId;
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/database/seed_migration_runner.dart';
import 'package:legal_case_diary/features/cases/data/case_repository.dart';
import 'package:legal_case_diary/features/cases/data/local/case_history_dao.dart';
import 'package:legal_case_diary/features/cases/data/local/cases_dao.dart';
import 'package:legal_case_diary/features/settings/data/local/courts_dao.dart';
import 'package:legal_case_diary/features/settings/data/local/on_behalfs_dao.dart';
import 'package:legal_case_diary/sync/sync_queue_dao.dart';
import 'package:legal_case_diary/sync/sync_write_helper.dart';

void main() {
  group('AD/HCD disposal classification', () {
    late AppDatabase db;
    late CasesDao casesDao;
    late LocalCaseRepository caseRepo;
    late CourtsDao courtsDao;
    late OnBehalfsDao onBehalfsDao;

    late String hcdCourtId;
    late String hcdOnBehalfId;
    late String adCourtId;
    late String adOnBehalfId;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
      await SeedMigrationRunner(db).runMigrations();

      final prefs = await SharedPreferences.getInstance();
      final identity = LocalIdentityService(prefs);
      final syncHelper = SyncWriteHelper(SyncQueueDao(db), identity);

      casesDao = CasesDao(db);
      courtsDao = CourtsDao(db);
      onBehalfsDao = OnBehalfsDao(db);
      caseRepo = LocalCaseRepository(
        casesDao,
        CaseHistoryDao(db),
        syncHelper,
      );

      final courts = await courtsDao.getAll();
      final hcdCourt = courts.firstWhere(
        (c) => c.courtCategoryId == highCourtDivisionId,
      );
      hcdCourtId = hcdCourt.id;

      final adCourt = courts.firstWhere(
        (c) => c.courtCategoryId == appellateDivisionId,
      );
      adCourtId = adCourt.id;

      final onBehalfs = await onBehalfsDao.getAll();
      hcdOnBehalfId = onBehalfs
          .firstWhere(
            (o) => o.courtCategoryId == highCourtDivisionId,
            orElse: () => onBehalfs.first,
          )
          .id;
      adOnBehalfId = onBehalfs
          .firstWhere(
            (o) => o.courtCategoryId == appellateDivisionId,
            orElse: () => onBehalfs.first,
          )
          .id;
    });

    tearDown(() async {
      await db.close();
    });

    test('HCD case with non-disposal result is active, not disposed', () async {
      final now =
          DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch;
      final rangeStart = DateTime.now()
          .subtract(const Duration(days: 1))
          .millisecondsSinceEpoch;

      final id = await caseRepo.insertCase(
        CasesCompanion(
          caseNumber: const Value('12/2025'),
          petitioner: const Value('State'),
          respondent: const Value('Accused'),
          courtId: Value(hcdCourtId),
          caseType: const Value('Criminal'),
          onBehalfId: Value(hcdOnBehalfId),
          nextDate: Value(now),
          result: const Value('Hearing'),
        ),
      );

      final active = await caseRepo.listActive();
      final disposed = await caseRepo.listDisposed();
      final upcoming =
          await caseRepo.listByNextDateRange(rangeStart, now + 1000);

      expect(active.map((c) => c.id), contains(id),
          reason: 'HCD "Hearing" case should appear in Active');
      expect(disposed.map((c) => c.id), isNot(contains(id)),
          reason: 'HCD "Hearing" case should NOT appear in Disposed');
      expect(upcoming.map((c) => c.id), contains(id),
          reason: 'HCD "Hearing" case should appear in date-range queries');
    });

    test('AD case with non-disposal result is active, not disposed', () async {
      final now =
          DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch;

      final id = await caseRepo.insertCase(
        CasesCompanion(
          caseNumber: const Value('AD/2025'),
          petitioner: const Value('State'),
          respondent: const Value('Accused'),
          courtId: Value(adCourtId),
          caseType: const Value('Civil'),
          onBehalfId: Value(adOnBehalfId),
          nextDate: Value(now),
          result: const Value('Hearing'),
        ),
      );

      final active = await caseRepo.listActive();
      final disposed = await caseRepo.listDisposed();

      expect(active.map((c) => c.id), contains(id),
          reason: 'AD "Hearing" case should appear in Active');
      expect(disposed.map((c) => c.id), isNot(contains(id)),
          reason: 'AD "Hearing" case should NOT appear in Disposed');
    });

    test('HCD case with disposal result IS disposed', () async {
      final now =
          DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch;

      final id = await caseRepo.insertCase(
        CasesCompanion(
          caseNumber: const Value('13/2025'),
          petitioner: const Value('State'),
          respondent: const Value('Accused'),
          courtId: Value(hcdCourtId),
          caseType: const Value('Criminal'),
          onBehalfId: Value(hcdOnBehalfId),
          nextDate: Value(now),
          result: const Value('নিষ্পত্তি'),
        ),
      );

      final active = await caseRepo.listActive();
      final disposed = await caseRepo.listDisposed();

      expect(disposed.map((c) => c.id), contains(id),
          reason: 'HCD "নিষ্পত্তি" result should be Disposed');
      expect(active.map((c) => c.id), isNot(contains(id)),
          reason: 'HCD disposed case should NOT appear in Active');
    });

    test('AD case with disposal result IS disposed', () async {
      final now =
          DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch;

      final id = await caseRepo.insertCase(
        CasesCompanion(
          caseNumber: const Value('AD/2026'),
          petitioner: const Value('State'),
          respondent: const Value('Accused'),
          courtId: Value(adCourtId),
          caseType: const Value('Civil'),
          onBehalfId: Value(adOnBehalfId),
          nextDate: Value(now),
          result: const Value('Disposed'),
        ),
      );

      final active = await caseRepo.listActive();
      final disposed = await caseRepo.listDisposed();

      expect(disposed.map((c) => c.id), contains(id),
          reason: 'AD "Disposed" result should be Disposed');
      expect(active.map((c) => c.id), isNot(contains(id)),
          reason: 'AD disposed case should NOT appear in Active');
    });

    test('lower-court case with no step IS active (regression guard)', () async {
      final courts = await courtsDao.getAll();
      final lowerCourt = courts.firstWhere(
        (c) => c.courtCategoryId != highCourtDivisionId &&
            c.courtCategoryId != appellateDivisionId,
      );
      final onBehalfs = await onBehalfsDao.getAll();
      final lowerOnBehalf = onBehalfs
          .firstWhere(
            (o) => o.courtCategoryId == lowerCourt.courtCategoryId,
            orElse: () => onBehalfs.first,
          )
          .id;

      final now =
          DateTime.now().add(const Duration(days: 3)).millisecondsSinceEpoch;

      final id = await caseRepo.insertCase(
        CasesCompanion(
          caseNumber: const Value('99/2025'),
          petitioner: const Value('A'),
          respondent: const Value('B'),
          courtId: Value(lowerCourt.id),
          caseType: const Value('Civil'),
          onBehalfId: Value(lowerOnBehalf),
          nextDate: Value(now),
          // lastStep left NULL.
        ),
      );

      final active = await caseRepo.listActive();
      final disposed = await caseRepo.listDisposed();

      expect(active.map((c) => c.id), contains(id),
          reason: 'lower-court case without a step should be Active');
      expect(disposed.map((c) => c.id), isNot(contains(id)),
          reason: 'lower-court case without a step should NOT be Disposed');
    });
  });
}
