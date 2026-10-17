/// The sync orchestrator.
///
/// One instance per app, reachable through `syncServiceProvider`. It owns the
/// **single serialized FIFO** rule: never two pushes at once, and a request that
/// arrives mid-run is queued rather than run in parallel. It gates on the three
/// facts that decide whether anything may leave the device — an active
/// subscription, a connection, and the user's own sync switch on the Online Sync
/// screen (user request) — and it owns the exponential backoff (30s → 30m)
/// between failed attempts.
///
/// A drain always pushes the pending queue first. A **delta pull** follows only
/// when the request asked for one (launch, resume, reconnect), because a burst
/// of local edits should cost one radio wake-up, not thirteen.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/repository_providers.dart';
import '../database/app_database.dart';
import '../features/accounts_and_profile/data/account_mode.dart';
import '../shared/providers/database_provider.dart';
import 'connectivity_monitor.dart';
import 'entity_tables.dart';
import 'pull_worker.dart';
import 'push_worker.dart';
import 'realtime_listener.dart';
import 'recovery_lock.dart';
// The service and the provider file reference each other: the providers wire
// the listener to the service, and the service records its health and reads the
// listener's generation. Dart resolves the cycle, and neither side builds the
// other during construction — the listener's ping callback and the service's
// health reads are all lazy.
import 'sync_health.dart';
import 'sync_providers.dart';
import 'sync_metadata_dao.dart';
import 'sync_queue_dao.dart';
import 'sync_transport.dart';

/// Base delay before the first retry.
const Duration syncRetryBase = Duration(seconds: 30);

/// Longest backoff between retries.
const Duration syncRetryMax = Duration(minutes: 30);

/// The coalescing window that turns many local writes into one radio wake-up.
const Duration syncCoalescingWindow = Duration(milliseconds: 2500);

/// Device-vs-server skew past this is reported as a clock warning.
const Duration syncClockSkewThreshold = Duration(minutes: 2);

/// Delay for the [attempt]th transient failure (1-based), capped at
/// [syncRetryMax]: 30s, 1m, 2m, 4m, …
Duration syncBackoffDelay(int attempt) {
  if (attempt <= 1) return syncRetryBase;
  var delay = syncRetryBase;
  for (var i = 1; i < attempt; i++) {
    delay *= 2;
    if (delay >= syncRetryMax) return syncRetryMax;
  }
  return delay;
}

/// A user-facing sync notice, resolved to ARB copy by whoever renders it.
enum SyncNotice {
  /// The server rejected a queued action because firm permissions changed.
  permissionsChanged,

  /// The device clock is more than ~2 minutes off from the server.
  clockSkew,
}

/// What one free → premium backlog pass did.
///
/// The counts are what Sync Status (Task 19) surfaces; nothing here silently
/// clears work, so a row that needed a person still needs one afterwards.
class BacklogOutcome {
  /// Creates an outcome.
  const BacklogOutcome({
    this.compacted = 0,
    this.pushed = 0,
    this.conflicts = 0,
    this.pulled = 0,
    this.conflictPending = 0,
    this.blocked = 0,
    this.failure,
  });

  /// Queue rows the compaction pass removed.
  final int compacted;

  /// Mutations the server accepted.
  final int pushed;

  /// Mutations that conflicted or hit a tombstone.
  final int conflicts;

  /// Rows the full pull applied.
  final int pulled;

  /// Entries still frozen for review afterwards.
  final int conflictPending;

  /// Entries still permanently rejected afterwards — never force-retried.
  final int blocked;

  /// A whole-batch transport failure, when the pass could not finish.
  final SyncFailure? failure;
}

/// Owns the push and delta-pull lifecycle.
class SyncService {
  /// Creates a service bound to the app's Riverpod [ref].
  ///
  /// [transportOverride] is a test seam: production leaves it null and the
  /// service builds a [SupabaseSyncTransport] from the active client.
  SyncService(this._ref, {this.transportOverride}) {
    _ref.onDispose(_dispose);
  }

  final Ref _ref;

  /// Supplies the transport instead of the Supabase client; diagnostics/tests.
  final SyncTransport? Function()? transportOverride;

  bool _inFlight = false;
  bool _queued = false;

