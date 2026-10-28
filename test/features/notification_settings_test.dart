/// Tests for the Notifications screen (Task 12 Phase 4).
///
/// The screen reads and writes the per-user `user_preferences` row through
/// [SettingsRepository], so these tests drive it with the shared fake and
/// assert what gets stored: the ON/OFF status, the day offsets (several at
/// once, the single `notificationDayOffset` following the nearest one), the
/// delivery time, and the OEM reminder banner plus setup-guide entry the plan
/// adds on top of the mockup's three controls.
///
/// The card carries one more pair for a **confirmed administrator** — Payment
/// Request Alerts, the switch the push sender reads for itself. Who may see it
/// is asserted here (`adminStatusProvider` is the seam), as is what switching it
/// on asks the OS for.
///
/// The time window is Flutter's, so the বাংলা test asserts what the Bengali
/// bundle is layered over it for: the English 12-hour layout with Bengali
/// digits, Latin AM/PM and the app's dialog action size.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/constants/app_spacing.dart';
import 'package:legal_case_diary/core/providers/notification_providers.dart';
import 'package:legal_case_diary/features/admin/presentation/admin_viewmodel.dart';
import 'package:legal_case_diary/features/settings/data/settings_repository.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_controls.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_notifications/notification_settings_screen.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_notifications/notification_time_picker.dart';

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
    expect(find.text('Default Notification Status'), findsOneWidget);
    // Every label on this screen is title-cased. The pairs are found by key,
    // because the Client Notification section below adds further On/Off pairs.
    expect(
      find.byKey(const ValueKey('settings-notifications-status-on')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-notifications-status-off')),
      findsOneWidget,
    );
    expect(find.text('Notification Day Offset'), findsOneWidget);
    // Default offset is one day before, like the mockup.
    expect(find.text('The Day Before'), findsOneWidget);
    expect(find.text('Notification Time'), findsOneWidget);
    // Mockup's 05:00 PM placeholder until the user picks a time.
    expect(find.text('05:00 PM'), findsOneWidget);
  });

  testWidgets('the ON/OFF pair stores the notification status', (tester) async {
    await pumpScreen(tester);

    await tester.tap(
      find.byKey(const ValueKey('settings-notifications-status-on')),
    );
    await tester.pumpAndSettle();
    expect(repo.settings.notificationEnabled, isTrue);

    await tester.tap(
      find.byKey(const ValueKey('settings-notifications-status-off')),
    );
    await tester.pumpAndSettle();
    expect(repo.settings.notificationEnabled, isFalse);
  });

  testWidgets('the day-offset picker ticks several offsets at once', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('The Day Before'));
    await tester.pumpAndSettle();
    expect(find.text('Select Day Offset'), findsOneWidget);
    // The same window the View Settings dropdowns use.
    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(dialog.elevation, settingsPopoverWindowElevation);
    expect(dialog.clipBehavior, Clip.antiAlias);
    final shape = dialog.shape! as RoundedRectangleBorder;
    expect(
      shape.borderRadius,
      BorderRadius.circular(AppSpacing.cardRadius * 2),
    );
    expect(shape.side, BorderSide.none);
    expect(
      tester.getSize(find.byType(SettingsPickerDialogHeader)).height,
      moreOrLessEquals(48 * 1.25, epsilon: 0.1),
    );
    // The shared list: the mockup's days plus Before 15 Days and Before 30 Days.
    expect(find.text('The Same Day'), findsOneWidget);
    expect(find.text('Before 2 Days'), findsOneWidget);
    expect(find.text('Before 7 Days'), findsOneWidget);
    expect(find.text('Before 15 Days'), findsOneWidget);
    expect(find.text('Before 30 Days'), findsOneWidget);
    // The stored default is the ticked row.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    // A second choice joins the first instead of replacing it, and the picker
    // stays open for the next tick: a hearing can alert several times.
    await tester.tap(find.text('Before 3 Days'));
    await tester.pumpAndSettle();
    expect(find.text('Select Day Offset'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    expect(repo.settings.notificationDefaultOffsets, <int>[1, 3]);
    // The case form's single default is the nearest offset ticked.
    expect(repo.settings.notificationDayOffset, 1);

    await tester.tap(find.text('Before 30 Days'));
    await tester.pumpAndSettle();
    expect(repo.settings.notificationDefaultOffsets, <int>[1, 3, 30]);

    // Unticking takes one back out.
    await tester.tap(find.text('Before 3 Days'));
    await tester.pumpAndSettle();
    expect(repo.settings.notificationDefaultOffsets, <int>[1, 30]);

    // The row behind the picker shows the whole selection, in picker order.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('The Day Before, Before 30 Days'), findsOneWidget);
  });

  testWidgets('the last remaining day offset cannot be unticked', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('The Day Before'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SettingsOptionRow, 'The Day Before'));
    await tester.pumpAndSettle();

    // An empty list would read as "never alert", so the last tick stays on.
    expect(repo.settings.notificationDefaultOffsets, <int>[1]);
    // The warning is drawn inside the window, not behind it.
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Select at least one day offset.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('stores the two added long-range offsets', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('The Day Before'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Before 15 Days'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Before 30 Days'));
    await tester.pumpAndSettle();

    expect(repo.settings.notificationDefaultOffsets, <int>[1, 15, 30]);
    expect(repo.settings.notificationDayOffset, 1);
  });

  testWidgets('the time row opens a picker whose confirm stores the time', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('05:00 PM'));
    await tester.pumpAndSettle();
    // The approved deviation from the mockup: the platform time picker.
    expect(find.byType(TimePickerDialog), findsOneWidget);

    // The title is Select Time, bold.
    expect(
      tester.widget<Text>(find.text('Select Time')).style?.fontWeight,
      FontWeight.w700,
    );
    // The active box is white on black; unselected boxes stay white with
    // black text, as they looked before.
    Color? textColor(String label) =>
        tester.widget<Text>(find.text(label)).style?.color;
    Color? boxColor(String label) => tester
        .widget<Material>(
          find
              .ancestor(of: find.text(label), matching: find.byType(Material))
              .first,
        )
        .color;
    expect(textColor('5'), Colors.white);
    expect(boxColor('5'), AppColors.secondary);
    expect(textColor('00'), AppColors.secondary);
    expect(boxColor('00'), Colors.white);
    expect(textColor('PM'), Colors.white);
    expect(boxColor('PM'), AppColors.secondary);
    expect(textColor('AM'), AppColors.secondary);
    expect(boxColor('AM'), Colors.white);

    // Confirming the mockup's placeholder (05:00 PM) stores it; the clock
    // face itself is Flutter's, so this only verifies our wiring.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(repo.settings.notificationTime, 17 * 60);
  });

  testWidgets('the gear tick plays only when the time changes', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var clicks = 0;
    final original = gearClickPlayer;
    gearClickPlayer = () => clicks++;
    addTearDown(() => gearClickPlayer = original);

    await pumpScreen(tester);
    await tester.tap(find.text('05:00 PM'));
    await tester.pumpAndSettle();
    expect(clicks, 0, reason: 'opening the window makes no tick');

    // Dragging over the header changes no hour or minute: silent.
    await tester.dragFrom(
      tester.getCenter(find.text('Select Time')),
      const Offset(60, 0),
    );
    await tester.pumpAndSettle();
    expect(clicks, 0);

    // Dragging the hand between dial numbers changes the hour: it ticks.
    final start = tester.getCenter(find.byType(TimePickerDialog));
    await tester.dragFrom(start, const Offset(90, 0));
    await tester.pumpAndSettle();
    expect(clicks, greaterThan(0));
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

  testWidgets('বাংলা day offsets carry Bengali digits', (tester) async {
    await pumpSettingsScreen(
      tester,
      const NotificationSettingsScreen(),
      repo: repo,
      locale: const Locale('bn'),
    );

    await tester.tap(find.text('একদিন আগে'));
    await tester.pumpAndSettle();

    // The day count is the language's own digits, not the raw number.
    expect(find.text('২ দিন আগে'), findsOneWidget);
    expect(find.text('৩০ দিন আগে'), findsOneWidget);
    expect(find.text('2 দিন আগে'), findsNothing);

    // And the row behind the picker reads the same way once one is ticked.
    await tester.tap(find.text('১৫ দিন আগে'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('একদিন আগে, ১৫ দিন আগে'), findsOneWidget);
  });

  testWidgets('বাংলা opens the same 12-hour window English does', (
    tester,
  ) async {
    repo = FakeSettingsRepository(
      const UserSettings(notificationTime: 8 * 60 + 30),
    );
    final scheduler = FakeNotificationScheduler();
    await pumpSettingsScreen(
      tester,
      const NotificationSettingsScreen(),
      repo: repo,
      locale: const Locale('bn'),
      overrides: [notificationSchedulerProvider.overrideWithValue(scheduler)],
    );

    await tester.tap(find.text('০৮:৩০ AM'));
    await tester.pumpAndSettle();

    // Flutter's window, on the English clock layout Bengali Material does not
    // ask for: a 12-hour dial with the AM/PM toggle beside it.
    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(find.text('AM'), findsOneWidget);
    expect(find.text('PM'), findsOneWidget);
    // The time itself is Bengali — digits localized, AM/PM left as letters.
    expect(find.text('৩০'), findsOneWidget);

    // Cancel/OK carry the app's dialog action size (112x48 at 16 pt) instead of
    // being sized to their own label.
    final actions = find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.byType(TextButton),
    );
    expect(actions, findsNWidgets(2));
    expect(tester.getSize(actions.first).height, 48);
    expect(tester.getSize(actions.last).height, 48);
    expect(tester.getSize(actions.first).width, greaterThanOrEqualTo(112));
    expect(tester.getSize(actions.last).width, greaterThanOrEqualTo(112));

    // Dismissing the window stores nothing.
    await tester.tap(find.text('বাতিল করুন'));
    await tester.pumpAndSettle();
    expect(repo.settings.notificationTime, 8 * 60 + 30);
    expect(scheduler.syncScheduleCalls, 0);
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
      overrides: [notificationSchedulerProvider.overrideWithValue(scheduler)],
    );

    await tester.tap(
      find.byKey(const ValueKey('settings-notifications-status-on')),
    );
    await tester.pumpAndSettle();
    expect(scheduler.syncScheduleCalls, 1);

    await tester.tap(
      find.byKey(const ValueKey('settings-notifications-status-off')),
    );
    await tester.pumpAndSettle();
    expect(scheduler.syncScheduleCalls, 2);

    await tester.tap(find.text('The Day Before'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Before 3 Days'));
    await tester.pumpAndSettle();
    expect(scheduler.syncScheduleCalls, 3);
    expect(repo.settings.notificationDefaultOffsets, <int>[1, 3]);
    // The picker stays open, so close it before reaching the row behind it.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await tester.tap(find.text('05:00 PM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(scheduler.syncScheduleCalls, 4);
  });

  /// A viewport tall enough for the whole card plus the rows under it, for the
  /// cases that reach the bottom pair: an off-screen row is not built at all.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 4600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  /// Whether the server has confirmed this account as an administrator.
  Override adminStatus(bool value) =>
      adminStatusProvider.overrideWith((ref) async => value);

  testWidgets('the two notification switches start on for a fresh account', (
    tester,
  ) async {
    useTallViewport(tester);
    await pumpScreen(tester);

    // Nothing has been stored yet: the device master switch and the automated
    // client message both default to on (user request, 0.0.697).
    expect(
      tester
          .widget<SettingsChoiceButton>(
            find.byKey(const ValueKey('settings-notifications-status-on')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<SettingsChoiceButton>(
            find.byKey(const ValueKey('client-notification-enabled-on')),
          )
          .selected,
      isTrue,
    );
  });

  testWidgets('a non-administrator is not offered the payment-alert pair', (
    tester,
  ) async {
    useTallViewport(tester);
    await pumpSettingsScreen(
      tester,
      const NotificationSettingsScreen(),
      repo: repo,
      overrides: [adminStatus(false)],
    );

    // The panel is invisible to a non-admin, and so is every control of it: the
    // switch would only ever write a preference nothing reads.
    expect(find.text('Admin Panel Notification'), findsNothing);
    expect(
      find.byKey(const ValueKey('settings-notifications-payment-alerts-on')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('settings-notifications-payment-alerts-off')),
      findsNothing,
    );
    // The ordinary pair is still there.
    expect(
      find.byKey(const ValueKey('settings-notifications-status-on')),
      findsOneWidget,
    );
  });

  testWidgets(
    'an administrator sees the payment-alert pair and its stored value',
    (tester) async {
      useTallViewport(tester);
      repo = FakeSettingsRepository(
        const UserSettings(paymentAlertsEnabled: false),
      );
      final scheduler = FakeNotificationScheduler();
      await pumpSettingsScreen(
        tester,
        const NotificationSettingsScreen(),
        repo: repo,
        overrides: [
          adminStatus(true),
          notificationSchedulerProvider.overrideWithValue(scheduler),
        ],
      );

      expect(find.text('Admin Panel Notification'), findsOneWidget);
      // Two pairs now, the administrator's last — the switch defaults to on, so
      // OFF here is the stored value rather than the default.
      await tester.tap(
        find.byKey(const ValueKey('settings-notifications-payment-alerts-on')),
      );
      await tester.pumpAndSettle();

      expect(repo.settings.paymentAlertsEnabled, isTrue);
      // Nothing local is scheduled for it: the count is pushed by the server.
      expect(scheduler.syncScheduleCalls, 0);
      // The OS permission was already granted, so it is not asked for again.
      expect(scheduler.permissionRequests, 0);
    },
  );

  testWidgets('switching payment alerts on asks for the OS permission once', (
    tester,
  ) async {
    useTallViewport(tester);
    repo = FakeSettingsRepository(
      const UserSettings(paymentAlertsEnabled: false),
    );
    final scheduler = FakeNotificationScheduler()
      ..notificationsAllowedValue = false;
    await pumpSettingsScreen(
      tester,
      const NotificationSettingsScreen(),
      repo: repo,
      overrides: [
        adminStatus(true),
        notificationSchedulerProvider.overrideWithValue(scheduler),
      ],
    );

    await tester.tap(
      find.byKey(const ValueKey('settings-notifications-payment-alerts-on')),
    );
    await tester.pumpAndSettle();

    // Android 13+ drops what an app may not post, so a switch turned on without
    // the permission would be a switch that does nothing. The preference is still
    // the user's answer: a refused prompt leaves the account in the fan-set, and
    // the reminder banner already tells them what to fix.
    expect(scheduler.permissionRequests, 1);
    expect(repo.settings.paymentAlertsEnabled, isTrue);
  });

  testWidgets('titles the device and client sections in bold', (tester) async {
    useTallViewport(tester);
    await pumpScreen(tester);

    for (final title in <String>[
      'Device Notification Settings',
      'Client Notification Settings',
    ]) {
      final text = tester.widget<Text>(find.text(title));
      expect(text.style?.fontWeight, FontWeight.w700, reason: title);
    }
    // The old in-card title is gone; the screen names the card above it.
    expect(find.text('Client Notification'), findsNothing);
  });

  testWidgets('shows the OEM reminder banner and setup-guide entry', (
    tester,
  ) async {
    useTallViewport(tester);
    await pumpScreen(tester);

    expect(
      find.text(
        'Notifications may not work reliably on your device. '
        'Tap to complete setup.',
      ),
      findsOneWidget,
    );
    expect(find.text('Battery & Auto-Start Setup Guide'), findsOneWidget);
  });

  testWidgets('the reminder banner goes away once the setup is completed', (
    tester,
  ) async {
    useTallViewport(tester);
    repo = FakeSettingsRepository(
      const UserSettings(notificationSetupDone: true),
    );
    await pumpScreen(tester);

    expect(
      find.text(
        'Notifications may not work reliably on your device. '
        'Tap to complete setup.',
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
    tester.view.physicalSize = const Size(1200, 4600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final scheduler = FakeNotificationScheduler();
    await pumpSettingsScreen(
      tester,
      const NotificationSettingsScreen(),
      repo: repo,
      overrides: [notificationSchedulerProvider.overrideWithValue(scheduler)],
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
    tester.view.physicalSize = const Size(1200, 4600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final scheduler = FakeNotificationScheduler()
      ..notificationsAllowedValue = false;
    await pumpSettingsScreen(
      tester,
      const NotificationSettingsScreen(),
      repo: repo,
      overrides: [notificationSchedulerProvider.overrideWithValue(scheduler)],
    );

    await tester.tap(find.text('Send Test Notification'));
    await tester.pumpAndSettle();

    expect(scheduler.permissionRequests, 1);
    // Nothing was posted, because the OS would have dropped it.
    expect(scheduler.testNotifications, 0);
    expect(
      find.text(
        "Could not show a notification. Check the app's notification "
        'permission.',
      ),
      findsOneWidget,
    );
  });
}
