/// Case-list extended ("table") view tests.
///
/// The header's view toggle used to do nothing: no screen passed it a callback,
/// so the icon was a live control with no effect, and `case_list_display_mode`
/// was stored by View Settings but read by nobody. These tests pin the wiring
/// that closed that gap — one shared stored preference, the compact card list
/// swapped for `CaseTableRow` rows, serial numbers only on the flat lists, and
/// no toggle at all on the two libraries that share the same shell.
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
import 'package:legal_case_diary/features/case_reference/data/local/case_references_dao.dart';
import 'package:legal_case_diary/features/case_reference/data/reference_repository.dart';
import 'package:legal_case_diary/features/case_reference/presentation/case_reference_screen.dart';
import 'package:legal_case_diary/features/cases/presentation/active_cases/active_cases_screen.dart';
import 'package:legal_case_diary/features/cases/presentation/all_cases/all_cases_screen.dart';
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
import 'package:legal_case_diary/sync/sync_queue_dao.dart';
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

  /// Inserts a case row directly so the test controls the dates it needs.
  Future<void> seedCase({
    required String id,
    String caseNumber = 'CASE-1',
    String onBehalfId = roleId,
    int? nextDateMs,
    String? lastStep,
    String? result,
    String? notesResults,
  }) => db
      .into(db.cases)
      .insert(
        CasesCompanion(
          id: Value(id),
          userId: Value(identity.getId()),
          courtId: const Value(courtId),
          caseType: const Value('Civil Suit'),
          caseNumber: Value(caseNumber),
          petitioner: const Value('Md. Rahim Uddin'),
          respondent: const Value('Bangladesh Government'),
          onBehalfId: Value(onBehalfId),
          nextDate: Value(nextDateMs),
          lastStep: Value(lastStep),
          result: Value(result),
          notesResults: Value(notesResults),
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
    expect((await settings.getSettings()).caseListDisplayMode, 'expanded');

    // Tapping again returns to the compact list and stores that too.
    await tester.tap(find.byKey(toggleKey));
    await settle(tester);

    expect(find.byType(CaseCard), findsOneWidget);
    expect(find.byType(CaseTableRow), findsNothing);
    expect((await settings.getSettings()).caseListDisplayMode, 'compact');

    await unmount(tester);
  });

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
    // dropdown would keep showing the mode the app started with — the same
    // stale-arrangement bug the bottom-nav order had (0.0.200).
    expect(
      (await container.read(
        settingsViewModelProvider.future,
      )).caseListDisplayMode,
      'compact',
    );

    await tester.tap(find.byKey(toggleKey));
    await settle(tester);

    expect(
      (await container.read(
        settingsViewModelProvider.future,
      )).caseListDisplayMode,
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

  testWidgets('the grouped lists keep their headings and carry no serial', (
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
    );

    await pumpScreen(tester, const DailyCauseListScreen());
    expect(find.byType(CaseTableRow), findsOneWidget);
    expect(find.byKey(serialKey), findsNothing);
    await unmount(tester);

    await pumpScreen(tester, const UpcomingCasesScreen());
    expect(find.byType(CaseTableRow), findsOneWidget);
    expect(find.byKey(serialKey), findsNothing);
    await unmount(tester);

    await pumpScreen(tester, const OverdueDatesScreen());
    expect(find.byType(CaseTableRow), findsOneWidget);
    expect(find.byKey(serialKey), findsNothing);
    // The overdue urgency strip follows the row into the extended view.
    expect(
      find.byKey(const ValueKey('case-row-overdue-strip')),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('an extended row keeps every field and action of the card', (
    WidgetTester tester,
  ) async {
    await setStoredMode('expanded');
    await seedCase(
      id: 'CASE-1',
      nextDateMs: AppDateUtils.bangladeshTodayStartOfDay() - 86400000,
      lastStep: 'Arrival',
      notesResults: 'Adjournment sought',
    );
    await pumpScreen(tester, const AllCasesScreen());

    // Full parity: the Update action, both contact actions, the court line and
    // the note the compact card shows are all still here.
    expect(find.byKey(const ValueKey('case-row-update')), findsOneWidget);
    expect(find.byIcon(Icons.call_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chat_outlined), findsOneWidget);
    expect(find.textContaining(courtName), findsWidgets);
    expect(find.byKey(const ValueKey('case-row-note')), findsOneWidget);
    expect(find.textContaining('Adjournment sought'), findsOneWidget);

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
}
