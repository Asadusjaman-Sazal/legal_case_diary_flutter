/// Paywall screen: premium benefits display & plan selection.
///
/// Task 15 Phase 5 asks for a **stub** here — the real screen (payment
/// submission, TrxID entry, plan activation and the 48-hour grace wording)
/// arrives in Task 21. So this screen is deliberately complete about the parts
/// it can be honest about and silent about the parts it cannot:
///
/// * it says **why** it opened — the 50-case free limit — and what the user can
///   still do about it, instead of blocking a save with no explanation;
/// * it lists what premium includes and what each plan costs, from the plan's
///   pricing (৳100 per month, ৳1,000 per year — there is no lifetime plan);
/// * every plan action is **disabled**, so nothing looks broken or tappable
///   before Task 21 wires payments, and the screen says so in one line.
///
/// No entitlement logic lives here: the gate that opens this screen reads
/// `resolvePremiumAccess`, which derives premium from the subscription expiry
/// plus the 48-hour grace window (see `add_edit_case_sheet.dart`), so Task 21
/// only has to replace the copy and enable the buttons.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/free_tier.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/utils/date_utils.dart';

/// Prices shown by the stub, in taka.
///
/// Named constants rather than inline literals so the one place to change them
/// is here (the plan fixes ৳100 monthly and ৳1,000 annually, and there is no
/// lifetime plan).
const int paywallMonthlyPrice = 100;
const int paywallAnnualPrice = 1000;

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
          const _PlansCard(),
          const SizedBox(height: AppSpacing.md),
          // The honest note: this build cannot take money yet.
          Text(
            l.paywall_note,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
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

/// Uppercase section heading, matching the Settings sub-pages' style.
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

/// The two plans, with prices and a disabled action each.
class _PlansCard extends StatelessWidget {
  const _PlansCard();

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
          _PlanRow(
            key: const ValueKey('paywall-plan-monthly'),
            name: l.paywall_planMonthly,
            price: l.paywall_planMonthlyPrice(
              AppDateUtils.formatDigits(
                paywallMonthlyPrice,
                l.localeName,
                grouping: false,
              ),
            ),
            actionLabel: l.paywall_comingSoon,
          ),
          const Divider(height: AppSpacing.lg, color: AppColors.outlineVariant),
          _PlanRow(
            key: const ValueKey('paywall-plan-annual'),
            name: l.paywall_planAnnual,
            price: l.paywall_planAnnualPrice(
              AppDateUtils.formatDigits(paywallAnnualPrice, l.localeName),
            ),
            actionLabel: l.paywall_comingSoon,
          ),
        ],
      ),
    );
  }
}

/// One plan: name, price, and the (disabled) action that Task 21 enables.
class _PlanRow extends StatelessWidget {
  final String name;
  final String price;
  final String actionLabel;

  const _PlanRow({
    required this.name,
    required this.price,
    required this.actionLabel,
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
      // Disabled on purpose: a stub must not pretend a payment can start.
      FilledButton(
        onPressed: null,
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
