/// Conflict log DAO: local data access for rejected mutation conflicts.
/// Implemented in Task 05 Phase 1.
library;

import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Data Access Object for [ConflictLog] table operations.
class ConflictLogDao {
  /// Creates a DAO backed by [db].
  ConflictLogDao(this.db);

  /// The Drift database instance.
  final AppDatabase db;

  /// Returns all non-deleted conflict log entries ordered by [conflictAt] descending.
  Future<List<ConflictLogRow>> getAll({int? limit, int? offset}) async {
    final query = db.select(db.conflictLog)
      ..where((row) => row.isDeleted.equals(false))
      ..orderBy([(row) => OrderingTerm(expression: row.conflictAt, mode: OrderingMode.desc)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Reactive stream of all non-deleted conflict log entries.
  Stream<List<ConflictLogRow>> watchAll({int? limit, int? offset}) {
    final query = db.select(db.conflictLog)
      ..where((row) => row.isDeleted.equals(false))
      ..orderBy([(row) => OrderingTerm(expression: row.conflictAt, mode: OrderingMode.desc)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.watch();
  }

  /// Returns non-dismissed, non-deleted unresolved conflicts.
  Future<List<ConflictLogRow>> getUnresolved({int? limit, int? offset}) async {
    final query = db.select(db.conflictLog)
      ..where(
        (row) => row.isDeleted.equals(false) &
            row.isDismissed.equals(false) &
            row.resolutionState.equals('unresolved'),
      )
      ..orderBy([(row) => OrderingTerm(expression: row.conflictAt, mode: OrderingMode.desc)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Returns a conflict log entry by id, or null if not found or deleted.
  Future<ConflictLogRow?> getById(String id) async => (db.select(db.conflictLog)
      ..where((row) => row.id.equals(id) & row.isDeleted.equals(false)))
      .getSingleOrNull();

  /// Inserts a conflict log entry. Returns the row id.
  Future<int> insert(ConflictLogCompanion conflict) => db.into(db.conflictLog).insert(conflict);

  /// Updates a conflict log entry. Returns true if a row was affected.
  Future<bool> update(ConflictLogCompanion conflict) async =>
      await (db.update(db.conflictLog)..where((row) => row.id.equals(conflict.id.value))).write(conflict) > 0;

  /// Marks a conflict log entry as dismissed.
  Future<int> dismiss(String id, int updatedAt) => db.update(db.conflictLog).write(
        ConflictLogCompanion(
          id: Value(id),
          isDismissed: const Value(true),
          updatedAt: Value(updatedAt),
        ),
      );

  /// Soft-deletes a conflict log entry by id.
  Future<int> delete(String id, int updatedAt) => db.update(db.conflictLog).write(
        ConflictLogCompanion(
          id: Value(id),
          isDeleted: const Value(true),
          updatedAt: Value(updatedAt),
        ),
      );
}
