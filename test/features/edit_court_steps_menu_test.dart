/// Edit Court/Steps menu labels and card order.
///
/// The first card is the broad Court Categories entry, and Law Names follows
/// the Case Types, Step etc card (user request, 0.0.828).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/features/settings/presentation/edit_court_steps/edit_court_steps_menu.dart';

import 'settings_test_support.dart';

void main() {
  testWidgets('the menu renames the first card and puts Law Names last', (
    WidgetTester tester,
  ) async {
    await pumpSettingsRouter(
      tester,
      location: '/',
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (context, state) => const EditCourtStepsMenu()),
      ],
    );

    expect(find.text('Court Categories'), findsOneWidget);
    expect(find.text('Lower Court Categories'), findsNothing);

    final courtCategories = tester.getTopLeft(find.text('Court Categories')).dy;
    final courtNames = tester.getTopLeft(find.text('Court Names')).dy;
    final itemTypes = tester.getTopLeft(find.text('Case Types, Step etc')).dy;
    final lawNames = tester.getTopLeft(find.text('Law Names')).dy;

    expect(courtCategories, lessThan(courtNames));
    expect(courtNames, lessThan(itemTypes));
    expect(itemTypes, lessThan(lawNames));
  });
}