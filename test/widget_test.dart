import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/app.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App root smoke test', (WidgetTester tester) async {
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

    // Wait for the DatabaseGuard to finish opening the database.
    await tester.pumpAndSettle();

    // The default locale is Bengali, so the scratch screen title should render
    // in Bengali once the first frame completes.
    expect(find.text('স্থানীয়করণ স্ক্র্যা'), findsOneWidget);
  });
}
