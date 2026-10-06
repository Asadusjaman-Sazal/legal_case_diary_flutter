/// Paywall screen: premium benefits display & plan selection.
///
/// Task 15 Phase 5 left a **stub** here; Task 21 Phase 1 replaced it with the
/// real screen. Every plan action is now **enabled** and opens the checkout for
/// that plan — the TrxID entry and submission live in `checkout_screen.dart`.
///
/// * it says **why** it opened — the 50-case free limit — and what the user can
///   still do about it, instead of blocking a save with no explanation. That
///   card shows **only** on the gate's entry: the 50-case limit opens
///   [AppRoutes.paywallFromCaseLimit], while every other entry (Settings >
///   Subscription > Purchase New Subscription, Manage Associates' Go Premium)
///   opens the bare [AppRoutes.paywall] and omits it;
/// * it lists what the subscription plans offer and what each plan costs, from
///   the plan's pricing (৳100 for one month, ৳285 for three, ৳540 for six and
///   ৳960 for a year — there is no lifetime plan), showing the full per-month
///   price struck through and the saving beside any plan that is discounted;
/// * selecting a plan pushes the checkout with the plan key as a query
///   parameter, so it never names a second source of plans or prices.
///
/// No entitlement logic lives here: the gate that opens this screen reads
/// `resolvePremiumAccess`, which derives premium from the subscription expiry
/// plus the 48-hour grace window (see `add_edit_case_sheet.dart`).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/free_tier.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/date_utils.dart';
import '../data/payment_plans.dart';
import 'payment_plan_labels.dart';

/// One amount as the paywall writes it — "৳285" — grouped only once it is long
/// enough for the grouping to help (৳1,200 reads better than ৳1200).
String _amountText(AppLocalizations l, int amount) => l.payments_amountValue(
  AppDateUtils.formatDigits(amount, l.localeName, grouping: amount >= 1000),
);

/// Prices shown by the paywall, in taka.
///
/// Aliases of the shared plan constants ([paymentMonthlyPrice],
/// [paymentQuarterlyPrice], [paymentHalfYearlyPrice] and [paymentAnnualPrice])
/// rather than second literals, so the price on the paywall, the amount in the
/// checkout instructions and the amount submitted can never drift apart.
const int paywallMonthlyPrice = paymentMonthlyPrice;
const int paywallQuarterlyPrice = paymentQuarterlyPrice;
const int paywallHalfYearlyPrice = paymentHalfYearlyPrice;
const int paywallAnnualPrice = paymentAnnualPrice;

/// What the subscription plans offer, in display order.
const List<PaywallFeature> paywallFeatures = <PaywallFeature>[
  PaywallFeature.disasterRecovery,
  PaywallFeature.realTimeBackup,
  PaywallFeature.multiDevice,
  PaywallFeature.collaboration,
];

/// One premium feature, as a key the screen localizes to a title and a body.
enum PaywallFeature {
  /// Your data survives a lost or broken phone.
  disasterRecovery,

  /// Every change is saved to the cloud as it happens.
  realTimeBackup,

  /// The same diary on several devices at once.
  multiDevice,

  /// Associates working on one shared diary.
  collaboration,
}

/// Premium benefits display & plan selection, per the plan's Payment section.
class PaywallScreen extends StatelessWidget {
  /// Whether to show the "Free Plan Limit Reached" card.
  ///
  /// True only when the 50-case gate opened this screen; every other entry
  /// opens the bare route and hides it (see [showLimitFor]).
  final bool showLimit;

  /// Creates the paywall, hiding the free-limit card unless [showLimit] is set.
  const PaywallScreen({super.key, this.showLimit = false});

  /// Whether a paywall opened at this route [state] shows the free-limit card.
  ///
  /// Only the 50-case gate names its reason (`?reason=limit`); every other entry
  /// leaves the query out, so the card belongs to that gate alone.
  static bool showLimitFor(GoRouterState state) =>
      state.uri.queryParameters[AppRoutes.paywallReasonParam] ==
      AppRoutes.paywallReasonLimitReached;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // The status bar is the user's own, and every shell screen leaves it
    // visible by insetting the whole Scaffold (`SafeArea` top, bottom false) —
    // the shell's own SafeArea does not reach this route, which sits outside it.
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
            _PlansCard(
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
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium,
                size: 20,
                color: AppColors.secondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l.paywall_limitTitle,
                  style: AppTypography.titleMd,
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
            style: AppTypography.bodyMd,
          ),
        ],
      ),
    );
  }
}

