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
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/cases/data/case_repository.dart';
import 'package:legal_case_diary/features/cases/data/local/case_history_dao.dart';
import 'package:legal_case_diary/features/cases/data/local/cases_dao.dart';
import 'package:legal_case_diary/features/cases/presentation/all_cases/all_cases_screen.dart';
import 'package:legal_case_diary/features/settings/data/local/case_notification_preferences_dao.dart';
import 'package:legal_case_diary/features/settings/data/local/case_types_dao.dart';
import 'package:legal_case_diary/features/settings/data/local/court_categories_dao.dart';
import 'package:legal_case_diary/features/settings/data/local/courts_dao.dart';
import 'package:legal_case_diary/features/settings/data/local/on_behalfs_dao.dart';
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
  late SyncWriteHelper syncHelper;
  late LocalCaseRepository caseRepository;
  late AddEditCaseLookupData lookupData;
  late String courtId;
  late String onBehalfId;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    identity = LocalIdentityService(prefs);
    db = AppDatabase(NativeDatabase.memory());
    syncHelper = SyncWriteHelper(SyncQueueDao(db), identity);
    const categoryId = 'appellate_division';
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
        .into(db.caseTypes)
        .insert(
          const CaseTypesCompanion(
            id: Value('acceptance-case-type'),
            courtCategoryId: Value(categoryId),
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

    lookupData = AddEditCaseLookupData(
      courtCategories: await CourtCategoriesDao(db).getAll(),
      courts: await CourtsDao(db).getAll(),
      caseTypes: await CaseTypesDao(db).getAll(),
      onBehalfs: await OnBehalfsDao(db).getAll(),
      notificationOffsets: const [0, 1, 3],
    );
    caseRepository = LocalCaseRepository(
      CasesDao(db),
      CaseHistoryDao(db),
      syncHelper,
    );
  });

  tearDown(() async => db.close());

  SettingsRepository settingsRepository() =>
      LocalSettingsRepository(UserPreferencesDao(db), identity);

  ProviderScope appScope(
    Widget child, {
    CaseWritePermissions permissions = const CaseWritePermissions(
      canAdd: true,
      canEdit: true,
    ),
  }) {
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
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: child,
      ),
    );
  }

  Future<void> openForm(
    WidgetTester tester, {
    Case? initialCase,
    DateTime? initialNextDate,
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
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-task07-form')));
    await tester.pumpAndSettle();
  }

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
          builder: (context, state) => const Text('Paywall — Task 15'),
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
    await _select(tester, const ValueKey('add-edit-case-type'));
    await tester.tap(find.text('Civil'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('add-edit-case-number')),
      'LIMIT-51',
    );
    await tester.tap(find.byKey(const ValueKey('add-edit-save')));
    await tester.pumpAndSettle();

    expect(find.text('Paywall — Task 15'), findsOneWidget);
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
    await _select(tester, const ValueKey('add-edit-case-type'));
    await tester.tap(find.text('Civil'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('add-edit-case-number')),
      'PREMIUM-51',
    );
    await tester.tap(find.byKey(const ValueKey('add-edit-save')));
    await tester.pumpAndSettle();

    expect(find.text('Paywall — Task 15'), findsNothing);
    expect(await CasesDao(db).getNonDeletedCaseCount(), 51);
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
    await _select(tester, const ValueKey('add-edit-case-type'));
    await tester.tap(find.text('Civil'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('add-edit-case-number')),
      'A-1/2026',
    );
    // Offset 0 is selected by the form's default; add the second offset.
    await _selectOffsets(tester, const [3]);
    await tester.tap(find.byKey(const ValueKey('add-edit-save')));
    await tester.pumpAndSettle();

    final added = (await CasesDao(db).getAll()).single;
    expect(added.caseNumber, 'A-1/2026');
    final preference = await CaseNotificationPreferencesDao(
      db,
    ).get(identity.getId(), added.id);
    expect(preference?.offsets, '[0,3]');
    expect(await CaseHistoryDao(db).getByCaseId(added.id), isEmpty);

    await openForm(tester, initialCase: added);
    await tester.enterText(
      find.byKey(const ValueKey('add-edit-case-number')),
      'A-1/2026-EDITED',
    );
    await tester.tap(find.byKey(const ValueKey('add-edit-save')));
    await tester.pumpAndSettle();

    final edited = await CasesDao(db).getById(added.id);
    expect(edited?.caseNumber, 'A-1/2026-EDITED');
    expect(await CaseHistoryDao(db).getByCaseId(added.id), isEmpty);
  });

  testWidgets('All Cases Update action opens the Quick Update dialog', (
    WidgetTester tester,
  ) async {
    final listCaseId = await caseRepository.insertCase(
      CasesCompanion(
        caseNumber: const Value('LIST-1'),
        petitioner: const Value('Alice'),
        respondent: const Value('Bob'),
        courtId: Value(courtId),
        caseType: const Value('Civil'),
        onBehalfId: Value(onBehalfId),
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
    expect(updated.nextDate, isNotNull);
    final history = await CaseHistoryDao(db).getByCaseId(updated.id);
    expect(history, hasLength(1));
    expect(history.single.hearingDate, isNotNull);
    expect(history.single.nextDate, updated.nextDate);

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

Future<void> _selectOffsets(WidgetTester tester, List<int> offsets) async {
  await _select(tester, const ValueKey('add-edit-day-offset'));
  for (final offset in offsets) {
    final item = find.byKey(ValueKey<int>(offset));
    expect(item, findsOneWidget);
    await tester.tap(item);
  }
  await tester.tap(find.byKey(const ValueKey('custom-dropdown-done')));
  await tester.pumpAndSettle();
}
