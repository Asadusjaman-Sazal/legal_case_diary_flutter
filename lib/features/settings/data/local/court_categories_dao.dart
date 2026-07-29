/// Court categories DAO: local data access for court categories.
/// Implemented in Task 05 Phase 1.
library;

import 'package:drift/drift.dart';

import '../../../../database/app_database.dart';

/// Data Access Object for [CourtCategories] table operations.
class CourtCategoriesDao {
  /// Creates a DAO backed by [db].
  CourtCategoriesDao(this.db);

  /// The Drift database instance.
  final AppDatabase db;

  /// Returns all non-deleted court categories ordered by [orderIndex].
  Future<List<CourtCategory>> getAll({int? limit, int? offset}) async {
    final query = db.select(db.courtCategories)
      ..where((row) => row.isDeleted.equals(false))
      ..orderBy([(row) => OrderingTerm(expression: row.orderIndex)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Reactive stream of all non-deleted court categories ordered by [orderIndex].
  Stream<List<CourtCategory>> watchAll({int? limit, int? offset}) {
    final query = db.select(db.courtCategories)
      ..where((row) => row.isDeleted.equals(false))
      ..orderBy([(row) => OrderingTerm(expression: row.orderIndex)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.watch();
  }

  /// Returns a court category by id, or null if not found or deleted.
  Future<CourtCategory?> getById(String id) async => (db.select(db.courtCategories)
      ..where((row) => row.id.equals(id) & row.isDeleted.equals(false)))
      .getSingleOrNull();

  /// Inserts a court category. Returns the row id.
  Future<int> insert(CourtCategoriesCompanion category) => db.into(db.courtCategories).insert(category);

  /// Updates a court category. Returns true if a row was affected.
  Future<bool> update(CourtCategoriesCompanion category) => db.update(db.courtCategories).replace(category);

  /// Soft-deletes a court category by id.
  Future<int> delete(String id, int updatedAt) => db.update(db.courtCategories).write(
        CourtCategoriesCompanion(
          id: Value(id),
          isDeleted: const Value(true),
          updatedAt: Value(updatedAt),
        ),
      );
}
