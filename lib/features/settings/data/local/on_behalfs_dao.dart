/// On-behalfs DAO: local data access for representational roles.
/// Implemented in Task 05 Phase 1.
library;

import 'package:drift/drift.dart';

import '../../../../database/app_database.dart';

/// Data Access Object for [OnBehalfs] table operations.
class OnBehalfsDao {
  /// Creates a DAO backed by [db].
  OnBehalfsDao(this.db);

  /// The Drift database instance.
  final AppDatabase db;

  /// Returns all non-deleted on-behalf options ordered by [orderIndex].
  Future<List<OnBehalf>> getAll({int? limit, int? offset}) async {
    final query = db.select(db.onBehalfs)
      ..where((row) => row.isDeleted.equals(false))
      ..orderBy([(row) => OrderingTerm(expression: row.orderIndex)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Reactive stream of all non-deleted on-behalf options ordered by [orderIndex].
  Stream<List<OnBehalf>> watchAll({int? limit, int? offset}) {
    final query = db.select(db.onBehalfs)
      ..where((row) => row.isDeleted.equals(false))
      ..orderBy([(row) => OrderingTerm(expression: row.orderIndex)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.watch();
  }

  /// Returns non-deleted on-behalf options for a specific court category.
  Future<List<OnBehalf>> getByCategory(String courtCategoryId, {int? limit, int? offset}) async {
    final query = db.select(db.onBehalfs)
      ..where((row) => row.isDeleted.equals(false) & row.courtCategoryId.equals(courtCategoryId))
      ..orderBy([(row) => OrderingTerm(expression: row.orderIndex)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Reactive stream of non-deleted on-behalf options for a specific court category.
  Stream<List<OnBehalf>> watchByCategory(String courtCategoryId, {int? limit, int? offset}) {
    final query = db.select(db.onBehalfs)
      ..where((row) => row.isDeleted.equals(false) & row.courtCategoryId.equals(courtCategoryId))
      ..orderBy([(row) => OrderingTerm(expression: row.orderIndex)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.watch();
  }

  /// Returns an on-behalf option by id, or null if not found or deleted.
  Future<OnBehalf?> getById(String id) async => (db.select(db.onBehalfs)
      ..where((row) => row.id.equals(id) & row.isDeleted.equals(false)))
      .getSingleOrNull();

  /// Inserts an on-behalf option. Returns the row id.
  Future<int> insert(OnBehalfsCompanion onBehalf) => db.into(db.onBehalfs).insert(onBehalf);

  /// Updates an on-behalf option. Returns true if a row was affected.
  Future<bool> update(OnBehalfsCompanion onBehalf) => db.update(db.onBehalfs).replace(onBehalf);

  /// Soft-deletes an on-behalf option by id.
  Future<int> delete(String id, int updatedAt) => db.update(db.onBehalfs).write(
        OnBehalfsCompanion(
          id: Value(id),
          isDeleted: const Value(true),
          updatedAt: Value(updatedAt),
        ),
      );
}
