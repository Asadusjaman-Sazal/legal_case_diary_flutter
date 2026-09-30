/// Sync metadata DAO: local key/value access for sync, recovery and archive
/// state.
///
/// The `sync_metadata` table is a local operational table — per-table pull
/// cursors, last successful sync time, clock offset, recovery flags and the
/// backup archive's path/checksum/state. Task 15 Phase 1 needs the archive keys
/// (the table's own documentation names `archive.path`, `archive.checksum` and
/// `archive.state`); Part B's sync engine reuses the same accessors for cursors.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// The `sync_metadata` key holding [table]'s composite pull cursor.
String syncCursorKey(String table) => 'cursor.$table';

/// The `sync_metadata` key holding this device's last successful sync time.
const String lastSuccessfulSyncAtKey = 'last_successful_sync_at';

/// The `sync_metadata` key holding the detected device-vs-server clock offset.
const String clockOffsetMsKey = 'clock_offset_ms';

/// The `(server_updated_at, id)` position a table's delta pull has reached.
///
/// [time] is the raw `server_updated_at` string exactly as the server returned
/// it — never re-formatted through `DateTime` — so the `gt`/`eq` comparison on
/// the next request cannot drift by a microsecond and skip or replay a row.
class SyncCursor {
  /// Creates a cursor at [time] for row [id].
  const SyncCursor({required this.time, required this.id});

  /// The server's `server_updated_at` value for the last row pulled.
  final String time;

  /// That row's id: the tie-breaker that keeps same-timestamp rows from being
  /// skipped at a page boundary.
  final String id;

  /// The durable JSON form stored in `sync_metadata`.
  Map<String, dynamic> toJson() => <String, dynamic>{'time': time, 'id': id};

  /// Reads a cursor from [raw]; null when it is unset, malformed or empty.
  ///
  /// A malformed cursor is treated as "no cursor", never as an error: the pull
  /// then re-reads the table from the minimum sentinel, which replays rows
  /// rather than skipping them.
  static SyncCursor? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = const JsonCodec().decode(raw);
      if (decoded is Map) {
        final time = decoded['time'];
        final id = decoded['id'];
        if (time is String && id is String && time.isNotEmpty && id.isNotEmpty) {
          return SyncCursor(time: time, id: id);
        }
      }
    } on Object {
      // Fall through to null.
    }
    return null;
  }
}

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

  /// The composite cursor [table]'s delta pull last committed, or null when it
  /// has never pulled (a full pull starts at the minimum sentinel).
  Future<SyncCursor?> getCursor(String table) async =>
      SyncCursor.decode(await getValue(syncCursorKey(table)));

  /// Stores [table]'s cursor. Called inside the same transaction as the page it
  /// describes, so a crash can replay rows but never skip them.
  Future<void> setCursor(String table, SyncCursor cursor) =>
      setValue(syncCursorKey(table), jsonEncode(cursor.toJson()));

  /// Forgets [table]'s cursor, so the next pull is a full pull.
  Future<void> clearCursor(String table) => deleteValue(syncCursorKey(table));

  /// An integer setting ([lastSuccessfulSyncAtKey] or [clockOffsetMsKey]).
  Future<int?> getIntValue(String key) async =>
      int.tryParse(await getValue(key) ?? '');

  /// Writes an integer setting.
  Future<void> setIntValue(String key, int value) => setValue(key, '$value');
}
