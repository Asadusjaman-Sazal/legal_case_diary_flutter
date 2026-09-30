/// The push worker: one serialized FIFO batch of local mutations per call.
///
/// It never runs two pushes at once. A batch is built in FK-safe dependency
/// order, written to `sync_queue.last_attempt_at` immediately before the
/// attempt, and sent through the single `push_changes` RPC. Every terminal
/// result is applied to the local database: an accepted row is marked synced,
/// a conflict or tombstone is logged in `conflict_log` and freezes its entity,
/// and a permission rejection is rolled back from `pre_mutation_payload`.
library;

import 'dart:convert';

import '../database/app_database.dart';
import 'entity_tables.dart';
import 'sync_conflict_log.dart';
import 'sync_queue_dao.dart';
import 'sync_table_bindings.dart';
import 'sync_transport.dart';

/// What one batch attempt produced.
class PushBatchOutcome {
  /// Creates an outcome.
  const PushBatchOutcome({
    this.attempted = 0,
    this.applied = 0,
    this.conflicts = 0,
    this.rolledBack = 0,
    this.blocked = 0,
    this.failure,
    this.maxRetryCount = 0,
    this.permissionRollback = false,
  });

  /// Mutations submitted.
  final int attempted;

  /// Mutations accepted or reconciled.
  final int applied;

  /// Conflicts/tombstones logged and frozen.
  final int conflicts;

  /// Permission rejections rolled back locally.
  final int rolledBack;

  /// Permanent rejections now needing review.
  final int blocked;

  /// A whole-batch transport failure, when there was one.
  final SyncFailure? failure;

  /// The highest retry count in the failed batch, for the backoff schedule.
  final int maxRetryCount;

  /// Set when a permission rejection means the user must be told.
  final bool permissionRollback;

  /// Whether anything at all was attempted.
  bool get isEmpty => attempted == 0 && failure == null;
}

/// One prepared mutation plus the local queue rows it reconciles.
class _Prepared {
  _Prepared(this.row, this.json, {this.pairedHistoryQueueId});

  final SyncQueueRow row;
  final Map<String, dynamic> json;
  final int? pairedHistoryQueueId;
}

/// Executes one push batch.
class PushWorker {
  /// Creates a worker over [db], its [queue] and [transport].
  PushWorker({
    required this.db,
    required this.queue,
    required this.transport,
    required this.currentUserId,
    this.firmId,
    this.batchSize = 50,
  });

  /// The encrypted local database.
  final AppDatabase db;

  /// The outbound queue.
  final SyncQueueDao queue;

  /// The network boundary; null when this build has no backend.
  final SyncTransport? transport;

  /// The authenticated account id, injected into conflict-log payloads.
  final String currentUserId;

  /// The account's firm id, or null for an individual.
  final String? firmId;

  /// Maximum mutations per `push_changes` call.
  final int batchSize;

  /// Runs one batch, or returns an empty outcome when there is nothing to do.
  Future<PushBatchOutcome> flushBatch() async {
    final send = transport;
    if (send == null) return const PushBatchOutcome();

    final prepared = await _prepare();
    if (prepared.isEmpty) return const PushBatchOutcome();

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final item in prepared) {
      await queue.markAttempt(item.row.id, now);
    }

    final List<Map<String, dynamic>> results;
    try {
      results = await send.pushChanges(
        prepared.map((item) => item.json).toList(growable: false),
      );
    } on SyncFailure catch (failure) {
      await _handleTransportFailure(prepared, failure);
      final maxRetry = prepared.fold<int>(
        0,
        (best, item) => item.row.retryCount + 1 > best
            ? item.row.retryCount + 1
            : best,
      );
      return PushBatchOutcome(
        attempted: prepared.length,
        failure: failure,
        maxRetryCount: maxRetry,
      );
    }

