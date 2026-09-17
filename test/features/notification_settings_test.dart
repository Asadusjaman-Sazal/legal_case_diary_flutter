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

import 'package:legal_case_diary/features/settings/data/settings_repository.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_notifications/notification_settings_screen.dart';

import 'settings_test_support.dart';

void main() {
  late FakeSettingsRepository repo;

  setUp(() {
    repo = FakeSettingsRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) =>
      pumpSettingsScreen(tester, const NotificationSettingsScreen(), repo: repo);

  testWidgets('shows the mockup controls with the stored values', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('DEFAULT NOTIFICATION STATUS'), findsOneWidget);
    expect(find.text('On'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
    expect(find.text('NOTIFICATION DAY OFFSET'), findsOneWidget);
    // Default offset is one day before, like the mockup.
    expect(find.text('The day before'), findsOneWidget);
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

    await tester.tap(find.text('The day before'));
    await tester.pumpAndSettle();
    expect(find.text('Select day offset'), findsOneWidget);
    // Every offset the mockup lists is offered.
    expect(find.text('The same day'), findsOneWidget);
    expect(find.text('Before 2 days'), findsOneWidget);
    expect(find.text('Before 7 days'), findsOneWidget);

    await tester.tap(find.text('Before 3 days'));
    await tester.pumpAndSettle();

    expect(repo.settings.notificationDayOffset, 3);
    expect(repo.settings.notificationDefaultOffsets, <int>[3]);
    expect(find.text('Before 3 days'), findsOneWidget);
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

  testWidgets('shows the OEM reminder banner and setup-guide entry', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(
      find.text(
        'Notifications may not work reliably on your device. '
        'Tap to complete setup.',
      ),
      findsOneWidget,
    );
    expect(find.text('Battery & auto-start setup guide'), findsOneWidget);

    await tester.tap(find.text('Battery & auto-start setup guide'));
    await tester.pumpAndSettle();
    expect(find.text('Setup guide arrives in Task 13'), findsOneWidget);
  });
}
