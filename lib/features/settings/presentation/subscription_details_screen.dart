/// Manage Plan — the plan itself, its usage, and the subscription actions.
///
/// It was Subscription Details until 0.0.624, when the owner split the purchase
/// ledger out into Subscription History and moved both onto the Account &
/// Profile menu's Subscription section. It is still a sub-page like every other
/// Settings destination — same header, same back button, room to scroll — and a
/// top-level route because the checkout can open it.
///
/// **What it states.** **Role** (and the firm, in firm mode) is the account's
/// standing, **Current Plan** is what is actually running — a plan name or *Free*
/// — and **Expiry** is when it ends, to the minute. A plan the account
/// cancelled says **Cancelled** with the moment it happened instead: the server
/// backdates that expiry, so it is not the fact the user is looking for.
/// *Current Plan* keeps the
/// plan rule the engine uses: an entitlement that has not landed yet reads a
/// dash rather than *Free*, because a premium user whose profile pull is in
/// flight must never be told they have nothing (plan §6, the entitlement
/// bullet).
///
/// **While the plan is live** the page adds two blocks below the summary
/// (0.0.626, user request): **Plan Usage** — the cases and devices left under
/// the tier's ceiling — and **Manage Subscription**, a full-width **Renew
/// Subscription** and **Cancel Subscription** pair. A chamber **member** reads
/// the usage and a note that the owner buys and renews instead; the server
/// refuses their renewal and cancellation, so neither action is offered.
///
/// **Cancelling.** The Cancel action opens a window saying the plan cannot be
/// restored, and a confirmed cancellation calls the server's
/// `cancel_subscription()` RPC — the only writer of `subscription_cancellations`
/// — then pulls the profile so the plan reads its lapsed state. The
/// cancellation appears in Subscription History as a new entry with a red
/// *Cancelled* label and the moment it happened.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/free_tier.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_dialog_actions.dart';
import '../../accounts_and_profile/data/account_mode.dart';
import '../../accounts_and_profile/data/profile_repository.dart';
import '../../payments/data/payment_plans.dart';
import '../../payments/data/payment_repository.dart';
import '../../payments/presentation/current_plan.dart';
import 'plan_usage_section.dart';
import 'settings_menu_card.dart';
import 'settings_sub_page_modal.dart';
import 'subscription_widgets.dart';

/// The Manage Plan sub-page.
class SubscriptionDetailsScreen extends ConsumerWidget {
  /// Creates the screen.
  const SubscriptionDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    // A chamber member reads the chamber's plan, so the page and the row that
    // opens it are named **Firm Plan** for them (user request, 0.0.698).
    final isMember = ref.watch(firmMemberProvider);
    // The limitations are for a *known* Free plan only: an entitlement still in
    // flight reads a dash, which is neither Free nor premium.
    final plan = ref.watch(currentPlanProvider);
    final tier = ref.watch(allowanceTierProvider);
    // Usage and the two actions belong to a **live** paid plan only. A granted
    // period with no expired tier is still premium here; the tier itself is
    // read by the usage block.
    final isPremium = plan.known && plan.premium;
    // A paid tier with no entitlement is **lapsed**, not free: its 50-case block
    // would contradict the allowance it still holds (Phase 10).
    final isLapsed =
        plan.known && !plan.premium && tier != SubscriptionTier.free;
    final isFree = plan.known && !plan.premium && !isLapsed;
    // Why the plan ended, when it did: a cancellation stamps the card with the
    // moment it happened, and gives the Limited Access block its own sentence.
    final cancelledAt = ref.watch(subscriptionCancelledAtProvider);

