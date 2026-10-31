/// The delta pull: one page at a time, one composite cursor per table.
///
/// The plan's rule is that a pull may replay rows but may never skip one, so
/// every page is committed to Drift **and** its `(server_updated_at, id)` cursor
/// advanced in a single transaction. The cursor is filtered on the
/// trigger-assigned `server_updated_at` only — never on the client's
/// `updated_at` — and paged ascending by both columns until a page comes back
/// short, which completes the table without inventing a device-clock cursor.
///
/// A pulled row that intersects local work that has not reached the server is
/// **never** allowed to overwrite it: the entity is frozen (`conflict_pending`)
/// and the authoritative row is recorded in `conflict_log` as `server_payload`
/// for the review UI (Task 19). A pulled tombstone is the one case that always
/// applies, because hiding a deleted record is the whole point of it.
library;

import '../database/app_database.dart';
import 'conflict_resolution.dart';
import 'entity_tables.dart';
import 'sync_metadata_dao.dart';
import 'sync_queue_dao.dart';
import 'sync_table_bindings.dart';
import 'sync_transport.dart';

/// Pull-only cache tables: read from the server and never pushed.
///
/// They are outside [syncTableByEntityType] on purpose. A cache has no queue
/// entity, no push binding and no local mutation to reconcile, so it must not be
/// reachable from the push path at all; it only needs a cursor and an upsert.
/// `shared_case_references` is the admin-curated citation library (Phase 5).
const List<String> pullOnlyCacheTables = <String>['shared_case_references'];

/// What one delta pull did, for logging and tests.
class PullOutcome {
  /// Creates an outcome.
  const PullOutcome({this.tables = 0, this.rows = 0, this.conflicts = 0});

  /// Tables walked.
  final int tables;

  /// Rows applied (or recorded as conflicts).
  final int rows;

  /// Rows that intersected pending local work.
  final int conflicts;
}

/// Pulls the delta for every synced table, in one serialized run.
class PullWorker {
  /// Creates a worker over [db], its [metadata], the [queue] and [transport].
  PullWorker({
    required this.db,
    required this.metadata,
    required this.queue,
    required this.transport,
    required this.currentUserId,
    this.pageSize = syncPullPageSize,
  });

  /// The encrypted local database.
  final AppDatabase db;

  /// Durable cursor and sync-health storage.
  final SyncMetadataDao metadata;

  /// The outbound queue, read to know which local work is still unpublished.
  final SyncQueueDao queue;

  /// The network boundary.
  final SyncTransport transport;

  /// The authenticated account id, injected into conflict-log payloads.
  final String currentUserId;

  /// Rows per request.
  final int pageSize;

  /// Pulls every synced table.
  ///
  /// [fromSentinel] forgets each table's cursor first, so the run is a full
  /// pull; the initial sync and the post-upgrade backlog both use it.
  Future<PullOutcome> pullAll({bool fromSentinel = false}) async {
    final unresolved = await _unresolvedSnapshot();
    var rows = 0;
    var conflicts = 0;
    for (final table in syncPullTablesInDependencyOrder) {
      if (fromSentinel) await metadata.clearCursor(table);
      final result = await _pullTable(table, unresolved);
      rows += result.rows;
      conflicts += result.conflicts;
    }
    for (final table in pullOnlyCacheTables) {
      if (fromSentinel) await metadata.clearCursor(table);
      rows += await _pullCacheTable(table);
    }
    return PullOutcome(
      tables:
          syncPullTablesInDependencyOrder.length + pullOnlyCacheTables.length,
      rows: rows,
      conflicts: conflicts,
    );
  }

  /// Applies exactly one row by id — the Realtime micro pull.
  ///
  /// Returns true when the row was applied without a conflict. The cursor is
  /// deliberately **not** advanced: the next delta pull sees this row again and
  /// re-applies it (an upsert by id, so it is idempotent), and leaving the cursor
  /// alone is what guarantees a notification can never make a later pull skip a
  /// row. The merge itself is [_applyRow], the same one a paged pull uses, so a
  /// notification and a delta pull cannot disagree about a conflict.
  Future<bool> pullRow(String entityType, String id) async {
    final table = syncTableForEntity(entityType);
    final binding = syncBindingFor(entityType);
    if (table == null || binding == null) return false;

    final row = await transport.fetchRow(table, id);
    if (row == null) return false;

    final unresolved = await _unresolvedSnapshot();
    final conflict = await _applyRow(entityType, binding, row, unresolved);
    return !conflict;
  }

