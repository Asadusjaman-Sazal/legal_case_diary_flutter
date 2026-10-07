/// Upcoming Cases screen tests.
///
/// The screen groups by next-hearing date. Inside each date it now groups by
/// court like the Daily Cause List, so cases of one court sit under a single
/// court title (court icon + court name + case count) and the card itself
/// carries no court line. These tests pin that structure and its ordering.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/constants/app_spacing.dart';
import 'package:legal_case_diary/core/constants/pre_seeded_data.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/core/utils/date_utils.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/cases/data/case_repository.dart';
import 'package:legal_case_diary/features/cases/data/local/case_history_dao.dart';
import 'package:legal_case_diary/features/cases/data/local/cases_dao.dart';
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
  late AppDatabase db;
  late SharedPreferences prefs;
  late LocalIdentityService identity;
  late LocalCaseRepository caseRepository;

  const roleId = 'upcoming-role';

  /// Two real pre-seeded courts in different court categories, each with a
  /// Bengali label that differs from the stored English name.
  final seedCourts =
      allSeedCourts
          .where(
            (court) =>
                lowerCourtCategoryIds.contains(court.courtCategoryId) &&
                court.courtNameBn != court.courtNameEn,
          )
          .toList()
        ..sort((a, b) {
          final ca = seedCategoryById[a.courtCategoryId]!.orderIndex;
          final cb = seedCategoryById[b.courtCategoryId]!.orderIndex;
          if (ca != cb) return ca.compareTo(cb);
          return a.orderIndex.compareTo(b.orderIndex);
        });
  final firstCourt = seedCourts.first;
  final secondCourt = seedCourts.firstWhere(
    (court) => court.courtCategoryId != firstCourt.courtCategoryId,
  );

  /// Inserts the court category and the court row the way the seed migration
  /// writes them: the English name under the stable seed id.
  Future<void> insertCourt(SeedCourt court) async {
    final category = seedCategoryById[court.courtCategoryId]!;
    final hasCategory =
        await (db.select(
          db.courtCategories,
        )..where((row) => row.id.equals(category.id))).getSingleOrNull() !=
        null;
    if (!hasCategory) {
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
    }
    await db
        .into(db.courts)
        .insert(
          CourtsCompanion(
            id: Value(court.id),
            courtName: Value(court.courtNameEn),
            higherLowerCourts: Value(court.higherLowerCourts),
            courtCategoryId: Value(court.courtCategoryId),
            orderIndex: Value(court.orderIndex),
            updatedAt: const Value(1),
          ),
        );
  }

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

    await insertCourt(firstCourt);
    await insertCourt(secondCourt);
    await db
        .into(db.onBehalfs)
        .insert(
          OnBehalfsCompanion(
            id: const Value(roleId),
            courtCategoryId: Value(firstCourt.courtCategoryId),
            name: const Value('Petitioner'),
            orderIndex: const Value(1),
            updatedAt: const Value(1),
          ),
        );
  });

  tearDown(() async => db.close());

  /// Seeds one case whose hearing is tomorrow, so the screen lists it.
  Future<String> seedUpcomingCase({
    String courtId = '',
    String caseNumber = 'UP-1',
    int? nextDateMs,
  }) => caseRepository.insertCase(
    CasesCompanion(
      caseNumber: Value(caseNumber),
      caseType: const Value('Civil Suit'),
      courtId: Value(courtId.isEmpty ? firstCourt.id : courtId),
      onBehalfId: const Value(roleId),
      petitioner: const Value('Md. Rahim Uddin'),
      respondent: const Value('Bangladesh Government'),
      lastStep: const Value('Arrival'),
      nextDate: Value(
        nextDateMs ?? AppDateUtils.bangladeshTodayStartOfDay() + 86400000,
      ),
    ),
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    Locale locale = const Locale('bn'),
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const UpcomingCasesScreen(),
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

  testWidgets("one court's cases sit under a single court title", (
    tester,
  ) async {
    final firstCaseId = await seedUpcomingCase(caseNumber: 'UP-1');
    final secondCaseId = await seedUpcomingCase(caseNumber: 'UP-2');
    await pumpScreen(tester);

    expect(find.text(firstCourt.courtNameBn), findsOneWidget);
    expect(find.byKey(ValueKey('case-card-$firstCaseId')), findsOneWidget);
    expect(find.byKey(ValueKey('case-card-$secondCaseId')), findsOneWidget);

    // Both cards follow the title, and the title sits above both of them.
    final titleY = tester.getTopLeft(find.text(firstCourt.courtNameBn)).dy;
    expect(
      tester.getTopLeft(find.byKey(ValueKey('case-card-$firstCaseId'))).dy,
      greaterThan(titleY),
    );
    expect(
      tester.getTopLeft(find.byKey(ValueKey('case-card-$secondCaseId'))).dy,
      greaterThan(titleY),
    );

    await unmount(tester);
  });

  testWidgets('each court gets its own title, in the Daily Cause List order', (
    tester,
  ) async {
    final firstCaseId = await seedUpcomingCase(caseNumber: 'UP-1');
    final secondCaseId = await seedUpcomingCase(
      courtId: secondCourt.id,
      caseNumber: 'UP-2',
    );
    await pumpScreen(tester);

    expect(find.text(firstCourt.courtNameBn), findsOneWidget);
    expect(find.text(secondCourt.courtNameBn), findsOneWidget);

    // The pre-seeded hierarchy decides which court comes first, exactly like
    // the Daily Cause List ordering: category order, then court order.
    expect(
      seedCategoryById[firstCourt.courtCategoryId]!.orderIndex,
      lessThan(seedCategoryById[secondCourt.courtCategoryId]!.orderIndex),
    );
    final firstTitleY = tester.getTopLeft(find.text(firstCourt.courtNameBn)).dy;
    final secondTitleY = tester
        .getTopLeft(find.text(secondCourt.courtNameBn))
        .dy;
    expect(firstTitleY, lessThan(secondTitleY));

    // Each card sits under its own court title.
    expect(
      firstTitleY,
      lessThan(
        tester.getTopLeft(find.byKey(ValueKey('case-card-$firstCaseId'))).dy,
      ),
    );
    expect(
      secondTitleY,
      lessThan(
        tester.getTopLeft(find.byKey(ValueKey('case-card-$secondCaseId'))).dy,
      ),
    );
    expect(
      tester.getTopLeft(find.byKey(ValueKey('case-card-$firstCaseId'))).dy,
      lessThan(secondTitleY),
    );

    await unmount(tester);
  });

  testWidgets('the court title is the Daily Cause List heading, in Bengali', (
    tester,
  ) async {
    await seedUpcomingCase(caseNumber: 'UP-1');
    await seedUpcomingCase(caseNumber: 'UP-2');
    await pumpScreen(tester);

    // Court icon beside the name, like the Daily Cause List heading.
    expect(find.byIcon(Icons.account_balance), findsOneWidget);

    // The stored English name is never printed.
    expect(find.text(firstCourt.courtNameEn), findsNothing);

    // The case count beside it uses the active language's digits. Exactly one
    // Bengali ২ is expected: this heading's count. The header's sync button stays
    // bare because this harness is a free account, and a free account syncs
    // nothing so is shown no count — seeding did queue two sync rows, but that is
    // not news a free account is given. The strict guard is the count that must
    // not be a bare Latin interpolation.
    expect(find.text(AppDateUtils.formatDigits(2, 'bn')), findsNWidgets(1));
    expect(find.text('2'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('cases-modal-sync-button')),
        matching: find.byType(Badge),
      ),
      findsNothing,
    );

    await unmount(tester);
  });

  testWidgets('the card itself carries no court line', (tester) async {
    final caseId = await seedUpcomingCase(caseNumber: 'UP-1');
    await pumpScreen(tester);

    final cardFinder = find.byKey(ValueKey('case-card-$caseId'));
    final card = tester.widget<CaseCard>(cardFinder);
    expect(card.variant, CaseCardVariant.dailyCauseList);
    expect(card.courtName, isNull);
    expect(
      find.descendant(
        of: cardFinder,
        matching: find.text(firstCourt.courtNameBn),
      ),
      findsNothing,
      reason: 'the court is the title above the card, not a card field',
    );

    // The rest of the card is unchanged.
    final l = AppLocalizations.of(tester.element(cardFinder));
    expect(card.title, 'Md. Rahim Uddin Vs Bangladesh Government');
    expect(card.step, stepLabelBnByToken['Arrival']);
    expect(card.statusLabel, 'Petitioner'); // the user's own role row.
    expect(card.alignStatusLabelRight, isTrue);
    expect(card.showPhoneButton, isTrue);
    expect(card.showMessageButton, isTrue);
    expect(card.nextDate, isNotNull);
    expect(l.upcomingCasesScreen_title, isNotEmpty);

    await unmount(tester);
  });

  testWidgets('the English date title keeps the short EEE, MMM DD, YYYY', (
    tester,
  ) async {
    // Two days out, so the group is a dated title rather than "Tomorrow".
    final hearing = AppDateUtils.bangladeshTodayStartOfDay() + 86400000 * 2;
    await seedUpcomingCase(caseNumber: 'UP-1', nextDateMs: hearing);
    await pumpScreen(tester, locale: const Locale('en'));

    final expected = DateFormat(
      'EEE, MMM dd, yyyy',
      'en',
    ).format(AppDateUtils.bangladeshDateTime(hearing));
    expect(expected, contains(', '));
    expect(find.text(expected), findsOneWidget);

    // The long form the screen used before is gone.
    expect(
      find.text(AppDateUtils.formatFullDate(hearing, locale: 'en')),
      findsNothing,
    );

    await unmount(tester);
  });

  testWidgets('the Bengali date title spells the month out', (tester) async {
    final hearing = AppDateUtils.bangladeshTodayStartOfDay() + 86400000 * 2;
    await seedUpcomingCase(caseNumber: 'UP-1', nextDateMs: hearing);
    await pumpScreen(tester);

    // Bengali keeps the language's day-first order and the full month name:
    // বৃহস্পতি, ২৪ সেপ্টেম্বর, ২০২৬.
    final expected = DateFormat(
      'EEE, dd MMMM, yyyy',
      'bn',
    ).format(AppDateUtils.bangladeshDateTime(hearing));
    expect(expected, isNot(contains('SEP')));
    expect(find.text(expected), findsOneWidget);

    // The abbreviated month the header used before is gone.
    final short = DateFormat(
      'EEE, MMM dd, yyyy',
      'bn',
    ).format(AppDateUtils.bangladeshDateTime(hearing));
    expect(short, isNot(expected));
    expect(find.text(short), findsNothing);

    await unmount(tester);
  });

  testWidgets('the divider takes only the space left after the date', (
    tester,
  ) async {
    final hearing = AppDateUtils.bangladeshTodayStartOfDay() + 86400000 * 2;
    await seedUpcomingCase(caseNumber: 'UP-1', nextDateMs: hearing);
    // A phone-wide surface: the Bengali date is the longest title, so a
    // half-width date area would wrap it and push the divider away.
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpScreen(tester);

    final label = find.text(
      DateFormat(
        'EEE, dd MMMM, yyyy',
        'bn',
      ).format(AppDateUtils.bangladeshDateTime(hearing)),
    );
    expect(label, findsOneWidget);
    final labelRect = tester.getRect(label);
    final dividerRect = tester.getRect(find.byType(Divider));

    // The date is drawn on a single line, deciding its own width...
    expect(
      labelRect.height,
      lessThan(26),
      reason: 'the date title must stay on one line',
    );
    // ...and the divider starts right after it, filling the rest of the row.
    expect(dividerRect.left, greaterThan(labelRect.right));
    expect(dividerRect.left - labelRect.right, lessThan(AppSpacing.sm));
    expect(dividerRect.right, greaterThan(labelRect.right));

    await unmount(tester);
  });

  testWidgets('the court title follows the active language', (tester) async {
    await seedUpcomingCase(caseNumber: 'UP-1');
    await pumpScreen(tester, locale: const Locale('en'));

    expect(find.text(firstCourt.courtNameEn), findsOneWidget);
    expect(find.text(firstCourt.courtNameBn), findsNothing);

    await unmount(tester);
  });
}
