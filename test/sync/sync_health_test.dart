/// Sync health tests — Task 19 Phase 2.
///
/// The reconnect ladder is exercised on a millisecond schedule, so the whole
/// 1s → 32s behaviour and its six-attempt ceiling are pinned without waiting a
/// minute.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/sync/realtime_listener.dart';
import 'package:legal_case_diary/sync/sync_health.dart';

/// A socket whose joins the test authorizes or refuses.
class _Socket implements RealtimeSocket {
  int joins = 0;
  bool authorized = true;
  void Function(RealtimeStatus status)? onStatus;

  @override
  Future<bool> subscribe(
    String topic, {
    required void Function(SyncPing ping) onPing,
    required void Function(RealtimeStatus status) onStatus,
  }) async {
    joins++;
    this.onStatus = onStatus;
    onStatus(authorized ? RealtimeStatus.subscribed : RealtimeStatus.failed);
    return authorized;
  }

  @override
  Future<void> unsubscribe() async {}
}

void main() {
  const fast = <Duration>[
    Duration(milliseconds: 5),
    Duration(milliseconds: 5),
    Duration(milliseconds: 5),
  ];

  late _Socket socket;
  late RealtimeListener listener;
  late SyncHealthController health;

  setUp(() {
    socket = _Socket();
    listener = RealtimeListener(
      socket: socket,
      topic: () => 'firm:f1',
      onPings: (_) {},
    );
    health = SyncHealthController(listener: listener, schedule: fast)..attach();
  });

  tearDown(() {
    health.dispose();
    listener.dispose();
  });

  Future<void> settle(int rounds) async {
    for (var i = 0; i < rounds; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }

  test('the default ladder is the plan\'s 1s to 32s ceiling', () {
    expect(syncReconnectSchedule, <Duration>[
      const Duration(seconds: 1),
      const Duration(seconds: 2),
      const Duration(seconds: 4),
      const Duration(seconds: 8),
      const Duration(seconds: 16),
      const Duration(seconds: 32),
    ]);
    expect(syncPausedAfterFailures, 3);
    expect(syncResumeThrottle, const Duration(seconds: 60));
  });

  test('a failed join waits on the ladder before each retry', () async {
    // Its own listener and socket, so the setUp ladder is not also driving this
    // channel. One short rung and two long ones, so "waited" is visible.
    final slowSocket = _Socket()..authorized = false;
    final slowListener = RealtimeListener(
      socket: slowSocket,
      topic: () => 'firm:f1',
      onPings: (_) {},
    );
    final slow = SyncHealthController(
      listener: slowListener,
      schedule: const <Duration>[
        Duration(milliseconds: 100),
        Duration(milliseconds: 600),
        Duration(milliseconds: 600),
      ],
    )..attach();
    addTearDown(() {
      slow.dispose();
      slowListener.dispose();
    });

    await slowListener.start();
    expect(slowSocket.joins, 1, reason: 'no retry before the first rung');

    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(slowSocket.joins, 2, reason: 'the first rung fired after 100 ms');
    // `channelAttempts` counts the rungs spent on this outage, so the retry that
    // just failed has already booked the next one.
    expect(slow.health.value.channelAttempts, 2);

    // Still 2 right after: the second rung is 600 ms away, so this is a ladder,
    // not a busy retry loop.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(slowSocket.joins, 2);
  });

  test('active retrying stops after the last rung', () async {
    socket.authorized = false;

    await listener.start();

    // Three 5 ms rungs: one initial join plus three retries, and then nothing,
    // even though the listener is still unsubscribed.
    await settle(3);
    expect(socket.joins, 4);
    expect(health.health.value.channelAttempts, 3);

    await settle(3);
    expect(socket.joins, 4, reason: 'the ceiling is quiet, not a poll');
  });

  test('three failures pause sync, and a success clears it', () async {
    health
      ..recordFailure()
      ..recordFailure();
    expect(health.health.value.isPaused, isFalse);
    expect(health.health.value.status, SyncHealthStatus.idle);

    health.recordFailure();
    expect(health.health.value.isPaused, isTrue);
    expect(health.health.value.consecutiveFailures, 3);

    health.recordSuccess();
    expect(health.health.value.isPaused, isFalse);
    expect(health.health.value.status, SyncHealthStatus.healthy);
    expect(health.health.value.consecutiveFailures, 0);
    expect(health.health.value.lastSuccessAt, isNotNull);
  });

  test('a lost channel counts as a failure too', () async {
    await listener.start();
    socket.onStatus!(RealtimeStatus.failed);

    expect(health.health.value.consecutiveFailures, 1);
    expect(listener.isSubscribed, isFalse);
  });

  test('a joined channel ends the ladder without claiming a sync success',
      () async {
    await settle(1);
    health
      ..recordFailure()
      ..recordFailure()
      ..recordFailure();
    expect(health.health.value.isPaused, isTrue);

    // Rejoining resets the reconnect attempts, but only a completed run makes
    // sync healthy again.
    await listener.start();
    expect(health.health.value.channelAttempts, 0);
    expect(health.health.value.isPaused, isTrue);
  });

  test('retryNow resets everything and tries immediately', () async {
    socket.authorized = false;
    await listener.start();
    health
      ..recordFailure()
      ..recordFailure()
      ..recordFailure();
    expect(health.health.value.isPaused, isTrue);

    socket.authorized = true;
    await health.retryNow();

    expect(health.health.value.consecutiveFailures, 0);
    expect(health.health.value.channelAttempts, 0);
    expect(listener.isSubscribed, isTrue);
  });

  test('leaving the foreground stops the ladder', () async {
    socket.authorized = false;
    await listener.start();
    final joinsSoFar = socket.joins;

    health.setForeground(false);
    await settle(3);

    expect(socket.joins, joinsSoFar, reason: 'no background retries');
    expect(health.health.value.channelAttempts, 0);
  });

  test('returning to the foreground attempts a join immediately', () async {
    health.setForeground(false);
    final before = socket.joins;

    health.setForeground(true);

    expect(socket.joins, before + 1);
  });

  test('losing the link stops the ladder, and regaining it re-joins', () async {
    health.setOnline(false);
    socket.authorized = false;
    await listener.start();
    final joins = socket.joins;
    await settle(2);
    expect(socket.joins, joins, reason: 'the ladder is off while offline');

    socket.authorized = true;
    health.setOnline(true);
    expect(socket.joins, joins + 1);
  });
}
