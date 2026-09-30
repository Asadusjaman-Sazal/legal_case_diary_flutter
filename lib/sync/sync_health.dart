/// Sync health: the reconnect schedule, the paused indicator's state, and the
/// resume throttle's window.
///
/// Three plan rules live here. **Reconnection** (Sync Plan §1): the first
/// attempt is immediate — a resume or a connectivity restoration is already an
/// attempt — and a failure retries on 1s → 2s → 4s → 8s → 16s → 32s, after
/// which active retrying stops (~63 s) and the `connectivity_plus` stream, the
/// next resume, or the user's tap is what restarts it. **The indicator** (§1.4):
/// after three consecutive failures the header shows "Sync paused", and tapping
/// it forces an immediate retry and resets the counters. **The throttle**
/// (§1.4/§12.3): a resume pull may be skipped only inside a 60-second window
/// **and** only when the same Realtime subscription stayed open since the last
/// successful pull — proven by the listener's generation, never by elapsed time
/// alone. The service owns that decision; this file owns the numbers and the
/// state the header renders.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'realtime_listener.dart';

/// The reconnect ladder: 1s → 2s → 4s → 8s → 16s → 32s (max).
const List<Duration> syncReconnectSchedule = <Duration>[
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 4),
  Duration(seconds: 8),
  Duration(seconds: 16),
  Duration(seconds: 32),
];

/// Consecutive failures after which the header says "Sync paused".
const int syncPausedAfterFailures = 3;

/// How recently a pull must have succeeded for a resume to be skippable.
const Duration syncResumeThrottle = Duration(seconds: 60);

/// What the header renders.
enum SyncHealthStatus {
  /// Nothing known yet: no success, no failure, nothing running.
  idle,

  /// A push or pull is running right now.
  syncing,

  /// The last run finished and nothing has failed since.
  healthy,

  /// Three consecutive failures: the header offers "Sync paused" and a retry.
  paused,
}

/// The observable sync health.
@immutable
class SyncHealth {
  /// Creates a health snapshot.
  const SyncHealth({
    this.status = SyncHealthStatus.idle,
    this.consecutiveFailures = 0,
    this.lastSuccessAt,
    this.channelAttempts = 0,
  });

  /// What the header shows.
  final SyncHealthStatus status;

  /// Failures since the last success, across pushes, pulls and channel joins.
  final int consecutiveFailures;

  /// When a run last completed successfully.
  final DateTime? lastSuccessAt;

  /// Reconnect attempts spent on the current outage.
  final int channelAttempts;

  /// Whether the header should offer the paused indicator.
  bool get isPaused => status == SyncHealthStatus.paused;

  /// A copy with the given fields replaced.
  SyncHealth copyWith({
    SyncHealthStatus? status,
    int? consecutiveFailures,
    DateTime? lastSuccessAt,
    int? channelAttempts,
  }) => SyncHealth(
    status: status ?? this.status,
    consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
    lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
    channelAttempts: channelAttempts ?? this.channelAttempts,
  );

  @override
  bool operator ==(Object other) =>
      other is SyncHealth &&
      other.status == status &&
      other.consecutiveFailures == consecutiveFailures &&
      other.lastSuccessAt == lastSuccessAt &&
      other.channelAttempts == channelAttempts;

  @override
  int get hashCode =>
      Object.hash(status, consecutiveFailures, lastSuccessAt, channelAttempts);
}

/// Tracks sync health and drives the Realtime reconnect ladder.
///
/// It watches the listener's status rather than the socket, so an automatic
/// re-join and a failed join are treated the same way: both are events the
/// ladder must react to, and both are things the user never sees directly.
class SyncHealthController {
  /// Creates a controller over [listener].
  SyncHealthController({
    required this.listener,
    this.schedule = syncReconnectSchedule,
  });

  /// The channel whose failures are retried.
  final RealtimeListener listener;

  /// The reconnect ladder, injectable so a test need not wait a minute.
  final List<Duration> schedule;

