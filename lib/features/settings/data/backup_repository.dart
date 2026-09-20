/// Local backup export engine (Task 15 Phase 1).
///
/// One code path serves every export the app performs: the manual
/// "Backup to Local Storage" action and, in Part B, the logout auto-export and
/// the extended-offline safety archive. Sync Plan §5 requires all three to write
/// exactly this format, so they all funnel through [BackupRepository].
///
/// The snapshot is taken as **raw rows** (`SELECT *`) rather than through the
/// generated data classes. That is deliberate: it preserves every column
/// verbatim — original ids, the global sync columns (`version`, `updated_at`,
/// `is_deleted`, `synced_at`, `last_modified_by`), soft-delete tombstones and
/// the `sync_queue` payloads — with no per-table serializer to drift out of
/// date. Rows are read and written in FK-safe parent → child order.
///
/// Table classes (per AGENTS.md rule 4) covered by the snapshot:
/// - push/pull domain: `cases`, `case_history`, `notes`, `case_references`,
///   `court_categories`, `case_categories`, `courts`, `steps`, `case_types`,
///   `on_behalfs`, `delete_requests`, `conflict_log`
/// - pull-only cache: `profiles`, `firms`, `firm_members`
/// - per-user preference: `user_preferences`, `case_notification_preferences`
/// - local operational: `sync_queue`, `sync_metadata`, `seed_migrations`
///
/// Nonportable secure credentials (the database encryption key and the local
/// identity/token material held in secure storage) are never part of the
/// database, so they are excluded by construction and recreated locally.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../../core/backup/backup_format.dart';
import '../../../database/app_database.dart';
import '../../../sync/sync_metadata_dao.dart';

/// Portable local tables in FK-safe parent → child order.
///
/// Import replays this order forwards and delete-all walks it backwards, so a
/// restore never inserts a child before its parent. `backup_repository_test.dart`
/// asserts this list covers every table in [AppDatabase], so adding a table
/// without adding it here fails the build's tests rather than silently
/// dropping data from every future backup.
const List<String> backupTableOrder = <String>[
  // Reference data first: nothing references outside itself except the
  // category tables, which every other reference row points at.
  'court_categories',
  'case_categories',
  'courts',
  'on_behalfs',
  'steps',
  'case_types',
  // Domain rows and their tombstones.
  'cases',
  'case_history',
  'notes',
  'case_references',
  'delete_requests',
  'conflict_log',
  // Pull-only caches and per-user preferences.
  'firms',
  'firm_members',
  'profiles',
  'user_preferences',
  'case_notification_preferences',
  // Local operational state (queue, cursors, recovery/archive metadata).
  'sync_queue',
  'sync_metadata',
  'seed_migrations',
];

/// `sync_metadata` key holding the last archive's path.
const String archivePathKey = 'archive.path';

/// `sync_metadata` key holding the last archive's checksum.
const String archiveChecksumKey = 'archive.checksum';

/// `sync_metadata` key holding the last archive's completion state.
const String archiveStateKey = 'archive.state';

/// [archiveStateKey] value written after a successful export.
const String archiveStateComplete = 'complete';

/// Persists a finished backup file and reports where it landed.
///
/// The platform file services implement this (Phase 4's `file_picker` sink),
/// and tests supply a recording fake. Keeping the write behind this seam is what
/// lets the manual backup, the Part B logout export and the safety archive share
/// one export path while writing to different destinations.
abstract interface class BackupArchiveSink {
  /// Writes [bytes] as [fileName] and returns the path they were written to.
  Future<String> write({required String fileName, required Uint8List bytes});
}

/// The receipt of one export.
class BackupExportResult {
  /// Path the backup file was written to.
  final String path;

  /// SHA-256 of the written file's bytes.
  final String checksum;

  /// The envelope that was written (its `checksum` covers the payload).
  final BackupEnvelope envelope;

  /// Creates an export receipt.
  const BackupExportResult({
    required this.path,
    required this.checksum,
    required this.envelope,
  });
}

/// The last recorded archive state, read back from `sync_metadata`.
class BackupArchiveState {
  /// Path of the last archive, if one was recorded.
  final String? path;

