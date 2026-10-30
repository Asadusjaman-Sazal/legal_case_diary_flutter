/// Law names repository.
///
/// The law list is one of the editable reference lists (AGENTS.md rule 10):
/// push/pull domain, firm-shared in firm mode, and seeded with the app's
/// defaults. Its three write rules are the court list's, one for one — an
/// insert marks the row custom, an update marks it user-modified so a later
/// seed cannot overwrite the edit, and a delete refuses a built-in row.
library;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/repositories/base_local_repository.dart';
import '../../../database/app_database.dart';
import '../../../sync/sync_write_helper.dart';
import 'local/laws_dao.dart';

/// Law names repository interface.
abstract class LawsRepository {
  Future<String> insert(LawsCompanion companion);
  Future<void> update(LawsCompanion companion, {Law? base});
  Future<void> delete(Law law);
  Future<Law?> getById(String id);
  Future<List<Law>> listAll({int? limit, int? offset});
  Stream<List<Law>> watchAll({int? limit, int? offset});
}

/// Local Drift-backed implementation of [LawsRepository].
class LocalLawsRepository with BaseLocalRepository implements LawsRepository {
  final LawsDao _dao;

  @override
  final SyncWriteHelper syncHelper;

  LocalLawsRepository(this._dao, this.syncHelper);

  @override
  Future<String> insert(LawsCompanion companion) async {
    final now = BaseLocalRepository.nowMillis;
    final id = const Uuid().v4();
    final userId = currentUserId;

    final finalCompanion = companion.copyWith(
      id: Value(id),
      isCustom: const Value(true),
      isUserModified: const Value(false),
      userId: Value(userId),
      // The server stamps the firm a shared list belongs to; the client never
      // invents one, exactly as the court list does.
      firmId: const Value<String?>(null),
      // A name typed by the user goes to the end of the list unless the caller
      // asked for a position (a reorder does that through `update`).
      orderIndex: companion.orderIndex.present
          ? companion.orderIndex
          : Value(await _dao.maxOrderIndex() + 1),
      updatedAt: Value(now),
      lastModifiedBy: Value(userId),
    );

    await _dao.insert(finalCompanion);

    final inserted = await _dao.getById(id);
    final payload = BaseLocalRepository.toSyncPayload(inserted!.toJson());
    await syncHelper.recordInsert(
      entityType: 'law',
      entityId: id,
      payload: payload,
      changedFields: payload.keys.toList(),
    );

    return id;
  }

  @override
  Future<void> update(LawsCompanion companion, {Law? base}) async {
    final id = companion.id.value;
    final existing = base ?? await _dao.getById(id);
    if (existing == null) {
      throw StateError('Cannot update law $id: not found');
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
      entityType: 'law',
      entityId: id,
      payload: payload,
      changedFields: changed,
      basePayload: BaseLocalRepository.toSyncPayload(existing.toJson()),
      baseVersion: existing.version,
      preMutationPayload: BaseLocalRepository.toSyncPayload(existing.toJson()),
    );
  }

  @override
  Future<void> delete(Law law) async {
    if (!law.isCustom) {
      throw StateError('Cannot delete built-in law ${law.id}');
    }
    final now = BaseLocalRepository.nowMillis;
    final userId = currentUserId;

    await _dao.delete(law.id, now);

    await syncHelper.recordDelete(
      entityType: 'law',
      entityId: law.id,
      payload: BaseLocalRepository.toSyncPayload(<String, dynamic>{
        'id': law.id,
        'isDeleted': true,
        'updatedAt': now,
        'lastModifiedBy': userId,
      }),
      changedFields: ['is_deleted', 'updated_at', 'last_modified_by'],
      basePayload: BaseLocalRepository.toSyncPayload(law.toJson()),
      baseVersion: law.version,
      preMutationPayload: BaseLocalRepository.toSyncPayload(law.toJson()),
    );
  }

  @override
  Future<Law?> getById(String id) => _dao.getById(id);

  @override
  Future<List<Law>> listAll({int? limit, int? offset}) =>
      _dao.getAll(limit: limit, offset: offset);

  @override
  Stream<List<Law>> watchAll({int? limit, int? offset}) =>
      _dao.watchAll(limit: limit, offset: offset);

  List<String> _changedFields(LawsCompanion companion) {
    final fields = <String>[];
    if (companion.name.present) fields.add('name');
    if (companion.category.present) fields.add('category');
    if (companion.orderIndex.present) fields.add('order_index');
    return fields;
  }
}
