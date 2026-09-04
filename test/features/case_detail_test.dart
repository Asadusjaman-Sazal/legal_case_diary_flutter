/// Widget tests for the Task 10 case detail screen.
///
/// Each test runs against an in-memory Drift database with the production
/// repository chain overridden, so the screen exercises the real data path.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/core/utils/date_utils.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/cases/data/case_repository.dart';
import 'package:legal_case_diary/features/cases/data/local/case_history_dao.dart';
import 'package:legal_case_diary/features/cases/data/local/cases_dao.dart';
import 'package:legal_case_diary/features/cases/presentation/case_detail/case_detail_screen.dart';
import 'package:legal_case_diary/features/settings/data/local/user_preferences_dao.dart';
import 'package:legal_case_diary/features/settings/data/settings_repository.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:legal_case_diary/shared/widgets/add_edit_case_sheet.dart';
import 'package:legal_case_diary/sync/sync_queue_dao.dart';
import 'package:legal_case_diary/sync/sync_write_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CaseDetailScreen Phase 1', () {
    late AppDatabase db;
    late SharedPreferences prefs;
    late LocalIdentityService identity;
    late LocalCaseRepository caseRepository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      identity = LocalIdentityService(prefs);
      db = AppDatabase(NativeDatabase.memory());
      final syncHelper = SyncWriteHelper(SyncQueueDao(db), identity);
      caseRepository = LocalCaseRepository(
        CasesDao(db),
        CaseHistoryDao(db),
        syncHelper,
      );
      await _seedReferenceRows(db);
    });

    tearDown(() async => db.close());

    // -----------------------------------------------------------------------
    // Harness helpers
    // -----------------------------------------------------------------------

    SettingsRepository settingsRepository() =>
        LocalSettingsRepository(UserPreferencesDao(db), identity);

    ProviderScope appScope(Widget child, {bool canEdit = true}) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWith((_) async => db),
          syncWriteHelperProvider.overrideWith((_) async => SyncWriteHelper(
                SyncQueueDao(db),
                identity,
              )),
          localIdentityServiceProvider.overrideWith((_) => identity),
          caseRepositoryProvider.overrideWith((_) async => caseRepository),
          transactionalCaseRepositoryProvider.overrideWith(
            (_) async => caseRepository,
          ),
          settingsRepositoryProvider.overrideWith(
            (_) async => settingsRepository(),
          ),
          caseWritePermissionsProvider.overrideWith(
            (_) async => CaseWritePermissions(canAdd: true, canEdit: canEdit),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: child,
        ),
      );
    }

    Future<void> pumpDetail(
      WidgetTester tester,
      String caseId, {
      bool canEdit = true,
    }) async {
      // Tall viewport so the whole detail list builds without scrolling.
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        appScope(CaseDetailScreen(caseId: caseId), canEdit: canEdit),
      );
      await tester.pumpAndSettle();
    }

    Future<String> seedCase({
      String roleId = 'onbehalf-test-respondent',
      String? partyPhone = '+8801711000000',
      int? nextDateMs,
    }) async {
      await db.into(db.onBehalfs).insert(
        OnBehalfsCompanion(
          id: Value(roleId),
          courtCategoryId: const Value('test-category'),
          name: Value(
            roleId.endsWith('respondent') ? 'Respondent' : 'Petitioner',
          ),
          orderIndex: const Value(1),
          updatedAt: const Value(1),
        ),
      );
      return caseRepository.insertCase(
        CasesCompanion(
          caseNumber: const Value('423/2023'),
          caseType: const Value('Civil Suit'),
          petitioner: const Value('Md. Rahim Uddin'),
          respondent: const Value('Bangladesh Government'),
          petitionerLeadCounsel: const Value('Adv. Abdul Kalam'),
          respondentLeadCounsel: const Value('Adv. Ahsan Habib'),
          courtId: const Value('court-test'),
          onBehalfId: Value(roleId),
          partyPhone: Value(partyPhone),
          caseTitleAndSection: const Value('Partition Suit (Title)'),
          caseRemarks: const Value('Dispute over ancestral property.'),
          nextDate: Value(nextDateMs),
        ),
      );
    }

    Future<void> seedHistoryEntry(
      String caseId, {
      required int hearingEpochMs,
      required int nextEpochMs,
      String? step,
      String? note,
    }) async {
      await CaseHistoryDao(db).insertHistoryEntry(
        CaseHistoryCompanion(
          id: Value('history-$nextEpochMs-$hearingEpochMs'),
          caseId: Value(caseId),
          userId: Value(identity.getId()),
          hearingDate: Value(hearingEpochMs),
          lastStep: Value(step),
          nextDate: Value(nextEpochMs),
          noteResult: Value(note),
          createdBy: Value(identity.getId()),
          sourceMutationId: Value('mutation-$nextEpochMs-$hearingEpochMs'),
          baseCaseVersion: const Value(0),
          resultCaseVersion: const Value(1),
          updatedAt: const Value(1),
        ),
      );
    }

    Finder phoneIn(Key partyKey) => find.descendant(
      of: find.byKey(partyKey),
      matching: find.byKey(const ValueKey('case-detail-party-phone')),
    );

    testWidgets('renders header, parties, description, history and Next Date card', (
      WidgetTester tester,
    ) async {
      final nextMs = AppDateUtils.bangladeshTodayStartOfDay() + 5 * 86400000;
      final caseId = await seedCase(nextDateMs: nextMs);
      await seedHistoryEntry(
        caseId,
        hearingEpochMs: AppDateUtils.bangladeshCivilDateEpoch(2026, 10, 15),
        nextEpochMs: AppDateUtils.bangladeshCivilDateEpoch(2026, 11, 20),
        step: 'Steps for Hearing',
        note: 'Adjourned due to absence of witness.',
      );
      await seedHistoryEntry(
        caseId,
        hearingEpochMs: AppDateUtils.bangladeshCivilDateEpoch(2026, 9, 12),
        nextEpochMs: AppDateUtils.bangladeshCivilDateEpoch(2026, 10, 15),
        step: 'Written Objection',
        note: 'Respondent submitted written objection.',
      );

      await pumpDetail(tester, caseId);

      // L1 + L2 + L3.
      expect(find.text('Civil Suit 423/2023'), findsOneWidget);
      expect(
        find.text('Joint District Judge, 2nd Court, Dhaka'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('case-detail-delete')), findsOneWidget);
      expect(find.byKey(const ValueKey('case-detail-edit')), findsOneWidget);
      expect(find.byKey(const ValueKey('case-detail-close')), findsOneWidget);

      // L4 parties card.
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('case-detail-on-behalf-role')))
            .data,
        'Respondent',
      );
      expect(find.text('Md. Rahim Uddin'), findsOneWidget);
      expect(find.text('Bangladesh Government'), findsOneWidget);
      expect(find.text('Lead Counsel: Adv. Abdul Kalam'), findsOneWidget);
      expect(find.text('Lead Counsel: Adv. Ahsan Habib'), findsOneWidget);

      // The single stored phone belongs to the represented party (respondent).
      expect(phoneIn(const ValueKey('case-detail-party-petitioner')), findsNothing);
      expect(phoneIn(const ValueKey('case-detail-party-respondent')), findsOneWidget);
      expect(find.text('+8801711000000'), findsOneWidget);

      // L5 description: section labels plus their boxed content.
      expect(find.text('Sections or Case Title'), findsOneWidget);
      expect(find.text('Partition Suit (Title)'), findsOneWidget);
      expect(find.text('Remarks or Case Summary'), findsOneWidget);
      expect(find.text('Dispute over ancestral property.'), findsOneWidget);

      // L6 history (2 total, newest nextDate first).
      expect(find.text('2 Entries Total'), findsOneWidget);
      expect(find.text('15 Oct 2026'), findsOneWidget);
      expect(find.text('12 Sep 2026'), findsOneWidget);
      expect(find.text('Written Objection'), findsOneWidget);

      // Next Date highlight card + countdown.
      expect(find.byKey(const ValueKey('case-detail-next-date-card')), findsOneWidget);
      expect(find.text('5 Days Remaining'), findsOneWidget);
      expect(find.byKey(const ValueKey('case-detail-set-reminder')), findsOneWidget);
    });

    testWidgets('places the client phone under the petitioner for petitioner-side roles', (
      WidgetTester tester,
    ) async {
      final caseId = await seedCase(
        roleId: 'onbehalf-test-petitioner',
        nextDateMs: AppDateUtils.bangladeshTodayStartOfDay() + 10 * 86400000,
      );
      await pumpDetail(tester, caseId);

      expect(find.text('10 Days Remaining'), findsOneWidget);
      expect(phoneIn(const ValueKey('case-detail-party-petitioner')), findsOneWidget);
      expect(phoneIn(const ValueKey('case-detail-party-respondent')), findsNothing);
    });

    testWidgets('hides the phone when the role side is unknown and hides card without a date', (
      WidgetTester tester,
    ) async {
      final caseId = await seedCase(
        roleId: 'onbehalf-test-mojhor', // ambiguous -> no phone.
        nextDateMs: null,
      );
      await pumpDetail(tester, caseId);

      expect(phoneIn(const ValueKey('case-detail-party-petitioner')), findsNothing);
      expect(phoneIn(const ValueKey('case-detail-party-respondent')), findsNothing);
      expect(find.byKey(const ValueKey('case-detail-next-date-card')), findsNothing);
      expect(find.text('No history entries yet.'), findsOneWidget);
    });

    testWidgets('shows 3 entries plus the View All toggle and expands on tap', (
      WidgetTester tester,
    ) async {
      final caseId = await seedCase(nextDateMs: null);
      for (var i = 1; i <= 4; i++) {
        await seedHistoryEntry(
          caseId,
          hearingEpochMs: AppDateUtils.bangladeshCivilDateEpoch(2026, 1, i),
          nextEpochMs: AppDateUtils.bangladeshCivilDateEpoch(2026, 2, i),
          step: 'Step $i',
        );
      }
      await pumpDetail(tester, caseId);

      expect(find.text('4 Entries Total'), findsOneWidget);
      expect(find.text('View All 4 History Entries'), findsOneWidget);
      expect(find.text('Step 1'), findsNothing); // oldest sits beyond the cap.
      expect(find.text('Step 4'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('case-detail-history-view-all')));
      await tester.pumpAndSettle();
      expect(find.text('View All 4 History Entries'), findsNothing);
      expect(find.text('Step 4'), findsOneWidget);
      expect(find.text('Step 1'), findsOneWidget);
    });

    testWidgets('Delete soft-deletes the case after confirmation and pops', (
      WidgetTester tester,
    ) async {
      final caseId = await seedCase(nextDateMs: null);
      await tester.pumpWidget(
        appScope(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CaseDetailScreen(caseId: caseId),
                    ),
                  ),
                  child: const Text('open-detail'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open-detail'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('case-detail-delete')));
      await tester.pumpAndSettle();
      expect(find.text('Confirm Delete'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('case-detail-delete-confirm')));
      await tester.pumpAndSettle();

      expect(find.byType(CaseDetailScreen), findsNothing);
      expect(find.text('open-detail'), findsOneWidget);
      expect(await caseRepository.getById(caseId), isNull);
    });

    testWidgets('Edit Case opens the Add/Edit sheet in edit mode', (
      WidgetTester tester,
    ) async {
      final caseId = await seedCase(nextDateMs: null);
      await pumpDetail(tester, caseId);

      await tester.tap(find.byKey(const ValueKey('case-detail-edit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('add-edit-header')), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('add-edit-header')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('case-detail-close')), findsOneWidget);
    });

    testWidgets('long-press offers Edit/Delete and Delete removes the entry', (
      WidgetTester tester,
    ) async {
      final caseId = await seedCase(nextDateMs: null);
      final hearingMs = AppDateUtils.bangladeshCivilDateEpoch(2026, 1, 10);
      final nextMs = AppDateUtils.bangladeshCivilDateEpoch(2026, 2, 15);
      await seedHistoryEntry(
        caseId,
        hearingEpochMs: hearingMs,
        nextEpochMs: nextMs,
        step: 'Written Objection',
        note: 'Old note.',
      );
      await pumpDetail(tester, caseId);

      final entryKey = ValueKey('case-detail-history-entry-history-$nextMs-$hearingMs');
      expect(find.byKey(entryKey), findsOneWidget);
      expect(find.text('Old note.'), findsOneWidget);

      await tester.longPress(find.byKey(entryKey));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('history-action-edit')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('history-action-delete')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('history-action-delete')));
      await tester.pumpAndSettle();
      expect(find.text('Confirm Delete'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('history-delete-confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(entryKey), findsNothing);
      expect(find.text('0 Entries Total'), findsOneWidget);
      expect(find.text('No history entries yet.'), findsOneWidget);
      final removed = await CaseHistoryDao(db).getById(
        'history-$nextMs-$hearingMs',
      );
      expect(removed, isNull);
    });

    testWidgets('long-press Edit saves updated date/step/note fields', (
      WidgetTester tester,
    ) async {
      final caseId = await seedCase(nextDateMs: null);
      final hearingMs = AppDateUtils.bangladeshCivilDateEpoch(2026, 1, 10);
      final nextMs = AppDateUtils.bangladeshCivilDateEpoch(2026, 2, 15);
      final entryId = 'history-$nextMs-$hearingMs';
      await seedHistoryEntry(
        caseId,
        hearingEpochMs: hearingMs,
        nextEpochMs: nextMs,
        step: 'Written Objection',
        note: 'Adjourned.',
      );
      // A step for the case's court category, so the Edit dialog renders the
      // category-filtered step selector with the stored step preselected.
      await db.into(db.steps).insert(
        const StepsCompanion(
          id: Value('step-written-objection'),
          courtCategoryId: Value('test-category'),
          stepName: Value('Written Objection'),
          orderIndex: Value(1),
          updatedAt: Value(1),
        ),
      );
      await pumpDetail(tester, caseId);
      expect(find.text('Adjourned.'), findsOneWidget);

      await tester.longPress(
        find.byKey(ValueKey('case-detail-history-entry-$entryId')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('history-action-edit')));
      await tester.pumpAndSettle();

      expect(find.text('Edit History Entry'), findsOneWidget);
      expect(find.byKey(const ValueKey('history-edit-save')), findsOneWidget);
      // Steps are filtered by the case's court category; the stored step is
      // reselected from the seeded list.
      expect(find.byKey(const ValueKey('history-edit-step')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Written Objection'),
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('history-edit-note')),
        'Heard and adjourned.',
      );
      await tester.tap(find.byKey(const ValueKey('history-edit-save')));
      await tester.pumpAndSettle();

      expect(find.text('Heard and adjourned.'), findsOneWidget);
      expect(find.text('Adjourned.'), findsNothing);
      final edited = await CaseHistoryDao(db).getById(entryId);
      expect(edited, isNotNull);
      expect(edited!.noteResult, 'Heard and adjourned.');
      expect(edited.lastStep, 'Written Objection');
    });

    testWidgets('long-press is inert for read-only members', (
      WidgetTester tester,
    ) async {
      final caseId = await seedCase(nextDateMs: null);
      final hearingMs = AppDateUtils.bangladeshCivilDateEpoch(2026, 1, 10);
      final nextMs = AppDateUtils.bangladeshCivilDateEpoch(2026, 2, 15);
      await seedHistoryEntry(
        caseId,
        hearingEpochMs: hearingMs,
        nextEpochMs: nextMs,
        step: 'Written Objection',
      );
      await pumpDetail(tester, caseId, canEdit: false);

      await tester.longPress(
        find.byKey(ValueKey('case-detail-history-entry-history-$nextMs-$hearingMs')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('history-action-edit')), findsNothing);
      expect(find.byKey(const ValueKey('history-action-delete')), findsNothing);
    });
  });
}

// ---------------------------------------------------------------------------
// Seed helpers
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
      courtName: Value('Joint District Judge, 2nd Court, Dhaka'),
      higherLowerCourts: Value('lower_courts'),
      courtCategoryId: Value('test-category'),
      orderIndex: Value(0),
      updatedAt: Value(1),
    ),
  );
}
