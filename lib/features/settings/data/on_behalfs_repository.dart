/// On-behalfs config repository.
/// Local implementation in Task 05 Phase 3; remote/sync-aware in Part B.
library;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/repositories/base_local_repository.dart';
import '../../../database/app_database.dart';
import '../../../sync/sync_write_helper.dart';
import 'local/on_behalfs_dao.dart';

/// On-behalfs repository interface.
abstract class OnBehalfsRepository {
  Future<String> insert(OnBehalfsCompanion companion);
  Future<void> update(OnBehalfsCompanion companion, {OnBehalf? base});
  Future<void> delete(OnBehalf onBehalf);
  Future<OnBehalf?> getById(String id);
  Future<List<OnBehalf>> listAll({int? limit, int? offset});
  Stream<List<OnBehalf>> watchAll({int? limit, int? offset});
  Future<List<OnBehalf>> listByCategory(String categoryId);
  Stream<List<OnBehalf>> watchByCategory(String categoryId);
}

/// Local Drift-backed implementation of [OnBehalfsRepository].
class LocalOnBehalfsRepository with BaseLocalRepository implements OnBehalfsRepository {
  final OnBehalfsDao _dao;

  @override
  final SyncWriteHelper syncHelper;

  LocalOnBehalfsRepository(this._dao, this.syncHelper);

  @override
  Future<String> insert(OnBehalfsCompanion companion) async {
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
      entityType: 'on_behalf',
      entityId: id,
      payload: payload,
      changedFields: payload.keys.toList(),
    );

    return id;
  }

  @override
  Future<void> update(OnBehalfsCompanion companion, {OnBehalf? base}) async {
    final id = companion.id.value;
    final existing = base ?? await _dao.getById(id);
    if (existing == null) {
      throw StateError('Cannot update on-behalf $id: not found');
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
      entityType: 'on_behalf',
      entityId: id,
      payload: payload,
      changedFields: changed,
      basePayload: BaseLocalRepository.toSyncPayload(existing.toJson()),
      baseVersion: existing.version,
      preMutationPayload: BaseLocalRepository.toSyncPayload(existing.toJson()),
    );
  }

  @override
  Future<void> delete(OnBehalf onBehalf) async {
    if (!onBehalf.isCustom) {
      throw StateError('Cannot delete built-in on-behalf ${onBehalf.id}');
    }
    final now = BaseLocalRepository.nowMillis;
    final userId = currentUserId;

    await _dao.delete(onBehalf.id, now);

    await syncHelper.recordDelete(
      entityType: 'on_behalf',
      entityId: onBehalf.id,
      payload: BaseLocalRepository.toSyncPayload(<String, dynamic>{
        'id': onBehalf.id,
        'isDeleted': true,
        'updatedAt': now,
        'lastModifiedBy': userId,
      }),
      changedFields: ['is_deleted', 'updated_at', 'last_modified_by'],
      basePayload: BaseLocalRepository.toSyncPayload(onBehalf.toJson()),
      baseVersion: onBehalf.version,
      preMutationPayload: BaseLocalRepository.toSyncPayload(onBehalf.toJson()),
    );
  }

  @override
  Future<OnBehalf?> getById(String id) => _dao.getById(id);

  @override
  Future<List<OnBehalf>> listAll({int? limit, int? offset}) => _dao.getAll(limit: limit, offset: offset);

  @override
  Stream<List<OnBehalf>> watchAll({int? limit, int? offset}) => _dao.watchAll(limit: limit, offset: offset);

  @override
  Future<List<OnBehalf>> listByCategory(String categoryId) => _dao.getByCategory(categoryId);

  @override
  Stream<List<OnBehalf>> watchByCategory(String categoryId) => _dao.watchByCategory(categoryId);

  List<String> _changedFields(OnBehalfsCompanion companion) {
    final fields = <String>[];
    if (companion.courtCategoryId.present) fields.add('court_category_id');
    if (companion.name.present) fields.add('name');
    if (companion.orderIndex.present) fields.add('order_index');
    return fields;
  }
}
