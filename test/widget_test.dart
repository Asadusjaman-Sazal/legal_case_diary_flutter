import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/app.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/cases/presentation/daily_cause_list/daily_cause_list_screen.dart';
import 'package:legal_case_diary/features/auth/data/local_auth_service.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App root smoke test — router lands on Daily Cause List', (
    WidgetTester tester,
  ) async {
    // Task 17's sign-in gate is satisfied, so this smoke test keeps testing what
    // it is about: a device that has passed the gate opens on its configured
    // landing page. What a *fresh* install opens on (the Login screen) is pinned
    // by the auth gate suite.
    SharedPreferences.setMockInitialValues(<String, Object>{
      authGateSatisfiedKey: true,
    });
    final prefs = await SharedPreferences.getInstance();
    late AppDatabase db;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWith((_) async {
            db = AppDatabase(NativeDatabase.memory());
            return db;
          }),
        ],
        child: const App(),
      ),
    );

    addTearDown(() async => await db.close());

    // Wait for the DatabaseGuard and router to settle.
    await tester.pumpAndSettle();

    // A fresh install has no stored preference, so it lands on the default
    // landing page: Daily Cause List (plan §10.1). The header title is localized
    // (default locale is Bengali), so assert the screen type, not a text string.
    expect(find.byType(DailyCauseListScreen), findsOneWidget);
    expect(find.byType(SafeArea), findsOneWidget);
    final systemUi = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );
    expect(systemUi.value.statusBarColor, Colors.black);
    expect(systemUi.value.statusBarIconBrightness, Brightness.light);
    expect(systemUi.value.statusBarBrightness, Brightness.dark);
    expect(find.text('Daily Cause List — Task 09'), findsNothing);

    // Unmount the scope inside the test body so the drift stream-cleanup
    // zero-timer from CasesScreenModal's settings watch fires before the
    // framework checks for pending timers at teardown.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