    // The status bar is the user's own. This page is a top-level route (it sits
    // outside the shell so the checkout can push it — see the router), so the
    // shell's own `SafeArea(top: true)` does not reach it. Without this inset
    // the Scaffold paints its app bar up behind the status bar, and the phone's
    // clock and icons sit on that white instead of on the app's own black.
    // Same inset, and same reason, as the paywall's and legal documents' own
    // `SafeArea` — the Subscription Plans screen is how this one should read.
    return SafeArea(
      top: true,
      bottom: false,
      child: SettingsSubPageModal(
        title: isMember
            ? l.settingsSubscription_firmPlanTitle
            : l.settingsSubscription_managePlanTitle,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.edgeMargin,
            AppSpacing.md,
            AppSpacing.edgeMargin,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SubscriptionSummaryCard(),
              if (isPremium) ...[
                const SizedBox(height: AppSpacing.lg),
                const PlanUsageSection(),
                const SizedBox(height: AppSpacing.lg),
                const _ManageSubscriptionSection(),
              ] else if (isFree) ...[
                const SizedBox(height: AppSpacing.lg),
                _FreePlanLimitations(l: l),
              ] else if (isLapsed) ...[
                const SizedBox(height: AppSpacing.lg),
                _LapsedAllowance(
                  l: l,
                  allowance: tier.lapseAllowance,
                  cancelled: cancelledAt != null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Role, current plan and expiry (or its cancellation) — the facts about the
/// account's standing, all set at one size.
class _SubscriptionSummaryCard extends ConsumerWidget {
  const _SubscriptionSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final profile = ref.watch(accountProfileProvider).value;
    final firm = ref.watch(accountFirmProvider).value;
    // The firm's expiry is the source of truth for a member; an individual's is
    // their own. Exactly the split `resolvePremiumAccess` uses.
    final expiryMs = profile?.firmId == null
        ? profile?.subscriptionExpiry
        : firm?.subscriptionExpiry;

    // The plan, through the one derivation that also prints in the side menu
    // ([currentPlanProvider]) — the dash rule for an entitlement that has not
    // landed lives there, so both surfaces tell the user the same thing.
    final plan = ref.watch(currentPlanProvider);
    final tier = ref.watch(allowanceTierProvider);
    // A chamber member's own ledger names no plan, so the card names the
    // chamber's tier instead of *Premium* (user request, 0.0.699).
    final member = ref.watch(firmMemberProvider);
    final cancelledAt = ref.watch(subscriptionCancelledAtProvider);
    // *Free* only when it is known to be: an entitlement still in flight reads a
    // dash, and a dash is not Free — so neither the hidden expiry nor the
    // limitations belong to it. A lapsed account is not Free either, and keeps
    // its expiry row (it has a date, in the past) and its allowance block.
    final isFree = plan.known && !plan.premium && tier == SubscriptionTier.free;
    // A cancellation is the *reason* the period is over. A plan that simply ran
    // out has no cancellation behind it and keeps its Expiry row.
    final endedByCancellation =
        plan.known && !plan.premium && !isFree && cancelledAt != null;

    return SubscriptionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: what this card is about, in the app's own title style.
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.workspace_premium_outlined,
                  size: 22,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // The card's title names the plan; the red Limited Access tag is
              // stated once, in the Current Plan row below it.
              Expanded(
                child: CurrentPlanLabel(
                  style: AppTypography.titleLg,
                  showTag: false,
                  firmPlanName: member,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.outlineVariant),
          _DetailRow(
            label: l.settingsManageAccount_role,
            value: _roleLabel(l, ref.watch(accountRoleProvider)),
          ),
          if (ref.watch(firmModeProvider))
            _DetailRow(
              label: l.settingsManageAccount_firm,
              value: (firm?.name ?? '').isNotEmpty ? firm!.name : '—',
            ),
          _DetailRow(
            label: l.settingsSubscription_currentPlan,
            // The plan keeps its weight but takes the same size as every other
            // value on the card (user request).
            valueChild: CurrentPlanLabel(
              style: AppTypography.bodyMd.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
              textAlign: TextAlign.right,
              firmPlanName: member,
            ),
            // A free plan has no expiry, so that row is gone and this is last.
            last: isFree,
          ),
          // Expiry is shown unless the plan is Free: a free account has nothing
          // to expire, and a dash beside "Free" reads as a missing value rather
          // than "not applicable". A plan the account cancelled shows that
          // cancellation instead — its moment is the fact the user came for, and
          // the backdated expiry behind it would only confuse.
          if (!isFree)
            _DetailRow(
              label: endedByCancellation
                  ? l.payments_statusCancelled
                  : l.settingsManageAccount_expiry,
              // To the minute, like the history below: a renewal is tracked by
              // the hour it was approved, not by a bare date.
              value: endedByCancellation
                  ? formatSubscriptionDateTime(
                      l,
                      cancelledAt.millisecondsSinceEpoch,
                    )
                  : expiryMs == null
                  ? '—'
                  : formatSubscriptionDateTime(l, expiryMs),
              last: true,
            ),
        ],
      ),
    );
  }
}

/// What a paid account on **Limited Access** may still write (Phase 10).
///
/// Shown instead of the free block: the account holds a tier, so the free 50 is
/// not its rule — its allowance is. The sentence names the reason the access
/// became limited, because "cancelled" and "expired" are different news.
class _LapsedAllowance extends StatelessWidget {
  const _LapsedAllowance({
    required this.l,
    required this.allowance,
    required this.cancelled,
  });

  final AppLocalizations l;

  /// Whether the plan ended because the account cancelled it.
  final bool cancelled;

  /// The tier's lapse allowance (Starter 100, Pro 250, Firm 500,
  /// Firm Plus 1,000, Enterprise 2,000).
  final int allowance;

  @override
  Widget build(BuildContext context) {
    final count = AppDateUtils.formatDigits(
      allowance,
      l.localeName,
      grouping: true,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.settingsSubscription_lapsedTitle, style: AppTypography.titleMd),
        const SizedBox(height: AppSpacing.sm),
        SubscriptionCard(
          child: Text(
            cancelled
                ? l.settingsSubscription_lapsedBodyCancelled(count)
                : l.settingsSubscription_lapsedBody(count),
            style: AppTypography.bodyMd,
          ),
        ),
      ],
    );
  }
}

