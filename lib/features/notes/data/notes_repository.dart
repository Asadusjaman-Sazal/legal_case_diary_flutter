/// Notes repository: manages free-form notes.
/// Local implementation in Task 05 Phase 3; remote/sync-aware in Part B.
library;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/repositories/base_local_repository.dart';
import '../../../database/app_database.dart';
import '../../../sync/sync_write_helper.dart';
import 'local/notes_dao.dart';

/// Notes repository interface.
abstract class NotesRepository {
  /// Inserts a note and returns the generated id.
  Future<String> insertNote(NotesCompanion companion);

  /// Updates a note.
  Future<void> updateNote(NotesCompanion companion, {Note? baseNote});

  /// Soft-deletes a note.
  Future<void> deleteNote(Note note);

  /// Restores a soft-deleted note (undo delete).
  Future<void> restoreNote(Note note);

  /// Toggles the pinned state of a note.
  Future<void> setPinned(String id, bool isPinned);

  /// Returns a note by id, or null if not found/deleted.
  Future<Note?> getById(String id);

  /// Lists all non-deleted notes.
  Future<List<Note>> listAll({int? limit, int? offset});

  /// Reactive stream of all non-deleted notes.
  Stream<List<Note>> watchAll({int? limit, int? offset});

  /// Searches non-deleted notes by title and body.
  Future<List<Note>> search(String query, {int? limit, int? offset});
}

/// Local Drift-backed implementation of [NotesRepository].
class LocalNotesRepository with BaseLocalRepository implements NotesRepository {
  final NotesDao _dao;

  @override
  final SyncWriteHelper syncHelper;

  /// Creates a repository backed by [dao] and [syncHelper].
  LocalNotesRepository(this._dao, this.syncHelper);

  @override
  Future<String> insertNote(NotesCompanion companion) async {
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
      entityType: 'note',
      entityId: id,
      payload: payload,
      changedFields: payload.keys.toList(),
    );

    return id;
  }

  @override
  Future<void> updateNote(NotesCompanion companion, {Note? baseNote}) async {
    final id = companion.id.value;
    final existing = baseNote ?? await _dao.getById(id);
    if (existing == null) {
      throw StateError('Cannot update note $id: not found');
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
      entityType: 'note',
      entityId: id,
      payload: payload,
      changedFields: changed,
      basePayload: BaseLocalRepository.toSyncPayload(existing.toJson()),
      baseVersion: existing.version,
      preMutationPayload: BaseLocalRepository.toSyncPayload(existing.toJson()),
    );
  }

  @override
  Future<void> deleteNote(Note note) async {
    final now = BaseLocalRepository.nowMillis;
    final userId = currentUserId;

    await _dao.delete(note.id, now);

    await syncHelper.recordDelete(
      entityType: 'note',
      entityId: note.id,
      payload: BaseLocalRepository.toSyncPayload(<String, dynamic>{
        'id': note.id,
        'isDeleted': true,
        'updatedAt': now,
        'lastModifiedBy': userId,
      }),
      changedFields: ['is_deleted', 'updated_at', 'last_modified_by'],
      basePayload: BaseLocalRepository.toSyncPayload(note.toJson()),
      baseVersion: note.version,
      preMutationPayload: BaseLocalRepository.toSyncPayload(note.toJson()),
    );
  }

  @override
  Future<void> setPinned(String id, bool isPinned) async {
    final note = await _dao.getById(id);
    if (note == null) return;

    final now = BaseLocalRepository.nowMillis;
    await _dao.setPinned(id, isPinned, now);

    final updated = await _dao.getById(id);
    final payload = BaseLocalRepository.toSyncPayload(updated!.toJson());
    await syncHelper.recordUpdate(
      entityType: 'note',
      entityId: id,
      payload: payload,
      changedFields: ['is_pinned'],
      basePayload: BaseLocalRepository.toSyncPayload(note.toJson()),
      baseVersion: note.version,
      preMutationPayload: BaseLocalRepository.toSyncPayload(note.toJson()),
    );
  }

  @override
  Future<void> restoreNote(Note note) async {
    final now = BaseLocalRepository.nowMillis;

    await _dao.restore(note.id, now);

    final restored = await _dao.getById(note.id);
    final payload = BaseLocalRepository.toSyncPayload(restored!.toJson());
    await syncHelper.recordUpdate(
      entityType: 'note',
      entityId: note.id,
      payload: payload,
      changedFields: ['is_deleted', 'updated_at', 'last_modified_by'],
      basePayload: BaseLocalRepository.toSyncPayload(note.toJson()),
      baseVersion: note.version,
      preMutationPayload: BaseLocalRepository.toSyncPayload(note.toJson()),
    );
  }

  @override
  Future<Note?> getById(String id) => _dao.getById(id);

  @override
  Future<List<Note>> listAll({int? limit, int? offset}) => _dao.getAll(limit: limit, offset: offset);

  @override
  Stream<List<Note>> watchAll({int? limit, int? offset}) => _dao.watchAll(limit: limit, offset: offset);

  @override
  Future<List<Note>> search(String query, {int? limit, int? offset}) => _dao.search(query, limit: limit, offset: offset);

  List<String> _changedFields(NotesCompanion companion) {
    final fields = <String>[];
    if (companion.title.present) fields.add('title');
    if (companion.body.present) fields.add('body');
    if (companion.items.present) fields.add('items');
    if (companion.isPinned.present) fields.add('is_pinned');
    return fields;
  }
}
