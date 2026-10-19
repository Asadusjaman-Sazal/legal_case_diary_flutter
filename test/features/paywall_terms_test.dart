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

  testWidgets('the toggle stays put while the intro scrolls away', (
    tester,
  ) async {
    await pumpPaywall(tester, height: 800);

    final intro = find.text('Choose the plan that fits your practice.');
    final toggle = find.byKey(const ValueKey('paywall-audience-individual'));
    final starter = find.byKey(const ValueKey('paywall-plan-starter'));
    expect(intro, findsOneWidget);

    final toggleBefore = tester.getRect(toggle);
    final starterBefore = tester.getRect(starter);
    // The intro sits above the toggle, and the toggle above the first card.
    expect(tester.getRect(intro).top, lessThan(toggleBefore.top));
    expect(toggleBefore.top, lessThan(starterBefore.top));

    // Scroll past the intro: the toggle travels up with it, then stops dead at
    // the top of the viewport.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    final pinned = tester.getRect(toggle);
    expect(pinned.top, lessThan(toggleBefore.top));
    // The cards kept going under it, and the intro — above the toggle — is
    // unmounted once it is out of view.
    expect(tester.getRect(starter).top, lessThan(starterBefore.top));
    expect(intro, findsNothing);

    // ...and scrolling further leaves the toggle exactly where it is.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getRect(toggle), pinned);
  });
}
