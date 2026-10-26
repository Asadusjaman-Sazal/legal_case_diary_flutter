/// Unit tests for Phase 3 local repositories.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/constants/pre_seeded_data.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/core/utils/date_utils.dart'
    show AppDateUtils;
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

    // The admin payment-alert toggle is a per-user preference like the rest, and
    // the server reads its synced column for itself — so it has to survive both
    // the JSON blob and the row, and default to on for an install that has never
    // touched it.
    test('UserSettings carries the admin payment-alert toggle', () {
      expect(
        const UserSettings().paymentAlertsEnabled,
        isTrue,
        reason: 'an admin who never chose is alerted by default',
      );

      final restored = UserSettings.fromRow(
        UserPreference(
          userId: 'user-1',
          notificationEnabled: false,
          paymentAlertsEnabled: true,
          viewSettingsJson: jsonEncode(
            const UserSettings(paymentAlertsEnabled: false).toJson(),
          ),
          updatedAt: 1,
        ),
      );

      expect(
        restored.paymentAlertsEnabled,
        isFalse,
        reason: 'the saved value wins over the column it was saved beside',
      );
      expect(
        jsonDecode(jsonEncode(const UserSettings().toJson()))['payment_alerts_enabled'],
        isTrue,
        reason: 'the toggle travels in the blob the sync payload reads from',
      );
    });

    test('UserSettings carries the client-notification choices', () {
      const defaults = UserSettings();
      expect(defaults.automatedNotificationEnabled, isFalse);
      expect(defaults.automatedNotificationAskBeforeSending, isTrue);
      expect(
        defaults.automatedNotificationChannel,
        clientNotificationChannelWhatsApp,
      );
      expect(
        defaults.automatedNotificationWhatsAppTemplate,
        clientNotificationTemplateLong,
      );
      expect(
        defaults.automatedNotificationSmsTemplate,
        clientNotificationTemplateShort,
      );
      expect(defaults.notificationContactNumber, isEmpty);

      const saved = UserSettings(
        automatedNotificationEnabled: true,
        automatedNotificationAskBeforeSending: false,
        automatedNotificationChannel: clientNotificationChannelSms,
        automatedNotificationWhatsAppTemplate: clientNotificationTemplateShort,
        automatedNotificationSmsTemplate: clientNotificationTemplateLong,
        notificationContactNumber: '01800000000',
      );
      final restored = UserSettings.fromRow(
        UserPreference(
          userId: 'user-1',
          notificationEnabled: false,
          paymentAlertsEnabled: true,
          viewSettingsJson: jsonEncode(saved.toJson()),
          updatedAt: 1,
        ),
      );
      expect(restored.automatedNotificationEnabled, isTrue);
      expect(restored.automatedNotificationAskBeforeSending, isFalse);
      expect(
        restored.automatedNotificationChannel,
        clientNotificationChannelSms,
      );
      expect(
        restored.automatedNotificationWhatsAppTemplate,
        clientNotificationTemplateShort,
      );
      expect(
        restored.automatedNotificationSmsTemplate,
        clientNotificationTemplateLong,
      );
      expect(restored.notificationContactNumber, '01800000000');

      // Add Case's own save rebuilds every field by hand, so it must carry these.
      final afterAdd = saved.copyWithLastAddCaseSelection(
        higherLowerCourt: 'lower_courts',
        division: null,
        district: null,
      );
      expect(afterAdd.automatedNotificationEnabled, isTrue);
      expect(
        afterAdd.automatedNotificationChannel,
        clientNotificationChannelSms,
      );
      expect(afterAdd.notificationContactNumber, '01800000000');

      // An unknown or hand-edited blob reads as the safe defaults.
      final odd = UserSettings.fromRow(
        UserPreference(
          userId: 'user-1',
          notificationEnabled: false,
          paymentAlertsEnabled: true,
          viewSettingsJson: jsonEncode(<String, Object?>{
            'automated_notification_channel': 'telegraph',
            'automated_notification_whatsapp_template': 'epic',
            'notification_contact_number': '018-0000 0000',
          }),
          updatedAt: 1,
        ),
      );
      expect(
        odd.automatedNotificationChannel,
        clientNotificationChannelWhatsApp,
      );
      expect(
        odd.automatedNotificationWhatsAppTemplate,
        clientNotificationTemplateLong,
      );
      expect(odd.notificationContactNumber, '01800000000');
    });

    test('UserSettings round-trips the Bottom Navigation screen order', () {
      const saved = UserSettings(
        bottomNavTabs: <String>['active', 'all_cases'],
        bottomNavOrder: <String>['active', 'all_cases', 'notes'],
      );

      final restored = UserSettings.fromRow(
        UserPreference(
          userId: 'user-1',
          notificationEnabled: false,
          paymentAlertsEnabled: true,
          viewSettingsJson: jsonEncode(saved.toJson()),
          updatedAt: 1,
        ),
      );

      expect(restored.bottomNavTabs, saved.bottomNavTabs);
      expect(restored.bottomNavOrder, saved.bottomNavOrder);
      // An install that never rearranged a row stores no serial at all.
      expect(const UserSettings().bottomNavOrder, isEmpty);
    });

    test('UserSettings round-trips the extended view column widths', () {
      const saved = UserSettings(
        caseTableColumnWidths: <String, double>{'court': 260.5, 'note': 180},
      );

      final restored = UserSettings.fromRow(
        UserPreference(
          userId: 'user-1',
          notificationEnabled: false,
          paymentAlertsEnabled: true,
          viewSettingsJson: jsonEncode(saved.toJson()),
          updatedAt: 1,
        ),
      );

      expect(restored.caseTableColumnWidths, saved.caseTableColumnWidths);
      // An install that never dragged a column stores nothing, which the table
      // reads as "use the built-in defaults".
      expect(const UserSettings().caseTableColumnWidths, isEmpty);
    });

    test('UserSettings round-trips the per-screen view choice', () {
      const saved = UserSettings(
        caseListDisplayMode: 'compact',
        caseListDisplayModes: <String, String>{
          'all_cases': 'expanded',
          'overdue': 'compact',
        },
      );

      final restored = UserSettings.fromRow(
        UserPreference(
          userId: 'user-1',
          notificationEnabled: false,
          paymentAlertsEnabled: true,
          viewSettingsJson: jsonEncode(saved.toJson()),
          updatedAt: 1,
        ),
      );

      expect(restored.caseListDisplayMode, 'compact');
      expect(restored.caseListDisplayModes, saved.caseListDisplayModes);
      // An install that has never switched a screen stores no per-screen map,
      // so every screen follows the global mode.
      expect(const UserSettings().caseListDisplayModes, isEmpty);
    });

    test('UserSettings round-trips which day each screen was folded', () {
      const saved = UserSettings(
        caseTableCollapsedCourts: <String, List<String>>{
          'overdue': <String>['court-1', 'court-2'],
          'daily_cause_list': <String>['court-1'],
        },
        caseTableCollapsedDays: <String, int>{
          'overdue': 1758844800000,
          'daily_cause_list': 1758844800000,
        },
      );

      final restored = UserSettings.fromRow(
        UserPreference(
          userId: 'user-1',
          notificationEnabled: false,
          paymentAlertsEnabled: true,
          viewSettingsJson: jsonEncode(saved.toJson()),
          updatedAt: 1,
        ),
      );

      expect(restored.caseTableCollapsedCourts, saved.caseTableCollapsedCourts);
      expect(restored.caseTableCollapsedDays, saved.caseTableCollapsedDays);
      // An install that never folded a court stores no day either, which every
      // grouped screen reads as "all courts open".
      expect(const UserSettings().caseTableCollapsedDays, isEmpty);
    });

    test('UserSettings falls back safely for malformed view JSON', () {
      final settings = UserSettings.fromRow(
        const UserPreference(
          userId: 'user-1',
          notificationEnabled: true,
          paymentAlertsEnabled: true,
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
        firmId: 'firm-1',
        requesterName: 'Rekha',
      );

      final request = await deleteRequestsRepo.getById(id);
      expect(request, isNotNull);
      expect(request!.status, 'pending');
      // The request is firm-scoped by the RLS insert policy, so a null here is
      // a refused insert rather than "no firm" (Task 20 Phase 3).
      expect(request.firmId, 'firm-1');
      expect(request.requestedBy, isNotEmpty);
      // Who asked travels on the request itself, so a reviewer can read it
      // offline: the server derives this column, and the requester's own value
      // only stands until that first sync.
      expect(request.requesterName, 'Rekha');
      expect(request.entitySnapshot, '{"id":"case-123"}');
    });

    test(
      'a pending request re-snapshots into its single queued insert',
      () async {
        final id = await deleteRequestsRepo.createRequest(
          entityType: 'note',
          entityId: 'note-1',
          entitySnapshot: <String, dynamic>{'id': 'note-1', 'title': 'Old'},
          targetBaseVersion: 3,
          firmId: 'firm-1',
          requesterName: 'Rekha',
        );

        await deleteRequestsRepo.refreshSnapshot(
          id: id,
          entitySnapshot: <String, dynamic>{'id': 'note-1', 'title': 'New'},
          targetBaseVersion: 9,
        );

        final request = await deleteRequestsRepo.getById(id);
        expect(request!.targetBaseVersion, 9);
        expect(
          request.entitySnapshot,
          contains('New'),
          reason: 'the reviewer must read what is being deleted now',
        );

        final queue = await SyncQueueDao(db).getByEntity('delete_request', id);
        // Nothing was pushed, so the refresh compacts into the one queued insert
        // rather than an update to a row the server has never seen.
        expect(queue.single.operation, 'insert');
        expect(
          jsonDecode(queue.single.changedFields),
          contains('entity_snapshot'),
        );
      },
    );

    test('a request that was never pushed cancels away to nothing', () async {
      final id = await deleteRequestsRepo.createRequest(
        entityType: 'note',
        entityId: 'note-1',
        entitySnapshot: <String, dynamic>{'id': 'note-1'},
        targetBaseVersion: 1,
        firmId: 'firm-1',
        requesterName: 'Rekha',
      );

      await deleteRequestsRepo.cancel(id);

      expect(await deleteRequestsRepo.getById(id), isNull);
      // insert + delete is a row the server never needed to know about, so the
      // compaction matrix drops both rather than sending a create and a tombstone
      // for a request that never existed there.
      expect(await SyncQueueDao(db).getByEntity('delete_request', id), isEmpty);
    });

    test(
      'a synced request cancels as a tombstone, never a hard delete',
      () async {
        final id = await deleteRequestsRepo.createRequest(
          entityType: 'note',
          entityId: 'note-1',
          entitySnapshot: <String, dynamic>{'id': 'note-1'},
          targetBaseVersion: 1,
          firmId: 'firm-1',
          requesterName: 'Rekha',
        );
        // The server has seen it: the row is now a fact that must be withdrawn
        // rather than an unsent intention.
        await SyncQueueDao(db).resolve(
          (await SyncQueueDao(db).getByEntity('delete_request', id)).single.id,
        );

        await deleteRequestsRepo.cancel(id);

        // The resolved insert stays in the table as history, so the cancel is read
        // back from the still-open row it added rather than from the pair.
        final queue = (await SyncQueueDao(db).getByEntity(
          'delete_request',
          id,
        )).where((row) => row.state != 'resolved').toList(growable: false);
        expect(queue.single.operation, 'delete');
        final payload =
            jsonDecode(queue.single.payload) as Map<String, dynamic>;
        expect(payload['is_deleted'], isTrue);
      },
    );

    test('watchMine shows only the requester\'s own requests', () async {
      await deleteRequestsRepo.createRequest(
        entityType: 'note',
        entityId: 'note-mine',
        entitySnapshot: <String, dynamic>{'id': 'note-mine'},
        targetBaseVersion: 1,
        firmId: 'firm-1',
        requesterName: 'Rekha',
      );
      await DeleteRequestsDao(db).insert(
        DeleteRequestsCompanion(
          id: const Value('someone-elses'),
          firmId: const Value('firm-1'),
          entityType: const Value('note'),
          entityId: const Value('note-theirs'),
          entitySnapshot: const Value('{}'),
          targetBaseVersion: const Value(1),
          requestedBy: const Value('user-2'),
          status: const Value('pending'),
          createdAt: const Value(1),
          updatedAt: const Value(1),
        ),
      );

      final mine = await deleteRequestsRepo
          .watchMine(deleteRequestsRepo.currentUserId)
          .first;

      expect(mine, hasLength(1));
      expect(mine.single.entityId, 'note-mine');
    });

    test('approving a synced request queues one update', () async {
      final id = await deleteRequestsRepo.createRequest(
        entityType: 'note',
        entityId: 'note-1',
        entitySnapshot: <String, dynamic>{'id': 'note-1'},
        targetBaseVersion: 1,
        firmId: 'firm-1',
        requesterName: 'Rekha',
      );
      // The server has seen the request, so the decision is an update against
      // the version it holds rather than a rewrite of an unsent intention.
      await SyncQueueDao(db).resolve(
        (await SyncQueueDao(db).getByEntity('delete_request', id)).single.id,
      );

      await deleteRequestsRepo.approve(id, reviewNote: 'Verified the record.');

      final request = await deleteRequestsRepo.getById(id);
      expect(request!.status, 'approved');
      expect(request.reviewNote, 'Verified the record.');
      expect(request.reviewedBy, deleteRequestsRepo.currentUserId);

      final queue = (await SyncQueueDao(db).getByEntity(
        'delete_request',
        id,
      )).where((row) => row.state != 'resolved').toList(growable: false);
      expect(queue, hasLength(1));
      expect(queue.single.operation, 'update');
      expect(queue.single.baseVersion, request.version);
      final payload =
          jsonDecode(queue.single.payload) as Map<String, dynamic>;
      // The one field `push_changes` reads to know a decision was made.
      expect(payload['status'], 'approved');
      expect(payload['review_note'], 'Verified the record.');
    });

    test('a request that was already decided is left alone', () async {
      final id = await deleteRequestsRepo.createRequest(
        entityType: 'note',
        entityId: 'note-1',
        entitySnapshot: <String, dynamic>{'id': 'note-1'},
        targetBaseVersion: 1,
        firmId: 'firm-1',
        requesterName: 'Rekha',
      );

      await deleteRequestsRepo.approve(id);
      final queueAfterApprove = (await SyncQueueDao(db).getByEntity(
        'delete_request',
        id,
      )).length;

      await deleteRequestsRepo.reject(id, reviewNote: 'Changed my mind.');

      final request = await deleteRequestsRepo.getById(id);
      expect(
        request!.status,
        'approved',
        reason: 'a decision is audit history, not something to overwrite',
      );
      expect(request.reviewNote, isNull);
      expect(
        (await SyncQueueDao(db).getByEntity('delete_request', id)),
        hasLength(queueAfterApprove),
      );
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
          notificationTimeMinutes: 9 * 60,
          updatedAt: 3000,
        );

        expect(await casesDao.getById(id), isNotNull);
        final preference = await CaseNotificationPreferencesDao(
          db,
        ).get(syncHelper.currentUserId, id);
        expect(preference?.enabled, isFalse);
        expect(preference?.offsets, '[0,2]');
        // The per-case Notification Time rides the same atomic write.
        expect(preference?.timeMinutes, 9 * 60);
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

    test('countAllByNextDate spans all dates; countByNextDateRange is month-scoped',
        () async {
      final now = DateTime.now();
      final thisMonthMs = AppDateUtils.normalizeToBangladeshStartOfDay(
        DateTime(now.year, now.month, 15).millisecondsSinceEpoch,
      );
      final nextMonthMs = AppDateUtils.normalizeToBangladeshStartOfDay(
        DateTime(now.year, now.month + 1, 15).millisecondsSinceEpoch,
      );

      await caseRepo.insertCase(
        CasesCompanion(
          caseNumber: const Value('A/2025'),
          petitioner: const Value('P1'),
          respondent: const Value('R1'),
          courtId: Value(sampleCourtId),
          caseType: const Value('Civil'),
          onBehalfId: Value(sampleOnBehalfId),
          nextDate: Value(thisMonthMs),
        ),
      );
      await caseRepo.insertCase(
        CasesCompanion(
          caseNumber: const Value('B/2025'),
          petitioner: const Value('P2'),
          respondent: const Value('R2'),
          courtId: Value(sampleCourtId),
          caseType: const Value('Civil'),
          onBehalfId: Value(sampleOnBehalfId),
          nextDate: Value(nextMonthMs),
        ),
      );

      final all = await casesDao.countAllByNextDate();
      // Both months counted together.
      expect(all.values.fold(0, (s, c) => s + c), 2);

      final monthStart = AppDateUtils.normalizeToBangladeshStartOfDay(
        DateTime(now.year, now.month, 1).millisecondsSinceEpoch,
      );
      final monthEnd = AppDateUtils.normalizeToBangladeshStartOfDay(
            DateTime(now.year, now.month + 1, 1).millisecondsSinceEpoch,
          ) -
          1;
      final scoped = await casesDao.countByNextDateRange(monthStart, monthEnd);
      // Only the focused month counted.
      expect(scoped.values.fold(0, (s, c) => s + c), 1);
    });
  });
}
