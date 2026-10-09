/// Case-list search tests.
///
/// Every case screen carried the header search icon from Task 06, but until
/// 0.0.195 each one passed `onSearch: () {}` — an inert button. These tests pin
/// the shared shell opening the scoped search bar, the shared matcher covering
/// the plan §12.1 field set, and each screen applying the query to *its own*
/// dataset only (so the same query means something different on the Active and
/// the Overdue list, exactly as the plan requires).
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/constants/pre_seeded_data.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/core/utils/date_utils.dart';
import 'package:legal_case_diary/core/utils/on_behalf_side.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/cases/data/case_repository.dart';
import 'package:legal_case_diary/features/cases/data/case_search_scope.dart';
import 'package:legal_case_diary/features/cases/data/local/case_history_dao.dart';
import 'package:legal_case_diary/features/cases/data/local/cases_dao.dart';
import 'package:legal_case_diary/features/cases/presentation/active_cases/active_cases_screen.dart';
import 'package:legal_case_diary/features/cases/presentation/all_cases/all_cases_screen.dart';
import 'package:legal_case_diary/features/cases/presentation/daily_cause_list/daily_cause_list_screen.dart';
import 'package:legal_case_diary/features/cases/presentation/disposed_cases/disposed_cases_screen.dart';
import 'package:legal_case_diary/features/cases/presentation/overdue_dates/overdue_dates_screen.dart';
import 'package:legal_case_diary/features/cases/presentation/upcoming_cases/upcoming_cases_screen.dart';
import 'package:legal_case_diary/features/settings/data/local/user_preferences_dao.dart';
import 'package:legal_case_diary/features/settings/data/settings_repository.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:legal_case_diary/shared/widgets/add_edit_case_sheet.dart';
import 'package:legal_case_diary/shared/widgets/case_card.dart';
import 'package:legal_case_diary/sync/sync_queue_dao.dart';
import 'package:legal_case_diary/sync/sync_write_helper.dart';

