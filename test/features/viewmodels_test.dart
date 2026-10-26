/// Unit tests for Phase 4 Riverpod ViewModels.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/case_reference/presentation/reference_viewmodel.dart';
import 'package:legal_case_diary/features/cases/presentation/case_viewmodel.dart';
import 'package:legal_case_diary/features/notes/presentation/notes_viewmodel.dart';
import 'package:legal_case_diary/features/settings/presentation/config_viewmodels.dart';
import 'package:legal_case_diary/features/settings/data/settings_repository.dart';
import 'package:legal_case_diary/features/settings/presentation/delete_requests_viewmodel.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_viewmodel.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/sync/sync_write_helper.dart';
import 'package:legal_case_diary/sync/sync_queue_dao.dart';

void main() {
  late AppDatabase db;
  late SyncWriteHelper syncHelper;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    final prefs = await SharedPreferences.getInstance();
    final identity = LocalIdentityService(prefs);
    syncHelper = SyncWriteHelper(SyncQueueDao(db), identity);

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) async => db),
        syncWriteHelperProvider.overrideWith((ref) async => syncHelper),
        localIdentityServiceProvider.overrideWith((ref) => identity),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('CaseViewModel', () {
    test('build returns empty state with zero counts', () async {
      final state = await container.read(caseViewModelProvider.future);
      expect(state.cases, isEmpty);
      expect(state.activeCount, 0);
      expect(state.nonDeletedCount, 0);
    });

    test('addCase refreshes the list', () async {
      final courtCategoriesRepo = await container.read(
        courtCategoriesRepositoryProvider.future,
      );
      final courtsRepo = await container.read(courtsRepositoryProvider.future);
      final onBehalfsRepo = await container.read(onBehalfsRepositoryProvider.future);

      final courtCategoryId = await courtCategoriesRepo.insert(CourtCategoriesCompanion(
        nameKey: const Value('test_category'),
        courtLevel: const Value('lower'),
        orderIndex: const Value(1),
      ));
      final courtId = await courtsRepo.insert(CourtsCompanion(
        courtName: const Value('Test Court'),
        higherLowerCourts: const Value('lower_courts'),
        courtCategoryId: Value(courtCategoryId),
      ));
      final onBehalfId = await onBehalfsRepo.insert(OnBehalfsCompanion(
        courtCategoryId: Value(courtCategoryId),
        name: const Value('Plaintiff'),
        orderIndex: const Value(1),
      ));

      final viewModel = container.read(caseViewModelProvider.notifier);
      await viewModel.addCase(CasesCompanion(
        caseNumber: const Value('1/2025'),
        petitioner: const Value('Alice'),
        respondent: const Value('Bob'),
        courtId: Value(courtId),
        caseType: const Value('Civil'),
        onBehalfId: Value(onBehalfId),
      ));

      final state = await container.read(caseViewModelProvider.future);
      expect(state.cases, hasLength(1));
      expect(state.cases.first.caseNumber, '1/2025');
      expect(state.nonDeletedCount, 1);
    });
  });

  group('NotesViewModel', () {
    test('build returns empty list', () async {
      final state = await container.read(notesViewModelProvider.future);
      expect(state.items, isEmpty);
    });

    test('addNote refreshes the list and toggles pin', () async {
      final viewModel = container.read(notesViewModelProvider.notifier);
      await viewModel.addNote(const NotesCompanion(
        title: Value('Reminder'),
        body: Value('Buy milk'),
      ));

      var state = await container.read(notesViewModelProvider.future);
      expect(state.items, hasLength(1));
      expect(state.items.first.title, 'Reminder');

      final noteId = state.items.first.id;
      await viewModel.setPinned(noteId, true);

      state = await container.read(notesViewModelProvider.future);
      expect(state.items.first.isPinned, true);
    });
  });

  group('ReferenceViewModel', () {
    test('build returns empty list', () async {
      final state = await container.read(referenceViewModelProvider.future);
      expect(state.items, isEmpty);
    });

    test('addReference refreshes the list', () async {
      final viewModel = container.read(referenceViewModelProvider.notifier);
      await viewModel.addReference(const CaseReferencesCompanion(
        referenceAndPageNo: Value('Ref 1'),
        titleAndDescription: Value('Important case law'),
      ));

      final state = await container.read(referenceViewModelProvider.future);
      expect(state.items, hasLength(1));
      expect(state.items.first.referenceAndPageNo, 'Ref 1');
    });
  });

  group('CourtCategoriesViewModel', () {
    test('build returns empty list', () async {
      final state = await container.read(courtCategoriesViewModelProvider.future);
      expect(state.items, isEmpty);
    });

    test('addCategory refreshes the list', () async {
      final viewModel = container.read(courtCategoriesViewModelProvider.notifier);
      await viewModel.addCategory(const CourtCategoriesCompanion(
        nameKey: Value('custom_category'),
        courtLevel: Value('lower'),
        orderIndex: Value(1),
      ));

      final state = await container.read(courtCategoriesViewModelProvider.future);
      expect(state.items, hasLength(1));
      expect(state.items.first.nameKey, 'custom_category');
    });
  });

  group('DeleteRequestsViewModel', () {
    test('createRequest refreshes the list', () async {
      final viewModel = container.read(deleteRequestsViewModelProvider.notifier);
      await viewModel.createRequest(
        entityType: 'case',
        entityId: 'case-123',
        entitySnapshot: const <String, dynamic>{'id': 'case-123'},
        targetBaseVersion: 1,
        firmId: 'firm-1',
        requesterName: 'Rekha',
      );

      final state = await container.read(deleteRequestsViewModelProvider.future);
      expect(state.items, hasLength(1));
      expect(state.items.first.entityType, 'case');
      expect(state.items.first.status, 'pending');
      expect(state.items.first.firmId, 'firm-1');
    });
  });

  group('SettingsViewModel', () {
    test('build returns default settings', () async {
      final settings = await container.read(settingsViewModelProvider.future);
      expect(settings.language, 'en');
      expect(settings.upcomingCasesPeriod, 7);
      expect(settings.isPremium, false);
    });

    test('saveSettings persists and refreshes', () async {
      final viewModel = container.read(settingsViewModelProvider.notifier);
      await viewModel.saveSettings(const UserSettings(
        language: 'bn',
        upcomingCasesPeriod: 14,
      ));

      final settings = await container.read(settingsViewModelProvider.future);
      expect(settings.language, 'bn');
      expect(settings.upcomingCasesPeriod, 14);
    });
  });
}
