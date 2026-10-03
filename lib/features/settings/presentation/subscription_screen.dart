/// Subscription screen: what this account's subscription is, and where to buy
/// another.
///
/// Both rows were Manage Account's **Subscription Details** and **Purchase New
/// Subscription**, moved here unchanged -- the same icons, the same wording, the
/// same destinations -- because an account's billing does not belong under its
/// profile, and the Settings list has a place for it after Online Sync. The
/// details sheet travels with the row that opens it, so the role, firm, plan,
/// expiry and payment history it shows are the content it always showed.
///
/// **Mockup departure (approved).** There is no `settings_subscription` mockup,
/// so this body is the two rows above moved verbatim; correspondingly Manage
/// Account keeps only Change Password, where its own binding mockup still draws
/// all three rows. Recorded in `docs/implementation_plan.md` and the task files.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/date_utils.dart';
import '../../accounts_and_profile/data/account_mode.dart';
import '../../accounts_and_profile/data/profile_repository.dart';
import '../../payments/data/payment_repository.dart';
import '../../payments/presentation/payment_plan_labels.dart';
import 'settings_menu_card.dart';
import 'settings_sub_page_modal.dart';

/// The Subscription screen: the two rows moved out of Manage Account.
class SubscriptionScreen extends ConsumerWidget {
  /// Creates the screen.
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final items = [
      SettingsSubMenuRow(
        icon: Icons.star_outline,
        title: l.settingsManageAccount_subscriptionDetails,
        onTap: () => _showSubscriptionDetails(context),
      ),
      SettingsSubMenuRow(
        icon: Icons.add_shopping_cart_outlined,
        title: l.settingsManageAccount_purchaseNewSubscription,
        onTap: () => context.push(AppRoutes.paywall),
      ),
    ];

    return SettingsSubPageModal(
      title: l.settingsSubscription_title,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.edgeMargin,
          AppSpacing.md,
          AppSpacing.edgeMargin,
          AppSpacing.xl,
        ),
        child: Column(
          children: [
            for (final item in items)
              Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: item,
              ),
          ],
        ),
      ),
    );
  }

  /// Shows the role, firm and subscription state behind the row above.
  void _showSubscriptionDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _SubscriptionDetailsSheet(),
    );
  }
}

/// The Subscription Details sheet: role, firm and the derived plan state.
class _SubscriptionDetailsSheet extends ConsumerWidget {
  const _SubscriptionDetailsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final profile = ref.watch(accountProfileProvider).value;
    final firm = ref.watch(accountFirmProvider).value;
    final premium = ref.watch(premiumAccessProvider);
    // Whether an answer of "free" is the account's plan or merely the gap left
    // before the profile pull lands. A premium user who signed in a moment ago
    // must not be told Free while the Plan row beside it already names the
    // month they paid for — the contradiction this screen used to show.
    final entitlementKnown = ref.watch(entitlementKnownProvider);

    // The firm's expiry is the source of truth for a member; an individual's is
    // their own. Exactly the split `resolvePremiumAccess` uses.
    final expiry = profile?.firmId == null
        ? profile?.subscriptionExpiry
        : firm?.subscriptionExpiry;

    // The active paid plan is named by the latest approved submission. With no
    // approval there is no paid plan to name — the Subscription row already says
    // Free/Premium — so a dash is the honest value, not a repeated tier word.
    final approved = (ref.watch(myPaymentSubmissionsProvider).value ??
            const <PaymentSubmission>[])
        .where((s) => s.status == 'approved')
        .toList(growable: false);
    final planValue = approved.isEmpty
        ? '—'
        : paymentPlanLabel(l, approved.first.planType);

