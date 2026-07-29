/// Sync queue DAO: local data access for outbound mutation queue.
/// Implemented in Task 05 Phase 1.
library;

import 'package:drift/drift.dart';

import '../database/app_database.dart';

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

  /// Reactive stream of all queue entries.
  Stream<List<SyncQueueRow>> watchAll({int? limit, int? offset}) {
    final query = db.select(db.syncQueue)
      ..orderBy([(row) => OrderingTerm(expression: row.createdAt)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.watch();
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
