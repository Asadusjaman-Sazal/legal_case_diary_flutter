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

import 'dart:convert';

import '../database/app_database.dart';
import 'entity_tables.dart';
import 'sync_conflict_log.dart';
import 'sync_metadata_dao.dart';
import 'sync_queue_dao.dart';
import 'sync_table_bindings.dart';
import 'sync_transport.dart';

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
    return PullOutcome(
      tables: syncPullTablesInDependencyOrder.length,
      rows: rows,
      conflicts: conflicts,
    );
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
      final target = next != null &&
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

    await writeConflictLog(
      db: db,
      queue: queue,
      currentUserId: currentUserId,
      entityType: entityType,
      entityId: id,
      mutationId: pending.mutationId,
      baseVersion: pending.baseVersion ?? 0,
      basePayload: pending.basePayload,
      submittedPayload: pending.payload,
      changedFields: pending.changedFields,
      serverVersion: _int(row['version']) ?? 0,
      serverPayload: jsonEncode(row),
      conflictAt: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    await queue.freezeEntity(
      entityType,
      id,
      error: 'The server has a newer version of this record.',
    );
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

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