/// What a Free account cannot do — shown only while the plan is Free, before
/// the purchase history.
///
/// Each line is a real limitation, not marketing: the case ceiling comes from
/// [freeTierCaseLimit] (the same constant the Add Case gate enforces, so the
/// two can never disagree), and the cloud, multi-device, collaboration and
/// recovery points are exactly the cloud features the paid plans add. The
/// header carries a bullet so the list reads as the section's items.
class _FreePlanLimitations extends StatelessWidget {
  const _FreePlanLimitations({required this.l});

  final AppLocalizations l;

  /// The bold phrase inside a limitation: the weight only, so the row's ink
  /// and size still come from its parent.
  static const TextStyle _bold = TextStyle(fontWeight: FontWeight.w700);

  @override
  Widget build(BuildContext context) {
    final limit = AppDateUtils.formatDigits(freeTierCaseLimit, l.localeName);
    // The three monthly rates the ladder sells on Starter: the yearly plan is
    // the cheapest per month, which is why the block says "starting at".
    String rate(int total, int months) =>
        AppDateUtils.formatDigits(total ~/ months, l.localeName);
    final limitations = <List<InlineSpan>>[
      [
        TextSpan(text: l.settingsSubscription_freeLimitCasesPrefix),
        TextSpan(
          text: l.settingsSubscription_freeLimitCasesBold(limit),
          style: _bold,
        ),
        TextSpan(text: l.settingsSubscription_freeLimitCasesSuffix),
      ],
      [TextSpan(text: l.settingsSubscription_freeLimitCloud)],
      [
        TextSpan(
          text: l.settingsSubscription_freeLimitRecoveryBold,
          style: _bold,
        ),
        TextSpan(text: l.settingsSubscription_freeLimitRecoverySuffix),
      ],
    ];
    final offers = <(String, String)>[
      (
        rate(paymentStarterQuarterlyPrice, 3),
        l.settingsSubscription_upgradeQuarterly,
      ),
      (
        rate(paymentStarterHalfYearlyPrice, 6),
        l.settingsSubscription_upgradeHalfYearly,
      ),
      (
        rate(paymentStarterAnnualPrice, 12),
        l.settingsSubscription_upgradeAnnual,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The heading is a plain title (user request): the leading bullet that
        // used to head it is gone, and only the limitations below stay bulleted.
        Text(
          l.settingsSubscription_freePlanLimitations,
          style: AppTypography.titleMd,
        ),
        const SizedBox(height: AppSpacing.sm),
        SubscriptionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < limitations.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.md),
                _LimitationRow(spans: limitations[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // The upgrade offer (user request): the same three limitation bullets
        // above, then what a paid plan would add and the cheapest entry.
        Text(
          l.settingsSubscription_upgradeTitle,
          style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l.settingsSubscription_upgradeBody,
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SubscriptionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < offers.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.md),
                _LimitationRow(
                  spans: [
                    TextSpan(
                      text: l.settingsSubscription_upgradeRate(offers[i].$1),
                      style: _bold,
                    ),
                    TextSpan(text: offers[i].$2),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l.settingsSubscription_upgradeHint,
          style: AppTypography.bodySm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: FilledButton(
            key: const ValueKey('manage-plan-upgrade'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              textStyle: AppTypography.labelLg,
            ),
            onPressed: () => context.push(AppRoutes.paywall),
            child: Text(l.paywall_title),
          ),
        ),
      ],
    );
  }
}

/// One limitation: a red bullet, then its sentence.
class _LimitationRow extends StatelessWidget {
  const _LimitationRow({required this.spans});

  /// The sentence as spans, so one phrase can carry the bold weight.
  final List<InlineSpan> spans;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 6,
        height: 6,
        // Nudged down to sit on the first line's centre rather than its top.
        margin: const EdgeInsets.only(top: 8, right: AppSpacing.sm),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          // Black bullets (user request), not the error red they carried.
          color: AppColors.secondary,
        ),
      ),
      Expanded(
        child: Text.rich(
          TextSpan(children: spans),
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
    ],
  );
}

