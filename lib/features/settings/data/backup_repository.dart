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
/// Every export is sealed **when the user has turned encryption on** (Task 15
/// Phase 2, Plan §12.3.1): the envelope's bytes are sealed into the
/// authenticated container from `core/backup/backup_cipher.dart` with a key
/// derived from the caller's recovery secret. Encryption is **off by default**,
/// so with no secret the envelope is written as readable JSON; the caller
/// decides per call from the stored `encryptBackups` preference. A non-null
/// secret is used for one export only and is never stored, logged or recorded.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart'
    show DriftSqlType, QueryRow, Table, TableInfo, Variable;
import 'package:uuid/uuid.dart';

import '../../../core/backup/backup_cipher.dart';
import '../../../core/backup/backup_format.dart';
import '../../../core/backup/backup_restore.dart';
import '../../../core/backup/excel_backup.dart';
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

/// The `sync_metadata` keys that describe the last archive.
///
/// They are a *receipt for a file outside the database*, so the two full wipes
/// named in the plan treat them specially: extended-offline recovery keeps them
/// (Proceed verifies the safety copy against them, and a failed recovery must be
/// retryable), while a logout keeps nothing at all.
const Set<String> archiveMetadataKeys = <String>{
  archivePathKey,
  archiveChecksumKey,
  archiveStateKey,
};

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

  /// Runs one export: snapshot → serialize → (seal) → write through [sink] →
  /// record.
  ///
  /// This is the single export path every caller shares. A non-null
  /// [recoverySecret] seals the file in the authenticated-encrypted container;
  /// with none, the versioned JSON envelope is written as-is, which is what
  /// "encryption off" means — and it is the default until the user turns
  /// encryption on in Backup & Restore. The archive's path, checksum and
  /// completion state are recorded only **after** the sink reports success, so a
  /// failed write can never leave a "complete" archive behind.
  ///
  /// [kdfIterations] is injectable so tests need not pay a full PBKDF2 stretch.
  Future<BackupExportResult> exportSnapshot({
    required BackupArchiveSink sink,
    required String appVersion,
    String? recoverySecret,
    int? exportedAt,
    String? fileName,
    int kdfIterations = kBackupKdfIterations,
  }) async {
    final stamp = exportedAt ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    final envelope = await buildEnvelope(
      appVersion: appVersion,
      exportedAt: stamp,
    );
    final plaintext = utf8.encode(envelope.encode());
    // No secret ⇒ readable JSON. A secret ⇒ the sealed container. Both are
    // written through the same sink, so the restore path opens either.
    final bytes = Uint8List.fromList(
      recoverySecret == null || recoverySecret.isEmpty
          ? plaintext
          : utf8.encode(
              (await encryptBackup(
                plaintext: plaintext,
                recoverySecret: recoverySecret,
                appVersion: appVersion,
                createdAt: stamp,
                iterations: kdfIterations,
              )).encode(),
            ),
    );
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

  /// Erases every app-state table, in one durable transaction.
  ///
  /// **This is the complete wipe scope the plan fixes** for extended-offline
  /// recovery (Task 19 Phase 5) and for logout/account switching (Task 19
  /// Phase 6, Addendum): every domain row and its tombstones, the `sync_queue`,
  /// the pull-only caches (`firms`, `firm_members`, `profiles`), the per-user
  /// preferences and case-notification configuration, the cursors, the seeded
  /// reference data and its ledger, and the rest of the sync/recovery metadata.
  /// Children go first, because the FK-safe export order is walked backwards.
  ///
  /// [keepMetadataKeys] are `sync_metadata` keys that survive the wipe; the two
  /// callers pass [archiveMetadataKeys] or nothing at all. No session material
  /// lives in the database, so nothing has to be carried across for the
  /// authenticated pull that follows a recovery or a fresh login.
  Future<void> wipeAllTables({
    Set<String> keepMetadataKeys = const <String>{},
  }) => db.transaction(() async {
    for (final name in backupTableOrder.reversed) {
      if (name == 'sync_metadata' && keepMetadataKeys.isNotEmpty) {
        final placeholders = List.filled(
          keepMetadataKeys.length,
          '?',
        ).join(', ');
        await db.customStatement(
          'DELETE FROM sync_metadata WHERE key NOT IN ($placeholders)',
          keepMetadataKeys.toList(growable: false),
        );
        continue;
      }
      await db.customStatement('DELETE FROM "$name"');
    }
  });

  /// Reads the last recorded archive state.
  Future<BackupArchiveState> readArchiveState() async => BackupArchiveState(
    path: await _metadata.getValue(archivePathKey),
    checksum: await _metadata.getValue(archiveChecksumKey),
    state: await _metadata.getValue(archiveStateKey),
  );

  /// Whether any of [tables] holds a row.
  ///
  /// Tombstones and queued writes count as data: restoring into a database that
  /// holds nothing but a soft-delete or a pending `sync_queue` entry would still
  /// discard information, so the collision check must not ignore them.
  Future<bool> hasDataInTables(Iterable<String> tables) async {
    for (final name in tables) {
      final row = await db
          .customSelect('SELECT 1 FROM "$name" LIMIT 1')
          .getSingleOrNull();
      if (row != null) return true;
    }
    return false;
  }

  /// Whether any portable table holds a row.
  Future<bool> hasExistingData() => hasDataInTables(backupTableOrder);

  // -------------------------------------------------------------------------
  // Excel workbook backup (plan deviation: see the Task 15 note)
  //
  // A plaintext spreadsheet covering the four tables a lawyer edits directly.
  // The columns are read from the live schema, the rows come from the same
  // `collectTables` snapshot the encrypted export uses, and the import is handed
  // back to `restoreSnapshot` through the same payload shape — so there is one
  // row reader, one set of import rules and one upgrade path for both formats.
  // -------------------------------------------------------------------------

  /// Column specs for every Excel sheet, derived from the live schema.
  Map<String, List<ExcelColumnSpec>> excelColumnSpecs() =>
      <String, List<ExcelColumnSpec>>{
        for (final table in excelSheetTables.values)
          table: excelColumnSpecsFor(table),
      };

  /// Column specs for one table, in the table's own column order.
  ///
  /// Derived rather than hand-listed: adding a column to a table adds it to the
  /// next export, the sample template and the reader at once, because all three
  /// read this list.
  List<ExcelColumnSpec> excelColumnSpecsFor(String table) => <ExcelColumnSpec>[
    for (final column in _tableInfo(table).$columns)
      ExcelColumnSpec(
        name: column.name,
        required: column.requiredDuringInsert,
        kind: _cellKind(column.type),
      ),
  ];

  /// The schema's table with [name]. Every portable table is present.
  TableInfo<Table, Object?> _tableInfo(String name) =>
      db.allTables.firstWhere((table) => table.actualTableName == name);

  /// Builds the Excel workbook for the current local state.
  Future<Uint8List> buildExcelWorkbook({
    required String appVersion,
    required int exportedAt,
  }) async {
    final collected = await collectTables();
    return excelBytes(
      encodeExcelBackup(
        appVersion: appVersion,
        exportedAt: exportedAt,
        schemaVersion: kBackupSchemaVersion,
        columns: excelColumnSpecs(),
        tables: <String, List<Map<String, dynamic>>>{
          for (final table in excelSheetTables.values)
            table: collected[table] is List
                ? (collected[table] as List).cast<Map<String, dynamic>>()
                : const <Map<String, dynamic>>[],
        },
      ),
    );
  }

  /// Builds the sample template: the same headers, one example row per sheet, the
  /// reference sheets, and the Guide.
  ///
  /// Asynchronous because the sample is filled from **this device's** data: to
  /// inject a case by hand the user has to quote the very court, role and category
  /// ids their cases already point at, and only the live database has those. Each
  /// reference sheet leads with one clearly-labelled sample row so the shape is
  /// visible even before the diary holds any.
  ///
  /// [districtLabel] resolves a court's stored district id to the name the sheet
  /// shows; the Courts sheet groups its lower rows by it, so it is sorted in the
  /// same language the sheet was generated in.
  Future<Uint8List> buildExcelTemplateWorkbook({
    required String appVersion,
    String Function(String nameKey)? categoryLabel,
    String Function(String districtId)? districtLabel,
  }) async {
    final reference = await _referenceData(categoryLabel, districtLabel);
    return excelBytes(
      buildExcelTemplate(
        appVersion: appVersion,
        schemaVersion: kBackupSchemaVersion,
        columns: excelColumnSpecs(),
        exampleValues: <String, Map<String, Object?>>{
          'cases': reference.exampleCaseValues,
        },
        extraSheets: <ExcelTemplateSheet>[
          reference.sheets[excelCourtsSheet]!,
          reference.sheets[excelCaseCategoriesSheet]!,
          reference.sheets[excelCaseTypesSheet]!,
          reference.sheets[excelStepsSheet]!,
          reference.sheets[excelOnBehalfsSheet]!,
          _guideSheet,
        ],
      ),
    );
  }

  /// The sample's reference sheets, read from the live diary.
  ///
  /// Each sheet is the parent category's display label, then the row itself, then
  /// the columns the Cases sheet quotes: ids for `court_id`, `on_behalf_id` and
  /// `case_category_id`, and names for `case_type` and `last_step`, which the
  /// schema stores as plain text. Soft-deleted rows are left out, since a case may
  /// not point at one.
  Future<_ExcelReferenceData> _referenceData(
    String Function(String nameKey)? categoryLabel,
    String Function(String districtId)? districtLabel,
  ) async {
    /// Turns a court category's stored name key into the label the app shows.
    String label(String? nameKey) =>
        nameKey == null ? '' : (categoryLabel?.call(nameKey) ?? nameKey);

    /// Turns a court's stored district id into the name the app shows.
    String district(String? id) =>
        id == null ? '' : (districtLabel?.call(id) ?? id);

    Future<List<List<Object?>>> rowsOf(
      String sql,
      List<Object?> Function(QueryRow row) cells,
    ) async {
      final rows = await db.customSelect(sql).get();
      return <List<Object?>>[for (final row in rows) cells(row)];
    }

    // Lower courts are grouped by district so the Courts sheet can be filtered by
    // one; AD/HCD rows carry no district and stay at the top in their own order.
    // Sorting here rather than in SQL keeps the district names alphabetical in
    // whichever language the sheet was generated in.
    final courtRows = await db.customSelect(_courtsSql).get();
    int byCategoryOrder(QueryRow a, QueryRow b) {
      final category = (a.read<int?>('category_order') ?? 0).compareTo(
        b.read<int?>('category_order') ?? 0,
      );
      if (category != 0) return category;
      final order = a.read<int>('row_order').compareTo(b.read<int>('row_order'));
      if (order != 0) return order;
      return a.read<String>('row_name').compareTo(b.read<String>('row_name'));
    }

    courtRows.sort((a, b) {
      final aDistrict = a.read<String?>('district_id');
      final bDistrict = b.read<String?>('district_id');
      if (aDistrict == null || bDistrict == null) {
        if (aDistrict == bDistrict) return byCategoryOrder(a, b);
        return aDistrict == null ? -1 : 1;
      }
      final byDistrict = district(
        aDistrict,
      ).toLowerCase().compareTo(district(bDistrict).toLowerCase());
      return byDistrict != 0 ? byDistrict : byCategoryOrder(a, b);
    });
    final courts = <List<Object?>>[
      for (final row in courtRows)
        <Object?>[
          row.read<String>('row_id'),
          row.read<String>('row_name'),
          label(row.read<String?>('category_key')),
          district(row.read<String?>('district_id')),
        ],
    ];
    final caseCategories = await rowsOf(_caseCategoriesSql, (row) => <Object?>[
      row.read<String>('row_id'),
      row.read<String>('row_name'),
      label(row.read<String?>('category_key')),
    ]);
    final caseTypes = await rowsOf(_caseTypesSql, (row) => <Object?>[
      row.read<String>('row_name'),
      label(row.read<String?>('category_key')),
      row.read<String?>('case_category_name') ?? '',
    ]);
    final steps = await rowsOf(_stepsSql, (row) => <Object?>[
      row.read<String>('row_name'),
      label(row.read<String?>('category_key')),
    ]);
    final onBehalfs = await rowsOf(_onBehalfsSql, (row) => <Object?>[
      row.read<String>('row_id'),
      row.read<String>('row_name'),
      label(row.read<String?>('category_key')),
    ]);

    /// The sample row every reference sheet leads with, so the shape is visible
    /// before the diary holds anything. It has to be deleted before restoring
    /// only because it is not real data — the app never reads these sheets.
    const sample = 'Example — $excelSampleRowLabel';

    return _ExcelReferenceData(
      sheets: <String, ExcelTemplateSheet>{
        excelCourtsSheet: ExcelTemplateSheet(excelCourtsSheet, const <String>[
          'Court ID',
          'Court Name',
          'Court Category',
          'District',
        ], <List<Object?>>[
          <Object?>['example-court-id', sample, sample, sample],
          ...courts,
        ]),
        excelCaseCategoriesSheet: ExcelTemplateSheet(
          excelCaseCategoriesSheet,
          const <String>['Case Category ID', 'Case Category', 'Court Category'],
          <List<Object?>>[
            <Object?>['example-case-category-id', sample, sample],
            ...caseCategories,
          ],
        ),
        excelCaseTypesSheet: ExcelTemplateSheet(
          excelCaseTypesSheet,
          const <String>['Case Type', 'Court Category', 'Case Category'],
          <List<Object?>>[
            <Object?>[sample, sample, sample],
            ...caseTypes,
          ],
        ),
        excelStepsSheet: ExcelTemplateSheet(
          excelStepsSheet,
          const <String>['Step', 'Court Category'],
          <List<Object?>>[
            <Object?>[sample, sample],
            ...steps,
          ],
        ),
        excelOnBehalfsSheet: ExcelTemplateSheet(
          excelOnBehalfsSheet,
          const <String>['On Behalf ID', 'On Behalf', 'Court Category'],
          <List<Object?>>[
            <Object?>['example-on-behalf-id', sample, sample],
            ...onBehalfs,
          ],
        ),
      },
      // The first real row of each sheet fills the example case, so its foreign
      // keys point at data this diary actually holds. A sheet the diary has no
      // rows for supplies nothing, and the column keeps its placeholder.
      exampleCaseValues: <String, Object?>{
        if (courts.isNotEmpty) 'court_id': courts.first[0],
        if (onBehalfs.isNotEmpty) 'on_behalf_id': onBehalfs.first[0],
        if (caseCategories.isNotEmpty)
          'case_category_id': caseCategories.first[0],
        if (caseTypes.isNotEmpty) 'case_type': caseTypes.first[0],
        if (steps.isNotEmpty) 'last_step': steps.first[0],
      },
    );
  }

  /// Runs one Excel export: build the workbook → write through [sink] → record.
  ///
  /// It is **plaintext on purpose**: a spreadsheet the user opens in Excel cannot
  /// be sealed in the app's authenticated container, which is the deliberate
  /// deviation from §12.3.1 that the screen warns about and the Task 15 note
  /// records. As with the encrypted export, the archive is recorded only after
  /// the sink reports success, so a dismissed save dialog records nothing.
  Future<ExcelExportResult> exportExcelWorkbook({
    required BackupArchiveSink sink,
    required String appVersion,
    int? exportedAt,
  }) async {
    final stamp = exportedAt ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    final bytes = await buildExcelWorkbook(
      appVersion: appVersion,
      exportedAt: stamp,
    );
    final path = await sink.write(
      fileName: defaultExcelFileName(stamp),
      bytes: bytes,
    );
    await recordArchive(
      path: path,
      checksum: checksumOfBytes(bytes),
      state: archiveStateComplete,
    );
    return ExcelExportResult(path: path, exportedAt: stamp);
  }

  /// Decodes a workbook into an [OpenedBackup] the restore path accepts.
  ///
  /// The rows are wrapped in the same payload shape, and pushed through the same
  /// per-version adapters, as an encrypted backup — so a newer spreadsheet format
  /// is upgraded by one shared chain rather than a second one that could
  /// disagree with it.
  OpenedBackup openExcelBackup(List<int> bytes, {String Function()? newId}) {
    final data = decodeExcelBackup(
      bytes,
      columns: excelColumnSpecs(),
      supportedSchemaVersion: kBackupSchemaVersion,
      newId: newId ?? const Uuid().v4,
    );
    final payload = <String, dynamic>{
      kBackupTablesSection: <String, dynamic>{
        for (final entry in data.tables.entries) entry.key: entry.value,
      },
    };
    return OpenedBackup(
      kind: BackupFileKind.excel,
      schemaVersion: data.schemaVersion,
      appVersion: data.appVersion,
      exportedAt: data.exportedAt,
      payload: migrateBackupPayload(payload, fromVersion: data.schemaVersion),
    );
  }

/// Imports an opened backup into the local database.
///
/// Everything happens in **one transaction**: the collision check, the
/// delete-all and every insert. A failure anywhere rolls the whole thing back,
/// so a restore can never leave the database half-replaced. Rows keep their
/// original ids and sync columns (they are inserted verbatim from the file), so
/// a later premium upgrade can push the restored data unchanged.
///
/// The file's **own tables are the scope** of both the replace and the collision
/// check — a full backup carries every portable table and replaces the lot, while
/// a scoped file replaces only what it carries. That is what makes a partial
/// format like an Excel workbook safe to restore into a working diary.
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
    // The file's own tables are the whole scope: the collision check, the wipe
    // and the inserts all walk this list, in the FK-safe order. A JSON backup
    // carries every portable table, so its behaviour is exactly as it was; a
    // scoped file — an Excel workbook covering four tables — replaces those four
    // and leaves every other table (courts, steps, preferences, the queue)
    // untouched, which is what keeps a partial file from emptying the diary's
    // reference data.
    final scope = <String>[
      for (final name in backupTableOrder)
        if (tables.containsKey(name)) name,
    ];
    var replaced = false;
    try {
      await db.transaction(() async {
        final existing = await hasDataInTables(scope);
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
          for (final name in scope.reversed) {
            await db.customStatement('DELETE FROM "$name"');
          }
        }
        // Parent before child, the same order the export wrote them in.
        for (final name in scope) {
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

/// Text the sample row of every template reference sheet carries, so the user can
/// tell it apart from their own data.
const String excelSampleRowLabel = 'Sample Row';

/// The Guide sheet: how to add one's own cases to the workbook.
///
/// English, like the sheet names, so the same workbook reads the same whoever
/// generated it — a localized Guide would only make sense in the language it was
/// written in.
final ExcelTemplateSheet _guideSheet = ExcelTemplateSheet(
  excelGuideSheet,
  const <String>['Guide'],
  <List<Object?>>[
    for (final line in _guideLines) <Object?>[line],
  ],
);

/// The Guide sheet's prose, one line per row.
const List<String> _guideLines = <String>[
  'Legal Case Diary — Excel Template Guide',
  '',
  'How To Add Your Own Cases',
  '1. Open the Cases sheet. Its first row lists the columns; do not change it.',
  '2. Add one row per case underneath. Every other sheet here works the same way.',
  '3. Leave the id cell blank and the app gives the new row a fresh id of its own.',
  '4. court_id has to be an id from the Courts sheet, and on_behalf_id one from the On Behalfs sheet.',
  '5. case_type has to be a name from the Case Types sheet, and last_step one from the Steps sheet.',
  '6. case_category_id is optional; leave it blank, or use an id from the Case Categories sheet.',
  '7. Every required column must be filled. The app refuses the whole file otherwise and names the sheet and row.',
  '',
  'Dates And Times',
  'Dates are stored as Unix epoch milliseconds, as a plain whole number: 1 January 2026 is 1767225600000.',
  'created_at and updated_at are required, so copy a timestamp from an existing row if you are unsure.',
  '',
  'The Other Sheets',
  'Courts, Case Categories, Case Types, Steps and On Behalfs list the reference data this diary already holds, so you can see the exact ids and names to quote. Each of them starts with one Example — Sample Row row; delete it.',
  'On the Courts sheet the District column groups the lower courts by district, so you can filter them by it; it is blank for the Appellate Division and the High Court Division.',
  'Case History, Notes and Case References hold the records that belong to a case. Each row needs the case_id of a case that exists, either already in the diary or added in this same file.',
  'Courts, steps and settings themselves cannot be added here — that is done in the app.',
  '',
  'Restoring The File',
  'Save the workbook as .xlsx, then choose Restore from Backup in Settings > Backup & Restore and pick this file.',
  'The app replaces what Cases, Case History, Notes and Case References hold on this device with what the file holds, and leaves the rest of the diary alone. It asks before it replaces anything.',
  '',
  'Please Note',
  'This workbook is a plaintext spreadsheet: anyone who opens it can read your case data.',
  'Do not rename the sheets or the header cells, and do not reorder the columns: the app matches both by name.',
];

/// Courts for the sample's Courts sheet. Soft-deleted rows are excluded, and the
/// district id and the two order columns come back so the rows can be sorted in
/// Dart — by district first, so the sheet can be filtered by it, then by court
/// category and court order as before.
const String _courtsSql =
    'SELECT c.id AS row_id, c.court_name AS row_name, '
    'cc.name_key AS category_key, c.district AS district_id, '
    'cc.order_index AS category_order, c.order_index AS row_order '
    'FROM courts c '
    'LEFT JOIN court_categories cc ON cc.id = c.court_category_id '
    'WHERE c.is_deleted = 0';

/// Case categories, by display name, with their court category.
const String _caseCategoriesSql =
    'SELECT k.id AS row_id, k.name AS row_name, '
    'cc.name_key AS category_key FROM case_categories k '
    'LEFT JOIN court_categories cc ON cc.id = k.court_category_id '
    'WHERE k.is_deleted = 0 '
    'ORDER BY cc.order_index, k.order_index, k.name';

/// Case types: the name `cases.case_type` stores, plus its scopes.
const String _caseTypesSql =
    'SELECT t.name AS row_name, cc.name_key AS category_key, '
    'k.name AS case_category_name FROM case_types t '
    'LEFT JOIN court_categories cc ON cc.id = t.court_category_id '
    'LEFT JOIN case_categories k ON k.id = t.case_category_id '
    'WHERE t.is_deleted = 0 '
    'ORDER BY cc.order_index, t.order_index, t.name';

/// Steps: the name `cases.last_step` stores.
const String _stepsSql =
    'SELECT s.step_name AS row_name, cc.name_key AS category_key '
    'FROM steps s '
    'LEFT JOIN court_categories cc ON cc.id = s.court_category_id '
    'WHERE s.is_deleted = 0 '
    'ORDER BY cc.order_index, s.order_index, s.step_name';

/// Representational roles, by display name.
const String _onBehalfsSql =
    'SELECT o.id AS row_id, o.name AS row_name, cc.name_key AS category_key '
    'FROM on_behalfs o '
    'LEFT JOIN court_categories cc ON cc.id = o.court_category_id '
    'WHERE o.is_deleted = 0 '
    'ORDER BY cc.order_index, o.order_index, o.name';

/// One built set of template reference sheets, plus the values that make the
/// sample case row believable.
class _ExcelReferenceData {
  /// Sheet name → the sheet, already carrying its sample row and live rows.
  final Map<String, ExcelTemplateSheet> sheets;

  /// `cases` column → value taken from the diary's own reference data.
  final Map<String, Object?> exampleCaseValues;

  const _ExcelReferenceData({
    required this.sheets,
    required this.exampleCaseValues,
  });
}

/// Default backup file name for an export taken at [exportedAt].
///
/// UTC `legal-case-diary-backup-YYYYMMDD-HHMMSS.lcbak` — sortable, unique per
/// second, and independent of the device locale. The extension is not `.json`
/// because the file is the encrypted container, not readable JSON; Phase 3's
/// picker filters on it.
String defaultBackupFileName(int exportedAt) =>
    'legal-case-diary-backup-${_fileStamp(exportedAt)}.lcbak';

/// Default workbook file name for an export taken at [exportedAt].
///
/// Mirrors [defaultBackupFileName] with the extension Excel itself recognises, so
/// the save dialog offers the file as a spreadsheet and the picker can find it
/// again.
String defaultExcelFileName(int exportedAt) =>
    'legal-case-diary-${_fileStamp(exportedAt)}.xlsx';

/// UTC `YYYYMMDD-HHMMSS`, the stamp both default file names share.
String _fileStamp(int exportedAt) {
  final at = DateTime.fromMillisecondsSinceEpoch(exportedAt, isUtc: true);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${at.year}${two(at.month)}${two(at.day)}'
      '-${two(at.hour)}${two(at.minute)}${two(at.second)}';
}

/// The cell kind a database column's values round-trip through.
///
/// The app stores every date and timestamp as an integer (epoch millis), so the
/// three kinds the schema actually uses cover it; anything else stays text, which
/// is the safe default for a value the workbook only has to carry.
/// Takes the column's type as `Object` because drift does not export the
/// `BaseSqlType` that `GeneratedColumn.type` is declared with; the constants
/// below are what it actually holds.
ExcelCellKind _cellKind(Object type) => switch (type) {
  DriftSqlType.bool => ExcelCellKind.boolean,
  DriftSqlType.int || DriftSqlType.bigInt => ExcelCellKind.integer,
  DriftSqlType.double => ExcelCellKind.real,
  _ => ExcelCellKind.text,
};

/// The receipt of one Excel export.
class ExcelExportResult {
  /// Path the workbook was written to.
  final String path;

  /// Export time in epoch milliseconds.
  final int exportedAt;

  /// Creates an Excel export receipt.
  const ExcelExportResult({required this.path, required this.exportedAt});
}
