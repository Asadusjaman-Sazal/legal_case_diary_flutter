/// Realtime listener tests — Task 19 Phase 1.
///
/// The socket is faked, so the whole listener — topic choice, coalescing, the
/// connection generation, the foreground-only lifecycle — is exercised with no
/// server and no WebSocket.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/sync/realtime_listener.dart';

/// A socket the test drives by hand.
class FakeSocket implements RealtimeSocket {
  /// Topics joined, in order.
  final List<String> subscribed = <String>[];

  /// How many times the channel was left.
  int unsubscribes = 0;

  /// Whether a join succeeds.
  bool authorized = true;

  /// When true the join never answers, so `start()` stays in flight.
  bool hang = false;

  void Function(SyncPing ping)? onPing;
  void Function(RealtimeStatus status)? onStatus;

  @override
  Future<bool> subscribe(
    String topic, {
    required void Function(SyncPing ping) onPing,
    required void Function(RealtimeStatus status) onStatus,
  }) async {
    subscribed.add(topic);
    this.onPing = onPing;
    this.onStatus = onStatus;
    if (hang) return false;
    onStatus(RealtimeStatus.subscribed);
    return authorized;
  }

  @override
  Future<void> unsubscribe() async {
    unsubscribes++;
    onPing = null;
  }

  /// Emits a ping as if it arrived over the socket.
  void emit(SyncPing ping) => onPing?.call(ping);
}

