/// Subscription plans screen (paywall) changes, 2026-10-19:
///
///  * the six-tier cards got breathing room between them and taller text lines;
///  * the default term is each audience's own (1 Month for Individual, 6 Months
///    for Firm), and a term can no longer be deselect: a card always carries one;
///  * each term button gained its undiscounted price and saving underneath;
///  * the Firm terms are a plain choice under the price line, with no "Or choose".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/features/payments/presentation/paywall_screen.dart';

void main() {
  /// Opens the paywall over a free profile; only the term logic is under test.
  ///
  /// [height] is the logical viewport height. The default fits the whole page so
  /// a test can assert on any card without scrolling; the pinned-toggle test
  /// shrinks it so there is something left to scroll.
  Future<void> pumpPaywall(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    double height = 4200,
  }) async {
    tester.view.physicalSize = Size(1200, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountProfileProvider.overrideWith(
            (ref) => Stream.value(null),
          ),
          firmMemberProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: const PaywallScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Individual cards open on 1 Month, Firm cards on 6 Months', (
    tester,
  ) async {
    await pumpPaywall(tester);

    // Starter and Pro lead with one month: the one-month plan is the base price
    // and no term button is selected.
    expect(find.text('Subscribe — ৳60/month'), findsOneWidget);
    expect(find.text('Subscribe — ৳120/month'), findsOneWidget);
    expect(find.textContaining('3 Months/'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('paywall-audience-firm')));
    await tester.pumpAndSettle();

    // Firm, Firm Plus and Enterprise open on their six-month plan.
    expect(find.text('Subscribe — 6 Months/৳1,250'), findsOneWidget);
    expect(find.text('Subscribe — 6 Months/৳2,500'), findsOneWidget);
    expect(find.text('Subscribe — 6 Months/৳7,500'), findsOneWidget);
  });

  testWidgets('tapping the selected term keeps it selected', (tester) async {
    await pumpPaywall(tester);

    await tester.tap(
      find.byKey(const ValueKey('paywall-term-starter-starter_half_yearly')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Subscribe — 6 Months/৳300'), findsOneWidget);

    // Selecting the chosen term again is a no-op, not a clear.
    await tester.tap(
      find.byKey(const ValueKey('paywall-term-starter-starter_half_yearly')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Subscribe — 6 Months/৳300'), findsOneWidget);
  });

  testWidgets('six-month and yearly buttons name their undiscounted price', (
    tester,
  ) async {
    await pumpPaywall(tester);

    // 6 months costs 5 monthly payments, 1 year costs 10.
    expect(find.text('৳360'), findsWidgets);
    expect(find.text('৳60 Off'), findsWidgets);
    expect(find.text('৳720'), findsWidgets);
    expect(find.text('৳120 Off'), findsWidgets);
  });

  testWidgets('Firm cards say no "Or choose"', (tester) async {
    await pumpPaywall(tester);
    expect(find.text('Or choose'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('paywall-audience-firm')));
    await tester.pumpAndSettle();
    expect(find.text('Or choose'), findsNothing);
  });

  testWidgets('the toggle scrolls away with the intro, not pinned', (
    tester,
  ) async {
    await pumpPaywall(tester, height: 800);

    final toggle = find.byKey(const ValueKey('paywall-audience-individual'));
    final starter = find.byKey(const ValueKey('paywall-plan-starter'));
    final toggleBefore = tester.getRect(toggle);
    final starterBefore = tester.getRect(starter);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    // The toggle moved up with the page (or left the tree) rather than staying
    // at a fixed offset the way a pinned header would.
    final movedAway =
        toggle.evaluate().isEmpty ||
        tester.getRect(toggle).top < toggleBefore.top;
    expect(movedAway, isTrue);
    // The cards scrolled too, so this is ordinary scrolling, not a layout jump.
    expect(tester.getRect(starter).top, lessThan(starterBefore.top));
  });

  testWidgets('a touched card inks, and stays inked until another is touched', (
    tester,
  ) async {
    await pumpPaywall(tester);

    final starter = find.byKey(const ValueKey('paywall-plan-starter'));
    final pro = find.byKey(const ValueKey('paywall-plan-pro'));

    // No card has been touched: even Most Popular and Current Plan are grey.
    expect(_cardBorder(tester, starter).color, AppColors.outlineVariant);
    expect(_cardBorder(tester, pro).color, AppColors.outlineVariant);
    expect(
      _cardBorder(tester, find.byKey(const ValueKey('paywall-plan-free'))).color,
      AppColors.outlineVariant,
    );

    // Touch Starter and lift: the ink stays after the finger is gone.
    await tester.tap(starter);
    await tester.pumpAndSettle();
    expect(_cardBorder(tester, starter).color, AppColors.primary);
    expect(_cardBorder(tester, starter).width, 2);
    expect(_cardBorder(tester, pro).color, AppColors.outlineVariant);

    // Touch Pro: the ink moves, and Starter goes back to grey.
    await tester.tap(pro);
    await tester.pumpAndSettle();
    expect(_cardBorder(tester, pro).color, AppColors.primary);
    expect(_cardBorder(tester, starter).color, AppColors.outlineVariant);
  });

  testWidgets('the selected term is marked with the ink outline, not green', (
    tester,
  ) async {
    await pumpPaywall(tester);

    final selected = find.byKey(
      const ValueKey('paywall-term-starter-starter_quarterly'),
    );
    final unselected = find.byKey(
      const ValueKey('paywall-term-starter-starter_half_yearly'),
    );
    expect(_termBorder(tester, unselected).color, AppColors.outlineVariant);

    await tester.tap(selected);
    await tester.pumpAndSettle();

    final border = _termBorder(tester, selected);
    expect(border.color, AppColors.primary);
    expect(border.color, isNot(AppColors.success));
    expect(border.width, 2);
  });

  testWidgets('the action is 54 tall', (tester) async {
    await pumpPaywall(tester);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('paywall-subscribe-starter')),
    );
    expect(button.style?.minimumSize?.resolve({}), const Size.fromHeight(54));
  });
}

/// The border of a card's frame, which is an [AnimatedContainer].
BorderSide _cardBorder(WidgetTester tester, Finder card) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(of: card, matching: find.byType(AnimatedContainer)).first,
  );
  return ((container.decoration! as BoxDecoration).border! as Border).top;
}

/// The border of one term button's inner container.
BorderSide _termBorder(WidgetTester tester, Finder term) {
  final container = tester.widget<Container>(
    find.descendant(of: term, matching: find.byType(Container)).first,
  );
  final decoration = container.decoration! as BoxDecoration;
  return (decoration.border! as Border).top;
}
