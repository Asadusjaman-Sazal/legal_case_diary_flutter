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

  /// Result words that dispose a case even when no seeded Step is available.
  static const _disposedResultTerms = <String>[
    'dismissed',
    'খারিজ',
    'disposed',
    'নিষ্পত্তি',
    'discharged',
    'অব্যহতি',
  ];

  /// Returns all non-deleted cases ordered by [nextDate] descending, then [updatedAt] descending.
  Future<List<Case>> getAll({int? limit, int? offset}) async {
    final query = db.select(db.cases)
      ..where((row) => row.isDeleted.equals(false))
      ..orderBy([
        (row) =>
            OrderingTerm(expression: row.nextDate, mode: OrderingMode.desc),
        (row) =>
            OrderingTerm(expression: row.updatedAt, mode: OrderingMode.desc),
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
        (row) =>
            OrderingTerm(expression: row.nextDate, mode: OrderingMode.desc),
        (row) =>
            OrderingTerm(expression: row.updatedAt, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.watch();
  }

  /// Returns non-deleted cases disposed by a seeded Step or AD/HCD Result.
  Future<List<Case>> getDisposed({int? limit, int? offset}) async {
    final query = db.select(db.cases)
      ..where((row) => row.isDeleted.equals(false) & _isDisposed)
      ..orderBy([
        (row) =>
            OrderingTerm(expression: row.nextDate, mode: OrderingMode.desc),
        (row) =>
            OrderingTerm(expression: row.updatedAt, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Returns non-deleted cases NOT disposed by a seeded Step or AD/HCD Result.
  Future<List<Case>> getActive({int? limit, int? offset}) async {
    final query = db.select(db.cases)
      ..where((row) => row.isDeleted.equals(false) & _isDisposed.not())
      ..orderBy([
        (row) =>
            OrderingTerm(expression: row.nextDate, mode: OrderingMode.desc),
        (row) =>
            OrderingTerm(expression: row.updatedAt, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Searches non-deleted cases across case number, parties, counsels, phone,
  /// remarks, and title (case-insensitive).
  Future<List<Case>> search(String query, {int? limit, int? offset}) async {
    final pattern = '%${query.toLowerCase()}%';
    final select = db.select(db.cases)
      ..where(
        (row) =>
            row.isDeleted.equals(false) &
            (row.caseNumber.lower().like(pattern) |
                row.petitioner.lower().like(pattern) |
                row.respondent.lower().like(pattern) |
                row.petitionerLeadCounsel.lower().like(pattern) |
                row.respondentLeadCounsel.lower().like(pattern) |
                row.partyPhone.lower().like(pattern) |
                row.caseTitleAndSection.lower().like(pattern) |
                row.caseRemarks.lower().like(pattern)),
      )
      ..orderBy([
        (row) =>
            OrderingTerm(expression: row.nextDate, mode: OrderingMode.desc),
        (row) =>
            OrderingTerm(expression: row.updatedAt, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      select.limit(limit, offset: offset ?? 0);
    }
    return select.get();
  }

  /// Returns non-deleted cases for a court category.
  Future<List<Case>> getByCourtCategory(
    String courtCategoryId, {
    int? limit,
    int? offset,
  }) async {
    final courtIds = await _courtIdsForCategory(courtCategoryId);
    final query = db.select(db.cases)
      ..where((row) => row.isDeleted.equals(false) & row.courtId.isIn(courtIds))
      ..orderBy([
        (row) =>
            OrderingTerm(expression: row.nextDate, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Returns non-deleted cases for a specific court.
  Future<List<Case>> getByCourt(
    String courtId, {
    int? limit,
    int? offset,
  }) async {
    final query = db.select(db.cases)
      ..where(
        (row) => row.isDeleted.equals(false) & row.courtId.equals(courtId),
      )
      ..orderBy([
        (row) =>
            OrderingTerm(expression: row.nextDate, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Returns non-deleted cases whose next hearing date falls in [start, end].
  Future<List<Case>> getByNextDateRange(
    int start,
    int end, {
    int? limit,
    int? offset,
  }) async {
    final query = db.select(db.cases)
      ..where(
        (row) =>
            row.isDeleted.equals(false) &
            row.nextDate.isBetweenValues(start, end),
      )
      ..orderBy([
        (row) =>
            OrderingTerm(expression: row.nextDate, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Returns a case by id, or null if not found or deleted.
  Future<Case?> getById(String id) async =>
      (db.select(db.cases)
            ..where((row) => row.id.equals(id) & row.isDeleted.equals(false)))
          .getSingleOrNull();

  /// Inserts a case. Returns the row id.
  Future<int> insert(CasesCompanion caseRecord) =>
      db.into(db.cases).insert(caseRecord);

  /// Updates a case. Returns true if a row was affected.
  Future<bool> update(CasesCompanion caseRecord) async =>
      await (db.update(
        db.cases,
      )..where((row) => row.id.equals(caseRecord.id.value))).write(caseRecord) >
      0;

  /// Soft-deletes a case by id.
  Future<int> delete(String id, int updatedAt) =>
      (db.update(db.cases)..where((row) => row.id.equals(id))).write(
        CasesCompanion(
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

  /// Counts non-deleted cases not disposed by a seeded Step or AD/HCD Result.
  Future<int> getActiveCaseCount() async {
    final countExp = db.cases.id.count();
    final query = db.selectOnly(db.cases)
      ..addColumns([countExp])
      ..where(
        db.cases.isDeleted.equals(false) &
            (db.cases.lastStep.isNull() |
                db.cases.lastStep.lower().isNotIn(_disposedLabels)) &
            _resultIsNotDisposed,
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
                db.cases.lastStep.lower().isNotIn(_disposedLabels)) &
            _resultIsNotDisposed,
      );
    return query.map((row) => row.read(countExp)!).watchSingle();
  }

  /// SQL expression used by both active-case count paths.
  Expression<bool> get _resultIsNotDisposed =>
      db.cases.result.isNull() |
      _disposedResultTerms
          .map((term) => db.cases.result.lower().like('%$term%').not())
          .reduce((left, right) => left & right);

  Expression<bool> get _isDisposed =>
      db.cases.lastStep.lower().isIn(_disposedLabels) |
      (db.cases.result.isNotNull() &
          _disposedResultTerms
              .map((term) => db.cases.result.lower().like('%$term%'))
              .reduce((left, right) => left | right));

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
