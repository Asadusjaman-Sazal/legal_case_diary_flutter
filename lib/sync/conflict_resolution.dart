/// The one place a conflict is answered (Task 19 Phase 3).
///
/// Detection happens in two workers — the push worker when `push_changes`
/// refuses a mutation, and the delta pull when an authoritative row intersects
/// local work that has not reached the server yet — but the *decision* and its
/// side effects must not drift between them, so both funnel through
/// [ConflictResolver].
///
/// Three answers, and only three:
///
/// * **Rebase, automatically** — the local edit and the server's change touch
///   disjoint fields (see `conflict_rebase.dart`). The local values are laid over
///   the authoritative row, a **new** mutation is sent against the server's
///   version, and the conflict is logged already answered. No person is asked.
/// * **Ask a person** — the changes overlap or are semantically coupled. Nothing
///   is overwritten and nothing is thrown away: the entity is frozen, every later
///   queue entry for it is preserved, and the Review Conflict screen decides.
/// * **A tombstone** — the server row is deleted. The plan's Zombie Data rule
///   forbids doing anything silently here, so it is always the second answer, and
///   the Review screen offers exactly two ways out: copy the local work onto a
///   **new** record, or confirm the discard with an authoritative rollback.
///
/// Resolution is the only thing that changes `resolution_state`. Dismissing the
/// banner and the passage of time never do (Sync Plan §1).
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import 'conflict_log_dao.dart';
import 'conflict_rebase.dart';
import 'entity_tables.dart';
import 'sync_conflict_log.dart';
import 'sync_queue_dao.dart';
import 'sync_table_bindings.dart';

/// Answers conflicts against one local database.
class ConflictResolver {
  /// Creates a resolver over [db], its [queue] and the signed-in account id.
  ConflictResolver({
    required this.db,
    required this.queue,
    required this.currentUserId,
    ConflictLogDao? conflictDao,
  }) : conflicts = conflictDao ?? ConflictLogDao(db);

  /// The encrypted local database.
  final AppDatabase db;

  /// The outbound queue, whose rows are rebased or released.
  final SyncQueueDao queue;

  /// Injected into the conflict mirror, exactly like every other local write.
  final String currentUserId;

  /// Reads and answers the conflict records themselves.
  final ConflictLogDao conflicts;

  /// Detects a conflict between queued local work [row] and the authoritative
  /// [serverRow], and rebases it when the changes are disjoint.
  ///
  /// Returns true when a person is now needed — the caller freezes the entity and
  /// surfaces the conflict; when it returns false the conflict is already
  /// answered and the rebased mutation is back in the queue.
  Future<bool> reconcile({
    required SyncQueueRow row,
    required Map<String, dynamic> serverRow,
  }) async {
    final plan = planConflictRebase(
      base: decodeJsonObject(row.basePayload),
      server: serverRow,
      local: decodeJsonObject(row.payload),
      changedFields: decodeJsonStringList(row.changedFields),
    );
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final serverVersion = _int(serverRow['version']) ?? 0;

    if (plan.mergeable && plan.payload != null) {
      final merged = plan.payload!;
      // The merged state becomes the new mutation: a fresh id (the rejected one
      // already has a server receipt), the server's version as its base, and the
      // authoritative row as both the common base and the rollback snapshot.
      await queue.rebaseMutation(
        row.id,
        mutationId: const Uuid().v4(),
        baseVersion: serverVersion,
        basePayload: jsonEncode(serverRow),
        payload: jsonEncode(merged),
        changedFields: jsonEncode(plan.mergedFields),
        preMutationPayload: jsonEncode(serverRow),
      );
      await _applyLocally(row.entityType, merged);
      await writeConflictLog(
        db: db,
        queue: queue,
        currentUserId: currentUserId,
        entityType: row.entityType,
        entityId: row.entityId,
        mutationId: row.mutationId,
        baseVersion: row.baseVersion ?? 0,
        basePayload: row.basePayload,
        submittedPayload: row.payload,
        changedFields: row.changedFields,
        serverVersion: serverVersion,
        serverPayload: jsonEncode(serverRow),
        conflictAt: now,
        mergeableConflict: true,
        resolutionState: conflictRebased,
        resolvedAt: now,
      );
      return false;
    }

    await writeConflictLog(
      db: db,
      queue: queue,
      currentUserId: currentUserId,
      entityType: row.entityType,
      entityId: row.entityId,
      mutationId: row.mutationId,
      baseVersion: row.baseVersion ?? 0,
      basePayload: row.basePayload,
      submittedPayload: row.payload,
      changedFields: row.changedFields,
      serverVersion: serverVersion,
      serverPayload: jsonEncode(serverRow),
      conflictAt: now,
      mergeableConflict: false,
    );
    await queue.freezeEntity(
      row.entityType,
      row.entityId,
      error: plan.reason,
    );
    return true;
  }

