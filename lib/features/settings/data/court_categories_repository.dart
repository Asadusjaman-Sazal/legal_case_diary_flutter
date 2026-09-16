/// Court categories config repository.
/// Local implementation in Task 05 Phase 3; remote/sync-aware in Part B.
library;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/repositories/base_local_repository.dart';
import '../../../database/app_database.dart';
import '../../../sync/sync_write_helper.dart';
import 'local/court_categories_dao.dart';

/// Court categories repository interface.
abstract class CourtCategoriesRepository {
  Future<String> insert(CourtCategoriesCompanion companion);
  Future<void> update(CourtCategoriesCompanion companion, {CourtCategory? base});
  Future<void> delete(CourtCategory category);
  Future<CourtCategory?> getById(String id);
  Future<List<CourtCategory>> listAll({int? limit, int? offset});
  Stream<List<CourtCategory>> watchAll({int? limit, int? offset});
}

/// Local Drift-backed implementation of [CourtCategoriesRepository].
class LocalCourtCategoriesRepository with BaseLocalRepository implements CourtCategoriesRepository {
  final CourtCategoriesDao _dao;

  @override
  final SyncWriteHelper syncHelper;

  /// Creates a repository backed by [dao] and [syncHelper].
  LocalCourtCategoriesRepository(this._dao, this.syncHelper);

  @override
  Future<String> insert(CourtCategoriesCompanion companion) async {
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
      entityType: 'court_category',
      entityId: id,
      payload: payload,
      changedFields: payload.keys.toList(),
    );

    return id;
  }

  @override
  Future<void> update(CourtCategoriesCompanion companion, {CourtCategory? base}) async {
    final id = companion.id.value;
    final existing = base ?? await _dao.getById(id);
    if (existing == null) {
      throw StateError('Cannot update court category $id: not found');
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
      entityType: 'court_category',
      entityId: id,
      payload: payload,
      changedFields: changed,
      basePayload: BaseLocalRepository.toSyncPayload(existing.toJson()),
      baseVersion: existing.version,
      preMutationPayload: BaseLocalRepository.toSyncPayload(existing.toJson()),
    );
  }

  @override
  Future<void> delete(CourtCategory category) async {
    if (!category.isCustom) {
      throw StateError('Cannot delete built-in court category ${category.id}');
    }
    final now = BaseLocalRepository.nowMillis;
    final userId = currentUserId;

    await _dao.delete(category.id, now);

    await syncHelper.recordDelete(
      entityType: 'court_category',
      entityId: category.id,
      payload: BaseLocalRepository.toSyncPayload(<String, dynamic>{
        'id': category.id,
        'isDeleted': true,
        'updatedAt': now,
        'lastModifiedBy': userId,
      }),
      changedFields: ['is_deleted', 'updated_at', 'last_modified_by'],
      basePayload: BaseLocalRepository.toSyncPayload(category.toJson()),
      baseVersion: category.version,
      preMutationPayload: BaseLocalRepository.toSyncPayload(category.toJson()),
    );
  }

  @override
  Future<CourtCategory?> getById(String id) => _dao.getById(id);

  @override
  Future<List<CourtCategory>> listAll({int? limit, int? offset}) => _dao.getAll(limit: limit, offset: offset);

  @override
  Stream<List<CourtCategory>> watchAll({int? limit, int? offset}) => _dao.watchAll(limit: limit, offset: offset);

  List<String> _changedFields(CourtCategoriesCompanion companion) {
    final fields = <String>[];
    if (companion.nameKey.present) fields.add('name_key');
    if (companion.courtLevel.present) fields.add('court_level');
    if (companion.orderIndex.present) fields.add('order_index');
    if (companion.division.present) fields.add('division');
    if (companion.district.present) fields.add('district');
    return fields;
  }
}
