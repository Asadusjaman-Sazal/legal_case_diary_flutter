/// The Admin Panel's **Payment Requests** sub-page: submissions awaiting a
/// decision, and the record of the ones already decided.
///
/// Moved off the panel itself when the panel became a menu of sub-pages (user
/// request), so the screen no longer carries a "Payment Requests" heading — the
/// header names it. Three things were added on the way: each card is numbered
/// within its section, the header's search filters both sections, opening a
/// closed one when it holds a match, and each section's button sticks to the top
/// of the list while the admin scrolls that section's own cards.
///
/// The screen is deliberately thin — it renders what `adminPaymentRequestsProvider`
/// returns and calls two methods on `AdminActionViewModel`. It holds no admin
/// state of its own, because the one question that matters ("is this person an
/// admin at all?") is answered by the server through `adminStatusProvider`.
///
/// Pending starts open and Resolved starts closed, because a resolved submission
/// cannot be acted on and the admin opening this page has work to do.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/utils/date_utils.dart';
import '../../../sync/sync_service.dart';
import '../../payments/data/payment_plans.dart';
import '../../payments/presentation/payment_plan_labels.dart';
import '../../settings/presentation/settings_menu_card.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';
import '../data/admin_repository.dart';
import 'admin_shared.dart';
import 'admin_viewmodel.dart';

/// Payment requests: Pending and Resolved, each collapsible, each numbered.
class AdminPaymentRequestsScreen extends ConsumerStatefulWidget {
  const AdminPaymentRequestsScreen({super.key});

  @override
  ConsumerState<AdminPaymentRequestsScreen> createState() =>
      _AdminPaymentRequestsScreenState();
}

