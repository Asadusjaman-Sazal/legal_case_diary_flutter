/// Sync Status providers and the actions the screen performs on a queue entry
/// (Task 19 Phase 4).
///
/// The screen itself is presentational: it reads one stream of every unfinished
/// queue entry here and derives its filter chips and counts from it, so there is
/// exactly one query behind the whole screen and no filter can disagree with the
/// badge that opened it. Retry and Discard live here too, because both are
/// queue operations rather than widget behaviour.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/repository_providers.dart';
import '../database/app_database.dart';
import '../shared/providers/database_provider.dart';
import 'entity_tables.dart';
import 'sync_metadata_dao.dart';
import 'sync_queue_dao.dart';
import 'sync_table_bindings.dart';
import 'sync_transport.dart';

/// The four filter chips the screen offers.
enum SyncStatusFilter {
  /// Every unfinished entry — the safety net, never empty while work is held.
  all,

  /// Work the worker still intends to send (`pending`, `pushing`).
  pending,

  /// Entries frozen because a person must answer a conflict.
  conflicted,

  /// Entries the server refused permanently until the user acts.
  blocked,
}

/// Whether [row] belongs under [filter].
bool syncStatusMatches(SyncQueueRow row, SyncStatusFilter filter) =>
    switch (filter) {
      SyncStatusFilter.all => true,
      SyncStatusFilter.pending =>
        row.state == 'pending' || row.state == 'pushing',
      SyncStatusFilter.conflicted => row.state == 'conflict_pending',
      SyncStatusFilter.blocked => row.state == 'blocked',
    };

/// How many entries each filter would show, for the chip labels.
Map<SyncStatusFilter, int> syncStatusCounts(List<SyncQueueRow> rows) {
  final counts = <SyncStatusFilter, int>{
    for (final filter in SyncStatusFilter.values) filter: 0,
  };
  for (final row in rows) {
    for (final filter in SyncStatusFilter.values) {
      if (syncStatusMatches(row, filter)) counts[filter] = counts[filter]! + 1;
    }
  }
  return counts;
}

/// How many entries are held for a person: everything not merely waiting.
///
/// This is what the header badge counts. `pending` work is normal and needs no
/// badge; a `blocked` or `conflict_pending` entry is the state the user must be
/// told about, because nothing will move it without them.
int syncStatusAttentionCount(List<SyncQueueRow> rows) => rows
    .where((row) => row.state == 'blocked' || row.state == 'conflict_pending')
    .length;

/// Every unfinished queue entry, oldest first.
final syncQueueEntriesProvider = StreamProvider<List<SyncQueueRow>>((
  ref,
) async* {
  final db = await ref.watch(databaseProvider.future);
  yield* SyncQueueDao(db).watchOpen();
});

/// When this device last completed a successful sync, from the durable
/// `sync_metadata` value the pull records.
///
/// It is watched rather than read once so the line on the screen updates the
/// moment a sync lands, exactly like every other live fact here.
final syncLastSuccessProvider = StreamProvider<int?>((ref) async* {
  final db = await ref.watch(databaseProvider.future);
  await for (final raw in SyncMetadataDao(
    db,
  ).watchValue(lastSuccessfulSyncAtKey)) {
    yield raw == null ? null : int.tryParse(raw);
  }
});

/// The count the app-wide header badge shows.
final syncStatusAttentionProvider = StreamProvider<int>((ref) async* {
  final entries = ref.watch(syncQueueEntriesProvider);
  yield entries.value == null ? 0 : syncStatusAttentionCount(entries.value!);
});

/// How a Discard ended, so the screen can tell the user what it did.
enum SyncDiscardOutcome {
  /// The authoritative row was fetched and put back in the record's place.
  rolledBackFromServer,

  /// The server has no such record, so the provisional local row was removed.
  removed,

  /// Offline: the pre-mutation snapshot was restored instead.
  rolledBackLocally,

  /// Nothing was written locally; the queued mutation was simply dropped.
  dropped,
}

/// Retry and Discard for one queue entry.
///
/// Both are deliberately local-only operations. Retry returns an entry to
/// `pending` and lets the ordinary trigger send it; Discard drops the mutation
/// and restores the record from the authoritative row (or, offline, from the
/// pre-mutation snapshot a permission rejection would also use). Neither can
/// bypass the entitlement gate or the push pipeline.
class SyncStatusActions {
  /// Creates the actions over [db], its [queue] and an optional [transport].
  SyncStatusActions({required this.db, required this.queue, this.transport});

  /// The local database the record is rolled back in.
  final AppDatabase db;

  /// The outbound queue the entry is dropped from.
  final SyncQueueDao queue;

  /// The REST transport used to fetch the authoritative row; null offline or in
  /// a build with no backend, in which case Discard falls back to the snapshot.
  final SyncTransport? transport;

  /// Retry: make a `blocked` entry eligible again with a clean retry count.
  Future<void> retry(SyncQueueRow row) => queue.retry(row.id);

  /// Discard: stop retrying this mutation and put the record back to a state the
  /// server agrees with.
  ///
  /// Order matters. The entry is dropped first so nothing can retry it while the
  /// rollback runs; then the authoritative row is preferred, because it is the
  /// only source that is true for *every* operation — an update goes back to the
  /// server's version, and a provisional insert the server never received
  /// disappears, which is what discarding it means. Offline there is no such
  /// source, so the pre-mutation snapshot is restored; when even that is absent
  /// (an insert this device only ever knew about) nothing local is invented and
  /// the mutation is merely dropped.
  Future<SyncDiscardOutcome> discard(SyncQueueRow row) async {
    final binding = syncBindingFor(row.entityType);
    await queue.delete(row.id);
    if (binding == null) return SyncDiscardOutcome.dropped;

    final table = syncTableForEntity(row.entityType);
    final transport = this.transport;
    if (table != null && transport != null) {
      final probe = await _tryFetch(transport, table, row.entityId);
      if (probe != null) {
        final authoritative = probe.row;
        if (authoritative != null) {
          await binding.applyServerRow(db, authoritative);
          return SyncDiscardOutcome.rolledBackFromServer;
        }
        await binding.deleteLocal(db, row.entityId);
        return SyncDiscardOutcome.removed;
      }
    }

    final snapshot = decodeJsonObject(row.preMutationPayload);
    if (snapshot.isNotEmpty) {
      await binding.applyServerRow(db, snapshot);
      return SyncDiscardOutcome.rolledBackLocally;
    }
    return SyncDiscardOutcome.dropped;
  }

  /// Asks the server for the row, answering null when the question itself could
  /// not be asked (offline, or no client) rather than when the row is absent.
  Future<({Map<String, dynamic>? row})?> _tryFetch(
    SyncTransport transport,
    String table,
    String id,
  ) async {
    try {
      return (row: await transport.fetchRow(table, id));
    } on Exception {
      return null;
    }
  }
}

/// The actions provider, wired to the active backend when there is one.
final syncStatusActionsProvider = FutureProvider<SyncStatusActions>((
  ref,
) async {
  final db = await ref.watch(databaseProvider.future);
  final client = ref.watch(activeSupabaseClientProvider);
  return SyncStatusActions(
    db: db,
    queue: SyncQueueDao(db),
    transport: client == null ? null : SupabaseSyncTransport(client),
  );
});
