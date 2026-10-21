/// Subscription Details — the sub-page behind the Subscription screen's first row.
///
/// This was a bottom sheet once, and a sheet was the wrong shape for it: it
/// holds a plan, an expiry and a purchase history, which is reference material a
/// user reads rather than a choice they make, so it is a sub-page like every
/// other Settings destination — same header, same back button, room to scroll.
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
/// **Subscription History** is one card per purchase — plan, what was paid,
/// when, and the reviewer's verdict — because it is a ledger a user reconciles
/// against a bank or MFS statement, and a five-column grid on a phone either
/// wraps its dates or pushes the verdict off the edge. A card gives each entry
/// its own block, so it can be read, and re-read, without counting columns.
///
/// **Cancelling.** While a paid plan is running, and only while the plan is the
/// account's own, the summary card carries a **Cancel** action at its right. It
/// opens a window saying the plan cannot be restored, and a confirmed
/// cancellation calls the server's `cancel_subscription()` RPC — the only writer
/// of `subscription_cancellations` — then pulls the profile so the plan reads
/// its lapsed state. The cancellation appears in the same ledger as a new entry
/// with a red *Cancelled* label and the moment it happened.
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
                _LapsedAllowance(
                  l: l,
                  allowance: tier.lapseAllowance,
                  cancelled: cancelledAt != null,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              _SubscriptionHistorySection(l: l),
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
    final cancelledAt = ref.watch(subscriptionCancelledAtProvider);
    // *Free* only when it is known to be: an entitlement still in flight reads a
    // dash, and a dash is not Free — so neither the hidden expiry nor the
    // limitations belong to it. A lapsed account is not Free either, and keeps
    // its expiry row (it has a date, in the past) and its allowance block.
    final isFree =
        plan.known && !plan.premium && tier == SubscriptionTier.free;
    // A cancellation is the *reason* the period is over. A plan that simply ran
    // out has no cancellation behind it and keeps its Expiry row.
    final endedByCancellation =
        plan.known && !plan.premium && !isFree && cancelledAt != null;

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
              // The card's title names the plan; the red Limited Access tag is
              // stated once, in the Current Plan row below it.
              Expanded(
                child: CurrentPlanLabel(
                  style: AppTypography.titleLg,
                  showTag: false,
                ),
              ),
              // Cancel is offered only while a paid period is running and only
              // for the account's own plan: a free or lapsed plan has nothing
              // to end, and a chamber member's entitlement is the chamber's (the
              // server refuses that case with `firm_member`).
              if (plan.known && plan.premium && !ref.watch(firmMemberProvider))
                const Padding(
                  padding: EdgeInsets.only(left: AppSpacing.sm),
                  child: _CancelSubscriptionAction(),
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
                  ? _dateAndTime(l, cancelledAt.millisecondsSinceEpoch)
                  : expiryMs == null
                  ? '—'
                  : _dateAndTime(l, expiryMs),
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
        Text(
          l.settingsSubscription_lapsedTitle,
          style: AppTypography.titleMd,
        ),
        const SizedBox(height: AppSpacing.sm),
        _Card(
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

/// Subscription History: purchases and cancellations as one ledger.
///
/// The section was **Payment History** until cancellation existed; both tables
/// are now read together so a plan that was ended is an entry in the same list
/// as the payment that bought it, rather than a fact the page omits.
class _SubscriptionHistorySection extends ConsumerWidget {
  const _SubscriptionHistorySection({required this.l});

  final AppLocalizations l;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.payments_historyTitle, style: AppTypography.titleMd),
        const SizedBox(height: AppSpacing.sm),
        _SubscriptionHistoryCards(
          l: l,
          submissions: ref.watch(myPaymentSubmissionsProvider),
          cancellations: ref.watch(mySubscriptionCancellationsProvider),
        ),
      ],
    );
  }
}

/// The Cancel action at the right of the plan card.
///
/// The confirmation is a window of its own because the decision cannot be
/// undone: the server keeps the tier but backdates the expiry behind the
/// 48-hour grace, so the account lands on its lapse allowance until it buys
/// again. The button is hidden by the summary card (see its comment), so this
/// widget is only ever built when cancelling makes sense.
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
    return TextButton(
      key: const ValueKey('subscription-details-cancel'),
      onPressed: _busy ? null : _cancel,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        // The default 48 px tap target is kept: the label is small, the target a
        // thumb hits is not.
        minimumSize: const Size(0, 40),
        // A filled destructive action (user request): the red the confirmation
        // window's own button carries, so the two read as one decision.
        backgroundColor: AppColors.error,
        foregroundColor: AppColors.onError,
        textStyle: AppTypography.labelMd,
      ),
      child: _busy
          ? const SizedBox(
              width: 14,
              height: 14,
              // White like the label: a spinner inherits no button colour of its
              // own, so the default primary would vanish into the red.
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.onError,
              ),
            )
          : Text(l.payments_cancelPlan),
    );
  }
}

/// Asks before the plan is ended for good.
///
/// Returns true only on **Confirm Cancellation**; **Go Back** and a dismissal
/// both return false and send nothing. The two actions are stacked full-width,
/// the shape the app's other irreversible windows use, with the way out in
/// black above the destructive red.
Future<bool> _showCancelSubscriptionDialog(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.payments_cancelTitle),
      content: Text(l.payments_cancelWarning, style: AppTypography.bodyMd),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextButton(
              key: const ValueKey('subscription-details-cancel-go-back'),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: AppColors.secondary,
                foregroundColor: AppColors.onSecondary,
                textStyle: const TextStyle(fontSize: 16),
              ),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l.payments_goBack),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              key: const ValueKey('subscription-details-cancel-confirm'),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.onError,
                textStyle: const TextStyle(fontSize: 16),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l.payments_confirmCancellation),
            ),
          ],
        ),
      ],
    ),
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

