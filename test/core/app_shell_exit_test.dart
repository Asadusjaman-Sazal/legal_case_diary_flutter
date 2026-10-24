/// Shell back-gesture tests for the bottom-nav screens.
///
/// A bottom-nav screen (the six case lists, Notes and Case Reference) is a
/// destination, not a step in a flow: the system back gesture there always
/// offers the Exit App? window instead of returning to whichever screen it was
/// opened from (the drawer and the All Cases summary cards push these routes).
/// Settings and its sub-pages keep the ordinary pop, and an open drawer still
/// closes on the first back.
///
/// These pump the **real** screens inside the real shell ([AppShellRoot]), so
/// the rule is asserted through the same widget tree the app builds.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/constants/app_spacing.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
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
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:legal_case_diary/shared/widgets/add_edit_case_sheet.dart';
import 'package:legal_case_diary/sync/connectivity_monitor.dart';
import 'package:legal_case_diary/sync/sync_queue_dao.dart';
import 'package:legal_case_diary/sync/sync_write_helper.dart';

/// The eight bottom-nav screens the rule covers, on the real route paths.
const Map<String, Widget> _bottomNavScreens = <String, Widget>{
  AppRoutes.allCases: AllCasesScreen(),
  AppRoutes.activeCases: ActiveCasesScreen(),
  AppRoutes.dailyCauseList: DailyCauseListScreen(),
  AppRoutes.overdueDates: OverdueDatesScreen(),
  AppRoutes.upcomingCases: UpcomingCasesScreen(),
  AppRoutes.disposedCases: DisposedCasesScreen(),
  AppRoutes.caseReference: CaseReferenceScreen(),
  AppRoutes.notes: NotesScreen(),
};

/// The channel `MainActivity.kt` serves for the Exit App? window's close.
const MethodChannel _exitChannel = MethodChannel(
  'com.legalcasediary.app/app_exit',
);

/// A stand-in for the screen a destination is opened from, and for the
/// Settings sub-pages the rule must leave alone.
class _Stub extends StatelessWidget {
  final String label;

  const _Stub(this.label);

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}

