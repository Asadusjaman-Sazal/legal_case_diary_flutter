/// The Admin Panel: payment requests awaiting a decision, and the record of the
/// ones already decided.
///
/// Task 22. The screen is deliberately thin — it renders what
/// `adminPaymentRequestsProvider` returns and calls two methods on
/// `AdminActionViewModel`. It holds no admin state of its own, because the one
/// question that matters ("is this person an admin at all?") is answered by the
/// server through `adminStatusProvider`, and navigation reads that **before** this
/// screen is ever built.
///
/// The two lists are collapsible and the default is the one that needs attention:
/// Pending starts open, Resolved starts closed, because a resolved submission
/// cannot be acted on and the admin opening this screen has work to do.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/app_share_flow.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/app_navigation_drawer.dart';
import '../../../shared/widgets/sync_button.dart';
import '../../../sync/connectivity_monitor.dart';
import '../../../sync/sync_providers.dart';
import '../../../sync/sync_health.dart';
import '../../../sync/sync_service.dart';
import '../../../sync/sync_status_providers.dart';
import '../../accounts_and_profile/data/account_mode.dart';
import '../../cases/presentation/cases_screen_modal.dart' show SyncState;
import '../../payments/data/payment_plans.dart';
import '../../payments/presentation/payment_plan_labels.dart';
import '../../settings/presentation/settings_menu_card.dart';
import '../../settings/presentation/settings_viewmodel.dart';
import '../data/admin_repository.dart';
import 'admin_viewmodel.dart';