/// Renew and Cancel at the size of the page's other primary actions.
///
/// A chamber **member** gets the owner sentence instead: their entitlement is
/// the chamber's, and the server refuses both actions for them.
class _ManageSubscriptionSection extends ConsumerWidget {
  const _ManageSubscriptionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.settingsSubscription_manageSubscription,
          style: AppTypography.titleMd,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (ref.watch(firmMemberProvider))
          SubscriptionCard(
            // Justified, like a paragraph rather than a label (user request,
            // 0.0.698).
            child: Text(
              l.paywall_memberPlanBody,
              textAlign: TextAlign.justify,
              style: AppTypography.bodyMd,
            ),
          )
        else ...[
          SizedBox(
            width: double.infinity,
            height: settingsPrimaryButtonHeight,
            child: FilledButton(
              key: const ValueKey('manage-plan-renew'),
              // The plans screen owns the term choice and the queued-change
              // warning, so renewal starts there rather than at checkout.
              onPressed: () => context.push(AppRoutes.paywall),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                textStyle: AppTypography.labelLg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
                ),
              ),
              child: Text(l.settingsSubscription_renewSubscription),
            ),
          ),
          const SizedBox(height: AppSpacing.gutter),
          const _CancelSubscriptionAction(),
        ],
      ],
    );
  }
}

/// The Cancel action, full width under Renew.
///
/// The confirmation is a window of its own because the decision cannot be
/// undone: the server keeps the tier but backdates the expiry behind the
/// 48-hour grace, so the account lands on its lapse allowance until it buys
/// again. Only the Manage Subscription block builds it, and only for a live
/// plan the account owns.
class _CancelSubscriptionAction extends ConsumerStatefulWidget {
  const _CancelSubscriptionAction();

  @override
  ConsumerState<_CancelSubscriptionAction> createState() =>
      _CancelSubscriptionActionState();
}

class _CancelSubscriptionActionState
    extends ConsumerState<_CancelSubscriptionAction> {
  /// True while the RPC is in flight, so the action cannot fire twice.
  bool _busy = false;

  Future<void> _cancel() async {
    final confirmed = await _showCancelSubscriptionDialog(context);
    if (!confirmed || !mounted) return;

    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(paymentRepositoryProvider).cancelSubscription();
      // The server moved the expiry behind the grace window, so the cached
      // profile has to be pulled before the page can read *Lapsed*: the plan,
      // the expiry and the limitations all derive from that row.
      await ref.read(accountRefreshProvider)();
      // The two ledger reads: the cancellation just recorded, and the purchases
      // the plan label is derived from.
      ref.invalidate(mySubscriptionCancellationsProvider);
      ref.invalidate(myPaymentSubmissionsProvider);
    } on PaymentCancelException catch (error) {
      if (!mounted) return;
      // A refusal leaves the plan exactly as it was, so it is reported and the
      // page is not touched.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cancelFailureText(l, error.kind))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      height: settingsPrimaryButtonHeight,
      child: FilledButton(
        key: const ValueKey('subscription-details-cancel'),
        onPressed: _busy ? null : _cancel,
        style: FilledButton.styleFrom(
          // A filled destructive action: the red the confirmation window's own
          // button carries, so the two read as one decision.
          backgroundColor: AppColors.error,
          foregroundColor: AppColors.onError,
          // While the RPC runs only the spinner shows; a greyed button behind a
          // white spinner would look broken.
          disabledBackgroundColor: AppColors.error.withValues(alpha: 0.6),
          textStyle: AppTypography.labelLg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
          ),
        ),
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                // White like the label: a spinner inherits no button colour of
                // its own, so the default primary would vanish into the red.
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.onError,
                ),
              )
            : Text(l.settingsSubscription_cancelSubscription),
      ),
    );
  }
}