class _AdminPaymentRequestsScreenState
    extends ConsumerState<AdminPaymentRequestsScreen> {
  /// Pending is the section that needs attention, so it starts open and
  /// Resolved — a history, not a to-do — starts closed.
  bool _pendingOpen = true;
  bool _resolvedOpen = false;

  /// Whether the header's search box is showing, and what is typed in it.
  bool _isSearching = false;
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggleSearch() => setState(() {
    _isSearching = !_isSearching;
    if (!_isSearching) {
      _search.clear();
      _query = '';
    }
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final requests = ref.watch(adminPaymentRequestsProvider);
    final action = ref.watch(AdminActionViewModel.provider);

    return SettingsSubPageModal(
      title: l.adminPanel_paymentRequests,
      actions: [
        const AdminSyncButton(),
        IconButton(
          key: const ValueKey('admin-payments-search'),
          icon: const Icon(Icons.search),
          tooltip: l.adminPanel_search,
          onPressed: _toggleSearch,
        ),
      ],
      child: requests.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (_, _) => _LoadFailed(
          onRetry: () => ref.invalidate(adminPaymentRequestsProvider),
        ),
        data: (all) {
          final searching = _query.trim().isNotEmpty;
          final pending = all
              .where((r) => r.isPending && _matches(r))
              .toList(growable: false);
          final resolved = all
              .where((r) => r.isResolved && _matches(r))
              .toList(growable: false);
          if (searching && pending.isEmpty && resolved.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isSearching) _searchField(l),
                AdminNoResults(message: l.adminPanel_noResults),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isSearching) _searchField(l),
              Expanded(
                // Pull to refresh does what the header button does — a forced
                // drain with the delta pull — and then re-reads the
                // submissions, so a payment that landed while the page was
                // open appears without a second trip to Settings.
                child: RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(syncServiceProvider).retryNow();
                    ref.invalidate(adminPaymentRequestsProvider);
                    await ref.read(adminPaymentRequestsProvider.future);
                  },
                  // Slivers, not a ListView, because each section's button has to
                  // hold the top of the list while the admin scrolls its own
                  // cards: the header scrolls away with them otherwise, and after
                  // a few hundred cards there is nothing left saying which
                  // section is on screen.
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        // The band around each section's button supplies its own
                        // `sm` above it, so this keeps the old `md` top edge.
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.edgeMargin,
                          AppSpacing.sm,
                          AppSpacing.edgeMargin,
                          0,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: action.phase != AdminActionPhase.idle
                              ? _ActionBanner(
                                  action: action,
                                  onDismiss: () => ref
                                      .read(
                                        AdminActionViewModel.provider.notifier,
                                      )
                                      .clear(),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                      _RequestSection(
                        icon: Icons.pending_actions,
                        title: l.adminPanel_pending,
                        count: pending.length,
                        // A section holding a match is opened by the search, so a
                        // result is never hidden inside a closed section.
                        open: searching ? pending.isNotEmpty : _pendingOpen,
                        emptyText: searching
                            ? l.adminPanel_noResults
                            : l.adminPanel_emptyPending,
                        children: [
                          for (var i = 0; i < pending.length; i++)
                            _RequestCard(
                              key: ValueKey('admin-request-${pending[i].id}'),
                              request: pending[i],
                              serial: i + 1,
                            ),
                        ],
                        onToggle: () =>
                            setState(() => _pendingOpen = !_pendingOpen),
                      ),
                      // The two bands already contribute a `sm` each, so this
                      // brings the gap between the sections to the old `lg`.
                      const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.md),
                      ),
                      _RequestSection(
                        icon: Icons.task_alt,
                        title: l.adminPanel_resolved,
                        count: resolved.length,
                        open: searching ? resolved.isNotEmpty : _resolvedOpen,
                        emptyText: searching
                            ? l.adminPanel_noResults
                            : l.adminPanel_emptyResolved,
                        // Newest decision first: the admin wants the latest
                        // history, not the oldest, and the server's own order is
                        // by submission time rather than by when it was decided.
                        children: [
                          for (var i = 0; i < resolved.length; i++)
                            _RequestCard(
                              key: ValueKey(
                                'admin-request-${_byDecisionTime(resolved)[i].id}',
                              ),
                              request: _byDecisionTime(resolved)[i],
                              serial: i + 1,
                            ),
                        ],
                        onToggle: () =>
                            setState(() => _resolvedOpen = !_resolvedOpen),
                      ),
                      // The list's own bottom padding, which a CustomScrollView
                      // has no padding for.
                      const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.xl),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _searchField(AppLocalizations l) => AdminSearchField(
    controller: _search,
    hint: l.adminPanel_searchHint,
    onChanged: (value) => setState(() => _query = value),
    onClose: _toggleSearch,
  );

  /// Whether one card matches the query on any text it shows.
  bool _matches(AdminPaymentRequest request) => adminTextMatches(_query, [
    request.fullName,
    request.email,
    request.transactionId,
    request.senderNumber,
    request.mobileNo,
    request.barAssociation,
    request.membershipNo,
    request.status,
  ]);

  /// Resolved submissions newest-decision-first; approvals before rejections
  /// within one instant, so a same-millisecond pair is still deterministic.
  static List<AdminPaymentRequest> _byDecisionTime(
    List<AdminPaymentRequest> resolved,
  ) {
    final ordered = [...resolved];
    ordered.sort((a, b) {
      final byTime = _decidedAt(b).compareTo(_decidedAt(a));
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return ordered;
  }

  static DateTime _decidedAt(AdminPaymentRequest r) =>
      r.approvedAt ?? r.rejectedAt ?? r.submittedAt ?? DateTime(1970);
}

/// The one-line outcome of the last approve/reject, or why it failed.
class _ActionBanner extends StatelessWidget {
  final AdminActionState action;
  final VoidCallback onDismiss;

  const _ActionBanner({required this.action, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isFailure = action.phase == AdminActionPhase.failure;
    final message = switch (action.phase) {
      AdminActionPhase.success =>
        action.failure == null ? l.adminPanel_approved : l.adminPanel_rejected,
      AdminActionPhase.failure => switch (action.failure) {
        AdminActionFailure.notAnAdmin => l.adminPanel_failedNotAdmin,
        AdminActionFailure.notFound => l.adminPanel_failedNotFound,
        AdminActionFailure.alreadyResolved =>
          l.adminPanel_failedAlreadyResolved,
        AdminActionFailure.unexpected => l.adminPanel_failedUnexpected,
        null => l.adminPanel_failedUnexpected,
      },
      _ => '',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: isFailure
            ? AppColors.errorContainer
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Row(
            children: [
              Icon(
                isFailure ? Icons.error_outline : Icons.check_circle,
                size: 18,
                color: isFailure
                    ? AppColors.onErrorContainer
                    : AppColors.success,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.bodySm.copyWith(
                    color: isFailure
                        ? AppColors.onErrorContainer
                        : AppColors.onSurface,
                  ),
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A collapsible Pending / Resolved section, headed by a Settings sub-menu
/// button that **sticks to the top of the list** for as long as the section's
/// own cards are on screen.
///
/// The button and its cards are wrapped in a single [SliverMainAxisGroup], which
/// is what scopes the stickiness to the section: the button holds the top of the
/// list while that section's cards are being read, then travels up and out as
/// the next section's button arrives in its place. (Pinned headers placed side
/// by side in a scroll view pile up at the top instead — they would all stay on
/// screen at once — so the group is what makes the handover work. The case
/// screens' court headings pin the same way.)
class _RequestSection extends StatelessWidget {
  /// Leading icon of the header button.
  final IconData icon;
  final String title;
  final int count;

  /// Whether the section is expanded; driven by the screen so the card is the
  /// single control that toggles it.
  final bool open;
  final String emptyText;
  final List<Widget> children;

  /// Called when the header button is tapped.
  final VoidCallback onToggle;

  const _RequestSection({
    required this.icon,
    required this.title,
    required this.count,
    required this.open,
    required this.emptyText,
    required this.children,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SliverMainAxisGroup(
      slivers: [
        PinnedHeaderSliver(
          // The band paints the page background across the list's full width,
          // which keeps the cards sliding underneath it out of sight while it is
          // pinned, and insets the button to the gutter the list uses. The `sm`
          // below it is the gap the cards had before the button was pinned.
          child: ColoredBox(
            color: AppColors.background,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.edgeMargin,
                vertical: AppSpacing.sm,
              ),
              child: SettingsMenuCard(
                icon: icon,
                title: title,
                onTap: onToggle,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.adminPanel_sectionCount(
                        AppDateUtils.formatDigits(count, l.localeName),
                      ),
                      style: AppTypography.bodySm,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // A closed section contributes its button only, so the next section's
        // button comes straight up to the top behind it. The reveal animates so
        // the list below does not jump when a section opens under the reader's
        // thumb.
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.edgeMargin,
          ),
          sliver: SliverToBoxAdapter(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: open ? _body(l) : const SizedBox(width: double.infinity),
            ),
          ),
        ),
      ],
    );
  }

  /// The revealed list: the empty note, or the requests separated by the same
  /// hairline the Settings lists use, inside a bordered surface that matches the
  /// header card's radius.
  Widget _body(AppLocalizations l) => Container(
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(settingsMenuCardRadius),
      border: Border.all(color: AppColors.outlineVariant),
    ),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    child: children.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(emptyText, style: AppTypography.bodySm),
          )
        : Column(
            children: [
              // Hairline between rows, exactly as the Settings main screen
              // separates its list tiles.
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.outlineVariant,
                  ),
                children[i],
              ],
            ],
          ),
  );
}

/// One payment request: who paid, what they paid for, and — while it is pending
/// — the two decisions an admin may take. Numbered within its section.
class _RequestCard extends ConsumerWidget {
  final AdminPaymentRequest request;

  /// The card's position in its section, counting from 1.
  final int serial;

  const _RequestCard({required this.request, required this.serial, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final action = ref.watch(AdminActionViewModel.provider);
    final isThisOne = action.actedOn == request.id;
    final busy = isThisOne && action.isRunning;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The number the admin reads down the list. A plain number, as
              // asked — the section's own header already carries the count.
              SizedBox(
                width: 28,
                child: Text(
                  AppDateUtils.formatDigits(
                    serial,
                    l.localeName,
                    grouping: false,
                  ),
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  request.fullName.isEmpty
                      ? l.adminPanel_noValue
                      : request.fullName,
                  style: AppTypography.titleMd,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _StatusChip(status: request.status),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            adminPaymentPlanAndAmount(l, request),
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // The sender's number is a number, not an amount, so it carries no
          // `৳` — the plan line above is the only place an amount appears.
          Text(
            request.senderNumber.isEmpty
                ? l.adminPanel_noValue
                : request.senderNumber,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _DetailLine(
            label: l.adminPanel_detailLabelTrx,
            value: request.transactionId,
          ),
          _DetailLine(
            label: l.adminPanel_detailLabelMfs,
            value: adminPaymentMethodLabel(l, request.mfsProvider),
          ),
          _DetailLine(
            label: l.adminPanel_detailLabelName,
            value: request.fullName,
          ),
          _DetailLine(
            label: l.adminPanel_detailLabelEmail,
            value: request.email,
          ),
          _DetailLine(
            label: l.adminPanel_detailLabelBar,
            value: request.barAssociation,
          ),
          _DetailLine(
            label: l.adminPanel_detailLabelMembership,
            value: request.membershipNo,
          ),
          _DetailLine(
            label: l.adminPanel_detailLabelMobile,
            value: request.mobileNo,
          ),
          _DetailLine(
            label: l.adminPanel_detailLabelSubmitted,
            value: adminPanelDate(l, request.submittedAt),
          ),
          if (request.isResolved) ...[
            if (request.approvedAt != null)
              _DetailLine(
                label: l.adminPanel_approvedExpiry,
                value: adminPanelDate(l, request.approvedNewExpiry),
              ),
            if ((request.adminNotes ?? '').isNotEmpty)
              _DetailLine(
                label: l.adminPanel_detailLabelNote,
                value: request.adminNotes!,
              ),
          ],
          if (request.isPending) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => _confirmReject(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      textStyle: AppTypography.labelLg,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.sheetRadius,
                        ),
                      ),
                    ),
                    child: Text(l.adminPanel_reject),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () => ref
                              .read(AdminActionViewModel.provider.notifier)
                              .approve(request.id),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      textStyle: AppTypography.labelLg,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.sheetRadius,
                        ),
                      ),
                    ),
                    child: Text(l.adminPanel_approve),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Asks for the note and rejects. A rejection is a decision the payer may
  /// query, so it is confirmed rather than fired from one tap.
  Future<void> _confirmReject(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _RejectNoteDialog(l: l),
    );
    if (note == null) return;
    final trimmed = note.trim();
    await ref
        .read(AdminActionViewModel.provider.notifier)
        .reject(request.id, note: trimmed.isEmpty ? null : trimmed);
  }
}

/// The rejection window: an optional note for the payer, and a Cancel that does
/// nothing at all.
class _RejectNoteDialog extends StatefulWidget {
  final AppLocalizations l;

  const _RejectNoteDialog({required this.l});

  @override
  State<_RejectNoteDialog> createState() => _RejectNoteDialogState();
}

class _RejectNoteDialogState extends State<_RejectNoteDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    return AlertDialog(
      title: Text(l.adminPanel_rejectTitle),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: l.adminPanel_rejectNoteLabel,
          hintText: l.adminPanel_rejectNoteHint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.sharedActions_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.onError,
          ),
          child: Text(l.adminPanel_rejectConfirm),
        ),
      ],
    );
  }
}

