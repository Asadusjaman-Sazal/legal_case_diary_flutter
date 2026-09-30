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

  /// Returns non-deleted unresolved conflicts.
  ///
  /// `is_dismissed` is deliberately **not** filtered: dismissal is UI-only and
  /// never resolves a conflict (plan §1), so a dismissed-but-unresolved conflict
  /// is still unresolved and must stay visible. This matches [watchUnresolved],
  /// which the banner reads, so the two can never disagree about what is open.
  Future<List<ConflictLogRow>> getUnresolved({int? limit, int? offset}) async {
    final query = db.select(db.conflictLog)
      ..where(
        (row) => row.isDeleted.equals(false) &
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

  /// Reactive stream of the conflicts still waiting for a person.
  ///
  /// This is what the app-wide banner (Task 19 Phase 3) watches: a conflict
  /// leaves the list only when its `resolution_state` stops being `unresolved`,
  /// which only the resolution writer does — never a dismissal or the passage of
  /// time.
  Stream<List<ConflictLogRow>> watchUnresolved() => (db.select(db.conflictLog)
        ..where(
          (row) => row.isDeleted.equals(false) &
              row.resolutionState.equals('unresolved'),
        )
        ..orderBy([
          (row) => OrderingTerm(expression: row.conflictAt, mode: OrderingMode.desc),
        ]))
      .watch();

  /// Records how a conflict was answered, and when.
  ///
  /// The only writer of `resolution_state`/`resolved_at`, so a conflict can
  /// never look resolved without a resolution having happened. Returns the number
  /// of rows affected (0 when the conflict no longer exists).
  Future<int> setResolution(
    String id, {
    required String resolutionState,
    required int resolvedAt,
    required int updatedAt,
  }) =>
      (db.update(db.conflictLog)..where((row) => row.id.equals(id)))
          .write(ConflictLogCompanion(
        resolutionState: Value(resolutionState),
        resolvedAt: Value(resolvedAt),
        updatedAt: Value(updatedAt),
      ));

  /// Inserts a conflict log entry. Returns the row id.
  Future<int> insert(ConflictLogCompanion conflict) => db.into(db.conflictLog).insert(conflict);

  /// Updates a conflict log entry. Returns true if a row was affected.
  Future<bool> update(ConflictLogCompanion conflict) async =>
      await (db.update(db.conflictLog)..where((row) => row.id.equals(conflict.id.value))).write(conflict) > 0;

  /// Marks a conflict log entry as dismissed.
  ///
  /// Dismissal is UI-only and deliberately does nothing to the data: the entry
  /// keeps its `resolution_state`, so it still counts as unresolved and can never
  /// be mistaken for an answered conflict (Task 19 Phase 3).
  Future<int> dismiss(String id, int updatedAt) =>
      (db.update(db.conflictLog)..where((row) => row.id.equals(id))).write(
        ConflictLogCompanion(
          isDismissed: const Value(true),
          updatedAt: Value(updatedAt),
        ),
      );

  /// Soft-deletes a conflict log entry by id.
  Future<int> delete(String id, int updatedAt) =>
      (db.update(db.conflictLog)..where((row) => row.id.equals(id))).write(
        ConflictLogCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(updatedAt),
        ),
      );
}
