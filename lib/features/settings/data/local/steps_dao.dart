/// Steps DAO: local data access for procedural steps.
/// Implemented in Task 05 Phase 1.
library;

import 'package:drift/drift.dart';

import '../../../../database/app_database.dart';

/// Data Access Object for [Steps] table operations.
class StepsDao {
  /// Creates a DAO backed by [db].
  StepsDao(this.db);

  /// The Drift database instance.
  final AppDatabase db;

  /// Returns all non-deleted steps ordered by [orderIndex].
  Future<List<Step>> getAll({int? limit, int? offset}) async {
    final query = db.select(db.steps)
      ..where((row) => row.isDeleted.equals(false))
      ..orderBy([(row) => OrderingTerm(expression: row.orderIndex)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Reactive stream of all non-deleted steps ordered by [orderIndex].
  Stream<List<Step>> watchAll({int? limit, int? offset}) {
    final query = db.select(db.steps)
      ..where((row) => row.isDeleted.equals(false))
      ..orderBy([(row) => OrderingTerm(expression: row.orderIndex)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.watch();
  }

  /// Returns non-deleted steps for a specific court category ordered by [orderIndex].
  Future<List<Step>> getByCategory(String courtCategoryId, {int? limit, int? offset}) async {
    final query = db.select(db.steps)
      ..where((row) => row.isDeleted.equals(false) & row.courtCategoryId.equals(courtCategoryId))
      ..orderBy([(row) => OrderingTerm(expression: row.orderIndex)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Reactive stream of non-deleted steps for a specific court category.
  Stream<List<Step>> watchByCategory(String courtCategoryId, {int? limit, int? offset}) {
    final query = db.select(db.steps)
      ..where((row) => row.isDeleted.equals(false) & row.courtCategoryId.equals(courtCategoryId))
      ..orderBy([(row) => OrderingTerm(expression: row.orderIndex)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.watch();
  }

  /// Returns a step by id, or null if not found or deleted.
  Future<Step?> getById(String id) async => (db.select(db.steps)
      ..where((row) => row.id.equals(id) & row.isDeleted.equals(false)))
      .getSingleOrNull();

  /// Inserts a step. Returns the row id.
  Future<int> insert(StepsCompanion step) => db.into(db.steps).insert(step);

  /// Updates a step. Returns true if a row was affected.
  Future<bool> update(StepsCompanion step) => db.update(db.steps).replace(step);

  /// Soft-deletes a step by id.
  Future<int> delete(String id, int updatedAt) => db.update(db.steps).write(
        StepsCompanion(
          id: Value(id),
          isDeleted: const Value(true),
          updatedAt: Value(updatedAt),
        ),
      );
}
