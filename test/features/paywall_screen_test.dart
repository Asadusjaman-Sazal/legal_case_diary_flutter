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

import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/constants/app_spacing.dart';
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
      avatarVersion: 0,
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

  testWidgets('a chamber member reads the full ladder but cannot buy', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpPaywall(tester, firmMember: true, showLimit: true);

    // The notice says the chamber covers the account, and the ladder is there
    // to read — both tabs and their cards.
    expect(find.text('Chamber Plan'), findsOneWidget);
    expect(
      find.textContaining("covered by the chamber's subscription"),
      findsOneWidget,
    );
    expect(find.text('Individual'), findsOneWidget);
    // The intro invites a choice the member cannot make, so it is not shown.
    expect(
      find.text('Choose the plan that fits your practice.'),
      findsNothing,
    );
    expect(find.text('Starter'), findsOneWidget);
    // The free wall is not a chamber's rule, even when a gate sent the member
    // here.
    expect(find.text('Free Plan Limit Reached'), findsNothing);

    Color? background(String key) => tester
        .widget<FilledButton>(find.byKey(ValueKey('paywall-subscribe-$key')))
        .style
        ?.backgroundColor
        ?.resolve(<WidgetState>{});
    Color? foreground(String key) => tester
        .widget<FilledButton>(find.byKey(ValueKey('paywall-subscribe-$key')))
        .style
        ?.foregroundColor
        ?.resolve(<WidgetState>{});
    VoidCallback? action(String key) => tester
        .widget<FilledButton>(find.byKey(ValueKey('paywall-subscribe-$key')))
        .onPressed;

    // Every sellable action is greyed but still answers a tap.
    for (final key in ['starter', 'pro']) {
      expect(action(key), isNotNull, reason: key);
      expect(background(key), AppColors.surfaceContainerHigh, reason: key);
      expect(foreground(key), AppColors.onSurfaceVariant, reason: key);
    }
    expect(find.textContaining('Subscribe —'), findsNWidgets(2));

    await tester.tap(
      find.byKey(const ValueKey('paywall-subscribe-starter')),
    );
    await tester.pumpAndSettle();

    // The tap explains the rule instead of opening checkout.
    expect(find.text(l.paywall_memberLockedToast), findsOneWidget);
    expect(find.byType(PaywallScreen), findsOneWidget);

    // The other tab's cards are locked the same way.
    await tester.tap(find.byKey(const ValueKey('paywall-audience-firm')));
    await tester.pumpAndSettle();
    expect(find.text('Firm Plus'), findsOneWidget);
    expect(find.text('Enterprise'), findsOneWidget);
    for (final key in ['firm', 'firm_plus', 'enterprise']) {
      expect(action(key), isNotNull, reason: key);
      expect(background(key), AppColors.surfaceContainerHigh, reason: key);
    }

    // Let the toast's own timer finish, so the test leaves no timer behind.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
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
    expect(find.text('Up to 50 cases'), findsOneWidget);
    expect(find.text('Offline use only'), findsOneWidget);
    expect(find.text('Offline backup and restoration'), findsOneWidget);
    expect(find.text('Data customization: court names, steps and case types'), findsOneWidget);

    // Starter's own features and its inherited header.
    expect(find.text('Most Popular'), findsOneWidget);
    _expectBadgeAtCardRight(tester, 'paywall-plan-starter');
    expect(find.text('Includes Everything in Free, plus'), findsOneWidget);
    expect(find.text('Up to 500 cases'), findsOneWidget);
    expect(find.text('Real-time cloud backup'), findsOneWidget);
    expect(
      find.text(
        'Disaster recovery: restore your diary from the cloud on a new device',
      ),
      findsOneWidget,
    );
    expect(find.text('Single-device use'), findsOneWidget);
    expect(find.text('Pro · 1 Month'), findsNothing);

    // Pro inherits Starter and adds its own two features.
    expect(find.text('Includes Everything in Starter, plus'), findsOneWidget);
    expect(find.text('Up to 1,000 cases'), findsOneWidget);
    expect(
      find.text('Multi-device support: up to 2 concurrent devices'),
      findsOneWidget,
    );

    // No paid card prints a headline price any more: Free is the one card left
    // with a price line, because it has no term rows to carry a total.
    expect(find.text('৳0'), findsOneWidget);
    expect(find.text('/month'), findsOneWidget);

    // Four term rows on each paid card, each naming its own per-month price.
    expect(find.text('1 Month'), findsNWidgets(2));
    expect(find.text('3 Months'), findsNWidgets(2));
    expect(find.text('6 Months'), findsNWidgets(2));
    expect(find.text('1 Year'), findsNWidgets(2));
    expect(find.text('৳80/month'), findsOneWidget);
    expect(find.text('৳60/month'), findsOneWidget);
    expect(find.text('৳50/month'), findsOneWidget);
    expect(find.text('৳45/month'), findsOneWidget);
    expect(find.text('৳150/month'), findsOneWidget);
    expect(find.text('৳120/month'), findsOneWidget);
    expect(find.text('৳110/month'), findsOneWidget);
    expect(find.text('৳100/month'), findsOneWidget);

    // The totals, which are the exact amounts the server validates.
    expect(find.text('৳180'), findsOneWidget);
    expect(find.text('৳300'), findsOneWidget);
    expect(find.text('৳540'), findsOneWidget);
    expect(find.text('৳360'), findsOneWidget);
    expect(find.text('৳660'), findsOneWidget);
    expect(find.text('৳1,200'), findsOneWidget);

    // The prose that used to state the ladder is gone: the per-month figures
    // state it now, so nothing is struck through and no saving is named.
    expect(find.text('Or choose'), findsNothing);
    expect(find.text('1 month free on 6 months'), findsNothing);
    expect(find.text('2 months free on 1 year'), findsNothing);
    expect(find.textContaining(' Off'), findsNothing);
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      expect(text.style?.decoration, isNot(TextDecoration.lineThrough));
    }

    // An Individual card opens on 6 Months too, as every card now does.
    expect(find.text('Subscribe — 6 Months/৳300'), findsOneWidget);
  });

  testWidgets('tapping a term applies its price and cannot be cleared', (
    tester,
  ) async {
    await pumpPaywall(tester);

    // The default is six months.
    expect(find.text('Subscribe — 6 Months/৳300'), findsOneWidget);

    // Choose one month: the action carries its per-month price.
    final monthly = find.byKey(
      const ValueKey('paywall-term-starter-starter_monthly'),
    );
    await tester.ensureVisible(monthly);
    await tester.tap(monthly);
    await tester.pumpAndSettle();
    expect(find.text('Subscribe — ৳80/month'), findsOneWidget);

    // Tapping the chosen term again leaves it chosen: a card always carries a
    // term to buy, so there is no way back to "no term".
    await tester.ensureVisible(monthly);
    await tester.tap(monthly);
    await tester.pumpAndSettle();
    expect(find.text('Subscribe — ৳80/month'), findsOneWidget);
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

    // Most Popular marks **Firm Plus**, not Firm (user ruling 2026-10-21).
    expect(find.text('Most Popular'), findsOneWidget);
    _expectBadgeAtCardRight(tester, 'paywall-plan-firm_plus');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('paywall-plan-firm')),
        matching: find.text('Most Popular'),
      ),
      findsNothing,
      reason: 'Firm is the entry chamber rung; the badge belongs to Firm Plus.',
    );
    // Each chamber card lists its **whole** allowance under a plain *Includes*
    // heading (user ruling, 2026-10-21): a buyer comparing chambers never has
    // to leave this tab to decode "Everything in Pro".
    expect(find.text('Includes'), findsNWidgets(3));
    expect(find.textContaining('Everything in'), findsNothing);
    expect(find.text('Up to 2,500 cases'), findsOneWidget);
    expect(
      find.text('Collaboration: up to 5 members (one concurrent device each)'),
      findsOneWidget,
    );
    expect(find.text('Up to 6,000 cases'), findsOneWidget);
    expect(
      find.text('Collaboration: up to 10 members (one concurrent device each)'),
      findsOneWidget,
    );
    // Enterprise is the largest tier, not an unlimited one: both numbers are
    // the ones the app's Add Case gate and the join gate enforce.
    expect(find.text('Up to 20,000 cases'), findsOneWidget);
    expect(
      find.text('Collaboration: up to 20 members (one concurrent device each)'),
      findsOneWidget,
    );
    // The three shared rows are printed from the same strings on every card.
    expect(find.text('Real-time cloud backup'), findsNWidgets(3));
    expect(find.text('Offline usage & data backup'), findsNWidgets(3));
    expect(
      find.text('Data customization: court names, steps and case types'),
      findsNWidgets(3),
    );

    // Firm is the one chamber tier with a one-month plan; Firm Plus and
    // Enterprise still start at three, so the row counts differ.
    expect(find.text('1 Month'), findsOneWidget);
    expect(find.text('3 Months'), findsNWidgets(3));
    expect(find.text('6 Months'), findsNWidgets(3));
    expect(find.text('1 Year'), findsNWidgets(3));
    // Firm's month costs more per month than its quarter, on purpose.
    expect(find.text('৳300/month'), findsOneWidget);
    expect(find.text('৳250/month'), findsOneWidget);
    expect(find.text('৳225/month'), findsOneWidget);
    expect(find.text('৳208/month'), findsOneWidget);
    expect(find.text('৳1,350'), findsOneWidget);
    // A chamber card opens on six months and names no prose.
    expect(find.text('Subscribe — 6 Months/৳1,350'), findsOneWidget);
    expect(find.text('Or choose'), findsNothing);
    expect(find.text('Shortest term: 3 months'), findsNothing);
    expect(find.textContaining(' Off'), findsNothing);
    // The quarter still picks a term, and the action follows.
    final firmQuarterly = find.byKey(
      const ValueKey('paywall-term-firm-firm_quarterly'),
    );
    await tester.ensureVisible(firmQuarterly);
    await tester.tap(firmQuarterly);
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
    expect(find.text('Renew — 6 Months/৳660'), findsOneWidget);
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
      find.text('Renew Scheduled Plan — 6 Months/৳1,350'),
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

  testWidgets('the start warning clamps a month the way the server does', (
    tester,
  ) async {
    // 31 January plus one month is 28 February on the server, because SQL
    // clamps a day the target month does not have. Dart would roll that day
    // over to 3 March, so the warning used to name a start date the account
    // would never be given (2027 is not a leap year).
    final start = DateTime.utc(2027, 1, 31, 10).millisecondsSinceEpoch;
    await pumpPaywall(
      tester,
      tier: SubscriptionTier.pro,
      premium: true,
      expiryMs: start,
      pendingKey: SubscriptionTier.firm.key,
      pendingFrom: start,
      planKey: paymentPlanProMonthly,
    );

    // One month, so the date the warning prints is January's 31st plus one.
    final monthly = find.byKey(const ValueKey('paywall-term-pro-pro_monthly'));
    await tester.ensureVisible(monthly);
    await tester.tap(monthly);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('paywall-subscribe-pro')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('paywall-renew-shift-dialog')),
      findsOneWidget,
    );
    expect(find.textContaining('28/02/2027'), findsOneWidget);
    expect(find.textContaining('03/03/2027'), findsNothing);
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

    expect(find.text('Limited Access Mode'), findsOneWidget);
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
    expect(find.text('৳০'), findsOneWidget);
    expect(find.text('১ মাস'), findsNWidgets(2));
    expect(find.text('৩ মাস'), findsNWidgets(2));
    expect(find.text('৬ মাস'), findsNWidgets(2));
    expect(find.text('১ বছর'), findsNWidgets(2));
    expect(find.text('৳৮০/মাস'), findsOneWidget);
    expect(find.text('৳৪৫/মাস'), findsOneWidget);
    expect(find.text('সাবস্ক্রাইব — ৬ মাস/৳৩০০'), findsOneWidget);
  });

  test('the six tiers and eighteen plans are the settled ladder', () {
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
      <int?>[50, 500, 1000, 2500, 6000, 20000],
    );
    expect(
      SubscriptionTier.values.map((tier) => tier.lapseAllowance),
      <int>[0, 100, 250, 500, 1000, 2000],
    );
    expect(
      SubscriptionTier.values.map((tier) => tier.monthlyPrice),
      <int>[0, 80, 150, 250, 500, 1500],
    );
    expect(
      SubscriptionTier.values.map((tier) => tier.seatCap),
      <int?>[null, 0, 0, 5, 10, 20],
    );

    expect(subscriptionPlans, hasLength(18));
    expect(paymentPlanAmount(paymentPlanStarterMonthly), 80);
    expect(paymentPlanAmount(paymentPlanStarterAnnual), 540);
    expect(paymentPlanAmount(paymentPlanProMonthly), 150);
    expect(paymentPlanAmount(paymentPlanProAnnual), 1200);
    expect(paymentPlanAmount(paymentPlanFirmMonthly), 300);
    expect(paymentPlanAmount(paymentPlanFirmHalfYearly), 1350);
    expect(paymentPlanAmount(paymentPlanFirmAnnual), 2500);
    expect(paymentPlanAmount(paymentPlanFirmPlusAnnual), 5000);
    expect(paymentPlanAmount(paymentPlanEnterpriseAnnual), 15000);
    expect(paymentPlanAmount('lifetime'), isNull);

    // The old Pro keys are history only: Starter tier and never sellable.
    expect(isLegacyStarterPlan(paymentPlanLegacyAnnual), isTrue);
    expect(planTier(paymentPlanLegacyAnnual), SubscriptionTier.starter);
    expect(subscriptionPlan(paymentPlanLegacyAnnual), isNull);

    expect(monthlyPlanFor(SubscriptionTier.starter), isNotNull);
    expect(monthlyPlanFor(SubscriptionTier.firm), isNotNull);
    expect(monthlyPlanFor(SubscriptionTier.firmPlus), isNull);
    expect(shortestPlanFor(SubscriptionTier.firm)!.months, 1);
    expect(shortestPlanFor(SubscriptionTier.enterprise)!.months, 3);
    expect(plansForAudience(SubscriptionAudience.individual), hasLength(8));
    expect(plansForAudience(SubscriptionAudience.firm), hasLength(10));
    expect(tiersForAudience(SubscriptionAudience.individual), hasLength(3));
    expect(tiersForAudience(SubscriptionAudience.firm), hasLength(3));
  });
}

/// The standing badge ends at the card's right edge, never beside its title.
///
/// Measured on the rendered boxes: the badge's own label sits one 8 px inset
/// inside the pill, and the pill one card-padding inside the card.
void _expectBadgeAtCardRight(WidgetTester tester, String cardKey) {
  final card = tester.getRect(find.byKey(ValueKey(cardKey)));
  final badgeText = tester.getRect(
    find.descendant(
      of: find.byKey(ValueKey(cardKey)),
      matching: find.text('Most Popular'),
    ),
  );
  // 1.5 pt of slack for the card's 1 px border, which the rect includes.
  expect(
    badgeText.right,
    closeTo(card.right - AppSpacing.cardPadding - AppSpacing.sm, 1.5),
    reason: 'The badge belongs at the card\'s right edge, not after the title.',
  );
  expect(
    badgeText.left,
    greaterThan(card.center.dx),
    reason: 'A right-edge badge sits in the card\'s right half.',
  );
}
