/// Launch/resume refresh of the account's profile and firm permissions.
///
/// The plan's permission-freshness rule refreshes `firm_members` **on launch, on
/// resume and on reconnect**, because the local permission cache is advisory and
/// the server is authoritative. This widget owns the first two; Phase 4's
/// connectivity monitor owns reconnect and calls the same
/// [accountRefreshProvider] entry point.
///
/// **A session that appears later is the fourth moment.** This scope sits above
/// the router and is mounted once per process, so a user who signs in on a
/// running app — the ordinary case — re-runs neither the launch nor the resume
/// hook. Nothing would pull their `profiles` row until the next resume, and
/// because entitlement is derived from that row every gate would answer *free*
/// in the meantime: the plan shown as Free, Online Sync refusing with "premium
/// is required", and the engine's own entitlement check dropping its pull so
/// "Last Sync" stays *Never*. The identity listener below closes that gap.
///
/// It renders its child untouched and never waits: the refresh starts after the
/// first frame and its result is ignored, so a cold start on a bad connection
/// opens the diary exactly as fast as it did in Part A. A refresh that cannot
/// happen leaves the cache holding its last known values — `permissions_synced_at`
/// is the honest record of how old they are.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sync/connectivity_monitor.dart';
import '../../auth/presentation/auth_viewmodel.dart';
import '../data/account_mode.dart';

/// Refreshes the account profile and firm permissions on launch and on resume.
class AccountRefreshScope extends ConsumerStatefulWidget {
  /// Creates the scope around [child].
  const AccountRefreshScope({required this.child, super.key});

  /// The app subtree; returned unchanged.
  final Widget child;

  @override
  ConsumerState<AccountRefreshScope> createState() =>
      _AccountRefreshScopeState();
}

class _AccountRefreshScopeState extends ConsumerState<AccountRefreshScope>
    with WidgetsBindingObserver {
  /// Whether a refresh is already running.
  ///
  /// One at a time. On a cold start the post-frame refresh and the identity
  /// listener can both want the same session; a second concurrent pull would
  /// only duplicate the first, so whichever asks second is dropped. Nothing is
  /// lost by that: the run already in flight reads the identity it awaits
  /// itself, so it pulls for the same account.
  bool _refreshing = false;

  /// The account the last completed refresh was for.
  ///
  /// A cold start restores its session a moment after the first frame, so the
  /// launch refresh and the identity listener see the same arrival — and the
  /// listener can fire either side of the launch refresh finishing, which is why
  /// both guards are needed. This one stops the *second* pull, whoever asked
  /// first; any later account is a different id and still pulls.
  String? _refreshedUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // After the first frame: the diary is already on screen by then.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_refresh()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Came back from the background: permissions may have changed while away.
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  /// Refreshes, swallowing anything the platform raises on the way.
  ///
  /// Catching broadly is deliberate: this runs unattended on every launch and
  /// resume, and a missing plugin, an unreadable key or a dead socket must never
  /// surface as an unhandled error over the user's diary.
  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await ref.read(accountRefreshProvider)();
      // Read *after* the refresh: the session it awaited is settled by now, so
      // this is the account the pull was actually for.
      _refreshedUserId = ref.read(authIdentityProvider)?.userId;
    } on Object {
      // The cache keeps its last known values; nothing else to do here.
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reconnect is the third moment the plan names, and it is the same function:
    // a device that was offline learns nothing about its firm's permissions
    // until the link comes back, so a false-to-true change pulls them again.
    // Listening (rather than reading) is what makes this a transition, not a
    // rebuild of whatever the current value happens to be.
    ref.listen(isOnlineProvider, (previous, next) {
      if (previous?.value == false && next.value == true) {
        unawaited(_refresh());
      }
    });

    // A session that arrives while the app is running — sign-in, sign-up, Google
    // or a password-recovery link — is a refresh moment none of the hooks above
    // sees. Keying on the account id (not merely on "somebody is signed in")
    // also covers switching accounts, and signing out needs nothing: the pull
    // caches were already emptied on the way out.
    ref.listen(authIdentityProvider, (previous, next) {
      if (next == null) {
        // Signed out. Forgotten so that signing back in as the same account —
        // whose caches the sign-out just emptied — pulls again.
        _refreshedUserId = null;
        return;
      }
      if (previous?.userId == next.userId) return;
      // The launch refresh already covered this arrival.
      if (_refreshedUserId == next.userId) return;
      unawaited(_refresh());
    });
    return widget.child;
  }
}
