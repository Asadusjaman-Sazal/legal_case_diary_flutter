/// Sync queue DAO: local data access for outbound mutation queue.
/// Implemented in Task 05 Phase 1.
library;

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'queue_compaction.dart';

/// Data Access Object for [SyncQueue] table operations.
class SyncQueueDao {
  /// Creates a DAO backed by [db].
  SyncQueueDao(this.db);

  /// The Drift database instance.
  final AppDatabase db;

  /// Returns all queue entries ordered by [createdAt] ascending.
  Future<List<SyncQueueRow>> getAll({int? limit, int? offset}) async {
    final query = db.select(db.syncQueue)
      ..orderBy([(row) => OrderingTerm(expression: row.createdAt)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Returns all pending queue entries ordered by [createdAt] ascending.
  Future<List<SyncQueueRow>> getPending({int? limit, int? offset}) async {
    final query = db.select(db.syncQueue)
      ..where((row) => row.state.equals('pending'))
      ..orderBy([(row) => OrderingTerm(expression: row.createdAt)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Returns queue entries for a specific entity.
  Future<List<SyncQueueRow>> getByEntity(String entityType, String entityId, {int? limit, int? offset}) async {
    final query = db.select(db.syncQueue)
      ..where((row) => row.entityType.equals(entityType) & row.entityId.equals(entityId))
      ..orderBy([(row) => OrderingTerm(expression: row.createdAt)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Returns a queue entry by its stable mutation id.
  Future<SyncQueueRow?> getByMutationId(String mutationId) async => (db.select(db.syncQueue)
      ..where((row) => row.mutationId.equals(mutationId)))
      .getSingleOrNull();

  /// Returns every entry still waiting to be pushed, oldest first.
  ///
  /// Ordering by dependency rank happens in the worker, because it depends on
  /// the entity map rather than on a column.
  Future<List<SyncQueueRow>> getPushable({int? limit}) async {
    final query = db.select(db.syncQueue)
      ..where((row) => row.state.equals('pending') | row.state.equals('pushing'))
      ..orderBy([(row) => OrderingTerm(expression: row.createdAt)]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  /// Returns every entry still awaiting a terminal result (for the Sync Status
  /// screen and the backlog review).
  Future<List<SyncQueueRow>> getUnresolved() async => (db.select(db.syncQueue)
        ..where((row) =>
            row.state.equals('pending') |
            row.state.equals('pushing') |
            row.state.equals('conflict_pending') |
            row.state.equals('blocked')))
      .get();

  /// The `entityType\u0000entityId` keys frozen on an unresolved conflict.
  ///
  /// One query, so the push worker can skip every entry of a frozen entity
  /// without asking per row.
  Future<Set<String>> getConflictPendingKeys() async {
    final rows = await (db.select(db.syncQueue)
          ..where((row) => row.state.equals('conflict_pending')))
        .get();
    return rows
        .map((row) => '${row.entityType}\u0000${row.entityId}')
        .toSet();
  }

  /// Whether any entry for the entity is frozen on a conflict.
  Future<bool> hasConflictPending(String entityType, String entityId) async {
    final row = await (db.select(db.syncQueue)
          ..where((row) =>
              row.entityType.equals(entityType) &
              row.entityId.equals(entityId) &
              row.state.equals('conflict_pending'))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  /// Records the start of one push attempt: state `pushing`, plus the attempt
  /// timestamp the Addendum requires immediately before every attempt.
  Future<int> markAttempt(int id, int attemptedAt) => updateState(
        id,
        'pushing',
        lastAttemptAt: attemptedAt,
      );

  /// Marks an entry resolved (its mutation was applied or reconciled).
  Future<int> resolve(int id) => updateState(id, 'resolved');

  /// Returns an entry to `pending` with a bumped retry count and the error.
  Future<int> incrementRetry(
    int id, {
    required int retryCount,
    required String error,
    required int attemptedAt,
  }) => updateState(
        id,
        'pending',
        retryCount: retryCount,
        lastError: error,
        lastAttemptAt: attemptedAt,
      );

  /// Stops automatic retries for an entry that needs a person.
  Future<int> block(int id, {required String error, int? retryCount}) =>
      updateState(id, 'blocked', lastError: error, retryCount: retryCount);

  /// Freezes an entry on an unresolved conflict.
  Future<int> markConflictPending(int id, {required String error}) =>
      updateState(id, 'conflict_pending', lastError: error);

  /// Freezes every still-open entry for one entity (compaction freeze).
  Future<void> freezeEntity(String entityType, String entityId,
      {required String error}) async {
    await (db.update(db.syncQueue)
          ..where((row) =>
              row.entityType.equals(entityType) &
              row.entityId.equals(entityId) &
              row.state.isNotIn(const ['resolved'])))
        .write(SyncQueueCompanion(
      state: const Value('conflict_pending'),
      lastError: Value(error),
    ));
  }

  /// Reactive stream of all queue entries.
  Stream<List<SyncQueueRow>> watchAll({int? limit, int? offset}) {
    final query = db.select(db.syncQueue)
      ..orderBy([(row) => OrderingTerm(expression: row.createdAt)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.watch();
  }

  /// Compacts every entity's accumulated `pending` rows in one transaction and
  /// returns how many rows were removed.
  ///
  /// The Offline Compaction Matrix itself is [planQueueCompaction]; this method
  /// only groups the rows by entity and applies its plan. `conflict_pending`,
  /// `blocked` and `resolved` rows are never read here, so nothing the user still
  /// has to review can be compacted away (AGENTS.md rule 4, Task 18 Phase 4).
  Future<int> compactPending() async {
    final pending = await getPending();
    final byEntity = <String, List<SyncQueueRow>>{};
    for (final row in pending) {
      byEntity
          .putIfAbsent('${row.entityType}\u0000${row.entityId}', () => [])
          .add(row);
    }

    var removed = 0;
    await db.transaction(() async {
      for (final group in byEntity.values) {
        group.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        final plan = planQueueCompaction(group);
        if (plan == null) continue;

        if (plan.dropAll) {
          for (final row in group) {
            removed += await delete(row.id);
          }
          continue;
        }

        for (final row in group) {
          if (row.id == plan.survivorId) continue;
          removed += await delete(row.id);
        }
        await (db.update(db.syncQueue)
              ..where((row) => row.id.equals(plan.survivorId!)))
            .write(SyncQueueCompanion(
          operation: Value(plan.operation!),
          payload: Value(plan.payload!),
          changedFields: Value(plan.changedFields!),
        ));
      }
    });
    return removed;
  }

  /// Inserts a queue entry. Returns the row id.
  Future<int> insert(SyncQueueCompanion row) => db.into(db.syncQueue).insert(row);

  /// Updates the state and optional diagnostics of a queue entry.
  ///
  /// Only the mutable columns are touched; the row's payload and mutation
  /// identity are preserved. Returns the number of rows updated.
  Future<int> updateState(
    int id,
    String state, {
    String? lastError,
    int? retryCount,
    int? lastAttemptAt,
  }) async {
    final companion = SyncQueueCompanion(
      state: Value(state),
      lastError: lastError == null ? const Value.absent() : Value(lastError),
      retryCount: retryCount == null ? const Value.absent() : Value(retryCount),
      lastAttemptAt: lastAttemptAt == null ? const Value.absent() : Value(lastAttemptAt),
    );
    return (db.update(db.syncQueue)
          ..where((row) => row.id.equals(id)))
        .write(companion);
  }

  /// Deletes a queue entry by id.
  Future<int> delete(int id) async => (db.delete(db.syncQueue)
      ..where((row) => row.id.equals(id)))
      .go();
}
