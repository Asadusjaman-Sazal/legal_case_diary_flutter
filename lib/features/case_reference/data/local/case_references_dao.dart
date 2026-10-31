/// Case references DAO: local data access for precedents and citations.
/// Implemented in Task 05 Phase 1.
library;

import 'package:drift/drift.dart';

import '../../../../database/app_database.dart';

/// Data Access Object for [CaseReferences] table operations.
class CaseReferencesDao {
  /// Creates a DAO backed by [db].
  CaseReferencesDao(this.db);

  /// The Drift database instance.
  final AppDatabase db;

  /// Returns all non-deleted references, pinned first, then by [updatedAt] descending.
  Future<List<CaseReference>> getAll({int? limit, int? offset}) async {
    final query = db.select(db.caseReferences)
      ..where((row) => row.isDeleted.equals(false))
      ..orderBy([
        (row) =>
            OrderingTerm(expression: row.isPinned, mode: OrderingMode.desc),
        (row) =>
            OrderingTerm(expression: row.updatedAt, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Reactive stream of all non-deleted references, pinned first.
  Stream<List<CaseReference>> watchAll({int? limit, int? offset}) {
    final query = db.select(db.caseReferences)
      ..where((row) => row.isDeleted.equals(false))
      ..orderBy([
        (row) =>
            OrderingTerm(expression: row.isPinned, mode: OrderingMode.desc),
        (row) =>
            OrderingTerm(expression: row.updatedAt, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.watch();
  }

  /// Searches non-deleted references across all seven text fields (case-insensitive).
  Future<List<CaseReference>> search(
    String query, {
    int? limit,
    int? offset,
  }) async {
    final pattern = '%${query.toLowerCase()}%';
    final select = db.select(db.caseReferences)
      ..where(
        (row) =>
            row.isDeleted.equals(false) &
            (row.referenceAndPageNo.lower().like(pattern) |
                row.statute.lower().like(pattern) |
                row.sectionOrArticle.lower().like(pattern) |
                row.titleAndDescription.lower().like(pattern) |
                row.commentsNotes.lower().like(pattern) |
                row.caseNote.lower().like(pattern) |
                row.tags.lower().like(pattern)),
      )
      ..orderBy([
        (row) =>
            OrderingTerm(expression: row.isPinned, mode: OrderingMode.desc),
        (row) =>
            OrderingTerm(expression: row.updatedAt, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      select.limit(limit, offset: offset ?? 0);
    }
    return select.get();
  }

  /// Counts the live references (the lapse allowance's add ceiling).
  Future<int> getNonDeletedCount() async {
    final countExp = db.caseReferences.id.count();
    final query = db.selectOnly(db.caseReferences)
      ..addColumns([countExp])
      ..where(db.caseReferences.isDeleted.equals(false));
    return query.map((row) => row.read(countExp)!).getSingle();
  }

  /// Ids of the [limit] most recently updated live references, newest first.
  ///
  /// The lapse allowance's writable set (§5.2), ordered `updated_at` descending
  /// with `id` as the tie-break. Soft-deleted rows never count, so deleting a
  /// writable reference frees its slot.
  Future<List<String>> getMostRecentlyUpdatedIds(int limit) async {
    if (limit <= 0) return const <String>[];
    final query = db.selectOnly(db.caseReferences)
      ..addColumns([db.caseReferences.id])
      ..where(db.caseReferences.isDeleted.equals(false))
      ..orderBy([
        OrderingTerm(
          expression: db.caseReferences.updatedAt,
          mode: OrderingMode.desc,
        ),
        OrderingTerm(expression: db.caseReferences.id, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    return query.map((row) => row.read(db.caseReferences.id)!).get();
  }

  /// Returns a reference by id, or null if not found or deleted.
  Future<CaseReference?> getById(String id) async =>
      (db.select(db.caseReferences)
            ..where((row) => row.id.equals(id) & row.isDeleted.equals(false)))
          .getSingleOrNull();

  /// Inserts a reference. Returns the row id.
  Future<int> insert(CaseReferencesCompanion reference) =>
      db.into(db.caseReferences).insert(reference);

  /// Updates a reference. Returns true if a row was affected.
  Future<bool> update(CaseReferencesCompanion reference) async =>
      await (db.update(
        db.caseReferences,
      )..where((row) => row.id.equals(reference.id.value))).write(reference) >
      0;

  /// Toggles the pinned state of a reference.
  Future<int> setPinned(String id, bool isPinned, int updatedAt) => db
      .update(db.caseReferences)
      .write(
        CaseReferencesCompanion(
          id: Value(id),
          isPinned: Value(isPinned),
          updatedAt: Value(updatedAt),
        ),
      );

  /// Soft-deletes a reference by id.
  Future<int> delete(String id, int updatedAt) =>
      (db.update(db.caseReferences)..where((row) => row.id.equals(id))).write(
        CaseReferencesCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(updatedAt),
        ),
      );

  /// Restores a previously soft-deleted reference (undo).
  Future<int> restore(String id, int updatedAt) =>
      (db.update(db.caseReferences)..where((row) => row.id.equals(id))).write(
        CaseReferencesCompanion(
          isDeleted: const Value(false),
          updatedAt: Value(updatedAt),
        ),
      );
}
