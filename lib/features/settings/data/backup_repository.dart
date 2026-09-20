/// Local backup export and restore engine (Task 15 Phases 1–3).
///
/// One code path serves every export the app performs: the manual
/// "Backup to Local Storage" action and, in Part B, the logout auto-export and
/// the extended-offline safety archive. Sync Plan §5 requires all three to write
/// exactly this format, so they all funnel through [BackupRepository]. Restore is
/// the mirror image and lives here too, so the two directions cannot disagree
/// about the table set or its order.
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
///
/// Every export is **encrypted** (Task 15 Phase 2, Plan §12.3.1): the envelope's
/// bytes are sealed into the authenticated container from
/// `core/backup/backup_cipher.dart` with a key derived from the caller's
/// recovery secret, so a plaintext snapshot never reaches shared storage. The
/// secret is passed in per call and never stored, logged or recorded.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;

import '../../../core/backup/backup_cipher.dart';
import '../../../core/backup/backup_format.dart';
import '../../../core/backup/backup_restore.dart';
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

  /// Runs one export: snapshot → serialize → encrypt → write through [sink] →
  /// record.
  ///
  /// This is the single export path every caller shares, and it always writes
  /// the authenticated-encrypted container (§12.3.1 forbids plaintext exports),
  /// so the recovery secret is required rather than optional. The archive's
  /// path, checksum and completion state are recorded only **after** the sink
  /// reports success, so a failed write can never leave a "complete" archive
  /// behind.
  ///
  /// [kdfIterations] is injectable so tests need not pay a full PBKDF2 stretch.
  Future<BackupExportResult> exportSnapshot({
    required BackupArchiveSink sink,
    required String appVersion,
    required String recoverySecret,
    int? exportedAt,
    String? fileName,
    int kdfIterations = kBackupKdfIterations,
  }) async {
    final stamp = exportedAt ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    final envelope = await buildEnvelope(
      appVersion: appVersion,
      exportedAt: stamp,
    );
    final container = await encryptBackup(
      plaintext: utf8.encode(envelope.encode()),
      recoverySecret: recoverySecret,
      appVersion: appVersion,
      createdAt: stamp,
      iterations: kdfIterations,
    );
    final bytes = Uint8List.fromList(utf8.encode(container.encode()));
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

  /// Whether any portable table holds a row.
  ///
  /// Tombstones and queued writes count as data: restoring into a database that
  /// holds nothing but a soft-delete or a pending `sync_queue` entry would still
  /// discard information, so the collision check must not ignore them.
  Future<bool> hasExistingData() async {
    for (final name in backupTableOrder) {
      final row = await db
          .customSelect('SELECT 1 FROM "$name" LIMIT 1')
          .getSingleOrNull();
      if (row != null) return true;
    }
    return false;
  }

  /// Imports an opened backup into the local database.
  ///
  /// Everything happens in **one transaction**: the collision check, the
  /// delete-all and every insert. A failure anywhere rolls the whole thing back,
  /// so a restore can never leave the database half-replaced. Rows keep their
  /// original ids and sync columns (they are inserted verbatim from the file), so
  /// a later premium upgrade can push the restored data unchanged.
  ///
  /// When the database already holds data and [replaceExisting] is false this
  /// throws [BackupRestoreFailure.conflictNeedsConfirmation] **before writing
  /// anything** — the caller asks the user, then cancels or calls again with
  /// `replaceExisting: true`. Restores never merge silently.
  Future<BackupRestoreResult> restoreSnapshot({
    required OpenedBackup backup,
    bool replaceExisting = false,
  }) async {
    // Validated before the transaction opens: a malformed snapshot is refused
    // outright rather than discovered halfway through the inserts.
    final tables = portableTablesFrom(backup.payload);
    final rowCount = tables.values.fold<int>(
      0,
      (sum, rows) => sum + rows.length,
    );
    var replaced = false;
    try {
      await db.transaction(() async {
        final existing = await hasExistingData();
        if (existing && !replaceExisting) {
          throw const BackupRestoreException(
            BackupRestoreFailure.conflictNeedsConfirmation,
            'The database already holds data; a restore would discard it.',
          );
        }
        if (existing) {
          replaced = true;
          // Child before parent, so the ON DELETE constraints never block the
          // wipe: the reverse of the FK-safe export order.
          for (final name in backupTableOrder.reversed) {
            await db.customStatement('DELETE FROM "$name"');
          }
        }
        // Parent before child, the same order the export wrote them in.
        for (final name in backupTableOrder) {
          for (final row in tables[name] ?? const <Map<String, dynamic>>[]) {
            await _insertRow(name, row);
          }
        }
      });
    } on BackupRestoreException {
      rethrow;
    } catch (error) {
      // Drift rolled the transaction back on the way here, so the database is
      // exactly as it was. The message stays schema-level: no row values.
      throw BackupRestoreException(
        BackupRestoreFailure.importFailed,
        'The restore was rolled back: $error',
      );
    }
    return BackupRestoreResult(
      kind: backup.kind,
      schemaVersion: backup.schemaVersion,
      tableCount: tables.length,
      rowCount: rowCount,
      replacedExisting: replaced,
    );
  }

  /// Inserts one raw row, naming exactly the columns the file carried.
  Future<void> _insertRow(String table, Map<String, dynamic> row) {
    final columns = row.keys.toList(growable: false);
    final names = columns.map((column) => '"$column"').join(', ');
    final placeholders = List<String>.filled(columns.length, '?').join(', ');
    return db.customInsert(
      'INSERT INTO "$table" ($names) VALUES ($placeholders)',
      variables: [for (final column in columns) _variableFor(row[column])],
    );
  }
}

