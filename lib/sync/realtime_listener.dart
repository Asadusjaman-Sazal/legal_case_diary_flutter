/// The Realtime listener: notification-only push from the database.
///
/// The app never subscribes to `postgres_changes` — that ships whole rows and
/// makes Supabase evaluate RLS for every subscriber on every change. Instead a
/// database trigger sends a tiny `{table, id}` Broadcast ping to this account's
/// **private** topic: `firm:{firm_id}` for a firm member, `user:{user_id}` for an
/// individual (the server half is Task 16 Phase 3; the `realtime.messages` policy
/// authorizes the topic, and the channel is joined with `private: true`).
///
/// The listener owns exactly **one** channel and it is open only while the app is
/// in the foreground: `start()` on resume, `stop()` immediately on background or
/// screen lock, so an idle app costs zero radio (plan §12.3). It never pulls
/// anything itself — it hands the collected pings to the sync service, which does
/// a **micro delta pull** for just those rows through the same merge path as a
/// full delta pull. A notification therefore can never bypass conflict handling,
/// and losing one is harmless: the next delta pull repairs the gap.
///
/// Every transition into "subscribed" — the first join, an automatic re-join
/// after a socket drop, and a subscriber that errors and comes back — increments
/// [generation]. That is how the service proves continuity before it may skip a
/// resume pull (plan §1): equality of the generation means one uninterrupted
/// subscription since the last successful pull was recorded.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'entity_tables.dart';

/// The Broadcast event name the database trigger sends (Task 16 Phase 3).
const String syncRealtimeEvent = 'row_change';

/// How long pings are collected before they become one micro pull.
///
/// A firm-wide run of edits (an import, a bulk Quick Update) arrives as a burst
/// of frames; without this window each frame would be one REST request.
const Duration syncRealtimePingWindow = Duration(milliseconds: 400);

/// How long a join is given before it counts as failed.
const Duration syncRealtimeJoinTimeout = Duration(seconds: 10);

/// The one table a ping is never a micro pull for.
///
/// `firm_members` is a **pull-only cache** (AGENTS.md rule 4): it is not in the
/// twelve synced domain tables, so `syncEntityForTable` returns null for it and
/// the ordinary ping path would drop it. Its rows are, however, exactly the fact
/// this account's permissions and membership are derived from — so a ping for it
/// is routed to the account refresh instead, which re-reads the profile, the firm
/// and the membership in one call. That is the client half of "broadcast
/// membership revocation so connected devices enforce removal immediately"; the
/// server half is Task 20 Phase 2's `remove_firm_member` and the trigger this
/// migration attaches to `firm_members`.
const String syncRealtimeMembershipTable = 'firm_members';

/// One `{table, id}` notification.
@immutable
class SyncPing {
  /// Creates a ping.
  const SyncPing(this.table, this.id);

  /// The server table the change landed in.
  final String table;

  /// The changed row's id.
  final String id;

  @override
  bool operator ==(Object other) =>
      other is SyncPing && other.table == table && other.id == id;

  @override
  int get hashCode => Object.hash(table, id);

  @override
  String toString() => '$table:$id';
}

/// Where the channel is right now.
enum RealtimeStatus {
  /// No channel is open (backgrounded, or nobody is signed in).
  stopped,

  /// A join is in flight.
  connecting,

  /// Joined and receiving pings.
  subscribed,

  /// The last join failed; the channel is not open.
  failed,
}

/// The socket operations the listener needs.
///
/// It is an interface so the whole listener — topic choice, coalescing,
/// generation counting, lifecycle bounds — runs in a unit test with no server.
abstract class RealtimeSocket {
  /// Joins [topic] privately.
  ///
  /// [onPing] receives every `{table, id}` frame, and [onStatus] every status
  /// transition (each transition into [RealtimeStatus.subscribed] is a new
  /// subscription, including an automatic re-join). Resolves true when the join
  /// was authorized.
  Future<bool> subscribe(
    String topic, {
    required void Function(SyncPing ping) onPing,
    required void Function(RealtimeStatus status) onStatus,
  });

  /// Leaves the channel.
  Future<void> unsubscribe();
}

/// A socket for a build with no backend: every join fails, so nothing happens.
///
/// Part A installs and signed-out states land here instead of on a live channel.
class NoRealtimeSocket implements RealtimeSocket {
  /// Creates the inert socket.
  const NoRealtimeSocket();

