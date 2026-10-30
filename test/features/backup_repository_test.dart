/// Tests for the local backup export engine (Task 15 Phases 1–2).
///
/// The engine snapshots every portable table as raw rows so ids, sync columns
/// and tombstones survive unchanged, then seals that snapshot into the
/// authenticated-encrypted container. These tests pin the table coverage, the
/// row fidelity, the encrypted file that is actually written and the recorded
/// archive state.
library;

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
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
import 'package:legal_case_diary/features/settings/data/backup_file_gateway.dart';
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

/// A workbook's parts, keyed by part path, so a test can read what was written.
Map<String, String> _workbookParts(Uint8List bytes) => <String, String>{
  for (final file in ZipDecoder().decodeBytes(bytes).files)
    if (file.isFile) file.name: utf8.decode(file.readBytes()!),
};

void main() {
  // The folder-resolution tests mock the method channel, which needs the test
  // binding; the rest of the suite uses it idempotently.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupRepository', () {
    late AppDatabase db;
    late BackupRepository backup;
    late LocalIdentityService identity;
    late LocalCaseRepository caseRepo;
    late LocalNotesRepository notesRepo;
    late CasesDao casesDao;
    late String courtId;
    late String onBehalfId;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());

      final prefs = await SharedPreferences.getInstance();
      identity = LocalIdentityService(prefs);
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
      onBehalfId = await LocalOnBehalfsRepository(OnBehalfsDao(db), syncHelper)
          .insert(
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
      expect(
        alive.keys,
        containsAll(<String>[
          'version',
          'updated_at',
          'is_deleted',
          'synced_at',
          'last_modified_by',
        ]),
      );
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

    test(
      'exportSnapshot writes an encrypted container and records the archive',
      () async {
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
        expect(
          container.checksum,
          checksumOfBytes(utf8.encode(result.envelope.encode())),
        );
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
      },
    );

    test(
      'the exported file never contains the case data or the secret',
      () async {
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
      },
    );

    test(
      'exportSnapshot without a secret writes the readable envelope',
      () async {
        await addCase('110/2021');
        final sink = _RecordingSink();

        final result = await backup.exportSnapshot(
          sink: sink,
          appVersion: '0.0.227',
          exportedAt: 1700000000000,
        );

        // No secret means no sealing: the file is the versioned JSON envelope,
        // which is what the default "encryption off" writes.
        final file = utf8.decode(sink.written.values.single);
        final decoded = BackupEnvelope.decode(file);
        expect(decoded.schemaVersion, kBackupSchemaVersion);
        expect(decoded.tables['cases'], hasLength(1));
        // And it is recorded exactly like the sealed export.
        expect(result.checksum, checksumOfBytes(sink.written.values.single));
        final archive = await backup.readArchiveState();
        expect(archive.hasCompletedArchive, isTrue);
      },
    );

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

    test(
      'a workbook import replaces only the tables the file carries',
      () async {
        await notesRepo.insertNote(
          const NotesCompanion(title: Value('Mine'), body: Value('Body')),
        );
        final bytes = await backup.buildExcelWorkbook(
          appVersion: '0.0.262',
          exportedAt: 1758844800000,
        );

        final result = await backup.restoreSnapshot(
          backup: backup.openExcelBackup(bytes),
          ownerId: identity.getId(),
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
      },
    );

    test('a scoped file only asks about the tables it would replace', () async {
      await notesRepo.insertNote(
        const NotesCompanion(title: Value('Mine'), body: Value('Body')),
      );
      // The court holds a row, but a workbook does not carry `courts`, so it is
      // not a reason to ask before replacing the four sheets.
      expect(await backup.hasDataInTables(<String>['cases', 'notes']), isTrue);
      expect(await backup.hasDataInTables(<String>['cases']), isFalse);
    });

    test('the sample template carries this diary’s own reference data', () async {
      final bytes = await backup.buildExcelTemplateWorkbook(
        appVersion: '0.0.263',
        categoryLabel: (nameKey) => 'LABEL:$nameKey',
      );
      final parts = _workbookParts(bytes);

      // The sample adds the sheets that show the user what to quote...
      final workbook = parts['xl/workbook.xml']!;
      for (final sheet in <String>[
        ...excelSheetTables.keys,
        ...excelTemplateSheets,
        excelInfoSheet,
      ]) {
        expect(workbook, contains('name="$sheet"'));
      }
      // ...filled from the live diary, so the court id a hand-typed case has to
      // quote is right there, next to the category label the app shows.
      final courts = parts['xl/worksheets/sheet6.xml']!;
      expect(courts, contains(courtId));
      expect(courts, contains('Test Court'));
      expect(courts, contains('LABEL:test_category'));
      // The Courts sheet leads with a District column, so a court can be found by
      // the district it sits in.
      expect(courts, contains('Court Category'));
      expect(courts, contains('District'));
      // Every reference sheet leads with one clearly-labelled sample row.
      expect(courts, contains('Example — $excelSampleRowLabel'));
    });

    test(
      'the Courts sheet groups lower courts by district, AD and HCD first',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final syncHelper = SyncWriteHelper(
          SyncQueueDao(db),
          LocalIdentityService(prefs),
        );
        final categories = LocalCourtCategoriesRepository(
          CourtCategoriesDao(db),
          syncHelper,
        );
        final courts = LocalCourtsRepository(CourtsDao(db), syncHelper);
        final highCourt = await categories.insert(
          CourtCategoriesCompanion(
            nameKey: const Value('high_court_division'),
            courtLevel: const Value('high_court'),
            orderIndex: const Value(0),
          ),
        );
        final civil = await categories.insert(
          CourtCategoriesCompanion(
            nameKey: const Value('district_courts_civil'),
            courtLevel: const Value('lower'),
            orderIndex: const Value(2),
          ),
        );
        final sessions = await categories.insert(
          CourtCategoriesCompanion(
            nameKey: const Value('district_sessions_criminal'),
            courtLevel: const Value('lower'),
            orderIndex: const Value(3),
          ),
        );
        // AD/HCD first (no district), then the lower courts of one district in
        // court-category order, then the next district.
        await courts.insert(
          CourtsCompanion(
            courtName: const Value('High Court Division Court'),
            higherLowerCourts: const Value('higher_courts'),
            courtCategoryId: Value(highCourt),
            orderIndex: const Value(0),
          ),
        );
        await courts.insert(
          CourtsCompanion(
            courtName: const Value('Dhaka Civil Court'),
            higherLowerCourts: const Value('lower_courts'),
            courtCategoryId: Value(civil),
            district: const Value('dhaka'),
            orderIndex: const Value(1),
          ),
        );
        await courts.insert(
          CourtsCompanion(
            courtName: const Value('Dhaka Sessions Court'),
            higherLowerCourts: const Value('lower_courts'),
            courtCategoryId: Value(sessions),
            district: const Value('dhaka'),
            orderIndex: const Value(1),
          ),
        );
        await courts.insert(
          CourtsCompanion(
            courtName: const Value('Gazipur Civil Court'),
            higherLowerCourts: const Value('lower_courts'),
            courtCategoryId: Value(civil),
            district: const Value('gazipur'),
            orderIndex: const Value(2),
          ),
        );

        final bytes = await backup.buildExcelTemplateWorkbook(
          appVersion: '0.0.264',
          districtLabel: (id) => 'DISTRICT:$id',
        );
        final sheet = _workbookParts(bytes)['xl/worksheets/sheet6.xml']!;

        // The district column carries the district's name, not its id.
        expect(sheet, contains('DISTRICT:dhaka'));
        expect(sheet, contains('DISTRICT:gazipur'));
        // AD/HCD stay above every district-grouped lower court...
        expect(
          sheet.indexOf('High Court Division Court'),
          lessThan(sheet.indexOf('Dhaka Civil Court')),
        );
        // ...and within a district the courts follow court-category order.
        expect(
          sheet.indexOf('Dhaka Civil Court'),
          lessThan(sheet.indexOf('Dhaka Sessions Court')),
        );
        expect(
          sheet.indexOf('Dhaka Sessions Court'),
          lessThan(sheet.indexOf('Gazipur Civil Court')),
        );
      },
    );

    test(
      'the sample restores, its case row quoting the real court and role',
      () async {
        final bytes = await backup.buildExcelTemplateWorkbook(
          appVersion: '0.0.263',
        );

        // The reader skips the sample's reference and Guide sheets, so the file the
        // user downloaded is the file they can fill in and restore.
        final opened = backup.openExcelBackup(bytes);
        expect(opened.kind, BackupFileKind.excel);
        final cases = (opened.tables['cases'] as List)
            .cast<Map<String, dynamic>>();
        expect(cases, hasLength(1));
        // The example case points at data this diary really holds, so it is a
        // workable starting point rather than a row of column names.
        expect(cases.single['court_id'], courtId);
        expect(cases.single['on_behalf_id'], onBehalfId);
      },
    );

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
    test('is a local-stamped Backup_dd-mm-yy_hh-mm-ssam/pm name', () {
      // A fixed instant, formatted in the machine's own local time — AM/PM is
      // only meaningful locally, and the name must stay unique per second.
      final stamp = DateTime.utc(2026, 9, 20, 5, 6, 7).millisecondsSinceEpoch;
      final at = DateTime.fromMillisecondsSinceEpoch(stamp);
      String two(int v) => v.toString().padLeft(2, '0');
      final amPm = at.hour >= 12 ? 'pm' : 'am';
      final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
      final expected =
          'Backup_${two(at.day)}-${two(at.month)}-'
          '${two(at.year % 100)}_${two(h)}-${two(at.minute)}-'
          '${two(at.second)}$amPm.lcbak';
      expect(defaultBackupFileName(stamp), expected);
    });

    test('an automatic backup carries its own stem and the same stamp', () {
      // The stamp is the same shape as a manual backup's, so the file still
      // says when it was made; the stem is what tells the two apart, and what
      // lets the sweep delete only the app's own automatic file.
      final stamp = DateTime.utc(2026, 9, 20, 5, 6, 7).millisecondsSinceEpoch;
      final automatic = automaticBackupFileName(stamp);
      final manual = defaultBackupFileName(stamp);
      expect(automatic, startsWith('AutomaticBackup_'));
      expect(automatic, endsWith('.lcbak'));
      // Identical but for the prefix: same stamp, same extension.
      expect(automatic, 'Automatic$manual');
    });

    test('names a workbook with the same stem and the Excel extension', () {
      final stamp = DateTime.utc(2026, 9, 20, 5, 6, 7).millisecondsSinceEpoch;
      final backup = defaultBackupFileName(stamp);
      expect(
        defaultExcelFileName(stamp),
        '${backup.substring(0, backup.length - '.lcbak'.length)}.xlsx',
      );
    });
  });

  group('backupDocumentsDirectory', () {
    const channel = MethodChannel(
      'com.legumsoft.legalcasediary/public_downloads',
    );

    test('uses the public Downloads folder when the host answers', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'path');
            return '/storage/emulated/0/Download';
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      final folder = await backupDocumentsDirectory();
      expect(
        folder.path.replaceAll(r'\', '/'),
        '/storage/emulated/0/Download/LegalCaseDiary',
      );
    });

    test(
      'falls back to the documents folder when the host has no channel',
      () async {
        // No handler is installed for the public-downloads channel, so it throws
        // MissingPluginException and the resolver falls back to the private
        // documents directory.
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (call) async => 'C:/PrivateDocuments',
            );
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(
                const MethodChannel('plugins.flutter.io/path_provider'),
                null,
              ),
        );

        final folder = await backupDocumentsDirectory();
        expect(
          folder.path.replaceAll(r'\', '/'),
          'C:/PrivateDocuments/LegalCaseDiary',
        );
      },
    );
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
