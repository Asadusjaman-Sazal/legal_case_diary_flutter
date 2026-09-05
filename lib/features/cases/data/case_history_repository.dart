/// Case history repository: sync-ready local edits and soft deletes for
/// procedural case-history entries.
///
/// Task 10 Phase 2. Automatic history creation stays inside the case quick
/// update transaction (`LocalCaseRepository`); this repository is the only
/// write path for the long-press Edit/Delete actions on a history item, so
/// every change carries the global sync columns and lands in `sync_queue`.
/// Local implementation in Task 10; remote/sync-aware behaviour in Part B.
library;

import 'package:drift/drift.dart';

import '../../../core/repositories/base_local_repository.dart';
import '../../../database/app_database.dart';
import '../../../sync/sync_write_helper.dart';
import 'local/case_history_dao.dart';

/// Case history repository interface.
abstract class CaseHistoryRepository {
  /// Returns a non-deleted history entry by id, or null if not found.
  Future<CaseHistoryRow?> getById(String id);

  /// Updates a history entry's edited hearing values ([CaseHistoryCompanion]).
  Future<void> updateHistory(
    CaseHistoryCompanion companion, {
    CaseHistoryRow? baseEntry,
  });

  /// Soft-deletes a history entry.
  Future<void> deleteHistory(CaseHistoryRow entry);
}

/// Local Drift-backed implementation of [CaseHistoryRepository].
class LocalCaseHistoryRepository
    with BaseLocalRepository
    implements CaseHistoryRepository {
  final CaseHistoryDao _dao;

  @override
  final SyncWriteHelper syncHelper;

  /// Creates a repository backed by [dao] and [syncHelper].
  LocalCaseHistoryRepository(this._dao, this.syncHelper);

  @override
  Future<CaseHistoryRow?> getById(String id) => _dao.getById(id);

  @override
  Future<void> updateHistory(
    CaseHistoryCompanion companion, {
    CaseHistoryRow? baseEntry,
  }) async {
    final id = companion.id.value;
    final existing = baseEntry ?? await _dao.getById(id);
    if (existing == null) {
      throw StateError('Cannot update history entry $id: not found');
    }

    final now = BaseLocalRepository.nowMillis;
    final userId = currentUserId;
    final finalCompanion = companion.copyWith(
      updatedAt: Value(now),
      lastModifiedBy: Value(userId),
    );

    await _dao.update(finalCompanion);

    final updated = await _dao.getById(id);
    final payload = BaseLocalRepository.toSyncPayload(updated!.toJson());
    final changed = _changedFields(finalCompanion);

    await syncHelper.recordUpdate(
      entityType: 'case_history',
      entityId: id,
      payload: payload,
      changedFields: changed,
      basePayload: BaseLocalRepository.toSyncPayload(existing.toJson()),
      baseVersion: existing.version,
      preMutationPayload: BaseLocalRepository.toSyncPayload(existing.toJson()),
    );
  }

  @override
  Future<void> deleteHistory(CaseHistoryRow entry) async {
    final now = BaseLocalRepository.nowMillis;
    final userId = currentUserId;

    await _dao.delete(entry.id, now);

    await syncHelper.recordDelete(
      entityType: 'case_history',
      entityId: entry.id,
      payload: BaseLocalRepository.toSyncPayload(<String, dynamic>{
        'id': entry.id,
        'isDeleted': true,
        'updatedAt': now,
        'lastModifiedBy': userId,
      }),
      changedFields: ['is_deleted', 'updated_at', 'last_modified_by'],
      basePayload: BaseLocalRepository.toSyncPayload(entry.toJson()),
      baseVersion: entry.version,
      preMutationPayload: BaseLocalRepository.toSyncPayload(entry.toJson()),
    );
  }

  /// Derives changed field names from the companion's present domain fields.
  List<String> _changedFields(CaseHistoryCompanion companion) {
    final fields = <String>[];
    if (companion.hearingDate.present) fields.add('hearing_date');
    if (companion.lastStep.present) fields.add('last_step');
    if (companion.nextDate.present) fields.add('next_date');
    if (companion.noteResult.present) fields.add('note_result');
    if (companion.result.present) fields.add('result');
    return fields;
  }
}
