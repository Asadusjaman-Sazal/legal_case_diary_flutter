/// Firms DAO: local read-only cache for firm records.
/// Implemented in Task 05 Phase 1.
library;

import 'package:drift/drift.dart';

import '../../../../database/app_database.dart';

/// Data Access Object for [Firms] pull-only cache operations.
class FirmsDao {
  /// Creates a DAO backed by [db].
  FirmsDao(this.db);

  /// The Drift database instance.
  final AppDatabase db;

  /// Returns all cached firms ordered by [name].
  Future<List<Firm>> getAll({int? limit, int? offset}) async {
    final query = db.select(db.firms)
      ..orderBy([(row) => OrderingTerm(expression: row.name)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Reactive stream of all cached firms ordered by [name].
  Stream<List<Firm>> watchAll({int? limit, int? offset}) {
    final query = db.select(db.firms)
      ..orderBy([(row) => OrderingTerm(expression: row.name)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.watch();
  }

  /// Returns a firm by id, or null if not found.
  Future<Firm?> getById(String id) async => (db.select(db.firms)
      ..where((row) => row.id.equals(id)))
      .getSingleOrNull();

  /// Inserts or replaces a cached firm.
  Future<int> upsert(FirmsCompanion firm) async => db.into(db.firms).insert(
        firm,
        onConflict: DoUpdate((_) => firm),
      );

  /// Deletes a cached firm by id.
  Future<int> delete(String id) async => (db.delete(db.firms)
      ..where((row) => row.id.equals(id)))
      .go();
}
