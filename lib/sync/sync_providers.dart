/// Sync-facing Riverpod providers.
///
/// The service itself lives in `sync_service.dart`; this file exposes the small
/// reactive facts the trigger scope needs without leaking Drift into widgets.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/repository_providers.dart';
import '../database/app_database.dart';
import '../features/accounts_and_profile/data/account_mode.dart';
import '../features/auth/presentation/auth_viewmodel.dart';
import '../shared/providers/database_provider.dart';
import 'conflict_log_dao.dart';
import 'conflict_resolution.dart';
import 'realtime_listener.dart';
import 'sync_health.dart';
import 'sync_queue_dao.dart';
import 'sync_service.dart';

/// The app's single Realtime listener.
///
/// One channel for the whole app, on this account's private topic:
/// `firm:{firm_id}` for a firm member, `user:{user_id}` for an individual. The
/// topic is resolved at each start from the cached profile and the signed-in
/// identity, so joining or leaving a firm — or signing out — changes the topic
/// without a second subscription. **Nobody signed in means no channel**, and a
/// build with no backend gets the inert socket rather than an error.
final realtimeListenerProvider = Provider<RealtimeListener>((ref) {
  final client = ref.watch(activeSupabaseClientProvider);
  final listener = RealtimeListener(
    socket: client == null
        ? const NoRealtimeSocket()
        : SupabaseRealtimeSocket(client),
    topic: () {
      final identity = ref.read(authIdentityProvider);
      if (identity == null) return null;
      final firmId = ref.read(accountProfileProvider).value?.firmId;
      if (firmId != null && firmId.isNotEmpty) return 'firm:$firmId';
      return 'user:${identity.userId}';
    },
    onPings: (pings) => ref.read(syncServiceProvider).requestRealtimePull(pings),
    // A membership or permission change is not a row to pull: it changes what
    // this account *is* and what it may do. The one refresh entry point re-reads
    // the profile, the firm and the membership together — which is also how a
    // removal is noticed (the profile's `firm_id` goes null while the cached
    // membership row is still there).
    onMembershipChange: () => unawaited(ref.read(accountRefreshProvider)()),
  );
  ref.onDispose(listener.dispose);
  return listener;
});

/// The app's sync health, and the channel's reconnect ladder.
///
/// It watches [realtimeListenerProvider] and is read lazily by the service, so
/// neither owns the other: the service reports outcomes in, the header renders
/// the state out.
final syncHealthControllerProvider = Provider<SyncHealthController>((ref) {
  final controller = SyncHealthController(
    listener: ref.watch(realtimeListenerProvider),
  )..attach();
  ref.onDispose(controller.dispose);
  return controller;
});

/// The health state as a stream, so a widget can `watch` it like any provider.
final syncHealthProvider = StreamProvider<SyncHealth>((ref) {
  final notifier = ref.watch(syncHealthControllerProvider).health;
  final changes = StreamController<SyncHealth>();
  void push() => changes.add(notifier.value);
  notifier.addListener(push);
  ref.onDispose(() {
    notifier.removeListener(push);
    changes.close();
  });
  push();
  return changes.stream;
});

/// The last thing the user must be told about sync, live.
///
/// `SyncService.notice` is a plain `ValueNotifier` so the engine can raise it
/// without knowing about widgets; this is the widget-facing stream. It has no
/// consumer in `lib/` until Task 20 Phase 2, which is why the banner that reads
/// it lives beside the conflict banner and is mounted in the same two places.
final syncNoticeProvider = StreamProvider<SyncNotice?>((ref) {
  final notice = ref.watch(syncServiceProvider).notice;
  final changes = StreamController<SyncNotice?>();
  void push() => changes.add(notice.value);
  notice.addListener(push);
  ref.onDispose(() {
    notice.removeListener(push);
    changes.close();
  });
  push();
  return changes.stream;
});

/// The conflicts still waiting for a person, newest first.
///
/// The app-wide banner watches this. The list shrinks only when a resolution is
/// written — `resolution_state` leaves `unresolved` — so a dismissal or the
/// passage of time never makes a conflict look answered (Task 19 Phase 3).
final unresolvedConflictsProvider =
    StreamProvider<List<ConflictLogRow>>((ref) async* {
  final db = await ref.watch(databaseProvider.future);
  yield* ConflictLogDao(db).watchUnresolved();
});

/// One conflict by id, live, for the Review Conflict screen.
final conflictByIdProvider =
    StreamProvider.family<ConflictLogRow?, String>((ref, id) async* {
  final db = await ref.watch(databaseProvider.future);
  yield* (db.select(db.conflictLog)..where((row) => row.id.equals(id)))
      .watchSingleOrNull();
});

/// The one resolver the UI answers conflicts through.
///
/// It is the same class the push and pull workers use, so a choice made on the
/// Review screen takes exactly the path an automatic rebase would.
final conflictResolverProvider = FutureProvider<ConflictResolver>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return ConflictResolver(
    db: db,
    queue: SyncQueueDao(db),
    currentUserId: ref.watch(accountCacheUserIdProvider),
  );
});

/// Whether this app run is allowed to sync: the Online Sync screen's own
/// switch.
///
/// It is deliberately **not** persisted. The request is a *temporary* pause, so
/// the flag lives in memory for the length of the process — a `NotifierProvider`
/// is never auto-disposed, so nothing but the switch or the end of the process
/// clears it — and a fresh launch always starts with sync on. Everything that
/// touches the network asks it: the three run paths in `SyncService` and the
/// Realtime channel in `SyncTriggerScope`.
class SyncEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  /// Turns sync on or off for this app run.
  void setEnabled(bool enabled) {
    if (state == enabled) return;
    state = enabled;
  }
}

/// The switch itself: read by the engine on every run, written by the screen.
final syncEnabledProvider = NotifierProvider<SyncEnabledNotifier, bool>(
  SyncEnabledNotifier.new,
);

/// The number of queue entries still waiting to be pushed.
///
/// It counts only `pending`, so the worker's own `pending -> pushing ->
/// resolved` churn does not look like new work.
final syncQueuePendingCountProvider = StreamProvider<int>((ref) async* {
  final db = await ref.watch(databaseProvider.future);
  yield* (db.select(db.syncQueue)
        ..where((row) => row.state.equals('pending')))
      .watch()
      .map((rows) => rows.length);
});
