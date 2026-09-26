/// Tests for the local backup export engine (Task 15 Phases 1–2).
///
/// The engine snapshots every portable table as raw rows so ids, sync columns
/// and tombstones survive unchanged, then seals that snapshot into the
/// authenticated-encrypted container. These tests pin the table coverage, the
/// row fidelity, the encrypted file that is actually written and the recorded
/// archive state.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/backup/backup_cipher.dart';
import 'package:legal_case_diary/core/backup/backup_format.dart';
import 'package:legal_case_diary/core/backup/backup_restore.dart';
import 'package:legal_case_diary/core/backup/excel_backup.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/cases/data/case_repository.dart';
import 'package:legal_case_diary/features/cases/data/local/case_history_dao.dart';
import 'package:legal_case_diary/features/cases/data/local/cases_dao.dart';
import 'package:legal_case_diary/features/notes/data/local/notes_dao.dart';
import 'package:legal_case_diary/features/notes/data/notes_repository.dart';
import 'package:legal_case_diary/features/settings/data/backup_repository.dart';
import 'package:legal_case_diary/features/settings/data/court_categories_repository.dart';
import 'package:legal_case_diary/features/settings/data/courts_repository.dart';
import 'package:legal_case_diary/features/settings/data/local/court_categories_dao.dart';
import 'package:legal_case_diary/features/settings/data/local/courts_dao.dart';
import 'package:legal_case_diary/features/settings/data/local/on_behalfs_dao.dart';
import 'package:legal_case_diary/features/settings/data/on_behalfs_repository.dart';
import 'package:legal_case_diary/sync/sync_queue_dao.dart';
import 'package:legal_case_diary/sync/sync_write_helper.dart';

/// Records what the engine wrote instead of touching the file system.
class _RecordingSink implements BackupArchiveSink {
  final Map<String, Uint8List> written = <String, Uint8List>{};

  @override
  Future<String> write({
    required String fileName,
    required Uint8List bytes,
  }) async {
    written[fileName] = bytes;
    return '/tmp/$fileName';
  }
}

/// The recovery secret every export in this suite uses.
const String _secret = "a lawyer's strong passphrase";

