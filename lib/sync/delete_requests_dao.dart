/// Delete requests DAO: local data access for delete-request queue.
/// Implemented in Task 05 Phase 1.
library;

import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Data Access Object for [DeleteRequests] table operations.
class DeleteRequestsDao {
  /// Creates a DAO backed by [db].
  DeleteRequestsDao(this.db);

  /// The Drift database instance.
  final AppDatabase db;

  /// Returns all non-deleted delete requests ordered by [createdAt] descending.
  Future<List<DeleteRequest>> getAll({int? limit, int? offset}) async {
    final query = db.select(db.deleteRequests)
      ..where((row) => row.isDeleted.equals(false))
      ..orderBy([(row) => OrderingTerm(expression: row.createdAt, mode: OrderingMode.desc)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Reactive stream of all non-deleted delete requests.
  Stream<List<DeleteRequest>> watchAll({int? limit, int? offset}) {
    final query = db.select(db.deleteRequests)
      ..where((row) => row.isDeleted.equals(false))
      ..orderBy([(row) => OrderingTerm(expression: row.createdAt, mode: OrderingMode.desc)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.watch();
  }

  /// Returns non-deleted delete requests filtered by [status].
  Future<List<DeleteRequest>> getByStatus(String status, {int? limit, int? offset}) async {
    final query = db.select(db.deleteRequests)
      ..where((row) => row.isDeleted.equals(false) & row.status.equals(status))
      ..orderBy([(row) => OrderingTerm(expression: row.createdAt, mode: OrderingMode.desc)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Returns a delete request by id, or null if not found or deleted.
  Future<DeleteRequest?> getById(String id) async => (db.select(db.deleteRequests)
      ..where((row) => row.id.equals(id) & row.isDeleted.equals(false)))
      .getSingleOrNull();

  /// Inserts a delete request. Returns the row id.
  Future<int> insert(DeleteRequestsCompanion request) => db.into(db.deleteRequests).insert(request);

  /// Updates a delete request. Returns true if a row was affected.
  Future<bool> update(DeleteRequestsCompanion request) => db.update(db.deleteRequests).replace(request);

  /// Soft-deletes a delete request by id.
  Future<int> delete(String id, int updatedAt) => db.update(db.deleteRequests).write(
        DeleteRequestsCompanion(
          id: Value(id),
          isDeleted: const Value(true),
          updatedAt: Value(updatedAt),
        ),
      );
}
