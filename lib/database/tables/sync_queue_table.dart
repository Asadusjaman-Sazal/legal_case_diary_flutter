/// Sync queue table: tracks outbound mutations awaiting push to the server.
/// Implemented in Task 03 Phase 2.
library;

import 'package:drift/drift.dart';

/// A queued local mutation waiting to be pushed to Supabase.
@DataClassName('SyncQueueRow')
class SyncQueue extends Table {
  /// Auto-increment primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Entity type (`case`, `case_history`, `note`, `reference`, `court`,
  /// `step`, `case_type`, `on_behalf`, `conflict_log`, `delete_request`).
  TextColumn get entityType => text()();

  /// UUID of the modified record.
  TextColumn get entityId => text()();

  /// `insert`, `update`, or `delete`.
  TextColumn get operation => text()();

  /// Stable client-generated idempotency key.
  TextColumn get mutationId => text().unique()();

  /// Last server version observed when this mutation began.
  IntColumn get baseVersion => integer().nullable()();

  /// JSON snapshot of the common base for three-way merge/rebase.
  TextColumn get basePayload => text()();

  /// JSON array of fields intentionally changed.
  TextColumn get changedFields => text()();

  /// JSON-serialized intended record state/patch.
  TextColumn get payload => text()();

  /// Snapshot used to roll back a server-rejected permission-sensitive action.
  TextColumn get preMutationPayload => text()();

  /// Timestamp when this queue entry was created (epoch ms).
  IntColumn get createdAt => integer()();

  /// Number of failed push attempts.
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  /// Timestamp before the most recent attempt (epoch ms); null if never attempted.
  IntColumn get lastAttemptAt => integer().nullable()();

  /// `pending`, `pushing`, `conflict_pending`, `blocked`, or `resolved`.
  TextColumn get state => text()();

  /// Last error message for diagnostics.
  TextColumn get lastError => text().nullable()();
}
