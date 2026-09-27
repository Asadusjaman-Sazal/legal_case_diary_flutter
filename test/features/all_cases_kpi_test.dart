/// All Cases summary tests.
///
/// The two count boxes at the top of the screen are tap-throughs to the list
/// they count (Active Cases / Disposed Cases), and the Court / Chronology
/// dropdowns below them carry the count boxes' title font size so the two rows
/// read as one block. Both are pinned here, because either can be lost silently
/// — a tile that stops navigating and a dropdown that drifts back to the
/// default 16 px both leave a screen that still builds.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/constants/pre_seeded_data.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/core/utils/date_utils.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/cases/data/case_repository.dart';
import 'package:legal_case_diary/features/cases/data/local/case_history_dao.dart';
import 'package:legal_case_diary/features/cases/data/local/cases_dao.dart';
import 'package:legal_case_diary/features/cases/presentation/active_cases/active_cases_screen.dart';
import 'package:legal_case_diary/features/cases/presentation/all_cases/all_cases_screen.dart';
import 'package:legal_case_diary/features/cases/presentation/disposed_cases/disposed_cases_screen.dart';
import 'package:legal_case_diary/features/settings/data/local/user_preferences_dao.dart';
import 'package:legal_case_diary/features/settings/data/settings_repository.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:legal_case_diary/shared/widgets/add_edit_case_sheet.dart';
import 'package:legal_case_diary/sync/sync_queue_dao.dart';
import 'package:legal_case_diary/sync/sync_write_helper.dart';

void main() {
  const dayMs = 86400000;
  const courtId = 'kpi-court';
  const roleId = 'kpi-role';

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
            id: Value('kpi-category'),
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
            courtCategoryId: Value('kpi-category'),
            orderIndex: Value(0),
            updatedAt: Value(1),
          ),
        );
    await db
        .into(db.onBehalfs)
        .insert(
          const OnBehalfsCompanion(
            id: Value(roleId),
            courtCategoryId: Value('kpi-category'),
            name: Value('Petitioner'),
            orderIndex: Value(1),
            updatedAt: Value(1),
          ),
        );
  });

  tearDown(() async => db.close());

  /// Seeds one case; a [disposed] one takes a disposal step so the screen's
  /// derived active/disposed split counts it as disposed.
  Future<void> seedCase({
    required String caseNumber,
    required String petitioner,
    bool disposed = false,
  }) => caseRepository.insertCase(
    CasesCompanion(
      caseNumber: Value(caseNumber),
      caseType: const Value('Civil Suit'),
      courtId: const Value(courtId),
      onBehalfId: const Value(roleId),
      petitioner: Value(petitioner),
      respondent: const Value('Bangladesh Government'),
      lastStep: Value(disposed ? disposedStepNames.first : 'Arrival'),
      nextDate: Value(AppDateUtils.bangladeshTodayStartOfDay() + 2 * dayMs),
    ),
  );

  /// Pumps All Cases with the Active / Disposed routes reachable, so the count
  /// boxes have somewhere to navigate to.
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const AllCasesScreen()),
        GoRoute(
          path: AppRoutes.activeCases,
          builder: (context, state) => const ActiveCasesScreen(),
        ),
        GoRoute(
          path: AppRoutes.disposedCases,
          builder: (context, state) => const DisposedCasesScreen(),
        ),
      ],
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
          locale: const Locale('en'),
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

  /// The rendered font size of every [text] on screen (a dropdown's own value
  /// and its floating label both carry the string).
  ///
  /// [within] scopes the search to one subtree, for a label that also appears
  /// elsewhere on screen.
  List<double?> renderedFontSizes(
    WidgetTester tester,
    String text, {
    Finder? within,
  }) => [
    for (final element in (within == null
            ? find.text(text)
            : find.descendant(of: within, matching: find.text(text)))
        .evaluate())
      (element.renderObject as RenderParagraph).text.style?.fontSize,
  ];

  testWidgets('each count box opens the list it counts', (tester) async {
    await seedCase(caseNumber: 'KPI-1', petitioner: 'Md. Rahim Uddin');
    await seedCase(caseNumber: 'KPI-2', petitioner: 'Karim Ahmed');
    await seedCase(
      caseNumber: 'KPI-3',
      petitioner: 'Closed Matter',
      disposed: true,
    );
    await pumpScreen(tester);

    // The boxes carry the split they promise: two active, one disposed.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('all-cases-kpi-active')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('all-cases-kpi-disposed')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('all-cases-kpi-active')));
    await tester.pumpAndSettle();
    expect(find.byType(ActiveCasesScreen), findsOneWidget);
    expect(find.byType(AllCasesScreen), findsNothing);

    // Back to All Cases, then the other box.
    Navigator.of(tester.element(find.byType(ActiveCasesScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(AllCasesScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('all-cases-kpi-disposed')));
    await tester.pumpAndSettle();
    expect(find.byType(DisposedCasesScreen), findsOneWidget);
    expect(find.byType(AllCasesScreen), findsNothing);

    await unmount(tester);
  });

  testWidgets('both filter dropdowns carry the count boxes title font size', (
    tester,
  ) async {
    await seedCase(caseNumber: 'KPI-1', petitioner: 'Md. Rahim Uddin');
    await pumpScreen(tester);

    final l = AppLocalizations.of(tester.element(find.byType(AllCasesScreen)));
    // The label is no longer upper-cased for the tile, so it also matches the
    // bottom bar's "Active Cases" entry — the measurement must stay on the tile.
    final tileTitle = renderedFontSizes(
      tester,
      l.allCasesScreen_activeCases,
      within: find.byKey(const ValueKey('all-cases-kpi-active')),
    ).single;
    expect(tileTitle, 14 * 0.6);

    // "Filter by Court" and "Newest First" are each both the dropdown's own
    // label and its displayed value, so every match has to be the same size.
    for (final label in [
      l.allCasesScreen_filterByCourt,
      l.allCasesScreen_newestFirst,
    ]) {
      final sizes = renderedFontSizes(tester, label);
      expect(sizes, isNotEmpty, reason: '"$label" is on screen');
      for (final size in sizes) {
        expect(size, tileTitle, reason: '"$label" matches the tile title');
      }
    }

    await unmount(tester);
  });
}