/// Premium benefits & payment requests for a registered administrator.
class AdminPanelScreen extends ConsumerStatefulWidget {
  /// Creates the panel.
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen> {
  /// Pending is the section that needs attention, so it starts open and
  /// Resolved — a history, not a to-do — starts closed.
  bool _pendingOpen = true;
  bool _resolvedOpen = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final requests = ref.watch(adminPaymentRequestsProvider);
    final action = ref.watch(AdminActionViewModel.provider);

    // A shell route, so `AppShellRoot`'s SafeArea already insets the status bar
    // above this screen — unlike the paywall, which sits outside the shell. A
    // second SafeArea here would double the inset.
    //
    // The header is the case screens' own: a hamburger that opens the drawer
    // and the Sync Status badge, with no back button (the drawer and the back
    // gesture both leave, so a back arrow beside the menu is a second answer to
    // the same question). Search and the view toggle are the case screens'
    // controls and have nothing to act on here.
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: AppNavigationDrawer(
        currentRoute: AppRoutes.adminPanel,
        sideNavOptions:
            ref.watch(settingsViewModelProvider).value?.sideNavOptions ??
            const {},
        // Print is left unbound: there is nothing here to print, and the
        // drawer hides the action rather than offering one that only reports
        // that it cannot help.
        onShare: () => shareAppInvite(context, ref),
      ),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: _AdminHeader(title: l.adminPanel_title),
      ),
      body: requests.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (_, _) => _LoadFailed(
          onRetry: () => ref.invalidate(adminPaymentRequestsProvider),
        ),
        data: (all) {
          final pending = all.where((r) => r.isPending).toList(growable: false);
          final resolved = all
              .where((r) => r.isResolved)
              .toList(growable: false);
          // Pull to refresh does what the header button does — a forced drain with the
          // delta pull — and then re-reads the submissions, so a payment that
          // landed while the screen was open appears without a second trip to
          // Settings.
          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(syncServiceProvider).retryNow();
              ref.invalidate(adminPaymentRequestsProvider);
              await ref.read(adminPaymentRequestsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.edgeMargin,
                AppSpacing.md,
                AppSpacing.edgeMargin,
                AppSpacing.xl,
              ),
              children: [
                // One step larger than the shared SettingsSectionLabel, so
                // "Payment Requests" reads as this screen's own heading rather
                // than as one more menu label.
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: Text(
                    l.adminPanel_paymentRequests,
                    style: AppTypography.labelLg.copyWith(
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                if (action.phase != AdminActionPhase.idle)
                  _ActionBanner(
                    action: action,
                    onDismiss: () => ref
                        .read(AdminActionViewModel.provider.notifier)
                        .clear(),
                  ),
                const SizedBox(height: AppSpacing.md),
                _RequestSection(
                  icon: Icons.pending_actions,
                  title: l.adminPanel_pending,
                  count: pending.length,
                  open: _pendingOpen,
                  emptyText: l.adminPanel_emptyPending,
                  children: [
                    for (final request in pending)
                      _RequestCard(
                        key: ValueKey('admin-request-${request.id}'),
                        request: request,
                      ),
                  ],
                  onToggle: () =>
                      setState(() => _pendingOpen = !_pendingOpen),
                ),
                const SizedBox(height: AppSpacing.lg),
                _RequestSection(
                  icon: Icons.task_alt,
                  title: l.adminPanel_resolved,
                  count: resolved.length,
                  open: _resolvedOpen,
                  emptyText: l.adminPanel_emptyResolved,
                  // Newest decision first: the admin wants the latest history,
                  // not the oldest, and the server's own order is by submission
                  // time rather than by when it was decided.
                  children: [
                    for (final request in _byDecisionTime(resolved))
                      _RequestCard(
                        key: ValueKey('admin-request-${request.id}'),
                        request: request,
                      ),
                  ],
                  onToggle: () =>
                      setState(() => _resolvedOpen = !_resolvedOpen),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

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

/// The case screens' header, minus the controls that have nothing to act on.
///
/// A hamburger that opens the drawer and the Sync Status badge, exactly as
/// `CasesScreenModal` draws them — no back arrow (the drawer and the system back
/// gesture are already two ways out, and a third button answering the same
/// question is noise), no search and no view toggle (both belong to a case
/// list, and an admin panel has none to search or restyle).
class _AdminHeader extends ConsumerWidget {
  final String title;

  const _AdminHeader({required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    // Read from the same provider the case screens read, so the badge appears
    // on exactly the same condition here as on a case screen.
    final attention = ref.watch(syncStatusAttentionProvider).value ?? 0;
    final pending = ref.watch(syncQueuePendingCountProvider).value ?? 0;
    final online = ref.watch(isOnlineProvider).value ?? true;
    final health = ref.watch(syncHealthProvider).value;
    final syncState = switch (health?.status) {
      SyncHealthStatus.syncing => SyncState.syncing,
      SyncHealthStatus.healthy => SyncState.success,
      SyncHealthStatus.paused => SyncState.paused,
      _ => SyncState.idle,
    };
    final premium = ref.watch(premiumAccessProvider).value == true;

    return Container(
      height: 56,
      color: AppColors.surface,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: AppColors.primary),
            tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
          Expanded(
            child: Text(
              title,
              style: AppTypography.titleLg,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (attention > 0)
            IconButton(
              key: const ValueKey('admin-panel-sync-status'),
              icon: Badge.count(
                count: attention,
                child: const Icon(Icons.sync_problem, color: AppColors.error),
              ),
              tooltip: l.syncStatus_title,
              onPressed: () => context.push(AppRoutes.settingsSyncStatus),
            ),
          // The same shared sync button the case screens carry, so an admin
          // pulls a sync from wherever they are. It reads the same providers
          // and does the same work — `retryNow`, which clears the backoff and
          // runs a forced drain with the delta pull.
          SyncButton(
            syncState: syncState,
            isPremium: premium,
            onSync: () => ref.read(syncServiceProvider).retryNow(),
            l: l,
            pending: pending,
            isOnline: online,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
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
/// button.
///
/// The header is the app's shared [SettingsMenuCard] — the very control the
/// Backup & Restore screen's sections draw — so the two sections are the same
/// size as those buttons by construction rather than by a copied measurement,
/// and stay that size if the shared card ever changes. Pending and Resolved
/// carry different icons so the two are told apart at a glance, and the
/// revealed requests sit in a bordered surface that matches the card's radius.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsMenuCard(
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
        // The reveal animates so the list below does not jump when a section
        // opens under the reader's thumb.
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: open
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: _body(l),
                )
              : const SizedBox(width: double.infinity),
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
/// — the two decisions an admin may take.
class _RequestCard extends ConsumerWidget {
  final AdminPaymentRequest request;

  const _RequestCard({required this.request, super.key});

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
            _planAndAmount(l, request),
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
            value: _methodLabel(l, request.mfsProvider),
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
            value: _date(l, request.submittedAt),
          ),
          if (request.isResolved) ...[
            if (request.approvedAt != null)
              _DetailLine(
                label: l.adminPanel_approvedExpiry,
                value: _date(l, request.approvedNewExpiry),
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

  /// The localized brand of one MFS provider, so the admin reads "bKash"
  /// rather than the stored `bkash` key.
  ///
  /// The checkout keeps its own copy of this mapping; two screens are below the
  /// point where a third one would make the two worth unifying.
  static String _methodLabel(AppLocalizations l, String provider) =>
      switch (provider) {
        'bkash' => l.payments_methodBkash,
        'nagad' => l.payments_methodNagad,
        'rocket' => l.payments_methodRocket,
        _ => provider,
      };

  /// "৳960 per year" — the plan's own name plus its bare amount, worded by the
  /// same helpers the paywall uses so the two never disagree.
  static String _planAndAmount(
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

  static String _date(AppLocalizations l, DateTime? value) => value == null
      ? l.adminPanel_noValue
      : AppDateUtils.formatDateDDMMYYYY(
          value.millisecondsSinceEpoch,
          locale: l.localeName,
        );

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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.edgeMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.adminPanel_loadFailed,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                textStyle: AppTypography.labelLg,
              ),
              child: Text(l.adminPanel_retry),
            ),
          ],
        ),
      ),
    );
  }
}
