import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/app.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/cases/presentation/all_cases/all_cases_screen.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App root smoke test — router lands on All Cases', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
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

    // Default landing page is All Cases (Task 07 production host). The
    // header title is localized (default locale is Bengali), so assert the
    // screen type instead of a text string.
    expect(find.byType(AllCasesScreen), findsOneWidget);
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