  @override
  Future<bool> subscribe(
    String topic, {
    required void Function(SyncPing ping) onPing,
    required void Function(RealtimeStatus status) onStatus,
  }) async {
    onStatus(RealtimeStatus.stopped);
    return false;
  }

  @override
  Future<void> unsubscribe() async {}
}

/// The real socket: one private channel over the Supabase Realtime client.
class SupabaseRealtimeSocket implements RealtimeSocket {
  /// Creates a socket over [client].
  SupabaseRealtimeSocket(this._client);

  final SupabaseClient _client;

  RealtimeChannel? _channel;

  @override
  Future<bool> subscribe(
    String topic, {
    required void Function(SyncPing ping) onPing,
    required void Function(RealtimeStatus status) onStatus,
  }) async {
    await unsubscribe();

    final channel = _client.channel(
      topic,
      opts: const RealtimeChannelConfig(private: true),
    );
    channel.onBroadcast(
      event: syncRealtimeEvent,
      callback: (frame) {
        final ping = syncPingFromBroadcast(frame);
        if (ping != null) onPing(ping);
      },
    );
    _channel = channel;

    final joined = Completer<bool>();
    var wasSubscribed = false;
    channel.subscribe((status, error) {
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          // Also fires again after an automatic re-join, which is exactly why
          // the listener counts generations from this callback.
          wasSubscribed = true;
          onStatus(RealtimeStatus.subscribed);
          if (!joined.isCompleted) joined.complete(true);
        case RealtimeSubscribeStatus.closed:
          onStatus(RealtimeStatus.failed);
          if (!joined.isCompleted) joined.complete(false);
        case RealtimeSubscribeStatus.channelError:
        case RealtimeSubscribeStatus.timedOut:
          onStatus(RealtimeStatus.failed);
          if (!joined.isCompleted) joined.complete(false);
      }
    }, syncRealtimeJoinTimeout);

    final ok = await joined.future;
    if (!ok) {
      // A failed join leaves no channel behind, so the next attempt starts
      // clean rather than reusing a dead subscription.
      if (!wasSubscribed) await unsubscribe();
    }
    return ok;
  }

  @override
  Future<void> unsubscribe() async {
    final channel = _channel;
    _channel = null;
    if (channel == null) return;
    try {
      await _client.removeChannel(channel);
    } on Object {
      // Already gone, or the socket is closed: nothing left to remove.
    }
  }
}

/// Reads a `{table, id}` ping out of a Broadcast frame.
///
/// The frame nests the trigger's payload (`{type, event, payload: {table, id}}`),
/// but a payload that is already the trigger's object is accepted too, so the
/// parse cannot depend on which of the two shapes the client delivers.
SyncPing? syncPingFromBroadcast(Map<String, dynamic> frame) {
  final inner = frame['payload'];
  final body = inner is Map ? Map<String, dynamic>.from(inner) : frame;
  final table = body['table'];
  final id = body['id'];
  if (table is String && id is String && table.isNotEmpty && id.isNotEmpty) {
    return SyncPing(table, id);
  }
  return null;
}

/// Keeps at most one private channel open while the app is in the foreground.
class RealtimeListener {
  /// Creates a listener over [socket].
  ///
  /// [topic] resolves the private topic at each [start] and returns null when
  /// nobody is signed in (nothing to subscribe to). [onPings] receives the
  /// coalesced batch; it is not awaited, so a slow pull can never block the
  /// socket.
  ///
  /// [onMembershipChange] fires at most once per window when a ping for
  /// [syncRealtimeMembershipTable] arrives, however many of them there were: the
  /// reaction to a membership or permission change is one account refresh, not
  /// one per frame.
  RealtimeListener({
    required this.socket,
    required this.topic,
    required this.onPings,
    this.onMembershipChange,
    this.pingWindow = syncRealtimePingWindow,
  });

  /// The socket operations.
  final RealtimeSocket socket;

  /// Resolves the private topic, or null to stay unsubscribed.
  final String? Function() topic;

  /// Receives each coalesced batch of pings.
  final void Function(List<SyncPing> pings) onPings;

  /// Fires when a membership/permission ping arrived; null in builds that
  /// handle only the domain tables.
  final void Function()? onMembershipChange;

  /// How long pings are collected before they are handed over.
  final Duration pingWindow;