void main() {
  const dayMs = 86400000;
  const courtId = 'search-court';
  const roleId = 'search-role';

  late AppDatabase db;
  late SharedPreferences prefs;
  late LocalIdentityService identity;
  late LocalCaseRepository caseRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    identity = LocalIdentityService(prefs);
    db = AppDatabase(NativeDatabase.memory());
    caseRepository = LocalCaseRepository(
      CasesDao(db),
      CaseHistoryDao(db),
      SyncWriteHelper(SyncQueueDao(db), identity),
    );

    await db
        .into(db.courtCategories)
        .insert(
          const CourtCategoriesCompanion(
            id: Value('search-category'),
            nameKey: Value('courtCategory_districtCourtsCivil'),
            courtLevel: Value('lower'),
            orderIndex: Value(1),
            updatedAt: Value(1),
          ),
        );
    await db
        .into(db.courts)
        .insert(
          const CourtsCompanion(
            id: Value(courtId),
            courtName: Value('Joint District Judge, 2nd Court, Dhaka'),
            higherLowerCourts: Value('lower_courts'),
            courtCategoryId: Value('search-category'),
            orderIndex: Value(0),
            updatedAt: Value(1),
          ),
        );
    await db
        .into(db.onBehalfs)
        .insert(
          const OnBehalfsCompanion(
            id: Value(roleId),
            courtCategoryId: Value('search-category'),
            name: Value('Petitioner'),
            orderIndex: Value(1),
            updatedAt: Value(1),
          ),
        );
  });

  tearDown(() async => db.close());

  /// Seeds one case on the given Bangladesh civil date.
  Future<String> seedCase({
    required String caseNumber,
    required String petitioner,
    required String respondent,
    required int nextDate,
    String? step,
    String? petitionerLeadCounsel,
    String? respondentLeadCounsel,
    String? partyPhone,
    String? titleAndSection,
    String? remarks,
  }) => caseRepository.insertCase(
    CasesCompanion(
      caseNumber: Value(caseNumber),
      caseType: const Value('Civil Suit'),
      courtId: const Value(courtId),
      onBehalfId: const Value(roleId),
      petitioner: Value(petitioner),
      respondent: Value(respondent),
      petitionerLeadCounsel: Value(petitionerLeadCounsel),
      respondentLeadCounsel: Value(respondentLeadCounsel),
      partyPhone: Value(partyPhone),
      caseTitleAndSection: Value(titleAndSection),
      caseRemarks: Value(remarks),
      lastStep: Value(step),
      nextDate: Value(nextDate),
    ),
  );

  /// One case per screen dataset, so every list has rows of its own to filter:
  /// `SRH-1`/`SRH-2` are upcoming and active, `SRH-4` is today's hearing,
  /// `SRH-3`/`SRH-6` are disposed and overdue, `SRH-5` is overdue only.
  Future<Map<String, String>> seedDatasets() async {
    final today = AppDateUtils.bangladeshTodayStartOfDay();
    final disposedStep = disposedStepNames.first;
    return {
      'Rahim': await seedCase(
        caseNumber: 'SRH-1',
        petitioner: 'Md. Rahim Uddin',
        respondent: 'Bangladesh Government',
        step: 'Arrival',
        nextDate: today + 2 * dayMs,
      ),
      'Karim': await seedCase(
        caseNumber: 'SRH-2',
        petitioner: 'Karim Ahmed',
        respondent: 'State',
        step: 'Arrival',
        nextDate: today + 3 * dayMs,
      ),
      'Disposed': await seedCase(
        caseNumber: 'SRH-3',
        petitioner: 'Disposed Party',
        respondent: 'State',
        step: disposedStep,
        nextDate: today - 2 * dayMs,
      ),
      'Today': await seedCase(
        caseNumber: 'SRH-4',
        petitioner: 'Today Only',
        respondent: 'City Corporation',
        step: 'Arrival',
        nextDate: today,
      ),
      'TodayToo': await seedCase(
        caseNumber: 'SRH-7',
        petitioner: 'Another Hearing',
        respondent: 'City Corporation',
        step: 'Arrival',
        nextDate: today,
      ),
      'Stale': await seedCase(
        caseNumber: 'SRH-5',
        petitioner: 'Stale Matter',
        respondent: 'State',
        step: 'Arrival',
        nextDate: today - 5 * dayMs,
      ),
      'OldPending': await seedCase(
        caseNumber: 'SRH-8',
        petitioner: 'Old Pending Matter',
        respondent: 'State',
        step: 'Arrival',
        nextDate: today - 7 * dayMs,
      ),
      'Closed': await seedCase(
        caseNumber: 'SRH-6',
        petitioner: 'Closed Matter',
        respondent: 'State',
        step: disposedStep,
        nextDate: today - 1 * dayMs,
      ),
    };
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget Function() screen, {
    Locale locale = const Locale('en'),
  }) async {
    // A tall viewport, so the lazily-built lists render every seeded card: a
    // "must be hidden" assertion would otherwise pass merely because the card
    // was never built.
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (context, state) => screen())],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWith((_) async => db),
          caseRepositoryProvider.overrideWith((_) async => caseRepository),
          transactionalCaseRepositoryProvider.overrideWith(
            (_) async => caseRepository,
          ),
          localIdentityServiceProvider.overrideWith((_) => identity),
          settingsRepositoryProvider.overrideWith(
            (_) async =>
                LocalSettingsRepository(UserPreferencesDao(db), identity),
          ),
          caseWritePermissionsProvider.overrideWith(
            (_) async =>
                const CaseWritePermissions(canAdd: true, canEdit: true),
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Unmounts before the test ends so no screen timer outlives the body.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// The screen's own `AppLocalizations`, for the localized tooltips/labels.
  AppLocalizations stringsOf(WidgetTester tester, Finder screen) =>
      AppLocalizations.of(tester.element(screen));

  /// Types [query] into the open search bar and settles.
  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pumpAndSettle();
  }

  group('CasesDao.searchScoped', () {
    late CasesDao dao;
    setUp(() => dao = CasesDao(db));

    test('every searchable field is matched, case-insensitively', () async {
      final today = AppDateUtils.bangladeshTodayStartOfDay();
      await seedCase(
        caseNumber: '110/2021',
        petitioner: 'Md. Rahim Uddin',
        respondent: 'Bangladesh Government',
        petitionerLeadCounsel: 'Adv. Karim',
        respondentLeadCounsel: 'Adv. Salam',
        partyPhone: '01812332721',
        titleAndSection: 'Section 138, N.I. Act',
        remarks: 'Settlement talks ongoing',
        nextDate: today,
      );

      // The plan §12.1 field set: case number, both parties, both lead
      // counsels, the party phone, the case title/section and the remarks.
      for (final query in <String>[
        '110/2021',
        'rahim',
        'GOVERNMENT',
        'KARIM',
        'salam',
        '181233',
        '138',
        'taLks',
      ]) {
        expect(await dao.searchScoped(query), hasLength(1), reason: query);
      }

      // A query that matches nothing stays empty: the NULL columns cannot
      // swallow the whole predicate and let every row through.
      expect(await dao.searchScoped('zzz'), isEmpty);
      expect(await dao.searchScoped('n.i. act'), hasLength(1));
      expect(await dao.searchScoped('salam karim'), isEmpty);
    });

    test('the represented party is resolved through on_behalf_id', () async {
      final today = AppDateUtils.bangladeshTodayStartOfDay();
      await seedCase(
        caseNumber: '110/2021',
        petitioner: 'Md. Rahim Uddin',
        respondent: 'Bangladesh Government',
        nextDate: today,
      );

      // The role row's own label is searchable through the reference the case
      // stores, so "who is the client" is reachable by name.
      expect(await dao.searchScoped('petitioner'), hasLength(1));

      OnBehalf role(String id, String name) => OnBehalf(
        id: id,
        courtCategoryId: 'search-category',
        name: name,
        orderIndex: 1,
        isCustom: false,
        isUserModified: false,
        updatedAt: 1,
        isDeleted: false,
      );

      final clientCase = (await dao.getAll()).single;
      expect(
        representedClientName(clientCase, role(roleId, 'Petitioner')),
        'Md. Rahim Uddin',
      );
      // Acting for the respondent names the respondent — the bug this rule
      // exists to prevent.
      expect(
        representedClientName(
          clientCase,
          role('search-role-respondent', 'Respondent'),
        ),
        'Bangladesh Government',
      );
      // A custom or missing role resolves to nothing rather than guessing.
      expect(representedSideOf(role('custom-role', 'বাদী')), isNull);
      expect(representedSideOf(null), isNull);
    });

    test('the dataset predicate decides what a query can reach', () async {
      final today = AppDateUtils.bangladeshTodayStartOfDay();
      await seedCase(
        caseNumber: 'ACT-1',
        petitioner: 'Active Matter',
        respondent: 'State',
        step: 'Arrival',
        nextDate: today + 2 * dayMs,
      );
      await seedCase(
        caseNumber: 'DIS-1',
        petitioner: 'Disposed Matter',
        respondent: 'State',
        step: disposedStepNames.first,
        nextDate: today - 2 * dayMs,
      );
      await seedCase(
        caseNumber: 'FUT-1',
        petitioner: 'Distant Matter',
        respondent: 'State',
        step: 'Arrival',
        nextDate: today + 60 * dayMs,
      );

      // "matter" is in all three: only the screen's own scope decides which
      // of them that screen can see.
      expect(await dao.searchScoped('matter'), hasLength(3));
      expect(
        await dao.searchScoped(
          'matter',
          scope: const CaseSearchScope(disposal: CaseSearchDisposal.activeOnly),
        ),
        hasLength(2),
      );
      expect(
        await dao.searchScoped(
          'matter',
          scope: const CaseSearchScope(
            disposal: CaseSearchDisposal.disposedOnly,
          ),
        ),
        hasLength(1),
      );
      // The upcoming window is tomorrow through tomorrow + 7 days.
      expect(
        await dao.searchScoped(
          'matter',
          scope: CaseSearchScope(
            disposal: CaseSearchDisposal.activeOnly,
            nextDateStart: today + dayMs,
            nextDateEnd: today + 8 * dayMs - 1,
          ),
        ),
        hasLength(1),
      );
      // The overdue window is everything before today, active only.
      expect(
        await dao.searchScoped(
          'matter',
          scope: CaseSearchScope(
            disposal: CaseSearchDisposal.activeOnly,
            nextDateStart: 0,
            nextDateEnd: today - 1,
          ),
        ),
        isEmpty,
      );
    });

    test('soft-deleted rows are excluded and paging is honoured', () async {
      final today = AppDateUtils.bangladeshTodayStartOfDay();
      final ids = <String>[];
      for (var index = 0; index < 3; index++) {
        ids.add(
          await seedCase(
            caseNumber: 'PAG-$index',
            petitioner: 'Paged Party',
            respondent: 'State',
            nextDate: today,
          ),
        );
      }
      await caseRepository.deleteCase(
        (await caseRepository.getById(ids.first))!,
      );

      expect(await dao.searchScoped('paged'), hasLength(2));
      expect(await dao.searchScoped('paged', limit: 1), hasLength(1));
      expect(
        await dao.searchScoped('paged', limit: 1, offset: 1),
        hasLength(1),
      );
      expect(await dao.searchScoped('paged', limit: 1, offset: 5), isEmpty);
    });
  });

  testWidgets('the search bar queries the database, not just the loaded rows', (
    tester,
  ) async {
    await seedDatasets();
    await pumpScreen(tester, AllCasesScreen.new);

    // A case saved after this screen loaded: an in-memory filter over the
    // loaded rows cannot see it, a Drift query can — which is the whole point
    // of running the search through the DAO (plan §12.1).
    final late = await seedCase(
      caseNumber: 'SRH-9',
      petitioner: 'Late Arrival Party',
      respondent: 'State',
      step: 'Arrival',
      nextDate: AppDateUtils.bangladeshTodayStartOfDay() + 4 * dayMs,
    );

    final l = stringsOf(tester, find.byType(AllCasesScreen));
    await tester.tap(find.byTooltip(l.casesModal_search));
    await tester.pumpAndSettle();
    await search(tester, 'late arrival');

    expect(find.byKey(ValueKey('case-card-$late')), findsOneWidget);

    // Closing the bar restores the screen's own dataset.
    await tester.tap(find.byTooltip(l.sharedActions_close));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('case-card-$late')), findsNothing);

    await unmount(tester);
  });

  testWidgets('the search icon opens the bar and filters the list', (
    tester,
  ) async {
    final ids = await seedDatasets();
    await pumpScreen(tester, AllCasesScreen.new);

    final l = stringsOf(tester, find.byType(AllCasesScreen));
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(ValueKey('case-card-${ids['Rahim']}')), findsOneWidget);
    expect(find.byKey(ValueKey('case-card-${ids['Karim']}')), findsOneWidget);

    await tester.tap(find.byTooltip(l.casesModal_search));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    // The (x) is on screen before a single letter is typed, so the search can
    // be closed at any time.
    expect(find.byTooltip(l.sharedActions_close), findsOneWidget);

    await search(tester, 'rahim');
    expect(find.byKey(ValueKey('case-card-${ids['Rahim']}')), findsOneWidget);
    expect(find.byKey(ValueKey('case-card-${ids['Karim']}')), findsNothing);

    // The (x) closes the bar, taking the query with it.
    await tester.tap(find.byTooltip(l.sharedActions_close));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(ValueKey('case-card-${ids['Karim']}')), findsOneWidget);

    // The header icon still opens the bar and closes it too.
    await tester.tap(find.byTooltip(l.casesModal_search));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.byTooltip(l.casesModal_search).first);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(ValueKey('case-card-${ids['Karim']}')), findsOneWidget);

    await unmount(tester);
  });

  testWidgets(
    'a touch outside the open bar hides the keyboard, keeping it open',
    (tester) async {
      final ids = await seedDatasets();
      await pumpScreen(tester, AllCasesScreen.new);

      final l = stringsOf(tester, find.byType(AllCasesScreen));
      await tester.tap(find.byTooltip(l.casesModal_search));
      await tester.pumpAndSettle();
      await search(tester, 'rahim');

      // A touch on mobile does not drop focus by itself, so the field has to do
      // it: without the screen's own handler the keyboard would stay up.
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.focusNode.hasFocus, isTrue);

      // Touch the header title — anything but the field itself.
      await tester.tapAt(const Offset(200, 28));
      await tester.pumpAndSettle();

      expect(field.focusNode.hasFocus, isFalse);
      // The search is still open and still filtering.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byKey(ValueKey('case-card-${ids['Rahim']}')), findsOneWidget);
      expect(find.byKey(ValueKey('case-card-${ids['Karim']}')), findsNothing);

      await unmount(tester);
    },
  );

  testWidgets('a query that matches nothing says so instead of looking empty', (
    tester,
  ) async {
    await seedDatasets();
    await pumpScreen(tester, AllCasesScreen.new);

    final l = stringsOf(tester, find.byType(AllCasesScreen));
    await tester.tap(find.byTooltip(l.casesModal_search));
    await tester.pumpAndSettle();
    await search(tester, 'nothing matches this');

    expect(find.text(l.sharedDialogs_noResults), findsOneWidget);
    expect(find.byType(CaseCard), findsNothing);

    await unmount(tester);
  });

  testWidgets('each screen searches only its own dataset', (tester) async {
    final ids = await seedDatasets();

    // (screen, screen type, query, the case it must still list, a case it must
    // hide because it belongs to another screen's dataset.)
    final datasets = <(Widget Function(), Type, String, String?, String?)>[
      (AllCasesScreen.new, AllCasesScreen, 'rahim', ids['Rahim'], ids['Karim']),
      (
        ActiveCasesScreen.new,
        ActiveCasesScreen,
        'karim',
        ids['Karim'],
        ids['Rahim'],
      ),
      (
        UpcomingCasesScreen.new,
        UpcomingCasesScreen,
        'rahim',
        ids['Rahim'],
        ids['Karim'],
      ),
      // Both are past-dated and active: the disposed past cases are kept
      // off this screen by the date-range query, so they cannot be the
      // case the query hides.
      (
        OverdueDatesScreen.new,
        OverdueDatesScreen,
        'stale',
        ids['Stale'],
        ids['OldPending'],
      ),
      // SRH-3 and SRH-6 are both disposed; SRH-5 is not, so it cannot be
      // the case this query hides.
      (
        DisposedCasesScreen.new,
        DisposedCasesScreen,
        'disposed party',
        ids['Disposed'],
        ids['Closed'],
      ),
      // Only SRH-4 and SRH-7 have a hearing today.
      (
        DailyCauseListScreen.new,
        DailyCauseListScreen,
        'today',
        ids['Today'],
        ids['TodayToo'],
      ),
    ];

    for (final (build, screenType, query, visibleId, hiddenId) in datasets) {
      await pumpScreen(tester, build);
      final l = stringsOf(tester, find.byType(screenType));

      // Guard: both cases belong to this screen's dataset and are on screen
      // before the query, so the negative assertion below means something.
      expect(
        find.byKey(ValueKey('case-card-$hiddenId')),
        findsOneWidget,
        reason: '$screenType: the case to be filtered out is listed first',
      );

      await tester.tap(find.byTooltip(l.casesModal_search));
      await tester.pumpAndSettle();
      await search(tester, query);

      expect(
        find.byKey(ValueKey('case-card-$visibleId')),
        findsOneWidget,
        reason: 'a case of this screen\'s own dataset must match "$query"',
      );
      expect(
        find.byKey(ValueKey('case-card-$hiddenId')),
        findsNothing,
        reason: 'the query is scoped to this screen\'s dataset',
      );

      // Close the bar again so the next screen starts clean.
      await tester.tap(find.byTooltip(l.casesModal_search).first);
      await tester.pumpAndSettle();
    }

    await unmount(tester);
  });

  testWidgets('an empty case list can still be pulled down to sync', (
    tester,
  ) async {
    // No cases seeded, so every one of these screens renders its empty state.
    // The empty state used to be a bare `Center`, which is not a scrollable, so
    // there was nothing to drag and pull-to-sync silently did not exist.
    for (final screen in <Widget Function()>[
      AllCasesScreen.new,
      ActiveCasesScreen.new,
      UpcomingCasesScreen.new,
      OverdueDatesScreen.new,
      DisposedCasesScreen.new,
      DailyCauseListScreen.new,
    ]) {
      await pumpScreen(tester, screen);
      expect(
        find.byType(RefreshIndicator),
        findsOneWidget,
        reason: '$screen offered no pull-to-sync while empty',
      );
      await unmount(tester);
    }
  });

  testWidgets('an empty case list says what is missing, not its own name', (
    tester,
  ) async {
    // No cases seeded. The five case screens name the absence — and the
    // All/Active pair point at the + button that fills them — instead of
    // echoing their own heading as the empty state.
    final screens =
        <(Widget Function(), Type, String Function(AppLocalizations))>[
          (AllCasesScreen.new, AllCasesScreen, (l) => l.allCasesScreen_empty),
          (
            ActiveCasesScreen.new,
            ActiveCasesScreen,
            (l) => l.activeCasesScreen_empty,
          ),
          (
            OverdueDatesScreen.new,
            OverdueDatesScreen,
            (l) => l.overdueDatesScreen_empty,
          ),
          (
            UpcomingCasesScreen.new,
            UpcomingCasesScreen,
            (l) => l.upcomingCasesScreen_empty,
          ),
          (
            DisposedCasesScreen.new,
            DisposedCasesScreen,
            (l) => l.disposedCasesScreen_empty,
          ),
        ];

    for (final (build, screenType, emptyMessage) in screens) {
      await pumpScreen(tester, build);
      final l = stringsOf(tester, find.byType(screenType));
      expect(
        find.text(emptyMessage(l)),
        findsOneWidget,
        reason: '$screenType must show its own empty message',
      );
      await unmount(tester);
    }
  });
}