/// Asks before the plan is ended for good.
///
/// Returns true only on **Confirm Cancellation**; **Go Back** and a dismissal
/// both return false and send nothing. The two actions are stacked full-width,
/// the shape the app's other irreversible windows use, with the way out in
/// black above the destructive red, at the shared 48 px action height.
///
/// **Geometry.** The window keeps its own 24 px side inset (the default 40 px
/// gave 340 px on a 420 px screen, so this is about 10% wider) and the extra
/// room around the body, split above and below so the window grows without
/// crowding the title or the actions. The extra height is a concrete amount
/// rather than a fraction: the body wraps to more lines in Bengali or at a
/// larger font, and a percentage would either clip it or shrink on a short
/// window.
Future<bool> _showCancelSubscriptionDialog(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final confirmed = await showAppDialog<bool>(
    context,
    // 10% wider than the default 40 px inset on the app's phones.
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    title: Text(l.payments_cancelTitle, textAlign: TextAlign.center),
    content: Padding(
      // 20% taller, as breathing room around the sentence rather than a
      // fixed window height, which a long Bengali line or a larger font
      // would otherwise clip.
      padding: const EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.xl + AppSpacing.sm,
      ),
      child: Text(l.payments_cancelWarning, style: AppTypography.bodyMd),
    ),
    actionMode: AppDialogActionMode.stack,
    actions: (dialogContext) => [
      AppDialogAction(
        key: const ValueKey('subscription-details-cancel-go-back'),
        label: l.payments_goBack,
        kind: AppDialogActionKind.primary,
        background: AppColors.secondary,
        foreground: AppColors.onSecondary,
        onPressed: () => Navigator.of(dialogContext).pop(false),
      ),
      AppDialogAction(
        key: const ValueKey('subscription-details-cancel-confirm'),
        label: l.payments_confirmCancellation,
        kind: AppDialogActionKind.destructive,
        onPressed: () => Navigator.of(dialogContext).pop(true),
      ),
    ],
  );
  return confirmed == true;
}

/// The sentence a refused cancellation is reported with.
///
/// The typed failures the server can answer are worded here; a transport or
/// unknown failure keeps the generic retry sentence, because the user's next
/// step is the same either way.
String _cancelFailureText(AppLocalizations l, PaymentCancelFailure kind) =>
    switch (kind) {
      PaymentCancelFailure.noActivePlan => l.payments_cancelNoActivePlan,
      PaymentCancelFailure.firmMember => l.payments_cancelFirmMember,
      _ => l.payments_cancelFailed,
    };

/// A labelled value row: label left, value right, hairline beneath.
///
/// Every value is the same size — the section's own body size — because the card
/// is a list of facts, not a headline and four footnotes (user request). The
/// plan keeps only its extra weight.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    this.value,
    this.valueChild,
    this.last = false,
  }) : assert(value != null || valueChild != null, 'a row shows a value');

  final String label;

  /// The value as plain text; null when [valueChild] draws it.
  final String? value;

  /// A value that needs more than one style, such as the plan's red tag.
  final Widget? valueChild;

  /// Whether this is the card's final row, and so carries no divider.
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    decoration: last
        ? null
        : const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
          ),
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.gutter),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Natural width, not Expanded: an expanded label takes half the row
        // even when the label is one word, and a timestamp like
        // "01/12/2026, 11:30 PM" wrapped in the remaining half. The label
        // takes what it needs; the value below takes the rest.
        Text(
          label,
          style: AppTypography.labelMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        // Expanded, not Flexible: a flexible box is only as wide as the
        // text inside it, so "right" meant "immediately after the label".
        // The value has to take the rest of the row to sit at the edge.
        Expanded(
          child:
              valueChild ??
              Text(
                value!,
                textAlign: TextAlign.right,
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
        ),
      ],
    ),
  );
}

/// The localized name of a role; an unknown server role is shown as it came.
String _roleLabel(AppLocalizations l, String role) => switch (role) {
  AccountRole.individual => l.settingsManageAccount_roleIndividual,
  AccountRole.owner => l.settingsManageAccount_roleOwner,
  AccountRole.associate => l.settingsManageAccount_roleAssociate,
  AccountRole.viewer => l.settingsManageAccount_roleViewer,
  _ => role,
};
