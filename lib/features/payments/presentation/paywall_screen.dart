/// Paywall screen: subscription benefits and the ten-plan ladder.
///
/// Task 15 Phase 5 left a **stub** here; Task 21 Phase 1 replaced it with the
/// real screen. Every plan action is **enabled** and opens the checkout for that
/// plan — the TrxID entry and submission live in `checkout_screen.dart`.
///
/// * it says **why** it opened — the 50-case free limit — and what the user can
///   still do about it, instead of blocking a save with no explanation. That
///   card shows **only** on the gate's entry: the 50-case limit opens
///   [AppRoutes.paywall] with `?reason=limit`, while every other entry (the side
///   menu, Settings → Subscription) opens the bare route and omits it;
/// * it lists the **ten plans of the ladder**, grouped by tier — Pro, Firm and
///   Firm Plus — each with its flat price. Pro sells 1, 3, 6 and 12 months; a
///   chamber (Firm and Firm Plus) sells 3, 6 and 12, because a chamber does not
///   buy a single month. There is **no struck-through full price and no saving
///   badge**: every price is simply its price;
/// * it offers only what the account may buy. The rule is one-directional —
///   **an account may buy its own tier or lower, never higher** — and it lives
///   in [plansVisibleToTier], which the screen and the tests both read, so a
///   Pro account is never shown a chamber plan it cannot seat anyone in;
/// * selecting a plan pushes the checkout with the plan key as a query
///   parameter, so the plan is named in exactly one place.
///
/// No entitlement logic lives here: whether premium is *live* is
/// `resolvePremiumAccess`'s answer, and which tier is *held* is
/// `currentTierProvider`'s.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/free_tier.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/date_utils.dart';
import '../../accounts_and_profile/data/account_mode.dart';
import '../data/payment_plans.dart';
import 'payment_plan_labels.dart';

/// One subscription benefit, shown in the offer card.
enum PaywallFeature {
  /// No case ceiling.
  unlimitedCases,

  /// Data survives a lost phone.
  disasterRecovery,

  /// Every change saved to the cloud.
  realTimeBackup,

  /// The same diary from several devices.
  multiDevice,

  /// Working with associates in one chamber.
  collaboration,
}

/// What the plans offer, in display order.
///
/// **Unlimited Cases leads the list**: it is the benefit a free user hits first
/// — the 50-case gate — so it answers the question that opened this screen
/// before the cloud features do.
const List<PaywallFeature> paywallFeatures = <PaywallFeature>[
  PaywallFeature.unlimitedCases,
  PaywallFeature.disasterRecovery,
  PaywallFeature.realTimeBackup,
  PaywallFeature.multiDevice,
  PaywallFeature.collaboration,
];

/// The amount rendered with the app's own currency formatting.
String _amountText(AppLocalizations l, int amount) => l.payments_amountValue(
  AppDateUtils.formatDigits(amount, l.localeName, grouping: amount >= 1000),
);

/// The plans an account on [tier] may buy, in paywall order.
///
/// **The rule is one-directional** (Task 21, user ruling): an account may buy
/// **its own tier or lower**, never higher. A Pro account sees the Pro plans
/// alone, a Firm account sees Pro and Firm, and a Firm Plus account sees all
/// ten. This is also what keeps the offer honest against the server's own seat
/// cap: Pro's cap is 0, so an account that cannot yet create a chamber is never
/// sold one through a list that ignored its tier.
///
/// [SubscriptionTier.free] is treated as Pro because Pro is the entry tier a
/// free user is being sold; a free account has no tier of its own to buy.
List<SubscriptionPlan> plansVisibleToTier(SubscriptionTier tier) {
  final ceiling = switch (tier) {
    SubscriptionTier.free => SubscriptionTier.pro,
    SubscriptionTier.pro => SubscriptionTier.pro,
    SubscriptionTier.firm => SubscriptionTier.firm,
    SubscriptionTier.firmPlus => SubscriptionTier.firmPlus,
  };
  return subscriptionPlans
      .where((plan) => plan.tier.rank <= ceiling.rank)
      .toList(growable: false);
}

