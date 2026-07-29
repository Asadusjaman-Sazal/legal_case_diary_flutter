/// Steps config repository.
/// Local implementation in Task 05 Phase 3; remote/sync-aware in Part B.
library;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/repositories/base_local_repository.dart';
import '../../../database/app_database.dart';
import '../../../sync/sync_write_helper.dart';
import 'local/steps_dao.dart';

/// Steps repository interface.
abstract class StepsRepository {
  Future<String> insert(StepsCompanion companion);
  Future<void> update(StepsCompanion companion, {Step? base});
  Future<void> delete(Step step);
  Future<Step?> getById(String id);
  Future<List<Step>> listAll({int? limit, int? offset});
  Stream<List<Step>> watchAll({int? limit, int? offset});
  Future<List<Step>> listByCategory(String categoryId);
  Stream<List<Step>> watchByCategory(String categoryId);
}

/// Local Drift-backed implementation of [StepsRepository].
class LocalStepsRepository with BaseLocalRepository implements StepsRepository {
  final StepsDao _dao;

  @override
  final SyncWriteHelper syncHelper;

  LocalStepsRepository(this._dao, this.syncHelper);

  @override
  Future<String> insert(StepsCompanion companion) async {
    final now = BaseLocalRepository.nowMillis;
    final id = const Uuid().v4();
    final userId = currentUserId;

    final finalCompanion = companion.copyWith(
      id: Value(id),
      isCustom: const Value(true),
      isUserModified: const Value(false),
      userId: Value(userId),
      firmId: const Value<String?>(null),
      updatedAt: Value(now),
      lastModifiedBy: Value(userId),
    );

    await _dao.insert(finalCompanion);

    final inserted = await _dao.getById(id);
    final payload = BaseLocalRepository.toSyncPayload(inserted!.toJson());
    await syncHelper.recordInsert(
      entityType: 'step',
      entityId: id,
      payload: payload,
      changedFields: payload.keys.toList(),
    );

    return id;
  }

  @override
  Future<void> update(StepsCompanion companion, {Step? base}) async {
    final id = companion.id.value;
    final existing = base ?? await _dao.getById(id);
    if (existing == null) {
      throw StateError('Cannot update step $id: not found');
    }

    final now = BaseLocalRepository.nowMillis;
    final userId = currentUserId;

    final finalCompanion = companion.copyWith(
      isUserModified: const Value(true),
      updatedAt: Value(now),
      lastModifiedBy: Value(userId),
    );

    await _dao.update(finalCompanion);

    final updated = await _dao.getById(id);
    final payload = BaseLocalRepository.toSyncPayload(updated!.toJson());
    final changed = _changedFields(finalCompanion);

    await syncHelper.recordUpdate(
      entityType: 'step',
      entityId: id,
      payload: payload,
      changedFields: changed,
      basePayload: BaseLocalRepository.toSyncPayload(existing.toJson()),
      baseVersion: existing.version,
      preMutationPayload: BaseLocalRepository.toSyncPayload(existing.toJson()),
    );
  }

  @override
  Future<void> delete(Step step) async {
    if (!step.isCustom) {
      throw StateError('Cannot delete built-in step ${step.id}');
    }
    final now = BaseLocalRepository.nowMillis;
    final userId = currentUserId;

    await _dao.delete(step.id, now);

    await syncHelper.recordDelete(
      entityType: 'step',
      entityId: step.id,
      payload: BaseLocalRepository.toSyncPayload(<String, dynamic>{
        'id': step.id,
        'isDeleted': true,
        'updatedAt': now,
        'lastModifiedBy': userId,
      }),
      changedFields: ['is_deleted', 'updated_at', 'last_modified_by'],
      basePayload: BaseLocalRepository.toSyncPayload(step.toJson()),
      baseVersion: step.version,
      preMutationPayload: BaseLocalRepository.toSyncPayload(step.toJson()),
    );
  }

  @override
  Future<Step?> getById(String id) => _dao.getById(id);

  @override
  Future<List<Step>> listAll({int? limit, int? offset}) => _dao.getAll(limit: limit, offset: offset);

  @override
  Stream<List<Step>> watchAll({int? limit, int? offset}) => _dao.watchAll(limit: limit, offset: offset);

  @override
  Future<List<Step>> listByCategory(String categoryId) => _dao.getByCategory(categoryId);

  @override
  Stream<List<Step>> watchByCategory(String categoryId) => _dao.watchByCategory(categoryId);

  List<String> _changedFields(StepsCompanion companion) {
    final fields = <String>[];
    if (companion.courtCategoryId.present) fields.add('court_category_id');
    if (companion.stepName.present) fields.add('step_name');
    if (companion.orderIndex.present) fields.add('order_index');
    return fields;
  }
}
