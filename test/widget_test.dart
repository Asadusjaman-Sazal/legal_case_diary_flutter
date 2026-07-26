import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/app.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App root smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const App(),
      ),
    );

    // The default locale is Bengali, so the scratch screen title should render
    // in Bengali once the first frame completes.
    expect(find.text('স্থানীয়করণ স্ক্র্যা'), findsOneWidget);
  });
}
