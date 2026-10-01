/// The removal screen: what a firm member sees on the device that was removed.
///
/// Task 20 Phase 2 item 5 asks for four things when an associate is removed —
/// reject and never merge their queued mutations (server side: `sync_can_write`
/// stops accepting them the moment `profiles.firm_id` is null), discard or roll
/// back the pending local ones, force the logout, and securely erase the app's
/// data. On the client the last three are one action, and it is deliberately the
/// **existing** wipe rather than a second one: [LogoutFlow.wipeAndComplete] runs
/// `BackupRepository.wipeAllTables()`, the same single children-first
/// transaction the recovery flow and every logout branch use, which empties the
/// `sync_queue` (so any queued mutation is discarded outright) together with
/// every domain row, cache, preference and cursor — and only then ends the
/// session.
///
/// **Nothing is erased until the user acts.** The screen blocks the app the way
/// the extended-offline lock does — there is no screen to reach, no FAB to press
/// and no route past it — but the erasure is the one irreversible step, so the
/// person is told what is happening first. An unfinished push in the window
/// between detection and the tap cannot corrupt anything: the server refuses a
/// removed member's writes, and each queued mutation is compared against its own
/// pre-mutation snapshot on the way out (Task 05/18 plumbing).
///
/// No safety copy is written, and that is the task's instruction rather than an
/// oversight: a removed member's authored records stay on the server — the
/// Addendum requires their attribution, not their erasure — while their queued
/// work is explicitly to be *discarded*, not exported. The body below says so
/// rather than promising a backup it does not take.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../auth/data/logout_flow.dart';
import '../data/account_mode.dart';

/// Replaces the app with the removal notice when this device was removed.
///
/// Latched: once a revocation has been seen it stays, because handling it wipes
/// the very rows the check reads — un-latching would let the app come back on the
/// wrong side of an unfinished wipe.
class MembershipRevokedScope extends ConsumerStatefulWidget {
  /// Creates the scope around [child].
  const MembershipRevokedScope({
    required this.router,
    required this.child,
    super.key,
  });

  /// Router used to reach the Login screen once the session has ended.
  final GoRouter router;

  /// The app below the notice; returned untouched while nothing has happened.
  final Widget child;

  @override
  ConsumerState<MembershipRevokedScope> createState() =>
      _MembershipRevokedScopeState();
}

class _MembershipRevokedScopeState
    extends ConsumerState<MembershipRevokedScope> {
  /// Set the first time a removal is seen, and never cleared in this session.
  bool _revoked = false;

  /// Set while the wipe and the sign-out are running, so the action cannot run
  /// twice.
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    if (!_revoked && ref.watch(membershipRevokedProvider)) {
      // Recorded during build for the frame that follows; nothing is destroyed
      // here, and no callback runs in a build.
      _revoked = true;
    }
    if (!_revoked) return widget.child;

    return PopScope(
      // There is no way past this screen except the one action, and no route to
      // press Back into.
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
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('membership-revoked-logout'),
                    onPressed: _busy ? null : _finish,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(
                      AppLocalizations.of(context).membershipRevoked_action,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Wipes everything and ends the session, then leaves for Login.
  ///
  /// The wipe is the recovery/logout flow's own, so the scope is complete by
  /// construction: every table, the queue included, then `signOut` — which
  /// invalidates the profile cache and clears the per-user local state. A failure
  /// anywhere keeps the screen up rather than dropping the user into a diary that
  /// still holds a removed member's data.
  Future<void> _finish() async {
    setState(() => _busy = true);
    try {
      await (await ref.read(logoutFlowProvider.future)).wipeAndComplete();
      if (!mounted) return;
      widget.router.go(AppRoutes.login);
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).membershipRevoked_logoutFailed,
          ),
        ),
      );
    }
  }
}
