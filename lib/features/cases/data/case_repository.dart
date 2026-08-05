/// Case repository: manages case CRUD, search, and provisional history.
/// Local implementation in Task 05 Phase 3; remote/sync-aware in Part B.
library;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/repositories/base_local_repository.dart';
import '../../../database/app_database.dart';
import '../../../sync/sync_write_helper.dart';
import 'local/case_history_dao.dart';
import 'local/cases_dao.dart';

/// Case repository interface.
abstract class CaseRepository {
  /// Inserts a new case. Returns the generated case id.
  Future<String> insertCase(CasesCompanion companion);

  /// Updates a case. If [isQuickUpdate] is true and [nextDate] changed,
  /// persists a single provisional case history entry for the previous values.
  Future<void> updateCase(
    CasesCompanion companion, {
    Case? baseCase,
    bool isQuickUpdate = false,
  });

  /// Soft-deletes a case.
  Future<void> deleteCase(Case currentCase);

  /// Returns a case by id, or null if not found/deleted.
  Future<Case?> getById(String id);

  /// Lists all non-deleted cases.
  Future<List<Case>> listAll({int? limit, int? offset});

  /// Reactive stream of all non-deleted cases.
  Stream<List<Case>> watchAll({int? limit, int? offset});

  /// Searches non-deleted cases.
  Future<List<Case>> search(String query, {int? limit, int? offset});

  /// Lists non-deleted cases with a next date in the range [start, end].
  Future<List<Case>> listByNextDateRange(
    int start,
    int end, {
    int? limit,
    int? offset,
  });

  /// Returns the count of all non-deleted cases.
  Future<int> nonDeletedCount();

  /// Returns the count of active (non-disposed) cases.
  Future<int> activeCount();
}

/// Transaction-capable local case write boundary used by form saves.
abstract class TransactionalCaseRepository implements CaseRepository {
  /// Inserts a case inside the caller-owned transaction.
  Future<String> insertCaseInTransaction(CasesCompanion companion);

  /// Updates a case inside the caller-owned transaction.
  Future<void> updateCaseInTransaction(
    CasesCompanion companion, {
    Case? baseCase,
    bool isQuickUpdate = false,
  });
}

