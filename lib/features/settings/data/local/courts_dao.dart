/// Courts DAO: local data access for courts.
/// Implemented in Task 05 Phase 1.
library;

import 'package:drift/drift.dart';

import '../../../../database/app_database.dart';

/// Data Access Object for [Courts] table operations.
class CourtsDao {
  /// Creates a DAO backed by [db].
  CourtsDao(this.db);

  /// The Drift database instance.
  final AppDatabase db;

  /// Returns all non-deleted courts ordered by [courtName].
  Future<List<Court>> getAll({int? limit, int? offset}) async {
    final query = db.select(db.courts)
      ..where((row) => row.isDeleted.equals(false))
      ..orderBy([(row) => OrderingTerm(expression: row.courtName)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Reactive stream of all non-deleted courts ordered by [courtName].
  Stream<List<Court>> watchAll({int? limit, int? offset}) {
    final query = db.select(db.courts)
      ..where((row) => row.isDeleted.equals(false))
      ..orderBy([(row) => OrderingTerm(expression: row.courtName)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.watch();
  }

  /// Returns non-deleted courts for a specific court category.
  Future<List<Court>> getByCategory(String courtCategoryId) async {
    final query = db.select(db.courts)
      ..where((row) => row.isDeleted.equals(false) & row.courtCategoryId.equals(courtCategoryId))
      ..orderBy([(row) => OrderingTerm(expression: row.courtName)]);
    return query.get();
  }

  /// Reactive stream of non-deleted courts for a specific court category.
  Stream<List<Court>> watchByCategory(String courtCategoryId) {
    final query = db.select(db.courts)
      ..where((row) => row.isDeleted.equals(false) & row.courtCategoryId.equals(courtCategoryId))
      ..orderBy([(row) => OrderingTerm(expression: row.courtName)]);
    return query.watch();
  }

  /// Returns non-deleted courts filtered by higher/lower court type.
  Future<List<Court>> getByHigherLower(String higherLowerCourts) async {
    final query = db.select(db.courts)
      ..where((row) => row.isDeleted.equals(false) & row.higherLowerCourts.equals(higherLowerCourts))
      ..orderBy([(row) => OrderingTerm(expression: row.courtName)]);
    return query.get();
  }

  /// Returns non-deleted courts filtered by division, district, and/or court type.
  Future<List<Court>> getByDivisionDistrict({
    String? division,
    String? district,
    String? higherLowerCourts,
  }) async {
    final query = db.select(db.courts)
      ..where((row) => row.isDeleted.equals(false));
    if (higherLowerCourts != null) {
      query.where((row) => row.higherLowerCourts.equals(higherLowerCourts));
    }
    if (division != null) {
      query.where((row) => row.division.equals(division));
    }
    if (district != null) {
      query.where((row) => row.district.equals(district));
    }
    query.orderBy([(row) => OrderingTerm(expression: row.courtName)]);
    return query.get();
  }

  /// Returns a court by id, or null if not found or deleted.
  Future<Court?> getById(String id) async => (db.select(db.courts)
      ..where((row) => row.id.equals(id) & row.isDeleted.equals(false)))
      .getSingleOrNull();

  /// Inserts a court. Returns the row id.
  Future<int> insert(CourtsCompanion court) => db.into(db.courts).insert(court);

  /// Updates a court. Returns true if a row was affected.
  Future<bool> update(CourtsCompanion court) => db.update(db.courts).replace(court);

  /// Soft-deletes a court by id.
  Future<int> delete(String id, int updatedAt) => db.update(db.courts).write(
        CourtsCompanion(
          id: Value(id),
          isDeleted: const Value(true),
          updatedAt: Value(updatedAt),
        ),
      );
}
