import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/app.dart';

void main() {
  testWidgets('App root smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const App());

    // Verify that our placeholder text appears.
    expect(find.text('Legal Case Diary — Offline First'), findsOneWidget);
  });
}
