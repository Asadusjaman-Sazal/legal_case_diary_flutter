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
/// [DeleteRequestReviewScreen] where the decision is actually made. Nothing here
/// writes anything.
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
              onTap: () => context.push(
                AppRoutes.deleteRequestReviewPath(request.id),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }

  /// The requester's list: their own requests and what the reviewer decided.
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
              // The requester cannot act on their own request from here; RLS
              // lets them only while it is pending and this screen is not where
              // it is withdrawn, so the row simply shows the outcome.
              onTap: null,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}

/// One request as a row: what it is, when it was asked, and its state.
class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.request,
    required this.l,
    required this.locale,
    required this.onTap,
  });

  final DeleteRequest request;
  final AppLocalizations l;
  final String locale;

  /// Opens the review screen; null on the requester's own list.
  final VoidCallback? onTap;

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
                  '${deleteRequestEntityLabel(l, request.entityType)} \u00b7 '
                  '${AppDateUtils.formatDateDDMMYYYY(request.createdAt, locale: locale)}',
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
          if (onTap == null)
            _StatusChip(label: _statusLabel(l, request.status))
          else
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
