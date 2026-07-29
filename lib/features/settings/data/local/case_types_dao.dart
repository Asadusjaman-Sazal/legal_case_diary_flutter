/// Case types DAO: local data access for case types.
/// Implemented in Task 05 Phase 1.
library;

import 'package:drift/drift.dart';

import '../../../../database/app_database.dart';

/// Data Access Object for [CaseTypes] table operations.
class CaseTypesDao {
  /// Creates a DAO backed by [db].
  CaseTypesDao(this.db);

  /// The Drift database instance.
  final AppDatabase db;

  /// Returns all non-deleted case types ordered by [orderIndex].
  Future<List<CaseType>> getAll({int? limit, int? offset}) async {
    final query = db.select(db.caseTypes)
      ..where((row) => row.isDeleted.equals(false))
      ..orderBy([(row) => OrderingTerm(expression: row.orderIndex)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Reactive stream of all non-deleted case types ordered by [orderIndex].
  Stream<List<CaseType>> watchAll({int? limit, int? offset}) {
    final query = db.select(db.caseTypes)
      ..where((row) => row.isDeleted.equals(false))
      ..orderBy([(row) => OrderingTerm(expression: row.orderIndex)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.watch();
  }

  /// Returns non-deleted case types for a specific court category.
  Future<List<CaseType>> getByCategory(String courtCategoryId, {int? limit, int? offset}) async {
    final query = db.select(db.caseTypes)
      ..where((row) => row.isDeleted.equals(false) & row.courtCategoryId.equals(courtCategoryId))
      ..orderBy([(row) => OrderingTerm(expression: row.orderIndex)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Reactive stream of non-deleted case types for a specific court category.
  Stream<List<CaseType>> watchByCategory(String courtCategoryId, {int? limit, int? offset}) {
    final query = db.select(db.caseTypes)
      ..where((row) => row.isDeleted.equals(false) & row.courtCategoryId.equals(courtCategoryId))
      ..orderBy([(row) => OrderingTerm(expression: row.orderIndex)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.watch();
  }

  /// Returns a case type by id, or null if not found or deleted.
  Future<CaseType?> getById(String id) async => (db.select(db.caseTypes)
      ..where((row) => row.id.equals(id) & row.isDeleted.equals(false)))
      .getSingleOrNull();

  /// Inserts a case type. Returns the row id.
  Future<int> insert(CaseTypesCompanion caseType) => db.into(db.caseTypes).insert(caseType);

  /// Updates a case type. Returns true if a row was affected.
  Future<bool> update(CaseTypesCompanion caseType) => db.update(db.caseTypes).replace(caseType);

  /// Soft-deletes a case type by id.
  Future<int> delete(String id, int updatedAt) => db.update(db.caseTypes).write(
        CaseTypesCompanion(
          id: Value(id),
          isDeleted: const Value(true),
          updatedAt: Value(updatedAt),
        ),
      );
}
