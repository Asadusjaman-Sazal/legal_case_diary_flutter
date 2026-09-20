/// Tests for Case Detail's Edit/Print header actions (Task 14 Phase 3).
///
/// The user's chosen entry point for exporting a case's history is the Case
/// Detail screen itself: **Edit** lost its "Case" so the row has room for
/// **Print**, and the printed sheet is the screen "the way the user has it" —
/// so the history is printed exactly as expanded or collapsed as it is on
/// screen, which is what these tests pin.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/print/print_document.dart';
import 'package:legal_case_diary/core/providers/print_providers.dart';
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

import '../core/print_test_support.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late LocalIdentityService identity;
  late LocalCaseRepository caseRepository;
  late RecordingPrintRenderer renderer;
  late RecordingPrintService printer;

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

    await db
        .into(db.courtCategories)
        .insert(
          const CourtCategoriesCompanion(
            id: Value('detail-category'),
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
            id: Value('detail-court'),
            courtName: Value('Joint District Judge, 2nd Court, Dhaka'),
            higherLowerCourts: Value('lower_courts'),
            courtCategoryId: Value('detail-category'),
            orderIndex: Value(0),
            updatedAt: Value(1),
          ),
        );
    await db
        .into(db.onBehalfs)
        .insert(
          const OnBehalfsCompanion(
            id: Value('detail-role'),
            courtCategoryId: Value('detail-category'),
            name: Value('Petitioner'),
            orderIndex: Value(1),
            updatedAt: Value(1),
          ),
        );
  });

  tearDown(() async => db.close());

  /// Seeds the case with [historyRows] history entries and returns its id.
  Future<String> seedCase(int historyRows) async {
    final today = AppDateUtils.bangladeshTodayStartOfDay();
    const dayMs = 86400000;
    final caseId = await caseRepository.insertCase(
      CasesCompanion(
        caseNumber: const Value('423/2023'),
        caseType: const Value('Civil Suit'),
        courtId: const Value('detail-court'),
        onBehalfId: const Value('detail-role'),
        petitioner: const Value('Md. Rahim Uddin'),
        respondent: const Value('Bangladesh Government'),
        petitionerLeadCounsel: const Value('Adv. Abdul Kalam'),
        respondentLeadCounsel: const Value('Adv. Ahsan Habib'),
        partyPhone: const Value('+8801711000000'),
        caseTitleAndSection: const Value('Partition Suit (Title)'),
        caseRemarks: const Value('Dispute over ancestral property.'),
        lastStep: const Value('Arrival'),
        nextDate: Value(today + 2 * dayMs),
      ),
    );

    for (var i = 0; i < historyRows; i++) {
      await CaseHistoryDao(db).insertHistoryEntry(
        CaseHistoryCompanion(
          id: Value('history-$i'),
          caseId: Value(caseId),
          userId: Value(identity.getId()),
          hearingDate: Value(today - (i + 1) * dayMs),
          lastStep: const Value('Arrival'),
          nextDate: Value(today - i * dayMs),
          noteResult: Value('Note $i'),
          createdBy: Value(identity.getId()),
          sourceMutationId: Value('mutation-$i'),
          baseCaseVersion: const Value(0),
          resultCaseVersion: const Value(1),
          updatedAt: const Value(1),
        ),
      );
    }
    return caseId;
  }

  Future<void> pumpDetail(WidgetTester tester, String caseId) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
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
            (_) async =>
                LocalSettingsRepository(UserPreferencesDao(db), identity),
          ),
          caseWritePermissionsProvider.overrideWith(
            (_) async => const CaseWritePermissions(canAdd: true, canEdit: true),
          ),
          printDocumentRendererProvider.overrideWithValue(renderer),
          printServiceProvider.overrideWithValue(printer),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: CaseDetailScreen(caseId: caseId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  AppLocalizations stringsOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(CaseDetailScreen)));

  /// The printed history rows, in document order.
  List<PrintEntry> printedHistory(PrintDocument document, AppLocalizations l) =>
      document.groups
          .firstWhere((group) => group.heading == l.caseDetailsScreen_caseHistory)
          .entries;

  testWidgets('the header offers Edit and Print instead of Edit Case', (
    tester,
  ) async {
    final caseId = await seedCase(1);
    await pumpDetail(tester, caseId);

    final l = stringsOf(tester);
    expect(find.text(l.sharedActions_edit), findsOneWidget);
    expect(find.byKey(const ValueKey('case-detail-print')), findsOneWidget);
    // The narrower label is the whole reason the row fits three actions.
    expect(find.text(l.caseDetailsScreen_editCase), findsNothing);

    await unmount(tester);
  });

  testWidgets('Print exports the detail sheet with its sections and labels', (
    tester,
  ) async {
    final caseId = await seedCase(1);
    await pumpDetail(tester, caseId);

    await tester.tap(find.byKey(const ValueKey('case-detail-print')));
    await tester.pumpAndSettle();

    final l = stringsOf(tester);
    final document = renderer.documents.single;

    // The first line leads with the case type, then the number, then the court.
    // The type is stored as typed, and the print inserts nothing between them.
    expect(document.title, startsWith('Civil Suit 423/2023'));
    expect(document.title, contains('Joint District Judge'));
    // The header line above already carries the case number, so no section
    // repeats it as an entry heading (history rows keep their own date).
    final sections = document.groups.where(
      (group) => group.heading != l.caseDetailsScreen_caseHistory,
    );
    for (final entry in sections.expand((group) => group.entries)) {
      expect(entry.heading, isEmpty);
    }
    // No hairline under any line: the sheet is checked at the renderer level,
    // which is where a line could ever be drawn.
    // The labels are the screen's own, so the sheet reads like the screen.
    final labels = document.groups
        .expand((group) => group.entries)
        .expand((entry) => entry.fields)
        .map((field) => field.label)
        .toList();
    // The case number and case type are on the header line, so the Case Details
    // section does not repeat them as labelled rows.
    expect(labels, isNot(contains(l.addEditCaseSheet_caseNumber)));
    expect(labels, isNot(contains(l.allCasesScreen_caseType)));
    expect(labels, isNot(contains(l.addEditCaseSheet_nameOfCourt)));
    expect(labels, contains(l.caseDetailsScreen_petitioner));
    expect(labels, contains(l.caseDetailsScreen_sectionsOrCaseTitle));
    // Section headings come from the screen's own labels too.
    final headings = document.groups
        .map((group) => group.heading)
        .toList();
    expect(headings, contains(l.caseDetailsScreen_caseTitleAndRemark));
    expect(headings, contains(l.caseDetailsScreen_caseHistory));
    expect(printer.jobs.single.jobName, document.title);

    await unmount(tester);
  });

  testWidgets('the printed history follows the on-screen expansion', (
    tester,
  ) async {
    final caseId = await seedCase(5);
    await pumpDetail(tester, caseId);

    final l = stringsOf(tester);

    // Collapsed on screen: the sheet prints the same three rows.
    await tester.tap(find.byKey(const ValueKey('case-detail-print')));
    await tester.pumpAndSettle();
    expect(printedHistory(renderer.documents.single, l), hasLength(3));

    await unmount(tester);
    renderer.documents.clear();

    // Expanded on screen (the user tapped Show): all five are printed.
    await pumpDetail(tester, caseId);
    await tester.tap(find.text(l.caseDetailsScreen_showHistory));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('case-detail-print')));
    await tester.pumpAndSettle();

    final document = renderer.documents.single;
    expect(printedHistory(document, l), hasLength(5));
    // The sheet says how many the case actually holds.
    expect(
      document.subtitle,
      l.caseDetailsScreen_entriesTotal(5),
    );

    await unmount(tester);
  });
}
