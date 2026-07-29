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

  /// Returns a history entry by its source mutation id, or null if not found.
  Future<CaseHistoryRow?> getBySourceMutationId(String sourceMutationId) async =>
      (db.select(db.caseHistory)
          ..where((row) => row.sourceMutationId.equals(sourceMutationId)))
          .getSingleOrNull();

  /// Inserts a history entry. Returns the row id.
  Future<int> insert(CaseHistoryCompanion entry) => insertHistoryEntry(entry);

  /// Inserts a history entry. Returns the row id.
  Future<int> insertHistoryEntry(CaseHistoryCompanion entry) => db.into(db.caseHistory).insert(entry);
}