/// The subscription-plan screen, optionally carrying the free-limit card.
class PaywallScreen extends StatelessWidget {
  /// Whether the free-limit card is shown, i.e. the gate's own entry.
  ///
  /// A query parameter decides it (`?reason=limit`) so the 50-case entry opens
  /// the card and every other entry opens the bare route and hides it — the
  /// paywall is one screen with one optional card, not two screens.
  final bool showLimit;

  /// Creates the paywall, hiding the free-limit card unless [showLimit] is set.
  const PaywallScreen({super.key, this.showLimit = false});

  /// Whether this entry shows the free-limit card.
  ///
  /// Only the case-limit gate passes `?reason=limit`; every other entry (the
  /// side menu, Settings → Subscription) opens the bare route and hides it.
  static bool showLimitFor(GoRouterState state) =>
      state.uri.queryParameters['reason'] == 'limit';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // The status bar is the user's own, and every shell screen leaves it
    // visible by insetting the whole Scaffold (`SafeArea` top, bottom false).
    // Without this the Scaffold paints its app bar up behind the status bar and
    // the phone's clock and icons sit on that white instead of on the app's own
    // black, so the paywall is the one screen that loses them.
    return SafeArea(
      top: true,
      bottom: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        // The default leading is a back arrow on a pushed route, which is the
        // way out of the gate: Cancel means "keep my cases as they are".
        appBar: AppBar(
          title: Text(l.paywall_title, style: AppTypography.titleLg),
          backgroundColor: AppColors.surfaceContainerLowest,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.edgeMargin,
            AppSpacing.md,
            AppSpacing.edgeMargin,
            AppSpacing.xl,
          ),
          children: [
            // The free-limit card belongs to the gate alone: only the 50-case
            // entry opens `?reason=limit`, every other entry hides it.
            if (showLimit) ...[
              const _LimitCard(),
              const SizedBox(height: AppSpacing.xl),
            ],
            _SectionHeader(l.paywall_benefitsTitle),
            const _FeaturesCard(),
            const SizedBox(height: AppSpacing.xl),
            _SectionHeader(l.paywall_plansTitle),
            _PlansSection(
              // Selecting a plan opens the checkout for that plan. The plan is
              // carried as a query parameter so the checkout route needs no
              // second path and a restored deep link still names its plan.
              onPlanSelected: (plan) =>
                  context.push('${AppRoutes.checkout}?plan=$plan'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Why the screen opened, and what is still free.
class _LimitCard extends StatelessWidget {
  const _LimitCard();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
      ),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 20,
                color: AppColors.onErrorContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l.paywall_limitTitle,
                  style: AppTypography.titleMd.copyWith(
                    color: AppColors.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l.paywall_limitBody(
              AppDateUtils.formatDigits(
                freeTierCaseLimit,
                l.localeName,
                grouping: false,
              ),
            ),
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// A section's own heading, above its card.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  // The committed heading style: titleMd enlarged to w700, so a card title
  // outranks the labels beneath it rather than matching them.
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      title,
      style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

/// What the subscription offers, as a card of short benefit rows.
class _FeaturesCard extends StatelessWidget {
  const _FeaturesCard();

  /// The title and body for [feature], so the card never restates the copy.
  static (String, String) _text(AppLocalizations l, PaywallFeature feature) =>
      switch (feature) {
        PaywallFeature.unlimitedCases => (
          l.paywall_featureUnlimitedCasesTitle,
          l.paywall_featureUnlimitedCasesBody,
        ),
        PaywallFeature.disasterRecovery => (
          l.paywall_featureDisasterRecoveryTitle,
          l.paywall_featureDisasterRecoveryBody,
        ),
        PaywallFeature.realTimeBackup => (
          l.paywall_featureRealTimeBackupTitle,
          l.paywall_featureRealTimeBackupBody,
        ),
        PaywallFeature.multiDevice => (
          l.paywall_featureMultiDeviceTitle,
          l.paywall_featureMultiDeviceBody,
        ),
        PaywallFeature.collaboration => (
          l.paywall_featureCollaborationTitle,
          l.paywall_featureCollaborationBody,
        ),
      };

  /// The icon that stands for one feature (0.0.441, user request) — drawn in
  /// the app's primary, so each row says what it is about at a glance rather
  /// than repeating one green tick.
  static IconData _icon(PaywallFeature feature) => switch (feature) {
    PaywallFeature.unlimitedCases => Icons.all_inclusive,
    PaywallFeature.disasterRecovery => Icons.cloud_done_outlined,
    PaywallFeature.realTimeBackup => Icons.cloud_upload_outlined,
    PaywallFeature.multiDevice => Icons.devices_outlined,
    PaywallFeature.collaboration => Icons.groups_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final feature in paywallFeatures) ...[
            if (feature != paywallFeatures.first)
              const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_icon(feature), size: 20, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_text(l, feature).$1, style: AppTypography.labelLg),
                      const SizedBox(height: 2),
                      Text(
                        _text(l, feature).$2,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The plans this account may buy, one tier card each.
class _PlansSection extends ConsumerWidget {
  final void Function(String plan) onPlanSelected;

  const _PlansSection({required this.onPlanSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = plansVisibleToTier(ref.watch(currentTierProvider));
    // Grouped by tier. The ladder is already ordered Pro → Firm → Firm Plus, so
    // a plain pass preserves that order and no sort is needed.
    final groups = <SubscriptionTier, List<SubscriptionPlan>>{};
    for (final plan in plans) {
      groups.putIfAbsent(planTier(plan.key)!, () => <SubscriptionPlan>[]).add(plan);
    }
    return Column(
      children: [
        for (final entry in groups.entries) ...[
          if (entry.key != groups.keys.first)
            const SizedBox(height: AppSpacing.md),
          _TierCard(
            tier: entry.key,
            plans: entry.value,
            onPlanSelected: onPlanSelected,
          ),
        ],
      ],
    );
  }
}

/// One tier's plans: the tier's name and what it sells, then its plan rows.
class _TierCard extends StatelessWidget {
  final SubscriptionTier tier;
  final List<SubscriptionPlan> plans;
  final void Function(String plan) onPlanSelected;

  const _TierCard({
    required this.tier,
    required this.plans,
    required this.onPlanSelected,
  });

  /// What [tier] sells, under its name — the one line that distinguishes the
  /// chamber tiers, whose prices alone do not say what they buy.
  static String _note(AppLocalizations l, SubscriptionTier tier) =>
      switch (tier) {
        SubscriptionTier.free => l.paywall_tierProNote,
        SubscriptionTier.pro => l.paywall_tierProNote,
        SubscriptionTier.firm => l.paywall_tierFirmNote,
        SubscriptionTier.firmPlus => l.paywall_tierFirmPlusNote,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subscriptionTierLabel(l, tier), style: AppTypography.titleMd),
          const SizedBox(height: 2),
          Text(
            _note(l, tier),
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < plans.length; i++) ...[
            if (i > 0)
              const Divider(
                height: AppSpacing.lg,
                color: AppColors.outlineVariant,
              ),
            _PlanRow(
              key: ValueKey('paywall-plan-${plans[i].key}'),
              name: paymentPlanLabel(l, plans[i].key),
              price: _amountText(l, plans[i].amount),
              actionLabel: l.paywall_subscribe,
              onPressed: () => onPlanSelected(plans[i].key),
            ),
          ],
        ],
      ),
    );
  }
}

/// One plan: name, price, and the action that opens its checkout.
class _PlanRow extends StatelessWidget {
  final String name;
  final String price;
  final String actionLabel;
  final VoidCallback onPressed;

  const _PlanRow({
    required this.name,
    required this.price,
    required this.actionLabel,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(name, style: AppTypography.titleMd)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            price,
            textAlign: TextAlign.end,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            textStyle: AppTypography.titleMd,
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          ),
          child: Text(actionLabel),
        ),
      ],
    );
  }
}