/// Group heading for the two titled sections ("Subscription Plans Offer" and
/// "Plans"). Bold and a step larger than the label style it used to borrow, so
/// each heading reads as a title. The ARB supplies Title Case, so nothing is
/// uppercased at render time.
class _SectionHeader extends StatelessWidget {
  final String text;

  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      left: AppSpacing.xs,
      right: AppSpacing.xs,
      bottom: AppSpacing.md,
    ),
    child: Text(
      text,
      style: AppTypography.titleMd.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      ),
    ),
  );
}

/// One ticked feature per row: a Title Case heading over its sentence-case body.
class _FeaturesCard extends StatelessWidget {
  const _FeaturesCard();

  /// The localized title for one feature.
  static String _title(AppLocalizations l, PaywallFeature feature) =>
      switch (feature) {
        PaywallFeature.disasterRecovery =>
          l.paywall_featureDisasterRecoveryTitle,
        PaywallFeature.realTimeBackup => l.paywall_featureRealTimeBackupTitle,
        PaywallFeature.multiDevice => l.paywall_featureMultiDeviceTitle,
        PaywallFeature.collaboration => l.paywall_featureCollaborationTitle,
      };

  /// The localized body sentence for one feature.
  static String _body(AppLocalizations l, PaywallFeature feature) =>
      switch (feature) {
        PaywallFeature.disasterRecovery =>
          l.paywall_featureDisasterRecoveryBody,
        PaywallFeature.realTimeBackup => l.paywall_featureRealTimeBackupBody,
        PaywallFeature.multiDevice => l.paywall_featureMultiDeviceBody,
        PaywallFeature.collaboration => l.paywall_featureCollaborationBody,
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
          for (var i = 0; i < paywallFeatures.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 18,
                  color: AppColors.success,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title(l, paywallFeatures[i]),
                        style: AppTypography.titleMd,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _body(l, paywallFeatures[i]),
                        style: AppTypography.bodyMd,
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

/// Every plan, with its price and an action each.
class _PlansCard extends StatelessWidget {
  /// Called with the selected plan key (`monthly`/`annual`).
  final void Function(String plan) onPlanSelected;

  const _PlansCard({required this.onPlanSelected});

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
        children: [
          for (var i = 0; i < subscriptionPlans.length; i++) ...[
            if (i > 0)
              const Divider(
                height: AppSpacing.lg,
                color: AppColors.outlineVariant,
              ),
            _PlanRow(
              key: ValueKey('paywall-plan-${subscriptionPlans[i].key}'),
              name: paymentPlanLabel(l, subscriptionPlans[i].key),
              price: _amountText(l, subscriptionPlans[i].amount),
              // The full price is the plan bought month by month, shown struck
              // through so the saving is visible rather than asserted.
              wasPrice: subscriptionPlans[i].discountPercent == 0
                  ? null
                  : _amountText(l, subscriptionPlans[i].undiscountedAmount),
              discountLabel: paymentPlanDiscountLabel(l, subscriptionPlans[i]),
              actionLabel: l.paywall_subscribe,
              onPressed: () => onPlanSelected(subscriptionPlans[i].key),
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

  /// The full price, struck through, or null when the plan has no discount.
  final String? wasPrice;

  /// The "20% Off" badge, or null when the plan has no discount.
  final String? discountLabel;

  final String actionLabel;
  final VoidCallback onPressed;

  const _PlanRow({
    required this.name,
    required this.price,
    required this.actionLabel,
    required this.onPressed,
    this.wasPrice,
    this.discountLabel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bodyStyle = AppTypography.bodySm.copyWith(
      color: AppColors.onSurfaceVariant,
    );
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AppTypography.titleMd),
              const SizedBox(height: AppSpacing.xs),
              // The discount and the new price share one line so the eye reads
              // "was, now, saving" left to right instead of across two rows.
              if (wasPrice == null)
                Text(price, style: bodyStyle)
              else
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  children: [
                    Text(
                      wasPrice!,
                      style: bodyStyle.copyWith(
                        color: AppColors.error,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: AppColors.error,
                      ),
                    ),
                    Text(
                      price,
                      style: bodyStyle.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _DiscountBadge(label: discountLabel!),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            textStyle: AppTypography.labelLg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
            ),
          ),
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

/// The savings badge, sized to sit inline with the price.
class _DiscountBadge extends StatelessWidget {
  final String label;

  const _DiscountBadge({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.radiusSm,
    ),
    decoration: BoxDecoration(
      color: AppColors.success.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
    ),
    child: Text(
      label,
      style: AppTypography.labelMd.copyWith(color: AppColors.success),
    ),
  );
}