  /// Set by any request that asks for a delta pull, so a burst of writes that
  /// coalesces with a resume still pulls once at the end.
  bool _pullWanted = false;

  /// When the last full pull succeeded, and which Realtime generation was open
  /// then — the pair [canSkipResumePull] reads.
  DateTime? _lastSuccessfulPullAt;
  int? _lastSuccessfulPullGeneration;

  Timer? _debounce;
  Timer? _retryTimer;
  Timer? _pingTimer;
  DateTime _nextAttemptAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Rows a Realtime ping asked for, waiting for the in-flight slot.
  final Set<SyncPing> _pendingPings = <SyncPing>{};

  /// The last thing the user must be told, resolved to ARB copy by the UI.
  final ValueNotifier<SyncNotice?> notice = ValueNotifier<SyncNotice?>(null);

  /// Schedules a coalesced drain after a short window.
  ///
  /// Called on launch/resume, on reconnect and whenever the queue changes, so
  /// many quick edits become one `push_changes` call. [pull] also asks for the
  /// delta pull at the end of that run; the write-coalescing triggers leave it
  /// false, so a burst of edits costs exactly one request.
  void requestSync({bool pull = false}) {
    if (pull) _pullWanted = true;
    _debounce?.cancel();
    _debounce = Timer(syncCoalescingWindow, () => unawaited(syncNow()));
  }

  /// Runs one serialized drain: push, then the delta pull when it was asked for.
  ///
  /// [force] ignores the backoff window — used by the manual sync and by a
  /// request that arrived while a run was in flight. [pull] asks for the delta
  /// pull on this run; so does any earlier [requestSync] that asked for one.
  Future<void> syncNow({bool force = false, bool pull = false}) async {
    if (!_ref.mounted) return;
    // Outranks every other gate, `force` included: while sync is off, neither a
    // local write, a resume, a reconnect nor the screen's own button runs one.
    if (!_isSyncEnabled()) return;
    // Recorded before the in-flight check, so a pull request that arrives
    // mid-run is honoured by the run that follows it.
    if (pull) _pullWanted = true;
    if (_inFlight) {
      _queued = true;
      return;
    }
    if (!force && DateTime.now().isBefore(_nextAttemptAt)) return;

    // Claim the slot synchronously, before any await, so two calls in the same
    // microtask cannot both decide they are the runner.
    _inFlight = true;
    final wantsPull = _pullWanted;
    _pullWanted = false;
    try {
      final transport = _transport();
      if (transport == null) return;
      if (!_isOnline()) return;
      if (!await _isEntitled()) return;
      await _drain(transport, pull: wantsPull);
    } finally {
      _release();
    }
  }

  /// A Realtime ping asks for a micro pull of exactly the rows it names.
  ///
  /// The listener already coalesces one burst; this window catches two bursts
  /// arriving back to back, and the run itself takes the same single in-flight
  /// slot a drain does, so a notification can never race a push.
  void requestRealtimePull(List<SyncPing> pings) {
    if (pings.isEmpty || !_ref.mounted) return;
    _pendingPings.addAll(pings);
    _pingTimer?.cancel();
    _pingTimer = Timer(
      syncRealtimePingWindow,
      () => unawaited(_drainRealtimePings()),
    );
  }

