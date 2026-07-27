/// Sync metadata table: local operational key/value store for sync state.
/// Holds per-table pull cursors, last successful sync time, clock offset,
/// recovery flags, archive state, and atomic recovery checkpoints.
/// Local operational table — no sync columns needed.
/// Implemented in Task 03 Phase 3.
library;

import 'package:drift/drift.dart';

/// A single key/value entry for sync, recovery, and cursor state.
@DataClassName('SyncMetadataRow')
class SyncMetadata extends Table {
  /// Stable key for this metadata entry (e.g. `cursor.cases`,
  /// `last_successful_sync_at`, `clock_offset_ms`, `recovery_required`,
  /// `archive.path`, `archive.checksum`, `archive.state`,
  /// `atomic_recovery_checkpoint`).
  TextColumn get key => text()();

  /// Value as a plain string or JSON-encoded payload.
  TextColumn get value => text()();

  /// Timestamp when this entry was last written (epoch ms).
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {key};
}
