import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/app.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App root smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWith((_) async => NativeDatabase.memory()),
        ],
        child: const App(),
      ),
    );

    // Wait for the DatabaseGuard to finish opening the database.
    await tester.pumpAndSettle();

    // The default locale is Bengali, so the scratch screen title should render
    // in Bengali once the first frame completes.
    expect(find.text('স্থানীয়করণ স্ক্র্যা'), findsOneWidget);
  });
}
