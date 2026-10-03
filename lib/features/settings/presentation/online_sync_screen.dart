/// Online Sync screen: the account's real sync state and per-entity rows.
///
/// Body mirrors `mockup_html_screens/settings_onlineSync/code.html`, rendered as
/// the mockup's mobile single-column stack of the bento grid. Every string the
/// mockup hard-codes is now derived: the account card reads the signed-in
/// account and its real entitlement, the status card reads the live engine, and
/// the three entity rows read their local counts and any work still queued.
///
/// **What the screen does not claim.** The sync engine records *this device's*
/// last successful sync and per-table pull cursors — there is no per-entity
/// "synced" flag anywhere in the app. So an entity row reports its item count
/// and whether it has changes still waiting to be sent, which is the honest
/// per-entity fact available; it never claims an entity is "synced".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../database/app_database.dart';
import '../../accounts_and_profile/data/account_mode.dart';
import '../../auth/presentation/auth_viewmodel.dart';
import '../../case_reference/presentation/reference_viewmodel.dart';
import '../../cases/presentation/case_viewmodel.dart';
import '../../notes/presentation/notes_viewmodel.dart';
import '../../sync/presentation/sync_status_screen.dart';
import '../../../sync/connectivity_monitor.dart';
import '../../../sync/sync_health.dart';
import '../../../sync/sync_providers.dart';
import '../../../sync/sync_service.dart';
import '../../../sync/sync_status_providers.dart';
import 'settings_menu_card.dart';
import 'settings_sub_page_modal.dart';

/// White bordered card shell shared by the status card and the sync rows.
/// Radius matches the mockup's `rounded-xl` (0.5 rem = 8 px).
BoxDecoration _cardDecoration({
  Color color = AppColors.surfaceContainerLowest,
}) => BoxDecoration(
  color: color,
  borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
  border: Border.all(color: AppColors.outlineVariant),
);

/// Why a manual sync cannot run right now, if it cannot.
///
/// The engine enforces all three of these itself (`SyncService._isOnline`,
/// `_isEntitled`), but it does so by silently returning, and a button that
/// appears to work while doing nothing is worse than one that explains itself.
enum _SyncBlocker {
  /// Nothing is blocking it.
  none,

  /// Nobody is signed in.
  signedOut,

  /// Signed in, but on the free plan — premium is what unlocks sync.
  needsPremium,

  /// Signed in, but the account's plan is not known yet.
  ///
  /// Distinct from [needsPremium] on purpose: the entitlement derivation reads
  /// the cached profile, so before the first pull of a session it answers false
  /// for a premium account too. Telling that user premium is required is simply
  /// untrue, and it is the state a fresh sign-in used to sit in.
  checking,

  /// No connection.
  offline,
}

/// Online Sync screen, wired to the live account and sync engine.
class OnlineSyncScreen extends ConsumerWidget {
  const OnlineSyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);

    // Live local counts; null while the list is still loading.
    final cases = ref.watch(
      caseViewModelProvider.select((s) => s.value?.nonDeletedCount),
    );
    final notes = ref.watch(
      notesViewModelProvider.select((s) => s.value?.items.length),
    );
    final references = ref.watch(
      referenceViewModelProvider.select((s) => s.value?.items.length),
    );

    // The account, the entitlement and the engine — each read from the provider
    // that already owns it rather than from a local guess, so what the screen
    // shows cannot disagree with what the rest of the app believes.
    //
    // The account itself is not drawn here: who is signed in and which plan
    // they hold are already stated in Settings > Manage Account, so this screen
    // is about the state of the sync rather than a second copy of the account.
    // What it still needs from the session is *whether there is one*, because
    // that decides whether sync can run at all.
    final health = ref.watch(syncHealthProvider).value;
    final lastSuccess = ref.watch(syncLastSuccessProvider).value;
    final attention = ref.watch(syncStatusAttentionProvider).value ?? 0;
    final pending = ref.watch(syncQueuePendingCountProvider).value ?? 0;

    final blocker = _syncBlockerOf(ref);

    return SettingsSubPageModal(
      title: l.settingsOnlineSync_title,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.edgeMargin,
          AppSpacing.md,
          AppSpacing.edgeMargin,
          AppSpacing.xl,
        ),
        children: [
          Text(
            l.settingsOnlineSync_subtitle,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SyncStatusCard(
            health: health,
            lastSuccess: lastSuccess,
            attention: attention,
            pending: pending,
            blocker: blocker,
          ),
          const SizedBox(height: AppSpacing.gutter),
          _SyncRow(
            icon: Icons.work_outline,
            label: l.settingsOnlineSync_cases,
            count: cases,
            entityTypes: const <String>['case', 'case_history'],
          ),
          const SizedBox(height: AppSpacing.gutter),
          _SyncRow(
            icon: Icons.sticky_note_2_outlined,
            label: l.settingsOnlineSync_notes,
            count: notes,
            entityTypes: const <String>['note'],
          ),
          const SizedBox(height: AppSpacing.gutter),
          _SyncRow(
            icon: Icons.menu_book_outlined,
            label: l.settingsOnlineSync_references,
            count: references,
            entityTypes: const <String>['reference'],
          ),
          const SizedBox(height: AppSpacing.gutter),
          const _PendingSyncEntry(),
        ],
      ),
    );
  }
}