/// The receipt of one restore.
class BackupRestoreResult {
  /// Whether the restored file was encrypted or a legacy plaintext envelope.
  final BackupFileKind kind;

  /// Payload schema version the file declared.
  final int schemaVersion;

  /// Number of tables the file carried.
  final int tableCount;

  /// Number of rows inserted.
  final int rowCount;

  /// Whether pre-existing data was deleted to make room.
  final bool replacedExisting;

  /// Creates a restore receipt.
  const BackupRestoreResult({
    required this.kind,
    required this.schemaVersion,
    required this.tableCount,
    required this.rowCount,
    required this.replacedExisting,
  });
}

/// Column names a backup may name, derived from the app's snake_case convention
/// (AGENTS.md rule 5).
///
/// Column names come from the file and are interpolated into the `INSERT`
/// statement, so they are matched against this pattern before any SQL is built —
/// a crafted backup cannot smuggle SQL through a column key. A test asserts every
/// column of every table in [AppDatabase] passes it, so the two cannot drift.
final RegExp _snakeCaseColumn = RegExp(r'^[a-z][a-z0-9_]*$');

/// Validates a backup payload's per-table snapshot before it is imported.
///
/// Throws [BackupRestoreException] with [BackupRestoreFailure.damagedFile] for a
/// payload with no table snapshot, an unknown table, a row that is not an
/// object, a column name outside the app's snake_case shape, or a value that is
/// not a SQLite scalar. Table and column names are checked against the schema,
/// never trusted from the file.
Map<String, List<Map<String, dynamic>>> portableTablesFrom(
  Map<String, dynamic> payload,
) {
  final raw = payload[kBackupTablesSection];
  if (raw is! Map<String, dynamic>) {
    throw const BackupRestoreException(
      BackupRestoreFailure.damagedFile,
      'The backup carries no table snapshot.',
    );
  }
  final known = backupTableOrder.toSet();
  final validated = <String, List<Map<String, dynamic>>>{};
  for (final entry in raw.entries) {
    final name = entry.key;
    if (!known.contains(name)) {
      throw BackupRestoreException(
        BackupRestoreFailure.damagedFile,
        'The backup names a table that is not part of this schema: $name',
      );
    }
    final rows = entry.value;
    if (rows is! List) {
      throw BackupRestoreException(
        BackupRestoreFailure.damagedFile,
        'The backup stores "$name" as something other than a list of rows.',
      );
    }
    validated[name] = [
      for (final row in rows) _validatedRow(name, row),
    ];
  }
  return validated;
}

/// Validates one raw row's column names and value types.
Map<String, dynamic> _validatedRow(String table, Object? row) {
  if (row is! Map) {
    throw BackupRestoreException(
      BackupRestoreFailure.damagedFile,
      'The backup stores a row of "$table" as something other than an object.',
    );
  }
  final validated = <String, dynamic>{};
  for (final entry in row.entries) {
    final column = entry.key;
    if (column is! String || !_snakeCaseColumn.hasMatch(column)) {
      throw BackupRestoreException(
        BackupRestoreFailure.damagedFile,
        'The backup names a column of "$table" that is not a schema column.',
      );
    }
    final value = entry.value;
    if (value != null && value is! num && value is! String && value is! bool) {
      throw BackupRestoreException(
        BackupRestoreFailure.damagedFile,
        'The backup stores a non-scalar value in "$table.$column".',
      );
    }
    validated[column] = value;
  }
  if (validated.isEmpty) {
    throw BackupRestoreException(
      BackupRestoreFailure.damagedFile,
      'The backup stores a row of "$table" with no columns.',
    );
  }
  return validated;
}

/// Binds one validated JSON scalar to a SQL parameter.
Variable _variableFor(Object? value) => switch (value) {
  null => const Variable(null),
  // Drift stores Dart bools as integers, and JSON has no bool column type.
  final bool flag => Variable(flag ? 1 : 0),
  final num number => Variable(number),
  final String text => Variable(text),
  // Unreachable: portableTablesFrom rejects anything else, but a switch that
  // silently dropped a value would insert NULLs instead, so it fails loudly.
  _ => throw BackupRestoreException(
    BackupRestoreFailure.damagedFile,
    'The backup stores a value this build cannot import.',
  ),
};

/// Default backup file name for an export taken at [exportedAt].
///
/// UTC `legal-case-diary-backup-YYYYMMDD-HHMMSS.lcbak` — sortable, unique per
/// second, and independent of the device locale. The extension is not `.json`
/// because the file is the encrypted container, not readable JSON; Phase 3's
/// picker filters on it.
String defaultBackupFileName(int exportedAt) {
  final at = DateTime.fromMillisecondsSinceEpoch(exportedAt, isUtc: true);
  String two(int value) => value.toString().padLeft(2, '0');
  final stamp =
      '${at.year}${two(at.month)}${two(at.day)}'
      '-${two(at.hour)}${two(at.minute)}${two(at.second)}';
  return 'legal-case-diary-backup-$stamp.lcbak';
}