  /// The observable status, for the header's sync state.
  final ValueNotifier<RealtimeStatus> status =
      ValueNotifier<RealtimeStatus>(RealtimeStatus.stopped);

  final Set<SyncPing> _pending = <SyncPing>{};

  /// Set by a membership ping, cleared when it is handed over.
  bool _membershipPending = false;

  Timer? _flushTimer;
  bool _starting = false;
  bool _wantOpen = false;
  bool _subscribed = false;
  int _generation = 0;

  /// How many subscriptions have been opened successfully.
  ///
  /// Monotonic for the life of the listener; a change means the current
  /// subscription is not the one that was open when a pull last succeeded.
  int get generation => _generation;

  /// Whether a channel is open and receiving right now.
  bool get isSubscribed => _subscribed;

  /// Opens the channel if it is not already open.
  ///
  /// Safe to call on every resume and on every profile refresh: a second call
  /// while subscribed is a no-op, and a call while a join is still in flight is
  /// ignored rather than racing the first one.
  Future<void> start() async {
    if (_subscribed || _starting) return;
    final resolved = topic();
    if (resolved == null) {
      _setStatus(RealtimeStatus.stopped);
      return;
    }

    _wantOpen = true;
    _starting = true;
    _setStatus(RealtimeStatus.connecting);
    try {
      final ok = await socket.subscribe(
        resolved,
        onPing: _accept,
        onStatus: _onSocketStatus,
      );
      if (!_wantOpen) {
        // Backgrounded while the join was in flight.
        _subscribed = false;
        await socket.unsubscribe();
        _setStatus(RealtimeStatus.stopped);
        return;
      }
      if (!ok) {
        _subscribed = false;
        _setStatus(RealtimeStatus.failed);
        return;
      }
      // The socket already reported `subscribed` through _onSocketStatus, which
      // incremented the generation; only the status is confirmed here.
      _subscribed = true;
    } on Object {
      _subscribed = false;
      _setStatus(RealtimeStatus.failed);
    } finally {
      _starting = false;
    }
  }

  /// Closes the channel and drops anything still waiting to be handed over.
  Future<void> stop() async {
    _wantOpen = false;
    _flushTimer?.cancel();
    _flushTimer = null;
    _pending.clear();
    _membershipPending = false;
    _subscribed = false;
    try {
      await socket.unsubscribe();
    } on Object {
      // Closing is best-effort: the socket may already be gone.
    }
    _setStatus(RealtimeStatus.stopped);
  }

  /// Hands over whatever has been collected, without waiting for the window.
  ///
  /// The service calls this when a full drain is about to run anyway, so a ping
  /// that arrived just before it is not pulled twice.
  void flushPending() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _handOver();
  }

  /// Releases the listeners.
  void dispose() {
    _flushTimer?.cancel();
    status.dispose();
  }

  void _onSocketStatus(RealtimeStatus next) {
    if (next == RealtimeStatus.subscribed) {
      // Every successful join is a new generation, including an automatic
      // re-join after a socket drop: continuity cannot be assumed across it.
      if (!_subscribed) _generation++;
      _subscribed = true;
    } else {
      _subscribed = false;
    }
    _setStatus(next);
  }

  void _accept(SyncPing ping) {
    // The membership ping is the one table that is routed rather than pulled:
    // it is what the account's own permissions and firm mode are derived from.
    if (ping.table == syncRealtimeMembershipTable) {
      if (onMembershipChange == null) return;
      _membershipPending = true;
      _armFlush();
      return;
    }
    // A table outside the twelve synced ones (a pull-only cache, a preference, a
    // server-managed row) is never pulled on a notification.
    if (syncEntityForTable(ping.table) == null) return;
    _pending.add(ping);
    _armFlush();
  }

  void _armFlush() {
    _flushTimer ??= Timer(pingWindow, () {
      _flushTimer = null;
      _handOver();
    });
  }

  void _handOver() {
    final pings = _pending.isEmpty
        ? const <SyncPing>[]
        : _pending.toList(growable: false);
    final membership = _membershipPending;
    _pending.clear();
    _membershipPending = false;
    if (membership) onMembershipChange?.call();
    if (pings.isNotEmpty) onPings(pings);
  }

  void _setStatus(RealtimeStatus next) {
    if (status.value != next) status.value = next;
  }
}