  /// The observable state.
  final ValueNotifier<SyncHealth> health = ValueNotifier<SyncHealth>(
    const SyncHealth(),
  );

  Timer? _retryTimer;
  int _channelAttempts = 0;
  bool _foreground = true;
  bool _online = true;

  /// Starts watching the channel.
  void attach() => listener.status.addListener(_onChannelStatus);

  /// Stops watching and cancels any pending retry.
  void dispose() {
    listener.status.removeListener(_onChannelStatus);
    _retryTimer?.cancel();
    _retryTimer = null;
    health.dispose();
  }

  /// Records the app moving to the foreground or the background.
  ///
  /// Reconnecting is a foreground-only activity: a backgrounded app must not
  /// hold a socket or spend a radio wake-up trying to get one, so leaving the
  /// foreground cancels the ladder and resets it.
  void setForeground(bool foreground) {
    _foreground = foreground;
    if (!foreground) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _channelAttempts = 0;
      _record(health.value.copyWith(channelAttempts: 0));
      return;
    }
    _channelAttempts = 0;
    unawaited(listener.start());
  }

  /// Records the link going down or coming back.
  ///
  /// While the link is down the ladder is pointless — every join would fail on
  /// the same dead socket — so it stops and the `connectivity_plus` stream is
  /// what restarts it. Coming back is a fresh attempt, not a continuation.
  void setOnline(bool online) {
    _online = online;
    if (!online) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _channelAttempts = 0;
      _record(health.value.copyWith(channelAttempts: 0));
      return;
    }
    _channelAttempts = 0;
    if (_foreground) unawaited(listener.start());
  }

  /// The tap behind the paused indicator: reset everything and try now.
  ///
  /// Counters are cleared **before** the attempt so a tap always produces a
  /// visible change, and the generation the listener bumps on a successful
  /// re-join is what re-arms the resume throttle afterwards.
  Future<void> retryNow() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    _channelAttempts = 0;
    _record(
      health.value.copyWith(
        status: SyncHealthStatus.idle,
        consecutiveFailures: 0,
        channelAttempts: 0,
      ),
    );
    await listener.start();
  }

  /// A run started.
  void recordRunStarted() {
    _record(health.value.copyWith(status: SyncHealthStatus.syncing));
  }

  /// A run finished successfully — the only thing that clears the pause.
  void recordSuccess() {
    _record(
      SyncHealth(
        status: SyncHealthStatus.healthy,
        lastSuccessAt: DateTime.now(),
        channelAttempts: _channelAttempts,
      ),
    );
  }

  /// A run failed (a transport failure, a rejected join, a lost socket).
  void recordFailure() {
    final failures = health.value.consecutiveFailures + 1;
    _record(
      health.value.copyWith(
        status: failures >= syncPausedAfterFailures
            ? SyncHealthStatus.paused
            : SyncHealthStatus.idle,
        consecutiveFailures: failures,
      ),
    );
  }

  void _onChannelStatus() {
    if (listener.status.value == RealtimeStatus.subscribed) {
      // A joined channel is not a successful *sync*, but it does end the
      // reconnect ladder: the outage is over.
      _retryTimer?.cancel();
      _retryTimer = null;
      _channelAttempts = 0;
      _record(health.value.copyWith(channelAttempts: 0));
      return;
    }
    if (listener.status.value == RealtimeStatus.failed) {
      recordFailure();
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    // Nothing to retry towards when the app is backgrounded or the link is down;
    // the connectivity stream and the next resume are what restart the ladder.
    if (!_foreground || !_online) return;
    final delay = _nextDelay();
    if (delay == null) return;
    _channelAttempts++;
    _record(health.value.copyWith(channelAttempts: _channelAttempts));
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => unawaited(listener.start()));
  }

  Duration? _nextDelay() {
    final attempt = _channelAttempts + 1;
    if (attempt > schedule.length) return null;
    return schedule[attempt - 1];
  }

  void _record(SyncHealth next) {
    if (health.value != next) health.value = next;
  }
}
