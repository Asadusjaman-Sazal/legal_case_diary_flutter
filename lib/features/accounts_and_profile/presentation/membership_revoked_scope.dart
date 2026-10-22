/// The removal scope: what a firm member's device does the moment it learns the
/// chamber has removed it.
///
/// **The device erases itself, and it erases first** (user ruling). Removal is one
/// act with two halves — the owner's server-side revoke, and this. The order is
/// the point: the wipe runs *before* anything can reach the firm again, so no
/// case, note, reference, roster, invite or pending request is left on the device,
/// and a `sync_queue` that still held work cannot drain it into the chamber. That
/// is why the earlier design's notice carrying an *Erase & sign out* button is
/// **withdrawn**: a copy that waits for a tap is a copy the person holding the
/// phone can keep, which is exactly what the ruling refuses.
///
/// What the person sees is therefore **informational, never a prompt** — an
/// *your access ended* screen that reports what has already been removed and why.
/// It has no button to erase, because by the time it is on screen the erasure has
/// happened; the only action it offers is leaving for the Login screen, and it is
/// reachable because the session has already ended.
///
/// The wipe is the existing complete scope, [BackupRepository.wipeToFreshInstall],
/// run through [LogoutFlow.wipeAndComplete] — the same one logout and the account
/// switch use. It empties the `sync_queue` (so queued mutations are discarded, not
/// pushed) along with every domain row, cache, preference and cursor, and leaves
/// the seeded baseline of a fresh install behind, so this device can next be used
/// by any account — including the same one rejoining a chamber.
///
/// **No safety copy, and no offer of one** (user ruling): a member keeps neither
/// Back Up nor Restore, because a file holding the chamber's whole ledger is the
/// firm's asset rather than the member's. Their authored rows are not lost — the
/// server keeps them, and the plan requires their attribution rather than their
/// erasure — while their *queued* work is explicitly to be discarded, so there is
/// nothing here a backup could honestly promise.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/notification_providers.dart';
import '../../../core/router/app_router.dart';
import '../../auth/data/logout_flow.dart';
import '../data/account_mode.dart';

/// Replaces the app with the access-ended notice when this device was removed.
///
/// The screen is latched: once a revocation has been seen it stays, because
/// handling it wipes the very rows the check reads — un-latching would let the app
/// come back on the wrong side of the wipe it just ran.
class MembershipRevokedScope extends ConsumerStatefulWidget {
  /// Creates the scope around [child].
  const MembershipRevokedScope({
    required this.router,
    required this.child,
    this.onEraseStarted,
    super.key,
  });

  /// Router used to reach the Login screen after the session has ended.
  final GoRouter router;

  /// The app below the notice; returned untouched until a removal is seen, and
  /// never again afterwards.
  final Widget child;

  /// Notified when the erasure has finished, successfully or not.
  ///
  /// Production passes nothing: the erasure is the app's own act and there is no
  /// one waiting on it. A test passes a callback so it can await the work it
  /// triggered instead of racing the widget's frame for it.
  final void Function(Future<void> erasure)? onEraseStarted;

  @override
  ConsumerState<MembershipRevokedScope> createState() =>
      _MembershipRevokedScopeState();
}

class _MembershipRevokedScopeState
    extends ConsumerState<MembershipRevokedScope> {
  /// Set the first time a removal is seen, and never cleared in this session.
  bool _revoked = false;

  /// The erasure runs once, and this is what proves it ran: the notice below
  /// reports what has *already* been removed, so it must not be shown before the
  /// wipe has finished.
  bool _erased = false;

  /// The erasure currently running, or the last one run.
  ///
  /// Held rather than fired and forgotten, so the retry can await the same work
  /// instead of starting a second erase, and so a test can await the erasure it
  /// triggered rather than racing the widget for it. Nothing awaits this in
  /// production — the erasure is the app's act, not the user's (user ruling).
  Future<void>? _erasure;

  @override
  Widget build(BuildContext context) {
    if (!_revoked && ref.watch(membershipRevokedProvider)) {
      // Recorded during build for the frame that follows. Nothing is destroyed
      // here: no callback runs in a build, and the erasure starts below it.
      _revoked = true;
      // `Future(...)` would run [_erase] synchronously up to its first await,
      // which is inside a build and would read providers there. A microtask
      // starts it after the build returns, still without waiting for a frame.
      _erasure = Future<void>.microtask(_erase);
      widget.onEraseStarted?.call(_erasure!);
    }
    if (!_revoked) return widget.child;

    return PopScope(
      // There is no route back into the app: it has been wiped, and the account
      // is signed out. This is not a gate the user is being asked to pass.
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.person_remove_alt_1_outlined,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  AppLocalizations.of(context).membershipRevoked_title,
                  textAlign: TextAlign.center,
                  style: AppTypography.titleLg,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppLocalizations.of(context).membershipRevoked_body,
                  textAlign: TextAlign.justify,
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                // Progress while the erasure runs, and nothing to press once it
                // has. A removal needs no confirmation and no tap (user ruling).
                if (!_erased) ...[
                  const SizedBox(height: AppSpacing.xl),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Cancels this device's alerts, wipes the complete scope, ends the session.
  ///
  /// Runs by itself, once, with no confirmation step. Each of the three has to
  /// happen in this order and only the first two can fail safely:
  ///
  ///   * the notification cancellation comes first because it is the one piece
  ///     the wipe cannot reach — scheduled case notifications live in the
  ///     platform's alarm manager, not in the database, so a wiped device whose
  ///     alarms were left armed would keep alerting about a chamber it can no
  ///     longer open;
  ///   * the wipe then discards the queue and every local row;
  ///   * the sign-out last, because the wipe's own failure must leave the session
  ///     in place rather than strand the app half-erased and signed out.
  ///
  /// A failure anywhere keeps this screen up and offers a retry, rather than
  /// dropping the user into a diary that still holds a removed member's data.
  Future<void> _erase() async {
    if (_erased) return;
    try {
      // The scheduler is best-effort: an unschedulable platform (a non-Android
      // build, or one with no notification permission) must not block the wipe,
      // which is the half that actually removes the chamber's data.
      await ref.read(notificationSchedulerProvider).cancelAll();
    } on Object {
      // Deliberately swallowed: see above. The upgrade path is a scheduler that
      // reports whether it was armed, so this can be recorded rather than lost.
    }
    try {
      await (await ref.read(logoutFlowProvider.future)).wipeAndComplete();
      if (!mounted) return;
      setState(() => _erased = true);
      widget.router.go(AppRoutes.login);
    } on Object {
      if (!mounted) return;
      // Nothing was erased, so the notice must not claim otherwise; the retry is
      // the one action, and it is offered because the user cannot be left here.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).membershipRevoked_eraseFailed,
          ),
          action: SnackBarAction(
            label: AppLocalizations.of(context).membershipRevoked_retry,
            onPressed: _erase,
          ),
        ),
      );
    }
  }
}
