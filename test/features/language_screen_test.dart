/// Tests for the Language screen (Settings → Language).
///
/// The screen is a single-line pair of buttons: black with white text for the
/// active language, white with black text and an outline for the other. Each
/// label keeps its own script's font, so the English word stays in the English
/// family and বাংলা stays in Tiro Bangla whichever locale is active.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/settings/presentation/language_screen.dart';
import 'package:legal_case_diary/shared/providers/locale_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  /// Pumps the screen in the app's own localized, locale-driven shell.
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: ref.watch(localeProvider),
            home: const LanguageScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The [Material] carrying a button's fill and outline. The closest ancestor
  /// is the button's own Material rather than the Scaffold's.
  Material buttonOf(WidgetTester tester, String label) =>
      tester.widget<Material>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Material))
            .first,
      );

  /// The tap area of a button, used to compare the pair's layout.
  Size tapAreaOf(WidgetTester tester, String label) => tester.getSize(
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
  );

  /// The style a button's label is actually rendered with.
  TextStyle styleOf(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label)).style!;

  testWidgets('shows English and বাংলা side by side on one line', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('বাংলা'), findsOneWidget);

    // One line, equal halves.
    expect(
      tester.getCenter(find.text('English')).dy,
      tester.getCenter(find.text('বাংলা')).dy,
    );
    expect(tapAreaOf(tester, 'English'), tapAreaOf(tester, 'বাংলা'));
  });

  testWidgets('fills the active language black and outlines the other', (
    tester,
  ) async {
    await pumpScreen(tester);

    // English is the default, so it is the filled one.
    expect(buttonOf(tester, 'English').color, Colors.black);
    expect(styleOf(tester, 'English').color, Colors.white);

    final other = buttonOf(tester, 'বাংলা');
    expect(other.color, Colors.white);
    expect(styleOf(tester, 'বাংলা').color, Colors.black);
    expect(
      (other.shape! as RoundedRectangleBorder).side.color,
      isNot(Colors.black),
    );

    // Tapping it swaps the two states.
    await tester.tap(find.text('বাংলা'));
    await tester.pumpAndSettle();

    expect(buttonOf(tester, 'বাংলা').color, Colors.black);
    expect(styleOf(tester, 'বাংলা').color, Colors.white);
    expect(buttonOf(tester, 'English').color, Colors.white);
    expect(styleOf(tester, 'English').color, Colors.black);
  });

  testWidgets('each label keeps its own script font in both locales', (
    tester,
  ) async {
    await pumpScreen(tester);

    // English active: the Bengali word must not render in the English family.
    expect(styleOf(tester, 'English').fontFamily, 'Inter');
    expect(styleOf(tester, 'বাংলা').fontFamily, 'TiroBangla');

    await tester.tap(find.text('বাংলা'));
    await tester.pumpAndSettle();

    // Bengali active: the theme switches to Tiro Bangla app-wide, yet the
    // English label still renders in the English family.
    expect(styleOf(tester, 'English').fontFamily, 'Inter');
    expect(styleOf(tester, 'বাংলা').fontFamily, 'TiroBangla');
  });

  testWidgets('switching language persists the choice', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('বাংলা'));
    await tester.pumpAndSettle();

    expect(prefs.getString('app_locale'), 'bn');
    // The screen's own copy follows the locale it just switched to.
    expect(find.text('ভাষা'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(prefs.getString('app_locale'), 'en');
    expect(find.text('Language'), findsOneWidget);
  });
}