void main() {
  const shortWindow = Duration(milliseconds: 20);

  late FakeSocket socket;
  late List<List<SyncPing>> batches;
  late int membershipEvents;
  late int deviceEvents;
  late int subscribedEvents;
  late RealtimeListener listener;

  setUp(() {
    socket = FakeSocket();
    batches = <List<SyncPing>>[];
    membershipEvents = 0;
    deviceEvents = 0;
    subscribedEvents = 0;
    listener = RealtimeListener(
      socket: socket,
      topic: () => 'firm:f1',
      onPings: batches.add,
      onMembershipChange: () => membershipEvents++,
      onDeviceChanged: () => deviceEvents++,
      onSubscribed: () => subscribedEvents++,
      pingWindow: shortWindow,
    );
  });

  /// Waits out the coalescing window and the hand-over it schedules.
  Future<void> settle() =>
      Future<void>.delayed(shortWindow + const Duration(milliseconds: 30));

  test('start joins the private topic once and counts a generation', () async {
    await listener.start();

    expect(socket.subscribed, <String>['firm:f1']);
    expect(listener.isSubscribed, isTrue);
    expect(listener.generation, 1);
    expect(listener.status.value, RealtimeStatus.subscribed);
  });

  test('start while subscribed does not open a second channel', () async {
    await listener.start();
    await listener.start();

    expect(socket.subscribed, hasLength(1));
    expect(listener.generation, 1);
  });

  test('a ping for a synced table is handed over once, coalesced', () async {
    await listener.start();

    socket
      ..emit(const SyncPing('courts', 'c1'))
      ..emit(const SyncPing('courts', 'c1'))
      ..emit(const SyncPing('cases', 'k1'));
    await settle();

    expect(batches, hasLength(1));
    expect(batches.single, hasLength(2), reason: 'duplicates collapse');
    expect(batches.single.map((ping) => ping.table).toSet(), <String>{
      'courts',
      'cases',
    });
  });

  test('a ping outside the twelve synced tables is dropped', () async {
    await listener.start();

    socket
      ..emit(const SyncPing('profiles', 'u1'))
      ..emit(const SyncPing('firms', 'f1'));
    await settle();

    expect(batches, isEmpty);
    expect(membershipEvents, 0, reason: 'a pull-only cache is not membership');
  });

  test('a membership ping is routed, never handed over as a pull', () async {
    await listener.start();

    socket.emit(const SyncPing('firm_members', 'user-2'));
    await settle();

    expect(membershipEvents, 1);
    expect(
      batches,
      isEmpty,
      reason:
          'firm_members is not in the twelve synced tables; a pull for it '
          'would be dropped anyway',
    );
  });

  test('a burst of membership pings is one refresh', () async {
    await listener.start();

    socket
      ..emit(const SyncPing('firm_members', 'user-2'))
      ..emit(const SyncPing('firm_members', 'user-3'))
      ..emit(const SyncPing('firm_members', 'user-2'));
    await settle();

    expect(membershipEvents, 1);
  });

  test('a membership ping and a row ping both travel', () async {
    await listener.start();

    socket
      ..emit(const SyncPing('firm_members', 'user-2'))
      ..emit(const SyncPing('cases', 'k1'));
    await settle();

    expect(membershipEvents, 1);
    expect(batches.single.single.table, 'cases');
  });

  test('a device ping checks the gate, never the sync pull', () async {
    await listener.start();
    socket.emit(const SyncPing('user_devices', 'd1'));
    await settle();

    expect(deviceEvents, 1);
    expect(batches, isEmpty);
    expect(membershipEvents, 0);
  });

  test('a burst of device pings is one check', () async {
    await listener.start();
    socket.emit(const SyncPing('user_devices', 'd1'));
    socket.emit(const SyncPing('user_devices', 'd2'));
    socket.emit(const SyncPing('user_devices', 'd3'));
    await settle();

    expect(deviceEvents, 1);
    expect(batches, isEmpty);
  });

  test('a pending device ping is dropped when the channel closes', () async {
    await listener.start();
    socket.emit(const SyncPing('user_devices', 'd1'));
    await listener.stop();
    await settle();

    expect(deviceEvents, 0);
  });

  test(
    'every successful join checks the device, including a re-join',
    () async {
      await listener.start();
      expect(subscribedEvents, 1);

      socket.onStatus!(RealtimeStatus.failed);
      await listener.start();
      expect(subscribedEvents, 2);

      // A duplicate subscribed callback for the same join is not a new join.
      socket.onStatus!(RealtimeStatus.subscribed);
      expect(subscribedEvents, 2);
    },
  );

  test(
    'a membership ping is still coalescing when the channel closes',
    () async {
      await listener.start();

      socket.emit(const SyncPing('firm_members', 'user-2'));
      // stop() clears whatever the window was still holding, the membership ping
      // included: nothing is acted on after the channel is gone.
      await listener.stop();
      await settle();

      expect(membershipEvents, 0);
    },
  );

  test(
    'stop leaves the channel, drops pending pings and forgets the join',
    () async {
      await listener.start();
      socket.emit(const SyncPing('courts', 'c1'));

      await listener.stop();
      await settle();

      expect(socket.unsubscribes, greaterThanOrEqualTo(1));
      expect(listener.isSubscribed, isFalse);
      expect(listener.status.value, RealtimeStatus.stopped);
      expect(batches, isEmpty, reason: 'a backgrounded app pulls nothing');
    },
  );

  test(
    'a re-join is a new generation, so continuity is never assumed',
    () async {
      await listener.start();
      expect(listener.generation, 1);

      // The socket drops and rejoins on its own, which reports `subscribed`
      // again through the same callback.
      socket.onStatus!(RealtimeStatus.failed);
      expect(listener.isSubscribed, isFalse);
      socket.onStatus!(RealtimeStatus.subscribed);

      expect(listener.generation, 2);
      expect(listener.isSubscribed, isTrue);
    },
  );

  test('a failed join reports failed and leaves nothing subscribed', () async {
    socket.authorized = false;

    await listener.start();

    expect(listener.isSubscribed, isFalse);
    expect(listener.status.value, RealtimeStatus.failed);
    expect(listener.generation, 1, reason: 'the join did report subscribed');
  });

  test('no signed-in account means no channel', () async {
    final anonymous = RealtimeListener(
      socket: socket,
      topic: () => null,
      onPings: batches.add,
      pingWindow: shortWindow,
    );

    await anonymous.start();

    expect(socket.subscribed, isEmpty);
    expect(anonymous.status.value, RealtimeStatus.stopped);
  });

  test('a backgrounded stop during a join closes what it opened', () async {
    socket.hang = true;
    final opening = listener.start();
    await listener.stop();
    await opening;

    expect(listener.isSubscribed, isFalse);
    expect(listener.status.value, RealtimeStatus.stopped);
  });

  group('syncPingFromBroadcast', () {
    test('reads the trigger payload out of a nested frame', () {
      final ping = syncPingFromBroadcast(<String, dynamic>{
        'type': 'broadcast',
        'event': 'row_change',
        'payload': <String, dynamic>{'table': 'cases', 'id': 'k1'},
      });
      expect(ping, const SyncPing('cases', 'k1'));
    });

    test('accepts a frame that is already the payload', () {
      expect(
        syncPingFromBroadcast(<String, dynamic>{'table': 'notes', 'id': 'n1'}),
        const SyncPing('notes', 'n1'),
      );
    });

    test('rejects anything without a table and id', () {
      expect(syncPingFromBroadcast(<String, dynamic>{}), isNull);
      expect(
        syncPingFromBroadcast(<String, dynamic>{'table': 'cases'}),
        isNull,
      );
      expect(
        syncPingFromBroadcast(<String, dynamic>{'payload': 'nope'}),
        isNull,
      );
    });
  });
}
