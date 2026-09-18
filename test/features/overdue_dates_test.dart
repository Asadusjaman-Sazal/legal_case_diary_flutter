/// Overdue Dates screen tests.
///
/// Covers the "Last Updated" status line: it used to print the literal word
/// "Local"; it now reports when the cases on screen were last modified, in the
/// mockup's `Thursday, 04/06/26, 10:45 AM` shape, localized.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/core/utils/date_utils.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/cases/presentation/overdue_dates/overdue_dates_screen.dart';
import 'package:legal_case_diary/features/settings/data/local/user_preferences_dao.dart';
import 'package:legal_case_diary/features/settings/data/settings_repository.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:legal_case_diary/shared/widgets/add_edit_case_sheet.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late LocalIdentityService identity;

  const courtId = 'overdue-court';
  const roleId = 'overdue-role';
  const categoryId = 'overdue-category';

  /// 04/06/2026 10:45 Bangladesh time — the mockup's sample stamp.
  final overdueUpdatedAt =
      AppDateUtils.bangladeshCivilDateEpoch(2026, 6, 4) +
      const Duration(hours: 10, minutes: 45).inMilliseconds;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    identity = LocalIdentityService(prefs);
    db = AppDatabase(NativeDatabase.memory());
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
            courtName: Value('Joint District Judge, 2nd Court, Dhaka'),
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

  /// Inserts a case row directly so the test controls `updated_at`.
  Future<void> seedCase({
    required String id,
    required int nextDateMs,
    required int updatedAtMs,
  }) async {
    await db
        .into(db.cases)
        .insert(
          CasesCompanion(
            id: Value(id),
            userId: Value(identity.getId()),
            courtId: const Value(courtId),
            caseType: const Value('Civil Suit'),
            caseNumber: Value(id),
            petitioner: const Value('Md. Rahim Uddin'),
            respondent: const Value('Bangladesh Government'),
            onBehalfId: const Value(roleId),
            nextDate: Value(nextDateMs),
            createdAt: Value(updatedAtMs),
            updatedAt: Value(updatedAtMs),
          ),
        );
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const OverdueDatesScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWith((_) async => db),
          localIdentityServiceProvider.overrideWith((_) => identity),
          settingsRepositoryProvider.overrideWith(
            (_) async =>
                LocalSettingsRepository(UserPreferencesDao(db), identity),
          ),
          caseWritePermissionsProvider.overrideWith(
            (_) async => const CaseWritePermissions(canAdd: true, canEdit: true),
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

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('shows when the overdue cases were last modified', (
    WidgetTester tester,
  ) async {
    final yesterday = AppDateUtils.bangladeshTodayStartOfDay() - 86400000;
    // The future case is modified much later, but it is not on this screen.
    await seedCase(
      id: 'OVERDUE-1',
      nextDateMs: yesterday,
      updatedAtMs: overdueUpdatedAt,
    );
    await seedCase(
      id: 'FUTURE-1',
      nextDateMs: AppDateUtils.bangladeshTodayStartOfDay() + 5 * 86400000,
      updatedAtMs: overdueUpdatedAt + 30 * 86400000,
    );
    await pumpScreen(tester);

    expect(
      find.text('Last Updated: Thursday, 04/06/26, 10:45 AM'),
      findsOneWidget,
    );
    expect(find.textContaining('Local'), findsNothing);

    await unmount(tester);
  });

  testWidgets('omits the status line when there is nothing to report', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);

    // No overdue cases means no modification to report — the line is hidden
    // rather than showing an invented timestamp.
    expect(find.textContaining('Last Updated'), findsNothing);

    await unmount(tester);
  });

  testWidgets('the court title counts the cases in the active language', (
    WidgetTester tester,
  ) async {
    final yesterday = AppDateUtils.bangladeshTodayStartOfDay() - 86400000;
    await seedCase(
      id: 'OVERDUE-1',
      nextDateMs: yesterday,
      updatedAtMs: overdueUpdatedAt,
    );
    await seedCase(
      id: 'OVERDUE-2',
      nextDateMs: yesterday,
      updatedAtMs: overdueUpdatedAt,
    );
    await pumpScreen(tester);

    // The number alone, the way the Daily Cause List and Upcoming Cases titles
    // read it — not the "2 Cases" this screen used to print.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('2 Cases'), findsNothing);

    await unmount(tester);
    // বাংলা writes the same count in Bengali digits.
    await pumpScreen(tester, locale: const Locale('bn'));
    expect(find.text('২'), findsOneWidget);
    expect(find.text('2'), findsNothing);

    await unmount(tester);
  });

  testWidgets('the status line uses the active language', (
    WidgetTester tester,
  ) async {
    await seedCase(
      id: 'OVERDUE-1',
      nextDateMs: AppDateUtils.bangladeshTodayStartOfDay() - 86400000,
      updatedAtMs: overdueUpdatedAt,
    );
    // A narrow phone: the localized line is the longest, so a wrapping or
    // overflowing status row would show up here.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpScreen(tester, locale: const Locale('bn'));

    // Bengali weekday and digits, in the mockup's shape.
    expect(
      find.text('সর্বশেষ আপডেট: বৃহস্পতিবার, ০৪/০৬/২৬, ১০:৪৫ AM'),
      findsOneWidget,
    );

    await unmount(tester);
  });
}
