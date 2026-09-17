/// Tests for the Language screen (Settings → Language).
///
/// The screen is a centred choice page: a badge, a heading and a one-line
/// explanation, two full-width option cards, a preview of today's date in the
/// active language, and a note. The active language is filled black with white
/// text and a check; the other is white with black text and an outline. Each
/// label keeps its own script's font, so the English word stays in the English
/// family and বাংলা stays in Tiro Bangla whichever locale is active.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/constants/app_spacing.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/utils/date_utils.dart';
import 'package:legal_case_diary/features/settings/presentation/language_screen.dart';
import 'package:legal_case_diary/shared/providers/locale_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    // `intl` needs its locale data before the preview date can be formatted.
    await initializeDateFormatting();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  /// Pumps the screen in the app's own localized, locale-driven shell.
  Future<void> pumpScreen(WidgetTester tester, {double textScale = 1.0}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: ref.watch(localeProvider),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: const LanguageScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The [Material] carrying an option's fill and outline. The closest ancestor
  /// is the option's own Material rather than the Scaffold's.
  Material optionOf(WidgetTester tester, String label) =>
      tester.widget<Material>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Material))
            .first,
      );

  /// The tap area of an option, used to compare the pair's layout.
  Size tapAreaOf(WidgetTester tester, String label) => tester.getSize(
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
  );

  /// The style an option's label is actually rendered with.
  TextStyle styleOf(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label)).style!;

  /// The check mark painted inside an option card.
  Icon checkOf(WidgetTester tester, String label) => tester.widget<Icon>(
    find.descendant(
      of: find
          .ancestor(of: find.text(label), matching: find.byType(InkWell))
          .first,
      matching: find.byType(Icon),
    ),
  );

  /// The [Semantics] node an option uses to announce its selected state.
  Semantics semanticsOf(WidgetTester tester, String label) => tester
      .widgetList<Semantics>(
        find.ancestor(of: find.text(label), matching: find.byType(Semantics)),
      )
      .firstWhere((s) => s.properties.selected != null);

  testWidgets('frames the two choices with a heading, a preview and a note', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Select App Language'), findsOneWidget);
    expect(
      find.text(
        'Every label, date and message in the app will use the language you pick here.',
      ),
      findsOneWidget,
    );
    expect(find.text("Today's Date in This Language"), findsOneWidget);
    expect(
      find.text(
        "This changes only the app's interface. Your saved cases and notes stay exactly as they are.",
      ),
      findsOneWidget,
    );
    // The badge icon sits above the heading.
    expect(find.byIcon(Icons.language), findsOneWidget);

    // The two choices are stacked, full width and the same size.
    expect(find.text('English'), findsOneWidget);
    expect(find.text('বাংলা'), findsOneWidget);
    expect(
      tester.getCenter(find.text('English')).dy,
      lessThan(tester.getCenter(find.text('বাংলা')).dy),
    );
    expect(tapAreaOf(tester, 'English'), tapAreaOf(tester, 'বাংলা'));
  });

  testWidgets('the group starts right under the app bar, not centred', (
    tester,
  ) async {
    // A tall phone: a centred group would leave a wide gap above the badge.
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpScreen(tester);

    // The 72 px badge starts one edge margin below the app bar: a vertically
    // centred group would leave a tall gap above it instead.
    const badgeRadius = 36.0;
    final badgeTop =
        tester.getCenter(find.byIcon(Icons.language)).dy - badgeRadius;
    final bodyTop = tester.getBottomLeft(find.byType(AppBar)).dy;

    expect(badgeTop - bodyTop, AppSpacing.edgeMargin);
  });

  testWidgets('fills the active language black and outlines the other', (
    tester,
  ) async {
    await pumpScreen(tester);

    // English is the default, so it is the filled one.
    expect(optionOf(tester, 'English').color, Colors.black);
    expect(styleOf(tester, 'English').color, Colors.white);

    final other = optionOf(tester, 'বাংলা');
    expect(other.color, Colors.white);
    expect(styleOf(tester, 'বাংলা').color, Colors.black);
    expect(
      (other.shape! as RoundedRectangleBorder).side.color,
      isNot(Colors.black),
    );

    // Tapping it swaps the two states.
    await tester.tap(find.text('বাংলা'));
    await tester.pumpAndSettle();

    expect(optionOf(tester, 'বাংলা').color, Colors.black);
    expect(styleOf(tester, 'বাংলা').color, Colors.white);
    expect(optionOf(tester, 'English').color, Colors.white);
    expect(styleOf(tester, 'English').color, Colors.black);
  });

  testWidgets('only the active option carries a visible check', (tester) async {
    await pumpScreen(tester);

    expect(checkOf(tester, 'English').color, Colors.white);
    expect(checkOf(tester, 'বাংলা').color, Colors.transparent);

    await tester.tap(find.text('বাংলা'));
    await tester.pumpAndSettle();

    expect(checkOf(tester, 'বাংলা').color, Colors.white);
    expect(checkOf(tester, 'English').color, Colors.transparent);
  });

  testWidgets('marks the active option as selected for screen readers', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(semanticsOf(tester, 'English').properties.selected, isTrue);
    expect(semanticsOf(tester, 'বাংলা').properties.selected, isFalse);
    // The check mark is what announces the selection.
    expect(checkOf(tester, 'English').semanticLabel, 'Selected');
    expect(checkOf(tester, 'বাংলা').semanticLabel, isNull);

    await tester.tap(find.text('বাংলা'));
    await tester.pumpAndSettle();

    expect(semanticsOf(tester, 'বাংলা').properties.selected, isTrue);
    expect(semanticsOf(tester, 'English').properties.selected, isFalse);
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

  testWidgets('the date preview follows the language just chosen', (
    tester,
  ) async {
    await pumpScreen(tester);

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final englishDate = AppDateUtils.formatFullDate(nowMs, locale: 'en');
    final bengaliDate = AppDateUtils.formatFullDate(nowMs, locale: 'bn');
    // Guard: the preview would pass even if the locale were ignored when the
    // two languages format a date identically.
    expect(englishDate, isNot(bengaliDate));
    expect(find.text(englishDate), findsOneWidget);
    // ...and it is painted in the active language's own font.
    expect(styleOf(tester, englishDate).fontFamily, 'Inter');

    await tester.tap(find.text('বাংলা'));
    await tester.pumpAndSettle();

    expect(find.text(bengaliDate), findsOneWidget);
    expect(styleOf(tester, bengaliDate).fontFamily, 'TiroBangla');
  });

  testWidgets('switching language persists the choice', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('বাংলা'));
    await tester.pumpAndSettle();

    expect(prefs.getString('app_locale'), 'bn');
    // The screen's own copy follows the locale it just switched to.
    expect(find.text('ভাষা'), findsOneWidget);
    expect(find.text('অ্যাপের ভাষা নির্বাচন করুন'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(prefs.getString('app_locale'), 'en');
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Select App Language'), findsOneWidget);
  });

  testWidgets('scrolls instead of overflowing on a short, large-text screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpScreen(tester, textScale: 1.3);

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    // The rest of the group is reachable by scrolling, not clipped away.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('বাংলা'), findsOneWidget);
    expect(
      find.text(
        "This changes only the app's interface. Your saved cases and notes stay exactly as they are.",
      ),
      findsOneWidget,
    );
  });
}