/// One label/value line, rendered only when there is a value worth showing.
class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final shown = value.isEmpty ? l.adminPanel_noValue : value;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        l.adminPanel_detailLabel(label, shown),
        style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
      ),
    );
  }
}

/// Pending / Approved / Rejected, coloured by outcome.
class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (label, color) = switch (status) {
      'approved' => (l.adminPanel_statusApproved, AppColors.success),
      'rejected' => (l.adminPanel_statusRejected, AppColors.error),
      _ => (l.adminPanel_statusPending, AppColors.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.radiusSm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(label, style: AppTypography.labelMd.copyWith(color: color)),
    );
  }
}

/// Shown when the list could not be loaded, with the one thing that can help.
class _LoadFailed extends StatelessWidget {
  final VoidCallback onRetry;

  const _LoadFailed({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AdminLoadFailed(
      message: l.adminPanel_loadFailed,
      retryLabel: l.adminPanel_retry,
      onRetry: onRetry,
    );
  }
}

/// The localized brand of one MFS provider, so the admin reads "bKash" rather
/// than the stored `bkash` key.
///
/// Top-level rather than private to the card: the search matches on it too, so
/// the two cannot disagree about what a card says.
String adminPaymentMethodLabel(AppLocalizations l, String provider) =>
    switch (provider) {
      'bkash' => l.payments_methodBkash,
      'nagad' => l.payments_methodNagad,
      'rocket' => l.payments_methodRocket,
      _ => provider,
    };

/// "৳960 per year" — the plan's own name plus its bare amount, worded by the
/// same helpers the paywall uses so the two never disagree.
String adminPaymentPlanAndAmount(
  AppLocalizations l,
  AdminPaymentRequest request,
) {
  final plan = subscriptionPlans.firstWhere(
    (p) => p.key == request.planKey,
    orElse: () => subscriptionPlans.first,
  );
  final amount = l.payments_amountValue(
    AppDateUtils.formatDigits(request.amount, l.localeName),
  );
  return '${paymentPlanLabel(l, plan.key)} · $amount';
}
