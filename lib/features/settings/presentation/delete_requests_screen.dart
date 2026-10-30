/// Delete requests screen: the reviewer's queue, or the requester's own list.
///
/// Task 20 Phase 4's notification surface, reached from Settings > Delete
/// Requests. Which of the two lists this screen shows is not a choice the screen
/// makes: a member with delete permission *reviews* (the pending queue), and a
/// member without it *asks* (their own requests and the reviewer's decision on
/// each). The two are mutually exclusive in practice — somebody who may delete
/// deletes directly and never raises a request — so this is one screen with two
/// voices rather than two screens nobody can both reach.
///
/// Both lists come from the same live local stream. The reviewer's row opens
/// [DeleteRequestReviewScreen] where the decision is actually made, and a long
/// press expands it in place to the same **Approve** and **Reject** pair, in one
/// line, for a quick decision (user request, 0.0.689); a stale request, whose
/// record moved, keeps the trip to the review screen, because approving it
/// blindly would judge a version nobody has seen.
///
/// The requester's own pending row expands on tap to a single red **Withdraw
/// Request** button on the right (user request); the old actions sheet — Edit
/// Request and Withdraw Request — is gone with the chevron, which promised a
/// screen the tap never opened.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/date_utils.dart';
import '../../../database/app_database.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_dialog_actions.dart';
import '../../accounts_and_profile/data/account_mode.dart';
import '../../auth/presentation/auth_viewmodel.dart';
import '../../auth/presentation/auth_widgets.dart';
import 'delete_request_review_screen.dart';
import 'delete_requests_viewmodel.dart';
import 'settings_controls.dart';
import 'settings_menu_card.dart' show settingsPrimaryButtonHeight;
import 'settings_sub_page_modal.dart';

/// The Delete Requests list: a reviewer's queue or a requester's own requests.
class DeleteRequestsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const DeleteRequestsScreen({super.key});

  @override
  ConsumerState<DeleteRequestsScreen> createState() =>
      _DeleteRequestsScreenState();
}

class _DeleteRequestsScreenState extends ConsumerState<DeleteRequestsScreen> {
  /// The row whose actions are showing; one at a time keeps the list readable.
  String? _expandedId;

  /// The row a quick decision is being written for, so it cannot be tapped twice.
  String? _busyId;

  /// Previous rows hidden from this screen only — nothing is written back to
  /// the request or the record (user request).
  final Set<String> _clearedPrevious = <String>{};

  /// The previous rows ticked for a bulk clear, and whether a long press put
  /// that section into selection mode.
  final Set<String> _selectedPrevious = <String>{};
  bool _selectingPrevious = false;

  /// Records that the reviewer's decisions on this account's requests have been
  /// read, so the Settings badge stops counting them.
  ///
  /// Called from [build] rather than `initState` because the decisions arrive
  /// with the stream a frame or two later: at `initState` time there is nothing
  /// to read yet, and marking then would silence the very badge this screen was
  /// opened to answer. Marking writes state, so it is deferred to after the
  /// frame; the resulting empty list stops the next build from scheduling it
  /// again.
  Future<void> _markDecisionsSeen(List<DeleteRequest> unseen) async {
    if (!mounted) return;
    await ref
        .read(deleteRequestsSeenProvider.notifier)
        .markSeen(
          unseen
              .map((request) => request.updatedAt)
              .reduce((a, b) => a > b ? a : b),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final signedIn = ref.watch(authIdentityProvider) != null;
    final firm = ref.watch(firmModeProvider);
    final reviewer = ref.watch(canDeleteDirectlyProvider);

    // Opening this screen is what "reading" a decision means.
    final unseen = ref.watch(deleteRequestsUnseenProvider);
    if (unseen.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _markDecisionsSeen(unseen),
      );
    }

    final Widget body;
    if (!signedIn) {
      body = _MessageBody(l.sharedMessages_signInRequired);
    } else if (!firm) {
      // An individual owns their own diary, so there is nobody to ask and
      // nothing to review; the Settings entry is not shown for them either.
      body = _MessageBody(l.deleteRequests_firmOnly);
    } else if (reviewer) {
      body = _queueBody(l);
    } else {
      body = _mineBody(l);
    }

    return SettingsSubPageModal(title: l.deleteRequests_title, child: body);
  }

