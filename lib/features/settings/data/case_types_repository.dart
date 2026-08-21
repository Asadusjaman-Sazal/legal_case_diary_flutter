/// Case types config repository.
/// Local implementation in Task 05 Phase 3; remote/sync-aware in Part B.
library;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/repositories/base_local_repository.dart';
import '../../../database/app_database.dart';
import '../../../sync/sync_write_helper.dart';
import 'local/case_types_dao.dart';

/// Case types repository interface.
abstract class CaseTypesRepository {
  Future<String> insert(CaseTypesCompanion companion);
  Future<void> update(CaseTypesCompanion companion, {CaseType? base});
  Future<void> delete(CaseType caseType);
  Future<CaseType?> getById(String id);
  Future<List<CaseType>> listAll({int? limit, int? offset});
  Stream<List<CaseType>> watchAll({int? limit, int? offset});
  Future<List<CaseType>> listByCategory(String categoryId);
  Stream<List<CaseType>> watchByCategory(String categoryId);
  Future<List<CaseType>> listByCaseCategory(String caseCategoryId);
  Stream<List<CaseType>> watchByCaseCategory(String caseCategoryId);
}

/// Local Drift-backed implementation of [CaseTypesRepository].
class LocalCaseTypesRepository
    with BaseLocalRepository
    implements CaseTypesRepository {
  final CaseTypesDao _dao;

  @override
  final SyncWriteHelper syncHelper;

  LocalCaseTypesRepository(this._dao, this.syncHelper);

  @override
  Future<String> insert(CaseTypesCompanion companion) async {
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
      entityType: 'case_type',
      entityId: id,
      payload: payload,
      changedFields: payload.keys.toList(),
    );

    return id;
  }

  @override
  Future<void> update(CaseTypesCompanion companion, {CaseType? base}) async {
    final id = companion.id.value;
    final existing = base ?? await _dao.getById(id);
    if (existing == null) {
      throw StateError('Cannot update case type $id: not found');
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
      entityType: 'case_type',
      entityId: id,
      payload: payload,
      changedFields: changed,
      basePayload: BaseLocalRepository.toSyncPayload(existing.toJson()),
      baseVersion: existing.version,
      preMutationPayload: BaseLocalRepository.toSyncPayload(existing.toJson()),
    );
  }

  @override
  Future<void> delete(CaseType caseType) async {
    if (!caseType.isCustom) {
      throw StateError('Cannot delete built-in case type ${caseType.id}');
    }
    final now = BaseLocalRepository.nowMillis;
    final userId = currentUserId;

    await _dao.delete(caseType.id, now);

    await syncHelper.recordDelete(
      entityType: 'case_type',
      entityId: caseType.id,
      payload: BaseLocalRepository.toSyncPayload(<String, dynamic>{
        'id': caseType.id,
        'isDeleted': true,
        'updatedAt': now,
        'lastModifiedBy': userId,
      }),
      changedFields: ['is_deleted', 'updated_at', 'last_modified_by'],
      basePayload: BaseLocalRepository.toSyncPayload(caseType.toJson()),
      baseVersion: caseType.version,
      preMutationPayload: BaseLocalRepository.toSyncPayload(caseType.toJson()),
    );
  }

  @override
  Future<CaseType?> getById(String id) => _dao.getById(id);

  @override
  Future<List<CaseType>> listAll({int? limit, int? offset}) =>
      _dao.getAll(limit: limit, offset: offset);

  @override
  Stream<List<CaseType>> watchAll({int? limit, int? offset}) =>
      _dao.watchAll(limit: limit, offset: offset);

  @override
  Future<List<CaseType>> listByCategory(String categoryId) =>
      _dao.getByCategory(categoryId);

  @override
  Stream<List<CaseType>> watchByCategory(String categoryId) =>
      _dao.watchByCategory(categoryId);

  @override
  Future<List<CaseType>> listByCaseCategory(String caseCategoryId) =>
      _dao.getByCaseCategory(caseCategoryId);

  @override
  Stream<List<CaseType>> watchByCaseCategory(String caseCategoryId) =>
      _dao.watchByCaseCategory(caseCategoryId);

  List<String> _changedFields(CaseTypesCompanion companion) {
    final fields = <String>[];
    if (companion.courtCategoryId.present) fields.add('court_category_id');
    if (companion.caseCategoryId.present) fields.add('case_category_id');
    if (companion.name.present) fields.add('name');
    if (companion.orderIndex.present) fields.add('order_index');
    return fields;
  }
}
