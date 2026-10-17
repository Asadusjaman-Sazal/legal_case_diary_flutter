/// Subscription Details — the sub-page behind the Subscription screen's first row.
///
/// This was a bottom sheet once, and a sheet was the wrong shape for it: it
/// holds a plan, an expiry and a purchase history, which is reference material a
/// user reads rather than a choice they make, so it is a sub-page like every
/// other Settings destination — same header, same back button, room to scroll.
///
/// **What it states.** **Role** (and the firm, in firm mode) is the account's
/// standing, **Current Plan** is what is actually running — a plan name or *Free*
/// — and **Expiry** is when it ends, to the minute. *Current Plan* keeps the
/// plan rule the engine uses: an entitlement that has not landed yet reads a
/// dash rather than *Free*, because a premium user whose profile pull is in
/// flight must never be told they have nothing (plan §6, the entitlement
/// bullet).
///
/// **Payment History** is one card per purchase — plan, what was paid, when,
/// and the reviewer's verdict — because it is a ledger a user reconciles against
/// a bank or MFS statement, and a five-column grid on a phone either wraps its
/// dates or pushes the verdict off the edge. A card gives each purchase its own
/// block, so it can be read, and re-read, without counting columns.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/free_tier.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/utils/date_utils.dart';
import '../../accounts_and_profile/data/account_mode.dart';
import '../../accounts_and_profile/data/profile_repository.dart';
import '../../payments/data/payment_plans.dart';
import '../../payments/data/payment_repository.dart';
import '../../payments/presentation/current_plan.dart';
import '../../payments/presentation/payment_plan_labels.dart';
import 'settings_sub_page_modal.dart';

/// The Subscription Details sub-page.
class SubscriptionDetailsScreen extends ConsumerWidget {
  /// Creates the screen.
  const SubscriptionDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    // The limitations are for a *known* Free plan only: an entitlement still in
    // flight reads a dash, which is neither Free nor premium.
    final plan = ref.watch(currentPlanProvider);
    final tier = ref.watch(allowanceTierProvider);
    // A paid tier with no entitlement is **lapsed**, not free: its 50-case block
    // would contradict the allowance it still holds (Phase 10).
    final isLapsed =
        plan.known && !plan.premium && tier != SubscriptionTier.free;
    final isFree = plan.known && !plan.premium && !isLapsed;

    return SettingsSubPageModal(
      title: l.settingsManageAccount_subscriptionDetails,
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
            if (isFree) ...[
              const SizedBox(height: AppSpacing.lg),
              _FreePlanLimitations(l: l),
            ] else if (isLapsed) ...[
              const SizedBox(height: AppSpacing.lg),
              _LapsedAllowance(l: l, allowance: tier.lapseAllowance),
            ],
            const SizedBox(height: AppSpacing.lg),
            _PaymentHistorySection(l: l),
          ],
        ),
      ),
    );
  }
}

/// Role, current plan and expiry — the three facts about the account's standing.
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
    final currentPlan = currentPlanLabel(l, plan, tier: tier);
    // *Free* only when it is known to be: an entitlement still in flight reads a
    // dash, and a dash is not Free — so neither the hidden expiry nor the
    // limitations belong to it. A lapsed account is not Free either, and keeps
    // its expiry row (it has a date, in the past) and its allowance block.
    final isFree =
        plan.known && !plan.premium && tier == SubscriptionTier.free;

    return _Card(
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
              Expanded(
                child: Text(
                  currentPlan,
                  style: AppTypography.titleLg,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
            value: currentPlan,
            emphasise: true,
            // A free plan has no expiry, so that row is gone and this is last.
            last: isFree,
          ),
          // Expiry is shown unless the plan is Free: a free account has nothing
          // to expire, and a dash beside "Free" reads as a missing value rather
          // than "not applicable".
          if (!isFree)
            _DetailRow(
              label: l.settingsManageAccount_expiry,
              // To the minute, like the history below: a renewal is tracked by
              // the hour it was approved, not by a bare date.
              value: expiryMs == null ? '—' : _dateAndTime(l, expiryMs),
              last: true,
            ),
        ],
      ),
    );
  }
}

