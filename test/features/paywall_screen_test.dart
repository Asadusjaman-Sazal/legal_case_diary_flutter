/// Tests for the paywall stub (Task 15 Phase 5).
///
/// The stub has no mockup — the real screen arrives in Task 21 — so these tests
/// pin what it promises today: it says why it opened, it prices both plans, no
/// plan action can start a payment, and it can always be left with the system
/// back gesture. They also pin the two things that must never drift apart: the
/// limit in the sentence and the constant the gate enforces, and the Bengali
/// rendering with Bengali digits.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/constants/free_tier.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/payments/presentation/paywall_screen.dart';

void main() {
  /// Opens the paywall on top of a home route, exactly as the gate does (a
  /// pushed route is also the only one with a back arrow to test).
  Future<void> pumpPaywall(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    // Tall viewport: the whole stub is on one screen, so no assertion fails for
    // the wrong reason (a lazy ListView never builds an off-screen row).
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              key: const ValueKey('open-paywall'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PaywallScreen()),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-paywall')));
    await tester.pumpAndSettle();
  }

  testWidgets('says why it opened, what premium adds and what it costs', (
    tester,
  ) async {
    await pumpPaywall(tester);

    expect(find.byType(PaywallScreen), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('Free Plan Limit Reached'), findsOneWidget);
    // The sentence uses the same constant the gate enforces.
    expect(
      find.textContaining('up to $freeTierCaseLimit cases'),
      findsOneWidget,
    );
    // And it tells the user the way back that needs no payment.
    expect(find.textContaining('Deleting a case frees a slot'), findsOneWidget);

    expect(find.text('Premium Includes'), findsOneWidget);
    for (final benefit in <String>[
      'Unlimited cases',
      'Secure encrypted cloud backup',
      'Your diary on every device you sign in on',
      'Firm mode for your associates',
    ]) {
      expect(find.text(benefit), findsOneWidget);
    }

    expect(find.text('Plans'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Annual'), findsOneWidget);
    expect(find.text('৳$paywallMonthlyPrice per month'), findsOneWidget);
    expect(find.text('৳1,000 per year'), findsOneWidget);
    // The stub says outright that it cannot take money yet.
    expect(
      find.textContaining('Subscriptions are not available yet'),
      findsOneWidget,
    );
  });

  testWidgets('no plan action can start a payment', (tester) async {
    await pumpPaywall(tester);

    final actions = tester.widgetList<FilledButton>(
      find.widgetWithText(FilledButton, 'Coming Soon'),
    );
    expect(actions, hasLength(2));
    for (final action in actions) {
      expect(action.onPressed, isNull);
    }

    // Tapping one changes nothing: no route, no message, no crash.
    await tester.tap(find.text('Coming Soon').first);
    await tester.pumpAndSettle();
    expect(find.byType(PaywallScreen), findsOneWidget);
  });

  testWidgets('the back arrow returns the user where they were', (
    tester,
  ) async {
    await pumpPaywall(tester);
    expect(find.byType(PaywallScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // The gate's cancel path: the user keeps every case they had.
    expect(find.byType(PaywallScreen), findsNothing);
    expect(find.byKey(const ValueKey('open-paywall')), findsOneWidget);
  });

  testWidgets('renders in Bengali with Bengali digits', (tester) async {
    await pumpPaywall(tester, locale: const Locale('bn'));

    expect(find.text('প্রিমিয়াম'), findsOneWidget);
    expect(find.textContaining('৫০টি মামলা'), findsOneWidget);
    expect(find.text('৳১০০ / মাস'), findsOneWidget);
    expect(find.text('৳১,০০০ / বছর'), findsOneWidget);
    expect(find.text('শীঘ্রই আসছে'), findsNWidgets(2));
  });

  test('the stub carries the plan’s own prices and benefits', () {
    // ৳100 per month, ৳1,000 per year, and no lifetime plan (plan §Pricing).
    expect(paywallMonthlyPrice, 100);
    expect(paywallAnnualPrice, 1000);
    expect(paywallBenefits, hasLength(4));
    // Unlimited cases, cloud backup, multi-device, firm mode — the four the
    // plan's Subscription Model lists for premium.
    expect(paywallBenefits, contains(PaywallBenefit.unlimitedCases));
    expect(paywallBenefits, contains(PaywallBenefit.firmMode));
  });
}
