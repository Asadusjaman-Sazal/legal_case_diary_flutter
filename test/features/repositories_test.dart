/// Unit tests for Phase 3 local repositories.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/constants/pre_seeded_data.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/case_reference/data/reference_repository.dart';
import 'package:legal_case_diary/features/cases/data/case_form_repository.dart';
import 'package:legal_case_diary/features/cases/data/case_repository.dart';
import 'package:legal_case_diary/features/settings/data/local/case_notification_preferences_dao.dart';
import 'package:legal_case_diary/shared/widgets/add_edit_case_sheet.dart';
import 'package:legal_case_diary/features/cases/data/local/case_history_dao.dart';
import 'package:legal_case_diary/features/cases/data/local/cases_dao.dart';
import 'package:legal_case_diary/features/case_reference/data/local/case_references_dao.dart';
import 'package:legal_case_diary/features/notes/data/local/notes_dao.dart';
import 'package:legal_case_diary/features/notes/data/notes_repository.dart';
import 'package:legal_case_diary/features/settings/data/court_categories_repository.dart';
import 'package:legal_case_diary/features/settings/data/courts_repository.dart';
import 'package:legal_case_diary/features/settings/data/delete_requests_repository.dart';
import 'package:legal_case_diary/features/settings/data/local/court_categories_dao.dart';
import 'package:legal_case_diary/features/settings/data/local/courts_dao.dart';
import 'package:legal_case_diary/features/settings/data/local/on_behalfs_dao.dart';
import 'package:legal_case_diary/features/settings/data/local/user_preferences_dao.dart';
import 'package:legal_case_diary/features/settings/data/on_behalfs_repository.dart';
import 'package:legal_case_diary/features/settings/data/settings_repository.dart';
import 'package:legal_case_diary/sync/delete_requests_dao.dart';
import 'package:legal_case_diary/sync/sync_queue_dao.dart';
import 'package:legal_case_diary/sync/sync_write_helper.dart';