    return _handleResults(prepared, results);
  }

  /// Loads, filters and pairs the next batch in dependency order.
  Future<List<_Prepared>> _prepare() async {
    final rows = await queue.getPushable();
    if (rows.isEmpty) return const <_Prepared>[];

    // An entity frozen on a conflict is skipped whole, later entries included.
    final frozen = await queue.getConflictPendingKeys();

    final eligible = rows
        .where((row) => syncTableForEntity(row.entityType) != null)
        .where((row) => !frozen.contains('${row.entityType}\u0000${row.entityId}'))
        .toList()
      ..sort((a, b) {
        final byRank = syncDependencyRank(a.entityType)
            .compareTo(syncDependencyRank(b.entityType));
        return byRank != 0 ? byRank : a.createdAt.compareTo(b.createdAt);
      });

    // A case-histoty insert is the provisional preview of a coincident case
    // update; it is folded into that mutation rather than pushed separately.
    final provisionalByCase = <String, SyncQueueRow>{};
    for (final row in eligible) {
      if (row.entityType == 'case_history' && row.operation == 'insert') {
        final caseId = decodeJsonObject(row.payload)['case_id'];
        if (caseId is String && caseId.isNotEmpty) {
          provisionalByCase[caseId] = row;
        }
      }
    }

    final prepared = <_Prepared>[];
    final attachedHistoryIds = <int>{};
    for (final row in eligible) {
      if (prepared.length >= batchSize) break;

      // A provisional preview is never a mutation of its own — the only
      // `case_history` insert the client ever queues is a preview — so it is
      // dropped here and travels folded into the case update it belongs to.
      // Sent alone it would put a history event on the server for a next-date
      // change that was never applied there, and the repaired retry would mint a
      // second event for the same change. Skipping (not deleting) it keeps the
      // preview `pending` until its parent case mutation is eligible again.
      if (row.entityType == 'case_history' && row.operation == 'insert') {
        continue;
      }

      Map<String, dynamic>? provisional;
      int? pairedId;
      if (row.entityType == 'case' && row.operation == 'update') {
        final history = provisionalByCase[row.entityId];
        // One preview belongs to one mutation, so a second case update in the
        // same batch cannot attach it again.
        if (history != null && !attachedHistoryIds.contains(history.id)) {
          final base = decodeJsonObject(row.basePayload);
          final next = decodeJsonObject(row.payload);
          if (base['next_date'] != next['next_date']) {
            provisional = decodeJsonObject(history.payload);
            pairedId = history.id;
            attachedHistoryIds.add(history.id);
          }
        }
      }

      prepared.add(_Prepared(row, _mutationJson(row, provisional),
          pairedHistoryQueueId: pairedId));
    }

    return prepared;
  }

  /// Builds the wire object for one queue row (the provisional preview folded
  /// in when there is one).
  Map<String, dynamic> _mutationJson(
    SyncQueueRow row,
    Map<String, dynamic>? provisional,
  ) {
    final payload = decodeJsonObject(row.payload);
    if (row.entityType == 'conflict_log') {
      // The local mirror carries no ownership columns; the server table has
      // both and RLS/sync_can_write need them.
      payload['user_id'] = currentUserId;
      if (firmId != null) payload['firm_id'] = firmId;
    }

    return <String, dynamic>{
      'mutation_id': row.mutationId,
      'entity_type': row.entityType,
      'entity_id': row.entityId,
      'operation': row.operation,
      'base_version': row.baseVersion,
      'base_payload': decodeJsonObject(row.basePayload),
      'changed_fields': decodeJsonStringList(row.changedFields),
      'payload': payload,
      'pre_mutation_payload': decodeJsonObject(row.preMutationPayload),
      'provisional_history': ?provisional,
    };
  }

  /// Returns a failed batch to `pending`, or blocks it after ten failures.
  Future<void> _handleTransportFailure(
    List<_Prepared> prepared,
    SyncFailure failure,
  ) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final item in prepared) {
      final nextRetry = item.row.retryCount + 1;
      if (!failure.retryable) {
        await queue.block(item.row.id, error: failure.message);
      } else if (nextRetry >= 10) {
        await queue.block(item.row.id,
            error: failure.message, retryCount: nextRetry);
      } else {
        await queue.incrementRetry(
          item.row.id,
          retryCount: nextRetry,
          error: failure.message,
          attemptedAt: now,
        );
      }
    }
  }

  /// Applies every terminal result.
  Future<PushBatchOutcome> _handleResults(
    List<_Prepared> prepared,
    List<Map<String, dynamic>> results,
  ) async {
    final byMutation = <String, Map<String, dynamic>>{
      for (final result in results)
        if (result['mutation_id'] is String) result['mutation_id'] as String: result,
    };

    var applied = 0;
    var conflicts = 0;
    var rolledBack = 0;
    var blocked = 0;
    var permissionRollback = false;

    for (final item in prepared) {
      final result = byMutation[item.row.mutationId];
      if (result == null) {
        await queue.block(item.row.id, error: 'No result returned for this mutation.');
        blocked++;
        continue;
      }

      final status = result['status'];
      switch (status) {
        case 'accepted':
          await _applyAccepted(item, result);
          applied++;
        case 'conflict':
        case 'tombstone':
          await _applyConflict(item, result);
          conflicts++;
        case 'already_resolved':
          await _applyAlreadyResolved(item, result);
          applied++;
        case 'rejected':
          final outcome = await _applyRejected(item, result);
          if (outcome == _RejectedAction.rolledBack) rolledBack++;
          if (outcome == _RejectedAction.blocked) blocked++;
          if (outcome == _RejectedAction.permission) {
            rolledBack++;
            permissionRollback = true;
          }
        default:
          await queue.block(item.row.id,
              error: 'Unrecognized result status "$status".');
          blocked++;
      }
    }

    return PushBatchOutcome(
      attempted: prepared.length,
      applied: applied,
      conflicts: conflicts,
      rolledBack: rolledBack,
      blocked: blocked,
      permissionRollback: permissionRollback,
    );
  }

  Future<void> _applyAccepted(
    _Prepared item,
    Map<String, dynamic> result,
  ) async {
    final binding = syncBindingFor(item.row.entityType)!;
    final version = _int(result['version']);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await binding.markSynced(db, item.row.entityId, version, now);

    // The authoritative history row replaces the local provisional preview.
    final history = result['history'];
    if (history is Map && item.pairedHistoryQueueId != null) {
      await syncBindingFor('case_history')!
          .applyServerRow(db, history.cast<String, dynamic>());
      await queue.resolve(item.pairedHistoryQueueId!);
    }

    final children = result['children'];
    if (children is List) {
      for (final child in children.whereType<Map>()) {
        final row = child.cast<String, dynamic>();
        final childId = row['id'];
        await syncBindingFor('case_history')!.applyServerRow(db, row);
        if (childId is String) {
          final localRows = await queue.getByEntity('case_history', childId);
          for (final local in localRows) {
            await queue.resolve(local.id);
          }
        }
      }
    }

    await queue.resolve(item.row.id);
  }

  Future<void> _applyConflict(_Prepared item, Map<String, dynamic> result) async {
    final serverRow = result['row'];
    await _logConflict(item, result);
    await queue.freezeEntity(item.row.entityType, item.row.entityId,
        error: result['message'] as String? ?? 'Conflict with the server.');
    // A tombstone hides the record locally; a version conflict must not
    // overwrite the queued edit, so its row is attached to the conflict log
    // instead.
    if (result['status'] == 'tombstone' && serverRow is Map) {
      await syncBindingFor(item.row.entityType)!
          .applyServerRow(db, serverRow.cast<String, dynamic>());
    }
  }

  Future<void> _applyAlreadyResolved(
    _Prepared item,
    Map<String, dynamic> result,
  ) async {
    final serverRow = result['row'];
    if (serverRow is Map) {
      await syncBindingFor(item.row.entityType)!
          .applyServerRow(db, serverRow.cast<String, dynamic>());
    }
    await queue.resolve(item.row.id);
  }

  Future<_RejectedAction> _applyRejected(
    _Prepared item,
    Map<String, dynamic> result,
  ) async {
    final code = result['error_code'];
    final message = result['message'] as String? ?? 'The mutation was refused.';

    if (code == 'permission_denied') {
      // Roll the provisional local action back to its pre-mutation snapshot.
      final snapshot = decodeJsonObject(item.row.preMutationPayload);
      if (snapshot.isNotEmpty) {
        await syncBindingFor(item.row.entityType)!.applyServerRow(db, snapshot);
      }
      await queue.resolve(item.row.id);
      return _RejectedAction.permission;
    }

    await queue.block(item.row.id, error: message);
    return _RejectedAction.blocked;
  }

  /// Writes a local `conflict_log` row — and queues it for the server mirror —
  /// for a rejected mutation. The record itself is written by the shared
  /// [writeConflictLog], which the delta pull uses too.
  Future<void> _logConflict(_Prepared item, Map<String, dynamic> result) async {
    final serverRow = result['row'];
    await writeConflictLog(
      db: db,
      queue: queue,
      currentUserId: currentUserId,
      entityType: item.row.entityType,
      entityId: item.row.entityId,
      mutationId: item.row.mutationId,
      baseVersion: item.row.baseVersion ?? 0,
      basePayload: item.row.basePayload,
      submittedPayload: _encode(item.json['payload']),
      changedFields: item.row.changedFields,
      serverVersion: _int(result['version']) ?? 0,
      serverPayload: serverRow is Map ? _encode(serverRow) : '{}',
      conflictAt: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
  }

  static String _encode(Object? value) => jsonEncode(value);

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

enum _RejectedAction { permission, blocked, rolledBack }

// `JsonEncoder` lives in dart:convert.