  /// Applies the collected pings as one micro pull.
  ///
  /// A failure here is deliberately quiet: Broadcast is an ephemeral
  /// notification, not a durable event log, so the next delta pull (resume,
  /// reconnect, or the backoff retry) is what repairs the gap — and nothing is
  /// frozen, blocked or retried on its account.
  Future<void> _drainRealtimePings() async {
    if (!_ref.mounted || _pendingPings.isEmpty) return;
    // A drain owns the slot; its `_release` starts this run when it finishes.
    if (_inFlight) return;
    // Sync off means the channel is closed, so a ping can only be a leftover
    // from the moment it was switched off: hold it rather than run it, and the
    // pull the enable path asks for fetches those rows anyway.
    if (!_isSyncEnabled()) return;

    _inFlight = true;
    final pings = _pendingPings.toList(growable: false);
    _pendingPings.clear();
    try {
      final transport = _transport();
      if (transport == null) return;
      if (!_isOnline()) return;
      if (!await _isEntitled()) return;
      final db = await _ref.read(databaseProvider.future);
      if (!_ref.mounted) return;

      final puller = PullWorker(
        db: db,
        metadata: SyncMetadataDao(db),
        queue: SyncQueueDao(db),
        transport: transport,
        currentUserId: _userId(),
      );
      var applied = 0;
      for (final ping in pings) {
        final entityType = syncEntityForTable(ping.table);
        if (entityType == null) continue;
        if (await puller.pullRow(entityType, ping.id)) applied++;
      }
      if (applied > 0 && _ref.mounted) {
        // A notification that landed a row is a successful sync of its own; the
        // clock probe stays with the full pull that follows soon after.
        await _recordSyncHealth(transport, db, probeClock: false);
        _health()?.recordSuccess();
      }
    } on SyncFailure {
      // Swallowed on purpose: see the method comment. It is still a failed
      // attempt, so the header's paused indicator counts it.
      _health()?.recordFailure();
    } finally {
      _release();
    }
  }

  /// Whether a resume pull may be skipped right now.
  ///
  /// Only when **all** of these hold: a full pull has succeeded before, the
  /// same Realtime subscription has stayed open since (the listener's generation
  /// is unchanged, so no disconnect, re-join, channel error or fresh join has
  /// happened in between), and that pull is inside [syncResumeThrottle]. Elapsed
  /// time alone never skips a pull — Broadcast is an ephemeral notification, so
  /// uncertain continuity must always be repaired through REST.
  bool canSkipResumePull() {
    final lastPull = _lastSuccessfulPullAt;
    final generation = _lastSuccessfulPullGeneration;
    if (lastPull == null || generation == null) return false;
    final listener = _ref.read(realtimeListenerProvider);
    if (!listener.isSubscribed || listener.generation != generation) {
      return false;
    }
    return DateTime.now().difference(lastPull) < syncResumeThrottle;
  }

  /// The resume entry point: pull, unless continuity has been proven.
  ///
  /// A skipped pull still asks for a push-only run, so anything a local write
  /// queued while the app was away leaves immediately; with an empty queue that
  /// run makes no request at all.
  void requestResumeSync() {
    if (canSkipResumePull()) {
      requestSync();
      return;
    }
    requestSync(pull: true);
  }