void main() {
  group('Phase 3 Repositories', () {
    late AppDatabase db;
    late SyncWriteHelper syncHelper;
    late CasesDao casesDao;
    late CaseHistoryDao historyDao;
    late NotesDao notesDao;
    late CaseReferencesDao referencesDao;
    late CourtCategoriesDao courtCategoriesDao;
    late CourtsDao courtsDao;
    late OnBehalfsDao onBehalfsDao;
    late DeleteRequestsDao deleteRequestsDao;
    late UserPreferencesDao userPrefsDao;
    late LocalCaseRepository caseRepo;
    late LocalNotesRepository notesRepo;
    late LocalReferenceRepository referenceRepo;
    late LocalCourtCategoriesRepository courtCategoriesRepo;
    late LocalCourtsRepository courtsRepo;
    late LocalOnBehalfsRepository onBehalfsRepo;
    late LocalDeleteRequestsRepository deleteRequestsRepo;
    late LocalSettingsRepository settingsRepo;
    late String sampleCourtCategoryId;
    late String sampleCourtId;
    late String sampleOnBehalfId;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
      final prefs = await SharedPreferences.getInstance();
      final identity = LocalIdentityService(prefs);
      syncHelper = SyncWriteHelper(SyncQueueDao(db), identity);

      casesDao = CasesDao(db);
      historyDao = CaseHistoryDao(db);
      notesDao = NotesDao(db);
      referencesDao = CaseReferencesDao(db);
      courtCategoriesDao = CourtCategoriesDao(db);
      courtsDao = CourtsDao(db);
      onBehalfsDao = OnBehalfsDao(db);
      deleteRequestsDao = DeleteRequestsDao(db);
      userPrefsDao = UserPreferencesDao(db);

      caseRepo = LocalCaseRepository(casesDao, historyDao, syncHelper);
      notesRepo = LocalNotesRepository(notesDao, syncHelper);
      referenceRepo = LocalReferenceRepository(referencesDao, syncHelper);
      courtCategoriesRepo = LocalCourtCategoriesRepository(
        courtCategoriesDao,
        syncHelper,
      );
      courtsRepo = LocalCourtsRepository(courtsDao, syncHelper);
      onBehalfsRepo = LocalOnBehalfsRepository(onBehalfsDao, syncHelper);
      deleteRequestsRepo = LocalDeleteRequestsRepository(
        deleteRequestsDao,
        syncHelper,
      );
      settingsRepo = LocalSettingsRepository(userPrefsDao, identity);

      sampleCourtCategoryId = await courtCategoriesRepo.insert(
        CourtCategoriesCompanion(
          nameKey: const Value('test_category'),
          courtLevel: const Value('lower'),
          orderIndex: const Value(1),
        ),
      );

      sampleCourtId = await courtsRepo.insert(
        CourtsCompanion(
          courtName: const Value('Test Court'),
          higherLowerCourts: const Value('lower_courts'),
          courtCategoryId: Value(sampleCourtCategoryId),
        ),
      );

      sampleOnBehalfId = await onBehalfsRepo.insert(
        OnBehalfsCompanion(
          courtCategoryId: Value(sampleCourtCategoryId),
          name: const Value('Plaintiff'),
          orderIndex: const Value(1),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('CaseRepository inserts a case and enqueues sync insert', () async {
      final id = await caseRepo.insertCase(
        CasesCompanion(
          caseNumber: const Value('111/2025'),
          petitioner: const Value('Alice'),
          respondent: const Value('Bob'),
          courtId: Value(sampleCourtId),
          caseType: const Value('Civil'),
          onBehalfId: Value(sampleOnBehalfId),
          partyPhone: const Value('+8801835000000'),
        ),
      );

      final fetched = await caseRepo.getById(id);
      expect(fetched, isNotNull);
      expect(fetched!.caseNumber, '111/2025');
      expect(fetched.partyPhone, '+8801835000000');
      expect(fetched.isDeleted, false);

      final queue = await SyncQueueDao(db).getByEntity('case', id);
      expect(queue, hasLength(1));
      expect(queue.first.entityType, 'case');
      expect(queue.first.operation, 'insert');
      expect(queue.first.entityId, id);
    });

    test(
      'CaseRepository soft-deletes a case and enqueues sync delete',
      () async {
        final id = await caseRepo.insertCase(
          CasesCompanion(
            caseNumber: const Value('222/2025'),
            petitioner: const Value('Alice'),
            respondent: const Value('Bob'),
            courtId: Value(sampleCourtId),
            caseType: const Value('Civil'),
            onBehalfId: Value(sampleOnBehalfId),
          ),
        );

        final before = await caseRepo.getById(id);
        await caseRepo.deleteCase(before!);

        final after = await caseRepo.getById(id);
        expect(after, isNull);

        // Insert + delete on the same entity is compacted away entirely.
        final queue = await SyncQueueDao(db).getByEntity('case', id);
        expect(queue, isEmpty);
      },
    );

    test('NotesRepository pins and unpins a note', () async {
      final id = await notesRepo.insertNote(
        NotesCompanion(
          title: const Value('Important'),
          body: const Value('Details'),
        ),
      );

      await notesRepo.setPinned(id, true);
      var note = await notesRepo.getById(id);
      expect(note!.isPinned, true);

      await notesRepo.setPinned(id, false);
      note = await notesRepo.getById(id);
      expect(note!.isPinned, false);
    });

    test('ReferenceRepository search returns matching references', () async {
      await referenceRepo.insertReference(
        CaseReferencesCompanion(
          referenceAndPageNo: const Value('Ref 1'),
          titleAndDescription: const Value('Criminal Procedure'),
        ),
      );
      await referenceRepo.insertReference(
        CaseReferencesCompanion(
          referenceAndPageNo: const Value('Ref 2'),
          titleAndDescription: const Value('Civil Code'),
        ),
      );

      final results = await referenceRepo.search('criminal');
      expect(results, hasLength(1));
      expect(results.first.referenceAndPageNo, 'Ref 1');
    });

    test('CourtCategoriesRepository inserts with ownership flags', () async {
      final id = await courtCategoriesRepo.insert(
        CourtCategoriesCompanion(
          nameKey: const Value('custom_category'),
          courtLevel: const Value('lower'),
          orderIndex: const Value(1),
        ),
      );

      final category = await courtCategoriesRepo.getById(id);
      expect(category!.isCustom, true);
      expect(category.userId, isNotNull);
      expect(category.firmId, isNull);
    });

    test('CourtsRepository delete removes court from listing', () async {
      final categoryId = await courtCategoriesRepo.insert(
        CourtCategoriesCompanion(
          nameKey: const Value('test_category'),
          courtLevel: const Value('lower'),
          orderIndex: const Value(1),
        ),
      );

      final id = await courtsRepo.insert(
        CourtsCompanion(
          courtName: const Value('Test Court'),
          higherLowerCourts: const Value('lower_courts'),
          courtCategoryId: Value(categoryId),
        ),
      );

      final court = await courtsRepo.getById(id);
      await courtsRepo.delete(court!);

      final after = await courtsRepo.listAll();
      final stillThere = after.any((c) => c.id == id);
      expect(stillThere, isFalse);
    });

    test('SettingsRepository persists and retrieves settings', () async {
      await settingsRepo.upsertSettings(
        const UserSettings(
          language: 'bn',
          upcomingCasesPeriod: 14,
          notificationDefaultOffsets: [0, 1, 3],
          lastAddCaseHigherLowerCourt: lowerCourtsOption,
          lastAddCaseDivision: divisionDhakaId,
          lastAddCaseDistrict: 'dhaka',
        ),
      );

      final settings = await settingsRepo.getSettings();
      expect(settings.language, 'bn');
      expect(settings.upcomingCasesPeriod, 14);
      expect(settings.notificationDefaultOffsets, [0, 1, 3]);
      expect(settings.lastAddCaseHigherLowerCourt, lowerCourtsOption);
      expect(settings.lastAddCaseDivision, divisionDhakaId);
      expect(settings.lastAddCaseDistrict, 'dhaka');
      expect(settings.isPremium, false);
    });

    test(
      'SettingsRepository patches Add Case defaults without losing other settings',
      () async {
        await settingsRepo.upsertSettings(
          const UserSettings(language: 'bn', upcomingCasesPeriod: 14),
        );

        await settingsRepo.saveLastAddCaseSelection(
          higherLowerCourt: lowerCourtsOption,
          division: divisionDhakaId,
          district: 'dhaka',
        );

        final settings = await settingsRepo.getSettings();
        expect(settings.language, 'bn');
        expect(settings.upcomingCasesPeriod, 14);
        expect(settings.lastAddCaseHigherLowerCourt, lowerCourtsOption);
        expect(settings.lastAddCaseDivision, divisionDhakaId);
        expect(settings.lastAddCaseDistrict, 'dhaka');
      },
    );

    test('UserSettings falls back safely for malformed view JSON', () {
      final settings = UserSettings.fromRow(
        const UserPreference(
          userId: 'user-1',
          notificationEnabled: true,
          notificationDefaultOffsets: '[0, 3]',
          viewSettingsJson: '{not-json',
          updatedAt: 1,
        ),
      );

      expect(settings.bottomNavTabs, [
        'overdue',
        'daily_cause_list',
        'active',
        'upcoming',
      ]);
      expect(settings.notificationDefaultOffsets, [0, 3]);
    });

    test('queue ordering preserves dependency-then-created_at', () async {
      // Create a court category first, then a court. FK-safe ordering requires
      // the category queue entry before the court queue entry.
      final categoryId = await courtCategoriesRepo.insert(
        CourtCategoriesCompanion(
          nameKey: const Value('queue_category'),
          courtLevel: const Value('lower'),
          orderIndex: const Value(1),
        ),
      );

      final courtId = await courtsRepo.insert(
        CourtsCompanion(
          courtName: const Value('Queue Court'),
          higherLowerCourts: const Value('lower_courts'),
          courtCategoryId: Value(categoryId),
        ),
      );

      final queue = await SyncQueueDao(db).getAll();
      final categoryIndex = queue.indexWhere(
        (r) => r.entityType == 'court_category' && r.entityId == categoryId,
      );
      final courtIndex = queue.indexWhere(
        (r) => r.entityType == 'court' && r.entityId == courtId,
      );
      expect(categoryIndex, isNot(equals(-1)));
      expect(courtIndex, isNot(equals(-1)));
      expect(categoryIndex, lessThan(courtIndex));
      expect(
        queue[categoryIndex].createdAt,
        lessThanOrEqualTo(queue[courtIndex].createdAt),
      );
    });

    test('DeleteRequestsRepository creates a request', () async {
      final id = await deleteRequestsRepo.createRequest(
        entityType: 'case',
        entityId: 'case-123',
        entitySnapshot: <String, dynamic>{'id': 'case-123'},
        targetBaseVersion: 1,
      );

      final request = await deleteRequestsRepo.getById(id);
      expect(request, isNotNull);
      expect(request!.status, 'pending');
    });

    test('sync payload and changed_fields are snake_case', () async {
      final id = await caseRepo.insertCase(
        CasesCompanion(
          caseNumber: const Value('333/2025'),
          petitioner: const Value('Alice'),
          respondent: const Value('Bob'),
          courtId: Value(sampleCourtId),
          caseType: const Value('Civil'),
          onBehalfId: Value(sampleOnBehalfId),
        ),
      );

      final queue = await SyncQueueDao(db).getByEntity('case', id);
      expect(queue, hasLength(1));

      final row = queue.first;
      final payload = jsonDecode(row.payload) as Map<String, dynamic>;
      final changed = jsonDecode(row.changedFields) as List<dynamic>;

      expect(payload.keys, contains('case_number'));
      expect(payload.keys, contains('petitioner'));
      expect(payload.keys, contains('court_id'));
      expect(changed.cast<String>(), contains('case_number'));
      expect(changed.cast<String>(), contains('petitioner'));
      expect(changed.cast<String>(), isNot(contains('caseNumber')));
    });

    test('ordinary case update does not create history', () async {
      final id = await caseRepo.insertCase(
        CasesCompanion(
          caseNumber: const Value('443/2025'),
          petitioner: const Value('Alice'),
          respondent: const Value('Bob'),
          courtId: Value(sampleCourtId),
          caseType: const Value('Civil'),
          onBehalfId: Value(sampleOnBehalfId),
          nextDate: const Value(1000),
        ),
      );

      await caseRepo.updateCase(
        CasesCompanion(id: Value(id), nextDate: const Value(2000)),
      );

      expect(await historyDao.getByCaseId(id), isEmpty);
    });

    test('quick update on nextDate creates provisional history', () async {
      final id = await caseRepo.insertCase(
        CasesCompanion(
          caseNumber: const Value('444/2025'),
          petitioner: const Value('Alice'),
          respondent: const Value('Bob'),
          courtId: Value(sampleCourtId),
          caseType: const Value('Civil'),
          onBehalfId: Value(sampleOnBehalfId),
          nextDate: const Value(1000),
        ),
      );

      await caseRepo.updateCase(
        CasesCompanion(id: Value(id), nextDate: const Value(2000)),
        isQuickUpdate: true,
      );

      final history = await historyDao.getByCaseId(id);
      expect(history, hasLength(1));
      expect(history.first.nextDate, 2000);

      final queue = await SyncQueueDao(db).getAll();
      final caseHistoryRows = queue.where(
        (r) => r.entityType == 'case_history',
      );
      expect(caseHistoryRows, hasLength(1));
    });
    test(
      'On Behalf resolution never silently chooses among multiple roles',
      () async {
        final single = resolveOnBehalfSelection(
          options: [
            await onBehalfsDao
                .getById(sampleOnBehalfId)
                .then((value) => value!),
          ],
        );
        expect(single?.id, sampleOnBehalfId);

        final secondId = await onBehalfsRepo.insert(
          OnBehalfsCompanion(
            courtCategoryId: Value(sampleCourtCategoryId),
            name: const Value('Defendant'),
            orderIndex: const Value(2),
          ),
        );
        final options = await onBehalfsDao.getByCategory(sampleCourtCategoryId);
        expect(resolveOnBehalfSelection(options: options), isNull);
        expect(
          resolveOnBehalfSelection(
            options: options,
            selected: options.firstWhere((item) => item.id == secondId),
          )?.id,
          secondId,
        );
      },
    );

    test(
      'CaseFormRepository saves the case and notification preference atomically',
      () async {
        final formRepo = CaseFormRepository(db, caseRepo);
        final id = await formRepo.save(
          companion: CasesCompanion(
            caseNumber: const Value('446/2025'),
            petitioner: const Value('Alice'),
            respondent: const Value('Bob'),
            courtId: Value(sampleCourtId),
            caseType: const Value('Civil'),
            onBehalfId: Value(sampleOnBehalfId),
            nextDate: const Value(3000),
          ),
          initialCase: null,
          userId: syncHelper.currentUserId,
          notificationEnabled: false,
          notificationOffsets: const [0, 2],
          updatedAt: 3000,
        );

        expect(await casesDao.getById(id), isNotNull);
        final preference = await CaseNotificationPreferencesDao(
          db,
        ).get(syncHelper.currentUserId, id);
        expect(preference?.enabled, isFalse);
        expect(preference?.offsets, '[0,2]');
      },
    );

    test(
      'CaseFormRepository rolls back a new case when preference save fails',
      () async {
        final beforeCases = await casesDao.getAll();
        final beforeQueue = await SyncQueueDao(db).getAll();
        await db.customStatement('''
        CREATE TRIGGER fail_case_preference_insert
        BEFORE INSERT ON case_notification_preferences
        BEGIN
          SELECT RAISE(ABORT, 'intentional preference failure');
        END;
      ''');

        final formRepo = CaseFormRepository(db, caseRepo);
        await expectLater(
          formRepo.save(
            companion: CasesCompanion(
              caseNumber: const Value('447/2025'),
              petitioner: const Value('Alice'),
              respondent: const Value('Bob'),
              courtId: Value(sampleCourtId),
              caseType: const Value('Civil'),
              onBehalfId: Value(sampleOnBehalfId),
              nextDate: const Value(4000),
            ),
            initialCase: null,
            userId: syncHelper.currentUserId,
            notificationEnabled: true,
            notificationOffsets: const [1],
            updatedAt: 4000,
          ),
          throwsA(isA<Exception>()),
        );

        expect(await casesDao.getAll(), hasLength(beforeCases.length));
        expect(await SyncQueueDao(db).getAll(), hasLength(beforeQueue.length));
      },
    );

    test(
      'quick update rolls back case, history, and queue on history failure',
      () async {
        final id = await caseRepo.insertCase(
          CasesCompanion(
            caseNumber: const Value('445/2025'),
            petitioner: const Value('Alice'),
            respondent: const Value('Bob'),
            courtId: Value(sampleCourtId),
            caseType: const Value('Civil'),
            onBehalfId: Value(sampleOnBehalfId),
            nextDate: const Value(1000),
          ),
        );
        final beforeCase = await casesDao.getById(id);
        final beforeQueue = await SyncQueueDao(db).getByEntity('case', id);

        await db.customStatement('''
        CREATE TRIGGER fail_case_history_insert
        BEFORE INSERT ON case_history
        BEGIN
          SELECT RAISE(ABORT, 'intentional history failure');
        END;
      ''');

        await expectLater(
          caseRepo.updateCase(
            CasesCompanion(id: Value(id), nextDate: const Value(2000)),
            isQuickUpdate: true,
          ),
          throwsA(isA<Exception>()),
        );

        final afterCase = await casesDao.getById(id);
        expect(afterCase?.nextDate, beforeCase?.nextDate);
        expect(await historyDao.getByCaseId(id), isEmpty);
        expect(
          await SyncQueueDao(db).getByEntity('case', id),
          hasLength(beforeQueue.length),
        );
        final historyQueue = (await SyncQueueDao(
          db,
        ).getAll()).where((row) => row.entityType == 'case_history');
        expect(
          historyQueue.where((row) {
            final payload = jsonDecode(row.payload) as Map<String, dynamic>;
            return payload['case_id'] == id;
          }),
          isEmpty,
        );
      },
    );
  });
}