  /// The reviewer's list: every request still waiting on a decision, and — for
  /// the firm's owner only — the requests already finished (user request).
  Widget _queueBody(AppLocalizations l) {
    final queue = ref.watch(deleteReviewQueueProvider);
    // The owner is the one who manages the chamber's queue; another reviewer
    // (an associate with delete permission) keeps the queue alone.
    final isOwner = !ref.watch(firmMemberProvider);
    final previous = isOwner
        ? ref.watch(previousDeleteRequestsProvider)
        : const <DeleteRequest>[];
    final visiblePrevious = previous
        .where((request) => !_clearedPrevious.contains(request.id))
        .toList(growable: false);
    final locale = Localizations.localeOf(context).toString();

    final list = ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.edgeMargin,
        AppSpacing.md,
        AppSpacing.edgeMargin,
        AppSpacing.xl,
      ),
      children: [
        SettingsSectionLabel(l.deleteRequests_toReview),
        const SizedBox(height: AppSpacing.sm),
        if (queue.isEmpty)
          _InfoRow(text: l.deleteRequests_noneToReview)
        else
          for (final request in queue) ...[
            _RequestRow(
              request: request,
              l: l,
              locale: locale,
              showStatusChip: false,
              // Who asked, in place of the date (user request): the question a
              // queued request puts to its reviewer is *who wants this gone*.
              requesterName: _requesterName(request, l),
              // The owner reads when it was raised as a third line, exactly as
              // the finished cards below show it (user request, 0.0.721).
              thirdLine: isOwner
                  ? AppDateUtils.formatDateTimeDDMMYYYY(
                      request.createdAt,
                      locale: locale,
                    )
                  : null,
              expanded: _expandedId == request.id,
              // A stale request's record moved: quick approval would judge a
              // version nobody has seen, so it keeps the review-screen trip.
              onLongPress: request.status == 'pending'
                  ? () => _toggleExpanded(request.id)
                  : null,
              actions: request.status == 'pending'
                  ? _reviewActions(request, l)
                  : null,
              onTap: () =>
                  context.push(AppRoutes.deleteRequestReviewPath(request.id)),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        if (visiblePrevious.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          SettingsSectionLabel(l.deleteRequests_previous),
          const SizedBox(height: AppSpacing.sm),
          for (final request in visiblePrevious) ...[
            _RequestRow(
              request: request,
              l: l,
              locale: locale,
              // A finished request is audit history: it keeps its outcome pill,
              // the requester's name and the moment it was raised, and it offers
              // no review screen. A tap shows its Clear action; a long press
              // starts the section's bulk clear (user request).
              showStatusChip: true,
              showChevron: false,
              requesterName: _requesterName(request, l),
              thirdLine: AppDateUtils.formatDateTimeDDMMYYYY(
                request.createdAt,
                locale: locale,
              ),
              selected: _selectedPrevious.contains(request.id),
              expanded: !_selectingPrevious && _expandedId == request.id,
              actions: !_selectingPrevious && _expandedId == request.id
                  ? _clearPreviousAction(request, l)
                  : null,
              onTap: _selectingPrevious
                  ? () => _togglePreviousSelected(request.id)
                  : () => _toggleExpanded(request.id),
              onLongPress: () => _startPreviousSelection(request.id),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ],
    );
    // While the section is selecting, its two actions are pinned under the
    // list instead of scrolling with it (user request): Cancel on the left,
    // Clear Selected on the right.
    if (!_selectingPrevious) return list;
    return Column(
      children: [
        Expanded(child: list),
        _previousSelectionBar(l),
      ],
    );
  }

  /// The bulk clear's two actions, pinned to the bottom while selecting.
  Widget _previousSelectionBar(AppLocalizations l) => Container(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.edgeMargin,
      AppSpacing.sm,
      AppSpacing.edgeMargin,
      AppSpacing.md,
    ),
    decoration: BoxDecoration(
      color: AppColors.background,
      border: Border(top: BorderSide(color: AppColors.outlineVariant)),
    ),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: const ValueKey('delete-request-clear-cancel'),
            onPressed: _exitPreviousSelection,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(settingsPrimaryButtonHeight),
              textStyle: AppTypography.titleMd,
            ),
            child: Text(l.sharedActions_cancel),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: FilledButton(
            key: const ValueKey('delete-request-clear-selected'),
            onPressed: _selectedPrevious.isEmpty
                ? null
                : _clearSelectedPrevious,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
              textStyle: AppTypography.titleMd,
              minimumSize: const Size.fromHeight(settingsPrimaryButtonHeight),
            ),
            child: Text(l.deleteRequests_clearSelected),
          ),
        ),
      ],
    ),
  );

  /// Who asked for one queued request.
  ///
  /// Read exactly as the review screen reads it: the name the request carries
  /// (the server derives it from `profiles`, and the requester's own phone
  /// writes it on the way out), else this device's own profile cache for that
  /// account, else the neutral label — so the row needs no network read and
  /// never invents a name.
  String _requesterName(DeleteRequest request, AppLocalizations l) {
    final stored = request.requesterName?.trim() ?? '';
    if (stored.isNotEmpty) return stored;
    final cached = ref
        .watch(deleteRequestRequesterNameProvider(request.requestedBy))
        .value;
    final name = cached?.trim() ?? '';
    return name.isEmpty ? l.deleteRequests_unknownRequester : name;
  }

  /// The requester's list: their own requests and what the reviewer decided.
  ///
  /// A **pending** request is still the requester's own to withdraw, so its card
  /// expands on tap to one red button; a decided one is audit history and stays
  /// a plain row that only shows the outcome.
  Widget _mineBody(AppLocalizations l) {
    final mine = ref.watch(myDeleteRequestsProvider);
    final locale = Localizations.localeOf(context).toString();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.edgeMargin,
        AppSpacing.md,
        AppSpacing.edgeMargin,
        AppSpacing.xl,
      ),
      children: [
        SettingsSectionLabel(l.deleteRequests_mine),
        const SizedBox(height: AppSpacing.sm),
        if (mine.isEmpty)
          _InfoRow(text: l.deleteRequests_noneMine)
        else
          for (final request in mine) ...[
            _RequestRow(
              request: request,
              l: l,
              locale: locale,
              // The requester's own list names the state of every row, because
              // both kinds sit in it; the reviewer's queue does not need to.
              showStatusChip: true,
              // The card expands rather than opening a screen, so no chevron
              // promises one (user request, 0.0.689).
              showChevron: false,
              // The record moved under their request, as this device can tell.
              changed:
                  ref
                      .watch(deleteRequestTargetChangedProvider(request.id))
                      .value ??
                  false,
              expanded: _expandedId == request.id,
              actions: request.status == 'pending'
                  ? _withdrawAction(request, l)
                  : null,
              onTap: request.status == 'pending'
                  ? () => _toggleExpanded(request.id)
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }

  /// Expands one row, or collapses it when it is the open one.
  void _toggleExpanded(String id) {
    setState(() => _expandedId = _expandedId == id ? null : id);
  }

  /// A long press starts the previous section's bulk clear with this row ticked.
  void _startPreviousSelection(String id) {
    setState(() {
      _expandedId = null;
      _selectingPrevious = true;
      _selectedPrevious.add(id);
    });
  }

  /// Ticks or un-ticks one previous row while the section is selecting.
  ///
  /// Un-ticking the last ticked row ends selection mode, so the section
  /// returns to normal without a second tap (user request, 0.0.720).
  void _togglePreviousSelected(String id) {
    setState(() {
      if (!_selectedPrevious.remove(id)) {
        _selectedPrevious.add(id);
        return;
      }
      if (_selectedPrevious.isEmpty) _selectingPrevious = false;
    });
  }

  /// Leaves the bulk clear without hiding anything.
  void _exitPreviousSelection() {
    setState(() {
      _selectingPrevious = false;
      _selectedPrevious.clear();
    });
  }

  /// Hides every ticked previous row from this screen; no request or record is
  /// touched (user request).
  void _clearSelectedPrevious() {
    setState(() {
      _clearedPrevious.addAll(_selectedPrevious);
      _selectedPrevious.clear();
      _selectingPrevious = false;
    });
  }

  /// One previous row's Clear action: the Withdraw Request button's shape, and
  /// it hides the row from this screen only (user request).
  Widget _clearPreviousAction(DeleteRequest request, AppLocalizations l) =>
      FilledButton(
        key: ValueKey('delete-request-clear-${request.id}'),
        onPressed: () => setState(() {
          _expandedId = null;
          _clearedPrevious.add(request.id);
        }),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: AppColors.onError,
          textStyle: AppTypography.titleMd,
          minimumSize: const Size.fromHeight(settingsPrimaryButtonHeight),
        ),
        child: Text(l.deleteRequests_clear),
      );

  /// The reviewer's quick decision: the review screen's pair, side by side.
  Widget _reviewActions(DeleteRequest request, AppLocalizations l) {
    final busy = _busyId == request.id;
    return Row(
      children: [
        Expanded(
          child: _QuickButton(
            key: ValueKey('delete-request-approve-${request.id}'),
            icon: Icons.delete_outline,
            label: l.deleteRequests_approve,
            // Approving deletes data, so it wears the error colour, as on the
            // review screen.
            destructive: true,
            onPressed: busy
                ? null
                : () => _decideFromRow(request, approve: true),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _QuickButton(
            key: ValueKey('delete-request-reject-${request.id}'),
            icon: Icons.close,
            label: l.deleteRequests_reject,
            onPressed: busy
                ? null
                : () => _decideFromRow(request, approve: false),
          ),
        ),
      ],
    );
  }

  /// The requester's one action, full width at the Settings button height —
  /// the same box as the reviewer's Approve, in the app's red (user request,
  /// 0.0.691).
  Widget _withdrawAction(DeleteRequest request, AppLocalizations l) =>
      FilledButton(
        key: ValueKey('delete-request-withdraw-${request.id}'),
        onPressed: () => _withdrawRequest(request),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: AppColors.onError,
          textStyle: AppTypography.titleMd,
          minimumSize: const Size.fromHeight(settingsPrimaryButtonHeight),
        ),
        child: Text(l.deleteRequests_withdraw),
      );

  /// Decides one request without leaving the list.
  ///
  /// The confirmation is the review screen's own, because an approval deletes
  /// the record for the whole firm; the optional review note, which needs that
  /// screen's box, is the only part left out of the quick path.
  Future<void> _decideFromRow(
    DeleteRequest request, {
    required bool approve,
  }) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _confirmDecision(
      context: context,
      title: approve
          ? l.deleteRequests_approveTitle
          : l.deleteRequests_rejectTitle,
      body: approve
          ? l.deleteRequests_approveBody
          : l.deleteRequests_rejectBody,
      confirmLabel: approve
          ? l.deleteRequests_approve
          : l.deleteRequests_reject,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyId = request.id);
    try {
      final viewModel = ref.read(deleteRequestsViewModelProvider.notifier);
      if (approve) {
        await viewModel.approve(request.id);
      } else {
        await viewModel.reject(request.id);
      }
      if (mounted) setState(() => _expandedId = null);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            approve ? l.deleteRequests_approved : l.deleteRequests_rejected,
          ),
        ),
      );
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l.deleteRequests_failed)));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  /// Withdraws the request, after confirming it.
  Future<void> _withdrawRequest(DeleteRequest request) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _confirmWithdraw(context, l);
    if (!confirmed || !mounted) return;
    final withdrawn = await _write(
      () =>
          ref.read(deleteRequestsViewModelProvider.notifier).cancel(request.id),
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          withdrawn
              ? l.deleteRequests_withdrawn
              : l.deleteRequests_withdrawFailed,
        ),
      ),
    );
  }

  /// Runs one action and reports whether it changed anything.
  ///
  /// A refused write (the request was decided on another device) and a failed
  /// one (the record is gone, or the queue refused the mutation) both leave the
  /// list exactly as it was; the caller words them as "nothing happened" rather
  /// than inventing an error surface for a screen that has no room for one.
  Future<bool> _write(Future<bool> Function() action) async {
    try {
      return await action();
    } on Object {
      return false;
    }
  }
}

