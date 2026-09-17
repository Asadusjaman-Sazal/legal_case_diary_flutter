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
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/cases/data/case_repository.dart';
import 'package:legal_case_diary/features/cases/data/local/case_history_dao.dart';
import 'package:legal_case_diary/features/cases/data/local/cases_dao.dart';
import 'package:legal_case_diary/features/cases/presentation/active_cases/active_cases_screen.dart';
import 'package:legal_case_diary/features/cases/presentation/all_cases/all_cases_screen.dart';
import 'package:legal_case_diary/features/cases/presentation/case_search.dart';
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

  /// A case row for the pure matcher tests (no database needed).
  Case caseRow({
    String caseNumber = '110/2021',
    String petitioner = 'Md. Rahim Uddin',
    String respondent = 'Bangladesh Government',
    String? petitionerLeadCounsel,
    String? respondentLeadCounsel,
    String? partyPhone,
    String? caseTitleAndSection,
    String? caseRemarks,
  }) => Case(
    id: 'case-1',
    userId: 'user-1',
    courtId: courtId,
    caseType: 'Civil Suit',
    caseNumber: caseNumber,
    petitioner: petitioner,
    respondent: respondent,
    petitionerLeadCounsel: petitionerLeadCounsel,
    respondentLeadCounsel: respondentLeadCounsel,
    onBehalfId: roleId,
    partyPhone: partyPhone,
    caseTitleAndSection: caseTitleAndSection,
    caseRemarks: caseRemarks,
    createdAt: 1,
    updatedAt: 1,
    isDeleted: false,
  );

  group('matchesCaseQuery', () {
    test('an empty or blank query matches every case', () {
      final row = caseRow();
      expect(matchesCaseQuery(row, ''), isTrue);
      expect(matchesCaseQuery(row, '   '), isTrue);
    });

    test('every searchable field is matched, case-insensitively', () {
      // The field set mirrors CasesDao.search, so the in-memory query and the
      // DAO primitive agree on what a case matches.
      expect(matchesCaseQuery(caseRow(), '110/2021'), isTrue);
      expect(matchesCaseQuery(caseRow(), 'rahim'), isTrue);
      expect(matchesCaseQuery(caseRow(), 'GOVERNMENT'), isTrue);
      expect(
        matchesCaseQuery(caseRow(petitionerLeadCounsel: 'adv. karim'), 'KARIM'),
        isTrue,
      );
      expect(
        matchesCaseQuery(
          caseRow(respondentLeadCounsel: 'Adv. Salam'),
          'salam',
        ),
        isTrue,
      );
      expect(
        matchesCaseQuery(caseRow(partyPhone: '01812332721'), '181233'),
        isTrue,
      );
      expect(
        matchesCaseQuery(
          caseRow(caseTitleAndSection: 'Section 138, N.I. Act'),
          '138',
        ),
        isTrue,
      );
      expect(
        matchesCaseQuery(caseRow(caseRemarks: 'Settlement talks ongoing'), 'taLks'),
        isTrue,
      );
    });

    test('the represented client name is matched through its role row', () {
      final row = caseRow();
      expect(matchesCaseQuery(row, 'petitioner'), isFalse);
      expect(matchesCaseQuery(row, 'petitioner', onBehalfName: 'Petitioner'), isTrue);
      // A role the user typed themselves is matched exactly like a seeded one.
      expect(
        matchesCaseQuery(row, 'বাদী', onBehalfName: 'বাদী'),
        isTrue,
      );
    });

    test('a non-matching query and absent optional fields never match', () {
      final bare = caseRow();
      expect(matchesCaseQuery(bare, 'zzz'), isFalse);
      // A query against a field this case does not have stays false instead of
      // throwing on the null.
      expect(matchesCaseQuery(bare, 'n.i. act'), isFalse);
      expect(matchesCaseQuery(bare, '0181'), isFalse);
    });
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

    await search(tester, 'rahim');
    expect(find.byKey(ValueKey('case-card-${ids['Rahim']}')), findsOneWidget);
    expect(find.byKey(ValueKey('case-card-${ids['Karim']}')), findsNothing);

    // The clear button empties the query but keeps the bar open.
    await tester.tap(find.byTooltip(l.customDropdown_clear));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byKey(ValueKey('case-card-${ids['Karim']}')), findsOneWidget);

    // The header icon closes the bar and the whole list is back.
    await tester.tap(find.byTooltip(l.casesModal_search).first);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(ValueKey('case-card-${ids['Karim']}')), findsOneWidget);

    await unmount(tester);
  });

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
    final datasets =
        <(Widget Function(), Type, String, String?, String?)>[
          (AllCasesScreen.new, AllCasesScreen, 'rahim', ids['Rahim'], ids['Karim']),
          (ActiveCasesScreen.new, ActiveCasesScreen, 'karim', ids['Karim'], ids['Rahim']),
          (UpcomingCasesScreen.new, UpcomingCasesScreen, 'rahim', ids['Rahim'], ids['Karim']),
          // Both are past-dated and active: the disposed past cases are kept
          // off this screen by the date-range query, so they cannot be the
          // case the query hides.
          (OverdueDatesScreen.new, OverdueDatesScreen, 'stale', ids['Stale'], ids['OldPending']),
          // SRH-3 and SRH-6 are both disposed; SRH-5 is not, so it cannot be
          // the case this query hides.
          (DisposedCasesScreen.new, DisposedCasesScreen, 'disposed party', ids['Disposed'], ids['Closed']),
          // Only SRH-4 and SRH-7 have a hearing today.
          (DailyCauseListScreen.new, DailyCauseListScreen, 'today', ids['Today'], ids['TodayToo']),
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
}
