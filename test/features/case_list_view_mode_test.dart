/// Case-list extended ("table") view tests.
///
/// The header's view toggle used to do nothing: no screen passed it a callback,
/// so the icon was a live control with no effect, and `case_list_display_mode`
/// was stored by View Settings but read by nobody. These tests pin the wiring
/// that closed that gap and then made the choice **per screen** — each screen
/// stores its own compact ↔ extended choice, the compact card list is swapped
/// for `CaseTableRow` rows, serial numbers appear on every screen that gets a
/// header row, and the two libraries that share the same shell show no toggle.
///
/// The grouped screens (Overdue Dates, Daily Cause List, Upcoming Cases) draw a
/// court's cases the same way in both views: one pinned, foldable `CaseTableGroup`
/// per court — cards in the compact list, rows in the table — so a folded court
/// and the stored fold choice mean the same thing whichever view is on screen.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/core/constants/app_spacing.dart';
import 'package:legal_case_diary/core/constants/pre_seeded_data.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/core/utils/date_utils.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/case_reference/data/local/case_references_dao.dart';
import 'package:legal_case_diary/features/case_reference/data/reference_repository.dart';
import 'package:legal_case_diary/features/case_reference/presentation/case_reference_screen.dart';
import 'package:legal_case_diary/features/cases/presentation/active_cases/active_cases_screen.dart';
import 'package:legal_case_diary/features/cases/presentation/all_cases/all_cases_screen.dart';
import 'package:legal_case_diary/features/cases/presentation/case_list_view_mode.dart';
import 'package:legal_case_diary/features/cases/presentation/case_table_view.dart';
import 'package:legal_case_diary/features/cases/presentation/daily_cause_list/daily_cause_list_screen.dart';
import 'package:legal_case_diary/features/cases/presentation/disposed_cases/disposed_cases_screen.dart';
import 'package:legal_case_diary/features/cases/presentation/overdue_dates/overdue_dates_screen.dart';
import 'package:legal_case_diary/features/cases/presentation/upcoming_cases/upcoming_cases_screen.dart';
import 'package:legal_case_diary/features/notes/data/local/notes_dao.dart';
import 'package:legal_case_diary/features/notes/data/notes_repository.dart';
import 'package:legal_case_diary/features/notes/presentation/notes_screen.dart';
import 'package:legal_case_diary/features/settings/data/local/user_preferences_dao.dart';
import 'package:legal_case_diary/features/settings/data/settings_repository.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_viewmodel.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:legal_case_diary/shared/widgets/add_edit_case_sheet.dart';
import 'package:legal_case_diary/shared/widgets/case_card.dart';
import 'package:legal_case_diary/shared/widgets/case_table_row.dart';
import 'package:legal_case_diary/sync/connectivity_monitor.dart';
import 'package:legal_case_diary/sync/sync_queue_dao.dart';
import 'package:legal_case_diary/sync/sync_status_providers.dart';
import 'package:legal_case_diary/sync/sync_write_helper.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late LocalIdentityService identity;
  late LocalSettingsRepository settings;
  late LocalNotesRepository notes;
  late LocalReferenceRepository references;

  const categoryId = 'view-mode-category';
  const courtId = 'view-mode-court';
  const roleId = 'view-mode-role';
  const courtName = 'Joint District Judge, 2nd Court, Dhaka';

  /// The view-toggle key the shell only renders when a host wires it.
  const toggleKey = ValueKey('cases-modal-view-toggle');

  /// The serial cell each row of a flat list carries.
  const serialKey = ValueKey('case-row-serial');

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    identity = LocalIdentityService(prefs);
    db = AppDatabase(NativeDatabase.memory());
    final sync = SyncWriteHelper(SyncQueueDao(db), identity);
    settings = LocalSettingsRepository(UserPreferencesDao(db), identity);
    notes = LocalNotesRepository(NotesDao(db), sync);
    references = LocalReferenceRepository(CaseReferencesDao(db), sync);

    await db
        .into(db.courtCategories)
        .insert(
          const CourtCategoriesCompanion(
            id: Value(categoryId),
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
            courtName: Value(courtName),
            higherLowerCourts: Value('lower_courts'),
            courtCategoryId: Value(categoryId),
            orderIndex: Value(0),
            updatedAt: Value(1),
          ),
        );
    await db
        .into(db.onBehalfs)
        .insert(
          const OnBehalfsCompanion(
            id: Value(roleId),
            courtCategoryId: Value(categoryId),
            name: Value('Petitioner'),
            orderIndex: Value(1),
            updatedAt: Value(1),
          ),
        );
  });

  tearDown(() async => db.close());

  /// Stores [mode] as the shared case-list display preference.
  Future<void> setStoredMode(String mode) async {
    final current = await settings.getSettings();
    await settings.upsertSettings(current.copyWith(caseListDisplayMode: mode));
  }

  /// Stores [ids] as [screenId]'s folded courts, stamped with the Bangladesh
  /// civil day that starts at [dayStart].
  ///
  /// The app stores the day a fold was made so a new day can open every court
  /// again; seeding the stamp is how a test says "this fold was made
  /// yesterday" without waiting for midnight.
  Future<void> seedFolds(
    String screenId,
    List<String> ids, {
    required int dayStart,
  }) async {
    final current = await settings.getSettings();
    await settings.upsertSettings(
      current.copyWith(
        caseTableCollapsedCourts: <String, List<String>>{
          ...current.caseTableCollapsedCourts,
          screenId: ids,
        },
        caseTableCollapsedDays: <String, int>{
          ...current.caseTableCollapsedDays,
          screenId: dayStart,
        },
      ),
    );
  }

  /// Inserts a case row directly so the test controls the dates it needs.
  Future<void> seedCase({
    required String id,
    String caseNumber = 'CASE-1',
    String onBehalfId = roleId,
    String? court,
    int? nextDateMs,
    String? lastStep,
    String? result,
    String? notesResults,
    String? caseTitleAndSection,
  }) => db
      .into(db.cases)
      .insert(
        CasesCompanion(
          id: Value(id),
          userId: Value(identity.getId()),
          courtId: Value(court ?? courtId),
          caseType: const Value('Civil Suit'),
          caseNumber: Value(caseNumber),
          petitioner: const Value('Md. Rahim Uddin'),
          respondent: const Value('Bangladesh Government'),
          onBehalfId: Value(onBehalfId),
          nextDate: Value(nextDateMs),
          lastStep: Value(lastStep),
          result: Value(result),
          notesResults: Value(notesResults),
          caseTitleAndSection: Value(caseTitleAndSection),
          createdAt: const Value(1),
          updatedAt: const Value(1),
        ),
      );

  /// Pumps a bounded number of frames.
  ///
  /// Every case screen now holds a live Drift settings stream, so this suite
  /// waits for the widgets under test instead of `pumpAndSettle`, which would
  /// wait for the frame pipeline itself to go quiet.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
  }

  /// Pumps [screen] with the app's providers, router and localizations.
  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    Locale locale = const Locale('en'),
    bool online = true,
    bool premium = true,
    int attention = 0,
  }) async {
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => screen)],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWith((_) async => db),
          localIdentityServiceProvider.overrideWith((_) => identity),
          settingsRepositoryProvider.overrideWith((_) async => settings),
          notesRepositoryProvider.overrideWith((_) async => notes),
          referenceRepositoryProvider.overrideWith((_) async => references),
          caseWritePermissionsProvider.overrideWith(
            (_) async =>
                const CaseWritePermissions(canAdd: true, canEdit: true),
          ),
          // The header's sync button reads connectivity to decide between the
          // sync arrows and the offline icon.
          isOnlineProvider.overrideWith((ref) => Stream<bool>.value(online)),
          // Premium by default, so the sync button draws its enabled states
          // rather than the free-plan one; a free case passes `premium: false`.
          premiumAccessProvider.overrideWith((ref) async => premium),
          // Only stubbed when a test asks for it: the header's Sync Status badge
          // appears exactly while blocked or conflicted work is held, and the
          // other tests leave the real provider alone.
          if (attention > 0)
            syncStatusAttentionProvider.overrideWith(
              (ref) => Stream<int>.value(attention),
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
    await settle(tester);
  }

  /// Tears the widgets down before the test ends.
  ///
  /// Disposing the provider container while Drift's query streams are still
  /// live schedules a timer, which the test binding reports as pending; pumping
  /// a bare tree here lets it fire inside the test.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// The serial numbers the flat list is showing, in order.
  List<String?> renderedSerials(WidgetTester tester) => tester
      .widgetList<Text>(find.byKey(serialKey))
      .map((text) => text.data)
      .toList();

  /// Folds or re-opens one court's group on a grouped screen, in either view.
  ///
  /// A grouped screen opens with every court expanded, so a test that wants to
  /// read a court's cases needs no tap; tapping the heading folds that court
  /// away, exactly as the user does, and tapping it again brings them back —
  /// rows in the table, cards in the compact list.
  Future<void> toggleCourt(WidgetTester tester, String name) async {
    final group = find.ancestor(
      of: find.text(name),
      matching: find.byType(CaseTableGroup),
    );
    expect(group, findsOneWidget);
    final band = find.descendant(
      of: group,
      matching: find.byKey(const ValueKey('case-table-group-toggle')),
    );
    expect(band, findsOneWidget);
    // The band spans the table's whole width, which is wider than the screen
    // whenever the columns do not fit, so its own centre can sit off-screen:
    // tap just inside its top-left corner, where it is always on screen.
    await tester.tapAt(tester.getTopLeft(band) + const Offset(24, 8));
    await settle(tester);
  }

  /// The header labels the table is drawing, in render order.
  List<String?> headerLabels(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('case-table-header')),
          matching: find.byType(Text),
        ),
      )
      .map((text) => text.data)
      .toList();

  testWidgets('the header toggle switches a case list between cards and rows, '
      'and stores the choice', (WidgetTester tester) async {
    await seedCase(
      id: 'CASE-1',
      nextDateMs: AppDateUtils.bangladeshTodayStartOfDay() + 86400000,
    );
    await pumpScreen(tester, const AllCasesScreen());

    // Compact is the app default: cards, and the toggle is a live control.
    expect(find.byType(CaseCard), findsOneWidget);
    expect(find.byType(CaseTableRow), findsNothing);
    expect(find.byKey(toggleKey), findsOneWidget);

    await tester.tap(find.byKey(toggleKey));
    await settle(tester);

    expect(find.byType(CaseTableRow), findsOneWidget);
    expect(find.byType(CaseCard), findsNothing);
    expect(
      (await settings.getSettings()).caseListDisplayModes['all_cases'],
      'expanded',
    );

    // Tapping again returns to the compact list and stores that too.
    await tester.tap(find.byKey(toggleKey));
    await settle(tester);

    expect(find.byType(CaseCard), findsOneWidget);
    expect(find.byType(CaseTableRow), findsNothing);
    expect(
      (await settings.getSettings()).caseListDisplayModes['all_cases'],
      'compact',
    );

    await unmount(tester);
  });

  testWidgets('each screen stores its own view choice', (
    WidgetTester tester,
  ) async {
    await seedCase(
      id: 'CASE-1',
      nextDateMs: AppDateUtils.bangladeshTodayStartOfDay() + 86400000,
    );
    await pumpScreen(tester, const AllCasesScreen());

    // All Cases is switched to the table; nothing global is written.
    await tester.tap(find.byKey(toggleKey));
    await settle(tester);
    expect(find.byType(CaseTableRow), findsOneWidget);
    final stored = await settings.getSettings();
    expect(stored.caseListDisplayModes['all_cases'], 'expanded');
    expect(stored.caseListDisplayModes.containsKey('active'), isFalse);
    await unmount(tester);

    // Active Cases, which the user never switched, stays compact — the choice
    // is the screen's, not the app's.
    await pumpScreen(tester, const ActiveCasesScreen());
    expect(find.byType(CaseCard), findsOneWidget);
    expect(find.byType(CaseTableRow), findsNothing);
    await unmount(tester);

    // The choice survives a restart: All Cases opens extended again.
    await pumpScreen(tester, const AllCasesScreen());
    expect(find.byType(CaseTableRow), findsOneWidget);
    expect(find.byType(CaseCard), findsNothing);

    await unmount(tester);
  });

  testWidgets(
    'the global View Settings mode is the default for screens the user '
    'never switched',
    (WidgetTester tester) async {
      await setStoredMode('expanded');
      await seedCase(
        id: 'CASE-1',
        nextDateMs: AppDateUtils.bangladeshTodayStartOfDay() + 86400000,
      );

      // No per-screen entry: the global mode applies.
      await pumpScreen(tester, const AllCasesScreen());
      expect(find.byType(CaseTableRow), findsOneWidget);
      await unmount(tester);

      // An explicit per-screen choice overrides the global one.
      final current = await settings.getSettings();
      await settings.upsertSettings(
        current.copyWith(
          caseListDisplayModes: const <String, String>{'all_cases': 'compact'},
        ),
      );
      await pumpScreen(tester, const AllCasesScreen());
      expect(find.byType(CaseCard), findsOneWidget);
      expect(find.byType(CaseTableRow), findsNothing);
      await unmount(tester);

      // Another screen still follows the global mode.
      await pumpScreen(tester, const ActiveCasesScreen());
      expect(find.byType(CaseTableRow), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets('a stored extended choice opens a case list already extended', (
    WidgetTester tester,
  ) async {
    await setStoredMode('expanded');
    await seedCase(
      id: 'CASE-1',
      nextDateMs: AppDateUtils.bangladeshTodayStartOfDay() + 86400000,
    );
    await pumpScreen(tester, const AllCasesScreen());

    expect(find.byType(CaseTableRow), findsOneWidget);
    expect(find.byType(CaseCard), findsNothing);

    await unmount(tester);
  });

  testWidgets('the write is visible to Settings, which reads the ViewModel', (
    WidgetTester tester,
  ) async {
    await seedCase(
      id: 'CASE-1',
      nextDateMs: AppDateUtils.bangladeshTodayStartOfDay() + 86400000,
    );
    await pumpScreen(tester, const AllCasesScreen());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AllCasesScreen)),
    );

    // View Settings renders the ViewModel, not the stream, so the header's
    // write has to leave that ViewModel holding the new value. Otherwise the
    // Settings screens would keep showing the mode the app started with — the
    // same stale-arrangement bug the bottom-nav order had (0.0.200).
    expect(
      (await container.read(
        settingsViewModelProvider.future,
      )).caseListDisplayModes['all_cases'],
      isNull,
    );

    await tester.tap(find.byKey(toggleKey));
    await settle(tester);

    expect(
      (await container.read(
        settingsViewModelProvider.future,
      )).caseListDisplayModes['all_cases'],
      'expanded',
    );

    await unmount(tester);
  });

  testWidgets('flat lists number their rows, in the active language', (
    WidgetTester tester,
  ) async {
    final tomorrow = AppDateUtils.bangladeshTodayStartOfDay() + 86400000;
    await setStoredMode('expanded');
    await seedCase(id: 'CASE-1', caseNumber: 'CASE-1', nextDateMs: tomorrow);
    await seedCase(id: 'CASE-2', caseNumber: 'CASE-2', nextDateMs: tomorrow);
    await pumpScreen(tester, const AllCasesScreen());

    expect(renderedSerials(tester), <String>['1', '2']);

    await unmount(tester);
    // বাংলা writes the same positions in Bengali digits.
    await pumpScreen(
      tester,
      const AllCasesScreen(),
      locale: const Locale('bn'),
    );
    expect(renderedSerials(tester), <String>['১', '২']);

    await unmount(tester);
  });

  testWidgets('the other flat lists number their rows too', (
    WidgetTester tester,
  ) async {
    final tomorrow = AppDateUtils.bangladeshTodayStartOfDay() + 86400000;
    await setStoredMode('expanded');
    await seedCase(
      id: 'ACTIVE-1',
      caseNumber: 'ACTIVE-1',
      nextDateMs: tomorrow,
    );
    // The disposal step is taken from the seed data, so the Disposed screen
    // lists this case and the Active screen does not.
    await seedCase(
      id: 'DISPOSED-1',
      lastStep: disposedStepNames.first,
      nextDateMs: tomorrow,
    );

    await pumpScreen(tester, const ActiveCasesScreen());
    expect(find.byType(CaseTableRow), findsOneWidget);
    expect(renderedSerials(tester), <String>['1']);
    await unmount(tester);

    await pumpScreen(tester, const DisposedCasesScreen());
    expect(find.byType(CaseTableRow), findsOneWidget);
    expect(renderedSerials(tester), <String>['1']);
    await unmount(tester);
  });

  testWidgets('the grouped lists keep their headings and number their rows', (
    WidgetTester tester,
  ) async {
    await setStoredMode('expanded');
    final today = AppDateUtils.bangladeshTodayStartOfDay();
    await seedCase(id: 'TODAY-1', caseNumber: 'TODAY-1', nextDateMs: today);
    await seedCase(
      id: 'TOMORROW-1',
      caseNumber: 'TOMORROW-1',
      nextDateMs: today + 86400000,
    );
    await seedCase(
      id: 'PAST-1',
      caseNumber: 'PAST-1',
      nextDateMs: today - 86400000,
      lastStep: 'Arrival',
    );

    await pumpScreen(tester, const DailyCauseListScreen());
    expect(find.byType(CaseTableRow), findsOneWidget);
    expect(renderedSerials(tester), <String>['1']);
    // The court sub-heading still sits above the rows, under the header row…
    expect(find.textContaining('Joint District Judge'), findsWidgets);
    // …so the table does not repeat the court as a column of its own.
    expect(find.byKey(const ValueKey('case-table-header-court')), findsNothing);
    expect(find.byKey(const ValueKey('case-table-cell-court')), findsNothing);
    await unmount(tester);

    await pumpScreen(tester, const UpcomingCasesScreen());
    expect(find.byType(CaseTableRow), findsOneWidget);
    expect(renderedSerials(tester), <String>['1']);
    expect(find.byKey(const ValueKey('case-table-header-court')), findsNothing);
    expect(find.byKey(const ValueKey('case-table-cell-court')), findsNothing);
    await unmount(tester);

    await pumpScreen(tester, const OverdueDatesScreen());
    expect(find.byType(CaseTableRow), findsOneWidget);
    expect(renderedSerials(tester), <String>['1']);
    // The overdue urgency strip follows the row into the extended view.
    expect(
      find.byKey(const ValueKey('case-row-overdue-strip')),
      findsOneWidget,
    );
    // The heading supplies the court, so that column is dropped — but the
    // Step/Result column is a column of its own here like everywhere else, and
    // the date column is named for the date alone.
    expect(find.byKey(const ValueKey('case-table-header-court')), findsNothing);
    expect(
      find.byKey(const ValueKey('case-table-header-step')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('case-table-cell-step')), findsOneWidget);
    expect(find.text('Previous Date'), findsOneWidget);
    expect(find.text('Next Date'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('case-table-cell-step')),
        matching: find.text('Arrival'),
      ),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('the flat lists keep the court column the grouped lists drop', (
    WidgetTester tester,
  ) async {
    await setStoredMode('expanded');
    await seedCase(
      id: 'CASE-1',
      nextDateMs: AppDateUtils.bangladeshTodayStartOfDay() + 86400000,
    );
    await pumpScreen(tester, const AllCasesScreen());

    // A flat list has no court heading, so the column stays.
    expect(
      find.byKey(const ValueKey('case-table-header-court')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('case-table-cell-court')), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('Overdue Dates shows the step in its own column, before Note', (
    WidgetTester tester,
  ) async {
    await setStoredMode('expanded');
    await seedCase(
      id: 'PAST-1',
      nextDateMs: AppDateUtils.bangladeshTodayStartOfDay() - 86400000,
      lastStep: 'Arrival',
    );
    await pumpScreen(tester, const OverdueDatesScreen());

    // The date cell is the date alone: one line, no step folded into it.
    final dateCell = find.byKey(const ValueKey('case-table-cell-date'));
    expect(
      find.descendant(of: dateCell, matching: find.byType(Text)),
      findsOneWidget,
    );
    // The step has a column of its own, next to Note in the render order.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('case-table-cell-step')),
        matching: find.text('Arrival'),
      ),
      findsOneWidget,
    );
    final labels = headerLabels(tester);
    expect(labels, contains('Step/Result'));
    expect(labels.indexOf('Note'), labels.indexOf('Step/Result') + 1);

    await unmount(tester);
  });

  testWidgets('the Step/Result column shows an AD/HCD result', (
    WidgetTester tester,
  ) async {
    await setStoredMode('expanded');
    // A higher court has no step dropdown: its free-text Result is the only
    // value in the step's slot, so the column has to show it.
    await seedCase(
      id: 'HCD-1',
      caseNumber: 'HCD-1',
      result: 'Appeal dismissed with costs',
      nextDateMs: AppDateUtils.bangladeshTodayStartOfDay() + 86400000,
    );
    // A lower-court case with both values keeps the step first and the result
    // beneath it rather than dropping one of them.
    await seedCase(
      id: 'CASE-2',
      caseNumber: 'CASE-2',
      lastStep: 'Arrival',
      result: 'Suit decreed',
      nextDateMs: AppDateUtils.bangladeshTodayStartOfDay() + 86400000,
    );
    await pumpScreen(tester, const AllCasesScreen());

    // The column names both values, replacing the bare "Step".
    final header = find.byKey(const ValueKey('case-table-header'));
    expect(
      find.descendant(of: header, matching: find.text('Step/Result')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: header, matching: find.text('Step')),
      findsNothing,
    );

    // The AD/HCD result fills the cell where the step would go.
    expect(find.byKey(const ValueKey('case-row-step')), findsNWidgets(2));
    expect(find.text('Appeal dismissed with costs'), findsOneWidget);

    // The case that carries both stacks the result under the step.
    final stacked = find.ancestor(
      of: find.text('Arrival'),
      matching: find.byKey(const ValueKey('case-table-cell-step')),
    );
    expect(stacked, findsOneWidget);
    final lines = find.descendant(of: stacked, matching: find.byType(Text));
    expect(lines, findsNWidgets(2));
    expect(tester.widget<Text>(lines.at(0)).data, 'Arrival');
    expect(tester.widget<Text>(lines.at(1)).data, 'Suit decreed');

    await unmount(tester);
  });

  testWidgets('a court heading stays pinned while its cases are on screen', (
    WidgetTester tester,
  ) async {
    await setStoredMode('expanded');

    // A second court, later in the hierarchy, so the screen draws two groups.
    const secondCategoryId = 'view-mode-category-2';
    const secondCourtId = 'view-mode-court-2';
    const secondCourtName = 'Senior Assistant Judge, Dhaka';
    await db
        .into(db.courtCategories)
        .insert(
          const CourtCategoriesCompanion(
            id: Value(secondCategoryId),
            nameKey: Value('courtCategory_districtCourtsCriminal'),
            courtLevel: Value('lower'),
            orderIndex: Value(2),
            updatedAt: Value(1),
          ),
        );
    await db
        .into(db.courts)
        .insert(
          const CourtsCompanion(
            id: Value(secondCourtId),
            courtName: Value(secondCourtName),
            higherLowerCourts: Value('lower_courts'),
            courtCategoryId: Value(secondCategoryId),
            orderIndex: Value(0),
            updatedAt: Value(1),
          ),
        );

    final today = AppDateUtils.bangladeshTodayStartOfDay();
    // Few cases under the first court, many under the second: the list is long
    // enough to scroll the second court's heading up to the top.
    for (var i = 1; i <= 2; i++) {
      await seedCase(
        id: 'A-$i',
        caseNumber: 'A-$i',
        nextDateMs: today - i * 86400000,
        lastStep: 'Arrival',
      );
    }
    for (var i = 1; i <= 12; i++) {
      await seedCase(
        id: 'B-$i',
        caseNumber: 'B-$i',
        court: secondCourtId,
        nextDateMs: today - i * 86400000,
        lastStep: 'Arrival',
      );
    }
    await pumpScreen(tester, const OverdueDatesScreen());

    // Courts open expanded, so both headings already have their rows on screen:
    // the pinning is about a heading and the rows it heads.
    final list = find.byType(CustomScrollView);
    expect(list, findsOneWidget);
    // Both court headings are pinned bands, not plain rows.
    expect(find.byType(CaseTableGroup), findsNWidgets(2));
    final listTop = tester.getTopLeft(list).dy;
    double headingTop(String name) => tester.getTopLeft(find.text(name)).dy;

    // The list is as wide as the table, and this table is wider than the test
    // screen, so the list's own centre can fall outside it: scroll by dragging
    // from a point that is inside the viewport.
    Future<void> scrollList(double dy) async {
      final rect = tester.getRect(list);
      await tester.dragFrom(
        Offset(rect.left + 100, rect.top + rect.height / 2),
        Offset(0, dy),
      );
      await settle(tester);
    }

    // Scrolling inside the first court's cases leaves its heading holding the
    // top of the list, and the next court's heading still below it.
    await scrollList(-60);
    expect(
      headingTop(courtName),
      closeTo(listTop + AppSpacing.sm, 1.0),
      reason: 'the first court heading is pinned',
    );
    expect(headingTop(secondCourtName), greaterThan(listTop + 60));

    // Scrolling on to the next court hands the top over: the first heading is
    // pushed out and the second one takes its place.
    await scrollList(-4000);
    expect(
      headingTop(secondCourtName),
      closeTo(listTop + AppSpacing.sm, 1.0),
      reason: 'the second court heading took the top',
    );
    final pushedOut = find.text(courtName);
    if (pushedOut.evaluate().isNotEmpty) {
      expect(tester.getTopLeft(pushedOut).dy, lessThan(listTop));
    }

    await unmount(tester);
  });

  testWidgets('the compact card list pins the same court headings', (
    WidgetTester tester,
  ) async {
    // The same shape as the extended pinning test — a short first court and a
    // long second one — so the handover has to happen in the card list too.
    const secondCategoryId = 'view-mode-category-2';
    const secondCourtId = 'view-mode-court-2';
    const secondCourtName = 'Senior Assistant Judge, Dhaka';
    await db
        .into(db.courtCategories)
        .insert(
          const CourtCategoriesCompanion(
            id: Value(secondCategoryId),
            nameKey: Value('courtCategory_districtCourtsCriminal'),
            courtLevel: Value('lower'),
            orderIndex: Value(2),
            updatedAt: Value(1),
          ),
        );
    await db
        .into(db.courts)
        .insert(
          const CourtsCompanion(
            id: Value(secondCourtId),
            courtName: Value(secondCourtName),
            higherLowerCourts: Value('lower_courts'),
            courtCategoryId: Value(secondCategoryId),
            orderIndex: Value(0),
            updatedAt: Value(1),
          ),
        );

    final today = AppDateUtils.bangladeshTodayStartOfDay();
    for (var i = 1; i <= 2; i++) {
      await seedCase(
        id: 'A-$i',
        caseNumber: 'A-$i',
        nextDateMs: today - i * 86400000,
        lastStep: 'Arrival',
      );
    }
    for (var i = 1; i <= 12; i++) {
      await seedCase(
        id: 'B-$i',
        caseNumber: 'B-$i',
        court: secondCourtId,
        nextDateMs: today - i * 86400000,
        lastStep: 'Arrival',
      );
    }

    await pumpScreen(tester, const OverdueDatesScreen());
    expect(find.byType(CaseCard), findsWidgets);
    final list = find.byType(CustomScrollView);
    expect(list, findsOneWidget);
    final listTop = tester.getTopLeft(list).dy;
    double headingTop(String name) => tester.getTopLeft(find.text(name)).dy;

    // Scrolling inside the first court's cards leaves its heading holding the
    // top of the list, exactly as it does over the table's rows.
    await tester.drag(list, const Offset(0, -60));
    await settle(tester);
    expect(
      headingTop(courtName),
      closeTo(listTop + AppSpacing.sm, 1.0),
      reason: 'the first court heading is pinned in the card list',
    );

    // Scrolling on to the next court hands the top over there too.
    await tester.drag(list, const Offset(0, -4000));
    await settle(tester);
    expect(
      headingTop(secondCourtName),
      closeTo(listTop + AppSpacing.sm, 1.0),
      reason: 'the second court heading took the top in the card list',
    );

    await unmount(tester);
  });

  testWidgets('the grouped screens pin their court headings in both views', (
    WidgetTester tester,
  ) async {
    final today = AppDateUtils.bangladeshTodayStartOfDay();
    // One case for each screen: today's hearings (Daily Cause List), a future
    // hearing (Upcoming Cases, which starts at tomorrow) and a past one
    // (Overdue Dates).
    await seedCase(id: 'TODAY-1', caseNumber: 'TODAY-1', nextDateMs: today);
    await seedCase(
      id: 'TOMORROW-1',
      caseNumber: 'TOMORROW-1',
      nextDateMs: today + 86400000,
      lastStep: 'Arrival',
    );
    await seedCase(
      id: 'PAST-1',
      caseNumber: 'PAST-1',
      nextDateMs: today - 86400000,
      lastStep: 'Arrival',
    );
    final screens = <Widget>[
      const DailyCauseListScreen(),
      const UpcomingCasesScreen(),
      const OverdueDatesScreen(),
    ];

    // The compact card list heads each court with the same pinned, foldable
    // group the table uses, so the heading behaviour does not depend on which
    // view the screen is in.
    for (final screen in screens) {
      await pumpScreen(tester, screen);
      expect(find.byType(CaseTableGroup), findsWidgets);
      expect(find.byType(CaseTableRow), findsNothing);
      // Every court opens expanded, so its cards are on screen with no tap.
      expect(find.byType(CaseCard), findsWidgets);
      expect(
        find.byKey(const ValueKey('case-table-group-collapsed')),
        findsNothing,
      );
      await unmount(tester);
    }

    await setStoredMode('expanded');
    for (final screen in screens) {
      await pumpScreen(tester, screen);
      expect(find.byType(CaseTableGroup), findsWidgets);
      // Every court opens expanded, so its rows are on screen with no tap.
      expect(find.byType(CaseTableRow), findsWidgets);
      await unmount(tester);
    }
  });

  testWidgets('a court heading folds its cases, and starts expanded', (
    WidgetTester tester,
  ) async {
    await setStoredMode('expanded');

    // A second court, later in the hierarchy, so folding one court cannot be
    // mistaken for folding the whole list.
    const secondCategoryId = 'view-mode-category-2';
    const secondCourtId = 'view-mode-court-2';
    const secondCourtName = 'Senior Assistant Judge, Dhaka';
    await db
        .into(db.courtCategories)
        .insert(
          const CourtCategoriesCompanion(
            id: Value(secondCategoryId),
            nameKey: Value('courtCategory_districtCourtsCriminal'),
            courtLevel: Value('lower'),
            orderIndex: Value(2),
            updatedAt: Value(1),
          ),
        );
    await db
        .into(db.courts)
        .insert(
          const CourtsCompanion(
            id: Value(secondCourtId),
            courtName: Value(secondCourtName),
            higherLowerCourts: Value('lower_courts'),
            courtCategoryId: Value(secondCategoryId),
            orderIndex: Value(0),
            updatedAt: Value(1),
          ),
        );
    final today = AppDateUtils.bangladeshTodayStartOfDay();
    await seedCase(
      id: 'PAST-1',
      caseNumber: 'PAST-1',
      nextDateMs: today - 86400000,
      lastStep: 'Arrival',
    );
    await seedCase(
      id: 'PAST-2',
      caseNumber: 'PAST-2',
      court: secondCourtId,
      nextDateMs: today - 86400000,
      lastStep: 'Arrival',
    );

    await pumpScreen(tester, const OverdueDatesScreen());

    // Expanded to start with: both courts draw their rows, and no heading shows
    // the down chevron — the rows are already there to read.
    expect(find.byType(CaseTableGroup), findsNWidgets(2));
    expect(find.byKey(const ValueKey('case-row-PAST-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('case-row-PAST-2')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('case-table-group-collapsed')),
      findsNothing,
    );

    // Tapping a heading hides that court's cases, and only that court's: only
    // the folded heading carries the down chevron that says so.
    await toggleCourt(tester, courtName);
    expect(find.byKey(const ValueKey('case-row-PAST-1')), findsNothing);
    expect(find.byKey(const ValueKey('case-row-PAST-2')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('case-table-group-collapsed')),
      findsOneWidget,
    );
    // The chevron is the direction that says "cases are hidden under here".
    expect(
      tester
          .widget<Icon>(
            find.byKey(const ValueKey('case-table-group-collapsed')),
          )
          .icon,
      Icons.keyboard_arrow_down,
    );

    // Tapping the same heading again brings the cases back, leaving no chevron
    // behind because the rows say the cases are showing.
    await toggleCourt(tester, courtName);
    expect(find.byKey(const ValueKey('case-row-PAST-1')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('case-table-group-collapsed')),
      findsNothing,
    );

    await unmount(tester);
  });

  testWidgets('a folded court stays folded across a restart, per screen', (
    WidgetTester tester,
  ) async {
    await setStoredMode('expanded');
    await seedCase(
      id: 'PAST-1',
      caseNumber: 'PAST-1',
      nextDateMs: AppDateUtils.bangladeshTodayStartOfDay() - 86400000,
      lastStep: 'Arrival',
    );
    await pumpScreen(tester, const OverdueDatesScreen());

    // The court opens expanded; folding it writes the choice to the app.
    expect(find.byKey(const ValueKey('case-row-PAST-1')), findsOneWidget);
    await toggleCourt(tester, courtName);
    expect(find.byKey(const ValueKey('case-row-PAST-1')), findsNothing);
    expect(
      (await settings.getSettings()).caseTableCollapsedCourts['overdue'],
      contains(courtId),
    );
    await unmount(tester);

    // The choice survives a restart: the court opens folded again.
    await pumpScreen(tester, const OverdueDatesScreen());
    expect(find.byKey(const ValueKey('case-row-PAST-1')), findsNothing);
    expect(
      find.byKey(const ValueKey('case-table-group-collapsed')),
      findsOneWidget,
    );

    // Re-opening it clears the stored choice, so the screen stores what it shows.
    await toggleCourt(tester, courtName);
    expect(find.byKey(const ValueKey('case-row-PAST-1')), findsOneWidget);
    expect(
      (await settings.getSettings()).caseTableCollapsedCourts['overdue'],
      isNull,
    );
    await unmount(tester);
  });

  testWidgets('a fold made yesterday opens expanded today', (
    WidgetTester tester,
  ) async {
    await setStoredMode('expanded');
    final today = AppDateUtils.bangladeshTodayStartOfDay();
    await seedCase(
      id: 'PAST-1',
      caseNumber: 'PAST-1',
      nextDateMs: today - 86400000,
      lastStep: 'Arrival',
    );
    // The court was folded away yesterday and the screen was not opened again
    // before the day turned over.
    await seedFolds('overdue', <String>[courtId], dayStart: today - 86400000);

    // The new day starts the list the way a fresh install does: every court
    // showing, because a fold is one day's choice and not a standing setting.
    await pumpScreen(tester, const OverdueDatesScreen());
    expect(find.byKey(const ValueKey('case-row-PAST-1')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('case-table-group-collapsed')),
      findsNothing,
    );
    await unmount(tester);
  });

  testWidgets("a fold made today drops yesterday's folds, and is stamped today", (
    WidgetTester tester,
  ) async {
    await setStoredMode('expanded');
    // A second court, later in the hierarchy, so "yesterday's court came back"
    // cannot be mistaken for the fold that was just made.
    const secondCategoryId = 'view-mode-category-2';
    const secondCourtId = 'view-mode-court-2';
    const secondCourtName = 'Senior Assistant Judge, Dhaka';
    await db
        .into(db.courtCategories)
        .insert(
          const CourtCategoriesCompanion(
            id: Value(secondCategoryId),
            nameKey: Value('courtCategory_districtCourtsCriminal'),
            courtLevel: Value('lower'),
            orderIndex: Value(2),
            updatedAt: Value(1),
          ),
        );
    await db
        .into(db.courts)
        .insert(
          const CourtsCompanion(
            id: Value(secondCourtId),
            courtName: Value(secondCourtName),
            higherLowerCourts: Value('lower_courts'),
            courtCategoryId: Value(secondCategoryId),
            orderIndex: Value(0),
            updatedAt: Value(1),
          ),
        );
    final today = AppDateUtils.bangladeshTodayStartOfDay();
    await seedCase(
      id: 'PAST-1',
      caseNumber: 'PAST-1',
      nextDateMs: today - 86400000,
      lastStep: 'Arrival',
    );
    await seedCase(
      id: 'PAST-2',
      caseNumber: 'PAST-2',
      court: secondCourtId,
      nextDateMs: today - 86400000,
      lastStep: 'Arrival',
    );
    await seedFolds('overdue', <String>[courtId], dayStart: today - 86400000);

    await pumpScreen(tester, const OverdueDatesScreen());
    expect(find.byKey(const ValueKey('case-row-PAST-1')), findsOneWidget);

    // Folding the other court today starts a fresh set: yesterday's court is not
    // revived alongside it, and the set is stamped with today so it holds until
    // the next day turns over.
    await toggleCourt(tester, secondCourtName);
    expect(find.byKey(const ValueKey('case-row-PAST-2')), findsNothing);
    expect(find.byKey(const ValueKey('case-row-PAST-1')), findsOneWidget);
    final stored = await settings.getSettings();
    expect(stored.caseTableCollapsedCourts['overdue'], <String>[secondCourtId]);
    expect(stored.caseTableCollapsedDays['overdue'], today);
    await unmount(tester);
  });

  testWidgets("one screen's new day leaves another screen's fold alone", (
    WidgetTester tester,
  ) async {
    await setStoredMode('expanded');
    final today = AppDateUtils.bangladeshTodayStartOfDay();
    await seedCase(id: 'TODAY-1', caseNumber: 'TODAY-1', nextDateMs: today);
    await seedCase(
      id: 'PAST-1',
      caseNumber: 'PAST-1',
      nextDateMs: today - 86400000,
      lastStep: 'Arrival',
    );
    // The same court, folded on two screens on two different days: Daily Cause
    // List was folded today, Overdue Dates yesterday.
    await seedFolds(CaseListScreenId.dailyCauseList, <String>[
      courtId,
    ], dayStart: today);
    await seedFolds('overdue', <String>[courtId], dayStart: today - 86400000);

    // The day stamp belongs to the screen, so today's fold still holds on Daily
    // Cause List while Overdue Dates opens the same court expanded.
    await pumpScreen(tester, const DailyCauseListScreen());
    expect(find.byKey(const ValueKey('case-row-TODAY-1')), findsNothing);
    await unmount(tester);

    await pumpScreen(tester, const OverdueDatesScreen());
    expect(find.byKey(const ValueKey('case-row-PAST-1')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the compact card list folds a court, and shares the choice', (
    WidgetTester tester,
  ) async {
    // A second court, later in the hierarchy, so folding one court cannot be
    // mistaken for folding the whole list.
    const secondCategoryId = 'view-mode-category-2';
    const secondCourtId = 'view-mode-court-2';
    const secondCourtName = 'Senior Assistant Judge, Dhaka';
    await db
        .into(db.courtCategories)
        .insert(
          const CourtCategoriesCompanion(
            id: Value(secondCategoryId),
            nameKey: Value('courtCategory_districtCourtsCriminal'),
            courtLevel: Value('lower'),
            orderIndex: Value(2),
            updatedAt: Value(1),
          ),
        );
    await db
        .into(db.courts)
        .insert(
          const CourtsCompanion(
            id: Value(secondCourtId),
            courtName: Value(secondCourtName),
            higherLowerCourts: Value('lower_courts'),
            courtCategoryId: Value(secondCategoryId),
            orderIndex: Value(0),
            updatedAt: Value(1),
          ),
        );
    final today = AppDateUtils.bangladeshTodayStartOfDay();
    await seedCase(
      id: 'PAST-1',
      caseNumber: 'PAST-1',
      nextDateMs: today - 86400000,
      lastStep: 'Arrival',
    );
    await seedCase(
      id: 'PAST-2',
      caseNumber: 'PAST-2',
      court: secondCourtId,
      nextDateMs: today - 86400000,
      lastStep: 'Arrival',
    );

    // The compact list is the app default, and it opens with both courts'
    // cards on screen.
    await pumpScreen(tester, const OverdueDatesScreen());
    expect(find.byType(CaseCard), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('case-table-group-collapsed')),
      findsNothing,
    );

    // Tapping a court heading in the card list hides that court's cards, and
    // only that court's.
    await toggleCourt(tester, courtName);
    expect(find.byKey(const ValueKey('case-card-PAST-1')), findsNothing);
    expect(find.byKey(const ValueKey('case-card-PAST-2')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('case-table-group-collapsed')),
      findsOneWidget,
    );
    // The choice is stored for the screen, so it survives a restart...
    expect(
      (await settings.getSettings()).caseTableCollapsedCourts['overdue'],
      contains(courtId),
    );
    await unmount(tester);

    await pumpScreen(tester, const OverdueDatesScreen());
    expect(find.byKey(const ValueKey('case-card-PAST-1')), findsNothing);
    expect(find.byKey(const ValueKey('case-card-PAST-2')), findsOneWidget);
    await unmount(tester);

    // ...and the two views read the same entry: the table opens with the court
    // still folded, because the fold is one state and not one per view.
    await setStoredMode('expanded');
    await pumpScreen(tester, const OverdueDatesScreen());
    expect(find.byKey(const ValueKey('case-row-PAST-1')), findsNothing);
    expect(find.byKey(const ValueKey('case-row-PAST-2')), findsOneWidget);

    // Re-opening it in the table clears it for the card list too.
    await toggleCourt(tester, courtName);
    expect(find.byKey(const ValueKey('case-row-PAST-1')), findsOneWidget);
    expect(
      (await settings.getSettings()).caseTableCollapsedCourts['overdue'],
      isNull,
    );
    await unmount(tester);
  });

  testWidgets('Overdue Dates shows an AD/HCD result in its Step/Result cell', (
    WidgetTester tester,
  ) async {
    await setStoredMode('expanded');
    // No step, only a result: the higher court's free text is the only value
    // the column has to carry.
    await seedCase(
      id: 'PAST-1',
      // Not a disposal term: a result that disposes the case (Dismissed,
      // Disposed, Discharged) moves it to Disposed Cases and off this screen.
      result: 'Judgment reserved',
      nextDateMs: AppDateUtils.bangladeshTodayStartOfDay() - 86400000,
    );
    await pumpScreen(tester, const OverdueDatesScreen());
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('case-table-cell-step')),
        matching: find.text('Judgment reserved'),
      ),
      findsOneWidget,
    );

    await unmount(tester);
  });

  testWidgets('an extended row shows one data column per field', (
    WidgetTester tester,
  ) async {
    await setStoredMode('expanded');
    await seedCase(
      id: 'CASE-1',
      caseNumber: 'CASE-1',
      nextDateMs: AppDateUtils.bangladeshTodayStartOfDay() + 86400000,
      lastStep: 'Arrival',
      notesResults: 'Adjournment sought',
    );
    await pumpScreen(tester, const AllCasesScreen());

    // One column per field, and no per-cell labels: each value appears once.
    expect(find.byKey(const ValueKey('case-row-update')), findsOneWidget);
    expect(find.textContaining(courtName), findsWidgets);
    expect(find.byKey(const ValueKey('case-row-note')), findsOneWidget);
    expect(find.text('Adjournment sought'), findsOneWidget);
    expect(find.text('Md. Rahim Uddin'), findsOneWidget);
    expect(find.text('Bangladesh Government'), findsOneWidget);
    expect(find.text('CASE-1'), findsOneWidget);
    // The table view drops the card's phone and message actions, per the
    // requested column list; they stay on the compact card and the detail
    // screen.
    expect(find.byIcon(Icons.call_outlined), findsNothing);
    expect(find.byIcon(Icons.chat_outlined), findsNothing);

    await unmount(tester);
  });

  testWidgets('a narrow phone scrolls the table instead of squeezing it', (
    WidgetTester tester,
  ) async {
    // 360 dp wide: narrower than the mockup's 600 px table, which is exactly the
    // case the horizontal scroll exists for.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await setStoredMode('expanded');
    // A role the user added themselves: the on-behalf chip has to give way to
    // the case number rather than push it off the row.
    const longRoleId = 'view-mode-long-role';
    await db
        .into(db.onBehalfs)
        .insert(
          const OnBehalfsCompanion(
            id: Value(longRoleId),
            courtCategoryId: Value(categoryId),
            name: Value('Opposite Party (Informant)'),
            orderIndex: Value(2),
            updatedAt: Value(1),
          ),
        );
    await seedCase(
      id: 'CASE-1',
      onBehalfId: longRoleId,
      nextDateMs: AppDateUtils.bangladeshTodayStartOfDay() + 86400000,
      lastStep: 'Arrival',
      notesResults: 'Adjournment sought',
    );
    await pumpScreen(tester, const AllCasesScreen());

    // The row keeps its full width — wider than the screen — rather than
    // squeezing its columns, and the body scrolls sideways to reach it.
    final rowWidth = tester.getSize(find.byType(CaseTableRow)).width;
    expect(rowWidth, greaterThan(360));
    final directions = tester
        .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .map((view) => view.scrollDirection);
    expect(directions, contains(Axis.horizontal));
    expect(tester.takeException(), isNull);

    await unmount(tester);
  });

  testWidgets('the table has one header row naming the columns in order', (
    WidgetTester tester,
  ) async {
    await setStoredMode('expanded');
    await seedCase(
      id: 'CASE-1',
      nextDateMs: AppDateUtils.bangladeshTodayStartOfDay() + 86400000,
    );
    await pumpScreen(tester, const AllCasesScreen());

    expect(find.byKey(const ValueKey('case-table-header')), findsOneWidget);

    // The requested column order, left to right: the date column sits before
    // Name of Court, and every other data column follows it.
    const order = <String>[
      'serial',
      'update',
      'date',
      'court',
      'caseType',
      'caseNumber',
      'petitioner',
      'respondent',
      'onBehalf',
      'step',
      'note',
    ];
    var previous = double.negativeInfinity;
    for (final column in order) {
      final finder = find.byKey(ValueKey('case-table-header-$column'));
      expect(finder, findsOneWidget, reason: column);
      final dx = tester.getTopLeft(finder).dx;
      expect(dx, greaterThan(previous), reason: column);
      previous = dx;
      // Each header cell sits exactly over its data column, which is why the
      // rows carry no labels of their own.
      expect(
        dx,
        closeTo(
          tester.getTopLeft(find.byKey(ValueKey('case-table-cell-$column'))).dx,
          0.01,
        ),
        reason: column,
      );
    }

    // The header names every column once; the rows show values only. The
    // labels are read inside the header, since a value can repeat a word (the
    // seeded on-behalf role here is literally "Petitioner").
    final header = find.byKey(const ValueKey('case-table-header'));
    for (final label in <String>[
      'Serial',
      'Update',
      'Name of Court',
      'Case Type',
      'Case Number',
      'Petitioner',
      'Respondent',
      'On Behalf',
      'Step/Result',
      'Note',
      'Next Date',
    ]) {
      expect(
        find.descendant(of: header, matching: find.text(label)),
        findsOneWidget,
        reason: label,
      );
    }

    await unmount(tester);
  });

  testWidgets('the table honours the requested content and styling rules', (
    WidgetTester tester,
  ) async {
    await setStoredMode('expanded');
    await seedCase(
      id: 'CASE-1',
      nextDateMs: AppDateUtils.bangladeshTodayStartOfDay() + 86400000,
      caseTitleAndSection: 'Section 138, Negotiable Instruments Act',
    );
    await pumpScreen(tester, const AllCasesScreen());

    // The Case Type column shows the case type only — the free-text title or
    // section stays on the compact card, not in this column.
    final typeCell = find.byKey(const ValueKey('case-table-cell-caseType'));
    expect(
      find.descendant(of: typeCell, matching: find.text('Civil Suit')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: typeCell,
        matching: find.textContaining('Negotiable Instruments'),
      ),
      findsNothing,
    );

    // Every data column shares the Name of Court font and size; the case
    // number is plain black rather than the card's link blue.
    final courtText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('case-table-cell-court')),
        matching: find.byType(Text),
      ),
    );
    for (final column in <String>[
      'caseType',
      'caseNumber',
      'petitioner',
      'respondent',
      'onBehalf',
      'step',
      'note',
      'date',
    ]) {
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(ValueKey('case-table-cell-$column')),
          matching: find.byType(Text),
        ),
      );
      expect(
        text.style!.fontFamily,
        courtText.style!.fontFamily,
        reason: column,
      );
      expect(text.style!.fontSize, courtText.style!.fontSize, reason: column);
    }
    final numberText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('case-table-cell-caseNumber')),
        matching: find.byType(Text),
      ),
    );
    expect(numberText.style!.color, AppColors.onSurface);

    // The header is centred; data cells keep their own alignment.
    final headerText = tester.widget<Text>(
      find.byKey(const ValueKey('case-table-header-court')),
    );
    expect(headerText.textAlign, TextAlign.center);

    await unmount(tester);
  });

  testWidgets('every table cell shows its data in a single line', (
    WidgetTester tester,
  ) async {
    await setStoredMode('expanded');
    // A long on-behalf role and a long note: neither may wrap the cell.
    const longRoleId = 'view-mode-long-role';
    await db
        .into(db.onBehalfs)
        .insert(
          const OnBehalfsCompanion(
            id: Value(longRoleId),
            courtCategoryId: Value(categoryId),
            name: Value('Opposite Party (Informant)'),
            orderIndex: Value(2),
            updatedAt: Value(1),
          ),
        );
    await seedCase(
      id: 'CASE-1',
      onBehalfId: longRoleId,
      nextDateMs: AppDateUtils.bangladeshTodayStartOfDay() + 86400000,
      lastStep: 'Arrival',
      notesResults: 'Adjournment sought and costs reserved for the next day',
    );
    await pumpScreen(tester, const AllCasesScreen());

    final cells = find.byWidgetPredicate(
      (widget) =>
          widget is KeyedSubtree &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'case-table-cell-',
          ),
    );
    expect(cells, findsNWidgets(caseTableColumnOrder.length));
    final texts = tester.widgetList<Text>(
      find.descendant(of: cells, matching: find.byType(Text)),
    );
    expect(texts, isNotEmpty);
    for (final text in texts) {
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
      expect(text.overflow, TextOverflow.ellipsis);
    }

    await unmount(tester);
  });

  testWidgets('dragging a header rule resizes the column and stores it', (
    WidgetTester tester,
  ) async {
    await setStoredMode('expanded');
    await seedCase(
      id: 'CASE-1',
      nextDateMs: AppDateUtils.bangladeshTodayStartOfDay() + 86400000,
    );
    await pumpScreen(tester, const AllCasesScreen());

    final courtCell = find.byKey(const ValueKey('case-table-cell-court'));
    final before = tester.getSize(courtCell).width;
    final defaults = resolveCaseTableWidths(const {});
    expect(before, defaults[CaseTableColumn.court]);

    await tester.drag(
      find.byKey(const ValueKey('case-table-resize-court')),
      const Offset(80, 0),
    );
    await settle(tester);

    // The column grew on screen, and the size was written to the user's
    // settings — nothing else in the settings row was disturbed.
    final after = tester.getSize(courtCell).width;
    expect(after, greaterThan(before));
    final stored = (await settings.getSettings()).caseTableColumnWidths;
    expect(stored['court'], greaterThan(defaults[CaseTableColumn.court]!));
    expect(after, closeTo(stored['court']!, 0.01));

    // A later visit opens at the size the user left it in.
    await unmount(tester);
    await pumpScreen(tester, const AllCasesScreen());
    expect(
      tester.getSize(find.byKey(const ValueKey('case-table-cell-court'))).width,
      closeTo(stored['court']!, 0.01),
    );

    await unmount(tester);
  });

  testWidgets('a stored column width is used and a corrupt one is clamped', (
    WidgetTester tester,
  ) async {
    final current = await settings.getSettings();
    await settings.upsertSettings(
      current.copyWith(
        caseListDisplayMode: 'expanded',
        caseTableColumnWidths: const <String, double>{
          'note': 320,
          // Far below the column's floor, and a column that no longer exists.
          'step': 1,
          'removed-column': 200,
        },
      ),
    );
    await seedCase(
      id: 'CASE-1',
      nextDateMs: AppDateUtils.bangladeshTodayStartOfDay() + 86400000,
    );
    await pumpScreen(tester, const AllCasesScreen());

    expect(
      tester.getSize(find.byKey(const ValueKey('case-table-cell-note'))).width,
      320,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('case-table-cell-step'))).width,
      caseTableMinColumnWidth(CaseTableColumn.step),
    );

    await unmount(tester);
  });

  testWidgets('the libraries keep the shell but never show a view toggle', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, const NotesScreen());
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byKey(toggleKey), findsNothing);
    await unmount(tester);

    await pumpScreen(tester, const CaseReferenceScreen());
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byKey(toggleKey), findsNothing);
    await unmount(tester);
  });

  // ---------------------------------------------------------------------------
  // The header sync button's pending count (Task 23 follow-up).
  //
  // The separate `sync_problem` badge deliberately stays silent for ordinary
  // pending work — it is for entries nothing will move on its own. The sync
  // button's count is the opposite: it answers "why has my edit not appeared
  // on the other device yet?", which is exactly a pending queue row.
  // ---------------------------------------------------------------------------

  /// Inserts one pending queue row, so the header has work to count.
  Future<void> enqueuePending() async {
    await SyncQueueDao(db).insert(
      SyncQueueCompanion.insert(
        entityType: 'case',
        entityId: 'queued-case',
        operation: 'update',
        mutationId: 'mut-queued-1',
        basePayload: '{}',
        changedFields: '[]',
        payload: '{}',
        preMutationPayload: '{}',
        createdAt: 1,
        state: 'pending',
      ),
    );
  }

  /// The number painted on the sync button's badge, or 0 when there is none.
  int pendingBadgeCount(WidgetTester tester) {
    final badges = tester.widgetList<Badge>(find.byType(Badge));
    for (final badge in badges) {
      final label = badge.label;
      if (label is Text && label.data != null) {
        final value = int.tryParse(label.data!);
        if (value != null) return value;
      }
    }
    return 0;
  }

  testWidgets('the header sync button counts pending work in red', (
    tester,
  ) async {
    await pumpScreen(tester, const AllCasesScreen());
    // Nothing queued: no count at all, rather than a reassuring "0".
    expect(pendingBadgeCount(tester), 0);
    await unmount(tester);

    await enqueuePending();
    await pumpScreen(tester, const AllCasesScreen());
    expect(pendingBadgeCount(tester), 1);

    final badge = tester.widget<Badge>(find.byType(Badge).first);
    expect(badge.backgroundColor, AppColors.error);
    await unmount(tester);
  });

  testWidgets('the Sync Status badge counts in the language\'s own digits', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const AllCasesScreen(),
      locale: const Locale('bn'),
      attention: 2,
    );

    // The badge names the blocked or conflicted work waiting to be resolved, and
    // its count is written in the active language's digits — `Badge.count` paints
    // Latin ones, which a Bengali reader must never be shown.
    final badge = find.descendant(
      of: find.byKey(const ValueKey('cases-modal-sync-status')),
      matching: find.byType(Badge),
    );
    expect(badge, findsOneWidget);
    expect(
      find.descendant(of: badge, matching: find.text('২')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: badge, matching: find.text('2')),
      findsNothing,
      reason: 'the count was painted in Latin digits',
    );

    await unmount(tester);
  });

  testWidgets('the badge tooltip says how much is waiting', (tester) async {
    await enqueuePending();
    await pumpScreen(tester, const AllCasesScreen());

    final button = tester.widget<IconButton>(
      find.byKey(const ValueKey('cases-modal-sync-button')),
    );
    expect(button.tooltip, isNot(contains('premium')));
    await unmount(tester);
  });

  testWidgets('the badge count uses the locale\'s digits', (tester) async {
    // A Latin "1" beside Bengali text is the defect the Daily Cause List
    // already guards against for its own counts; the badge must match.
    await enqueuePending();
    await pumpScreen(
      tester,
      const AllCasesScreen(),
      locale: const Locale('bn'),
    );

    expect(
      find.text(AppDateUtils.formatDigits(1, 'bn', grouping: false)),
      findsOneWidget,
    );
    expect(find.text('1'), findsNothing);
    await unmount(tester);
  });

  testWidgets('a successful sync wears ordinary ink, not green', (
    tester,
  ) async {
    // Regression: green said "something good happened" on every launch, which
    // trains the eye to stop reading the icon at all. Success is the ordinary
    // case and now looks like the ordinary case.
    await pumpScreen(tester, const AllCasesScreen());

    final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_done_outlined));
    expect(icon.color, AppColors.primary);
    expect(icon.color, isNot(AppColors.success));
    await unmount(tester);
  });

  testWidgets('offline with nothing queued shows the cloud-off icon bare', (
    tester,
  ) async {
    await pumpScreen(tester, const AllCasesScreen(), online: false);

    // The off cloud, and no count — there is no work to report.
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done_outlined), findsNothing);
    expect(pendingBadgeCount(tester), 0);
    await unmount(tester);
  });

  testWidgets('offline with work queued keeps the red count on the off cloud', (
    tester,
  ) async {
    // The count is how an offline user learns an edit is waiting, so it stays;
    // the cloud under it is the off one, because the button never claims a sync
    // is possible when it is not. The two facts are separate.
    await enqueuePending();
    await pumpScreen(tester, const AllCasesScreen(), online: false);

    expect(pendingBadgeCount(tester), 1);
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a free account wears the sync-off cloud, not the checkmark', (
    tester,
  ) async {
    // Sync is off for a free account, so the checkmark — "this device's work is
    // safely in the account" — would claim a sync that cannot have run.
    await pumpScreen(tester, const AllCasesScreen(), premium: false);

    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done_outlined), findsNothing);
    await unmount(tester);
  });

  testWidgets('a free account is shown no count, even with work queued', (
    tester,
  ) async {
    // Every write path queues its mutation, free accounts included, so the queue
    // is real — but a count over a sync button promises a sync that never comes,
    // and reports work as *waiting* when for this account it is not.
    await enqueuePending();
    await pumpScreen(tester, const AllCasesScreen(), premium: false);

    expect(pendingBadgeCount(tester), 0);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('cases-modal-sync-button')),
        matching: find.byType(Badge),
      ),
      findsNothing,
    );
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a free account is told the entitlement, not a queue count', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    await enqueuePending();
    await pumpScreen(tester, const AllCasesScreen(), premium: false);

    final button = tester.widget<IconButton>(
      find.byKey(const ValueKey('cases-modal-sync-button')),
    );
    expect(button.tooltip, l.sync_unavailable);
    await unmount(tester);
  });

  testWidgets('a free account offline still reads the entitlement', (
    tester,
  ) async {
    // Free is permanent, offline is incidental: the entitlement is the reason
    // there is no sync at all, so it is the answer whether or not the radio is
    // up — and it is also the answer for the icon, which stays the off cloud.
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpScreen(
      tester,
      const AllCasesScreen(),
      premium: false,
      online: false,
    );

    final button = tester.widget<IconButton>(
      find.byKey(const ValueKey('cases-modal-sync-button')),
    );
    expect(button.tooltip, l.sync_unavailable);
    expect(button.tooltip, isNot(l.sync_offline));
    await unmount(tester);
  });
}