/// The real shell over the real screens, plus a Settings surface to open them
/// from and a Settings sub-page that must keep popping.
GoRouter _router() => GoRouter(
  initialLocation: AppRoutes.settings,
  routes: [
    ShellRoute(
      // The banners are not what is under test, and they read live providers.
      builder: (context, state, child) =>
          AppShellRoot(showConflictBanner: false, child: child),
      routes: [
        for (final entry in _bottomNavScreens.entries)
          GoRoute(
            path: entry.key,
            pageBuilder: (context, state) =>
                NoTransitionPage(child: entry.value),
          ),
        GoRoute(
          path: AppRoutes.settings,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: _Stub('Settings')),
        ),
        GoRoute(
          path: AppRoutes.settingsProfile,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: _Stub('Profile')),
        ),
      ],
    ),
  ],
);

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late LocalIdentityService identity;
  late LocalSettingsRepository settings;
  late LocalNotesRepository notes;
  late LocalReferenceRepository references;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    identity = LocalIdentityService(prefs);
    db = AppDatabase(NativeDatabase.memory());
    final sync = SyncWriteHelper(SyncQueueDao(db), identity);
    settings = LocalSettingsRepository(UserPreferencesDao(db), identity);
    notes = LocalNotesRepository(NotesDao(db), sync);
    references = LocalReferenceRepository(CaseReferencesDao(db), sync);
  });

  tearDown(() async => db.close());

  /// Pumps a bounded number of frames.
  ///
  /// The screens hold live Drift streams, so this suite waits for the widgets
  /// under test instead of `pumpAndSettle`, which would wait for the frame
  /// pipeline itself to go quiet.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
  }

  /// Runs a test body and always takes the widget tree down afterwards.
  ///
  /// The tree has to be released before the body ends — the framework checks
  /// for pending timers the moment it returns, and the screens hold live Drift
  /// streams. A plain last line would be skipped by a failing assertion, and
  /// the tree left standing then poisons every test after it.
  Future<void> withScreens(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    try {
      await body();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  /// Pumps the shell with the app's own local providers.
  Future<void> pumpShell(WidgetTester tester, GoRouter router) async {
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
          premiumAccessProvider.overrideWith((ref) async => true),
          isOnlineProvider.overrideWith((ref) => Stream<bool>.value(true)),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          routerConfig: router,
        ),
      ),
    );
    await settle(tester);
  }

  /// Presses the system back button — what the platform sends for the gesture.
  Future<void> pressBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await settle(tester);
  }

  /// Opens [screen]'s drawer and returns its Scaffold state.
  Future<ScaffoldState> openDrawer(WidgetTester tester, Type screen) async {
    final scaffold = find.descendant(
      of: find.byType(screen),
      matching: find.byType(Scaffold),
    );
    final state = tester.state<ScaffoldState>(scaffold);
    state.openDrawer();
    await settle(tester);
    return state;
  }

  testWidgets('back on every bottom-nav screen offers the exit window', (
    tester,
  ) async {
    await withScreens(tester, () async {
      final router = _router();
      await pumpShell(tester, router);

      for (final path in _bottomNavScreens.keys) {
        // Opened the way it is in the app: pushed on top of another screen, so
        // there is a real previous screen a pop would fall back to.
        router.go(AppRoutes.settings);
        await settle(tester);
        router.push(path);
        await settle(tester);
        expect(router.state.matchedLocation, path, reason: path);

        await pressBack(tester);

        expect(find.text('Exit App?'), findsOneWidget, reason: path);
        expect(
          find.text('Do you want to exit Legal Case Diary?'),
          findsOneWidget,
          reason: path,
        );
        // The screen it was opened from was not reached.
        expect(find.text('Settings'), findsNothing, reason: path);

        // Cancel leaves the user exactly where they were.
        await tester.tap(find.text('Cancel'));
        await settle(tester);
        expect(find.text('Exit App?'), findsNothing, reason: path);
        expect(router.state.matchedLocation, path, reason: path);
      }
    });
  });

  testWidgets('a Settings sub-page still pops back normally', (tester) async {
    await withScreens(tester, () async {
      final router = _router();
      await pumpShell(tester, router);

      router.push(AppRoutes.settingsProfile);
      await settle(tester);
      expect(find.text('Profile'), findsOneWidget);

      await pressBack(tester);

      // No window, and the previous screen is back — the rule is scoped to the
      // bottom-nav destinations.
      expect(find.text('Exit App?'), findsNothing);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Profile'), findsNothing);
    });
  });

  testWidgets('an open drawer closes on the first back, the window on the '
      'next', (tester) async {
    await withScreens(tester, () async {
      final router = _router();
      await pumpShell(tester, router);
      router.push(AppRoutes.notes);
      await settle(tester);

      final scaffold = await openDrawer(tester, NotesScreen);
      expect(scaffold.isDrawerOpen, isTrue);

      await pressBack(tester);
      expect(find.text('Exit App?'), findsNothing);
      expect(scaffold.isDrawerOpen, isFalse);
      expect(router.state.matchedLocation, AppRoutes.notes);

      await pressBack(tester);
      expect(find.text('Exit App?'), findsOneWidget);
    });
  });

  testWidgets('the exit window uses the Update corner and a wider gap', (
    tester,
  ) async {
    await withScreens(tester, () async {
      final router = _router();
      await pumpShell(tester, router);
      await pressBack(tester);
      expect(find.text('Exit App?'), findsOneWidget);

      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(
        tester.widget<Text>(find.text('Exit App?')).textAlign,
        TextAlign.center,
      );
      expect(
        (dialog.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(AppSpacing.cardRadius * 2),
      );
      final actions = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextButton),
      );
      final cancel = tester.getRect(actions.at(0));
      final exit = tester.getRect(actions.at(1));
      // 8 px default doubled by 2 px on each side.
      expect(exit.left - cancel.right, 12);

      await tester.tap(find.text('Cancel'));
      await settle(tester);
    });
  });

  /// Offers the window and confirms it, leaving the tap's work settled.
  Future<void> confirmExit(WidgetTester tester) async {
    await pressBack(tester);
    expect(find.text('Exit App?'), findsOneWidget);
    await tester.tap(find.text('Exit'));
    // The window's answer only reaches the app once the dialog's dismissal
    // completes, so give the route time to finish closing.
    await settle(tester);
    await settle(tester);
    expect(find.text('Exit App?'), findsNothing);
  }

  testWidgets('confirming Exit closes the app through the host hook', (
    tester,
  ) async {
    await withScreens(tester, () async {
      // The real close is the host's: `SystemNavigator.pop()` only dispatches an
      // Android back press on this Flutter, which leaves the app running.
      final hostCalls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _exitChannel,
        (call) async {
          hostCalls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _exitChannel,
          null,
        ),
      );

      final router = _router();
      await pumpShell(tester, router);
      router.push(AppRoutes.caseReference);
      await settle(tester);

      await confirmExit(tester);

      expect(
        hostCalls.map((call) => call.method),
        contains('closeApp'),
        reason: 'Exit must close the app, not merely dismiss the window',
      );
    });
  });

  testWidgets('without a working host hook, Exit falls back to the framework '
      'pop', (tester) async {
    await withScreens(tester, () async {
      // `SystemNavigator.pop()` travels on the platform channel and is what a
      // host without the hook (a test runner, Windows) still gets.
      final pops = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          pops.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final router = _router();
      await pumpShell(tester, router);
      router.push(AppRoutes.caseReference);
      await settle(tester);

      // A host without the method answers with an empty reply, which is what
      // `MissingPluginException` means. Left unregistered instead (handler
      // removed), the test messenger would never answer at all, which is a
      // property of the harness and not of a host.
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        _exitChannel.name,
        (message) async => null,
      );
      await confirmExit(tester);

      // A host that answers but refuses: the other fallback branch.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _exitChannel,
        (call) async => throw PlatformException(code: 'refused'),
      );
      await confirmExit(tester);

      expect(
        pops.where((call) => call.method == 'SystemNavigator.pop').length,
        2,
        reason: 'both fallbacks must still close the app',
      );
    });
  });
}
