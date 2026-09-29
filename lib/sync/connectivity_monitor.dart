/// Connectivity monitor: whether this device has a connection right now.
///
/// Task 17 Phase 4 is the first consumer (`connectivity_plus` was deferred from
/// Task 01 for exactly this), and the launch/resume refresh and the session
/// state machine both read it. The sync workers in Task 19 will read the same
/// provider to know when to drain the queue.
///
/// **It reports the link, not the internet.** A captive portal or a dead uplink
/// still counts as "connected", and that is deliberate: the app is offline-first
/// and every network call classifies its own failure (`mapAuthFailure`). This
/// answer only ever decides whether to *try*, so a wrong one costs a failed
/// request, never a wrong screen — and it must never be used to decide that the
/// user is locked out of their own diary.
///
/// Nothing here blocks a read: the current value is emitted first, then every
/// change, and a platform without the plugin (a unit test, or a desktop build)
/// reports "reachable" rather than stalling. Optimism is the safe direction: a
/// request that runs and fails shows its own localized message, while a false
/// "offline" would silently hide it.
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reads the device's current link state and watches it change.
class ConnectivityMonitor {
  /// Creates a monitor over the plugin, or over [connectivity] in a test.
  ConnectivityMonitor({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Whether any interface is up right now.
  Future<bool> isOnline() async {
    try {
      return _anyOnline(await _connectivity.checkConnectivity());
    } on Exception {
      // No plugin, or a platform that cannot answer: assume reachable.
      return true;
    }
  }

  /// The current value first, then one value per change.
  ///
  /// Errors from the platform channel are swallowed: a monitor that cannot be
  /// listened to keeps its last answer instead of failing a caller that only
  /// wanted a hint.
  Stream<bool> get onlineChanges async* {
    yield await isOnline();
    yield* _connectivity.onConnectivityChanged
        .map(_anyOnline)
        .handleError((Object _) {});
  }

  /// Connected when at least one interface is not `none`.
  static bool _anyOnline(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}

/// Provider for the singleton monitor.
final connectivityMonitorProvider = Provider<ConnectivityMonitor>(
  (ref) => ConnectivityMonitor(),
);

/// Whether the device currently believes it has a connection.
///
/// Null while the first answer is still arriving; readers treat that as
/// "unknown", and the one place that matters (`SessionStatus`) resolves it to
/// the actionable choice rather than to a silent lock-out.
final isOnlineProvider = StreamProvider<bool>(
  (ref) => ref.watch(connectivityMonitorProvider).onlineChanges,
);