  /// The pause indicator's tap: reset the backoff and retry now.
  ///
  /// It clears the service's own retry window as well as the channel's ladder,
  /// so a tap is never swallowed by the backoff the user is trying to escape.
  Future<void> retryNow() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    _nextAttemptAt = DateTime.fromMillisecondsSinceEpoch(0);
    final health = _health();
    if (health != null) await health.retryNow();
    await syncNow(force: true, pull: true);
  }

  /// The health controller, or null before the app provides one (tests).
  SyncHealthController? _health() {
    if (!_ref.mounted) return null;
    return _ref.read(syncHealthControllerProvider);
  }

  /// Frees the single in-flight slot and starts whatever was waiting on it.
  ///
  /// A Realtime micro pull goes first: it is the smaller job, and the drain it
  /// was queued behind is usually the one that triggered the ping anyway.
  void _release() {
    _inFlight = false;
    if (!_ref.mounted) return;
    if (_pendingPings.isNotEmpty) {
      unawaited(_drainRealtimePings());
      return;
    }
    if (_queued) {
      _queued = false;
      unawaited(syncNow(force: true));
    }
  }

  /// Pushes batches until the queue is empty or a failure schedules a retry,
  /// then pulls the delta when [pull] is set.
  Future<void> _drain(SyncTransport transport, {required bool pull}) async {
    final db = await _ref.read(databaseProvider.future);
    if (!_ref.mounted) return;
    final queue = SyncQueueDao(db);
    _health()?.recordRunStarted();
    // The Offline Compaction Matrix runs before every push, not just in the
    // backlog pass: a run of `pending` rows for one entity would otherwise go in
    // one batch, and the second mutation would conflict against the version the
    // first one just produced. Only `pending` rows are read, so a frozen or
    // blocked action is untouched.
    await queue.compactPending();
    final worker = PushWorker(
      db: db,
      queue: queue,
      transport: transport,
      currentUserId: _userId(),
      firmId: _firmId(),
    );

    // A bounded loop: each pass sends up to `batchSize` mutations, so this
    // clears the backlog without an unbounded loop on a pathological queue.
    for (var pass = 0; pass < 20; pass++) {
      final outcome = await worker.flushBatch();
      if (outcome.isEmpty) break;

      if (outcome.permissionRollback) {
        notice.value = SyncNotice.permissionsChanged;
      }

      final failure = outcome.failure;
      if (failure != null) {
        // The link is down; pulling would fail on the same socket. The retry
        // asks for the pull again, so nothing is lost by stopping here.
        _health()?.recordFailure();
        _scheduleBackoff(failure, outcome.maxRetryCount);
        return;
      }
    }

    if (!pull) {
      // A push-only drain is still a successful sync: stamp the instant the
      // 335-day offline check reads, without paying for a server-clock round
      // trip the pull path makes anyway.
      await _recordSyncHealth(transport, db, probeClock: false);
      _health()?.recordSuccess();
      return;
    }

    final puller = PullWorker(
      db: db,
      metadata: SyncMetadataDao(db),
      queue: queue,
      transport: transport,
      currentUserId: _userId(),
    );
    try {
      await puller.pullAll();
    } on SyncFailure catch (failure) {
      // A failed pull is a failed attempt for the header, and the retry asks
      // for the pull again, so the gap is repaired at the next window.
      _health()?.recordFailure();
      _scheduleBackoff(failure, 1);
      return;
    }
    if (!_ref.mounted) return;
    await _recordSyncHealth(transport, db);
    // The two facts the resume throttle reads, recorded together and only after
    // the pull actually committed.
    _lastSuccessfulPullAt = DateTime.now();
    _lastSuccessfulPullGeneration = _ref
        .read(realtimeListenerProvider)
        .generation;
    _health()?.recordSuccess();
  }

  /// Pushes the backlog an account accumulated while it was free, then performs
  /// a full pull.
  ///
  /// This is the free → premium upgrade path (plan §2), called by Task 21's
  /// activation signal. It compacts only the eligible `pending` rows, leaves
  /// `conflict_pending` rows for review and `blocked` rows visible rather than
  /// clearing them, pushes FK-ordered micro-batches through `push_changes`, and
  /// finishes with a pull from the minimum sentinel so the device starts from the
  /// firm's real data rather than from whatever cursors it had. It returns null
  /// when the pass could not start at all (no client, offline, not entitled).
  ///
  /// A `blocked` row is never force-retried: it is skipped by the worker and
  /// reported in the outcome, and it joins the backlog only once the user has
  /// repaired it back to `pending` (Task 19's Sync Status).
  Future<BacklogOutcome?> runBacklogPush() async {
    if (!_ref.mounted) return null;
    if (!_isSyncEnabled()) return null;
    if (_inFlight) {
      // A running drain already pushes the same queue; ask for another pass
      // rather than interleaving two batch sequences.
      _queued = true;
      return null;
    }
    _inFlight = true;
    try {
      final transport = _transport();
      if (transport == null) return null;
      if (!_isOnline()) return null;
      if (!await _isEntitled()) return null;
      final db = await _ref.read(databaseProvider.future);
      if (!_ref.mounted) return null;
      return await _runBacklog(db, transport);
    } finally {
      _release();
    }
  }

  /// One backlog pass over an already-open database.
  Future<BacklogOutcome> _runBacklog(
    AppDatabase db,
    SyncTransport transport,
  ) async {
    final queue = SyncQueueDao(db);
    final compacted = await queue.compactPending();

    final worker = PushWorker(
      db: db,
      queue: queue,
      transport: transport,
      currentUserId: _userId(),
      firmId: _firmId(),
    );
    var pushed = 0;
    var conflicts = 0;
    SyncFailure? failure;

    for (var pass = 0; pass < 20; pass++) {
      final outcome = await worker.flushBatch();
      if (outcome.isEmpty) break;
      if (outcome.permissionRollback) {
        notice.value = SyncNotice.permissionsChanged;
      }
      pushed += outcome.applied;
      conflicts += outcome.conflicts;
      failure = outcome.failure;
      if (failure != null) {
        _scheduleBackoff(failure, outcome.maxRetryCount);
        break;
      }
    }

    var pulled = 0;
    if (failure == null) {
      final puller = PullWorker(
        db: db,
        metadata: SyncMetadataDao(db),
        queue: queue,
        transport: transport,
        currentUserId: _userId(),
      );
      try {
        final pull = await puller.pullAll(fromSentinel: true);
        pulled = pull.rows;
        if (_ref.mounted) await _recordSyncHealth(transport, db);
      } on SyncFailure catch (pullFailure) {
        failure = pullFailure;
        _scheduleBackoff(pullFailure, 1);
      }
    }

    final remaining = await queue.getUnresolved();
    return BacklogOutcome(
      compacted: compacted,
      pushed: pushed,
      conflicts: conflicts,
      pulled: pulled,
      conflictPending: remaining
          .where((row) => row.state == 'conflict_pending')
          .length,
      blocked: remaining.where((row) => row.state == 'blocked').length,
      failure: failure,
    );
  }

  /// Records the per-device sync health the plan names: the last successful
  /// sync instant (the 335-day offline check reads it) and, when [probeClock],
  /// the device-vs-server clock offset, reported past
  /// [syncClockSkewThreshold].
  ///
  /// The clock probe is best-effort: a failed reading records nothing and
  /// raises nothing, because the sync itself already succeeded.
  Future<void> _recordSyncHealth(
    SyncTransport transport,
    AppDatabase db, {
    bool probeClock = true,
  }) async {
    final metadata = SyncMetadataDao(db);
    await metadata.setIntValue(
      lastSuccessfulSyncAtKey,
      DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    if (!probeClock) return;
    try {
      final server = await transport.serverTime();
      if (server == null || !_ref.mounted) return;
      final offset = server.difference(DateTime.now().toUtc());
      await metadata.setIntValue(clockOffsetMsKey, offset.inMilliseconds);
      if (offset.abs() > syncClockSkewThreshold) {
        notice.value = SyncNotice.clockSkew;
      }
    } on Object {
      // An unreadable server clock says nothing about the device's clock.
    }
  }

  void _scheduleBackoff(SyncFailure failure, int attempt) {
    if (!failure.retryable) return;
    // Whatever was missed while the link was down is repaired by a full delta
    // pull, so the retry asks for one (Realtime is notification-only, Task 19).
    _pullWanted = true;
    final delay = syncBackoffDelay(attempt);
    _nextAttemptAt = DateTime.now().add(delay);
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => unawaited(syncNow(force: true)));
  }

  SyncTransport? _transport() {
    final override = transportOverride;
    if (override != null) return override();
    final client = _ref.read(activeSupabaseClientProvider);
    return client == null ? null : SupabaseSyncTransport(client);
  }

  bool _isOnline() => _ref.read(isOnlineProvider).value ?? true;

  /// Whether the user has left sync switched on.
  ///
  /// The Online Sync screen's switch, and the **first** thing every run path
  /// asks — before the transport is even built — so a paused app makes no
  /// request and arms no retry. Nothing is remembered while it is off and
  /// nothing is lost: the enable path requests a pull, which is what catches up
  /// on everything missed.
  bool _isSyncEnabled() => _ref.read(syncEnabledProvider);

  Future<bool> _isEntitled() async {
    // The extended-offline lock pauses both workers (Task 19 Phase 5): a device
    // waiting to be reconstructed must not push its stale work or pull a delta
    // over it, so every run path asks this before it starts.
    if (await RecoveryLock(
      await _ref.read(databaseProvider.future),
    ).isRequired()) {
      return false;
    }
    try {
      return await _ref.read(premiumAccessProvider.future);
    } on Object {
      // An unreadable entitlement is not a reason to sync; stay conservative.
      return false;
    }
  }

  String _userId() => _ref.read(accountCacheUserIdProvider);

  String? _firmId() => _ref.read(accountProfileProvider).value?.firmId;

  void _dispose() {
    _debounce?.cancel();
    _retryTimer?.cancel();
    _pingTimer?.cancel();
    _pendingPings.clear();
    notice.dispose();
  }
}

/// The single app-wide sync service.
final syncServiceProvider = Provider<SyncService>(SyncService.new);
