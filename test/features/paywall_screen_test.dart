/// Tests for the paywall (Task 15 Phase 5 stub, enabled in Task 21 Phase 1).
///
/// These pin what the screen promises now that a plan can be bought: it prices
/// each plan from the shared constants, each plan action is **enabled** and
/// opens its checkout, it can always be left with the system back gesture, and
/// it shows the "Free Plan Limit Reached" card only when the 50-case gate opened
/// it. They also pin the Bengali rendering with Bengali digits.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/constants/app_typography.dart';
import 'package:legal_case_diary/core/constants/free_tier.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/features/payments/data/payment_plans.dart';
import 'package:legal_case_diary/features/payments/presentation/paywall_screen.dart';

void main() {
  /// Opens the paywall on top of a home route, exactly as the gate does (a
  /// pushed route is also the only one with a back arrow to test). [showLimit]
  /// mirrors the route query — true only for the 50-case gate's entry. [tier]
  /// overrides the tier the account holds, which is what decides how much of the
  /// ladder is offered; null leaves the real provider in place (an empty cache,
  /// i.e. Free).
  Future<void> pumpPaywall(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    double statusBarHeight = 0,
    bool showLimit = false,
    SubscriptionTier? tier,
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

    // The plans section reads the account's tier from the cached profile, so
    // the paywall now needs a scope. Unless [tier] says otherwise nothing is
    // overridden and no profile row is seeded, so the cache is empty and the
    // tier reads Free — the state a genuinely new account is in.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (tier != null) currentTierProvider.overrideWithValue(tier),
        ],
        child: MaterialApp(
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
    // A free account is sold Pro alone: it may buy its own tier or lower, and
    // Pro is the entry tier. So Pro's card is the only tier card on screen, and
    // neither of the chamber tiers the account cannot buy is named at all.
    expect(find.text('Pro'), findsOneWidget);
    for (final hidden in <String>['Firm', 'Firm Plus']) {
      expect(find.text(hidden), findsNothing, reason: hidden);
    }
    expect(find.text('1 Month'), findsOneWidget);
    expect(find.text('3 Months'), findsOneWidget);
    expect(find.text('6 Months'), findsOneWidget);
    expect(find.text('1 Year'), findsOneWidget);
    // Flat prices, written as their own amount — Pro's yearly is ৳1,000, and
    // the withdrawn discount model's struck-through ৳960 is gone.
    expect(find.text('৳$paymentMonthlyPrice'), findsOneWidget);
    expect(find.text('৳$paymentQuarterlyPrice'), findsOneWidget);
    expect(find.text('৳$paymentHalfYearlyPrice'), findsOneWidget);
    // The amount is written with a thousands separator, so a four-digit price
    // reads ৳1,000 rather than ৳1000.
    expect(find.text('৳1,000'), findsOneWidget);
    for (final gone in <String>['৳960', '৳600', '৳1,200']) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
    for (final badge in <String>['10% Off', '20% Off']) {
      expect(find.text(badge), findsNothing, reason: badge);
    }
    expect(find.textContaining('per month'), findsNothing);
    expect(find.textContaining('per year'), findsNothing);
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

  testWidgets('no price is struck through, and each tier states one', (
    tester,
  ) async {
    await pumpPaywall(tester);

    // Every plan carries its own flat price now: the discount model that drew a
    // struck-through original and a saving badge is withdrawn, so any price
    // still carrying a line through it would be a leftover of it.
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final style = text.style;
      if (style?.decoration == TextDecoration.lineThrough) {
        fail('a struck-through price is still rendered: "${text.data}"');
      }
    }
    // A free account is sold Pro, so Pro's own one-line note is stated once and
    // the chamber tiers' notes are not shown.
    expect(find.text('One account'), findsOneWidget);
    for (final otherNote in <String>[
      'Up to 5 associates',
      'Up to 20 associates',
    ]) {
      expect(find.text(otherNote), findsNothing, reason: otherNote);
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
    // A free account is shown Pro's four plans, and every one of them can be
    // acted on — the ladder added plans, not disabled states.
    expect(actions, hasLength(4));
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
    // Bengali digits, flat prices: the yearly plan is ৳১,০০০.
    expect(find.text('৳১০০'), findsOneWidget);
    expect(find.text('৳২৮৫'), findsOneWidget);
    expect(find.text('৳৫৪০'), findsOneWidget);
    expect(find.text('৳১,০০০'), findsOneWidget);
    expect(find.textContaining('/ মাস'), findsNothing);
    expect(find.textContaining('/ বছর'), findsNothing);
    // The withdrawn discount model is gone here too.
    expect(find.text('৳৯৬০'), findsNothing);
    expect(find.text('১০% ছাড়'), findsNothing);
    expect(find.text('২০% ছাড়'), findsNothing);
    // Free falls back to the entry tier even in Bengali, so Pro's four plans
    // are the four actions on screen.
    expect(find.text('সাবস্ক্রাইব'), findsNWidgets(4));
  });

  testWidgets('offers a Firm Plus account the whole ladder', (tester) async {
    await pumpPaywall(tester, tier: SubscriptionTier.firmPlus);

    // All three tier cards, in ladder order, and all ten plan rows.
    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('Firm'), findsOneWidget);
    expect(find.text('Firm Plus'), findsOneWidget);
    for (final plan in subscriptionPlans) {
      expect(
        find.byKey(ValueKey('paywall-plan-${plan.key}')),
        findsOneWidget,
        reason: 'the ${plan.key} row should be offered to Firm Plus',
      );
    }
    expect(find.text('Subscribe'), findsNWidgets(subscriptionPlans.length));
  });

  testWidgets('never offers an account a tier above its own', (tester) async {
    // A Pro account is sold Pro alone: the six chamber rows are not built at
    // all, so a price it cannot buy is never on screen to be tapped.
    await pumpPaywall(tester, tier: SubscriptionTier.pro);

    expect(find.text('Subscribe'), findsNWidgets(4));
    expect(find.text('Firm'), findsNothing);
    expect(find.text('Firm Plus'), findsNothing);
    expect(
      find.byKey(ValueKey('paywall-plan-$paymentPlanFirmAnnual')),
      findsNothing,
    );
  });

  test('the ladder order is the tier rank every comparison reads', () {
    // `SubscriptionTier.rank` is the declaration order, and the paywall's
    // "this tier or lower" rule reads it. Reordering the enum would silently
    // reorder every gate, so the order is pinned here.
    expect(SubscriptionTier.values.map((tier) => tier.rank), <int>[0, 1, 2, 3]);
    expect(
      SubscriptionTier.values.map((tier) => tier.key),
      <String>['free', 'pro', 'firm', 'firm_plus'],
    );
  });

  test('the plan prices and features are the plan’s own', () {
    // The ladder's ten flat prices. Pro's yearly is ৳1,000 — a deliberate rise
    // from the shipped ৳960 — and a chamber sells 3, 6 or 12 months, because a
    // chamber does not buy a single month.
    expect(paymentMonthlyPrice, 100);
    expect(paymentQuarterlyPrice, 285);
    expect(paymentHalfYearlyPrice, 540);
    expect(paymentAnnualPrice, 1000);
    expect(paymentFirmQuarterlyPrice, 855);
    expect(paymentFirmHalfYearlyPrice, 1620);
    expect(paymentFirmAnnualPrice, 3000);
    expect(paymentFirmPlusQuarterlyPrice, 1710);
    expect(paymentFirmPlusHalfYearlyPrice, 3240);
    expect(paymentFirmPlusAnnualPrice, 6000);
    // Each key resolves to its own amount, and an unknown key resolves to none.
    expect(paymentPlanAmount(paymentPlanMonthly), 100);
    expect(paymentPlanAmount(paymentPlanAnnual), 1000);
    expect(paymentPlanAmount(paymentPlanFirmAnnual), 3000);
    expect(paymentPlanAmount(paymentPlanFirmPlusAnnual), 6000);
    expect(paymentPlanAmount('lifetime'), isNull);
    // The ten plans, in the ladder's order: Pro, then Firm, then Firm Plus.
    expect(
      subscriptionPlans.map((p) => p.key),
      <String>[
        paymentPlanMonthly,
        paymentPlanQuarterly,
        paymentPlanHalfYearly,
        paymentPlanAnnual,
        paymentPlanFirmQuarterly,
        paymentPlanFirmHalfYearly,
        paymentPlanFirmAnnual,
        paymentPlanFirmPlusQuarterly,
        paymentPlanFirmPlusHalfYearly,
        paymentPlanFirmPlusAnnual,
      ],
    );
    // Each plan carries the tier it belongs to, and only Pro sells one month.
    expect(
      subscriptionPlans.map((p) => planTier(p.key)),
      <SubscriptionTier?>[
        SubscriptionTier.pro,
        SubscriptionTier.pro,
        SubscriptionTier.pro,
        SubscriptionTier.pro,
        SubscriptionTier.firm,
        SubscriptionTier.firm,
        SubscriptionTier.firm,
        SubscriptionTier.firmPlus,
        SubscriptionTier.firmPlus,
        SubscriptionTier.firmPlus,
      ],
    );
    expect(planTier('lifetime'), isNull);
    // No plan carries a discount: every price is simply its price.
    expect(subscriptionPlans.where((p) => p.amount <= 0), isEmpty);
    // The one-directional visibility rule: an account buys its own tier or
    // lower, never higher. Free is sold the entry tier, Pro is Pro alone, and a
    // Firm Plus account sees all ten.
    expect(plansVisibleToTier(SubscriptionTier.free), hasLength(4));
    expect(plansVisibleToTier(SubscriptionTier.pro), hasLength(4));
    expect(plansVisibleToTier(SubscriptionTier.firm), hasLength(7));
    expect(plansVisibleToTier(SubscriptionTier.firmPlus), hasLength(10));
    expect(
      plansVisibleToTier(SubscriptionTier.pro).map((p) => planTier(p.key)),
      everyElement(SubscriptionTier.pro),
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
