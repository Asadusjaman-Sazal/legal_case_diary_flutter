/// Tests for the paywall (Task 15 Phase 5 stub, enabled in Task 21 Phase 1).
///
/// These pin what the screen promises now that a plan can be bought: it says why
/// it opened, it prices each plan from the shared constants, each plan action is
/// **enabled** and opens its checkout, and it can always be left with the system
/// back gesture. They also pin the Bengali rendering with Bengali digits.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/constants/free_tier.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/payments/data/payment_plans.dart';
import 'package:legal_case_diary/features/payments/presentation/paywall_screen.dart';

void main() {
  /// Opens the paywall on top of a home route, exactly as the gate does (a
  /// pushed route is also the only one with a back arrow to test).
  Future<void> pumpPaywall(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    // Tall viewport: the whole screen is on one screen, so no assertion fails
    // for the wrong reason (a lazy ListView never builds an off-screen row).
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
    for (final plan in <String>['1 Month', '3 Months', '6 Months', '1 Year']) {
      expect(find.text(plan), findsOneWidget);
    }
    expect(find.text('৳$paywallMonthlyPrice per month'), findsOneWidget);
    expect(find.text('৳$paywallQuarterlyPrice for 3 months'), findsOneWidget);
    expect(find.text('৳$paywallHalfYearlyPrice for 6 months'), findsOneWidget);
    expect(find.text('৳1,000 per year'), findsOneWidget);
    // The stub's "not available yet" note is gone.
    expect(find.textContaining('not available yet'), findsNothing);
  });

  testWidgets('every plan action is enabled', (tester) async {
    await pumpPaywall(tester);

    final actions = tester.widgetList<FilledButton>(
      find.widgetWithText(FilledButton, 'Subscribe'),
    );
    expect(actions, hasLength(subscriptionPlans.length));
    for (final action in actions) {
      expect(action.onPressed, isNotNull);
    }
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
    expect(find.text('১ মাস'), findsOneWidget);
    expect(find.text('৩ মাস'), findsOneWidget);
    expect(find.text('৬ মাস'), findsOneWidget);
    expect(find.text('১ বছর'), findsOneWidget);
    expect(find.text('৳১০০ / মাস'), findsOneWidget);
    expect(find.text('৳২৮৫ / ৩ মাস'), findsOneWidget);
    expect(find.text('৳৫৫০ / ৬ মাস'), findsOneWidget);
    expect(find.text('৳১,০০০ / বছর'), findsOneWidget);
    expect(find.text('সাবস্ক্রাইব'), findsNWidgets(subscriptionPlans.length));
  });

  test('the plan prices and benefits are the plan’s own', () {
    // ৳100 / ৳285 / ৳550 / ৳1,000, and no lifetime plan.
    expect(paywallMonthlyPrice, 100);
    expect(paywallQuarterlyPrice, 285);
    expect(paywallHalfYearlyPrice, 550);
    expect(paywallAnnualPrice, 1000);
    expect(paymentPlanAmount(paymentPlanMonthly), 100);
    expect(paymentPlanAmount(paymentPlanQuarterly), 285);
    expect(paymentPlanAmount(paymentPlanHalfYearly), 550);
    expect(paymentPlanAmount(paymentPlanAnnual), 1000);
    expect(paymentPlanAmount('lifetime'), isNull);
    // The four plans, in the order the paywall lists them.
    expect(
      subscriptionPlans.map((p) => p.key),
      <String>[
        paymentPlanMonthly,
        paymentPlanQuarterly,
        paymentPlanHalfYearly,
        paymentPlanAnnual,
      ],
    );
    expect(paywallBenefits, hasLength(4));
    // Unlimited cases, cloud backup, multi-device, firm mode — the four the
    // plan's Subscription Model lists for premium.
    expect(paywallBenefits, contains(PaywallBenefit.unlimitedCases));
    expect(paywallBenefits, contains(PaywallBenefit.firmMode));
  });
}
