/// Tests for the Case Types, Steps etc category cards (Task 12 Phase 3).
///
/// The screen lists the seeded court hierarchy only (the two higher-court
/// divisions plus the 6 lower-court categories) and every card starts
/// collapsed: the category name is visible, its management buttons are not,
/// and tapping the card opens it — one card at a time. The higher-court
/// divisions offer no Steps button: their cases use the Result text box.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/constants/app_spacing.dart';
import 'package:legal_case_diary/core/constants/pre_seeded_data.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/features/settings/presentation/edit_court_steps/court_names_steps_screen.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_menu_card.dart';

/// The 8 category cards, in the order the screen renders them.
const _labels = <String>[
  'Appellate Division',
  'High Court Division',
  'District Courts (Civil)',
  'Sessions Courts (Criminal)',
  'Metropolitan Sessions (Criminal)',
  'Chief Judicial Magistrate',
  'Chief Metropolitan Magistrate',
  'Executive Magistrate',
];

/// Pumps the card screen and returns the locations pushed by its buttons.
///
/// The item-list route is stubbed: the real one reads Drift, which this suite
/// has no use for — only the location each button pushes matters here.
Future<List<Uri>> _pumpCards(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  final pushed = <Uri>[];
  final router = GoRouter(
    initialLocation: '/cards',
    routes: [
      GoRoute(path: '/cards', builder: (_, _) => const CourtNamesStepsScreen()),
      GoRoute(
        path: AppRoutes.settingsCourtNamesSteps,
        builder: (context, state) {
          pushed.add(state.uri);
          return const Scaffold(body: SizedBox.shrink());
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  // All 8 cards are asserted, so the window has to be tall enough to render
  // the whole list (a lazy ListView would skip the off-screen ones).
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
  return pushed;
}

/// Size of the button whose label is [label] (its decorated container).
Size _buttonSize(WidgetTester tester, String label) => tester.getSize(
  find.ancestor(of: find.text(label), matching: find.byType(Container)).first,
);

void main() {
  testWidgets('lists the seeded hierarchy only, buttons hidden', (
    tester,
  ) async {
    await _pumpCards(tester);

    expect(find.text('Case Types, Steps etc'), findsOneWidget);
    for (final label in _labels) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(
      find.byType(Card),
      findsNWidgets(allCategoryIds.length),
      reason: 'exactly the 8 seeded categories',
    );
    expect(find.text('Tribunals'), findsNothing);

    // Cards render in the seeded order, top to bottom.
    final tops = _labels
        .map((label) => tester.getTopLeft(find.text(label)).dy)
        .toList();
    expect(tops, orderedEquals(<double>[...tops]..sort()));

    // The same 8 px between cards as the Edit Court/Steps sub-menu keeps
    // between its cards, and no icon on any card (user request, 0.0.612).
    final firstBottom = tester.getBottomLeft(find.byType(Card).at(0)).dy;
    final secondTop = tester.getTopLeft(find.byType(Card).at(1)).dy;
    expect(secondTop - firstBottom, AppSpacing.sm);
    expect(find.byIcon(Icons.expand_more), findsNothing);
    expect(find.byIcon(Icons.expand_less), findsNothing);

    expect(find.text('Case Types'), findsNothing);
    expect(find.text('Steps'), findsNothing);
    expect(find.text('On Behalf'), findsNothing);
  });

  testWidgets('tapping a card reveals its buttons and grows the card', (
    tester,
  ) async {
    await _pumpCards(tester);
    final collapsed = tester.getSize(find.byType(Card).first);

    await tester.tap(find.text('Appellate Division'));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(Card).first).height,
      greaterThan(collapsed.height),
    );
    expect(find.text('Case Types'), findsOneWidget);
    expect(find.text('On Behalf'), findsOneWidget);
    // The higher-court divisions have no steps: their cases use Result.
    expect(find.text('Steps'), findsNothing);

    // Only this card opened: the other seven still show no buttons.
    expect(
      find.descendant(of: find.byType(Card), matching: find.byType(Container)),
      findsNWidgets(2),
    );

    await tester.tap(find.text('Appellate Division'));
    await tester.pumpAndSettle();
    expect(find.text('Case Types'), findsNothing);
    expect(tester.getSize(find.byType(Card).first).height, collapsed.height);
  });

  testWidgets('opening a card closes the one that was open', (tester) async {
    await _pumpCards(tester);
    final collapsed = tester.getSize(find.byType(Card).first).height;

    await tester.tap(find.text('Appellate Division'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(Card).first,
        matching: find.text('Case Types'),
      ),
      findsOneWidget,
    );

    // Open the third card: its buttons appear, the first card's go away.
    final thirdCard = find.byType(Card).at(2);
    await tester.tap(find.text('District Courts (Civil)'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: thirdCard, matching: find.text('Case Types')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(Card).first,
        matching: find.text('Case Types'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byType(Card), matching: find.byType(Container)),
      findsNWidgets(3),
      reason: 'only the newly opened card carries buttons',
    );
    expect(tester.getSize(find.byType(Card).first).height, collapsed);
    expect(tester.getSize(thirdCard).height, greaterThan(collapsed));
  });

  testWidgets('the three buttons share the card width evenly, in card shape', (
    tester,
  ) async {
    await _pumpCards(tester);
    await tester.tap(find.text('District Courts (Civil)'));
    await tester.pumpAndSettle();

    const buttonLabels = <String>['Case Types', 'Steps', 'On Behalf'];
    final sizes = buttonLabels.map((l) => _buttonSize(tester, l)).toList();
    final lefts = buttonLabels
        .map((l) => tester.getTopLeft(find.text(l)).dx)
        .toList();

    // All three the same size, on one row, left to right.
    for (final size in sizes) {
      expect(size.height, 44.0);
      expect(size.width, closeTo(sizes.first.width, 0.01));
    }
    for (final label in buttonLabels) {
      expect(
        tester.getTopLeft(find.text(label)).dy,
        closeTo(tester.getTopLeft(find.text(buttonLabels.first)).dy, 0.01),
      );
    }
    expect(lefts[1], greaterThan(lefts[0]));
    expect(lefts[2], greaterThan(lefts[1]));

    // Together with the two 8 px gaps they fill the width the card leaves for
    // its content — the same width its name row occupies.
    final innerWidth = tester
        .getSize(
          find
              .ancestor(
                of: find.text('District Courts (Civil)'),
                matching: find.byType(ConstrainedBox),
              )
              .first,
        )
        .width;
    expect(
      sizes.fold<double>(0, (sum, s) => sum + s.width) + 16.0,
      closeTo(innerWidth, 0.01),
    );

    // Buttons carry the card's own shape, not a pill.
    expect(
      (tester.widget<Card>(find.byType(Card).first).shape
              as RoundedRectangleBorder)
          .borderRadius,
      BorderRadius.circular(settingsMenuCardRadius),
    );
    for (final label in buttonLabels) {
      final container = tester.widget<Container>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Container))
            .first,
      );
      expect(
        (container.decoration! as BoxDecoration).borderRadius,
        BorderRadius.circular(settingsMenuCardRadius),
        reason: label,
      );
    }
  });

  testWidgets('higher-court divisions offer no Steps', (tester) async {
    await _pumpCards(tester);

    for (final label in <String>['Appellate Division', 'High Court Division']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      final card = find.ancestor(
        of: find.text(label),
        matching: find.byType(Card),
      );
      expect(
        find.descendant(of: card, matching: find.text('Case Types')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('On Behalf')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('Steps')),
        findsNothing,
        reason: '$label has no steps',
      );
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('a button opens its kind for that category', (tester) async {
    final pushed = await _pumpCards(tester);

    await tester.tap(find.text('Metropolitan Sessions (Criminal)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Steps'));
    await tester.pumpAndSettle();

    expect(pushed, hasLength(1));
    expect(pushed.single.path, AppRoutes.settingsCourtNamesSteps);
    expect(pushed.single.queryParameters, <String, String>{
      'kind': 'steps',
      'category': metropolitanSessionsJudgeCriminalId,
    });
  });

  testWidgets('the category names follow the language', (tester) async {
    await _pumpCards(tester, locale: const Locale('bn'));

    expect(find.text('আপিল বিভাগ'), findsOneWidget);
    expect(find.text('মেট্রোপলিটন সেশন (ফৌজদারি)'), findsOneWidget);
  });
}
