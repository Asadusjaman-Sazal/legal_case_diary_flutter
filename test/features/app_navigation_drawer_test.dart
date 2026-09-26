/// Guards the side-menu polish.
///
/// The selected item is filled black, and the profile header renders three
/// centre-aligned lines whose order flips between English ("Legal Case Diary /
/// of / name") and Bengali ("name / এর / লিগ্যাল কেস ডায়েরি").
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_name_store.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:legal_case_diary/shared/widgets/app_navigation_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  /// Mounts the drawer over a stored name and opens it.
  Future<void> pumpDrawer(
    WidgetTester tester, {
    required Locale locale,
    String route = AppRoutes.dailyCauseList,
  }) async {
    await ProfileStore(
      prefs,
    ).write(const ProfileFields(fullName: 'Rahim Uddin'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: Scaffold(
            drawer: AppNavigationDrawer(currentRoute: route),
            body: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await tester.pumpAndSettle();
  }

  Finder drawerText(String text) =>
      find.descendant(of: find.byType(Drawer), matching: find.text(text));

  testWidgets('the selected item is filled black', (tester) async {
    await pumpDrawer(tester, locale: const Locale('en'));

    final blackTiles = find.descendant(
      of: find.byType(Drawer),
      matching: find.byWidgetPredicate(
        (widget) => widget is Material && widget.color == Colors.black,
      ),
    );
    expect(blackTiles, findsOneWidget);
  });

  testWidgets('English header reads app, "of", name down the page', (
    tester,
  ) async {
    await pumpDrawer(tester, locale: const Locale('en'));

    expect(drawerText('Legal Case Diary'), findsOneWidget);
    expect(drawerText('of'), findsOneWidget);
    expect(drawerText('Rahim Uddin'), findsOneWidget);

    expect(
      tester.getTopLeft(drawerText('Legal Case Diary')).dy,
      lessThan(tester.getTopLeft(drawerText('of')).dy),
    );
    expect(
      tester.getTopLeft(drawerText('of')).dy,
      lessThan(tester.getTopLeft(drawerText('Rahim Uddin')).dy),
    );
    expect(tester.widget<Text>(drawerText('of')).textAlign, TextAlign.center);
  });

  testWidgets('Bengali header reads name, "এর", app down the page', (
    tester,
  ) async {
    await pumpDrawer(tester, locale: const Locale('bn'));

    expect(drawerText('Rahim Uddin'), findsOneWidget);
    expect(drawerText('এর'), findsOneWidget);
    expect(drawerText('লিগ্যাল কেস ডায়েরি'), findsOneWidget);

    expect(
      tester.getTopLeft(drawerText('Rahim Uddin')).dy,
      lessThan(tester.getTopLeft(drawerText('এর')).dy),
    );
    expect(
      tester.getTopLeft(drawerText('এর')).dy,
      lessThan(tester.getTopLeft(drawerText('লিগ্যাল কেস ডায়েরি')).dy),
    );
    expect(tester.widget<Text>(drawerText('এর')).textAlign, TextAlign.center);
  });
}
