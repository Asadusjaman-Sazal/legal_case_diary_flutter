/// The app header's sync button, shared by the case screens and the Admin Panel.
///
/// It was private to `cases_screen_modal.dart` until the panel needed the same
/// control. Extracting it rather than copying it is what keeps the two headers
/// from drifting: the icon per state, the red pending count, the localized
/// digits and the offline substitution all live here once, so a change to one
/// header's sync button is a change to both.
library;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/utils/date_utils.dart';
import '../../features/cases/presentation/cases_screen_modal.dart'
    show SyncState;

/// A tappable sync button showing the engine's state, with a red count of
/// changes still waiting to be sent.
class SyncButton extends StatelessWidget {
  /// The engine state the icon reads.
  final SyncState syncState;

  /// Whether the account may sync at all; a free account gets the disabled button.
  final bool isPremium;

  /// Called on tap. Null disables the button, as a free account requires.
  final VoidCallback? onSync;

  /// Localizations for the tooltip and the count.
  final AppLocalizations l;

  /// Changes still waiting to be sent, shown as a red count on the button.
  ///
  /// The `sync_problem` badge beside this button only fires for *blocked* or
  /// conflicted work — the things nothing will move on its own. Ordinary pending
  /// work is normal and silent there, which is right for a badge but wrong for
  /// the sync button: a user with two unsent edits and taps sync has no way to
  /// see that from the header.
  final int pending;

  /// Whether the device currently has a connection.
  ///
  /// Defaults to true. Offline, the button always wears the cloud-off icon —
  /// the red count still sits on top when work is queued, but the cloud itself
  /// never claims a sync is possible when it is not.
  final bool isOnline;

  const SyncButton({
    required this.syncState,
    required this.isPremium,
    required this.onSync,
    required this.l,
    this.pending = 0,
    this.isOnline = true,
    super.key,
  });

  Color get _iconColor {
    if (!isPremium) return AppColors.onSurfaceVariant;
    return switch (syncState) {
      SyncState.idle => AppColors.primary,
      SyncState.syncing => AppColors.secondary,
      // A successful sync is the ordinary case, so it wears the ordinary ink.
      // Green here said "something good happened" on every launch, which trains
      // the eye to stop reading the icon at all.
      SyncState.success => AppColors.primary,
      SyncState.paused => AppColors.onSurfaceVariant,
      SyncState.error => AppColors.error,
    };
  }

  String _tooltip() {
    if (pending > 0) return l.sync_pendingBadge(pending);
    if (!isOnline) return l.sync_offline;
    if (!isPremium) return l.sync_unavailable;
    return switch (syncState) {
      SyncState.idle => l.sync_idle,
      SyncState.syncing => l.sync_syncing,
      SyncState.success => l.sync_success,
      SyncState.paused => l.sync_paused,
      SyncState.error => l.sync_error,
    };
  }

  /// Whether the button wears the network-off cloud.
  ///
  /// Offline or paused, it does — even with work queued, because the count is
  /// information about a queue and the cloud is a claim about the connection.
  /// The two are separate, and only the cloud is about syncing being possible.
  bool get _showsOffCloud => !isOnline || syncState == SyncState.paused;

  @override
  Widget build(BuildContext context) {
    final canTap = isPremium && syncState != SyncState.syncing;

    final Widget icon;
    if (syncState == SyncState.syncing && isPremium) {
      icon = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.secondary,
        ),
      );
    } else {
      icon = Icon(
        // `Icons.sync` is gone: the ordinary (idle) state now wears the same
        // success cloud a completed sync wears, and offline or paused wears the
        // off cloud. A real error keeps its own mark, because "something went
        // wrong" is not the same claim as "you are offline".
        _showsOffCloud
            ? Icons.cloud_off_outlined
            : switch (syncState) {
                SyncState.error => Icons.sync_problem_outlined,
                _ => Icons.cloud_done_outlined,
              },
        // Offline is informational, not an alarm, so it wears muted ink; every
        // other state keeps its own colour.
        color: !isOnline ? AppColors.onSurfaceVariant : _iconColor,
        size: 22,
      );
    }

    // A red count on the sync icon: the ordinary pending work the separate
    // `sync_problem` badge deliberately does not show, because here it answers
    // "why did my edit not appear on the other device yet?".
    //
    // While a sync is actually running the spinner is left bare — a count
    // beside a spinner would suggest work is stuck when it is draining.
    final Widget child = pending > 0 && syncState != SyncState.syncing
        ? Badge(
            // Localized digits like every other count in the app: a Latin "2"
            // beside Bengali text is the exact defect this guards against.
            label: Text(
              AppDateUtils.formatDigits(pending, l.localeName, grouping: false),
            ),
            backgroundColor: AppColors.error,
            textColor: AppColors.onError,
            child: icon,
          )
        : icon;

    return Tooltip(
      message: _tooltip(),
      child: IconButton(
        key: const ValueKey('cases-modal-sync-button'),
        icon: child,
        // Tapping still syncs, exactly as before: one control must do one
        // thing. The count is information, and where it can be acted on is the
        // separate Pending Sync entry on the Online Sync screen — which is
        // already reachable, and already where held work is explained.
        onPressed: canTap ? onSync : null,
        tooltip: _tooltip(),
      ),
    );
  }
}
