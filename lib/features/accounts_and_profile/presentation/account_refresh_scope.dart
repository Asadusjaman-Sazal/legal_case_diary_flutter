/// Launch/resume refresh of the account's profile and firm permissions.
///
/// The plan's permission-freshness rule refreshes `firm_members` **on launch, on
/// resume and on reconnect**, because the local permission cache is advisory and
/// the server is authoritative. This widget owns the first two; Phase 4's
/// connectivity monitor owns reconnect and calls the same
/// [accountRefreshProvider] entry point.
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
    try {
      await ref.read(accountRefreshProvider)();
    } on Object {
      // The cache keeps its last known values; nothing else to do here.
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
    return widget.child;
  }
}
