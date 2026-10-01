/// Sync-ready local write helper.
///
/// Repositories call this helper **after** writing to Drift so that every
/// insert, update, or soft-delete is reflected in the local `sync_queue` and
/// ready for push in Part B.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/services/local_identity_service.dart';
import '../database/app_database.dart';
import '../shared/providers/database_provider.dart';
import 'recovery_lock.dart';
import 'sync_queue_dao.dart';

/// The sync-able operation being recorded.
enum SyncOperation { insert, update, delete }

/// Convenience holder for the sync columns that every push-domain repository
/// must set on a row before (or while) calling [SyncWriteHelper].
class SyncColumns {
  /// Epoch millisecond timestamp for `updated_at`.
  final int updatedAt;

  /// Local identity UUID for `last_modified_by`.
  final String lastModifiedBy;

  /// `synced_at` is null until the server confirms the write.
  final int? syncedAt;

  /// Soft-delete flag; only transitions false -> true through a repository.
  final bool isDeleted;

  /// Creates a holder with the given values.
  const SyncColumns({
    required this.updatedAt,
    required this.lastModifiedBy,
    this.syncedAt,
    this.isDeleted = false,
  });
}

/// Encapsulates the common logic for recording local mutations in the
/// `sync_queue`, including the offline compaction matrix and the local identity.
class SyncWriteHelper {
  final SyncQueueDao _queue;
  final LocalIdentityService _identity;

  /// Creates a helper backed by [_queue] and [_identity].
  SyncWriteHelper(this._queue, this._identity);

  /// Stable local identity UUID used for `last_modified_by` in Part A.
  String get currentUserId => _identity.getId();

  /// Current epoch timestamp in milliseconds (UTC).
  static int get nowMillis => DateTime.now().toUtc().millisecondsSinceEpoch;

  /// Sync column values repositories must apply to every push-domain write.
  SyncColumns syncColumns({bool isDeleted = false}) => SyncColumns(
    updatedAt: nowMillis,
    lastModifiedBy: currentUserId,
    isDeleted: isDeleted,
  );

  /// Records an insert into `sync_queue` (with compaction).
  Future<void> recordInsert({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> payload,
    required List<String> changedFields,
    Map<String, dynamic>? basePayload,
    int? baseVersion,
    Map<String, dynamic>? preMutationPayload,
  }) => _record(
    operation: SyncOperation.insert,
    entityType: entityType,
    entityId: entityId,
    payload: payload,
    changedFields: changedFields,
    basePayload: basePayload,
    baseVersion: baseVersion,
    preMutationPayload: preMutationPayload,
  );

  /// Records an update into `sync_queue` (with compaction).
  Future<void> recordUpdate({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> payload,
    required List<String> changedFields,
    Map<String, dynamic>? basePayload,
    int? baseVersion,
    Map<String, dynamic>? preMutationPayload,
  }) => _record(
    operation: SyncOperation.update,
    entityType: entityType,
    entityId: entityId,
    payload: payload,
    changedFields: changedFields,
    basePayload: basePayload,
    baseVersion: baseVersion,
    preMutationPayload: preMutationPayload,
  );

  /// Records a soft-delete into `sync_queue` (with compaction).
  Future<void> recordDelete({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> payload,
    required List<String> changedFields,
    Map<String, dynamic>? basePayload,
    int? baseVersion,
    Map<String, dynamic>? preMutationPayload,
  }) => _record(
    operation: SyncOperation.delete,
    entityType: entityType,
    entityId: entityId,
    payload: payload,
    changedFields: changedFields,
    basePayload: basePayload,
    baseVersion: baseVersion,
    preMutationPayload: preMutationPayload,
  );

