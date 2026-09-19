/// Tests for the OEM battery/auto-start setup guide (Task 13 Phase 3).
///
/// The screen has no mockup (built from the Settings chrome, as approved), so
/// these tests are the contract: the right steps for the detected phone, the
/// localized copy, the "Take Me There" fall-through when an OEM page is missing,
/// what Done and Skip store, and the first-launch offer that must happen once —
/// and only on the phones that need it.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/app.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/notifications/oem_setup_guide.dart';
import 'package:legal_case_diary/core/providers/notification_providers.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_notifications/battery_setup_guide_screen.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';

import '../core/notification_test_support.dart';
import 'settings_test_support.dart';

/// Pumps the guide screen inside a router, so `push` and back work.
Future<void> _pumpGuide(
  WidgetTester tester, {
  required FakeSettingsRepository repo,
  required FakeNotificationScheduler scheduler,
  Locale locale = const Locale('en'),
}) async {
  // A tall viewport: the guide is a scrolling list, and a step that is merely
  // off-screen is not built, which would make "the step is missing" tests lie.
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: AppRoutes.settingsBatterySetupGuide,
    routes: [
      GoRoute(
        path: AppRoutes.settingsNotifications,
        builder: (context, state) => const Scaffold(),
      ),
      GoRoute(
        path: AppRoutes.settingsBatterySetupGuide,
        builder: (context, state) => const BatterySetupGuideScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWith((ref) async => repo),
        notificationSchedulerProvider.overrideWithValue(scheduler),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late FakeSettingsRepository repo;
  late FakeNotificationScheduler scheduler;

  setUp(() {
    repo = FakeSettingsRepository();
    scheduler = FakeNotificationScheduler();
  });

  testWidgets('renders the steps a Xiaomi phone needs, localized', (
    tester,
  ) async {
    scheduler.device = const DeviceIdentity(manufacturer: 'Xiaomi', brand: 'Redmi');
    await _pumpGuide(tester, repo: repo, scheduler: scheduler);

    expect(find.text('Allow Auto-Start'), findsOneWidget);
    expect(find.text('Set Battery Usage to Unrestricted'), findsOneWidget);
    expect(find.text('Allow Exact Alarms'), findsOneWidget);
    expect(
      find.text(
        'Xiaomi, Oppo, Vivo, Realme and similar phones stop background alarms '
        'to save battery, so hearing reminders can fail silently. These two or '
        'three steps keep them working.',
      ),
      findsOneWidget,
    );
    // Every step has its own "Take Me There".
    expect(find.text('Take Me There'), findsNWidgets(3));
  });

  testWidgets('a phone with no auto-start manager gets two steps', (
    tester,
  ) async {
    scheduler.device = const DeviceIdentity(manufacturer: 'Google', brand: 'Pixel 8');
    await _pumpGuide(tester, repo: repo, scheduler: scheduler);

    expect(find.text('Allow Auto-Start'), findsNothing);
    expect(find.text('Set Battery Usage to Unrestricted'), findsOneWidget);
    expect(find.text('Allow Exact Alarms'), findsOneWidget);
    expect(find.text('Take Me There'), findsNWidgets(2));
  });

  testWidgets('the steps read in Bengali under বাংলা', (tester) async {
    scheduler.device = const DeviceIdentity(manufacturer: 'Xiaomi');
    await _pumpGuide(
      tester,
      repo: repo,
      scheduler: scheduler,
      locale: const Locale('bn'),
    );

    expect(find.text('অটো-স্টার্ট অনুমতি দিন'), findsOneWidget);
    expect(find.text('ব্যাটারি ব্যবহার সীমাহীন করুন'), findsOneWidget);
    expect(find.text('সেখানে নিয়ে যান'), findsNWidgets(3));
    expect(find.text('Allow Auto-Start'), findsNothing);
  });

  testWidgets('Take Me There falls through to the app page when the OEM page is gone', (
    tester,
  ) async {
    scheduler.device = const DeviceIdentity(manufacturer: 'Xiaomi');
    // Only the universal fallback resolves, like a phone whose MIUI page was
    // renamed by an update.
    scheduler.openableTargets = {OemSettingsTarget.appDetails};
    await _pumpGuide(tester, repo: repo, scheduler: scheduler);

    await tester.tap(find.text('Take Me There').first);
    await tester.pumpAndSettle();

    expect(scheduler.openedTargets, [
      OemSettingsTarget.autoStart,
      OemSettingsTarget.appDetails,
    ]);
    expect(
      find.text('Could Not Open That Settings Page. Please Set It Manually.'),
      findsNothing,
    );
  });

  testWidgets('an unreachable step says so instead of looking broken', (
    tester,
  ) async {
    scheduler.device = const DeviceIdentity(manufacturer: 'Xiaomi');
    scheduler.openableTargets = {};
    await _pumpGuide(tester, repo: repo, scheduler: scheduler);

    await tester.tap(find.text('Take Me There').first);
    await tester.pumpAndSettle();

    expect(scheduler.openedTargets, [
      OemSettingsTarget.autoStart,
      OemSettingsTarget.appDetails,
    ]);
    expect(
      find.text('Could Not Open That Settings Page. Please Set It Manually.'),
      findsOneWidget,
    );
  });

  testWidgets('an already-granted exact-alarm permission is stated, not offered', (
    tester,
  ) async {
    scheduler.device = const DeviceIdentity(manufacturer: 'Xiaomi');
    scheduler.exactAlarmsAllowedValue = true;
    await _pumpGuide(tester, repo: repo, scheduler: scheduler);

    expect(find.text('Exact Alarms Are Already Allowed'), findsOneWidget);
    // The other two steps still offer their button.
    expect(find.text('Take Me There'), findsNWidgets(2));
  });

  testWidgets('Done stores the setup and re-arms the alarm', (tester) async {
    scheduler.device = const DeviceIdentity(manufacturer: 'Xiaomi');
    await _pumpGuide(tester, repo: repo, scheduler: scheduler);

    await tester.tap(find.text("Done, I've Completed the Steps"));
    await tester.pumpAndSettle();

    expect(repo.settings.notificationSetupDone, isTrue);
    expect(repo.settings.notificationGuideShown, isTrue);
    // Re-armed, because the user may have just granted exact alarms.
    expect(scheduler.syncScheduleCalls, 1);
  });

  testWidgets('Skip keeps the reminder banner but stops the offer', (
    tester,
  ) async {
    scheduler.device = const DeviceIdentity(manufacturer: 'Xiaomi');
    await _pumpGuide(tester, repo: repo, scheduler: scheduler);

    await tester.tap(find.text('Skip for Now'));
    await tester.pumpAndSettle();

    // Not completed, so Settings keeps nudging…
    expect(repo.settings.notificationSetupDone, isFalse);
    // …but the first-launch offer is spent.
    expect(repo.settings.notificationGuideShown, isTrue);
  });

  group('first-launch offer', () {
    /// Pumps the whole app over [db] and [prefs].
    ///
    /// The preferences are built once per test on purpose: resetting them would
    /// mint a new local identity, and the notification flags are per-user, so a
    /// second launch would look like a brand-new user.
    Future<void> pumpApp(
      WidgetTester tester,
      AppDatabase db,
      FakeNotificationScheduler fake,
      SharedPreferences prefs,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            notificationSchedulerProvider.overrideWithValue(fake),
            databaseProvider.overrideWith((_) async => db),
          ],
          child: const App(),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    }

    testWidgets('an aggressive OEM is offered the guide once, on first launch', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() async => db.close());
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      scheduler.device = const DeviceIdentity(
        manufacturer: 'Xiaomi',
        brand: 'Redmi',
      );

      await pumpApp(tester, db, scheduler, prefs);
      expect(find.byType(BatterySetupGuideScreen), findsOneWidget);

      // A second launch over the same database: the offer is spent.
      await unmount(tester);
      await pumpApp(tester, db, scheduler, prefs);
      expect(find.byType(BatterySetupGuideScreen), findsNothing);

      await unmount(tester);
    });

    testWidgets('a phone that needs nothing is not interrupted', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() async => db.close());
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      scheduler.device = const DeviceIdentity(
        manufacturer: 'Google',
        brand: 'Pixel 8',
      );

      await pumpApp(tester, db, scheduler, prefs);
      expect(find.byType(BatterySetupGuideScreen), findsNothing);

      await unmount(tester);
    });

    testWidgets('a launch from a notification is never covered by the guide', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() async => db.close());
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      scheduler
        ..device = const DeviceIdentity(manufacturer: 'Xiaomi')
        ..launchCaseIdValue = 'case-9';

      await pumpApp(tester, db, scheduler, prefs);
      expect(find.byType(BatterySetupGuideScreen), findsNothing);

      await unmount(tester);
    });
  });
}