    final String subscription;
    if (premium.isLoading || !entitlementKnown) {
      subscription = '—';
    } else if (premium.value ?? false) {
      subscription = expiry == null
          ? l.settingsManageAccount_planPremium
          : l.settingsManageAccount_premiumUntil(
              AppDateUtils.formatDateDDMMYYYY(
                expiry,
                locale: Localizations.localeOf(context).languageCode,
              ),
            );
    } else {
      subscription = l.settingsManageAccount_planFree;
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      // Scrollable because the payment history below can be arbitrarily long;
      // the sheet itself is content-sized, so without this it could overflow.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.settingsManageAccount_subscriptionDetails,
              style: AppTypography.titleLg,
            ),
            SizedBox(height: AppSpacing.lg),
            _DetailRow(
              label: l.settingsManageAccount_role,
              value: _roleLabel(
                l,
                ref.watch(accountRoleProvider),
              ),
            ),
            if (ref.watch(firmModeProvider)) ...[
              SizedBox(height: AppSpacing.md),
              _DetailRow(
                label: l.settingsManageAccount_firm,
                value: (firm?.name ?? '').isNotEmpty ? firm!.name : '—',
              ),
            ],
            SizedBox(height: AppSpacing.md),
            _DetailRow(
              label: l.settingsManageAccount_subscription,
              value: subscription,
            ),
            // Phase 4 item 4: the plan and the expiry date, in DD/MM/YYYY.
            SizedBox(height: AppSpacing.md),
            _DetailRow(
              label: l.settingsManageAccount_plan,
              value: planValue,
            ),
            SizedBox(height: AppSpacing.md),
            _DetailRow(
              label: l.settingsManageAccount_expiry,
              value: expiry == null
                  ? '—'
                  : AppDateUtils.formatDateDDMMYYYY(
                      expiry,
                      locale: Localizations.localeOf(context).languageCode,
                    ),
            ),
            // Task 21 Phase 2 item 4: this account's own submissions, own rows
            // only under RLS. Placed here (behind Subscription Details) so the
            // mockup-bound Manage Account list needs no new row.
            SizedBox(height: AppSpacing.lg),
            Text(l.payments_historyTitle, style: AppTypography.titleMd),
            SizedBox(height: AppSpacing.sm),
            const _PaymentHistory(),
          ],
        ),
      ),
    );
  }
}

/// This account's payment submissions, newest first.
class _PaymentHistory extends ConsumerWidget {
  const _PaymentHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(myPaymentSubmissionsProvider);
    final muted = AppTypography.bodySm.copyWith(
      color: AppColors.onSurfaceVariant,
    );
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => Text(l.payments_noSubmissions, style: muted),
      data: (items) {
        if (items.isEmpty) return Text(l.payments_noSubmissions, style: muted);
        return Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: AppSpacing.lg, color: AppColors.outlineVariant),
              _PaymentHistoryRow(submission: items[i]),
            ],
          ],
        );
      },
    );
  }
}

/// One submission: plan, amount, status, and the reviewer's note.
class _PaymentHistoryRow extends StatelessWidget {
  const _PaymentHistoryRow({required this.submission});

  final PaymentSubmission submission;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final plan = paymentPlanLabel(l, submission.planType);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$plan · ${l.payments_amountValue(
                  AppDateUtils.formatDigits(submission.amount, locale),
                )}',
                style: AppTypography.bodyMd,
              ),
              if ((submission.adminNotes ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${l.payments_notesLabel}: ${submission.adminNotes}',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _PaymentStatusPill(status: submission.status),
      ],
    );
  }
}

/// The status pill for one submission.
class _PaymentStatusPill extends StatelessWidget {
  const _PaymentStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (label, color) = switch (status) {
      'approved' => (l.payments_statusApproved, AppColors.success),
      'rejected' => (l.payments_statusRejected, AppColors.error),
      _ => (l.payments_statusPending, AppColors.secondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      child: Text(
        label,
        style: AppTypography.labelMd.copyWith(color: color),
      ),
    );
  }
}

/// The localized name of a role; an unknown server role is shown as it came.
String _roleLabel(AppLocalizations l, String role) => switch (role) {
  AccountRole.individual => l.settingsManageAccount_roleIndividual,
  AccountRole.owner => l.settingsManageAccount_roleOwner,
  AccountRole.associate => l.settingsManageAccount_roleAssociate,
  AccountRole.viewer => l.settingsManageAccount_roleViewer,
  _ => role,
};

/// A labelled value row in the subscription sheet.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          label,
          style: AppTypography.labelMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
      SizedBox(width: AppSpacing.md),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
        ),
      ),
    ],
  );
}
