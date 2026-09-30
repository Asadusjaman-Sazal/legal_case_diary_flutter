/// The Offline Compaction Matrix, applied to a whole run of queued rows.
///
/// Task 05 already applies the matrix at **write** time, so most entities hold a
/// single `pending` row and this pass finds nothing to do. It exists for the rows
/// that do accumulate — a delete followed by an edit, two inserts for one entity,
/// or a run written before a conflict froze the entity — because sending two
/// mutations for one entity in one batch would make the second conflict against
/// the version the first one just produced.
///
/// The rules are Task 05's, unchanged: preserve the earliest row's identity
/// (`mutation_id`, `base_version`, `base_payload`, `pre_mutation_payload`), keep
/// the **latest** payload, and union the changed fields. Only `pending` rows are
/// ever eligible — a `conflict_pending` or `blocked` row is a record the user
/// still has to review, so nothing may be merged away around it.
library;

import 'dart:convert';

import '../database/app_database.dart';

/// What one entity's accumulated `pending` rows collapse to.
class CompactedRun {
  /// Creates a plan.
  const CompactedRun({
    required this.dropAll,
    this.survivorId,
    this.operation,
    this.payload,
    this.changedFields,
  });

  /// True when the run cancels out (an insert that was deleted again before it
  /// ever reached the server, so nothing needs to be sent at all).
  final bool dropAll;

  /// The queue row that survives; null when [dropAll].
  final int? survivorId;

  /// `insert`, `update` or `delete`, for the surviving row.
  final String? operation;

  /// The latest payload, as stored JSON text.
  final String? payload;

  /// The union of every row's changed fields, as stored JSON text.
  final String? changedFields;
}

/// Plans the matrix over one entity's `pending` rows, oldest first.
///
/// Returns null when the run must be left exactly as it is: fewer than two rows,
/// or a shape the matrix does not define (a delete followed by an edit is not the
/// same thing as an edit followed by a delete, so it is pushed in order instead
/// of guessed at).
CompactedRun? planQueueCompaction(List<SyncQueueRow> rows) {
  if (rows.length < 2) return null;

  final first = rows.first;
  final last = rows.last;

  if (first.operation == 'insert') {
    if (rows.any((row) => row.operation == 'delete')) {
      // Insert + delete: the server never needed to hear about either.
      return const CompactedRun(dropAll: true);
    }
    return CompactedRun(
      dropAll: false,
      survivorId: first.id,
      operation: 'insert',
      payload: last.payload,
      changedFields: _unionChangedFields(rows),
    );
  }

  if (first.operation == 'update') {
    final deleted = rows.any((row) => row.operation == 'delete');
    return CompactedRun(
      dropAll: false,
      survivorId: first.id,
      operation: deleted ? 'delete' : 'update',
      payload: last.payload,
      changedFields: _unionChangedFields(rows),
    );
  }

  return null;
}

/// Every field named by any row, in first-seen order, as JSON text.
String _unionChangedFields(List<SyncQueueRow> rows) {
  final union = <String>{};
  for (final row in rows) {
    try {
      final decoded = const JsonCodec().decode(row.changedFields);
      if (decoded is List) {
        union.addAll(decoded.whereType<String>());
      }
    } on Object {
      // A row whose changed-field list cannot be read contributes nothing.
    }
  }
  return jsonEncode(union.toList());
}
