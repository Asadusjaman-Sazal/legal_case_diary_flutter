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

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import 'sync_queue_dao.dart';

/// The four states a conflict record can be in.
///
/// They are the only values `resolution_state` ever holds, so "is this conflict
/// still waiting for a person?" is one comparison rather than a guess about
/// strings scattered through the sync code.
const String conflictUnresolved = 'unresolved';

/// Answered without a person: the three-way comparison merged it.
const String conflictRebased = 'rebased';

/// Answered by the user on the Review Conflict screen.
const String conflictUserResolved = 'user_resolved';

/// The user confirmed that the queued local work is thrown away, and the
/// authoritative server row was rolled back into place.
const String conflictDiscarded = 'discarded';

/// Writes the local conflict record, queues its mirror, and returns the id.
///
/// [basePayload], [submittedPayload], [changedFields] and [serverPayload] are
/// JSON text, exactly as they are stored: they round-trip into the local text
/// columns and into the mirror payload unchanged.
///
/// A conflict that the three-way comparison could merge is logged already
/// answered: [resolutionState] `rebased` with its [resolvedAt] set, because the
/// rebase is the resolution (nothing is left for a person) and the entry is the
/// audit trail of it. Everything else defaults to `unresolved`.
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
  bool mergeableConflict = false,
  String resolutionState = conflictUnresolved,
  int? resolvedAt,
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
          resolutionState: resolutionState,
          conflictAt: conflictAt,
          resolvedAt: Value(resolvedAt),
          updatedAt: conflictAt,
          mergeableConflict: Value(mergeableConflict),
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
        'resolution_state': resolutionState,
        'mergeable_conflict': mergeableConflict,
        'conflict_at': conflictAt,
        'resolved_at': resolvedAt,
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

/// The mirror payload for one local conflict row, in snake_case.
///
/// One builder for the insert and for every later resolution update, so the
/// mirror's shape cannot drift between "the conflict happened" and "the conflict
/// was resolved". The ownership columns the local table does not carry
/// (`user_id`, `firm_id`) are added by the push worker at send time.
///
/// The server mirror stores the payloads as text and the two timestamps as
/// epoch milliseconds, exactly like the local row (the shipped server schema),
/// so this is a straight field-for-field translation and never a re-encode.
Map<String, dynamic> conflictLogMirrorPayload(ConflictLogRow row) =>
    <String, dynamic>{
      'id': row.id,
      'mutation_id': row.mutationId,
      'entity_type': row.entityType,
      'entity_id': row.entityId,
      'base_version': row.baseVersion,
      'base_payload': row.basePayload,
      'submitted_payload': row.submittedPayload,
      'changed_fields': row.changedFields,
      'server_version': row.serverVersion,
      'server_payload': row.serverPayload,
      'resolution_state': row.resolutionState,
      'mergeable_conflict': row.mergeableConflict,
      'conflict_at': row.conflictAt,
      'resolved_at': row.resolvedAt,
      'is_dismissed': row.isDismissed,
      'is_deleted': row.isDeleted,
      'updated_at': row.updatedAt,
      'last_modified_by': row.lastModifiedBy,
    };