/// What a lapsed paid account may still write (Phase 10).
///
/// Shown instead of the free block: the account holds a tier, so the free 50 is
/// not its rule — its allowance is.
class _LapsedAllowance extends StatelessWidget {
  const _LapsedAllowance({required this.l, required this.allowance});

  final AppLocalizations l;

  /// The tier's lapse allowance (Pro 100, Firm 500, Firm Plus 1,000).
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
        Text(
          l.settingsSubscription_lapsedTitle,
          style: AppTypography.titleMd,
        ),
        const SizedBox(height: AppSpacing.sm),
        _Card(
          child: Text(
            l.settingsSubscription_lapsedBody(count),
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

  @override
  Widget build(BuildContext context) {
    final limit = AppDateUtils.formatDigits(
      freeTierCaseLimit,
      l.localeName,
    );
    final limitations = <String>[
      l.settingsSubscription_freeLimitCases(limit),
      l.settingsSubscription_freeLimitCloud,
      l.settingsSubscription_freeLimitRecovery,
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
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < limitations.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.md),
                _LimitationRow(text: limitations[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One limitation: a red bullet, then its sentence.
class _LimitationRow extends StatelessWidget {
  const _LimitationRow({required this.text});

  final String text;

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
        child: Text(
          text,
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
    ],
  );
}

/// Payment History: the account's own submissions, as a ledger.
class _PaymentHistorySection extends ConsumerWidget {
  const _PaymentHistorySection({required this.l});

  final AppLocalizations l;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myPaymentSubmissionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.payments_historyTitle, style: AppTypography.titleMd),
        const SizedBox(height: AppSpacing.sm),
        _PaymentHistoryCards(l: l, async: async)
      ],
    );
  }
}

/// The verdict on one purchase, as a pill.
///
/// A pill rather than bare text so a card can be scanned for the one still
/// waiting, which is the purchase a user actually wants to find.
class _PaymentStatusPill extends StatelessWidget {
  const _PaymentStatusPill({required this.status});

  /// `pending`, `approved` or `rejected`.
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
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Text(
        label,
        style: AppTypography.labelMd.copyWith(color: color),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// The ledger: one card per purchase, newest first.
class _PaymentHistoryCards extends StatelessWidget {
  const _PaymentHistoryCards({required this.l, required this.async});

  final AppLocalizations l;
  final AsyncValue<List<PaymentSubmission>> async;

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => _Empty(l.payments_noSubmissions),
      data: (items) {
        if (items.isEmpty) return _Empty(l.payments_noSubmissions);
        // Newest first, so the purchase a user is asking about is the one they
        // do not have to scroll for.
        final rows = [...items]
          ..sort((a, b) => _submittedMillis(b).compareTo(_submittedMillis(a)));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _PaymentHistoryCard(
                  number: i + 1,
                  submission: rows[i],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One purchase: its number and plan across the top, the verdict beside them,
/// and what was paid and when beneath.
///
/// The number is part of the data a user reconciles against ("that was my
/// second one"), so it is kept even though a card makes it obvious which is
/// which. The reviewer's note is shown when there is one — a rejection always
/// carries a reason, and a ledger that hid it would leave the user guessing why
/// money did not become a subscription.
class _PaymentHistoryCard extends StatelessWidget {
  const _PaymentHistoryCard({required this.number, required this.submission});

  /// Position in the list, newest first.
  final int number;

  /// The purchase itself.
  final PaymentSubmission submission;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // The number as a small tinted circle, so a purchase is a thing
              // rather than a line.
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  // Bengali reads ১: a card number is a number like the
                  // amount beside it, so it takes the active language's
                  // digits.
                  AppDateUtils.formatDigits(
                    number,
                    l.localeName,
                    grouping: false,
                  ),
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.gutter),
              Expanded(
                child: Text(
                  paymentPlanLabel(l, submission.planType),
                  style: AppTypography.titleMd,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _PaymentStatusPill(status: submission.status),
            ],
          ),
          const SizedBox(height: AppSpacing.gutter),
          const Divider(height: 1, color: AppColors.outlineVariant),
          const SizedBox(height: AppSpacing.gutter),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Paid takes its natural width and the timestamp takes everything
              // that is left: two equal Expanded halves made the timestamp the
              // card's narrower column, and it wrapped its AM/PM while the
              // short Paid value sat on unused space.
              _LabelledValue(
                label: l.settingsSubscription_paid,
                value: l.payments_amountValue(
                  AppDateUtils.formatDigits(
                    submission.amount,
                    l.localeName,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _LabelledValue(
                  label: l.settingsSubscription_dateTime,
                  value: _purchaseAtLabel(l, submission),
                  trailing: true,
                ),
              ),
            ],
          ),
          if ((submission.adminNotes ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.gutter),
            _LabelledValue(
              label: l.payments_notesLabel,
              value: submission.adminNotes!,
            ),
          ],
        ],
      ),
    );
  }
}

/// A small caption over its value, right-aligned where the card's second
/// column sits.
class _LabelledValue extends StatelessWidget {
  const _LabelledValue({
    required this.label,
    required this.value,
    this.trailing = false,
  });

