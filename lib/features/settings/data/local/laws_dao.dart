/// Laws DAO: local data access for the law-name list.
///
/// The list is small (a dozen or so rows), so the DAO is the plain cour/step
/// shape: ordered reads, one reactive watch, and a soft delete. Ordering is
/// `order_index` first — the seed order, and whatever the user reorders it to —
/// then the name, so two rows added at the same position still read A→Z.
library;

import 'package:drift/drift.dart';

import '../../../../database/app_database.dart';

/// Data Access Object for [Laws] table operations.
class LawsDao {
  /// Creates a DAO backed by [db].
  LawsDao(this.db);

  /// The Drift database instance.
  final AppDatabase db;

  /// Returns all non-deleted law names in display order.
  Future<List<Law>> getAll({int? limit, int? offset}) async {
    final query = db.select(db.laws)
      ..where((row) => row.isDeleted.equals(false))
      ..orderBy([
        (row) => OrderingTerm(expression: row.orderIndex),
        (row) => OrderingTerm(expression: row.name),
      ]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Reactive stream of all non-deleted law names in display order.
  Stream<List<Law>> watchAll({int? limit, int? offset}) {
    final query = db.select(db.laws)
      ..where((row) => row.isDeleted.equals(false))
      ..orderBy([
        (row) => OrderingTerm(expression: row.orderIndex),
        (row) => OrderingTerm(expression: row.name),
      ]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.watch();
  }

  /// Returns a law name by id, or null if not found or deleted.
  Future<Law?> getById(String id) async => (db.select(db.laws)
        ..where((row) => row.id.equals(id) & row.isDeleted.equals(false)))
      .getSingleOrNull();

  /// Returns the highest `order_index` in use, or -1 when the list is empty.
  ///
  /// A new name appends after it, so a freshly typed law never lands at the
  /// top of the list or shares position 0 with the whole seed.
  Future<int> maxOrderIndex() async {
    final row = await (db.selectOnly(db.laws)
          ..addColumns([db.laws.orderIndex.max()])
          ..where(db.laws.isDeleted.equals(false)))
        .getSingle();
    return row.read(db.laws.orderIndex.max()) ?? -1;
  }

  /// Inserts a law name. Returns the affected row count.
  Future<int> insert(LawsCompanion law) => db.into(db.laws).insert(law);

  /// Updates a law name. Returns true if a row was affected.
  Future<bool> update(LawsCompanion law) async =>
      await (db.update(
        db.laws,
      )..where((row) => row.id.equals(law.id.value))).write(law) >
      0;

  /// Soft-deletes a law name by id.
  Future<int> delete(String id, int updatedAt) =>
      (db.update(db.laws)..where((row) => row.id.equals(id))).write(
        LawsCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(updatedAt),
        ),
      );
}
