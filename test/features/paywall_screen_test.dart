/// Tests for the revamped paywall (2026-10-19).
///
/// These pin the card the user approved: the Individual/Firm toggle, one
/// stacked card per tier, the feature rows, the monthly price, the three grey
/// term buttons, the free-month notes and one action. They also pin the
/// current/scheduled states, the different-tier warning and the Bengali
/// rendering.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/features/payments/data/payment_plans.dart';
import 'package:legal_case_diary/features/payments/presentation/current_plan.dart';
import 'package:legal_case_diary/features/payments/presentation/paywall_screen.dart';

void main() {
  /// Opens the paywall on a tall viewport with a seeded profile.
  ///
  /// The profile is the source of the tier, the expiry and any queued plan, so
  /// the screen can be tested in the same states a real account reaches. The
  /// current-plan record is overridden directly: entitlement derivation is not
  /// what these tests are checking.
  Future<void> pumpPaywall(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    double statusBarHeight = 0,
    bool showLimit = false,
    bool showLapsed = false,
    SubscriptionTier tier = SubscriptionTier.free,
    bool premium = false,
    int? expiryMs,
    String? pendingKey,
    int? pendingFrom,
    String? planKey,
    bool firmMember = false,
  }) async {
    tester.view.physicalSize = const Size(1200, 4200);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = FakeViewPadding(top: statusBarHeight);
    tester.view.viewPadding = FakeViewPadding(top: statusBarHeight);
    addTearDown(tester.view.reset);

    final profile = Profile(
      id: 'user-1',
      fullName: '',
      role: 'individual',
      subscriptionStatus: premium ? 'premium' : 'free',
      subscriptionExpiry: expiryMs,
      tier: tier.key,
      tierPending: pendingKey,
      tierPendingFrom: pendingFrom,
      createdAt: 0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountProfileProvider.overrideWith(
            (ref) => Stream<Profile?>.value(profile),
          ),
          currentPlanProvider.overrideWithValue((
            known: true,
            premium: premium,
            planKey: planKey,
          )),
          firmMemberProvider.overrideWithValue(firmMember),
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
                    builder: (_) => PaywallScreen(
                      showLimit: showLimit,
                      showLapsed: showLapsed,
                    ),
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

  testWidgets('a chamber member sees the chamber notice instead of cards', (
    tester,
  ) async {
    await pumpPaywall(tester, firmMember: true, showLimit: true);

    expect(find.text('Chamber Plan'), findsOneWidget);
    expect(
      find.textContaining("covered by the chamber's subscription"),
      findsOneWidget,
    );
    expect(find.text('Individual'), findsNothing);
    expect(find.text('Starter'), findsNothing);
    expect(find.text('Subscribe'), findsNothing);
    expect(find.text('Free Plan Limit Reached'), findsNothing);
  });

  testWidgets('the Individual tab shows Free, Starter and Pro as cards', (
    tester,
  ) async {
    await pumpPaywall(tester, showLimit: true);

    expect(find.text('Choose the plan that fits your practice.'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Starter'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
    // The chamber tiers are on the other tab.
    expect(find.text('Firm Plus'), findsNothing);

    // Free is the current plan and has no purchase action.
    expect(find.text('Current Plan'), findsWidgets);
    expect(find.text('Up to 50 Cases'), findsOneWidget);
    expect(find.text('Offline Use Only'), findsOneWidget);
    expect(find.text('Offline Backup and Restoration'), findsOneWidget);
    expect(find.text('Data Customization: Court Names, Steps, and Case Types'), findsOneWidget);

    // Starter's own features and its inherited header.
    expect(find.text('Most Popular'), findsOneWidget);
    expect(find.text('Everything in Free, plus'), findsOneWidget);
    expect(find.text('Up to 500 Cases'), findsOneWidget);
    expect(find.text('Real-Time Cloud Backup'), findsOneWidget);
    expect(
      find.text(
        'Disaster Recovery: Restore your diary from the cloud on a new phone',
      ),
      findsOneWidget,
    );
    expect(find.text('Single-Device Use'), findsOneWidget);
    expect(find.text('Pro · 1 Month'), findsNothing);

    // Pro inherits Starter and adds its own two features.
    expect(find.text('Everything in Starter, plus'), findsOneWidget);
    expect(find.text('Up to 1,000 Cases'), findsOneWidget);
    expect(find.text('Multi-Device Support: Up to 2 Devices'), findsOneWidget);

    // Price line and three term buttons.
    expect(find.text('৳60'), findsOneWidget);
    expect(find.text('/month'), findsNWidgets(3));
    // Starter and Pro each carry the same three term names.
    expect(find.text('3 Months'), findsNWidgets(2));
    expect(find.text('6 Months'), findsNWidgets(2));
    expect(find.text('1 Year'), findsNWidgets(2));
    expect(find.text('৳180'), findsOneWidget);
    expect(find.text('৳300'), findsOneWidget);
    // ৳600 is Starter's year and Pro's six months.
    expect(find.text('৳600'), findsNWidgets(2));
    // Both paid cards carry the same two notes.
    expect(find.text('1 month free on 6 months'), findsNWidgets(2));
    expect(find.text('2 months free on 1 year'), findsNWidgets(2));
    // The annual term is selected by default.
    expect(find.text('Subscribe — 1 Year/৳600'), findsOneWidget);
  });

  testWidgets('tapping a term applies its price and tapping it again clears it', (
    tester,
  ) async {
    await pumpPaywall(tester);

    // The default is the annual plan.
    expect(find.text('Subscribe — 1 Year/৳600'), findsOneWidget);

    // Tap the selected annual term: the action falls back to one month.
    await tester.tap(
      find.byKey(const ValueKey('paywall-term-starter-starter_annual')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Subscribe — ৳60/month'), findsOneWidget);

    // Choose six months: the action carries the total.
    await tester.tap(
      find.byKey(const ValueKey('paywall-term-starter-starter_half_yearly')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Subscribe — 6 Months/৳300'), findsOneWidget);
  });

  testWidgets('the Firm tab shows Firm, Firm Plus and Enterprise', (
    tester,
  ) async {
    await pumpPaywall(tester);

    await tester.tap(find.byKey(const ValueKey('paywall-audience-firm')));
    await tester.pumpAndSettle();

    // "Firm" is both the toggle's label and the card's title.
    expect(find.text('Firm'), findsNWidgets(2));
    expect(find.text('Firm Plus'), findsOneWidget);
    expect(find.text('Enterprise'), findsOneWidget);
    expect(find.text('Free'), findsNothing);
    expect(find.text('Starter'), findsNothing);
    expect(find.text('Pro'), findsNothing);

    expect(find.text('Most Popular'), findsOneWidget);
    expect(find.text('Everything in Pro, plus'), findsOneWidget);
    expect(find.text('Up to 2,500 Cases'), findsOneWidget);
    expect(
      find.text('Collaboration: Up to 5 Members (One Device Each)'),
      findsOneWidget,
    );
    expect(find.text('Everything in Firm, plus'), findsOneWidget);
    expect(find.text('Up to 6,000 Cases'), findsOneWidget);
    expect(
      find.text('Collaboration: Up to 12 Members (One Device Each)'),
      findsOneWidget,
    );
    expect(find.text('Everything in Firm Plus, plus'), findsOneWidget);
    expect(find.text('Unlimited Cases (Fair Use Applies)'), findsOneWidget);
    expect(find.text('Unlimited Members and Devices'), findsOneWidget);

    // Firm sells no one-month term; its shortest is three months.
    expect(find.text('Shortest term: 3 months'), findsNWidgets(3));
    expect(find.text('Subscribe — 1 Year/৳2,500'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('paywall-term-firm-firm_annual')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Subscribe — 3 Months/৳750'), findsOneWidget);
  });

  testWidgets('the held tier says Current Plan and its action says Renew', (
    tester,
  ) async {
    await pumpPaywall(
      tester,
      tier: SubscriptionTier.pro,
      premium: true,
      expiryMs: DateTime.now()
          .add(const Duration(days: 100))
          .millisecondsSinceEpoch,
      planKey: paymentPlanProAnnual,
    );

    final proCard = find.byKey(const ValueKey('paywall-plan-pro'));
    expect(
      find.descendant(of: proCard, matching: find.text('Current Plan')),
      findsOneWidget,
    );
    expect(find.text('Renew — 1 Year/৳1,200'), findsOneWidget);
    // The Free card is included, not purchasable.
    final freeButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('paywall-subscribe-free')),
    );
    expect(freeButton.onPressed, isNull);
    expect(find.text('Included'), findsOneWidget);
  });

  testWidgets('a different tier warns before checkout', (tester) async {
    await pumpPaywall(
      tester,
      tier: SubscriptionTier.pro,
      premium: true,
      expiryMs: DateTime.now()
          .add(const Duration(days: 30))
          .millisecondsSinceEpoch,
      planKey: paymentPlanProAnnual,
    );

    await tester.tap(
      find.byKey(const ValueKey('paywall-subscribe-starter')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('paywall-change-dialog')), findsOneWidget);
    expect(find.text('This Plan Starts Later'), findsOneWidget);
    expect(find.textContaining('will start on'), findsOneWidget);
    expect(find.textContaining('Your case ceiling will be'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('paywall-change-go-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paywall-change-dialog')), findsNothing);
  });

  testWidgets('a queued plan is Scheduled and a third tier is blocked', (
    tester,
  ) async {
    final start = DateTime.now()
        .add(const Duration(days: 30))
        .millisecondsSinceEpoch;
    await pumpPaywall(
      tester,
      tier: SubscriptionTier.pro,
      premium: true,
      expiryMs: start,
      pendingKey: SubscriptionTier.firm.key,
      pendingFrom: start,
      planKey: paymentPlanProAnnual,
    );

    // The banner names the queued plan before the cards.
    expect(
      find.byKey(const ValueKey('paywall-scheduled-banner')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('paywall-audience-firm')));
    await tester.pumpAndSettle();

    final firmCard = find.byKey(const ValueKey('paywall-plan-firm'));
    expect(
      find.descendant(of: firmCard, matching: find.text('Scheduled')),
      findsOneWidget,
    );
    expect(
      find.text('Renew Scheduled Plan — 1 Year/৳2,500'),
      findsOneWidget,
    );

    // A third tier cannot be bought while the Firm change waits.
    final enterprise = tester.widget<FilledButton>(
      find.byKey(const ValueKey('paywall-subscribe-enterprise')),
    );
    expect(enterprise.onPressed, isNull);
    expect(
      find.textContaining('You can renew your current plan'),
      findsWidgets,
    );
  });

  testWidgets('renewing the current tier explains the later start', (
    tester,
  ) async {
    final start = DateTime.now()
        .add(const Duration(days: 30))
        .millisecondsSinceEpoch;
    await pumpPaywall(
      tester,
      tier: SubscriptionTier.pro,
      premium: true,
      expiryMs: start,
      pendingKey: SubscriptionTier.firm.key,
      pendingFrom: start,
      planKey: paymentPlanProAnnual,
    );

    await tester.tap(
      find.byKey(const ValueKey('paywall-subscribe-pro')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('paywall-renew-shift-dialog')),
      findsOneWidget,
    );
    expect(
      find.text('Your Scheduled Plan Will Start Later'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('paywall-renew-shift-go-back')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('paywall-renew-shift-dialog')),
      findsNothing,
    );
  });

  testWidgets('a lapsed plan names its allowance in the gate card', (
    tester,
  ) async {
    await pumpPaywall(
      tester,
      showLapsed: true,
      tier: SubscriptionTier.pro,
      planKey: paymentPlanProAnnual,
    );

    expect(find.text('Your Plan Has Lapsed'), findsOneWidget);
    expect(find.textContaining('up to 250 cases'), findsOneWidget);
    expect(find.text('Free Plan Limit Reached'), findsNothing);
  });

  testWidgets('leaves the phone status bar visible above its app bar', (
    tester,
  ) async {
    await pumpPaywall(tester, statusBarHeight: 90);

    final appBar = tester.getRect(find.byType(AppBar));
    expect(appBar.top, 90);
    expect(appBar.height, lessThan(90));
  });

  testWidgets('the back arrow returns the user where they were', (
    tester,
  ) async {
    await pumpPaywall(tester);
    expect(find.byType(PaywallScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(PaywallScreen), findsNothing);
    expect(find.byKey(const ValueKey('open-paywall')), findsOneWidget);
  });

  testWidgets('renders in Bengali with Bengali digits', (tester) async {
    await pumpPaywall(tester, locale: const Locale('bn'));

    expect(find.text('সাবস্ক্রিপশন প্ল্যান'), findsOneWidget);
    expect(find.text('স্টার্টার'), findsOneWidget);
    expect(find.text('প্রো'), findsOneWidget);
    expect(find.text('৳৬০'), findsOneWidget);
    expect(find.text('৩ মাস'), findsNWidgets(2));
    expect(find.text('৬ মাস'), findsNWidgets(2));
    expect(find.text('১ বছর'), findsNWidgets(2));
    expect(find.text('সাবস্ক্রাইব — ১ বছর/৳৬০০'), findsOneWidget);
  });

  test('the six tiers and seventeen plans are the settled ladder', () {
    expect(
      SubscriptionTier.values.map((tier) => tier.key),
      <String>[
        'free',
        'starter',
        'pro',
        'firm',
        'firm_plus',
        'enterprise',
      ],
    );
    expect(
      SubscriptionTier.values.map((tier) => tier.rank),
      <int>[0, 1, 2, 3, 4, 5],
    );
    expect(
      SubscriptionTier.values.map((tier) => tier.caseCeiling),
      <int?>[50, 500, 1000, 2500, 6000, null],
    );
    expect(
      SubscriptionTier.values.map((tier) => tier.lapseAllowance),
      <int>[0, 100, 250, 500, 1000, 2000],
    );
    expect(
      SubscriptionTier.values.map((tier) => tier.monthlyPrice),
      <int>[0, 60, 120, 250, 500, 1500],
    );
    expect(
      SubscriptionTier.values.map((tier) => tier.seatCap),
      <int?>[null, 0, 0, 5, 12, null],
    );

    expect(subscriptionPlans, hasLength(17));
    expect(paymentPlanAmount(paymentPlanStarterAnnual), 600);
    expect(paymentPlanAmount(paymentPlanProAnnual), 1200);
    expect(paymentPlanAmount(paymentPlanFirmAnnual), 2500);
    expect(paymentPlanAmount(paymentPlanFirmPlusAnnual), 5000);
    expect(paymentPlanAmount(paymentPlanEnterpriseAnnual), 15000);
    expect(paymentPlanAmount('lifetime'), isNull);

    // The old Pro keys are history only: Starter tier and never sellable.
    expect(isLegacyStarterPlan(paymentPlanLegacyAnnual), isTrue);
    expect(planTier(paymentPlanLegacyAnnual), SubscriptionTier.starter);
    expect(subscriptionPlan(paymentPlanLegacyAnnual), isNull);

    expect(monthlyPlanFor(SubscriptionTier.starter), isNotNull);
    expect(monthlyPlanFor(SubscriptionTier.firm), isNull);
    expect(shortestPlanFor(SubscriptionTier.firm)!.months, 3);
    expect(shortestPlanFor(SubscriptionTier.enterprise)!.months, 3);
    expect(plansForAudience(SubscriptionAudience.individual), hasLength(8));
    expect(plansForAudience(SubscriptionAudience.firm), hasLength(9));
    expect(tiersForAudience(SubscriptionAudience.individual), hasLength(3));
    expect(tiersForAudience(SubscriptionAudience.firm), hasLength(3));
  });
}