  Future<void> _record({
    required SyncOperation operation,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> payload,
    required List<String> changedFields,
    Map<String, dynamic>? basePayload,
    int? baseVersion,
    Map<String, dynamic>? preMutationPayload,
  }) async {
    // Repositories reject every mutation while the extended-offline lock is set
    // (Task 19 Phase 5). This is the guard behind the blocking screen: a path
    // that never reaches the UI still cannot queue work that the coming
    // reconstruction would discard.
    //
    // `ponytail:` the check lives at the queue write rather than at the top of
    // each repository method, because the queue write is the one place every
    // mutation passes through. A repository that has already written its row
    // leaves an unsynced row behind when this throws — which recovery discards
    // along with everything else, so nothing survives it. Upgrade by hoisting a
    // guard to the repository entry points if a local write ever needs to be
    // prevented before it happens.
    if (await RecoveryLock(_queue.db).isRequired()) {
      throw const RecoveryRequiredException();
    }

    // Only **open** entries are prior mutations. `getByEntity` returns every
    // entry the entity has ever had, `resolved` ones included, and a resolved
    // entry is finished work the server already holds — not something to compact
    // against. Counting it made an entity whose first insert had been pushed and
    // resolved swallow every later mutation: a delete compacted to nothing at all
    // (so the server was never told), and an edit rewrote itself into a fresh
    // insert the server would refuse as a duplicate id. Found by Task 20 Phase 3,
    // whose cancel-after-sync depends on the delete being queued; it applied to
    // every push-domain table.
    final existing = (await _queue.getByEntity(entityType, entityId))
        .where((row) => row.state != 'resolved')
        .toList(growable: false);

    // Inserts are always enqueued as a new pending row (a second insert for the
    // same entity is an caller error, but preserving it is safest). We also
    // skip compaction whenever there is a conflict pending row or no prior
    // pending row for this entity.
    final hasConflict = existing.any((row) => row.state == 'conflict_pending');
    if (hasConflict || operation == SyncOperation.insert || existing.isEmpty) {
      await _insertPending(
        operation: operation,
        entityType: entityType,
        entityId: entityId,
        payload: payload,
        changedFields: changedFields,
        basePayload: basePayload,
        baseVersion: baseVersion,
        preMutationPayload: preMutationPayload,
      );
      return;
    }

    final first = existing.first;

    switch (operation) {
      case SyncOperation.insert:
        // Unreachable because of the early return above; inserts are always
        // enqueued directly before reaching the switch.
        throw StateError(
          'Unexpected insert compaction attempt for $entityType:$entityId',
        );

      case SyncOperation.update:
        if (first.operation == 'insert') {
          // insert + update(s) -> single insert with the latest snapshot.
          await _compactToSingle(
            existing: existing,
            operation: SyncOperation.insert,
            payload: payload,
            changedFields: changedFields,
            mutationId: first.mutationId,
          );
        } else if (first.operation == 'update') {
          // multiple updates -> single update with the latest snapshot.
          await _compactToSingle(
            existing: existing,
            operation: SyncOperation.update,
            payload: payload,
            changedFields: changedFields,
            mutationId: first.mutationId,
          );
        } else {
          // Existing pending delete then an update -> treat as new pending row.
          await _insertPending(
            operation: operation,
            entityType: entityType,
            entityId: entityId,
            payload: payload,
            changedFields: changedFields,
            basePayload: basePayload,
            baseVersion: baseVersion,
            preMutationPayload: preMutationPayload,
          );
        }

      case SyncOperation.delete:
        if (first.operation == 'insert') {
          // insert + delete -> server never needs to know; drop both.
          await _queue.db.transaction(() async {
            for (final row in existing) {
              await _queue.delete(row.id);
            }
          });
        } else {
          // update(s) + delete -> single soft-delete update with latest snapshot.
          await _compactToSingle(
            existing: existing,
            operation: SyncOperation.delete,
            payload: payload,
            changedFields: changedFields,
            mutationId: first.operation == 'delete' ? first.mutationId : null,
          );
        }
    }
  }

  /// Replaces a run of [existing] queue rows with a single compacted row.
  Future<void> _compactToSingle({
    required List<SyncQueueRow> existing,
    required SyncOperation operation,
    required Map<String, dynamic> payload,
    required List<String> changedFields,
    required String? mutationId,
  }) async {
    final first = existing.first;
    final allChanged = <String>{...changedFields};
    for (final row in existing) {
      final fields = jsonDecode(row.changedFields) as List<dynamic>;
      for (final field in fields) {
        if (field is String) allChanged.add(field);
      }
    }

    final entityType = first.entityType;
    final entityId = first.entityId;

    await _queue.db.transaction(() async {
      for (final row in existing) {
        await _queue.delete(row.id);
      }
      await _insertPending(
        operation: operation,
        entityType: entityType,
        entityId: entityId,
        payload: payload,
        changedFields: allChanged.toList(),
        basePayload: _jsonToMap(first.basePayload),
        baseVersion: first.baseVersion,
        preMutationPayload: _jsonToMap(first.preMutationPayload),
        mutationId: mutationId,
      );
    });
  }

  Future<void> _insertPending({
    required SyncOperation operation,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> payload,
    required List<String> changedFields,
    Map<String, dynamic>? basePayload,
    int? baseVersion,
    Map<String, dynamic>? preMutationPayload,
    String? mutationId,
  }) async {
    final effectiveBasePayload = basePayload ?? <String, dynamic>{};
    final effectivePrePayload = preMutationPayload ?? <String, dynamic>{};

    final companion = SyncQueueCompanion(
      entityType: Value(entityType),
      entityId: Value(entityId),
      operation: Value(operation.name),
      mutationId: Value(mutationId ?? const Uuid().v4()),
      baseVersion: baseVersion == null
          ? const Value.absent()
          : Value(baseVersion),
      basePayload: Value(jsonEncode(effectiveBasePayload)),
      changedFields: Value(jsonEncode(changedFields)),
      payload: Value(jsonEncode(payload)),
      preMutationPayload: Value(jsonEncode(effectivePrePayload)),
      createdAt: Value(nowMillis),
      state: const Value('pending'),
    );

    await _queue.insert(companion);
  }

  /// Parses a JSON string into a mutable map, defaulting to an empty map.
  Map<String, dynamic> _jsonToMap(String json) {
    if (json.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(json);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{};
  }
}

/// Riverpod provider for the shared [SyncWriteHelper].
final syncWriteHelperProvider = FutureProvider<SyncWriteHelper>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final identity = ref.watch(localIdentityServiceProvider);
  return SyncWriteHelper(SyncQueueDao(db), identity);
});
