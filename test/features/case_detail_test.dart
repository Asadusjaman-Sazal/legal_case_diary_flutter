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
import 'package:legal_case_diary/core/constants/pre_seeded_data.dart';
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

    ProviderScope appScope(
      Widget child, {
      bool canEdit = true,
      Locale locale = const Locale('en'),
    }) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWith((_) async => db),
          syncWriteHelperProvider.overrideWith(
            (_) async => SyncWriteHelper(SyncQueueDao(db), identity),
          ),
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
          locale: locale,
          home: child,
        ),
      );
    }

    Future<void> pumpDetail(
      WidgetTester tester,
      String caseId, {
      bool canEdit = true,
      Locale locale = const Locale('en'),
    }) async {
      // Tall viewport so the whole detail list builds without scrolling.
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        appScope(
          CaseDetailScreen(caseId: caseId),
          canEdit: canEdit,
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<String> seedCase({
      String roleId = 'onbehalf-test-respondent',
      String? partyPhone = '+8801711000000',
      int? nextDateMs,
      String courtId = 'court-test',
      String caseType = 'Civil Suit',
      String? lastStep,
      String? honorableJudges,
      String? tenderNumber,
      String? previousCourtCase,
      String? districtOfOrigin,
    }) async {
      await db
          .into(db.onBehalfs)
          .insert(
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
          caseType: Value(caseType),
          lastStep: Value(lastStep),
          petitioner: const Value('Md. Rahim Uddin'),
          respondent: const Value('Bangladesh Government'),
          petitionerLeadCounsel: const Value('Adv. Abdul Kalam'),
          respondentLeadCounsel: const Value('Adv. Ahsan Habib'),
          courtId: Value(courtId),
          onBehalfId: Value(roleId),
          partyPhone: Value(partyPhone),
          caseTitleAndSection: const Value('Partition Suit (Title)'),
          caseRemarks: const Value('Dispute over ancestral property.'),
          nextDate: Value(nextDateMs),
          honorableJudges: Value(honorableJudges),
          tenderNumber: Value(tenderNumber),
          previousCourtCase: Value(previousCourtCase),
          districtOfOrigin: Value(districtOfOrigin),
        ),
      );
    }

    Future<void> seedHistoryEntry(
      String caseId, {
      required int hearingEpochMs,
      required int nextEpochMs,
      String? step,
      String? note,
      String? result,
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
          result: Value(result),
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

    testWidgets(
      'renders header, parties, description, history and Next Date card',
      (WidgetTester tester) async {
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
        expect(
          find.byKey(const ValueKey('case-detail-delete')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('case-detail-edit')), findsOneWidget);
        expect(find.byKey(const ValueKey('case-detail-close')), findsOneWidget);

        // L4 parties card.
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('case-detail-on-behalf-role')),
              )
              .data,
          'Respondent',
        );
        expect(find.text('Md. Rahim Uddin'), findsOneWidget);
        expect(find.text('Bangladesh Government'), findsOneWidget);
        expect(find.text('Lead Counsel: Adv. Abdul Kalam'), findsOneWidget);
        expect(find.text('Lead Counsel: Adv. Ahsan Habib'), findsOneWidget);

        // The single stored phone belongs to the represented party (respondent).
        expect(
          phoneIn(const ValueKey('case-detail-party-petitioner')),
          findsNothing,
        );
        expect(
          phoneIn(const ValueKey('case-detail-party-respondent')),
          findsOneWidget,
        );
        expect(find.text('+8801711000000'), findsOneWidget);

        // L5 description: section labels plus their boxed content.
        expect(find.text('Sections or Case Title'), findsOneWidget);
        expect(find.text('Partition Suit (Title)'), findsOneWidget);
        expect(find.text('Remarks or Case Summary'), findsOneWidget);
        expect(find.text('Dispute over ancestral property.'), findsOneWidget);

        // L6 history (2 total, newest date first): DD/MM/YYYY date with the
        // day of the week under it, step content on the right.
        expect(find.text('2 Entries Total'), findsOneWidget);
        // Fewer than 3 entries: no Show/Hide toggle in the title row.
        expect(
          find.byKey(const ValueKey('case-detail-history-show-hide')),
          findsNothing,
        );
        expect(find.text('15/10/2026'), findsOneWidget);
        expect(find.text('12/09/2026'), findsOneWidget);
        expect(find.text('THU'), findsOneWidget); // 15 Oct 2026
        expect(find.text('SAT'), findsOneWidget); // 12 Sep 2026
        expect(find.text('Written Objection'), findsOneWidget);
        // Weekday sits centered under the date; Step and Note both read left
        // aligned (Google Keep style) across the full content width.
        final weekdayAlign = tester.widget<Align>(
          find.ancestor(of: find.text('THU'), matching: find.byType(Align)),
        );
        expect(weekdayAlign.alignment, Alignment.center);
        expect(
          tester.widget<Text>(find.text('Written Objection')).textAlign,
          TextAlign.left,
        );
        expect(
          tester
              .widget<Text>(
                find.text('Respondent submitted written objection.'),
              )
              .textAlign,
          TextAlign.left,
        );

        // Next Date highlight card + countdown.
        expect(
          find.byKey(const ValueKey('case-detail-next-date-card')),
          findsOneWidget,
        );
        expect(find.text('5 Days Remaining'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('case-detail-set-reminder')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'places the client phone under the petitioner for petitioner-side roles',
      (WidgetTester tester) async {
        final caseId = await seedCase(
          roleId: 'onbehalf-test-petitioner',
          nextDateMs: AppDateUtils.bangladeshTodayStartOfDay() + 10 * 86400000,
        );
        await pumpDetail(tester, caseId);

        expect(find.text('10 Days Remaining'), findsOneWidget);
        expect(
          phoneIn(const ValueKey('case-detail-party-petitioner')),
          findsOneWidget,
        );
        expect(
          phoneIn(const ValueKey('case-detail-party-respondent')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'hides the phone when the role side is unknown and hides card without a date',
      (WidgetTester tester) async {
        final caseId = await seedCase(
          roleId: 'onbehalf-test-mojhor', // ambiguous -> no phone.
          nextDateMs: null,
        );
        await pumpDetail(tester, caseId);

        expect(
          phoneIn(const ValueKey('case-detail-party-petitioner')),
          findsNothing,
        );
        expect(
          phoneIn(const ValueKey('case-detail-party-respondent')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('case-detail-next-date-card')),
          findsNothing,
        );
        expect(find.text('No history entries yet.'), findsOneWidget);
      },
    );

    testWidgets('shows 3 entries and Show expands the list on tap', (
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
      // Collapsed title row offers the Show toggle and no separate expander.
      expect(find.text('Show'), findsOneWidget);
      expect(find.text('Hide'), findsNothing);
      expect(
        find.byKey(const ValueKey('case-detail-history-view-all')),
        findsNothing,
      );
      expect(find.text('Step 1'), findsNothing); // oldest sits beyond the cap.
      expect(find.text('Step 4'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('case-detail-history-show-hide')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Step 4'), findsOneWidget);
      expect(find.text('Step 1'), findsOneWidget);
      // Expanded: the Case History title is pinned to the top and the toggle
      // now reads Hide.
      expect(find.byType(PinnedHeaderSliver), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PinnedHeaderSliver),
          matching: find.text('Case History'),
        ),
        findsOneWidget,
      );
      expect(find.text('Hide'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('case-detail-history-show-hide')),
      );
      await tester.pumpAndSettle();
      // Folded back: no pin, Show toggle returns, entries capped at 3 again.
      expect(find.byType(PinnedHeaderSliver), findsNothing);
      expect(find.text('Show'), findsOneWidget);
      expect(find.text('Hide'), findsNothing);
      expect(find.text('Step 1'), findsNothing);
    });

    testWidgets(
      'Show expands every entry and Hide folds back to 3 with a pinned title only while expanded',
      (WidgetTester tester) async {
        final caseId = await seedCase(nextDateMs: null);
        for (var i = 1; i <= 5; i++) {
          await seedHistoryEntry(
            caseId,
            hearingEpochMs: AppDateUtils.bangladeshCivilDateEpoch(2026, 1, i),
            nextEpochMs: AppDateUtils.bangladeshCivilDateEpoch(2026, 2, i),
            step: 'Step $i',
          );
        }
        await pumpDetail(tester, caseId);

        // Collapsed default: Show button, newest 3 entries only, no pin.
        expect(find.text('Show'), findsOneWidget);
        expect(find.text('Hide'), findsNothing);
        expect(find.byType(PinnedHeaderSliver), findsNothing);
        expect(find.text('Step 5'), findsOneWidget);
        expect(find.text('Step 3'), findsOneWidget);
        expect(find.text('Step 2'), findsNothing);
        expect(find.text('Step 1'), findsNothing);

        await tester.tap(
          find.byKey(const ValueKey('case-detail-history-show-hide')),
        );
        await tester.pumpAndSettle();

        // Expanded: all entries render and the Case History title (with entry
        // count + Hide) is pinned at the top.
        expect(find.text('Hide'), findsOneWidget);
        expect(find.text('Show'), findsNothing);
        expect(find.text('Step 1'), findsOneWidget);
        expect(find.text('5 Entries Total'), findsOneWidget);
        expect(find.byType(PinnedHeaderSliver), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(PinnedHeaderSliver),
            matching: find.text('5 Entries Total'),
          ),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('case-detail-history-show-hide')),
        );
        await tester.pumpAndSettle();

        // Hidden again: title is no longer sticky and the cap returns.
        expect(find.byType(PinnedHeaderSliver), findsNothing);
        expect(find.text('Show'), findsOneWidget);
        expect(find.text('Step 1'), findsNothing);
      },
    );

    testWidgets('history Step/Result text uses the Note size but stays bold', (
      WidgetTester tester,
    ) async {
      final caseId = await seedCase(nextDateMs: null);
      final hearingMs = AppDateUtils.bangladeshCivilDateEpoch(2026, 1, 10);
      final nextMs = AppDateUtils.bangladeshCivilDateEpoch(2026, 2, 15);
      await seedHistoryEntry(
        caseId,
        hearingEpochMs: hearingMs,
        nextEpochMs: nextMs,
        step: 'Steps for Hearing',
        note: 'Adjourned for witness.',
      );
      await pumpDetail(tester, caseId);

      final stepStyle = tester
          .widget<Text>(find.text('Steps for Hearing'))
          .style!;
      final noteStyle = tester
          .widget<Text>(find.text('Adjourned for witness.'))
          .style!;
      // Same size/line-height as the Note content...
      expect(stepStyle.fontSize, noteStyle.fontSize);
      expect(stepStyle.height, noteStyle.height);
      // ...but still bold; both Step and Note read left aligned.
      expect(stepStyle.fontWeight, FontWeight.w600);
      expect(noteStyle.fontWeight, FontWeight.w400);
      expect(
        tester.widget<Text>(find.text('Steps for Hearing')).textAlign,
        TextAlign.left,
      );
      expect(
        tester.widget<Text>(find.text('Adjourned for witness.')).textAlign,
        TextAlign.left,
      );
    });

    testWidgets(
      'orders history rows newest-first by the date shown on each row',
      (WidgetTester tester) async {
        final caseId = await seedCase(nextDateMs: null);
        // Hearing on 10/01/2026 set a next date far ahead (15/03/2026); a later
        // quick update pulled the diary back to 05/02/2026. Sorting by the stored
        // next-date would float the older 10/01 row above the 20/02 row, so the
        // section must order by each row's own displayed date instead.
        await seedHistoryEntry(
          caseId,
          hearingEpochMs: AppDateUtils.bangladeshCivilDateEpoch(2026, 1, 10),
          nextEpochMs: AppDateUtils.bangladeshCivilDateEpoch(2026, 3, 15),
          step: 'Older Hearing',
        );
        await seedHistoryEntry(
          caseId,
          hearingEpochMs: AppDateUtils.bangladeshCivilDateEpoch(2026, 2, 20),
          nextEpochMs: AppDateUtils.bangladeshCivilDateEpoch(2026, 2, 5),
          step: 'Newer Hearing',
        );
        await pumpDetail(tester, caseId);

        expect(find.text('20/02/2026'), findsOneWidget);
        expect(find.text('10/01/2026'), findsOneWidget);
        // The 20/02/2026 hearing (newer) renders above the 10/01/2026 one even
        // though its stored next-date (05/02/2026) is older than 15/03/2026.
        expect(
          tester.getTopLeft(find.text('Newer Hearing')).dy,
          lessThan(tester.getTopLeft(find.text('Older Hearing')).dy),
        );
      },
    );

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

      await tester.tap(_deleteConfirmButton());
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

      final entryKey = ValueKey(
        'case-detail-history-entry-history-$nextMs-$hearingMs',
      );
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

      await tester.tap(_deleteConfirmButton());
      await tester.pumpAndSettle();

      expect(find.byKey(entryKey), findsNothing);
      expect(find.text('0 Entries Total'), findsOneWidget);
      expect(find.text('No history entries yet.'), findsOneWidget);
      final removed = await CaseHistoryDao(
        db,
      ).getById('history-$nextMs-$hearingMs');
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
      await db
          .into(db.steps)
          .insert(
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
        find.byKey(
          ValueKey('case-detail-history-entry-history-$nextMs-$hearingMs'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('history-action-edit')), findsNothing);
      expect(find.byKey(const ValueKey('history-action-delete')), findsNothing);
    });

    testWidgets(
      'AD/HCD case shows the judges line and the Other Information card',
      (WidgetTester tester) async {
        // Appellate Division court so the screen treats the case as AD/HCD.
        await db
            .into(db.courtCategories)
            .insert(
              const CourtCategoriesCompanion(
                id: Value(appellateDivisionId),
                nameKey: Value('courtCategory_appellateDivision'),
                courtLevel: Value('higher'),
                orderIndex: Value(0),
                updatedAt: Value(1),
              ),
            );
        await db
            .into(db.courts)
            .insert(
              const CourtsCompanion(
                id: Value('court-ad'),
                courtName: Value('Appellate Division'),
                higherLowerCourts: Value(higherCourtsOption),
                courtCategoryId: Value(appellateDivisionId),
                orderIndex: Value(0),
                updatedAt: Value(1),
              ),
            );
        final caseId = await seedCase(
          courtId: 'court-ad',
          honorableJudges: 'Justice Md. Abu Taher',
          tenderNumber: 'T-2026/045',
          previousCourtCase: 'Case No. 88/2020',
          districtOfOrigin: 'Chattogram',
        );
        await pumpDetail(tester, caseId);

        // Judges line sits under the court name in the title area.
        expect(
          find.byKey(const ValueKey('case-detail-judges')),
          findsOneWidget,
        );
        expect(find.text('Justice Md. Abu Taher'), findsOneWidget);

        // Other Information card between Case Title & Remark and Case History.
        expect(
          find.byKey(const ValueKey('case-detail-other-information')),
          findsOneWidget,
        );
        expect(find.text('Tender Number'), findsOneWidget);
        expect(find.text('T-2026/045'), findsOneWidget);
        expect(find.text('Previous Court Case'), findsOneWidget);
        expect(find.text('Case No. 88/2020'), findsOneWidget);
        expect(find.text('District of Origin'), findsOneWidget);
        expect(find.text('Chattogram'), findsOneWidget);
      },
    );

    testWidgets('the header shows the case type in the active language', (
      WidgetTester tester,
    ) async {
      await db
          .into(db.courtCategories)
          .insert(
            const CourtCategoriesCompanion(
              id: Value(appellateDivisionId),
              nameKey: Value('courtCategory_appellateDivision'),
              courtLevel: Value('higher'),
              orderIndex: Value(0),
              updatedAt: Value(1),
            ),
          );
      await db
          .into(db.courts)
          .insert(
            const CourtsCompanion(
              id: Value('court-ad'),
              courtName: Value('Appellate Division'),
              higherLowerCourts: Value(higherCourtsOption),
              courtCategoryId: Value(appellateDivisionId),
              orderIndex: Value(0),
              updatedAt: Value(1),
            ),
          );
      // `cases.case_type` stores the case type's name, not its stable ID, so
      // the screen has to map it back to show it in Bengali.
      const caseTypeName = 'Civil Appeal-';
      final caseId = await seedCase(
        courtId: 'court-ad',
        caseType: caseTypeName,
      );
      await pumpDetail(tester, caseId, locale: const Locale('bn'));

      final bengali =
          caseTypeLabelBnByCourtCategory[appellateDivisionId]![caseTypeName]!;
      expect(bengali, isNot(caseTypeName));
      expect(find.text('$bengali 423/2023'), findsOneWidget);
      expect(find.text('$caseTypeName 423/2023'), findsNothing);
    });
    testWidgets('steps are shown in the active language', (
      WidgetTester tester,
    ) async {
      // `lastStep` stores step *names*, here the pre-seeded English ones.
      final caseId = await seedCase(
        courtId: 'court-test',
        lastStep: 'Arrival',
        nextDateMs: AppDateUtils.bangladeshTodayStartOfDay() + 86400000,
      );
      await seedHistoryEntry(
        caseId,
        hearingEpochMs: AppDateUtils.bangladeshTodayStartOfDay(),
        nextEpochMs: AppDateUtils.bangladeshTodayStartOfDay() + 86400000,
        step: 'Filing',
      );
      await pumpDetail(tester, caseId, locale: const Locale('bn'));

      // The Next Date card's step line and the history row's step.
      expect(find.text(stepLabelBnByToken['Arrival']!), findsOneWidget);
      expect(find.text(stepLabelBnByToken['Filing']!), findsOneWidget);
      expect(find.text('Arrival'), findsNothing);
      expect(find.text('Filing'), findsNothing);
    });

    testWidgets(
      'a history step stored as an ID resolves, typed text does not',
      (WidgetTester tester) async {
        // Rows written by older builds can hold a step's stable ID, which must
        // still resolve to the language the app is showing.
        final arrivalId = stepLabelEn.entries
            .firstWhere((entry) => entry.value == 'Arrival')
            .key;
        final caseId = await seedCase(
          courtId: 'court-test',
          lastStep: arrivalId,
        );
        await seedHistoryEntry(
          caseId,
          hearingEpochMs: AppDateUtils.bangladeshTodayStartOfDay(),
          nextEpochMs: AppDateUtils.bangladeshTodayStartOfDay() + 86400000,
          step: arrivalId,
        );
        // A step name the user typed themselves is shown exactly as typed.
        const typedStep = 'পরীক্ষামূলক ধাপ';
        await seedHistoryEntry(
          caseId,
          hearingEpochMs: AppDateUtils.bangladeshTodayStartOfDay() - 86400000,
          nextEpochMs: AppDateUtils.bangladeshTodayStartOfDay(),
          step: typedStep,
        );
        await pumpDetail(tester, caseId, locale: const Locale('bn'));

        expect(find.text(stepLabelBnByToken[arrivalId]!), findsOneWidget);
        expect(find.text(typedStep), findsOneWidget); // user text untouched.
        expect(find.text(arrivalId), findsNothing);
      },
    );

    testWidgets('the history entry count uses Bengali numerals', (
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
      await pumpDetail(tester, caseId, locale: const Locale('bn'));

      expect(find.text('মোট ৪ টি এন্ট্রি'), findsOneWidget);
      expect(find.text('মোট 4 টি এন্ট্রি'), findsNothing);
      expect(find.text('দেখুন'), findsOneWidget);
    });

    testWidgets(
      'AD/HCD history rows show the hearing Result like lower-court Step rows',
      (WidgetTester tester) async {
        await db
            .into(db.courtCategories)
            .insert(
              const CourtCategoriesCompanion(
                id: Value(appellateDivisionId),
                nameKey: Value('courtCategory_appellateDivision'),
                courtLevel: Value('higher'),
                orderIndex: Value(0),
                updatedAt: Value(1),
              ),
            );
        await db
            .into(db.courts)
            .insert(
              const CourtsCompanion(
                id: Value('court-ad'),
                courtName: Value('Appellate Division'),
                higherLowerCourts: Value(higherCourtsOption),
                courtCategoryId: Value(appellateDivisionId),
                orderIndex: Value(0),
                updatedAt: Value(1),
              ),
            );
        final caseId = await seedCase(courtId: 'court-ad');
        await seedHistoryEntry(
          caseId,
          hearingEpochMs: AppDateUtils.bangladeshCivilDateEpoch(2026, 10, 15),
          nextEpochMs: AppDateUtils.bangladeshCivilDateEpoch(2026, 11, 20),
          result: 'Rule discharged',
          note: 'Full bench heard the matter.',
        );
        // AD/HCD rows must render the Result snapshot, never a stored Step.
        await seedHistoryEntry(
          caseId,
          hearingEpochMs: AppDateUtils.bangladeshCivilDateEpoch(2026, 9, 12),
          nextEpochMs: AppDateUtils.bangladeshCivilDateEpoch(2026, 10, 15),
          step: 'Steps for Hearing',
          result: 'Adjourned',
        );

        await pumpDetail(tester, caseId);

        expect(find.text('Rule discharged'), findsOneWidget);
        expect(find.text('Full bench heard the matter.'), findsOneWidget);
        expect(find.text('Adjourned'), findsOneWidget);
        expect(find.text('Steps for Hearing'), findsNothing);
      },
    );

    testWidgets(
      'lower-court case hides the judges line and the Other Information card',
      (WidgetTester tester) async {
        // Even with AD/HCD fields populated, a lower-court case must not render
        // the AD/HCD-only sections; the gate is the court category.
        final caseId = await seedCase(
          honorableJudges: 'Justice Md. Abu Taher',
          tenderNumber: 'T-2026/045',
          previousCourtCase: 'Case No. 88/2020',
          districtOfOrigin: 'Chattogram',
        );
        await pumpDetail(tester, caseId);

        expect(find.byKey(const ValueKey('case-detail-judges')), findsNothing);
        expect(find.text('Justice Md. Abu Taher'), findsNothing);
        expect(
          find.byKey(const ValueKey('case-detail-other-information')),
          findsNothing,
        );
        expect(find.text('Tender Number'), findsNothing);
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Finders
// ---------------------------------------------------------------------------

/// Delete button of the app-wide confirmation dialog (`confirmDeleteDialog`).
Finder _deleteConfirmButton() => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.widgetWithText(FilledButton, 'Delete'),
);

// ---------------------------------------------------------------------------
// Seed helpers
// ---------------------------------------------------------------------------

Future<void> _seedReferenceRows(AppDatabase db) async {
  await db
      .into(db.courtCategories)
      .insert(
        const CourtCategoriesCompanion(
          id: Value('test-category'),
          nameKey: Value('test_category'),
          courtLevel: Value('lower'),
          orderIndex: Value(1),
          updatedAt: Value(1),
        ),
      );
  await db
      .into(db.courts)
      .insert(
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