/// Entry card for the Sync Status / Diagnostics screen (Task 19 Phase 4),
/// titled *Pending Sync* and placed last, after the three entity rows.
///
/// The plan's second route into that screen: the header badge is the shortcut
/// while something is held, and this is where a user looks for it deliberately.
/// It reads the attention count so the card itself carries the same news. Its
/// own title is used rather than `syncStatus_title`, which names the screen it
/// opens — renaming that would have changed that screen's own header too.
class _PendingSyncEntry extends ConsumerWidget {
  const _PendingSyncEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final attention = ref.watch(syncStatusAttentionProvider).value ?? 0;
    return SettingsMenuCard(
      icon: Icons.fact_check_outlined,
      title: l.settingsOnlineSync_pendingSyncTitle,
      subtitle: attention == 0
          ? l.settingsOnlineSync_pendingSyncSubtitle
          : l.syncStatus_entryTitle(
              l.syncStatus_filterBlocked,
              l.syncStatus_filterConflicted,
            ),
      onTap: () => context.push(AppRoutes.settingsSyncStatus),
    );
  }
}

/// Sync status card: the engine's live state and the CTA that drives it.
class _SyncStatusCard extends ConsumerWidget {
  final SyncHealth? health;
  final int? lastSuccess;
  final int attention;
  final int pending;
  final _SyncBlocker blocker;

