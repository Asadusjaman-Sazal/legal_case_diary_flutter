/// Daily Cause List tests.
///
/// Covers the things that are easy to get wrong on this screen and are not
/// covered elsewhere: the header FAB opening the Add Case form (it was wired to
/// an empty callback), the court heading above the cards following the active
/// language (a pre-seeded court row stores its English name), and the hearing
/// counts/date label following the active language's numbering system.
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
import 'package:legal_case_diary/features/cases/presentation/daily_cause_list/daily_cause_list_screen.dart';
import 'package:legal_case_diary/features/settings/data/local/user_preferences_dao.dart';
import 'package:legal_case_diary/features/settings/data/settings_repository.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:legal_case_diary/shared/widgets/add_edit_case_sheet.dart';
import 'package:legal_case_diary/sync/sync_queue_dao.dart';
import 'package:legal_case_diary/sync/sync_write_helper.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late LocalIdentityService identity;
  late LocalCaseRepository caseRepository;

  const courtId = 'dcl-court';
  const roleId = 'dcl-role';

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    identity = LocalIdentityService(prefs);
    db = AppDatabase(NativeDatabase.memory());
    final syncHelper = SyncWriteHelper(SyncQueueDao(db), identity);
    caseRepository = LocalCaseRepository(
      CasesDao(db),
      CaseHistoryDao(db),
      syncHelper,
    );
    await db
        .into(db.courtCategories)
        .insert(
          const CourtCategoriesCompanion(
            id: Value('dcl-category'),
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
            courtCategoryId: Value('dcl-category'),
            orderIndex: Value(0),
            updatedAt: Value(1),
          ),
        );
    await db
        .into(db.onBehalfs)
        .insert(
          const OnBehalfsCompanion(
            id: Value(roleId),
            courtCategoryId: Value('dcl-category'),
            name: Value('Petitioner'),
            orderIndex: Value(1),
            updatedAt: Value(1),
          ),
        );
  });

  tearDown(() async => db.close());

  /// Seeds one case with a hearing on the given Bangladesh civil date.
  Future<String> seedHearing(String caseNumber, int nextDateMs) =>
      caseRepository.insertCase(
        CasesCompanion(
          caseNumber: Value(caseNumber),
          caseType: const Value('Civil Suit'),
          courtId: const Value(courtId),
          onBehalfId: const Value(roleId),
          petitioner: const Value('Md. Rahim Uddin'),
          respondent: const Value('Bangladesh Government'),
          nextDate: Value(nextDateMs),
        ),
      );

  Future<void> pumpScreen(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const DailyCauseListScreen(),
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

  testWidgets('the header FAB opens the Add Case form', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);
    final l = AppLocalizations.of(
      tester.element(find.byType(DailyCauseListScreen)),
    );

    expect(find.byTooltip(l.casesModal_addCase), findsOneWidget);
    expect(find.byType(AddEditCaseSheet), findsNothing);

    await tester.tap(find.byTooltip(l.casesModal_addCase));
    await tester.pumpAndSettle();
    expect(find.byType(AddEditCaseSheet), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('the court title follows the active language', (tester) async {
    // A pre-seeded court row stores its English name, so the group title above
    // the cards has to resolve it through the seed data instead of printing the
    // stored name.
    final seed = allSeedCourts.firstWhere(
      (court) =>
          lowerCourtCategoryIds.contains(court.courtCategoryId) &&
          court.courtNameBn != court.courtNameEn,
    );
    final category = seedCategoryById[seed.courtCategoryId]!;
    await db
        .into(db.courtCategories)
        .insert(
          CourtCategoriesCompanion(
            id: Value(category.id),
            nameKey: Value(category.nameKey),
            courtLevel: Value(category.courtLevel),
            orderIndex: Value(category.orderIndex),
            updatedAt: const Value(1),
          ),
        );
    await db
        .into(db.courts)
        .insert(
          CourtsCompanion(
            id: Value(seed.id),
            courtName: Value(seed.courtNameEn),
            higherLowerCourts: Value(seed.higherLowerCourts),
            courtCategoryId: Value(seed.courtCategoryId),
            orderIndex: const Value(1),
            updatedAt: const Value(1),
          ),
        );
    await caseRepository.insertCase(
      CasesCompanion(
        caseNumber: const Value('DCL-1'),
        caseType: const Value('Civil Suit'),
        courtId: Value(seed.id),
        onBehalfId: const Value(roleId),
        petitioner: const Value('Md. Rahim Uddin'),
        respondent: const Value('Bangladesh Government'),
        nextDate: Value(AppDateUtils.bangladeshTodayStartOfDay()),
      ),
    );
    await pumpScreen(tester, locale: const Locale('bn'));

    expect(find.text(seed.courtNameBn), findsOneWidget);
    expect(find.text(seed.courtNameEn), findsNothing);
    // Guard: the two labels really differ, so the assertion means something.
    expect(seed.courtNameBn, isNot(seed.courtNameEn));

    await unmount(tester);
  });

  testWidgets('court hearing counts use Bengali digits', (
    WidgetTester tester,
  ) async {
    final today = AppDateUtils.bangladeshTodayStartOfDay();
    await seedHearing('DCL-1', today);
    await seedHearing('DCL-2', today);
    await pumpScreen(tester, locale: const Locale('bn'));

    // The per-court KPI beside the court name is a plain count, so it has to be
    // formatted rather than interpolated.
    expect(find.text(AppDateUtils.formatDigits(2, 'bn')), findsOneWidget);
    expect(find.text('2'), findsNothing);

    await unmount(tester);
  });
}
