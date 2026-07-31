import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/app.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App root smoke test — router lands on Daily Cause List',
      (WidgetTester tester) async {
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

    // Default landing page is Daily Cause List (stub text from Task 09).
    expect(find.text('Daily Cause List — Task 09'), findsOneWidget);
  });
}
