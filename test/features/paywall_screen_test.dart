/// Tests for the paywall (Task 15 Phase 5 stub, enabled in Task 21 Phase 1).
///
/// These pin what the screen promises now that a plan can be bought: it prices
/// each plan from the shared constants, each plan action is **enabled** and
/// opens its checkout, it can always be left with the system back gesture, and
/// it shows the "Free Plan Limit Reached" card only when the 50-case gate opened
/// it. They also pin the Bengali rendering with Bengali digits.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/constants/app_typography.dart';
import 'package:legal_case_diary/core/constants/free_tier.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/payments/data/payment_plans.dart';
import 'package:legal_case_diary/features/payments/presentation/paywall_screen.dart';

void main() {
  /// Opens the paywall on top of a home route, exactly as the gate does (a
  /// pushed route is also the only one with a back arrow to test). [showLimit]
  /// mirrors the route query — true only for the 50-case gate's entry.
  Future<void> pumpPaywall(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    double statusBarHeight = 0,
    bool showLimit = false,
  }) async {
    // Tall viewport: the whole screen is on one screen, so no assertion fails
    // for the wrong reason (a lazy ListView never builds an off-screen row).
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    // A status bar to inset against. Zero is the test default so the other
    // assertions are not made to reason about an inset they do not care about.
    tester.view.padding = FakeViewPadding(top: statusBarHeight);
    tester.view.viewPadding = FakeViewPadding(top: statusBarHeight);
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
                MaterialPageRoute<void>(
                  builder: (_) => PaywallScreen(showLimit: showLimit),
                ),
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

  testWidgets('says why it opened, what the plans offer and what they cost', (
    tester,
  ) async {
    // The 50-case gate's entry: the reason card is shown.
    await pumpPaywall(tester, showLimit: true);

    expect(find.byType(PaywallScreen), findsOneWidget);
    expect(find.text('Subscription Plans'), findsOneWidget);
    expect(find.text('Free Plan Limit Reached'), findsOneWidget);
    // The sentence uses the same constant the gate enforces.
    expect(
      find.textContaining('up to $freeTierCaseLimit cases'),
      findsOneWidget,
    );
    // And it tells the user the way back that needs no payment.
    expect(find.textContaining('Deleting a case frees a slot'), findsOneWidget);

    expect(find.text('Subscription Plans Offer'), findsOneWidget);
    for (final title in <String>[
      // Unlimited Cases leads the offer (0.0.441).
      'Unlimited Cases',
      'Disaster Recovery',
      'Real-time Backup',
      'Multi-device Support',
      'Collaboration',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    for (final body in <String>[
      'Store as many cases as you need, with no limit.',
      'If your phone is lost or broken, your data is always safe in the cloud. '
          'You can login to your new device with your account to get access to '
          'your old data.',
      'Every change is instantly saved to the cloud.',
      'Access your diary from multiple devices simultaneously.',
      'Work together with your associates on the same diary.',
    ]) {
      expect(find.text(body), findsOneWidget);
    }
    // Unlimited Cases is first, so its heading sits above the rest.
    expect(
      tester.getTopLeft(find.text('Unlimited Cases')).dy,
      lessThan(tester.getTopLeft(find.text('Disaster Recovery')).dy),
    );
    // Each row carries its own icon, not one repeated tick.
    for (final icon in <IconData>[
      Icons.all_inclusive,
      Icons.cloud_done_outlined,
      Icons.cloud_upload_outlined,
      Icons.devices_outlined,
      Icons.groups_outlined,
    ]) {
      expect(find.byIcon(icon), findsOneWidget, reason: '$icon');
    }
    expect(find.byIcon(Icons.check_circle), findsNothing);

    expect(find.text('Plans'), findsOneWidget);
    for (final plan in <String>['1 Month', '3 Months', '6 Months', '1 Year']) {
      expect(find.text(plan), findsOneWidget);
    }
    // The price carries no duration of its own — the plan's name above it says
    // how long the plan runs.
    expect(find.text('৳$paywallMonthlyPrice'), findsOneWidget);
    expect(find.text('৳$paywallQuarterlyPrice'), findsOneWidget);
    expect(find.text('৳$paywallHalfYearlyPrice'), findsOneWidget);
    expect(find.text('৳960'), findsOneWidget);
    expect(find.textContaining('per month'), findsNothing);
    expect(find.textContaining('for 3 months'), findsNothing);
    expect(find.textContaining('for 6 months'), findsNothing);
    expect(find.textContaining('per year'), findsNothing);
    // The full per-month price is struck through beside each discounted plan,
    // and the badge names the saving the plan actually offers.
    expect(find.text('৳600'), findsOneWidget);
    expect(find.text('৳1,200'), findsOneWidget);
    expect(find.text('10% Off'), findsOneWidget);
    expect(find.text('20% Off'), findsOneWidget);
    // The stub's "not available yet" note is gone.
    expect(find.textContaining('not available yet'), findsNothing);
  });

  testWidgets('hides the free-limit card unless the 50-case gate opened it', (
    tester,
  ) async {
    // The Settings > Subscription > Purchase New Subscription entry (and every
    // other non-limit entry) opens the bare route, so the reason card is absent
    // while the rest of the screen still renders.
    await pumpPaywall(tester);

    expect(find.byType(PaywallScreen), findsOneWidget);
    expect(find.text('Free Plan Limit Reached'), findsNothing);
    expect(find.textContaining('up to $freeTierCaseLimit cases'), findsNothing);
    expect(find.text('Subscription Plans Offer'), findsOneWidget);
    expect(find.text('Plans'), findsOneWidget);
  });

  testWidgets('the group headings are bold and larger than a label', (
    tester,
  ) async {
    await pumpPaywall(tester);

    for (final heading in <String>['Subscription Plans Offer', 'Plans']) {
      final style = tester.widget<Text>(find.text(heading)).style!;
      expect(style.fontWeight, FontWeight.w700);
      expect(style.fontSize, greaterThan(AppTypography.labelLg.fontSize!));
    }
  });

  testWidgets('the struck-through price is red', (tester) async {
    await pumpPaywall(tester);

    for (final wasPrice in <String>['৳300', '৳600', '৳1,200']) {
      final text = tester.widget<Text>(find.text(wasPrice));
      final style = text.style!;
      expect(style.decoration, TextDecoration.lineThrough);
      expect(style.color, AppColors.error);
      expect(style.decorationColor, AppColors.error);
    }
  });

  testWidgets('leaves the phone status bar visible above its app bar', (
    tester,
  ) async {
    // The paywall is a top-level route, so the shell's SafeArea never reaches
    // it. Without its own inset the Scaffold paints its app bar up behind the
    // status bar and the clock and icons land on white instead of on black.
    await pumpPaywall(tester, statusBarHeight: 90);

    // The Scaffold starts below the inset, and its app bar keeps its own
    // height rather than growing to absorb the status bar.
    final appBar = tester.getRect(find.byType(AppBar));
    expect(appBar.top, 90);
    expect(appBar.height, lessThan(90));
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
    await pumpPaywall(
      tester,
      locale: const Locale('bn'),
      showLimit: true,
    );

    expect(find.text('সাবস্ক্রিপশন প্ল্যান'), findsOneWidget);
    expect(find.textContaining('৫০টি মামলা'), findsOneWidget);
    expect(find.text('সাবস্ক্রিপশন প্ল্যানে যা থাকে'), findsOneWidget);
    expect(find.text('দুর্যোগে ডেটা পুনরুদ্ধার'), findsOneWidget);
    expect(find.text('রিয়েল-টাইম ব্যাকআপ'), findsOneWidget);
    expect(find.text('একাধিক ডিভাইসে ব্যবহার'), findsOneWidget);
    expect(find.text('সহযোগিতা'), findsOneWidget);
    expect(find.text('১ মাস'), findsOneWidget);
    expect(find.text('৩ মাস'), findsOneWidget);
    expect(find.text('৬ মাস'), findsOneWidget);
    expect(find.text('১ বছর'), findsOneWidget);
    expect(find.text('৳১০০'), findsOneWidget);
    expect(find.text('৳২৮৫'), findsOneWidget);
    expect(find.text('৳৫৪০'), findsOneWidget);
    expect(find.text('৳৯৬০'), findsOneWidget);
    expect(find.textContaining('/ মাস'), findsNothing);
    expect(find.textContaining('/ বছর'), findsNothing);
    // The struck-through full price and the savings, in Bengali digits.
    expect(find.text('৳৬০০'), findsOneWidget);
    expect(find.text('৳১,২০০'), findsOneWidget);
    expect(find.text('১০% ছাড়'), findsOneWidget);
    expect(find.text('২০% ছাড়'), findsOneWidget);
    expect(find.text('সাবস্ক্রাইব'), findsNWidgets(subscriptionPlans.length));
  });

  test('the plan prices and features are the plan’s own', () {
    // ৳100 / ৳285 / ৳540 / ৳960, and no lifetime plan.
    expect(paywallMonthlyPrice, 100);
    expect(paywallQuarterlyPrice, 285);
    expect(paywallHalfYearlyPrice, 540);
    expect(paywallAnnualPrice, 960);
    expect(paymentPlanAmount(paymentPlanMonthly), 100);
    expect(paymentPlanAmount(paymentPlanQuarterly), 285);
    expect(paymentPlanAmount(paymentPlanHalfYearly), 540);
    expect(paymentPlanAmount(paymentPlanAnnual), 960);
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
    // Every saving is measured against the plan's own per-month rate, so a
    // badge can only claim a discount the amounts actually carry.
    expect(
      subscriptionPlans.map((p) => p.discountPercent),
      <int>[0, 5, 10, 20],
    );
    expect(
      subscriptionPlans.map((p) => p.undiscountedAmount),
      <int>[100, 300, 600, 1200],
    );
    expect(paywallFeatures, hasLength(5));
    // The five the offer section lists, in display order: Unlimited Cases leads
    // (it is the 50-case gate's answer), then the cloud features.
    expect(
      paywallFeatures,
      <PaywallFeature>[
        PaywallFeature.unlimitedCases,
        PaywallFeature.disasterRecovery,
        PaywallFeature.realTimeBackup,
        PaywallFeature.multiDevice,
        PaywallFeature.collaboration,
      ],
    );
  });
}
