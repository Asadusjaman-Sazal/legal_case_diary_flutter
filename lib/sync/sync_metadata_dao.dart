/// Sync metadata DAO: local key/value access for sync, recovery and archive
/// state.
///
/// The `sync_metadata` table is a local operational table — per-table pull
/// cursors, last successful sync time, clock offset, recovery flags and the
/// backup archive's path/checksum/state. Task 15 Phase 1 needs the archive keys
/// (the table's own documentation names `archive.path`, `archive.checksum` and
/// `archive.state`); Part B's sync engine reuses the same accessors for cursors.
library;

import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Data Access Object for [SyncMetadata] table operations.
class SyncMetadataDao {
  /// Creates a DAO backed by [db].
  SyncMetadataDao(this.db);

  /// The Drift database instance.
  final AppDatabase db;

  /// Returns the raw value stored under [key], or null when unset.
  Future<String?> getValue(String key) async {
    final row = await (db.select(
      db.syncMetadata,
    )..where((row) => row.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  /// Reactive stream of the value stored under [key]; null when unset.
  Stream<String?> watchValue(String key) =>
      (db.select(db.syncMetadata)..where((row) => row.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.value);

  /// Inserts or overwrites the value stored under [key].
  Future<void> setValue(String key, String value, {int? updatedAt}) {
    final stamp = updatedAt ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    final companion = SyncMetadataCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(stamp),
    );
    return db
        .into(db.syncMetadata)
        .insert(companion, onConflict: DoUpdate((_) => companion));
  }

  /// Removes the entry stored under [key]. Returns the number of rows removed.
  Future<int> deleteValue(String key) =>
      (db.delete(db.syncMetadata)..where((row) => row.key.equals(key))).go();
}
