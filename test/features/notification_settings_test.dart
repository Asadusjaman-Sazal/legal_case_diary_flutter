/// Tests for the Notifications screen (Task 12 Phase 4).
///
/// The screen reads and writes the per-user `user_preferences` row through
/// [SettingsRepository], so these tests drive it with the shared fake and
/// assert what gets stored: the ON/OFF status, the day offset (mirrored into
/// the offsets list), the delivery time, and the OEM reminder banner plus
/// setup-guide entry the plan adds on top of the mockup's three controls.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/providers/notification_providers.dart';
import 'package:legal_case_diary/features/settings/data/settings_repository.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_notifications/notification_settings_screen.dart';

import '../core/notification_test_support.dart';
import 'settings_test_support.dart';

void main() {
  late FakeSettingsRepository repo;

  setUp(() {
    repo = FakeSettingsRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) => pumpSettingsScreen(
    tester,
    const NotificationSettingsScreen(),
    repo: repo,
  );

  testWidgets('shows the mockup controls with the stored values', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('DEFAULT NOTIFICATION STATUS'), findsOneWidget);
    // Every label on this screen is title-cased.
    expect(find.text('On'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
    expect(find.text('NOTIFICATION DAY OFFSET'), findsOneWidget);
    // Default offset is one day before, like the mockup.
    expect(find.text('The Day Before'), findsOneWidget);
    expect(find.text('NOTIFICATION TIME'), findsOneWidget);
    // Mockup's 05:00 PM placeholder until the user picks a time.
    expect(find.text('05:00 PM'), findsOneWidget);
  });

  testWidgets('the ON/OFF pair stores the notification status', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('On'));
    await tester.pumpAndSettle();
    expect(repo.settings.notificationEnabled, isTrue);

    await tester.tap(find.text('Off'));
    await tester.pumpAndSettle();
    expect(repo.settings.notificationEnabled, isFalse);
  });

  testWidgets('the day-offset dialog stores the choice and its offsets list', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('The Day Before'));
    await tester.pumpAndSettle();
    expect(find.text('Select Day Offset'), findsOneWidget);
    // The shared list: the mockup's days plus Before 15 Days and Before 30 Days.
    expect(find.text('The Same Day'), findsOneWidget);
    expect(find.text('Before 2 Days'), findsOneWidget);
    expect(find.text('Before 7 Days'), findsOneWidget);
    expect(find.text('Before 15 Days'), findsOneWidget);
    expect(find.text('Before 30 Days'), findsOneWidget);

    await tester.tap(find.text('Before 3 Days'));
    await tester.pumpAndSettle();

    expect(repo.settings.notificationDayOffset, 3);
    expect(repo.settings.notificationDefaultOffsets, <int>[3]);
    expect(find.text('Before 3 Days'), findsOneWidget);
  });

  testWidgets('stores the two added long-range offsets', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('The Day Before'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Before 30 Days'));
    await tester.pumpAndSettle();

    expect(repo.settings.notificationDayOffset, 30);
    expect(repo.settings.notificationDefaultOffsets, <int>[30]);
    expect(find.text('Before 30 Days'), findsOneWidget);
  });

  testWidgets('the time row opens a picker whose confirm stores the time', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('05:00 PM'));
    await tester.pumpAndSettle();
    // The approved deviation from the mockup: the platform time picker.
    expect(find.byType(TimePickerDialog), findsOneWidget);

    // Confirming the mockup's placeholder (05:00 PM) stores it; the clock
    // face itself is Flutter's, so this only verifies our wiring.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(repo.settings.notificationTime, 17 * 60);
  });

  testWidgets('renders a stored notification time as HH:MM AM/PM', (
    tester,
  ) async {
    repo = FakeSettingsRepository(
      const UserSettings(notificationTime: 8 * 60 + 30),
    );
    await pumpScreen(tester);

    expect(find.text('08:30 AM'), findsOneWidget);
  });

  testWidgets('every notification change re-arms the daily alarm', (
    tester,
  ) async {
    // Task 13 Phase 2: the stored preference is only half the story — the armed
    // alarm has to follow it, including switching alerts off (which cancels it).
    final scheduler = FakeNotificationScheduler();
    await pumpSettingsScreen(
      tester,
      const NotificationSettingsScreen(),
      repo: repo,
      overrides: [
        notificationSchedulerProvider.overrideWithValue(scheduler),
      ],
    );

    await tester.tap(find.text('On'));
    await tester.pumpAndSettle();
    expect(scheduler.syncScheduleCalls, 1);

    await tester.tap(find.text('Off'));
    await tester.pumpAndSettle();
    expect(scheduler.syncScheduleCalls, 2);

    await tester.tap(find.text('The Day Before'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Before 3 Days'));
    await tester.pumpAndSettle();
    expect(scheduler.syncScheduleCalls, 3);
    expect(repo.settings.notificationDayOffset, 3);

    await tester.tap(find.text('05:00 PM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(scheduler.syncScheduleCalls, 4);
  });

  testWidgets('shows the OEM reminder banner and setup-guide entry', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(
      find.text(
        'Notifications May Not Work Reliably on Your Device. '
        'Tap to Complete Setup.',
      ),
      findsOneWidget,
    );
    expect(find.text('Battery & Auto-Start Setup Guide'), findsOneWidget);
  });

  testWidgets('the reminder banner goes away once the setup is completed', (
    tester,
  ) async {
    repo = FakeSettingsRepository(
      const UserSettings(notificationSetupDone: true),
    );
    await pumpScreen(tester);

    expect(
      find.text(
        'Notifications May Not Work Reliably on Your Device. '
        'Tap to Complete Setup.',
      ),
      findsNothing,
    );
    // The guide stays reachable from Settings either way.
    expect(find.text('Battery & Auto-Start Setup Guide'), findsOneWidget);
  });

  testWidgets('the test action posts a real notification and says so', (
    tester,
  ) async {
    // Tall viewport: the test-alert card sits below the three mockup controls,
    // and an off-screen card is not built at all.
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final scheduler = FakeNotificationScheduler();
    await pumpSettingsScreen(
      tester,
      const NotificationSettingsScreen(),
      repo: repo,
      overrides: [
        notificationSchedulerProvider.overrideWithValue(scheduler),
      ],
    );

    await tester.tap(find.text('Send Test Notification'));
    await tester.pumpAndSettle();

    expect(scheduler.testNotifications, 1);
    // The permission was already granted, so it is not asked for again.
    expect(scheduler.permissionRequests, 0);
    expect(find.text('Test Notification Sent'), findsOneWidget);
  });

  testWidgets('a blocked permission is reported, not papered over', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final scheduler = FakeNotificationScheduler()
      ..notificationsAllowedValue = false;
    await pumpSettingsScreen(
      tester,
      const NotificationSettingsScreen(),
      repo: repo,
      overrides: [
        notificationSchedulerProvider.overrideWithValue(scheduler),
      ],
    );

    await tester.tap(find.text('Send Test Notification'));
    await tester.pumpAndSettle();

    expect(scheduler.permissionRequests, 1);
    // Nothing was posted, because the OS would have dropped it.
    expect(scheduler.testNotifications, 0);
    expect(
      find.text(
        "Could Not Show a Notification. Check the App's Notification "
        'Permission.',
      ),
      findsOneWidget,
    );
  });
}
