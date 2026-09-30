/// One place that records a rejected mutation as a local `conflict_log` row —
/// and queues the server mirror of it.
///
/// Two callers need exactly the same record: the push worker, when the server
/// answers `conflict`/`tombstone`, and the delta pull, when a pulled row
/// intersects local work that has not reached the server yet. Keeping it here
/// means the two paths can never drift into writing different-shaped logs.
///
/// `conflict_log` is a push/pull domain table, so the mirror is a plain insert
/// mutation queued like any other local write (AGENTS.md rule 4). The ownership
/// columns (`user_id`/`firm_id`) that the local table does not carry are added by
/// the push worker at send time, so they come from one place only.
library;

import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import 'sync_queue_dao.dart';

/// Writes the local conflict record, queues its mirror, and returns the id.
///
/// [basePayload], [submittedPayload], [changedFields] and [serverPayload] are
/// JSON text, exactly as they are stored: they round-trip into the local text
/// columns and into the mirror payload unchanged.
Future<String> writeConflictLog({
  required AppDatabase db,
  required SyncQueueDao queue,
  required String currentUserId,
  required String entityType,
  required String entityId,
  required String mutationId,
  required int baseVersion,
  required String basePayload,
  required String submittedPayload,
  required String changedFields,
  required int serverVersion,
  required String serverPayload,
  required int conflictAt,
}) async {
  final id = const Uuid().v4();

  await db.into(db.conflictLog).insert(
        ConflictLogCompanion.insert(
          id: id,
          mutationId: mutationId,
          entityType: entityType,
          entityId: entityId,
          baseVersion: baseVersion,
          basePayload: basePayload,
          submittedPayload: submittedPayload,
          changedFields: changedFields,
          serverVersion: serverVersion,
          serverPayload: serverPayload,
          resolutionState: 'unresolved',
          conflictAt: conflictAt,
          updatedAt: conflictAt,
        ),
      );

  await queue.insert(
    SyncQueueCompanion.insert(
      entityType: 'conflict_log',
      entityId: id,
      operation: 'insert',
      mutationId: const Uuid().v4(),
      basePayload: '{}',
      changedFields: jsonEncode(const <String>['is_deleted']),
      payload: jsonEncode(<String, dynamic>{
        'id': id,
        'mutation_id': mutationId,
        'entity_type': entityType,
        'entity_id': entityId,
        'base_version': baseVersion,
        'base_payload': basePayload,
        'submitted_payload': submittedPayload,
        'changed_fields': changedFields,
        'server_version': serverVersion,
        'server_payload': serverPayload,
        'resolution_state': 'unresolved',
        'conflict_at': conflictAt,
        'is_dismissed': false,
        'is_deleted': false,
        'updated_at': conflictAt,
        'last_modified_by': currentUserId,
      }),
      preMutationPayload: '{}',
      createdAt: conflictAt,
      state: 'pending',
    ),
  );

  return id;
}
