/// Tests for notification tap routing (Task 13 Phase 1, item 5).
///
/// Both routes into a tapped notification's screen are covered — a tap that
/// *launches* the app (the launch payload decides the router's initial location)
/// and a tap while the app is already running (the listener's registered
/// handler) — and both kinds of notification the app posts: a hearing alert,
/// whose payload is the case id, and the admin payment alert, whose payload is
/// its own marker and which opens the panel's Payment Requests page.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/app.dart';
import 'package:legal_case_diary/core/providers/notification_providers.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/cases/presentation/case_detail/case_detail_screen.dart';
import 'package:legal_case_diary/core/push/payment_alert_message.dart';
import 'package:legal_case_diary/features/admin/presentation/admin_panel_screen.dart';
import 'package:legal_case_diary/features/admin/presentation/admin_payment_requests_screen.dart';
import 'package:legal_case_diary/features/cases/presentation/daily_cause_list/daily_cause_list_screen.dart';
import 'package:legal_case_diary/features/auth/data/local_auth_service.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';

import 'notification_test_support.dart';

/// Pumps the whole app with [scheduler] standing in for the platform one.
Future<AppDatabase> _pumpApp(
  WidgetTester tester,
  FakeNotificationScheduler scheduler,
) async {
  // The sign-in gate (Task 17) is satisfied: these tests are about notification
  // routing, and a device that has passed the gate is the shape they describe.
  SharedPreferences.setMockInitialValues(<String, Object>{
    authGateSatisfiedKey: true,
  });
  final prefs = await SharedPreferences.getInstance();
  late AppDatabase db;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationSchedulerProvider.overrideWithValue(scheduler),
        databaseProvider.overrideWith((_) async {
          db = AppDatabase(NativeDatabase.memory());
          return db;
        }),
      ],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

/// Unmounts the tree so live Drift streams stop before teardown.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  testWidgets('a launch from a notification opens that case detail view', (
    tester,
  ) async {
    final scheduler = FakeNotificationScheduler()..launchPayloadValue = 'case-9';
    final db = await _pumpApp(tester, scheduler);
    addTearDown(() async => db.close());

    expect(find.byType(CaseDetailScreen), findsOneWidget);
    // The default landing page (Daily Cause List) is overridden for this launch
    // only.
    expect(find.byType(DailyCauseListScreen), findsNothing);
    expect(scheduler.initializeCalls, 1);

    await _unmount(tester);
  });

  testWidgets('a launch from a payment alert opens Payment Requests', (
    tester,
  ) async {
    final scheduler = FakeNotificationScheduler()
      ..launchPayloadValue = paymentAlertPayload;
    final db = await _pumpApp(tester, scheduler);
    addTearDown(() async => db.close());

    // The cold half of the tap: the count the admin was told about is on the
    // screen that can act on it, not on a case detail named after a marker.
    expect(find.byType(AdminPaymentRequestsScreen), findsOneWidget);
    expect(find.byType(CaseDetailScreen), findsNothing);
    expect(find.byType(DailyCauseListScreen), findsNothing);

    await _unmount(tester);
  });

  testWidgets('an ordinary launch still lands on the configured page', (
    tester,
  ) async {
    final scheduler = FakeNotificationScheduler();
    final db = await _pumpApp(tester, scheduler);
    addTearDown(() async => db.close());

    expect(find.byType(CaseDetailScreen), findsNothing);
    expect(find.byType(DailyCauseListScreen), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets('closing a notification-opened detail returns to the landing page', (
    tester,
  ) async {
    final scheduler = FakeNotificationScheduler()..launchPayloadValue = 'case-9';
    final db = await _pumpApp(tester, scheduler);
    addTearDown(() async => db.close());

    // The tap made the detail the stack's only route, so Close has nothing to
    // pop back to and must go to the stored landing page instead of leaving an
    // empty navigator (the black screen).
    await tester.tap(find.byKey(const ValueKey('case-detail-close')));
    await tester.pumpAndSettle();

    expect(find.byType(CaseDetailScreen), findsNothing);
    expect(find.byType(DailyCauseListScreen), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets('a tap while the app is running opens that case detail view', (
    tester,
  ) async {
    final scheduler = FakeNotificationScheduler();
    final db = await _pumpApp(tester, scheduler);
    addTearDown(() async => db.close());

    // The listener registers its handler during startup; a tap on a posted
    // alert calls exactly this.
    expect(scheduler.notificationSelected, isNotNull);
    scheduler.notificationSelected!('case-42');
    await tester.pumpAndSettle();

    expect(find.byType(CaseDetailScreen), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets('a payment-alert tap while the app runs opens Payment Requests', (
    tester,
  ) async {
    final scheduler = FakeNotificationScheduler();
    final db = await _pumpApp(tester, scheduler);
    addTearDown(() async => db.close());

    // The warm half: the same resolver the launch path uses, so one notification
    // cannot open two different screens depending on whether the app was running.
    expect(scheduler.notificationSelected, isNotNull);
    scheduler.notificationSelected!(paymentAlertPayload);
    await tester.pumpAndSettle();

    expect(find.byType(AdminPaymentRequestsScreen), findsOneWidget);
    expect(find.byType(CaseDetailScreen), findsNothing);

    await _unmount(tester);
  });

  testWidgets('back from a payment-alert launch lands on the Admin Panel', (
    tester,
  ) async {
    final scheduler = FakeNotificationScheduler()
      ..launchPayloadValue = paymentAlertPayload;
    final db = await _pumpApp(tester, scheduler);
    addTearDown(() async => db.close());

    // The launch made Payment Requests the stack's only route, so there is
    // nothing to pop — back goes to the screen the page belongs to rather than
    // doing nothing at all.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(AdminPaymentRequestsScreen), findsNothing);
    expect(find.byType(AdminPanelScreen), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets('back from a payment-alert tap while the app runs lands on the panel', (
    tester,
  ) async {
    final scheduler = FakeNotificationScheduler();
    final db = await _pumpApp(tester, scheduler);
    addTearDown(() async => db.close());

    // A warm tap *replaces* the stack, so this entry has nothing beneath it
    // either and the same back answer must hold.
    scheduler.notificationSelected!(paymentAlertPayload);
    await tester.pumpAndSettle();
    expect(find.byType(AdminPaymentRequestsScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(AdminPaymentRequestsScreen), findsNothing);
    expect(find.byType(AdminPanelScreen), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets('the system back from a payment-alert launch lands on the panel', (
    tester,
  ) async {
    final scheduler = FakeNotificationScheduler()
      ..launchPayloadValue = paymentAlertPayload;
    final db = await _pumpApp(tester, scheduler);
    addTearDown(() async => db.close());

    // The Android back gesture is the same way out as the arrow, so it cannot
    // leave the admin on a page with no way back to the panel.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(AdminPaymentRequestsScreen), findsNothing);
    expect(find.byType(AdminPanelScreen), findsOneWidget);

    await _unmount(tester);
  });
}
