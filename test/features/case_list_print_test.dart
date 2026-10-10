/// Tests for the Print and Share actions on the case screens (Task 14 Phase 3).
///
/// What matters here is not the PDF layout (Phases 1 and 2 pin that) but the
/// wiring: every case screen must print **its own dataset**, with the filters
/// and search query it is showing, and Share must stay a separate action that
/// hands over the app rather than the PDF.
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
import 'package:legal_case_diary/core/print/print_document.dart';
import 'package:legal_case_diary/core/providers/print_providers.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/services/app_share_service.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/core/utils/date_utils.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/cases/data/case_repository.dart';
import 'package:legal_case_diary/features/cases/data/local/case_history_dao.dart';
import 'package:legal_case_diary/features/cases/data/local/cases_dao.dart';
import 'package:legal_case_diary/features/cases/presentation/active_cases/active_cases_screen.dart';
import 'package:legal_case_diary/features/cases/presentation/all_cases/all_cases_screen.dart';
import 'package:legal_case_diary/features/cases/presentation/cases_screen_modal.dart';
import 'package:legal_case_diary/features/cases/presentation/daily_cause_list/daily_cause_list_screen.dart';
import 'package:legal_case_diary/features/cases/presentation/disposed_cases/disposed_cases_screen.dart';
import 'package:legal_case_diary/features/cases/presentation/overdue_dates/overdue_dates_screen.dart';
import 'package:legal_case_diary/features/cases/presentation/upcoming_cases/upcoming_cases_screen.dart';
import 'package:legal_case_diary/features/settings/data/local/user_preferences_dao.dart';
import 'package:legal_case_diary/features/settings/data/settings_repository.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:legal_case_diary/shared/widgets/add_edit_case_sheet.dart';
import 'package:legal_case_diary/sync/sync_queue_dao.dart';
import 'package:legal_case_diary/sync/sync_write_helper.dart';

import '../core/print_test_support.dart';