/// One request as a row: what it is, who asked (or when), and its state.
///
/// A row with [actions] expands: the card keeps its own line and grows a footer
/// with those actions, right-aligned, so a quick decision never covers the user
/// and the record the request names (user request, 0.0.689).
class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.request,
    required this.l,
    required this.locale,
    required this.onTap,
    required this.showStatusChip,
    this.requesterName,
    this.changed = false,
    this.onLongPress,
    this.expanded = false,
    this.actions,
    this.showChevron = true,
    this.selected = false,
    this.thirdLine,
  });

  final DeleteRequest request;
  final AppLocalizations l;
  final String locale;

  /// Who asked, when the row should name them instead of dating the request.
  ///
  /// The reviewer's queue passes it (user request); the requester's own list
  /// leaves it null and keeps the date, because their own name would tell them
  /// nothing they do not already know, and the date orders their list.
  final String? requesterName;

  /// Opens the row's destination: a review, or the expanded card itself. Null
  /// on a row that has nothing left to do.
  final VoidCallback? onTap;

  /// Opens the card's quick actions on a long press. The reviewer's queue only.
  final VoidCallback? onLongPress;

  /// Whether the action footer is showing.
  final bool expanded;

  /// The card's footer, drawn when [expanded]. Null on a row with no actions.
  final Widget? actions;

  /// Whether a tappable row draws the chevron. False where the tap expands the
  /// card instead of opening a screen, so the icon never promises one.
  final bool showChevron;

  /// Whether the row carries its state as a pill. The requester's own list does,
  /// because pending and decided rows sit in it side by side; the reviewer's
  /// queue does not — everything in it is pending by definition.
  final bool showStatusChip;

  /// Whether the record has changed since the request was made, as far as this
  /// device can tell. Only the requester's own list passes a true value.
  final bool changed;

  /// Whether the row is ticked in the previous section's bulk clear.
  final bool selected;

  /// A third line under the entity/requester line, drawn as given (the previous
  /// section passes the request's date and time, with no label).
  final String? thirdLine;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                ),
                child: Icon(
                  selected ? Icons.check_circle : Icons.delete_outline,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deleteRequestSummary(request, l),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyLg,
                    ),
                    Text(
                      [
                        deleteRequestEntityLabel(l, request.entityType),
                        // The reviewer's queue names the person; every other row
                        // dates the request.
                        requesterName ??
                            AppDateUtils.formatDateDDMMYYYY(
                              request.createdAt,
                              locale: locale,
                            ),
                      ].join(' \u00b7 '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    if (thirdLine != null)
                      Text(
                        thirdLine!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    if (changed)
                      Text(
                        l.deleteRequests_changed,
                        key: const ValueKey('delete-request-changed'),
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (showStatusChip)
                _StatusChip(label: _statusLabel(l, request.status)),
              // A tappable row says so; a static one has nothing more to add.
              if (onTap != null && showChevron)
                const Icon(Icons.chevron_right, color: AppColors.outline),
            ],
          ),
        ),
        if (expanded && actions != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: actions,
          ),
      ],
    );

    if (onTap == null && onLongPress == null) {
      return Container(decoration: settingsCardDecoration(), child: content);
    }
    return Material(
      color: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('delete-request-row-${request.id}'),
        onTap: onTap,
        onLongPress: onLongPress,
        child: content,
      ),
    );
  }
}

