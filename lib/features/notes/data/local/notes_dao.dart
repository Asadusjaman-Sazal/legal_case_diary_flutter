/// Notes DAO: local data access for free-form notes.
/// Implemented in Task 05 Phase 1.
library;

import 'package:drift/drift.dart';

import '../../../../database/app_database.dart';

/// Data Access Object for [Notes] table operations.
class NotesDao {
  /// Creates a DAO backed by [db].
  NotesDao(this.db);

  /// The Drift database instance.
  final AppDatabase db;

  /// Returns all non-deleted notes, pinned first, then by [updatedAt] descending.
  Future<List<Note>> getAll({int? limit, int? offset}) async {
    final query = db.select(db.notes)
      ..where((row) => row.isDeleted.equals(false))
      ..orderBy([
        (row) => OrderingTerm(expression: row.isPinned, mode: OrderingMode.desc),
        (row) => OrderingTerm(expression: row.updatedAt, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Reactive stream of all non-deleted notes, pinned first.
  Stream<List<Note>> watchAll({int? limit, int? offset}) {
    final query = db.select(db.notes)
      ..where((row) => row.isDeleted.equals(false))
      ..orderBy([
        (row) => OrderingTerm(expression: row.isPinned, mode: OrderingMode.desc),
        (row) => OrderingTerm(expression: row.updatedAt, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.watch();
  }

  /// Searches non-deleted notes by title and body (case-insensitive).
  Future<List<Note>> search(String query, {int? limit, int? offset}) async {
    final pattern = '%${query.toLowerCase()}%';
    final select = db.select(db.notes)
      ..where(
        (row) => row.isDeleted.equals(false) &
            (row.title.lower().like(pattern) | row.body.lower().like(pattern)),
      )
      ..orderBy([
        (row) => OrderingTerm(expression: row.isPinned, mode: OrderingMode.desc),
        (row) => OrderingTerm(expression: row.updatedAt, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      select.limit(limit, offset: offset ?? 0);
    }
    return select.get();
  }

  /// Returns a note by id, or null if not found or deleted.
  Future<Note?> getById(String id) async => (db.select(db.notes)
      ..where((row) => row.id.equals(id) & row.isDeleted.equals(false)))
      .getSingleOrNull();

  /// Inserts a note. Returns the row id.
  Future<int> insert(NotesCompanion note) => db.into(db.notes).insert(note);

  /// Updates a note. Returns true if a row was affected.
  Future<bool> update(NotesCompanion note) => db.update(db.notes).replace(note);

  /// Toggles the pinned state of a note.
  Future<int> setPinned(String id, bool isPinned, int updatedAt) => db.update(db.notes).write(
        NotesCompanion(
          id: Value(id),
          isPinned: Value(isPinned),
          updatedAt: Value(updatedAt),
        ),
      );

  /// Soft-deletes a note by id.
  Future<int> delete(String id, int updatedAt) => db.update(db.notes).write(
        NotesCompanion(
          id: Value(id),
          isDeleted: const Value(true),
          updatedAt: Value(updatedAt),
        ),
      );
}