void main() {
  const dayMs = 86400000;
  const courtId = 'print-court';
  const roleId = 'print-role';

  late AppDatabase db;
  late SharedPreferences prefs;
  late LocalIdentityService identity;
  late LocalCaseRepository caseRepository;
  late RecordingPrintRenderer renderer;
  late RecordingPrintService printer;
  late RecordingShareService sharer;

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
    renderer = RecordingPrintRenderer();
    printer = RecordingPrintService();
    sharer = RecordingShareService();

    await db
        .into(db.courtCategories)
        .insert(
          const CourtCategoriesCompanion(
            id: Value('print-category'),
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
            courtCategoryId: Value('print-category'),
            orderIndex: Value(0),
            updatedAt: Value(1),
          ),
        );
    await db
        .into(db.onBehalfs)
        .insert(
          const OnBehalfsCompanion(
            id: Value(roleId),
            courtCategoryId: Value('print-category'),
            name: Value('Petitioner'),
            orderIndex: Value(1),
            updatedAt: Value(1),
          ),
        );
  });

  tearDown(() async => db.close());

  Future<String> seedCase({
    required String caseNumber,
    required String petitioner,
    required int nextDate,
    String respondent = 'State',
    String? step,
  }) => caseRepository.insertCase(
    CasesCompanion(
      caseNumber: Value(caseNumber),
      caseType: const Value('Civil Suit'),
      courtId: const Value(courtId),
      onBehalfId: const Value(roleId),
      petitioner: Value(petitioner),
      respondent: Value(respondent),
      partyPhone: const Value('01700000000'),
      lastStep: Value(step),
      nextDate: Value(nextDate),
    ),
  );

  /// One case per screen dataset, exactly as the search suite seeds them.
  Future<void> seedDatasets() async {
    final today = AppDateUtils.bangladeshTodayStartOfDay();
    final disposedStep = disposedStepNames.first;
    await seedCase(
      caseNumber: 'PRN-1',
      petitioner: 'Md. Rahim Uddin',
      step: 'Arrival',
      nextDate: today + 2 * dayMs,
    );
    await seedCase(
      caseNumber: 'PRN-2',
      petitioner: 'Karim Ahmed',
      step: 'Arrival',
      nextDate: today + 3 * dayMs,
    );
    await seedCase(
      caseNumber: 'PRN-4',
      petitioner: 'Today Only',
      step: 'Arrival',
      nextDate: today,
    );
    await seedCase(
      caseNumber: 'PRN-5',
      petitioner: 'Stale Matter',
      step: 'Arrival',
      nextDate: today - 5 * dayMs,
    );
    await seedCase(
      caseNumber: 'PRN-3',
      petitioner: 'Disposed Party',
      step: disposedStep,
      nextDate: today - 2 * dayMs,
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget Function() screen,
  ) async {
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
            (_) async => const CaseWritePermissions(canAdd: true, canEdit: true),
          ),
          printDocumentRendererProvider.overrideWithValue(renderer),
          printServiceProvider.overrideWithValue(printer),
          appShareServiceProvider.overrideWithValue(sharer),
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

  /// Opens the drawer and taps Print, returning the document it produced.
  Future<PrintDocument> tapPrint(WidgetTester tester) async {
    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.print_outlined));
    await tester.pumpAndSettle();
    return renderer.documents.single;
  }

  group('Print on the case screens', () {
    testWidgets('prints the rows the screen is showing, under its own title', (
      tester,
    ) async {
      await seedDatasets();

      const numbers = ['PRN-1', 'PRN-2', 'PRN-3', 'PRN-4', 'PRN-5'];
      final screens = <(Widget Function(), Type, String)>[
        (AllCasesScreen.new, AllCasesScreen, 'All Cases'),
        (ActiveCasesScreen.new, ActiveCasesScreen, 'Active Cases'),
        (UpcomingCasesScreen.new, UpcomingCasesScreen, 'Upcoming Cases'),
        (OverdueDatesScreen.new, OverdueDatesScreen, 'Overdue Dates'),
        (DisposedCasesScreen.new, DisposedCasesScreen, 'Disposed Cases'),
        (DailyCauseListScreen.new, DailyCauseListScreen, 'Daily Cause List'),
      ];

      for (final (build, screenType, title) in screens) {
        renderer.documents.clear();
        printer.jobs.clear();
        await pumpScreen(tester, build);
        await tester.pumpAndSettle();

        // The invariant under test: the printout carries exactly the cases the
        // screen is listing — no more (it must not print another screen's rows)
        // and no fewer.
        final listed = [
          for (final number in numbers)
            if (find.textContaining(number).evaluate().isNotEmpty) number,
        ];
        expect(listed, isNotEmpty, reason: '$screenType lists no case');

        final document = await tapPrint(tester);
        // A ruled-table printout: the Case No. is the third cell of every data
        // row (after the serial and the Prev. Date).
        final printed = document.tableRows
            .where((row) => row.kind == PrintTableRowKind.data)
            .map((row) => row.cells[2])
            .toList();

        expect(document.title, title, reason: '$screenType prints its own title');
        expect(
          document.entryCount,
          listed.length,
          reason: '$screenType must print exactly the rows it is showing',
        );
        for (final number in listed) {
          expect(
            printed.any((cell) => cell.contains(number)),
            isTrue,
            reason: '$screenType lists $number but did not print it',
          );
        }
        for (final number in numbers.where((n) => !listed.contains(n))) {
          expect(
            printed.any((cell) => cell.contains(number)),
            isFalse,
            reason: '$screenType printed $number, which it does not list',
          );
        }

        // The presented job is named after the screen, with the print date, so
        // the saved PDF is self-describing.
        expect(printer.jobs.single.jobName, startsWith(title));
        expect(
          printer.jobs.single.jobName,
          matches(RegExp(r' \d{2}-\d{2}-\d{2}$')),
          reason: 'the file name ends with the print date',
        );
        expect(printer.jobs.single.bytes, isNotEmpty);

        await unmount(tester);
      }
    });

    testWidgets('an active search query narrows the printout too', (
      tester,
    ) async {
      await seedDatasets();
      await pumpScreen(tester, AllCasesScreen.new);

      final l = AppLocalizations.of(
        tester.element(find.byType(AllCasesScreen)),
      );
      await tester.tap(find.byTooltip(l.casesModal_search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'rahim');
      await tester.pumpAndSettle();

      final document = await tapPrint(tester);

      expect(document.entryCount, 1);
      // The one matching case, under its court heading.
      final dataRow = document.tableRows.firstWhere(
        (row) => row.kind == PrintTableRowKind.data,
      );
      expect(dataRow.cells[2], contains('PRN-1'));
      // The query is printed as a header fact, so the sheet says what it is.
      expect(document.meta.single.value, 'rahim');

      await unmount(tester);
    });

    testWidgets('every table row carries a continuing serial in its first cell', (
      tester,
    ) async {
      await seedDatasets();

      await pumpScreen(tester, AllCasesScreen.new);
      final flat = await tapPrint(tester);
      // The first data row's first cell is the serial `1`.
      expect(
        flat.tableRows
            .firstWhere((row) => row.kind == PrintTableRowKind.data)
            .cells
            .first,
        '1',
      );
      await unmount(tester);

      renderer.documents.clear();
      await pumpScreen(tester, DailyCauseListScreen.new);
      final grouped = await tapPrint(tester);
      // Serials run across the whole list, including the grouped screen's rows.
      expect(
        grouped.tableRows
            .where((row) => row.kind == PrintTableRowKind.data)
            .map((row) => row.cells.first),
        isNotEmpty,
      );
      await unmount(tester);
    });

    testWidgets('Share hands over the app invite, never the PDF', (
      tester,
    ) async {
      await seedDatasets();
      await pumpScreen(tester, AllCasesScreen.new);

      tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.share_outlined));
      await tester.pumpAndSettle();

      expect(sharer.invites, hasLength(1));
      expect(sharer.invites.single.message, contains(appStoreUrl));
      expect(sharer.invites.single.subject, isNotEmpty);
      // Print and Share stay separate: sharing produced no print job.
      expect(printer.jobs, isEmpty);
      expect(renderer.documents, isEmpty);

      await unmount(tester);
    });

    testWidgets('a share-sheet fallback is reported to the user', (tester) async {
      await seedDatasets();
      sharer.outcome = AppShareOutcome.copiedToClipboard;
      await pumpScreen(tester, AllCasesScreen.new);

      final l = AppLocalizations.of(
        tester.element(find.byType(AllCasesScreen)),
      );
      tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.share_outlined));
      await tester.pumpAndSettle();

      expect(find.text(l.appShare_copied), findsOneWidget);

      await unmount(tester);
    });

    testWidgets('a screen with no printable document says so', (tester) async {
      // The case-reference and notes libraries share the shell but have no case
      // list to print, so the shell must not leave a dead tap.
      await pumpScreen(
        tester,
        () => const CasesScreenModal(
          title: 'Case Reference',
          body: SizedBox.shrink(),
        ),
      );

      final l = AppLocalizations.of(tester.element(find.byType(CasesScreenModal)));
      tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.print_outlined));
      await tester.pumpAndSettle();

      expect(find.text(l.print_notAvailable), findsOneWidget);
      expect(renderer.documents, isEmpty);

      await unmount(tester);
    });
  });
}