/// The verdict on one ledger entry, as a pill.
///
/// A pill rather than bare text so a card can be scanned for the one still
/// waiting, which is the purchase a user actually wants to find. A cancellation
/// is a verdict of its own — red, like a rejection, because the plan is no longer
/// running.
class _PaymentStatusPill extends StatelessWidget {
  const _PaymentStatusPill({required this.status});

  /// `pending`, `approved`, `rejected` or `cancelled`.
  final String status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (label, color) = switch (status) {
      'approved' => (l.payments_statusApproved, AppColors.success),
      'rejected' => (l.payments_statusRejected, AppColors.error),
      'cancelled' => (l.payments_statusCancelled, AppColors.error),
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

/// The ledger: one card per entry, purchases and cancellations together,
/// newest first.
class _SubscriptionHistoryCards extends StatelessWidget {
  const _SubscriptionHistoryCards({
    required this.l,
    required this.submissions,
    required this.cancellations,
  });

  final AppLocalizations l;
  final AsyncValue<List<PaymentSubmission>> submissions;
  final AsyncValue<List<SubscriptionCancellation>> cancellations;

  @override
  Widget build(BuildContext context) {
    if (submissions.isLoading || cancellations.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // What loaded is what is shown: a cancellations read that failed must not
    // hide the purchases, so the ledger draws whichever half it could read.
    final rows = <_HistoryRow>[
      ...?submissions.value?.map(_HistoryRow.purchase),
      ...?cancellations.value?.map(_HistoryRow.cancellation),
    ]..sort((a, b) => b.at.compareTo(a.at));

    if (rows.isEmpty) return _Empty(l.payments_noSubmissions);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _HistoryCard(number: i + 1, row: rows[i]),
          ),
      ],
    );
  }
}

/// One entry in the ledger, whichever table it came from.
///
/// A purchase and a cancellation are drawn by the same card, so their facts are
/// flattened to one shape. [at] is the moment the card prints — an approval for
/// an approved purchase, the submission otherwise, the cancellation for a
/// cancellation — so the list's order is the order the user reads.
class _HistoryRow {
  const _HistoryRow({
    required this.at,
    required this.planType,
    required this.amount,
    required this.status,
    this.note,
  });

  factory _HistoryRow.purchase(PaymentSubmission submission) => _HistoryRow(
    at: _purchaseAtMillis(submission),
    planType: submission.planType,
    amount: submission.amount,
    status: submission.status,
    note: submission.adminNotes,
  );

  factory _HistoryRow.cancellation(SubscriptionCancellation cancellation) =>
      _HistoryRow(
        at: cancellation.cancelledAt?.millisecondsSinceEpoch ?? 0,
        planType: cancellation.planType ?? '',
        amount: cancellation.amount,
        status: 'cancelled',
      );

  /// Epoch millis of the moment the card prints, or 0 when it has none.
  final int at;

  /// The plan key, empty when the server could not name one.
  final String planType;

  /// What was paid, or null when the server could not name it.
  final int? amount;

  /// `pending`, `approved`, `rejected` or `cancelled`.
  final String status;

  /// The reviewer's note, on a purchase that carries one.
  final String? note;
}

/// One entry: its number and plan across the top, the verdict beside them, and
/// what was paid and when beneath.
///
/// The number is part of the data a user reconciles against ("that was my
/// second one"), so it is kept even though a card makes it obvious which is
/// which. The reviewer's note is shown when there is one — a rejection always
/// carries a reason, and a ledger that hid it would leave the user guessing why
/// money did not become a subscription. A cancellation carries the plan and the
/// amount that were running, so its card repeats those facts with the moment it
/// ended.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.number, required this.row});

  /// Position in the list, newest first.
  final int number;

  /// The entry itself.
  final _HistoryRow row;

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
                  // An unnamed plan is a dash, never the plan label's default —
                  // a cancellation the server could not attribute must not read
                  // as a 1 Month purchase.
                  row.planType.isEmpty
                      ? '—'
                      : paymentPlanLabel(l, row.planType),
                  style: AppTypography.titleMd,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _PaymentStatusPill(status: row.status),
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
                value: row.amount == null
                    ? '—'
                    : l.payments_amountValue(
                        AppDateUtils.formatDigits(
                          row.amount!,
                          l.localeName,
                        ),
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _LabelledValue(
                  label: l.settingsSubscription_dateTime,
                  value: _historyAtLabel(l, row.at),
                  trailing: true,
                ),
              ),
            ],
          ),
          if ((row.note ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.gutter),
            _LabelledValue(
              label: l.payments_notesLabel,
              value: row.note!,
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
              child: valueChild ??
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

/// The moment a purchase happened: the approval for one that was approved, the
/// submission otherwise — a pending or rejected purchase never happened, so its
/// card shows the only moment it has. A cancellation's moment is its own.
int _purchaseAtMillis(PaymentSubmission submission) =>
    (submission.status == 'approved'
            ? submission.approvedAt ?? submission.submittedAt
            : submission.submittedAt)
        ?.millisecondsSinceEpoch ??
    0;

/// The moment a ledger entry prints, or a dash when it carries none: an entry
/// with no time sorts last rather than first, because an unknown moment is not
/// the newest one.
String _historyAtLabel(AppLocalizations l, int epochMs) =>
    epochMs == 0 ? '—' : _dateAndTime(l, epochMs);

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