  /// Checksum of the last archive, if one was recorded.
  final String? checksum;

  /// Completion state of the last archive, if one was recorded.
  final String? state;

  /// Creates an archive-state snapshot.
  const BackupArchiveState({this.path, this.checksum, this.state});

  /// Whether a completed archive has been recorded.
  bool get hasCompletedArchive => state == archiveStateComplete && path != null;
}

/// Reads and writes the whole portable local state as a versioned snapshot.
class BackupRepository {
  /// Creates a repository backed by [db].
  ///
  /// [metadata] is injectable so tests can observe the archive writes.
  BackupRepository(this.db, {SyncMetadataDao? metadata})
    : _metadata = metadata ?? SyncMetadataDao(db);

  /// The local database being snapshotted.
  final AppDatabase db;

  final SyncMetadataDao _metadata;

  /// The portable tables, in FK-safe export/import order.
  List<String> get tableNames => List<String>.unmodifiable(backupTableOrder);

  /// Reads every portable table as raw rows keyed by column name.
  Future<Map<String, dynamic>> collectTables() async {
    final tables = <String, dynamic>{};
    for (final name in backupTableOrder) {
      final rows = await db.customSelect('SELECT * FROM "$name"').get();
      tables[name] = <Map<String, dynamic>>[for (final row in rows) row.data];
    }
    return tables;
  }

  /// Builds the versioned envelope for the current local state.
  Future<BackupEnvelope> buildEnvelope({
    required String appVersion,
    required int exportedAt,
  }) async {
    final payload = <String, dynamic>{
      kBackupTablesSection: await collectTables(),
    };
    return BackupEnvelope.create(
      appVersion: appVersion,
      exportedAt: exportedAt,
      payload: payload,
    );
  }

  /// Runs one export: snapshot → serialize → write through [sink] → record.
  ///
  /// This is the single export path every caller shares. The archive's path,
  /// checksum and completion state are recorded only **after** the sink reports
  /// success, so a failed write can never leave a "complete" archive behind.
  Future<BackupExportResult> exportSnapshot({
    required BackupArchiveSink sink,
    required String appVersion,
    int? exportedAt,
    String? fileName,
  }) async {
    final stamp = exportedAt ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    final envelope = await buildEnvelope(
      appVersion: appVersion,
      exportedAt: stamp,
    );
    final bytes = Uint8List.fromList(utf8.encode(envelope.encode()));
    final path = await sink.write(
      fileName: fileName ?? defaultBackupFileName(stamp),
      bytes: bytes,
    );
    final checksum = checksumOfBytes(bytes);
    await recordArchive(
      path: path,
      checksum: checksum,
      state: archiveStateComplete,
    );
    return BackupExportResult(
      path: path,
      checksum: checksum,
      envelope: envelope,
    );
  }

  /// Records the last archive's path, checksum and completion state.
  Future<void> recordArchive({
    required String path,
    required String checksum,
    required String state,
  }) => db.transaction(() async {
    await _metadata.setValue(archivePathKey, path);
    await _metadata.setValue(archiveChecksumKey, checksum);
    await _metadata.setValue(archiveStateKey, state);
  });

  /// Reads the last recorded archive state.
  Future<BackupArchiveState> readArchiveState() async => BackupArchiveState(
    path: await _metadata.getValue(archivePathKey),
    checksum: await _metadata.getValue(archiveChecksumKey),
    state: await _metadata.getValue(archiveStateKey),
  );
}

/// Default backup file name for an export taken at [exportedAt].
///
/// UTC `legal-case-diary-backup-YYYYMMDD-HHMMSS.json` — sortable, unique per
/// second, and independent of the device locale.
String defaultBackupFileName(int exportedAt) {
  final at = DateTime.fromMillisecondsSinceEpoch(exportedAt, isUtc: true);
  String two(int value) => value.toString().padLeft(2, '0');
  final stamp =
      '${at.year}${two(at.month)}${two(at.day)}'
      '-${two(at.hour)}${two(at.minute)}${two(at.second)}';
  return 'legal-case-diary-backup-$stamp.json';
}
