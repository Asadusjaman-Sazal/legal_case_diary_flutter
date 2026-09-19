/// Tests for notification tap routing (Task 13 Phase 1, item 5).
///
/// Both routes into the case detail view are covered: a tap that *launches* the
/// app (the launch payload decides the router's initial location) and a tap
/// while the app is already running (the listener's registered handler).
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/app.dart';
import 'package:legal_case_diary/core/providers/notification_providers.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/cases/presentation/all_cases/all_cases_screen.dart';
import 'package:legal_case_diary/features/cases/presentation/case_detail/case_detail_screen.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';

import 'notification_test_support.dart';

/// Pumps the whole app with [scheduler] standing in for the platform one.
Future<AppDatabase> _pumpApp(
  WidgetTester tester,
  FakeNotificationScheduler scheduler,
) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
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
    final scheduler = FakeNotificationScheduler()..launchCaseIdValue = 'case-9';
    final db = await _pumpApp(tester, scheduler);
    addTearDown(() async => db.close());

    expect(find.byType(CaseDetailScreen), findsOneWidget);
    // The stored landing page (All Cases) is overridden for this launch only.
    expect(find.byType(AllCasesScreen), findsNothing);
    expect(scheduler.initializeCalls, 1);

    await _unmount(tester);
  });

  testWidgets('an ordinary launch still lands on the configured page', (
    tester,
  ) async {
    final scheduler = FakeNotificationScheduler();
    final db = await _pumpApp(tester, scheduler);
    addTearDown(() async => db.close());

    expect(find.byType(CaseDetailScreen), findsNothing);
    expect(find.byType(AllCasesScreen), findsOneWidget);

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
    expect(scheduler.caseSelected, isNotNull);
    scheduler.caseSelected!('case-42');
    await tester.pumpAndSettle();

    expect(find.byType(CaseDetailScreen), findsOneWidget);

    await _unmount(tester);
  });
}
