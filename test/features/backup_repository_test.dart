/// Tests for the local backup export engine (Task 15 Phase 1).
///
/// The engine snapshots every portable table as raw rows so ids, sync columns
/// and tombstones survive unchanged. These tests pin the table coverage, the
/// row fidelity, the written envelope and the recorded archive state.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/backup/backup_format.dart';
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

    test('exportSnapshot writes a versioned envelope and records the archive', () async {
      await addCase('110/2021');
      final sink = _RecordingSink();

      final result = await backup.exportSnapshot(
        sink: sink,
        appVersion: '0.0.227',
        exportedAt: 1700000000000,
      );

      // The file itself is a valid, self-verifying envelope.
      expect(sink.written.keys.single, defaultBackupFileName(1700000000000));
      final bytes = sink.written.values.single;
      final decoded = BackupEnvelope.decode(utf8.decode(bytes));
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

    test('a failed write never records a completed archive', () async {
      final sink = _FailingSink();
      await expectLater(
        backup.exportSnapshot(
          sink: sink,
          appVersion: '0.0.227',
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
  });

  group('defaultBackupFileName', () {
    test('is a sortable UTC timestamp with the json extension', () {
      // 2026-09-20 05:06:07 UTC.
      final stamp = DateTime.utc(2026, 9, 20, 5, 6, 7).millisecondsSinceEpoch;
      expect(
        defaultBackupFileName(stamp),
        'legal-case-diary-backup-20260920-050607.json',
      );
    });
  });
}

/// Fails the write so the "no completed archive on failure" rule can be tested.
class _FailingSink implements BackupArchiveSink {
  @override
  Future<String> write({
    required String fileName,
    required Uint8List bytes,
  }) async => throw StateError('disk full');
}