/// One of the reviewer's quick decisions, styled as its review-screen twin.
class _QuickButton extends StatelessWidget {
  const _QuickButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 20),
    label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    style: FilledButton.styleFrom(
      backgroundColor: destructive ? AppColors.error : AppColors.primary,
      foregroundColor: destructive ? AppColors.onError : AppColors.onPrimary,
      textStyle: AppTypography.titleMd,
      minimumSize: const Size.fromHeight(settingsPrimaryButtonHeight),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
    ),
  );
}

/// The quick decision's confirmation, the review screen's own window.
Future<bool> _confirmDecision({
  required BuildContext context,
  required String title,
  required String body,
  required String confirmLabel,
}) {
  return showAppConfirmDialog(
    context,
    title: title,
    message: body,
    cancelLabel: AppLocalizations.of(context).sharedActions_cancel,
    confirmLabel: confirmLabel,
    confirmKey: const ValueKey('delete-request-quick-confirm'),
  );
}

/// The withdrawal window.
///
/// A confirmation rather than a plain tap because a withdrawal cannot be undone
/// — the requester would have to raise the request again and the reviewer would
/// see a new one. It takes the shared pop-over frame (8 px corner, 112 x 48 /
/// 16 pt actions) with a centred title and a justified body; on a narrow phone
/// the pair becomes two full-width buttons instead of wrapping at their
/// intrinsic sizes (user request, 0.0.694).
Future<bool> _confirmWithdraw(BuildContext context, AppLocalizations l) async {
  final answer = await showAppDialog<bool>(
    context,
    // 5% wider than the default 40 px inset on the app's phones
    // (user request, 0.0.693).
    insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
    title: Text(l.deleteRequests_withdrawTitle, textAlign: TextAlign.center),
    content: Text(l.deleteRequests_withdrawBody, textAlign: TextAlign.justify),
    actions: (dialogContext) => [
      AppDialogAction(
        label: l.sharedActions_cancel,
        onPressed: () => Navigator.of(dialogContext).pop(false),
      ),
      AppDialogAction(
        label: l.deleteRequests_withdraw,
        kind: AppDialogActionKind.destructive,
        key: const ValueKey('delete-request-withdraw-confirm'),
        onPressed: () => Navigator.of(dialogContext).pop(true),
      ),
    ],
  );
  return answer ?? false;
}

/// The status word for [status]; unknown values fall back to pending so a row
/// never renders an empty chip.
String _statusLabel(AppLocalizations l, String status) => switch (status) {
  'approved' => l.deleteRequests_statusApproved,
  'rejected' => l.deleteRequests_statusRejected,
  'stale_review_required' => l.deleteRequests_statusStale,
  // A request answered by someone else deleting the record: terminal, and the
  // only status word that says the requester does not need to wait any more.
  'already_deleted' => l.deleteRequests_statusAlreadyDeleted,
  _ => l.deleteRequests_statusPending,
};

/// A small state pill for the requester's list.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
    ),
    child: Text(
      label,
      style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant),
    ),
  );
}

/// Centred single-message body (no account, or not a firm member).
class _MessageBody extends StatelessWidget {
  const _MessageBody(this.text);

  /// The message to show.
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: AuthErrorBanner(text: text),
    ),
  );
}

/// A single muted line where a list has nothing in it yet.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: settingsCardDecoration(),
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Text(
      text,
      style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
    ),
  );
}