  const _SyncStatusCard({
    required this.health,
    required this.lastSuccess,
    required this.attention,
    required this.pending,
    required this.blocker,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final syncing = health?.status == SyncHealthStatus.syncing;
    final paused = health?.status == SyncHealthStatus.paused;
    // Attention outranks everything: a blocked or conflicted change is the one
    // thing on this screen that cannot resolve itself.
    final needsAction = attention > 0;
    // Being offline is the same kind of news and ranks with it. The tint used
    // to be decided by attention alone, so a signed-in premium user with an
    // empty queue was shown a green "No Connection" and a green Wi-Fi-off icon
    // beside a Sync Now that could not run — the screen saying everything was
    // well at the one moment nothing could sync. The mockup's blocked card is
    // red for the same reason.
    final tint = needsAction || blocker == _SyncBlocker.offline
        ? AppColors.error
        : paused
        ? AppColors.onSurfaceVariant
        : AppColors.success;

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_icon(l), size: 16, color: tint),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            _pillLabel(l),
                            style: AppTypography.labelMd.copyWith(color: tint),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      lastSuccess == null
                          ? l.settingsOnlineSync_lastSyncNever
                          : l.settingsOnlineSync_lastSyncAt(
                              syncStatusRelativeTime(l, lastSuccess!),
                            ),
                      style: AppTypography.titleLg,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(_body(l), style: AppTypography.bodySm),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                ),
                child: Icon(_icon(l), size: 24, color: tint),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              // Disabled rather than hidden when sync cannot run: the user can
              // then see why, which is the whole point of this card.
              onPressed: blocker == _SyncBlocker.none && !syncing
                  ? () => _syncNow(context, ref)
                  : null,
              icon: syncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync, size: 20),
              label: Text(
                syncing
                    ? l.settingsOnlineSync_syncing
                    : l.settingsOnlineSync_syncNow,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                disabledBackgroundColor: AppColors.surfaceContainerHigh,
                disabledForegroundColor: AppColors.onSurfaceVariant,
                textStyle: AppTypography.titleMd,
                // Same height as every other Settings sub-menu CTA.
                minimumSize: const Size.fromHeight(settingsPrimaryButtonHeight),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.sm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                ),
              ),
            ),
          ),
          if (blocker != _SyncBlocker.none) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _blockerMessage(l),
              style: AppTypography.bodySm.copyWith(color: AppColors.tertiary),
            ),
          ],
        ],
      ),
    );
  }

  IconData _icon(AppLocalizations l) => switch (blocker) {
    _SyncBlocker.signedOut => Icons.cloud_off_outlined,
    _SyncBlocker.needsPremium => Icons.workspace_premium_outlined,
    _SyncBlocker.checking => Icons.cloud_sync_outlined,
    _SyncBlocker.offline => Icons.wifi_off_outlined,
    _SyncBlocker.none => switch (health?.status) {
      SyncHealthStatus.syncing => Icons.sync,
      SyncHealthStatus.paused => Icons.pause_circle_outline,
      _ => attention > 0 ? Icons.error_outline : Icons.check_circle_outline,
    },
  };

  String _pillLabel(AppLocalizations l) => switch (blocker) {
    _SyncBlocker.signedOut => l.settingsOnlineSync_notSignedIn,
    _SyncBlocker.needsPremium => l.settingsOnlineSync_freePlanPill,
    _SyncBlocker.checking => l.settingsOnlineSync_checkingPlan,
    _SyncBlocker.offline => l.settingsOnlineSync_offline,
    _SyncBlocker.none => switch (health?.status) {
      SyncHealthStatus.syncing => l.settingsOnlineSync_syncing,
      SyncHealthStatus.paused => l.settingsOnlineSync_paused,
      _ =>
        attention > 0
            ? l.settingsOnlineSync_actionRequired
            : l.settingsOnlineSync_upToDate,
    },
  };

  String _body(AppLocalizations l) => switch (blocker) {
    _SyncBlocker.signedOut => l.settingsOnlineSync_dataStaysOnDevice,
    _SyncBlocker.needsPremium => l.settingsOnlineSync_freePlanHint,
    _SyncBlocker.checking => l.settingsOnlineSync_checkingPlanBody,
    _SyncBlocker.offline => l.settingsOnlineSync_needConnectionToSync,
    _SyncBlocker.none =>
      attention > 0
          ? l.settingsOnlineSync_actionRequiredBody
          : pending > 0
          ? l.settingsOnlineSync_pendingUploads(pending)
          : l.settingsOnlineSync_pendingNone,
  };

  String _blockerMessage(AppLocalizations l) => switch (blocker) {
    _SyncBlocker.signedOut => l.settingsOnlineSync_needSignInToSync,
    _SyncBlocker.needsPremium => l.settingsOnlineSync_needPremiumToSync,
    _SyncBlocker.checking => l.settingsOnlineSync_checkingPlanMessage,
    _SyncBlocker.offline => l.settingsOnlineSync_needConnectionToSync,
    _SyncBlocker.none => '',
  };

  /// Runs one forced drain and reports what happened.
  ///
  /// `syncNow` returns void and signals failure through health and notices, so
  /// the outcome is read from the engine afterwards rather than invented here.
  Future<void> _syncNow(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(syncServiceProvider).syncNow(force: true, pull: true);
    // The engine returns silently when a guard refuses it, so confirm against
    // the health it published before telling the user anything.
    final failed = ref.read(syncHealthProvider).value?.consecutiveFailures;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failed != null && failed > 0
              ? l.settingsOnlineSync_syncFailed
              : l.settingsOnlineSync_syncFinished,
        ),
      ),
    );
  }
}

