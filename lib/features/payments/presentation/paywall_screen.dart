/// Paywall screen: premium benefits display & plan selection.
///
/// Task 15 Phase 5 left a **stub** here; Task 21 Phase 1 replaced it with the
/// real screen. Every plan action is now **enabled** and opens the checkout for
/// that plan — the TrxID entry and submission live in `checkout_screen.dart`.
///
/// * it says **why** it opened — the 50-case free limit — and what the user can
///   still do about it, instead of blocking a save with no explanation;
/// * it lists what premium includes and what each plan costs, from the plan's
///   pricing (৳100 for one month, ৳285 for three, ৳550 for six and ৳1,000 for a
///   year — there is no lifetime plan);
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

/// Premium benefits shown by the stub, in display order.
const List<PaywallBenefit> paywallBenefits = <PaywallBenefit>[
  PaywallBenefit.unlimitedCases,
  PaywallBenefit.cloudBackup,
  PaywallBenefit.multiDevice,
  PaywallBenefit.firmMode,
];

/// One premium benefit, as a key the screen localizes.
enum PaywallBenefit {
  /// No case limit at all.
  unlimitedCases,

  /// Secure cloud backup and sync.
  cloudBackup,

  /// The same diary on every device.
  multiDevice,

  /// Firm mode for associates.
  firmMode,
}

/// Premium benefits display & plan selection, per the plan's Payment section.
class PaywallScreen extends StatelessWidget {
  /// Creates the paywall.
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      // The default leading is a back arrow on a pushed route, which is the way
      // out of the gate: Cancel means "keep my cases as they are".
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
          const _LimitCard(),
          const SizedBox(height: AppSpacing.xl),
          _SectionHeader(l.paywall_benefitsTitle),
          const _BenefitsCard(),
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

/// Section heading, matching the Settings sub-pages' style. The ARB supplies
/// Title Case, so nothing is uppercased at render time.
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
      style: AppTypography.labelLg.copyWith(
        color: AppColors.onSurfaceVariant,
        letterSpacing: 0.7,
      ),
    ),
  );
}

/// One ticked benefit per row.
class _BenefitsCard extends StatelessWidget {
  const _BenefitsCard();

  /// The localized wording for one benefit.
  static String _label(AppLocalizations l, PaywallBenefit benefit) =>
      switch (benefit) {
        PaywallBenefit.unlimitedCases => l.paywall_benefitUnlimitedCases,
        PaywallBenefit.cloudBackup => l.paywall_benefitCloudBackup,
        PaywallBenefit.multiDevice => l.paywall_benefitMultiDevice,
        PaywallBenefit.firmMode => l.paywall_benefitFirmMode,
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
          for (var i = 0; i < paywallBenefits.length; i++) ...[
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
                  child: Text(
                    _label(l, paywallBenefits[i]),
                    style: AppTypography.bodyMd,
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
              price: paymentPlanPriceLabel(
                l,
                subscriptionPlans[i],
                AppDateUtils.formatDigits(
                  subscriptionPlans[i].amount,
                  l.localeName,
                  grouping: subscriptionPlans[i].amount >= 1000,
                ),
              ),
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
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: AppTypography.titleMd),
            const SizedBox(height: AppSpacing.xs),
            Text(
              price,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
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
