/// Subscription History: purchases and cancellations as one ledger.
///
/// This was the bottom half of Subscription Details until the owner split it
/// out (0.0.624). The screen's header is the only title: the section it draws
/// has no heading of its own, because repeating "Subscription History" under
/// the AppBar says nothing new.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/utils/date_utils.dart';
import '../../payments/data/payment_repository.dart';
import '../../payments/presentation/payment_plan_labels.dart';
import 'settings_sub_page_modal.dart';
import 'subscription_widgets.dart';

/// The Subscription History sub-page: the ledger alone, under its own header.
class SubscriptionHistoryScreen extends ConsumerWidget {
  const SubscriptionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A top-level route: the Account & Profile menu opens it from inside the
    // shell and the checkout opens it from the root, so it carries its own
    // status-bar inset, exactly like Manage Plan.
    return SafeArea(
      top: true,
      bottom: false,
      child: SettingsSubPageModal(
        title: AppLocalizations.of(context).payments_historyTitle,
        child: const SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.edgeMargin,
            AppSpacing.md,
            AppSpacing.edgeMargin,
            AppSpacing.xl,
          ),
          child: SubscriptionHistorySection(showHeading: false),
        ),
      ),
    );
  }
}

/// Purchases and cancellations as one ledger, newest first.
///
/// The section was **Payment History** until cancellation existed; both tables
/// are read together so a plan that was ended is an entry in the same list as
/// the payment that bought it. [showHeading] is false on the screen above,
/// whose AppBar already names it.
class SubscriptionHistorySection extends ConsumerWidget {
  const SubscriptionHistorySection({this.showHeading = true, super.key});

  /// Whether to draw the section's own title above the cards.
  final bool showHeading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeading) ...[
          Text(l.payments_historyTitle, style: AppTypography.titleMd),
          const SizedBox(height: AppSpacing.sm),
        ],
        _SubscriptionHistoryCards(
          l: l,
          submissions: ref.watch(myPaymentSubmissionsProvider),
          cancellations: ref.watch(mySubscriptionCancellationsProvider),
        ),
      ],
    );
  }
}

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
    return SubscriptionCard(
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
    epochMs == 0 ? '—' : formatSubscriptionDateTime(l, epochMs);

