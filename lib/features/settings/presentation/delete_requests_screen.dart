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
/// Both lists come from the same live local stream, and the reviewer's row opens
/// [DeleteRequestReviewScreen] where the decision is actually made. The one thing
/// this screen writes is the requester's own pending request: its row opens an
/// actions sheet — **Edit Request** re-takes the snapshot, **Withdraw Request**
/// cancels — and both go through [DeleteRequestsViewModel].
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
import '../../accounts_and_profile/data/account_mode.dart';
import '../../auth/presentation/auth_viewmodel.dart';
import '../../auth/presentation/auth_widgets.dart';
import 'delete_request_review_screen.dart';
import 'delete_requests_viewmodel.dart';
import 'settings_controls.dart';
import 'settings_sub_page_modal.dart';

/// The two things a requester may do with their own still-pending request.
enum _RequestAction { edit, withdraw }

/// The Delete Requests list: a reviewer's queue or a requester's own requests.
class DeleteRequestsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const DeleteRequestsScreen({super.key});

  @override
  ConsumerState<DeleteRequestsScreen> createState() =>
      _DeleteRequestsScreenState();
}

class _DeleteRequestsScreenState extends ConsumerState<DeleteRequestsScreen> {
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

  /// The reviewer's list: every request still waiting on a decision.
  Widget _queueBody(AppLocalizations l) {
    final queue = ref.watch(deleteReviewQueueProvider);
    final locale = Localizations.localeOf(context).toString();

    return ListView(
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
              // queued request puts to its reviewer is *who wants this gone*,
              // and the moment it was raised is on the review screen itself.
              requesterName: _requesterName(request, l),
              onTap: () => context.push(
                AppRoutes.deleteRequestReviewPath(request.id),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }

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
  /// A **pending** request is still the requester's own to change (Phase 3 item
  /// 3), so its row opens the actions sheet; a decided one is audit history and
  /// stays a plain row that only shows the outcome.
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
              onTap: request.status == 'pending'
                  ? () => _showRequestActions(request)
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }

  /// Offers the two actions a pending request allows, then runs the one chosen.
  Future<void> _showRequestActions(DeleteRequest request) async {
    final l = AppLocalizations.of(context);
    final action = await showModalBottomSheet<_RequestAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('delete-request-action-edit'),
              leading: const Icon(Icons.edit_outlined),
              title: Text(l.deleteRequests_edit),
              onTap: () => Navigator.of(sheetContext).pop(_RequestAction.edit),
            ),
            ListTile(
              key: const ValueKey('delete-request-action-withdraw'),
              // The error colour, because withdrawing is the destructive one of
              // the two: it throws away an action the requester already took.
              leading: const Icon(Icons.close, color: AppColors.error),
              title: Text(
                l.deleteRequests_withdraw,
                style: AppTypography.titleMd.copyWith(color: AppColors.error),
              ),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_RequestAction.withdraw),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _RequestAction.edit:
        await _editRequest(request);
      case _RequestAction.withdraw:
        await _withdrawRequest(request);
    }
  }

  /// Re-takes the request's snapshot from the record it names.
  ///
  /// Nothing is confirmed first: a refresh deletes nothing, and the requester is
  /// saying "this is what I am asking to delete now" about a request they can
  /// refresh again at any time.
  Future<void> _editRequest(DeleteRequest request) async {
    final l = AppLocalizations.of(context);
    // Captured before the write: the snackbar outlives the frame that reported
    // it, and a rebuilt list no longer holds the context that was captured.
    final messenger = ScaffoldMessenger.of(context);
    final refreshed = await _write(
      () => ref
          .read(deleteRequestsViewModelProvider.notifier)
          .refreshSnapshot(request.id),
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          refreshed ? l.deleteRequests_updated : l.deleteRequests_updateFailed,
        ),
      ),
    );
  }

  /// Withdraws the request, after confirming it.
  Future<void> _withdrawRequest(DeleteRequest request) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _confirmWithdraw(context, l);
    if (!confirmed || !mounted) return;
    final withdrawn = await _write(
      () => ref
          .read(deleteRequestsViewModelProvider.notifier)
          .cancel(request.id),
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
class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.request,
    required this.l,
    required this.locale,
    required this.onTap,
    required this.showStatusChip,
    this.requesterName,
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

  /// Opens the row's destination: a review, or the requester's own actions.
  /// Null on a row that has nothing left to do.
  final VoidCallback? onTap;

  /// Whether the row carries its state as a pill. The requester's own list does,
  /// because pending and decided rows sit in it side by side; the reviewer's
  /// queue does not — everything in it is pending by definition.
  final bool showStatusChip;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
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
            child: const Icon(
              Icons.delete_outline,
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
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (showStatusChip) _StatusChip(label: _statusLabel(l, request.status)),
          // A tappable row says so; a static one has nothing more to add.
          if (onTap != null)
            const Icon(Icons.chevron_right, color: AppColors.outline),
        ],
      ),
    );

    if (onTap == null) {
      return Container(decoration: settingsCardDecoration(), child: content);
    }
    return Material(
      color: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        side: BorderSide(color: AppColors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('delete-request-row-${request.id}'),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// The withdrawal window.
///
/// A confirmation rather than a plain tap because the two actions on the sheet
/// are not equally reversible: an edit can be repeated, a withdrawal cannot —
/// the requester would have to raise the request again and the reviewer would
/// see a new one.
Future<bool> _confirmWithdraw(BuildContext context, AppLocalizations l) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.deleteRequests_withdrawTitle),
      content: Text(l.deleteRequests_withdrawBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.sharedActions_cancel),
        ),
        FilledButton(
          key: const ValueKey('delete-request-withdraw-confirm'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.deleteRequests_withdraw),
        ),
      ],
    ),
  );
  return answer ?? false;
}

/// The status word for [status]; unknown values fall back to pending so a row
/// never renders an empty chip.
String _statusLabel(AppLocalizations l, String status) => switch (status) {
  'approved' => l.deleteRequests_statusApproved,
  'rejected' => l.deleteRequests_statusRejected,
  'stale_review_required' => l.deleteRequests_statusStale,
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