  /// The user's answer to an ambiguous conflict: the field values they chose.
  ///
  /// [chosen] is snake_case field -> value, already resolved to either the
  /// server's or the local value by the Review screen. The result is one new
  /// mutation against the server's version — the preserved rows it replaces are
  /// released, never silently dropped — and the conflict is marked
  /// `user_resolved`.
  Future<void> resolveWithFields(
    ConflictLogRow conflict, {
    required Map<String, dynamic> chosen,
  }) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final server = decodeJsonObject(conflict.serverPayload);
    final payload = <String, dynamic>{...server, ...chosen};

    await queue.resolveEntity(conflict.entityType, conflict.entityId);
    await queue.insert(
      SyncQueueCompanion.insert(
        entityType: conflict.entityType,
        entityId: conflict.entityId,
        operation: 'update',
        mutationId: const Uuid().v4(),
        baseVersion: Value(conflict.serverVersion),
        basePayload: conflict.serverPayload,
        changedFields: jsonEncode(chosen.keys.toList(growable: false)),
        payload: jsonEncode(payload),
        preMutationPayload: conflict.serverPayload,
        createdAt: now,
        state: 'pending',
      ),
    );
    await _applyLocally(conflict.entityType, payload);
    await _markResolved(conflict, state: conflictUserResolved, resolvedAt: now);
  }

  /// Keeps the local work by giving it a record of its own.
  ///
  /// The tombstone's other legal answer: the server row is gone, so the preserved
  /// edit becomes a **new** record — new id, queued as an insert — instead of
  /// resurrecting the deleted row (Sync Plan §3). The deleted row stays deleted.
  Future<void> rebaseOntoNewRecord(ConflictLogRow conflict) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    // The submitted payload already passed the server's column check (it was
    // rejected for its version, not for its shape), so it is the safest possible
    // source for the copy: exactly the columns the entity actually has.
    final payload = decodeJsonObject(conflict.submittedPayload);
    final id = const Uuid().v4();
    payload['id'] = id;
    payload['is_deleted'] = false;
    payload['updated_at'] = now;
    // Server-owned or server-assigned columns are never sent by the client; the
    // row is new, so it starts at version 1 with this device as its author.
    payload
      ..remove('version')
      ..remove('last_modified_by')
      ..remove('server_updated_at')
      ..remove('synced_at');
    if (payload.containsKey('created_at')) payload['created_at'] = now;

    await queue.resolveEntity(conflict.entityType, conflict.entityId);
    await queue.insert(
      SyncQueueCompanion.insert(
        entityType: conflict.entityType,
        entityId: id,
        operation: 'insert',
        mutationId: const Uuid().v4(),
        basePayload: '{}',
        changedFields: jsonEncode(payload.keys.toList(growable: false)),
        payload: jsonEncode(payload),
        preMutationPayload: '{}',
        createdAt: now,
        state: 'pending',
      ),
    );
    await _applyLocally(conflict.entityType, payload);
    await _markResolved(conflict, state: conflictUserResolved, resolvedAt: now);
  }

  /// Throws the preserved local work away, deliberately, and puts the
  /// authoritative server row back in its place.
  ///
  /// This is the only path that discards queued work, and it can only be reached
  /// from the Review screen's explicit confirmation. The rollback is the server
  /// row itself — for a tombstone that hides the record locally, which is exactly
  /// what the server says is true.
  Future<void> discard(ConflictLogRow conflict) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await queue.resolveEntity(conflict.entityType, conflict.entityId);
    await _applyLocally(conflict.entityType, decodeJsonObject(conflict.serverPayload));
    await _markResolved(conflict, state: conflictDiscarded, resolvedAt: now);
  }

  /// Records the answer locally and queues its mirror update.
  ///
  /// The mirror is an ordinary `conflict_log` **update** mutation, so a conflict
  /// raised on one device reads as answered on every other one — the same
  /// one-shape-for-insert-and-update rule [conflictLogMirrorPayload] exists for.
  Future<void> _markResolved(
    ConflictLogRow conflict, {
    required String state,
    required int resolvedAt,
  }) async {
    await conflicts.setResolution(
      conflict.id,
      resolutionState: state,
      resolvedAt: resolvedAt,
      updatedAt: resolvedAt,
    );
    final updated = await conflicts.getById(conflict.id);
    if (updated == null) return;

    await queue.insert(
      SyncQueueCompanion.insert(
        entityType: 'conflict_log',
        entityId: updated.id,
        operation: 'update',
        mutationId: const Uuid().v4(),
        baseVersion: Value(updated.version),
        basePayload: jsonEncode(conflictLogMirrorPayload(conflict)),
        changedFields: jsonEncode(const <String>[
          'resolution_state',
          'resolved_at',
          'updated_at',
        ]),
        payload: jsonEncode(conflictLogMirrorPayload(updated)),
        preMutationPayload: jsonEncode(conflictLogMirrorPayload(conflict)),
        createdAt: resolvedAt,
        state: 'pending',
      ),
    );
  }

  /// Writes a reconciled payload into its local table, when the entity has a
  /// binding. An entity outside the synced class has nothing to write.
  Future<void> _applyLocally(String entityType, Map<String, dynamic> payload) async {
    final binding = syncBindingFor(entityType);
    if (binding == null) return;
    await binding.applyServerRow(db, payload);
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
