/// Case reference repository: manages precedents and citations.
/// Local implementation in Task 05 Phase 3; remote/sync-aware in Part B.
library;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/repositories/base_local_repository.dart';
import '../../../database/app_database.dart';
import '../../../sync/sync_write_helper.dart';
import 'local/case_references_dao.dart';

/// Case reference repository interface.
abstract class ReferenceRepository {
  /// Inserts a reference and returns the generated id.
  Future<String> insertReference(CaseReferencesCompanion companion);

  /// Updates a reference.
  Future<void> updateReference(
    CaseReferencesCompanion companion, {
    CaseReference? baseReference,
  });

  /// Soft-deletes a reference.
  Future<void> deleteReference(CaseReference reference);

  /// Restores a soft-deleted reference (undo delete).
  Future<void> restoreReference(CaseReference reference);

  /// Toggles the pinned state of a reference.
  Future<void> setPinned(String id, bool isPinned);

  /// Returns a reference by id, or null if not found/deleted.
  Future<CaseReference?> getById(String id);

  /// Lists all non-deleted references.
  Future<List<CaseReference>> listAll({int? limit, int? offset});

  /// Reactive stream of all non-deleted references.
  Stream<List<CaseReference>> watchAll({int? limit, int? offset});

  /// Searches non-deleted references.
  Future<List<CaseReference>> search(String query, {int? limit, int? offset});
}

/// Local Drift-backed implementation of [ReferenceRepository].
class LocalReferenceRepository
    with BaseLocalRepository
    implements ReferenceRepository {
  final CaseReferencesDao _dao;

  @override
  final SyncWriteHelper syncHelper;

  /// Creates a repository backed by [dao] and [syncHelper].
  LocalReferenceRepository(this._dao, this.syncHelper);

  @override
  Future<String> insertReference(CaseReferencesCompanion companion) async {
    final now = BaseLocalRepository.nowMillis;
    final id = const Uuid().v4();
    final userId = currentUserId;

    final finalCompanion = companion.copyWith(
      id: Value(id),
      userId: Value(userId),
      firmId: const Value<String?>(null),
      createdAt: Value(now),
      updatedAt: Value(now),
      lastModifiedBy: Value(userId),
      isDeleted: const Value(false),
    );

    await _dao.insert(finalCompanion);

    final inserted = await _dao.getById(id);
    final payload = BaseLocalRepository.toSyncPayload(inserted!.toJson());
    await syncHelper.recordInsert(
      entityType: 'reference',
      entityId: id,
      payload: payload,
      changedFields: payload.keys.toList(),
    );

    return id;
  }

  @override
  Future<void> updateReference(
    CaseReferencesCompanion companion, {
    CaseReference? baseReference,
  }) async {
    final id = companion.id.value;
    final existing = baseReference ?? await _dao.getById(id);
    if (existing == null) {
      throw StateError('Cannot update reference $id: not found');
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
      entityType: 'reference',
      entityId: id,
      payload: payload,
      changedFields: changed,
      basePayload: BaseLocalRepository.toSyncPayload(existing.toJson()),
      baseVersion: existing.version,
      preMutationPayload: BaseLocalRepository.toSyncPayload(existing.toJson()),
    );
  }

  @override
  Future<void> deleteReference(CaseReference reference) async {
    final now = BaseLocalRepository.nowMillis;
    final userId = currentUserId;

    await _dao.delete(reference.id, now);

    await syncHelper.recordDelete(
      entityType: 'reference',
      entityId: reference.id,
      payload: BaseLocalRepository.toSyncPayload(<String, dynamic>{
        'id': reference.id,
        'isDeleted': true,
        'updatedAt': now,
        'lastModifiedBy': userId,
      }),
      changedFields: ['is_deleted', 'updated_at', 'last_modified_by'],
      basePayload: BaseLocalRepository.toSyncPayload(reference.toJson()),
      baseVersion: reference.version,
      preMutationPayload: BaseLocalRepository.toSyncPayload(reference.toJson()),
    );
  }

  @override
  Future<void> restoreReference(CaseReference reference) async {
    final now = BaseLocalRepository.nowMillis;

    await _dao.restore(reference.id, now);

    final restored = await _dao.getById(reference.id);
    final payload = BaseLocalRepository.toSyncPayload(restored!.toJson());
    await syncHelper.recordUpdate(
      entityType: 'reference',
      entityId: reference.id,
      payload: payload,
      changedFields: ['is_deleted', 'updated_at', 'last_modified_by'],
      basePayload: BaseLocalRepository.toSyncPayload(reference.toJson()),
      baseVersion: reference.version,
      preMutationPayload: BaseLocalRepository.toSyncPayload(reference.toJson()),
    );
  }

  @override
  Future<void> setPinned(String id, bool isPinned) async {
    final reference = await _dao.getById(id);
    if (reference == null) return;

    final now = BaseLocalRepository.nowMillis;
    await _dao.setPinned(id, isPinned, now);

    final updated = await _dao.getById(id);
    final payload = BaseLocalRepository.toSyncPayload(updated!.toJson());
    await syncHelper.recordUpdate(
      entityType: 'reference',
      entityId: id,
      payload: payload,
      changedFields: ['is_pinned'],
      basePayload: BaseLocalRepository.toSyncPayload(reference.toJson()),
      baseVersion: reference.version,
      preMutationPayload: BaseLocalRepository.toSyncPayload(reference.toJson()),
    );
  }

  @override
  Future<CaseReference?> getById(String id) => _dao.getById(id);

  @override
  Future<List<CaseReference>> listAll({int? limit, int? offset}) =>
      _dao.getAll(limit: limit, offset: offset);

  @override
  Stream<List<CaseReference>> watchAll({int? limit, int? offset}) =>
      _dao.watchAll(limit: limit, offset: offset);

  @override
  Future<List<CaseReference>> search(String query, {int? limit, int? offset}) =>
      _dao.search(query, limit: limit, offset: offset);

  List<String> _changedFields(CaseReferencesCompanion companion) {
    final fields = <String>[];
    if (companion.referenceAndPageNo.present) {
      fields.add('reference_and_page_no');
    }
    if (companion.statute.present) fields.add('statute');
    if (companion.sectionOrArticle.present) fields.add('section_or_article');
    if (companion.titleAndDescription.present) {
      fields.add('title_and_description');
    }
    if (companion.commentsNotes.present) fields.add('comments_notes');
    if (companion.caseNote.present) fields.add('case_note');
    if (companion.tags.present) fields.add('tags');
    if (companion.isPinned.present) fields.add('is_pinned');
    return fields;
  }
}
