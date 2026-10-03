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
/// **Payment History** is a table — number, plan, paid, when, status — rather
/// than the loose rows the sheet drew, because it is a ledger a user reconciles
/// against a bank or MFS statement. It scrolls sideways rather than wrapping,
/// so the columns stay in their positions instead of drifting as a date grows.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/utils/date_utils.dart';
import '../../accounts_and_profile/data/account_mode.dart';
import '../../accounts_and_profile/data/profile_repository.dart';
import '../../payments/data/payment_repository.dart';
import '../../payments/presentation/payment_plan_labels.dart';
import 'settings_sub_page_modal.dart';

/// Fixed column widths, in logical pixels.
///
/// The table is wider than a narrow phone on purpose: a wrapped date column
/// would put every row's baseline somewhere different, and a ledger whose
/// columns do not line up cannot be scanned. Scrolling sideways keeps the grid.
const double _serialColumnWidth = 34;
const double _paidColumnWidth = 74;
const double _dateColumnWidth = 132;
const double _statusColumnWidth = 92;

/// The Subscription Details sub-page.
class SubscriptionDetailsScreen extends ConsumerWidget {
  /// Creates the screen.
  const SubscriptionDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);

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
    final premium = ref.watch(premiumAccessProvider);
    // Whether an answer of "free" is the account's plan or merely the gap left
    // before the profile pull lands. A premium user who signed in a moment ago
    // must not read Free while the expiry beside it already names a date.
    final entitlementKnown = ref.watch(entitlementKnownProvider);

    // The firm's expiry is the source of truth for a member; an individual's is
    // their own. Exactly the split `resolvePremiumAccess` uses.
    final expiryMs = profile?.firmId == null
        ? profile?.subscriptionExpiry
        : firm?.subscriptionExpiry;

    // The active paid plan is named by the latest approved submission. With no
    // approval there is no paid plan to name — a member riding on the firm's
    // subscription is Premium without a submission of their own, which is the
    // case the word *Premium* exists for rather than a repeated tier name.
    final approved = (ref.watch(myPaymentSubmissionsProvider).value ??
            const <PaymentSubmission>[])
        .where((s) => s.status == 'approved')
        .toList(growable: false);

    final String currentPlan;
    if (premium.isLoading || !entitlementKnown) {
      currentPlan = '—';
    } else if (premium.value ?? false) {
      currentPlan = approved.isEmpty
          ? l.settingsManageAccount_planPremium
          : paymentPlanLabel(l, approved.first.planType);
    } else {
      currentPlan = l.settingsManageAccount_planFree;
    }

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
          ),
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
        _Card(child: _PaymentHistoryTable(l: l, async: async)),
      ],
    );
  }
}

/// The ledger table itself: a header row and one row per purchase.
class _PaymentHistoryTable extends StatelessWidget {
  const _PaymentHistoryTable({required this.l, required this.async});

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
        return _ScrollableTable(
          header: _TableRow(
            header: true,
            cells: <Widget>[
              _HeaderCell(l.settingsSubscription_serial, width: _serialColumnWidth),
              _HeaderCell(l.settingsManageAccount_plan),
              _HeaderCell(
                l.settingsSubscription_paid,
                width: _paidColumnWidth,
              ),
              _HeaderCell(
                l.settingsSubscription_dateTime,
                width: _dateColumnWidth,
              ),
              _HeaderCell(
                l.settingsSubscription_status,
                width: _statusColumnWidth,
              ),
            ],
          ),
          rows: [
            for (var i = 0; i < rows.length; i++)
              _TableRow(
                cells: <Widget>[
                  _BodyCell('${i + 1}.', width: _serialColumnWidth),
                  _BodyCell(paymentPlanLabel(l, rows[i].planType)),
                  _BodyCell(
                    l.payments_amountValue(
                      AppDateUtils.formatDigits(rows[i].amount, l.localeName),
                    ),
                    width: _paidColumnWidth,
                  ),
                  _BodyCell(
                    _submittedAtLabel(l, rows[i]),
                    width: _dateColumnWidth,
                  ),
                  _StatusCell(status: rows[i].status, width: _statusColumnWidth),
                ],
              ),
          ],
        );
      },
    );
  }
}

/// One table row: a hairline under every row but the last.
class _TableRow extends StatelessWidget {
  const _TableRow({required this.cells, this.header = false});

  final List<Widget> cells;
  final bool header;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: header
          ? const BoxDecoration(
              color: AppColors.surfaceContainerLow,
              border: Border(
                bottom: BorderSide(color: AppColors.outlineVariant),
              ),
            )
          : null,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.gutter,
      ),
      child: Row(children: cells),
    );
  }
}

/// A header cell.
class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text, {this.width});

  final String text;
  final double? width;

  @override
  Widget build(BuildContext context) => _Cell(
        width: width,
        child: Text(
          text,
          style: AppTypography.labelMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
}

/// A body cell.
class _BodyCell extends StatelessWidget {
  const _BodyCell(this.text, {this.width});

  final String text;
  final double? width;

  @override
  Widget build(BuildContext context) => _Cell(
        width: width,
        child: Text(
          text,
          style: AppTypography.bodyMd,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
}

/// The status cell, which is a pill rather than bare text so a row can be
/// scanned for the one that still needs attention.
class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.status, required this.width});

  final String status;
  final double width;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (label, color) = switch (status) {
      'approved' => (l.payments_statusApproved, AppColors.success),
      'rejected' => (l.payments_statusRejected, AppColors.error),
      _ => (l.payments_statusPending, AppColors.secondary),
    };
    return _Cell(
      width: width,
      child: Container(
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
      ),
    );
  }
}

/// A table cell: fixed width where the column is fixed, intrinsic where the plan
/// name is the long one.
class _Cell extends StatelessWidget {
  const _Cell({required this.child, this.width});

  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: child,
          ),
        ),
      );
}

/// A table that keeps its columns and scrolls sideways when a phone is narrower
/// than the ledger needs.
class _ScrollableTable extends StatelessWidget {
  const _ScrollableTable({required this.header, required this.rows});

  final Widget header;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            for (var i = 0; i < rows.length; i++)
              Container(
                decoration: BoxDecoration(
                  border: i == rows.length - 1
                      ? null
                      : const Border(
                          bottom: BorderSide(color: AppColors.outlineVariant),
                        ),
                ),
                child: rows[i],
              ),
          ],
        ),
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
            Expanded(
              child: Text(
                label,
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Flexible(
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

/// The moment a submission was made, in Bangladesh civil time.
String _submittedAtLabel(AppLocalizations l, PaymentSubmission submission) {
  final at = submission.submittedAt;
  if (at == null) return '—';
  return _dateAndTime(l, at.millisecondsSinceEpoch);
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
