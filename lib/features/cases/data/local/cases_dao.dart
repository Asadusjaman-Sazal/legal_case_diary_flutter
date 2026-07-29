/// Cases DAO: local data access for legal cases.
/// Implemented in Task 05 Phase 1.
library;

import 'package:drift/drift.dart';

import '../../../../database/app_database.dart';

/// Data Access Object for [Cases] table operations.
class CasesDao {
  /// Creates a DAO backed by [db].
  CasesDao(this.db);

  /// The Drift database instance.
  final AppDatabase db;

  /// Canonical lowercased labels that mark a case as disposed.
  /// Used by [getActiveCaseCount] / [watchActiveCaseCount].
  static const _disposedLabels = <String>['disposed', 'নিষ্পত্তি'];

  /// Returns all non-deleted cases ordered by [nextDate] descending, then [updatedAt] descending.
  Future<List<Case>> getAll({int? limit, int? offset}) async {
    final query = db.select(db.cases)
      ..where((row) => row.isDeleted.equals(false))
      ..orderBy([
        (row) => OrderingTerm(expression: row.nextDate, mode: OrderingMode.desc),
        (row) => OrderingTerm(expression: row.updatedAt, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Reactive stream of all non-deleted cases.
  Stream<List<Case>> watchAll({int? limit, int? offset}) {
    final query = db.select(db.cases)
      ..where((row) => row.isDeleted.equals(false))
      ..orderBy([
        (row) => OrderingTerm(expression: row.nextDate, mode: OrderingMode.desc),
        (row) => OrderingTerm(expression: row.updatedAt, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.watch();
  }

  /// Searches non-deleted cases across case number, parties, counsels, phones,
  /// remarks, and title (case-insensitive).
  Future<List<Case>> search(String query, {int? limit, int? offset}) async {
    final pattern = '%${query.toLowerCase()}%';
    final select = db.select(db.cases)
      ..where(
        (row) => row.isDeleted.equals(false) &
            (row.caseNumber.lower().like(pattern) |
                row.petitioner.lower().like(pattern) |
                row.respondent.lower().like(pattern) |
                row.petitionerLeadCounsel.lower().like(pattern) |
                row.respondentLeadCounsel.lower().like(pattern) |
                row.petitionerPhone.lower().like(pattern) |
                row.respondentPhone.lower().like(pattern) |
                row.caseTitleAndSection.lower().like(pattern) |
                row.caseRemarks.lower().like(pattern)),
      )
      ..orderBy([
        (row) => OrderingTerm(expression: row.nextDate, mode: OrderingMode.desc),
        (row) => OrderingTerm(expression: row.updatedAt, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      select.limit(limit, offset: offset ?? 0);
    }
    return select.get();
  }

  /// Returns non-deleted cases for a court category.
  Future<List<Case>> getByCourtCategory(String courtCategoryId, {int? limit, int? offset}) async {
    final courtIds = await _courtIdsForCategory(courtCategoryId);
    final query = db.select(db.cases)
      ..where((row) => row.isDeleted.equals(false) & row.courtId.isIn(courtIds))
      ..orderBy([
        (row) => OrderingTerm(expression: row.nextDate, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Returns non-deleted cases for a specific court.
  Future<List<Case>> getByCourt(String courtId, {int? limit, int? offset}) async {
    final query = db.select(db.cases)
      ..where((row) => row.isDeleted.equals(false) & row.courtId.equals(courtId))
      ..orderBy([
        (row) => OrderingTerm(expression: row.nextDate, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Returns non-deleted cases whose next hearing date falls in [start, end].
  Future<List<Case>> getByNextDateRange(int start, int end, {int? limit, int? offset}) async {
    final query = db.select(db.cases)
      ..where(
        (row) => row.isDeleted.equals(false) &
            row.nextDate.isBetweenValues(start, end),
      )
      ..orderBy([
        (row) => OrderingTerm(expression: row.nextDate, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Returns a case by id, or null if not found or deleted.
  Future<Case?> getById(String id) async => (db.select(db.cases)
      ..where((row) => row.id.equals(id) & row.isDeleted.equals(false)))
      .getSingleOrNull();

  /// Inserts a case. Returns the row id.
  Future<int> insert(CasesCompanion caseRecord) => db.into(db.cases).insert(caseRecord);

  /// Updates a case. Returns true if a row was affected.
  Future<bool> update(CasesCompanion caseRecord) => db.update(db.cases).replace(caseRecord);

  /// Soft-deletes a case by id.
  Future<int> delete(String id, int updatedAt) => db.update(db.cases).write(
        CasesCompanion(
          id: Value(id),
          isDeleted: const Value(true),
          updatedAt: Value(updatedAt),
        ),
      );

  /// Counts all non-deleted cases (for the 50-case free limit).
  Future<int> getNonDeletedCaseCount() async {
    final countExp = db.cases.id.count();
    final query = db.selectOnly(db.cases)
      ..addColumns([countExp])
      ..where(db.cases.isDeleted.equals(false));
    return query.map((row) => row.read(countExp)!).getSingle();
  }

  /// Reactive stream of the non-deleted case count.
  Stream<int> watchNonDeletedCaseCount() {
    final countExp = db.cases.id.count();
    final query = db.selectOnly(db.cases)
      ..addColumns([countExp])
      ..where(db.cases.isDeleted.equals(false));
    return query.map((row) => row.read(countExp)!).watchSingle();
  }

  /// Counts non-deleted cases whose step is not disposed (Active Cases/KPIs).
  ///
  /// This is a Phase 1 heuristic: a case is considered active if [lastStep]
  /// is null or is not one of the canonical disposed labels. The repository
  /// layer may refine this once the step storage format is finalized.
  Future<int> getActiveCaseCount() async {
    final countExp = db.cases.id.count();
    final query = db.selectOnly(db.cases)
      ..addColumns([countExp])
      ..where(
        db.cases.isDeleted.equals(false) &
            (db.cases.lastStep.isNull() |
                db.cases.lastStep.lower().isNotIn(_disposedLabels)),
      );
    return query.map((row) => row.read(countExp)!).getSingle();
  }

  /// Reactive stream of the active (non-disposed) case count.
  Stream<int> watchActiveCaseCount() {
    final countExp = db.cases.id.count();
    final query = db.selectOnly(db.cases)
      ..addColumns([countExp])
      ..where(
        db.cases.isDeleted.equals(false) &
            (db.cases.lastStep.isNull() |
                db.cases.lastStep.lower().isNotIn(_disposedLabels)),
      );
    return query.map((row) => row.read(countExp)!).watchSingle();
  }

  Future<List<String>> _courtIdsForCategory(String courtCategoryId) async =>
      (db.selectOnly(db.courts)
          ..addColumns([db.courts.id])
          ..where(
            db.courts.isDeleted.equals(false) &
                db.courts.courtCategoryId.equals(courtCategoryId),
          ))
          .map((row) => row.read(db.courts.id)!)
          .get();
}