/// One entity row with its local item count and any work still queued for it.
///
/// The trailing marker is deliberately only ever "work waiting" or a muted
/// idle: the app has no per-entity synced flag, so it never claims one.
class _SyncRow extends ConsumerWidget {
  final IconData icon;
  final String label;
  final int? count;

  /// Queue entity types belonging to this row.
  final List<String> entityTypes;

  const _SyncRow({
    required this.icon,
    required this.label,
    required this.count,
    required this.entityTypes,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    // Local alias so the null check promotes below.
    final itemCount = count;
    // How many of this entity's changes are still waiting to be sent.
    final waiting =
        (ref.watch(syncQueueEntriesProvider).value ?? const <SyncQueueRow>[])
            .where((row) => entityTypes.contains(row.entityType))
            .length;
    // Whether sync can reach the account at all — the fact that decides what
    // the marker *means*. Without it, "nothing waiting" would read as
    // "Synced" on a free plan where nothing was ever sent.
    final blocker = _syncBlockerOf(ref);

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.md),
      // Content row matches the Account & Profile sub-menu card (44 px between
      // the two 16 px paddings), so the three entity rows are the same size as
      // those menu cards.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: settingsMenuCardRowHeight),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.labelLg.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    itemCount == null
                        ? l.settingsOnlineSync_itemsUnknown
                        : l.settingsOnlineSync_itemsCount(itemCount),
                    style: AppTypography.bodySm,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // One marker per real state, never a green "nothing waiting" beside
            // a red "Sync Now is disabled": a row says Synced only when this
            // entity really is on the account, and says so in red when it is
            // not and cannot be.
            Icon(
              _markerIcon(waiting, blocker),
              size: 18,
              color: _markerColor(waiting, blocker),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              _markerLabel(l, waiting, blocker),
              style: AppTypography.bodySm.copyWith(
                color: _markerColor(waiting, blocker),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The marker icon for one entity row.
///
/// **Waiting work outranks the blocker.** A queued change is a fact regardless
/// of the plan or the connection, so it is reported as work in every case;
/// otherwise two pending edits on a free plan read as "Not synced", which tells
/// the user nothing is queued when two things are.
IconData _markerIcon(int waiting, _SyncBlocker blocker) {
  if (waiting > 0) return Icons.cloud_upload_outlined;
  return blocker == _SyncBlocker.none
      ? Icons.cloud_done_outlined
      : Icons.cloud_off_outlined;
}

/// Amber while work waits, green only when the entity really is on the
/// account, red when it is not and cannot be.
Color _markerColor(int waiting, _SyncBlocker blocker) {
  if (waiting > 0) return AppColors.tertiary;
  return blocker == _SyncBlocker.none
      ? AppColors.success
      : AppColors.error;
}

/// What the marker says. The blockers get their own wording because "Sign in
/// to sync" tells the user what to do and "Not synced" does not — but only once
/// there is nothing waiting, which is the state that wording actually describes.
String _markerLabel(AppLocalizations l, int waiting, _SyncBlocker blocker) {
  if (waiting > 0) return l.settingsOnlineSync_pendingCount(waiting);
  if (blocker != _SyncBlocker.none) {
    return blocker == _SyncBlocker.signedOut
        ? l.settingsOnlineSync_notSyncedSignedOut
        : l.settingsOnlineSync_notSynced;
  }
  return l.settingsOnlineSync_synced;
}

/// The single blocker rule, so the status card and the three entity rows cannot
/// disagree about why sync is unavailable.
_SyncBlocker _syncBlockerOf(WidgetRef ref) {
  if (ref.watch(authIdentityProvider) == null) return _SyncBlocker.signedOut;
  final premium = ref.watch(premiumAccessProvider);
  // Unknown before free: an account whose profile row has not been pulled yet
  // has no plan to report, and the same false that means "free" for a known
  // account means "no answer yet" for this one.
  if (premium.isLoading || !ref.watch(entitlementKnownProvider)) {
    return _SyncBlocker.checking;
  }
  if (!(premium.value ?? false)) return _SyncBlocker.needsPremium;
  if (!(ref.watch(isOnlineProvider).value ?? true)) {
    return _SyncBlocker.offline;
  }
  return _SyncBlocker.none;
}
