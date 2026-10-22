/// Task 07 acceptance tests for real form persistence and host wiring.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/constants/pre_seeded_data.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/cases/data/case_repository.dart';
import 'package:legal_case_diary/features/cases/data/local/case_history_dao.dart';
import 'package:legal_case_diary/features/cases/data/local/cases_dao.dart';
import 'package:legal_case_diary/features/cases/presentation/all_cases/all_cases_screen.dart';
import 'package:legal_case_diary/features/payments/presentation/paywall_screen.dart';
import 'package:legal_case_diary/features/settings/data/local/case_notification_preferences_dao.dart';
import 'package:legal_case_diary/features/settings/data/local/case_types_dao.dart';
import 'package:legal_case_diary/features/settings/data/local/court_categories_dao.dart';
import 'package:legal_case_diary/features/settings/data/local/courts_dao.dart';
import 'package:legal_case_diary/features/settings/data/local/on_behalfs_dao.dart';
import 'package:legal_case_diary/features/settings/data/local/user_preferences_dao.dart';
import 'package:legal_case_diary/features/settings/data/premium_access.dart';
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
  late SyncWriteHelper syncHelper;
  late LocalCaseRepository caseRepository;
  late AddEditCaseLookupData lookupData;
  late String courtId;
  late String onBehalfId;

  /// Reads every lookup table the form needs; also re-run mid-test after a row
  /// is added, so a test can hand the form a freshly loaded dataset.
  Future<AddEditCaseLookupData> loadLookupData() async => AddEditCaseLookupData(
    courtCategories: await CourtCategoriesDao(db).getAll(),
    caseCategories: await (db.select(
      db.caseCategories,
    )..where((row) => row.isDeleted.equals(false))).get(),
    courts: await CourtsDao(db).getAll(),
    caseTypes: await CaseTypesDao(db).getAll(),
    onBehalfs: await OnBehalfsDao(db).getAll(),
    notificationOffsets: const [0, 1, 3],
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    identity = LocalIdentityService(prefs);
    db = AppDatabase(NativeDatabase.memory());
    syncHelper = SyncWriteHelper(SyncQueueDao(db), identity);
    const categoryId = 'appellate_division';
    const caseCategoryId = 'acceptance-case-category';
    await db
        .into(db.courtCategories)
        .insert(
          const CourtCategoriesCompanion(
            id: Value(categoryId),
            nameKey: Value('courtCategory_appellateDivision'),
            courtLevel: Value('appellate'),
            orderIndex: Value(1),
            updatedAt: Value(1),
          ),
        );
    courtId = 'acceptance-court';
    await db
        .into(db.courts)
        .insert(
          const CourtsCompanion(
            id: Value('acceptance-court'),
            courtName: Value('Acceptance High Court'),
            higherLowerCourts: Value('higher_courts'),
            courtCategoryId: Value(categoryId),
            updatedAt: Value(1),
          ),
        );
    await db
        .into(db.caseCategories)
        .insert(
          const CaseCategoriesCompanion(
            id: Value(caseCategoryId),
            courtCategoryId: Value(categoryId),
            name: Value('Acceptance Civil Cases'),
            orderIndex: Value(1),
            updatedAt: Value(1),
          ),
        );
    await db
        .into(db.caseTypes)
        .insert(
          const CaseTypesCompanion(
            id: Value('acceptance-case-type'),
            courtCategoryId: Value(categoryId),
            caseCategoryId: Value(caseCategoryId),
            name: Value('Civil'),
            orderIndex: Value(1),
            updatedAt: Value(1),
          ),
        );
    onBehalfId = 'acceptance-on-be-half';
    await db
        .into(db.onBehalfs)
        .insert(
          const OnBehalfsCompanion(
            id: Value('acceptance-on-be-half'),
            courtCategoryId: Value(categoryId),
            name: Value('Plaintiff'),
            orderIndex: Value(1),
            updatedAt: Value(1),
          ),
        );

    await db
        .into(db.courtCategories)
        .insert(
          const CourtCategoriesCompanion(
            id: Value(highCourtDivisionId),
            nameKey: Value('courtCategory_highCourtDivision'),
            courtLevel: Value('appellate'),
            orderIndex: Value(2),
            updatedAt: Value(1),
          ),
        );
    await db
        .into(db.courts)
        .insert(
          const CourtsCompanion(
            id: Value('acceptance-hcd-court'),
            courtName: Value('Acceptance High Court Division'),
            higherLowerCourts: Value('higher_courts'),
            courtCategoryId: Value(highCourtDivisionId),
            updatedAt: Value(1),
          ),
        );
    await db
        .into(db.caseCategories)
        .insert(
          const CaseCategoriesCompanion(
            id: Value('acceptance-hcd-case-category'),
            courtCategoryId: Value(highCourtDivisionId),
            name: Value('Acceptance High Court Cases'),
            orderIndex: Value(1),
            updatedAt: Value(1),
          ),
        );
    await db
        .into(db.caseTypes)
        .insert(
          const CaseTypesCompanion(
            id: Value('acceptance-hcd-case-type'),
            courtCategoryId: Value(highCourtDivisionId),
            caseCategoryId: Value('acceptance-hcd-case-category'),
            name: Value('High Court Civil'),
            orderIndex: Value(1),
            updatedAt: Value(1),
          ),
        );
    await db
        .into(db.onBehalfs)
        .insert(
          const OnBehalfsCompanion(
            id: Value('acceptance-hcd-on-be-half'),
            courtCategoryId: Value(highCourtDivisionId),
            name: Value('Petitioner'),
            orderIndex: Value(1),
            updatedAt: Value(1),
          ),
        );

    lookupData = await loadLookupData();
    caseRepository = LocalCaseRepository(
      CasesDao(db),
      CaseHistoryDao(db),
      syncHelper,
    );
  });

  tearDown(() async => db.close());

  SettingsRepository settingsRepository() =>
      LocalSettingsRepository(UserPreferencesDao(db), identity);

  /// The app's providers under a plain [MaterialApp] (`child`) or a
  /// [MaterialApp.router] (`router`) — the free-tier gate needs the latter,
  /// because it navigates with `context.push`.
  ProviderScope appScope(
    Widget? child, {
    CaseWritePermissions permissions = const CaseWritePermissions(
      canAdd: true,
      canEdit: true,
    ),
    Locale locale = const Locale('en'),
    GoRouter? router,
  }) {
    assert(
      (child == null) != (router == null),
      'pass exactly one of child and router',
    );
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWith((_) async => db),
        syncWriteHelperProvider.overrideWith((_) async => syncHelper),
        localIdentityServiceProvider.overrideWith((_) => identity),
        caseRepositoryProvider.overrideWith((_) async => caseRepository),
        transactionalCaseRepositoryProvider.overrideWith(
          (_) async => caseRepository,
        ),
        settingsRepositoryProvider.overrideWith(
          (_) async => settingsRepository(),
        ),
        caseWritePermissionsProvider.overrideWith((_) async => permissions),
      ],
      child: router == null
          ? MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: locale,
              home: child,
            )
          : MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: locale,
              routerConfig: router,
            ),
    );
  }

  /// Opens the Add Case form under a router that can reach the paywall.
  ///
  /// The sheet is opened the way the app opens it — as a modal route of its own
  /// — because the gate navigates relative to the sheet and a successful save
  /// pops the sheet's route; a form mounted as the root body has no route to
  /// pop and would take the whole tree with it.
  Future<void> openFormWithPaywall(WidgetTester tester) async {
    final host = Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          key: const ValueKey('open-task07-form'),
          onPressed: () => AddEditCaseSheet.show<void>(
            context,
            lookupData: lookupData,
            initialNextDate: DateTime(2026, 7, 31),
          ),
          child: const Text('Open form'),
        ),
      ),
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => host),
        GoRoute(
          path: AppRoutes.paywall,
          // Mirror the app router: the limit card shows only when the gate
          // named its reason (`?reason=limit`).
          builder: (context, state) =>
              PaywallScreen(showLimit: PaywallScreen.showLimitFor(state)),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(appScope(null, router: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-task07-form')));
    await tester.pumpAndSettle();
  }

  /// Inserts [count] live cases, for tests that start near the free limit.
  Future<List<Case>> seedLiveCases(int count, {String prefix = 'SEED'}) async {
    final ids = <String>[];
    for (var index = 0; index < count; index++) {
      ids.add(
        await caseRepository.insertCase(
          CasesCompanion(
            caseNumber: Value('$prefix-$index'),
            petitioner: const Value('Alice'),
            respondent: const Value('Bob'),
            courtId: Value(courtId),
            caseType: const Value('Civil'),
            onBehalfId: Value(onBehalfId),
          ),
        ),
      );
    }
    return [for (final id in ids) (await caseRepository.getById(id))!];
  }

  /// Fills the minimum an acceptance-division case needs and saves it.
  Future<void> fillAndSaveAcceptanceCase(
    WidgetTester tester, {
    required String caseNumber,
  }) async {
    await _select(tester, const ValueKey('add-edit-higher-lower-court'));
    await tester.tap(find.byKey(const ValueKey('appellate_division')));
    await tester.pumpAndSettle();
    await _select(tester, const ValueKey('add-edit-name-of-court'));
    await tester.tap(find.text('Acceptance High Court'));
    await tester.pumpAndSettle();
    await _selectAcceptanceCaseCategory(tester);
    await _select(tester, const ValueKey('add-edit-case-type'));
    await tester.tap(find.text('Civil'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('add-edit-case-number')),
      caseNumber,
    );
    await tester.tap(find.byKey(const ValueKey('add-edit-save')));
    await tester.pumpAndSettle();
  }

  Future<void> openForm(
    WidgetTester tester, {
    Case? initialCase,
    DateTime? initialNextDate,
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      appScope(
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              key: const ValueKey('open-task07-form'),
              onPressed: () => AddEditCaseSheet.show<void>(
                context,
                initialCase: initialCase,
                lookupData: lookupData,
                initialNextDate: initialNextDate,
              ),
              child: const Text('Open form'),
            ),
          ),
        ),
        locale: locale,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-task07-form')));
    await tester.pumpAndSettle();
  }

  testWidgets('On Behalf options follow the active language', (
    WidgetTester tester,
  ) async {
    // A pre-seeded option, stored the way the seeder stores it: stable seed ID
    // with the English name, so only the seed data holds its Bengali label.
    const seededId = 'onbehalf-high_court_division-petitioner';
    await db
        .into(db.onBehalfs)
        .insert(
          const OnBehalfsCompanion(
            id: Value(seededId),
            courtCategoryId: Value(highCourtDivisionId),
            name: Value('Petitioner'),
            orderIndex: Value(2),
            updatedAt: Value(1),
          ),
        );
    lookupData = await loadLookupData();

    final id = await caseRepository.insertCase(
      CasesCompanion(
        caseNumber: const Value('ON-BEHALF-1'),
        petitioner: const Value('Alice'),
        respondent: const Value('Bob'),
        courtId: const Value('acceptance-hcd-court'),
        caseType: const Value('High Court Civil'),
        onBehalfId: const Value(seededId),
        nextDate: const Value(1),
      ),
    );
    final current = (await caseRepository.getById(id))!;

    await openForm(tester, initialCase: current, locale: const Locale('bn'));
    await _select(tester, const ValueKey('add-edit-on-behalf'));

    // The picker lists the Bengali label, not the stored English name.
    final bengali = onBehalfLabelBn[seededId]!;
    expect(bengali, isNot('Petitioner'));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('custom-dropdown-dialog')),
        matching: find.text(bengali),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Save validates mandatory fields before writing', (
    WidgetTester tester,
  ) async {
    await openForm(tester);
    await tester.tap(find.byKey(const ValueKey('add-edit-save')));
    await tester.pump();

    expect(find.text('Higher or Lower Court is required'), findsOneWidget);
    expect(await CasesDao(db).getAll(), isEmpty);
  });

  testWidgets('firm permissions disable Add/Edit controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      appScope(
        const AddEditCaseSheet(lookupData: AddEditCaseLookupData()),
        permissions: const CaseWritePermissions(canAdd: false, canEdit: false),
      ),
    );
    await tester.pumpAndSettle();

    final save = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('add-edit-save')),
    );
    expect(save.onPressed, isNull);
  });

  test('cached firm membership resolves write permissions', () async {
    final userId = identity.getId();
    await db
        .into(db.profiles)
        .insert(
          ProfilesCompanion(
            id: Value(userId),
            fullName: const Value('Firm Associate'),
            firmId: const Value('firm-1'),
            role: const Value('associate'),
            subscriptionStatus: const Value('free'),
            createdAt: const Value(1),
          ),
        );
    await db
        .into(db.firmMembers)
        .insert(
          FirmMembersCompanion(
            id: const Value('member-1'),
            firmId: const Value('firm-1'),
            userId: Value(userId),
            role: const Value('associate'),
            canAdd: const Value(false),
            canEdit: const Value(true),
          ),
        );

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((_) async => db),
        localIdentityServiceProvider.overrideWith((_) => identity),
      ],
    );
    addTearDown(container.dispose);

    final permissions = await container.read(
      caseWritePermissionsProvider.future,
    );
    expect(permissions.canAdd, isFalse);
    expect(permissions.canEdit, isTrue);
  });

  test('premium access derives from expiry and firm expiry', () async {
    final userId = identity.getId();
    final now = DateTime.utc(2026, 8, 1, 12);
    await db
        .into(db.profiles)
        .insert(
          ProfilesCompanion(
            id: Value(userId),
            fullName: const Value('Premium User'),
            role: const Value('individual'),
            subscriptionStatus: const Value('free'),
            subscriptionExpiry: Value(
              now.add(const Duration(hours: 24)).millisecondsSinceEpoch,
            ),
            createdAt: const Value(1),
          ),
        );
    expect(await resolvePremiumAccess(db, userId, now: now), isTrue);

    await db
        .update(db.profiles)
        .write(
          ProfilesCompanion(
            id: Value(userId),
            subscriptionStatus: const Value('premium'),
            subscriptionExpiry: Value(
              now.subtract(const Duration(hours: 49)).millisecondsSinceEpoch,
            ),
          ),
        );
    // A stale display status cannot grant access after the grace period.
    expect(await resolvePremiumAccess(db, userId, now: now), isFalse);

    await db
        .into(db.firms)
        .insert(
          FirmsCompanion(
            id: const Value('firm-premium'),
            name: const Value('Premium Firm'),
            ownerId: const Value('owner-1'),
            subscriptionStatus: const Value('premium'),
            subscriptionExpiry: Value(
              now.add(const Duration(hours: 1)).millisecondsSinceEpoch,
            ),
            createdAt: const Value(1),
          ),
        );
    await db
        .update(db.profiles)
        .write(
          ProfilesCompanion(
            id: Value(userId),
            firmId: const Value('firm-premium'),
            subscriptionExpiry: Value(
              now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
            ),
          ),
        );
    // Firm associates inherit the firm's mirrored expiry, not their profile.
    expect(await resolvePremiumAccess(db, userId, now: now), isTrue);
  });

  testWidgets('Quick Update denies save when edit permission is absent', (
    WidgetTester tester,
  ) async {
    final id = await caseRepository.insertCase(
      CasesCompanion(
        caseNumber: const Value('DENIED-1'),
        petitioner: const Value('Alice'),
        respondent: const Value('Bob'),
        courtId: Value(courtId),
        caseType: const Value('Civil'),
        onBehalfId: Value(onBehalfId),
        nextDate: const Value(1),
      ),
    );
    final current = (await caseRepository.getById(id))!;

    await tester.pumpWidget(
      appScope(
        QuickUpdateCaseDialog(currentCase: current, canEdit: false),
        permissions: const CaseWritePermissions(canAdd: true, canEdit: false),
      ),
    );
    await tester.pumpAndSettle();

    final save = tester.widget<FilledButton>(find.byType(FilledButton).last);
    expect(save.onPressed, isNull);
    expect((await caseRepository.getById(id))!.nextDate, 1);
    expect(await CaseHistoryDao(db).getByCaseId(id), isEmpty);
  });

  testWidgets(
    'Quick Update keeps the current date separate and shows Result for AD/HCD',
    (WidgetTester tester) async {
      final currentDate = DateTime(2026, 8, 5);
      final id = await caseRepository.insertCase(
        CasesCompanion(
          caseNumber: const Value('205/23'),
          petitioner: const Value('Alice'),
          respondent: const Value('Bob'),
          courtId: Value(courtId),
          caseType: const Value('Civil Suit'),
          onBehalfId: Value(onBehalfId),
          nextDate: Value(currentDate.millisecondsSinceEpoch),
        ),
      );
      final current = (await caseRepository.getById(id))!;

      await tester.pumpWidget(
        appScope(QuickUpdateCaseDialog(currentCase: current)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Civil Suit 205/23'), findsOneWidget);
      expect(find.text('Current Next Date: 05/08/26, Wed'), findsOneWidget);
      expect(find.text('Next Date'), findsOneWidget);
      expect(find.text('Pick a date'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('quick-update-notification')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('quick-update-day-offset')),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.widgetWithText(FilledButton, 'Save')).height,
        closeTo(52, 0.1),
      );

      await tester.tap(find.byKey(const ValueKey('quick-update-day-offset')));
      await tester.pumpAndSettle();
      expect(find.text('The same day'), findsAtLeastNWidgets(1));
      // The field mirrors the Settings offset, so this label can appear twice.
      expect(find.text('The day before'), findsAtLeastNWidgets(1));
      expect(find.text('Before 3 days'), findsOneWidget);
      expect(find.text('Before 7 days'), findsOneWidget);
      expect(find.text('Before 15 days'), findsOneWidget);
      expect(find.text('Before 30 days'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('settings-picker-close')));
      await tester.pumpAndSettle();

      // AD/HCD cases hide the Step picker and show the Result field instead.
      expect(find.byKey(const ValueKey('quick-update-result')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick-update-step')), findsNothing);

      // This case has no notification choice of its own, so its toggle starts
      // from the Settings default — off in this harness. The Settings switch is
      // the default a case starts from, not a veto, so switching the case on
      // here is what makes it alert.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('quick-update-notification')),
          matching: find.byIcon(Icons.notifications_none),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('quick-update-notification')));
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect((await caseRepository.getById(id))!.nextDate, current.nextDate);
      final preference = await CaseNotificationPreferencesDao(
        db,
      ).get(identity.getId(), id);
      // Switched on for this one case, while the Settings default stays off.
      expect(preference?.enabled, isTrue);
      // Untouched Day Offset mirrors Settings → Notifications (default: the
      // day before), the same rule the Add/Edit form follows.
      expect(preference?.offsets, '[1]');
    },
  );

  testWidgets('the Quick Update day offsets carry Bengali digits', (
    WidgetTester tester,
  ) async {
    final id = await caseRepository.insertCase(
      CasesCompanion(
        caseNumber: const Value('306/23'),
        petitioner: const Value('Alice'),
        respondent: const Value('Bob'),
        courtId: Value(courtId),
        caseType: const Value('Civil Suit'),
        onBehalfId: Value(onBehalfId),
        nextDate: Value(DateTime(2026, 8, 5).millisecondsSinceEpoch),
      ),
    );
    final current = (await caseRepository.getById(id))!;

    await tester.pumpWidget(
      appScope(
        QuickUpdateCaseDialog(currentCase: current),
        locale: const Locale('bn'),
      ),
    );
    await tester.pumpAndSettle();

    // The Update window shares the Select Day Offset window's 8 px corners.
    final windowShape =
        tester.widget<Dialog>(find.byType(Dialog)).shape
            as RoundedRectangleBorder;
    expect(windowShape.borderRadius, BorderRadius.circular(8));

    await tester.tap(find.byKey(const ValueKey('quick-update-day-offset')));
    await tester.pumpAndSettle();

    // The day count follows the active language's digits, like Settings →
    // Notifications, instead of the raw number in a Bengali sentence.
    expect(find.text('২ দিন আগে'), findsOneWidget);
    expect(find.text('৩০ দিন আগে'), findsOneWidget);
    expect(find.text('2 দিন আগে'), findsNothing);
  });

  testWidgets('Add case routes to paywall at the free-tier limit', (
    WidgetTester tester,
  ) async {
    for (var index = 0; index < 50; index++) {
      await caseRepository.insertCase(
        CasesCompanion(
          caseNumber: Value('LIMIT-$index'),
          petitioner: const Value('Alice'),
          respondent: const Value('Bob'),
          courtId: Value(courtId),
          caseType: const Value('Civil'),
          onBehalfId: Value(onBehalfId),
        ),
      );
    }

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: AddEditCaseSheet(
              lookupData: lookupData,
              initialNextDate: DateTime(2026, 7, 31),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.paywall,
          // Mirror the app router: the limit card shows only when the gate
          // named its reason (`?reason=limit`).
          builder: (context, state) =>
              PaywallScreen(showLimit: PaywallScreen.showLimitFor(state)),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWith((_) async => db),
          syncWriteHelperProvider.overrideWith((_) async => syncHelper),
          localIdentityServiceProvider.overrideWith((_) => identity),
          caseRepositoryProvider.overrideWith((_) async => caseRepository),
          settingsRepositoryProvider.overrideWith(
            (_) async => settingsRepository(),
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
    await _select(tester, const ValueKey('add-edit-higher-lower-court'));
    await tester.tap(find.byKey(const ValueKey('appellate_division')));
    await tester.pumpAndSettle();
    await _select(tester, const ValueKey('add-edit-name-of-court'));
    await tester.tap(find.text('Acceptance High Court'));
    await tester.pumpAndSettle();
    await _selectAcceptanceCaseCategory(tester);
    await _select(tester, const ValueKey('add-edit-case-type'));
    await tester.tap(find.text('Civil'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('add-edit-case-number')),
      '123456/2051',
    );
    await tester.tap(find.byKey(const ValueKey('add-edit-save')));
    await tester.pumpAndSettle();

    // The gate lands on the real paywall, which says why it opened.
    expect(find.byType(PaywallScreen), findsOneWidget);
    expect(find.text('Free Plan Limit Reached'), findsOneWidget);
    expect(await CasesDao(db).getNonDeletedCaseCount(), 50);
  });

  testWidgets('Premium expiry bypasses the free-tier paywall in the form', (
    WidgetTester tester,
  ) async {
    for (var index = 0; index < 50; index++) {
      await caseRepository.insertCase(
        CasesCompanion(
          caseNumber: Value('PREMIUM-$index'),
          petitioner: const Value('Alice'),
          respondent: const Value('Bob'),
          courtId: Value(courtId),
          caseType: const Value('Civil'),
          onBehalfId: Value(onBehalfId),
        ),
      );
    }
    final now = DateTime.now().toUtc();
    await db
        .into(db.profiles)
        .insert(
          ProfilesCompanion(
            id: Value(identity.getId()),
            fullName: const Value('Premium Individual'),
            role: const Value('individual'),
            subscriptionStatus: const Value('free'),
            subscriptionExpiry: Value(
              now.add(const Duration(hours: 24)).millisecondsSinceEpoch,
            ),
            createdAt: const Value(1),
          ),
        );

    await openForm(tester, initialNextDate: now);
    await _select(tester, const ValueKey('add-edit-higher-lower-court'));
    await tester.tap(find.byKey(const ValueKey('appellate_division')));
    await tester.pumpAndSettle();
    await _select(tester, const ValueKey('add-edit-name-of-court'));
    await tester.tap(find.text('Acceptance High Court'));
    await tester.pumpAndSettle();
    await _selectAcceptanceCaseCategory(tester);
    await _select(tester, const ValueKey('add-edit-case-type'));
    await tester.tap(find.text('Civil'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('add-edit-case-number')),
      '123456/2051',
    );
    await tester.tap(find.byKey(const ValueKey('add-edit-save')));
    await tester.pumpAndSettle();

    expect(find.byType(PaywallScreen), findsNothing);
    expect(await CasesDao(db).getNonDeletedCaseCount(), 51);
  });

  testWidgets('soft-deleted cases never count against the free limit', (
    WidgetTester tester,
  ) async {
    // 51 rows exist, but two are tombstones: the limit counts live cases only,
    // so this database is two cases below the gate, not one above it.
    final seeded = await seedLiveCases(51, prefix: 'TOMBSTONE');
    await caseRepository.deleteCase(seeded[0]);
    await caseRepository.deleteCase(seeded[1]);
    expect(await CasesDao(db).getNonDeletedCaseCount(), 49);

    await openFormWithPaywall(tester);
    await fillAndSaveAcceptanceCase(tester, caseNumber: 'FIFTIETH/2026');

    expect(find.byType(PaywallScreen), findsNothing);
    expect(await CasesDao(db).getNonDeletedCaseCount(), 50);
  });

  testWidgets('deleting a case makes room under the free limit', (
    WidgetTester tester,
  ) async {
    final seeded = await seedLiveCases(50, prefix: 'FULL');

    // At exactly 50 live cases a free user is blocked, and the paywall says so.
    await openFormWithPaywall(tester);
    await fillAndSaveAcceptanceCase(tester, caseNumber: 'BLOCKED/2026');
    expect(find.byType(PaywallScreen), findsOneWidget);
    expect(await CasesDao(db).getNonDeletedCaseCount(), 50);

    // The way back is a delete, not a payment: a soft-deleted case never counts.
    await caseRepository.deleteCase(seeded.first);
    expect(await CasesDao(db).getNonDeletedCaseCount(), 49);

    await openFormWithPaywall(tester);
    await fillAndSaveAcceptanceCase(tester, caseNumber: 'MADE-ROOM/2026');
    expect(find.byType(PaywallScreen), findsNothing);
    expect(await CasesDao(db).getNonDeletedCaseCount(), 50);
  });

  testWidgets('editing a case is never gated by the free limit', (
    WidgetTester tester,
  ) async {
    // One case the form can actually reopen: the bare seeded rows carry no case
    // category or next date, and an edit passes the same mandatory-field
    // validation the form always applies.
    final editableId = await caseRepository.insertCase(
      CasesCompanion(
        caseNumber: const Value('EDITABLE-1'),
        petitioner: const Value('Alice'),
        respondent: const Value('Bob'),
        courtId: Value(courtId),
        caseCategoryId: const Value('acceptance-case-category'),
        caseType: const Value('Civil'),
        onBehalfId: Value(onBehalfId),
        nextDate: const Value(1),
      ),
    );
    final existing = (await caseRepository.getById(editableId))!;
    await seedLiveCases(49, prefix: 'EDIT');
    expect(await CasesDao(db).getNonDeletedCaseCount(), 50);

    // A lapsed-premium user with 200 cases keeps every one of them editable,
    // viewable and deletable — only *adding* past the limit is gated.
    await openForm(tester, initialCase: existing);
    await tester.enterText(
      find.byKey(const ValueKey('add-edit-case-number')),
      'EDITED/2026',
    );
    await tester.tap(find.byKey(const ValueKey('add-edit-save')));
    await tester.pumpAndSettle();

    expect(find.byType(PaywallScreen), findsNothing);
    expect(
      (await CasesDao(db).getById(existing.id))?.caseNumber,
      'EDITED/2026',
    );
    expect(await CasesDao(db).getNonDeletedCaseCount(), 50);
  });

  testWidgets('Add and Edit persist the case and notification JSON', (
    WidgetTester tester,
  ) async {
    await openForm(tester, initialNextDate: DateTime(2026, 7, 31));
    await _select(tester, const ValueKey('add-edit-higher-lower-court'));
    await tester.tap(find.byKey(const ValueKey('appellate_division')));
    await tester.pumpAndSettle();
    await _select(tester, const ValueKey('add-edit-name-of-court'));
    await tester.tap(find.text('Acceptance High Court'));
    await tester.pumpAndSettle();
    await _selectAcceptanceCaseCategory(tester);
    await _select(tester, const ValueKey('add-edit-case-type'));
    await tester.tap(find.text('Civil'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('add-edit-case-number')),
      '123456789/2026',
    );
    // Offset 1 is selected because the form mirrors Settings → Notifications
    // (whose default is "the day before"); add the second offset.
    await _selectOffsets(tester, const [3]);
    await tester.tap(find.byKey(const ValueKey('add-edit-save')));
    await tester.pumpAndSettle();

    final added = (await CasesDao(db).getAll()).single;
    expect(added.caseNumber, '123456789/2026');
    final preference = await CaseNotificationPreferencesDao(
      db,
    ).get(identity.getId(), added.id);
    expect(preference?.offsets, '[1,3]');
    expect(await CaseHistoryDao(db).getByCaseId(added.id), isEmpty);

    await openForm(tester, initialCase: added);
    await tester.enterText(
      find.byKey(const ValueKey('add-edit-case-number')),
      '987654321/2027',
    );
    await tester.tap(find.byKey(const ValueKey('add-edit-save')));
    await tester.pumpAndSettle();

    final edited = await CasesDao(db).getById(added.id);
    expect(edited?.caseNumber, '987654321/2027');
    expect(await CaseHistoryDao(db).getByCaseId(added.id), isEmpty);
  });

  testWidgets('the Day Offset mirrors the stored notification setting', (
    WidgetTester tester,
  ) async {
    await settingsRepository().upsertSettings(
      const UserSettings(notificationDayOffset: 15),
    );

    // No injected lookup data: this is the app's real load path, which reads
    // the per-user preference row for the Day Offset default.
    await tester.pumpWidget(
      appScope(
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              key: const ValueKey('open-task07-form'),
              onPressed: () => AddEditCaseSheet.show<void>(context),
              child: const Text('Open form'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-task07-form')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('add-edit-day-offset')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Before 15 days'), findsOneWidget);
  });

  testWidgets(
    'the Notification Time follows Settings and is overridden per case',
    (WidgetTester tester) async {
      await settingsRepository().upsertSettings(
        const UserSettings(notificationTime: 9 * 60 + 30),
      );

      // The real load path, so the default time comes from the stored settings.
      await tester.pumpWidget(
        appScope(
          Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const ValueKey('open-task07-form'),
                onPressed: () => AddEditCaseSheet.show<void>(context),
                child: const Text('Open form'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open-task07-form')));
      await tester.pumpAndSettle();

      final timeField = find.byKey(
        const ValueKey('add-edit-notification-time'),
      );
      await tester.scrollUntilVisible(
        timeField,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      // scrollUntilVisible stops as soon as the field is technically on screen,
      // which leaves it under the sheet's footer; lift it clear so the tap lands.
      await tester.drag(
        find.byKey(const ValueKey('add-edit-form-scroll')),
        const Offset(0, -160),
      );
      await tester.pumpAndSettle();
      // Day Offset and Notification Time share the one line.
      expect(
        tester.getCenter(find.byKey(const ValueKey('add-edit-day-offset'))).dx,
        lessThan(tester.getCenter(timeField).dx),
      );
      // Following the default, and nothing to reset yet.
      expect(find.text('09:30 AM'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('add-edit-notification-time-reset')),
        findsNothing,
      );

      await _pickNotificationTime(
        tester,
        const ValueKey('add-edit-notification-time'),
        hour: 11,
        minute: 5,
      );

      // The case's own time replaces the default, and can be handed back.
      expect(find.text('11:05 AM'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('add-edit-notification-time-reset')),
      );
      await tester.pumpAndSettle();
      expect(find.text('09:30 AM'), findsOneWidget);
    },
  );

  testWidgets('Quick Update overrides the notification time for one case', (
    WidgetTester tester,
  ) async {
    await settingsRepository().upsertSettings(
      const UserSettings(notificationTime: 9 * 60 + 30),
    );
    final id = await caseRepository.insertCase(
      CasesCompanion(
        caseNumber: const Value('410/23'),
        petitioner: const Value('Alice'),
        respondent: const Value('Bob'),
        courtId: Value(courtId),
        caseType: const Value('Civil Suit'),
        onBehalfId: Value(onBehalfId),
        nextDate: Value(DateTime(2026, 8, 5).millisecondsSinceEpoch),
      ),
    );
    final current = (await caseRepository.getById(id))!;

    await tester.pumpWidget(
      appScope(QuickUpdateCaseDialog(currentCase: current)),
    );
    await tester.pumpAndSettle();

    // Same control as the form: the Settings time until it is overridden.
    expect(find.text('09:30 AM'), findsOneWidget);
    await _pickNotificationTime(
      tester,
      const ValueKey('quick-update-notification-time'),
      hour: 11,
      minute: 5,
    );
    expect(find.text('11:05 AM'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final preference = await CaseNotificationPreferencesDao(
      db,
    ).get(identity.getId(), id);
    expect(preference?.timeMinutes, 11 * 60 + 5);
  });

  testWidgets('High Court fields persist and restore in edit mode', (
    WidgetTester tester,
  ) async {
    await openForm(tester, initialNextDate: DateTime(2026, 8, 1));
    await _select(tester, const ValueKey('add-edit-higher-lower-court'));
    await tester.tap(find.byKey(const ValueKey(highCourtDivisionId)));
    await tester.pumpAndSettle();
    await _select(tester, const ValueKey('add-edit-name-of-court'));
    await tester.tap(find.text('Acceptance High Court Division'));
    await tester.pumpAndSettle();
    await _select(tester, const ValueKey('add-edit-case-category'));
    await tester.tap(find.text('Acceptance High Court Cases'));
    await tester.pumpAndSettle();
    await _select(tester, const ValueKey('add-edit-case-type'));
    await tester.tap(find.text('High Court Civil'));
    await tester.pumpAndSettle();

    await _enterFormText(
      tester,
      const ValueKey('add-edit-honorable-judges'),
      'Justice Example',
    );
    await _enterFormText(
      tester,
      const ValueKey('add-edit-tender-number'),
      '00123',
    );
    await _enterFormText(
      tester,
      const ValueKey('add-edit-previous-court-case'),
      'Previous-9',
    );
    await _enterFormText(
      tester,
      const ValueKey('add-edit-district-of-origin'),
      'Dhaka',
    );
    await _enterFormText(
      tester,
      const ValueKey('add-edit-case-number'),
      'HCD-1',
    );
    await _enterFormText(
      tester,
      const ValueKey('add-edit-result'),
      'Disposed by order',
    );
    await tester.tap(find.byKey(const ValueKey('add-edit-save')));
    await tester.pumpAndSettle();

    final added = (await CasesDao(db).getAll()).single;
    expect(added.caseCategoryId, 'acceptance-hcd-case-category');
    expect(added.honorableJudges, 'Justice Example');
    expect(added.tenderNumber, '00123');
    expect(added.previousCourtCase, 'Previous-9');
    expect(added.districtOfOrigin, 'Dhaka');
    expect(added.result, 'Disposed by order');
    expect((await caseRepository.listDisposed()).single.id, added.id);

    await openForm(tester, initialCase: added);
    expect(
      await _formFieldText(tester, const ValueKey('add-edit-honorable-judges')),
      'Justice Example',
    );
    expect(
      await _formFieldText(tester, const ValueKey('add-edit-tender-number')),
      '00123',
    );
    expect(
      await _formFieldText(
        tester,
        const ValueKey('add-edit-previous-court-case'),
      ),
      'Previous-9',
    );
    expect(
      await _formFieldText(
        tester,
        const ValueKey('add-edit-district-of-origin'),
      ),
      'Dhaka',
    );
    expect(
      await _formFieldText(tester, const ValueKey('add-edit-result')),
      'Disposed by order',
    );
  });

  testWidgets('case cards show On Behalf and Step in the active language', (
    WidgetTester tester,
  ) async {
    // Pre-seeded rows the way the seeder stores them: stable seed ID with the
    // English name, and steps saved on the case as comma-joined names.
    const seededRoleId = 'onbehalf-high_court_division-petitioner';
    await db
        .into(db.onBehalfs)
        .insert(
          const OnBehalfsCompanion(
            id: Value(seededRoleId),
            courtCategoryId: Value(highCourtDivisionId),
            name: Value('Petitioner'),
            orderIndex: Value(2),
            updatedAt: Value(1),
          ),
        );
    const storedStep = 'Arrival';
    final cardCaseId = await caseRepository.insertCase(
      CasesCompanion(
        caseNumber: const Value('BN-CARD-1'),
        petitioner: const Value('Alice'),
        respondent: const Value('Bob'),
        courtId: Value(courtId),
        caseType: const Value('Civil'),
        onBehalfId: const Value(seededRoleId),
        lastStep: const Value(storedStep),
        nextDate: Value(DateTime(2026, 8, 5).millisecondsSinceEpoch),
      ),
    );

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const AllCasesScreen()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWith((_) async => db),
          syncWriteHelperProvider.overrideWith((_) async => syncHelper),
          localIdentityServiceProvider.overrideWith((_) => identity),
          caseRepositoryProvider.overrideWith((_) async => caseRepository),
          settingsRepositoryProvider.overrideWith(
            (_) async => settingsRepository(),
          ),
          caseWritePermissionsProvider.overrideWith(
            (_) async =>
                const CaseWritePermissions(canAdd: true, canEdit: true),
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('bn'),
          routerConfig: router,
        ),
      ),
    );
    await _pumpUntil(tester, find.byKey(ValueKey('case-card-$cardCaseId')));

    // The role chip and the step line are seed labels, not stored English.
    final role = onBehalfLabelBn[seededRoleId]!;
    final step = stepLabelBnByToken[storedStep]!;
    expect(role, isNot('Petitioner'));
    expect(step, isNot(storedStep));
    expect(find.text(role), findsOneWidget);
    expect(find.text(step), findsOneWidget);

    // Unmount inside the test body so the drift stream-cleanup zero-timer from
    // AllCasesScreen's watch fires before the framework checks for pending
    // timers at teardown.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('a seeded court name on the card follows the active language', (
    WidgetTester tester,
  ) async {
    // The database stores the seed's English name, so the card has to resolve
    // it through the seed lookup exactly like the form's court dropdown does.
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
    final cardCaseId = await caseRepository.insertCase(
      CasesCompanion(
        caseNumber: const Value('BN-COURT-1'),
        petitioner: const Value('Alice'),
        respondent: const Value('Bob'),
        courtId: Value(seed.id),
        caseType: const Value('Civil'),
        onBehalfId: Value(onBehalfId),
        nextDate: Value(DateTime(2026, 8, 5).millisecondsSinceEpoch),
      ),
    );

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const AllCasesScreen()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWith((_) async => db),
          syncWriteHelperProvider.overrideWith((_) async => syncHelper),
          localIdentityServiceProvider.overrideWith((_) => identity),
          caseRepositoryProvider.overrideWith((_) async => caseRepository),
          settingsRepositoryProvider.overrideWith(
            (_) async => settingsRepository(),
          ),
          caseWritePermissionsProvider.overrideWith(
            (_) async =>
                const CaseWritePermissions(canAdd: true, canEdit: true),
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('bn'),
          routerConfig: router,
        ),
      ),
    );
    await _pumpUntil(tester, find.byKey(ValueKey('case-card-$cardCaseId')));

    expect(find.text(seed.courtNameBn), findsOneWidget);
    expect(find.text(seed.courtNameEn), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('All Cases Update action opens the Quick Update dialog', (
    WidgetTester tester,
  ) async {
    final listCaseNextDate = DateTime(2026, 8, 5).millisecondsSinceEpoch;
    final listCaseId = await caseRepository.insertCase(
      CasesCompanion(
        caseNumber: const Value('LIST-1'),
        petitioner: const Value('Alice'),
        respondent: const Value('Bob'),
        courtId: Value(courtId),
        caseType: const Value('Civil'),
        onBehalfId: Value(onBehalfId),
        partyPhone: const Value('+8801712345678'),
        nextDate: Value(listCaseNextDate),
      ),
    );

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const AllCasesScreen()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWith((_) async => db),
          syncWriteHelperProvider.overrideWith((_) async => syncHelper),
          localIdentityServiceProvider.overrideWith((_) => identity),
          caseRepositoryProvider.overrideWith((_) async => caseRepository),
          settingsRepositoryProvider.overrideWith(
            (_) async => settingsRepository(),
          ),
          caseWritePermissionsProvider.overrideWith(
            (_) async =>
                const CaseWritePermissions(canAdd: true, canEdit: true),
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await _pumpUntil(tester, find.byKey(ValueKey('case-card-$listCaseId')));
    expect(find.text('05/08/26, Wed'), findsOneWidget);
    expect(find.byTooltip('Phone'), findsOneWidget);
    expect(find.byTooltip('Message'), findsOneWidget);

    await tester.tap(find.byTooltip('Phone'));
    await tester.pumpAndSettle();
    expect(find.text('Open with'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('case-card-call-cancel')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Message'));
    await tester.pumpAndSettle();
    expect(find.text('Open with'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('case-card-message-cancel')));
    await tester.pumpAndSettle();

    final caseCardPhoneHeight = tester.getSize(find.byTooltip('Phone')).height;
    final caseCardMessageHeight = tester
        .getSize(find.byTooltip('Message'))
        .height;
    expect(caseCardPhoneHeight, caseCardMessageHeight);
    expect(
      tester.getSize(find.byType(FilledButton)).height,
      caseCardPhoneHeight,
    );

    await tester.tap(find.text('Update'));
    await tester.pump();
    await _pumpUntil(tester, find.byType(QuickUpdateCaseDialog));
    expect(find.byType(QuickUpdateCaseDialog), findsOneWidget);

    final saveFinder = find.widgetWithText(FilledButton, 'Save');
    await _pumpUntil(
      tester,
      saveFinder,
      condition: () =>
          tester.widget<FilledButton>(saveFinder).onPressed != null,
    );

    await tester.tap(saveFinder);
    await tester.pump(const Duration(milliseconds: 500));
    final updated = (await CasesDao(db).getById(listCaseId))!;
    expect(updated.nextDate, listCaseNextDate);
    // A blank Next Date leaves the existing date untouched and does not create
    // a date history entry; Quick Update can still change other fields.
    expect(await CaseHistoryDao(db).getByCaseId(updated.id), isEmpty);

    // Unmount the scope inside the test body so the drift stream-cleanup
    // zero-timer from AllCasesScreen's watch fires before the framework
    // checks for pending timers at teardown. A plain pump() does not elapse
    // fake time, so pump with a small duration to run the timer.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  bool Function()? condition,
}) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    if (finder.evaluate().isNotEmpty && (condition == null || condition())) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('Timed out waiting for expected widget state');
}

Future<void> _select(WidgetTester tester, Key key) async {
  final field = find.byKey(key);
  if (field.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      field,
      240,
      scrollable: find.byType(Scrollable).first,
    );
  }
  expect(field, findsOneWidget);
  await Scrollable.ensureVisible(
    tester.element(field),
    alignment: 0.5,
    duration: Duration.zero,
  );
  await tester.pump();
  await tester.tap(field);
  await tester.pumpAndSettle();
}

Future<void> _enterFormText(WidgetTester tester, Key key, String value) async {
  final field = find.byKey(key);
  if (field.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      field,
      240,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(
    tester.element(field),
    alignment: 0.5,
    duration: Duration.zero,
  );
  await tester.enterText(field, value);
}

Future<String?> _formFieldText(WidgetTester tester, Key key) async {
  final field = find.byKey(key);
  if (field.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      field,
      240,
      scrollable: find.byType(Scrollable).first,
    );
  }
  return tester.widget<TextFormField>(field).controller?.text;
}

Future<void> _selectOffsets(WidgetTester tester, List<int> offsets) async {
  await _select(tester, const ValueKey('add-edit-day-offset'));
  for (final offset in offsets) {
    final item = find.byKey(ValueKey<int>(offset));
    expect(item, findsOneWidget);
    await tester.tap(item);
    await tester.pumpAndSettle();
  }
  // The Settings-style window saves every tick; its header closes it.
  await tester.tap(find.byKey(const ValueKey('settings-picker-close')));
  await tester.pumpAndSettle();
}

Future<void> _selectAcceptanceCaseCategory(WidgetTester tester) async {
  await _select(tester, const ValueKey('add-edit-case-category'));
  await tester.tap(find.text('Acceptance Civil Cases'));
  await tester.pumpAndSettle();
}

/// Opens the shared notification-time window from [fieldKey] and types a time
/// through its keyboard entry — the only way a widget test can choose a value
/// on the dial.
Future<void> _pickNotificationTime(
  WidgetTester tester,
  Key fieldKey, {
  required int hour,
  required int minute,
}) async {
  await tester.tap(find.byKey(fieldKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.keyboard_outlined));
  await tester.pumpAndSettle();
  // The hour and minute cells are the last two text fields the window builds
  // after the hidden ones Flutter keeps for the dial's accessibility layer.
  final fields = find.byType(TextField);
  final count = fields.evaluate().length;
  await tester.enterText(fields.at(count - 2), '$hour');
  await tester.enterText(fields.at(count - 1), '$minute');
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}