  /// Pages one table until a short page completes it.
  Future<({int rows, int conflicts})> _pullTable(
    String table,
    Map<String, SyncQueueRow> unresolved,
  ) async {
    final entityType = syncEntityForTable(table);
    final binding = entityType == null ? null : syncBindingFor(entityType);
    if (entityType == null || binding == null) return (rows: 0, conflicts: 0);

    var rows = 0;
    var conflicts = 0;
    var cursor = await metadata.getCursor(table);

    while (true) {
      final page = await transport.fetchPage(
        table,
        sinceTime: cursor?.time,
        sinceId: cursor?.id,
        limit: pageSize,
      );
      if (page.isEmpty) break;

      final next = _cursorOf(page.last);
      final target =
          next != null &&
              (cursor == null ||
                  next.time != cursor.time ||
                  next.id != cursor.id)
          ? next
          : null;

      // The page and its cursor commit together. A crash between the fetch and
      // this transaction simply replays the page on the next run.
      await db.transaction(() async {
        for (final row in page) {
          rows++;
          if (await _applyRow(entityType, binding, row, unresolved)) {
            conflicts++;
          }
        }
        if (target != null) await metadata.setCursor(table, target);
      });

      // A page with no readable `(server_updated_at, id)` cannot advance the
      // cursor, so pulling it again would loop forever. End the table instead.
      if (target == null) break;
      cursor = target;
      if (page.length < pageSize) break;
    }

    return (rows: rows, conflicts: conflicts);
  }

  /// Pages one pull-only cache table into its local table.
  ///
  /// A cache row has no local work to protect, so it is upserted by id with no
  /// conflict check; the page and its cursor commit together for the same reason
  /// a domain table's do.
  Future<int> _pullCacheTable(String table) async {
    var rows = 0;
    var cursor = await metadata.getCursor(table);

    while (true) {
      final page = await transport.fetchPage(
        table,
        sinceTime: cursor?.time,
        sinceId: cursor?.id,
        limit: pageSize,
      );
      if (page.isEmpty) break;

      final next = _cursorOf(page.last);
      final target =
          next != null &&
              (cursor == null ||
                  next.time != cursor.time ||
                  next.id != cursor.id)
          ? next
          : null;

      await db.transaction(() async {
        for (final row in page) {
          rows++;
          await _applyCacheRow(table, row);
        }
        if (target != null) await metadata.setCursor(table, target);
      });

      if (target == null) break;
      cursor = target;
      if (page.length < pageSize) break;
    }

    return rows;
  }

  /// Upserts one cache row into the local table it belongs to.
  Future<void> _applyCacheRow(String table, Map<String, dynamic> row) async {
    switch (table) {
      case 'shared_case_references':
        await db
            .into(db.sharedCaseReferences)
            .insertOnConflictUpdate(
              SharedCaseReference.fromJson(snakeToCamelMap(row)),
            );
    }
  }

  /// Applies one pulled row; returns true when it was recorded as a conflict.
  Future<bool> _applyRow(
    String entityType,
    SyncTableBinding binding,
    Map<String, dynamic> row,
    Map<String, SyncQueueRow> unresolved,
  ) async {
    final id = row['id'];
    if (id is! String || id.isEmpty) return false;

    final pending = unresolved['$entityType\u0000$id'];
    final isDeleted = row['is_deleted'] == true;
    if (pending == null) {
      await binding.applyServerRow(db, row);
      return false;
    }

    switch (pending.state) {
      case 'conflict_pending':
        // The conflict is already recorded; a newer server row must not
        // overwrite the preserved local work, but a tombstone still hides it.
        if (isDeleted) await binding.applyServerRow(db, row);
        return false;
      case 'blocked':
        // A permanent rejection is awaiting the user in Sync Status (Task 19);
        // pulling must not relabel it or overwrite what they are reviewing.
        return false;
    }

    // The same reconciliation the push worker uses: a disjoint change is rebased
    // into the queued mutation and nothing is frozen; a collision or a tombstone
    // is preserved for the Review Conflict screen. A rebased row is not a
    // conflict anyone has to look at, so it does not count as one.
    final needsReview = await ConflictResolver(
      db: db,
      queue: queue,
      currentUserId: currentUserId,
    ).reconcile(row: pending, serverRow: row);
    if (!needsReview) return false;

    if (isDeleted) await binding.applyServerRow(db, row);
    return true;
  }

  /// The still-unpublished queue entries, keyed `entityType\u0000entityId`.
  ///
  /// One query for the whole run: the pull happens right after a push, so the
  /// set is normally small, and the earliest entry is the one that was rejected.
  Future<Map<String, SyncQueueRow>> _unresolvedSnapshot() async {
    final rows = <SyncQueueRow>[...await queue.getUnresolved()]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final snapshot = <String, SyncQueueRow>{};
    for (final row in rows) {
      snapshot.putIfAbsent('${row.entityType}\u0000${row.entityId}', () => row);
    }
    return snapshot;
  }

  static SyncCursor? _cursorOf(Map<String, dynamic> row) {
    final time = row['server_updated_at'];
    final id = row['id'];
    if (time is String && id is String && time.isNotEmpty && id.isNotEmpty) {
      return SyncCursor(time: time, id: id);
    }
    return null;
  }
}
