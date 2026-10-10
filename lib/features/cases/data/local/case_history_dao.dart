/// Case history DAO: local data access for procedural case history.
/// Implemented in Task 05 Phase 1.
library;

import 'package:drift/drift.dart';

import '../../../../database/app_database.dart';

/// Data Access Object for [CaseHistory] table operations.
class CaseHistoryDao {
  /// Creates a DAO backed by [db].
  CaseHistoryDao(this.db);

  /// The Drift database instance.
  final AppDatabase db;

  /// Returns non-deleted history entries for a case, ordered by [nextDate] descending.
  Future<List<CaseHistoryRow>> getByCaseId(String caseId, {int? limit, int? offset}) async {
    final query = db.select(db.caseHistory)
      ..where((row) => row.isDeleted.equals(false) & row.caseId.equals(caseId))
      ..orderBy([
        (row) => OrderingTerm(expression: row.nextDate, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Reactive stream of non-deleted history entries for a case.
  Stream<List<CaseHistoryRow>> watchByCaseId(String caseId, {int? limit, int? offset}) {
    final query = db.select(db.caseHistory)
      ..where((row) => row.isDeleted.equals(false) & row.caseId.equals(caseId))
      ..orderBy([
        (row) => OrderingTerm(expression: row.nextDate, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.watch();
  }

  /// The most recent hearing date for each of [caseIds], keyed by case id.
  ///
  /// One grouped query rather than one per case: a case-list printout needs the
  /// previous hearing date for every row at once, so a per-case lookup would be
  /// N queries. A case with no non-deleted history is simply **absent** from the
  /// map — the printout leaves its Prev. Date cell blank. Tombstones are
  /// excluded, exactly as [getByCaseId] excludes them.
  Future<Map<String, int>> latestHearingDateByCaseIds(
    Iterable<String> caseIds,
  ) async {
    final ids = caseIds.toSet();
    if (ids.isEmpty) return const <String, int>{};
    final maxDate = db.caseHistory.hearingDate.max();
    final rows =
        await (db.selectOnly(db.caseHistory)
              ..addColumns([db.caseHistory.caseId, maxDate])
              ..where(
                db.caseHistory.isDeleted.equals(false) &
                    db.caseHistory.caseId.isIn(ids),
              )
              ..groupBy([db.caseHistory.caseId]))
            .get();
    final result = <String, int>{};
    for (final row in rows) {
      final id = row.read(db.caseHistory.caseId);
      final date = row.read(maxDate);
      if (id != null && date != null) result[id] = date;
    }
    return result;
  }

  /// Returns a history entry by its source mutation id, or null if not found.
  Future<CaseHistoryRow?> getBySourceMutationId(String sourceMutationId) async =>
      (db.select(db.caseHistory)
          ..where((row) => row.sourceMutationId.equals(sourceMutationId)))
          .getSingleOrNull();

  /// Returns a non-deleted history entry by id, or null if not found.
  Future<CaseHistoryRow?> getById(String id) async =>
      (db.select(db.caseHistory)
            ..where((row) => row.id.equals(id) & row.isDeleted.equals(false)))
          .getSingleOrNull();

  /// Inserts a history entry. Returns the row id.
  Future<int> insert(CaseHistoryCompanion entry) => insertHistoryEntry(entry);

  /// Inserts a history entry. Returns the row id.
  Future<int> insertHistoryEntry(CaseHistoryCompanion entry) => db.into(db.caseHistory).insert(entry);

  /// Updates a history entry. Returns true if a row was affected.
  Future<bool> update(CaseHistoryCompanion entry) async =>
      await (db.update(db.caseHistory)
            ..where((row) => row.id.equals(entry.id.value)))
          .write(entry) >
      0;

  /// Soft-deletes a history entry by id.
  Future<int> delete(String id, int updatedAt) =>
      (db.update(db.caseHistory)..where((row) => row.id.equals(id))).write(
        CaseHistoryCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(updatedAt),
        ),
      );
}