void main() {
  group('BackupRepository', () {
    late AppDatabase db;
    late BackupRepository backup;
    late LocalCaseRepository caseRepo;
    late LocalNotesRepository notesRepo;
    late CasesDao casesDao;
    late String courtId;
    late String onBehalfId;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());

      final prefs = await SharedPreferences.getInstance();
      final identity = LocalIdentityService(prefs);
      final syncHelper = SyncWriteHelper(SyncQueueDao(db), identity);

      casesDao = CasesDao(db);
      caseRepo = LocalCaseRepository(casesDao, CaseHistoryDao(db), syncHelper);
      notesRepo = LocalNotesRepository(NotesDao(db), syncHelper);
      backup = BackupRepository(db);

      final categories = LocalCourtCategoriesRepository(
        CourtCategoriesDao(db),
        syncHelper,
      );
      final courtCategoryId = await categories.insert(
        CourtCategoriesCompanion(
          nameKey: const Value('test_category'),
          courtLevel: const Value('lower'),
          orderIndex: const Value(1),
        ),
      );
      courtId = await LocalCourtsRepository(CourtsDao(db), syncHelper).insert(
        CourtsCompanion(
          courtName: const Value('Test Court'),
          higherLowerCourts: const Value('lower_courts'),
          courtCategoryId: Value(courtCategoryId),
        ),
      );
      onBehalfId = await LocalOnBehalfsRepository(
        OnBehalfsDao(db),
        syncHelper,
      ).insert(
        OnBehalfsCompanion(
          courtCategoryId: Value(courtCategoryId),
          name: const Value('Plaintiff'),
          orderIndex: const Value(1),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    Future<String> addCase(String number) => caseRepo.insertCase(
      CasesCompanion(
        caseNumber: Value(number),
        petitioner: const Value('Alice'),
        respondent: const Value('Bob'),
        courtId: Value(courtId),
        caseType: const Value('Civil'),
        onBehalfId: Value(onBehalfId),
      ),
    );

    test('the export list covers every table in the database', () {
      final inDatabase = db.allTables
          .map((table) => table.actualTableName)
          .toSet();
      expect(backupTableOrder.toSet(), inDatabase);
      expect(backup.tableNames, backupTableOrder);
    });

    test('collectTables reads raw snake_case rows for every table', () async {
      await addCase('110/2021');

      final tables = await backup.collectTables();

      expect(tables.keys.toSet(), backupTableOrder.toSet());
      final cases = (tables['cases'] as List).cast<Map<String, dynamic>>();
      expect(cases, hasLength(1));
      // Raw columns survive unmapped: the DB names, not the Dart field names.
      expect(cases.single.keys, containsAll(<String>['id', 'case_number']));
      expect(cases.single['case_number'], '110/2021');
      expect(cases.single.containsKey('caseNumber'), isFalse);
    });

    test('rows keep their ids, sync columns and tombstones', () async {
      final aliveId = await addCase('110/2021');
      final deadId = await addCase('111/2021');
      await casesDao.delete(deadId, 4242);

      final envelope = await backup.buildEnvelope(
        appVersion: '0.0.227',
        exportedAt: 1000,
      );
      final cases = (envelope.tables['cases'] as List)
          .cast<Map<String, dynamic>>();
      final alive = cases.singleWhere((row) => row['id'] == aliveId);
      final dead = cases.singleWhere((row) => row['id'] == deadId);

      // Every global sync column is present and intact.
      expect(alive.keys, containsAll(<String>['version', 'updated_at', 'is_deleted', 'synced_at', 'last_modified_by']));
      expect(alive['is_deleted'], 0);
      expect(dead['is_deleted'], 1);
      expect(dead['updated_at'], 4242);
      expect(dead['last_modified_by'], isNotNull);
    });

    test('pending sync_queue rows are part of the snapshot', () async {
      final id = await addCase('110/2021');

      final envelope = await backup.buildEnvelope(
        appVersion: '0.0.227',
        exportedAt: 1000,
      );
      final queue = (envelope.tables['sync_queue'] as List)
          .cast<Map<String, dynamic>>();
      // The fixture's reference-row inserts queue too, so pin this case's row.
      final entries = queue.where((row) => row['entity_id'] == id).toList();

      expect(entries, hasLength(1));
      expect(entries.single['entity_type'], 'case');
      expect(entries.single['operation'], 'insert');
      expect(entries.single['payload'], isNotNull);
    });

    test('soft-deleted-only content still exports (notes tombstone)', () async {
      final noteId = await notesRepo.insertNote(
        NotesCompanion(
          title: const Value('Reminder'),
          body: const Value('File the affidavit'),
          createdAt: const Value(1),
        ),
      );
      await db
          .update(db.notes)
          .write(const NotesCompanion(isDeleted: Value(true)));

      final envelope = await backup.buildEnvelope(
        appVersion: '0.0.227',
        exportedAt: 1000,
      );
      final notes = (envelope.tables['notes'] as List)
          .cast<Map<String, dynamic>>();

      expect(notes.single['id'], noteId);
      expect(notes.single['is_deleted'], 1);
    });

    test('exportSnapshot writes an encrypted container and records the archive', () async {
      await addCase('110/2021');
      final sink = _RecordingSink();

      final result = await backup.exportSnapshot(
        sink: sink,
        appVersion: '0.0.227',
        recoverySecret: _secret,
        exportedAt: 1700000000000,
        kdfIterations: 1000,
      );

      // The file itself is an authenticated container holding a self-verifying
      // envelope: decrypt first, then read the versioned document inside.
      expect(sink.written.keys.single, defaultBackupFileName(1700000000000));
      final bytes = sink.written.values.single;
      final container = EncryptedBackup.decode(utf8.decode(bytes));
      expect(container.format, kEncryptedBackupFormat);
      expect(container.formatVersion, kEncryptedBackupFormatVersion);
      expect(container.checksum, checksumOfBytes(utf8.encode(result.envelope.encode())));
      final decoded = BackupEnvelope.decode(
        utf8.decode(await decryptBackup(container, recoverySecret: _secret)),
      );
      expect(decoded.schemaVersion, kBackupSchemaVersion);
      expect(decoded.appVersion, '0.0.227');
      expect(decoded.exportedAt, 1700000000000);
      expect(decoded.verifyChecksum(), isTrue);
      expect(decoded.tables['cases'], hasLength(1));

      // The receipt and the recorded archive agree with the written bytes.
      expect(result.path, '/tmp/${defaultBackupFileName(1700000000000)}');
      expect(result.checksum, checksumOfBytes(bytes));
      final archive = await backup.readArchiveState();
      expect(archive.path, result.path);
      expect(archive.checksum, result.checksum);
      expect(archive.state, archiveStateComplete);
      expect(archive.hasCompletedArchive, isTrue);
    });

    test('the exported file never contains the case data or the secret', () async {
      await addCase('110/2021');
      final sink = _RecordingSink();

      await backup.exportSnapshot(
        sink: sink,
        appVersion: '0.0.227',
        recoverySecret: _secret,
        exportedAt: 1700000000000,
        kdfIterations: 1000,
      );

      // §12.3.1: no plaintext export ever reaches storage.
      final file = utf8.decode(sink.written.values.single);
      expect(file, isNot(contains('110/2021')));
      expect(file, isNot(contains('Alice')));
      expect(file, isNot(contains('schema_version')));
      expect(file, isNot(contains(_secret)));
      // It is the container: a wrong secret cannot open it.
      await expectLater(
        decryptBackup(
          EncryptedBackup.decode(file),
          recoverySecret: 'not the passphrase',
        ),
        throwsA(isA<BackupDecryptionException>()),
      );
    });

    test('a failed write never records a completed archive', () async {
      final sink = _FailingSink();
      await expectLater(
        backup.exportSnapshot(
          sink: sink,
          appVersion: '0.0.227',
          recoverySecret: _secret,
          exportedAt: 1000,
        ),
        throwsA(isA<StateError>()),
      );
      final archive = await backup.readArchiveState();
      expect(archive.hasCompletedArchive, isFalse);
    });

    test('no archive is recorded before the first export', () async {
      final archive = await backup.readArchiveState();
      expect(archive.path, isNull);
      expect(archive.state, isNull);
      expect(archive.hasCompletedArchive, isFalse);
    });

    test('the Excel sheet columns are the live schema columns, in order', () {
      for (final table in excelSheetTables.values) {
        final info = db.allTables.firstWhere(
          (candidate) => candidate.actualTableName == table,
        );
        final specs = backup.excelColumnSpecsFor(table);
        // Derived from the schema rather than listed by hand, so the workbook,
        // the sample template and the reader cannot drift from the tables.
        expect(
          specs.map((spec) => spec.name),
          info.$columns.map((column) => column.name),
        );
        expect(
          specs.map((spec) => spec.required),
          info.$columns.map((column) => column.requiredDuringInsert),
        );
      }
      expect(backup.excelColumnSpecs().keys, excelSheetTables.values);
    });

    test('a workbook round-trips the four tables and their values', () async {
      final id = await notesRepo.insertNote(
        const NotesCompanion(
          title: Value('Reminder'),
          body: Value('File the affidavit'),
        ),
      );

      final bytes = await backup.buildExcelWorkbook(
        appVersion: '0.0.262',
        exportedAt: 1758844800000,
      );
      final opened = backup.openExcelBackup(bytes);

      expect(opened.kind, BackupFileKind.excel);
      expect(opened.tables.keys.toSet(), excelSheetTables.values.toSet());
      final notes = (opened.tables['notes'] as List)
          .cast<Map<String, dynamic>>();
      expect(notes, hasLength(1));
      // The id, the sync columns and the text come back as the app wrote them,
      // which is what lets a restored row be pushed later unchanged.
      expect(notes.single['id'], id);
      expect(notes.single['title'], 'Reminder');
      expect(notes.single['is_deleted'], isFalse);
      expect(notes.single['updated_at'], isA<int>());
    });

    test('a workbook import replaces only the tables the file carries', () async {
      await notesRepo.insertNote(
        const NotesCompanion(title: Value('Mine'), body: Value('Body')),
      );
      final bytes = await backup.buildExcelWorkbook(
        appVersion: '0.0.262',
        exportedAt: 1758844800000,
      );

      final result = await backup.restoreSnapshot(
        backup: backup.openExcelBackup(bytes),
        replaceExisting: true,
      );

      expect(result.replacedExisting, isTrue);
      expect(result.tableCount, excelSheetTables.length);
      // The note survives its own replace...
      final notes = await db
          .customSelect('SELECT COUNT(*) AS n FROM notes')
          .getSingle();
      expect(notes.data['n'], 1);
      // ...and the court the file never carried is still there, which is what
      // keeps a partial file from emptying the diary's reference data.
      final courts = await db
          .customSelect(
            'SELECT COUNT(*) AS n FROM courts WHERE id = ?',
            variables: <Variable>[Variable(courtId)],
          )
          .getSingle();
      expect(courts.data['n'], 1);
    });

    test('a scoped file only asks about the tables it would replace', () async {
      await notesRepo.insertNote(
        const NotesCompanion(title: Value('Mine'), body: Value('Body')),
      );
      // The court holds a row, but a workbook does not carry `courts`, so it is
      // not a reason to ask before replacing the four sheets.
      expect(await backup.hasDataInTables(<String>['cases', 'notes']), isTrue);
      expect(await backup.hasDataInTables(<String>['cases']), isFalse);
    });

    test('a hand-added workbook row with a blank id is given one', () {
      final specs = backup.excelColumnSpecsFor('notes');
      final rebuilt = encodeExcelBackup(
        appVersion: '0.0.262',
        exportedAt: 1758844800000,
        schemaVersion: 1,
        columns: backup.excelColumnSpecs(),
        tables: <String, List<Map<String, dynamic>>>{
          for (final table in excelSheetTables.values)
            table: table == 'notes'
                ? <Map<String, dynamic>>[
                    <String, dynamic>{
                      for (final spec in specs)
                        spec.name: spec.name == 'id' ? '' : _sampleValue(spec),
                    },
                  ]
                : const <Map<String, dynamic>>[],
        },
      );

      // A blank id is what makes a row typed into Excel importable; any other
      // blank in a required column is refused by the format reader instead.
      final opened = backup.openExcelBackup(rebuilt, newId: () => 'fresh-id');
      final notes = (opened.tables['notes'] as List)
          .cast<Map<String, dynamic>>();
      expect(notes.single['id'], 'fresh-id');
    });
  });

  group('defaultBackupFileName', () {
    test('is a sortable UTC timestamp with the encrypted-backup extension', () {
      // 2026-09-20 05:06:07 UTC.
      final stamp = DateTime.utc(2026, 9, 20, 5, 6, 7).millisecondsSinceEpoch;
      expect(
        defaultBackupFileName(stamp),
        'legal-case-diary-backup-20260920-050607.lcbak',
      );
    });

    test('names a workbook with the extension Excel recognises', () {
      final stamp = DateTime.utc(2026, 9, 20, 5, 6, 7).millisecondsSinceEpoch;
      expect(
        defaultExcelFileName(stamp),
        'legal-case-diary-20260920-050607.xlsx',
      );
    });
  });

}

/// A plausible, non-empty value for one column of the sample row.
Object _sampleValue(ExcelColumnSpec spec) => switch (spec.kind) {
  ExcelCellKind.integer => 1,
  ExcelCellKind.real => 1.0,
  ExcelCellKind.boolean => false,
  ExcelCellKind.text => 'sample',
};

/// Fails the write so the "no completed archive on failure" rule can be tested.
class _FailingSink implements BackupArchiveSink {
  @override
  Future<String> write({
    required String fileName,
    required Uint8List bytes,
  }) async => throw StateError('disk full');
}