  final String label;
  final String value;

  /// Whether this sits in the card's right-hand column.
  final bool trailing;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: trailing
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            textAlign: trailing ? TextAlign.right : TextAlign.left,
            style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
          ),
        ],
      );
}

/// The empty state, which says what is missing rather than showing a bare table.
class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(
          text,
          style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
        ),
      );
}

/// A card in the Settings surface: the shared border, radius and padding.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: child,
      );
}

/// A labelled value row: label left, value right, hairline beneath.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.emphasise = false,
    this.last = false,
  });

  final String label;
  final String value;

  /// The plan is the answer a user came here for, so it is set larger than the
  /// rest rather than reading as one more fact.
  final bool emphasise;

  /// Whether this is the card's final row, and so carries no divider.
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
        decoration: last
            ? null
            : const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.outlineVariant),
                ),
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
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: emphasise
                    ? AppTypography.titleMd
                    : AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
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

/// The moment a purchase happened: the approval for one that was approved, the
/// submission otherwise — a pending or rejected purchase never happened, so its
/// card shows the only moment it has.
String _purchaseAtLabel(AppLocalizations l, PaymentSubmission submission) {
  final at = (submission.status == 'approved'
          ? submission.approvedAt ?? submission.submittedAt
          : submission.submittedAt)
      ?.millisecondsSinceEpoch;
  if (at == null) return '—';
  return _dateAndTime(l, at);
}

/// A purchase's epoch millis, with a submission that carries no time sorted
/// last rather than first: an unknown moment is not the newest one.
int _submittedMillis(PaymentSubmission submission) =>
    submission.submittedAt?.millisecondsSinceEpoch ?? 0;

/// `DD/MM/YYYY, hh:mm a` in Bangladesh civil time.
///
/// Every timestamp a Bengali lawyer reads has to be the local one, so both
/// halves go through [AppDateUtils], which shifts to Bangladesh civil time
/// before formatting: `formatDateDDMMYYYY` does that for the date, and the
/// clock time is derived from the same shifted value rather than from the raw
/// instant, which would otherwise disagree with the date beside it by six hours.
String _dateAndTime(AppLocalizations l, int epochMs) {
  final civil = AppDateUtils.bangladeshDateTime(epochMs);
  final minutes = civil.hour * 60 + civil.minute;
  return '${AppDateUtils.formatDateDDMMYYYY(epochMs, locale: l.localeName)}, '
      '${AppDateUtils.formatClockTime(minutes, locale: l.localeName)}';
}