/// Local Drift-backed implementation of [CaseRepository].
class LocalCaseRepository
    with BaseLocalRepository
    implements TransactionalCaseRepository {
  final CasesDao _casesDao;
  final CaseHistoryDao _historyDao;

  @override
  final SyncWriteHelper syncHelper;

  /// Creates a repository backed by [dao], [historyDao], and [syncHelper].
  LocalCaseRepository(this._casesDao, this._historyDao, this.syncHelper);

  @override
  Future<String> insertCase(CasesCompanion companion) =>
      _casesDao.db.transaction(() => insertCaseInTransaction(companion));

  @override
  Future<String> insertCaseInTransaction(CasesCompanion companion) async {
    final now = companion.updatedAt.present
        ? companion.updatedAt.value
        : BaseLocalRepository.nowMillis;
    final id = const Uuid().v4();
    final userId = currentUserId;

    final finalCompanion = companion.copyWith(
      id: Value(id),
      userId: Value(userId),
      firmId: const Value<String?>(null),
      createdAt: companion.createdAt.present ? companion.createdAt : Value(now),
      updatedAt: Value(now),
      lastModifiedBy: Value(userId),
      isDeleted: const Value(false),
    );

    await _casesDao.insert(finalCompanion);

    final inserted = await _casesDao.getById(id);
    final payload = BaseLocalRepository.toSyncPayload(inserted!.toJson());
    await syncHelper.recordInsert(
      entityType: 'case',
      entityId: id,
      payload: payload,
      changedFields: payload.keys.toList(),
    );

    return id;
  }

  @override
  Future<void> updateCase(
    CasesCompanion companion, {
    Case? baseCase,
    bool isQuickUpdate = false,
  }) => _casesDao.db.transaction(
    () => updateCaseInTransaction(
      companion,
      baseCase: baseCase,
      isQuickUpdate: isQuickUpdate,
    ),
  );

  @override
  Future<void> updateCaseInTransaction(
    CasesCompanion companion, {
    Case? baseCase,
    bool isQuickUpdate = false,
  }) async {
    final id = companion.id.value;
    final existing = baseCase ?? await _casesDao.getById(id);
    if (existing == null) {
      throw StateError('Cannot update case $id: not found');
    }

    // A quick update is one logical mutation: the case snapshot, history row,
    // and both sync-queue records must commit or roll back together.
    final now = companion.updatedAt.present
        ? companion.updatedAt.value
        : BaseLocalRepository.nowMillis;
    final userId = currentUserId;
    final finalCompanion = companion.copyWith(
      updatedAt: Value(now),
      lastModifiedBy: Value(userId),
    );

    await _casesDao.update(finalCompanion);

    // Record the case update before provisional history so the queue keeps
    // the parent case ahead of its dependent case_history row.
    final updated = await _casesDao.getById(id);
    final payload = BaseLocalRepository.toSyncPayload(updated!.toJson());
    final changed = _changedFields(finalCompanion);

    await syncHelper.recordUpdate(
      entityType: 'case',
      entityId: id,
      payload: payload,
      changedFields: changed,
      basePayload: BaseLocalRepository.toSyncPayload(existing.toJson()),
      baseVersion: existing.version,
      preMutationPayload: BaseLocalRepository.toSyncPayload(existing.toJson()),
    );

    if (isQuickUpdate) {
      final newNextDate = finalCompanion.nextDate.present
          ? finalCompanion.nextDate.value
          : existing.nextDate;
      if (newNextDate != existing.nextDate) {
        await _insertProvisionalHistory(existing, newNextDate, userId, now);
      }
    }
  }

  @override
  Future<void> deleteCase(Case currentCase) async {
    final now = BaseLocalRepository.nowMillis;
    final userId = currentUserId;

    await _casesDao.delete(currentCase.id, now);

    final payload = BaseLocalRepository.toSyncPayload(<String, dynamic>{
      'id': currentCase.id,
      'isDeleted': true,
      'updatedAt': now,
      'lastModifiedBy': userId,
    });

    await syncHelper.recordDelete(
      entityType: 'case',
      entityId: currentCase.id,
      payload: payload,
      changedFields: ['is_deleted', 'updated_at', 'last_modified_by'],
      basePayload: BaseLocalRepository.toSyncPayload(currentCase.toJson()),
      baseVersion: currentCase.version,
      preMutationPayload: BaseLocalRepository.toSyncPayload(
        currentCase.toJson(),
      ),
    );
  }

  @override
  Future<Case?> getById(String id) => _casesDao.getById(id);

  @override
  Future<List<Case>> listAll({int? limit, int? offset}) =>
      _casesDao.getAll(limit: limit, offset: offset);

  @override
  Stream<List<Case>> watchAll({int? limit, int? offset}) =>
      _casesDao.watchAll(limit: limit, offset: offset);

  @override
  Future<List<Case>> search(String query, {int? limit, int? offset}) =>
      _casesDao.search(query, limit: limit, offset: offset);

  @override
  Future<List<Case>> listByNextDateRange(
    int start,
    int end, {
    int? limit,
    int? offset,
  }) => _casesDao.getByNextDateRange(start, end, limit: limit, offset: offset);

  @override
  Future<int> nonDeletedCount() => _casesDao.getNonDeletedCaseCount();

  @override
  Future<int> activeCount() => _casesDao.getActiveCaseCount();

  Future<void> _insertProvisionalHistory(
    Case oldCase,
    int? newNextDate,
    String userId,
    int now,
  ) async {
    final historyId = const Uuid().v4();
    final mutationId = const Uuid().v4();
    final hearingDate = oldCase.nextDate ?? now;

    final companion = CaseHistoryCompanion(
      id: Value(historyId),
      caseId: Value(oldCase.id),
      userId: Value(userId),
      firmId: const Value<String?>(null),
      hearingDate: Value(hearingDate),
      lastStep: Value(oldCase.lastStep),
      nextDate: Value(newNextDate),
      noteResult: Value(oldCase.notesResults),
      createdBy: Value(userId),
      sourceMutationId: Value(mutationId),
      baseCaseVersion: Value(oldCase.version ?? 0),
      resultCaseVersion: Value((oldCase.version ?? 0) + 1),
      updatedAt: Value(now),
      lastModifiedBy: Value(userId),
    );

    await _historyDao.insertHistoryEntry(companion);

    final inserted = await _historyDao.getBySourceMutationId(mutationId);
    final payload = BaseLocalRepository.toSyncPayload(inserted!.toJson());
    await syncHelper.recordInsert(
      entityType: 'case_history',
      entityId: historyId,
      payload: payload,
      changedFields: payload.keys.toList(),
    );
  }

  /// Derives changed field names from the companion's present domain fields.
  List<String> _changedFields(CasesCompanion companion) {
    final fromCompanion = <String>[];
    if (companion.caseNumber.present) fromCompanion.add('case_number');
    if (companion.petitioner.present) fromCompanion.add('petitioner');
    if (companion.respondent.present) fromCompanion.add('respondent');
    if (companion.petitionerLeadCounsel.present) {
      fromCompanion.add('petitioner_lead_counsel');
    }
    if (companion.respondentLeadCounsel.present) {
      fromCompanion.add('respondent_lead_counsel');
    }
    if (companion.onBehalfId.present) fromCompanion.add('on_behalf_id');
    if (companion.partyPhone.present) {
      fromCompanion.add('party_phone');
    }
    if (companion.caseTitleAndSection.present) {
      fromCompanion.add('case_title_and_section');
    }
    if (companion.caseRemarks.present) fromCompanion.add('case_remarks');
    if (companion.nextDate.present) fromCompanion.add('next_date');
    if (companion.lastStep.present) fromCompanion.add('last_step');
    if (companion.notesResults.present) fromCompanion.add('notes_results');
    if (companion.courtId.present) fromCompanion.add('court_id');
    if (companion.caseType.present) fromCompanion.add('case_type');
    return fromCompanion;
  }
}
