/// Cases DAO: local data access for legal cases.
/// Implemented in Task 05 Phase 1.
library;

import 'package:drift/drift.dart';

import '../../../../core/constants/pre_seeded_data.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../database/app_database.dart';
import '../case_search_scope.dart';

/// Data Access Object for [Cases] table operations.
class CasesDao {
  /// Creates a DAO backed by [db].
  CasesDao(this.db);

  /// The Drift database instance.
  final AppDatabase db;

  /// Result words that dispose a case even when no seeded Step is available.
  /// Lower-cased forms of [disposedResultTermLabels], sourced from the seed data
  /// so the help dialog and disposal detection stay in sync.
  static final _disposedResultTerms = disposedResultTermLabels
      .expand((term) => [term.en.toLowerCase(), term.bn])
      .toList();

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
  Future<List<Case>> search(String query, {int? limit, int? offset}) =>
      searchScoped(query, limit: limit, offset: offset);

  /// Searches non-deleted cases within [scope] across the plan §12.1 field set:
  /// case number, petitioner, respondent, both lead counsels, the represented
  /// client's own role row resolved through `on_behalf_id`, the party phone,
  /// the case title/section and the remarks.
  ///
  /// This is the path every case-list screen's search bar runs on, so the field
  /// set and the dataset predicate live in one place instead of being re-done
  /// in memory per screen.
  Future<List<Case>> searchScoped(
    String query, {
    CaseSearchScope scope = const CaseSearchScope(),
    int? limit,
    int? offset,
  }) async {
    final pattern = '%${query.trim().toLowerCase()}%';
    final select = db.select(db.cases)
      ..where(
        (row) =>
            row.isDeleted.equals(false) &
            _textMatches(pattern) &
            _scopeMatches(scope),
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

  /// The plan §12.1 text predicate.
  ///
  /// `search` is every searchable column's case-insensitive `LIKE`; the three
  /// required columns ([Cases.caseNumber], [Cases.petitioner],
  /// [Cases.respondent]) are matched directly, and each nullable column is
  /// guarded so a NULL cannot decide the predicate.
  Expression<bool> _textMatches(String pattern) {
    final row = db.cases;
    final required =
        row.caseNumber.lower().like(pattern) |
        row.petitioner.lower().like(pattern) |
        row.respondent.lower().like(pattern);
    final optional =
        _nullableLike(row.petitionerLeadCounsel, pattern) |
        _nullableLike(row.respondentLeadCounsel, pattern) |
        _nullableLike(row.partyPhone, pattern) |
        _nullableLike(row.caseTitleAndSection, pattern) |
        _nullableLike(row.caseRemarks, pattern);
    return required | optional | _onBehalfRoleMatches(pattern);
  }

  /// `NULL LIKE …` guarded form of a substring match on a nullable column.
  ///
  /// The guard is `IS NOT NULL AND LIKE …` rather than `IS NULL OR LIKE …`:
  /// with the OR form a NULL column would make the match **true** for every
  /// row, and the query would return the whole table. `FALSE AND NULL` is FALSE
  /// in SQLite, so this form is never NULL and never matches a NULL column.
  Expression<bool> _nullableLike(Expression<String> column, String pattern) =>
      column.isNotNull() & column.lower().like(pattern);

  /// The represented client rule: which party a case's single `party_phone`
  /// belongs to is answered by `on_behalf_id`, so the role row's own label is
  /// searchable through a subquery on the id reference.
  Expression<bool> _onBehalfRoleMatches(String pattern) {
    final roles = db.selectOnly(db.onBehalfs)
      ..addColumns([db.onBehalfs.id])
      ..where(db.onBehalfs.name.lower().like(pattern));
    return db.cases.onBehalfId.isInQuery(roles);
  }

  /// The screen's own dataset predicate (plan §12.1).
  Expression<bool> _scopeMatches(CaseSearchScope scope) {
    final row = db.cases;
    final disposal = switch (scope.disposal) {
      CaseSearchDisposal.any => const Constant<bool>(true),
      CaseSearchDisposal.activeOnly =>
        _stepIsNotDisposed & _resultIsNotDisposed,
      CaseSearchDisposal.disposedOnly => _isDisposed,
    };
    final start = scope.nextDateStart;
    final end = scope.nextDateEnd;
    if (start == null || end == null) return disposal;
    return disposal &
        row.nextDate.isNotNull() &
        row.nextDate.isBetweenValues(start, end);
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
            row.nextDate.isBetweenValues(start, end) &
            _isDisposed.not(),
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

  /// Ids of the [limit] most recently updated live cases, newest first.
  ///
  /// This is the lapse allowance's writable set (§5.2): `updated_at` descending
  /// with `id` as the tie-break, so two calls — and two devices holding the same
  /// ledger — agree on the order. Soft-deleted rows are excluded, which is what
  /// makes deleting a writable case free a slot for the next one.
  Future<List<String>> getMostRecentlyUpdatedIds(int limit) async {
    if (limit <= 0) return const <String>[];
    final query = db.selectOnly(db.cases)
      ..addColumns([db.cases.id])
      ..where(db.cases.isDeleted.equals(false))
      ..orderBy([
        OrderingTerm(expression: db.cases.updatedAt, mode: OrderingMode.desc),
        OrderingTerm(expression: db.cases.id, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    return query.map((row) => row.read(db.cases.id)!).get();
  }

  /// Reactive stream of the non-deleted case count for the diary the tier
  /// limits: the chamber's cases when [firmId] is given, the account's own
  /// (`firm_id IS NULL`) otherwise — the same scope `enforce_case_ceiling`
  /// counts at the server.
  Stream<int> watchNonDeletedCaseCount({String? firmId}) {
    final countExp = db.cases.id.count();
    final query = db.selectOnly(db.cases)
      ..addColumns([countExp])
      ..where(
        db.cases.isDeleted.equals(false) &
            (firmId == null
                ? db.cases.firmId.isNull()
                : db.cases.firmId.equals(firmId)),
      );
    return query.map((row) => row.read(countExp)!).watchSingle();
  }

  /// Counts non-deleted cases not disposed by a seeded Step or AD/HCD Result.
  Future<int> getActiveCaseCount() async {
    final countExp = db.cases.id.count();
    final query = db.selectOnly(db.cases)
      ..addColumns([countExp])
      ..where(
        db.cases.isDeleted.equals(false) &
            _stepIsNotDisposed &
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
            _stepIsNotDisposed &
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

  /// SQL expression marking a case as disposed when its Steps field contains a
  /// disposal step name (from [disposedStepNames]) among other comma-joined
  /// steps, e.g. "Withdrawal,Dismissal" or "নিষ্পত্তি,Argument".
  ///
  /// Guarded by [Cases.lastStep.isNotNull] so a NULL step field (always the case
  /// for AD/HCD cases, which have no Steps) yields FALSE rather than NULL. An
  /// unguarded `NULL LIKE ...` reduces to NULL, which `NULL | resultCheck`
  /// propagates, causing the row to be excluded by both `_isDisposed` and its
  /// negation — i.e. missing from every disposal-filtered screen.
  Expression<bool> get _stepIsDisposed =>
      db.cases.lastStep.isNotNull() &
      disposedStepNames
          .map((label) => db.cases.lastStep.lower().like('%$label%'))
          .reduce((left, right) => left | right);

  /// SQL expression marking a case as NOT disposed by its Steps field.
  Expression<bool> get _stepIsNotDisposed =>
      db.cases.lastStep.isNull() |
      disposedStepNames
          .map((label) => db.cases.lastStep.lower().like('%$label%').not())
          .reduce((left, right) => left & right);

  Expression<bool> get _isDisposed =>
      _stepIsDisposed |
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

  /// Returns the count of non-deleted, non-disposed cases whose [Cases.nextDate]
  /// falls within `[startMs, endMs]` inclusive, grouped by their next-date's
  /// Bangladesh civil-day start-of-day epoch. Used by the Daily Cause List badge
  /// calendar to render per-date hearing counts.
  Future<Map<int, int>> countByNextDateRange(int startMs, int endMs) async {
    final rows = await (db.selectOnly(db.cases)
          ..addColumns([db.cases.nextDate, db.cases.id.count()])
          ..where(
            db.cases.isDeleted.equals(false) &
                db.cases.nextDate.isNotNull() &
                db.cases.nextDate.isBetweenValues(startMs, endMs) &
                _isDisposed.not(),
          )
          ..groupBy([db.cases.nextDate]))
        .get();
    final counts = <int, int>{};
    for (final row in rows) {
      final epoch = row.read(db.cases.nextDate);
      final count = row.read(db.cases.id.count());
      if (epoch != null && count != null) {
        counts[AppDateUtils.normalizeToBangladeshStartOfDay(epoch)] = count;
      }
    }
    return counts;
  }

  /// Returns the count of non-deleted, non-disposed cases whose [Cases.nextDate]
  /// is set, grouped by their next-date's Bangladesh civil-day start-of-day
  /// epoch — across the FULL range of dates (no month window). Used by the Daily
  /// Cause List badge calendar so every date that has hearings shows a badge and
  /// the "Total Hearings" count reflects all upcoming/scheduled cases, not just
  /// the visible month.
  Future<Map<int, int>> countAllByNextDate() async {
    final rows = await (db.selectOnly(db.cases)
          ..addColumns([db.cases.nextDate, db.cases.id.count()])
          ..where(
            db.cases.isDeleted.equals(false) &
                db.cases.nextDate.isNotNull() &
                _isDisposed.not(),
          )
          ..groupBy([db.cases.nextDate]))
        .get();
    final counts = <int, int>{};
    for (final row in rows) {
      final epoch = row.read(db.cases.nextDate);
      final count = row.read(db.cases.id.count());
      if (epoch != null && count != null) {
        counts[AppDateUtils.normalizeToBangladeshStartOfDay(epoch)] = count;
      }
    }
    return counts;
  }
}
