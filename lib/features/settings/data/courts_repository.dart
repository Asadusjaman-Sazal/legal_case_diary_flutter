/// Courts config repository.
/// Local implementation in Task 05 Phase 3; remote/sync-aware in Part B.
library;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/repositories/base_local_repository.dart';
import '../../../database/app_database.dart';
import '../../../sync/sync_write_helper.dart';
import 'local/courts_dao.dart';

/// Courts repository interface.
abstract class CourtsRepository {
  Future<String> insert(CourtsCompanion companion);
  Future<void> update(CourtsCompanion companion, {Court? base});
  Future<void> delete(Court court);
  Future<Court?> getById(String id);
  Future<List<Court>> listAll({int? limit, int? offset});
  Stream<List<Court>> watchAll({int? limit, int? offset});
  Future<List<Court>> listByCategory(String categoryId);
  Stream<List<Court>> watchByCategory(String categoryId);
}

/// Local Drift-backed implementation of [CourtsRepository].
class LocalCourtsRepository with BaseLocalRepository implements CourtsRepository {
  final CourtsDao _dao;

  @override
  final SyncWriteHelper syncHelper;

  LocalCourtsRepository(this._dao, this.syncHelper);

  @override
  Future<String> insert(CourtsCompanion companion) async {
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
      entityType: 'court',
      entityId: id,
      payload: payload,
      changedFields: payload.keys.toList(),
    );

    return id;
  }

  @override
  Future<void> update(CourtsCompanion companion, {Court? base}) async {
    final id = companion.id.value;
    final existing = base ?? await _dao.getById(id);
    if (existing == null) {
      throw StateError('Cannot update court $id: not found');
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
      entityType: 'court',
      entityId: id,
      payload: payload,
      changedFields: changed,
      basePayload: BaseLocalRepository.toSyncPayload(existing.toJson()),
      baseVersion: existing.version,
      preMutationPayload: BaseLocalRepository.toSyncPayload(existing.toJson()),
    );
  }

  @override
  Future<void> delete(Court court) async {
    if (!court.isCustom) {
      throw StateError('Cannot delete built-in court ${court.id}');
    }
    final now = BaseLocalRepository.nowMillis;
    final userId = currentUserId;

    await _dao.delete(court.id, now);

    await syncHelper.recordDelete(
      entityType: 'court',
      entityId: court.id,
      payload: BaseLocalRepository.toSyncPayload(<String, dynamic>{
        'id': court.id,
        'isDeleted': true,
        'updatedAt': now,
        'lastModifiedBy': userId,
      }),
      changedFields: ['is_deleted', 'updated_at', 'last_modified_by'],
      basePayload: BaseLocalRepository.toSyncPayload(court.toJson()),
      baseVersion: court.version,
      preMutationPayload: BaseLocalRepository.toSyncPayload(court.toJson()),
    );
  }

  @override
  Future<Court?> getById(String id) => _dao.getById(id);

  @override
  Future<List<Court>> listAll({int? limit, int? offset}) => _dao.getAll(limit: limit, offset: offset);

  @override
  Stream<List<Court>> watchAll({int? limit, int? offset}) => _dao.watchAll(limit: limit, offset: offset);

  @override
  Future<List<Court>> listByCategory(String categoryId) => _dao.getByCategory(categoryId);

  @override
  Stream<List<Court>> watchByCategory(String categoryId) => _dao.watchByCategory(categoryId);

  List<String> _changedFields(CourtsCompanion companion) {
    final fields = <String>[];
    if (companion.courtName.present) fields.add('court_name');
    if (companion.higherLowerCourts.present) fields.add('higher_lower_courts');
    if (companion.division.present) fields.add('division');
    if (companion.district.present) fields.add('district');
    if (companion.courtCategoryId.present) fields.add('court_category_id');
    return fields;
  }
}
