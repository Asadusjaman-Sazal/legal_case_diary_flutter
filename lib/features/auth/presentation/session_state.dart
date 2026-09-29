/// What the session's state means for the user, and the one notice it shows.
///
/// The plan's *Offline Session Expiry* rule has two halves, and this file keeps
/// them apart on purpose:
///
/// * **Local data is never gated on JWT validity.** Access tokens expire in
///   about an hour and refreshing needs network, so an offline lawyer must still
///   reach their diary. Nothing here influences whether the database opens: the
///   gate reads local facts, and this state is only ever a *notice*.
/// * **A session the server actually rejected, while online, needs a fresh
///   sign-in** — and the local diary is still not touched. Wiping is the logout
///   flow's job (Task 19), which is exactly where the plan's "never wipe while
///   `sync_queue` has pending rows" rule lives.
///
/// [SessionStatus.staleOffline] and [SessionStatus.reLoginRequired] are the two
/// states item 3 of the task asks to distinguish, and they differ in one fact:
/// whether there is a connection. Offline, there is nothing the user could do,
/// so nothing is asked of them and no notice appears; online, the notice below
/// offers the one action that helps.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../sync/connectivity_monitor.dart';
import '../data/local_auth_service.dart';
import 'auth_viewmodel.dart';

/// The session's state, in the terms the app acts on.
enum SessionStatus {
  /// Nobody signed in, and this device has never held an account.
  signedOut,

  /// A live session. Everything works.
  usable,

  /// A stored account with no live session and no connection to refresh one:
  /// the plan's *"offline, token stale"*. The diary is fully usable and sync is
  /// simply paused, so **no notice is shown** — there is nothing to do.
  staleOffline,

  /// The server rejected the stored session while the device is online (revoked
  /// session, changed password). Signing in again is required; the local diary
  /// is not touched until the branched logout flow decides.
  reLoginRequired,
}

/// The one place the session's state is decided.
final sessionStatusProvider = Provider<SessionStatus>((ref) {
  final auth = ref.watch(authViewModelProvider).value ?? const AuthState();
  if (auth.identity != null) return SessionStatus.usable;

  // Unknown connectivity resolves to *online*: showing the notice when we cannot
  // tell is the actionable choice, and a stale "offline" would silently hide the
  // one thing the user has to do.
  final online = ref.watch(isOnlineProvider).value ?? true;
  if (auth.sessionExpired) {
    return online ? SessionStatus.reLoginRequired : SessionStatus.staleOffline;
  }

  // No live session and no rejection: whose diary this is comes from the local
  // cache, which is what makes the diary reachable before any network call.
  final cachedAccount =
      ref.watch(localAuthServiceProvider).cachedUserId != null;
  return cachedAccount ? SessionStatus.staleOffline : SessionStatus.signedOut;
});

/// Mounts [child] and, when the session was rejected while online, a strip
/// offering the sign-in the user needs.
///
/// A strip, not a window: the diary behind it stays fully visible and usable —
/// the whole point of never gating local data on the session — and only the
/// action is offered. It sits above the navigator like the OEM setup guide and
/// the backup nudge, so it reaches whatever screen the user is on, and it routes
/// through the router it is given because a widget above the navigator has no
/// `context.go` of its own.
class SessionExpiryNotice extends ConsumerWidget {
  /// Creates the notice around [child].
  const SessionExpiryNotice({
    required this.router,
    required this.child,
    super.key,
  });

  /// Router used to reach the Login screen.
  final GoRouter router;

  /// The app below the notice.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(sessionStatusProvider) != SessionStatus.reLoginRequired) {
      return child;
    }
    final l = AppLocalizations.of(context);

    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Material(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                clipBehavior: Clip.antiAlias,
                elevation: 4,
                child: InkWell(
                  onTap: () => router.go(AppRoutes.login),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 20,
                          color: AppColors.onErrorContainer,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            l.auth_sessionExpired,
                            style: AppTypography.bodyMd.copyWith(
                              color: AppColors.onErrorContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          l.auth_sessionExpiredAction,
                          style: AppTypography.titleMd.copyWith(
                            color: AppColors.onErrorContainer,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
