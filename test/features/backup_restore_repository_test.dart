/// Tests for the restore/import engine (Task 15 Phase 3).
///
/// Restore must reproduce the source database exactly — ids, sync columns,
/// tombstones and queued writes included — and must never leave a partially
/// replaced database behind: a collision, a damaged file or a failed insert
/// leaves the existing data untouched.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/backup/backup_format.dart';
import 'package:legal_case_diary/core/backup/backup_ownership.dart';
import 'package:legal_case_diary/core/backup/backup_restore.dart';
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

/// The recovery secret every export in this suite uses.
const String _secret = "a lawyer's strong passphrase";

/// Records what an export wrote instead of touching the file system.
class _RecordingSink implements BackupArchiveSink {
  Uint8List? written;

  @override
  Future<String> write({
    required String fileName,
    required Uint8List bytes,
  }) async {
    written = bytes;
    return '/tmp/$fileName';
  }
}

/// One in-memory database plus the repositories a fixture needs.
class _Side {
  _Side._(this.db, this.syncHelper, this.identity);

  /// Opens a fresh empty database with its own local identity.
  static Future<_Side> open() async {
    final db = AppDatabase(NativeDatabase.memory());
    final prefs = await SharedPreferences.getInstance();
    final identity = LocalIdentityService(prefs);
    return _Side._(db, SyncWriteHelper(SyncQueueDao(db), identity), identity);
  }

  final AppDatabase db;
  final SyncWriteHelper syncHelper;

  /// This device's identity: the value its own writes carry, and the value a
  /// restore is performed as.
  final LocalIdentityService identity;

  /// Shorthand for [identity].
  String get ownerId => identity.getId();

  BackupRepository get backup => BackupRepository(db);
  CasesDao get casesDao => CasesDao(db);

  /// Inserts the reference rows a case needs and returns their ids.
  Future<({String courtId, String onBehalfId})> seedReferenceData() async {
    final categories = LocalCourtCategoriesRepository(
      CourtCategoriesDao(db),
      syncHelper,
    );
    final categoryId = await categories.insert(
      CourtCategoriesCompanion(
        nameKey: const Value('test_category'),
        courtLevel: const Value('lower'),
        orderIndex: const Value(1),
      ),
    );
    final courtId = await LocalCourtsRepository(CourtsDao(db), syncHelper).insert(
      CourtsCompanion(
        courtName: const Value('Test Court'),
        higherLowerCourts: const Value('lower_courts'),
        courtCategoryId: Value(categoryId),
      ),
    );
    final onBehalfId = await LocalOnBehalfsRepository(
      OnBehalfsDao(db),
      syncHelper,
    ).insert(
      OnBehalfsCompanion(
        courtCategoryId: Value(categoryId),
        name: const Value('Plaintiff'),
        orderIndex: const Value(1),
      ),
    );
    return (courtId: courtId, onBehalfId: onBehalfId);
  }

  /// Adds a case (which also writes history and a queue entry).
  Future<String> addCase(
    String number, {
    required String courtId,
    required String onBehalfId,
    String petitioner = 'Alice',
  }) => LocalCaseRepository(casesDao, CaseHistoryDao(db), syncHelper).insertCase(
    CasesCompanion(
      caseNumber: Value(number),
      petitioner: Value(petitioner),
      respondent: const Value('Bob'),
      courtId: Value(courtId),
      caseType: const Value('Civil'),
      onBehalfId: Value(onBehalfId),
    ),
  );

  /// Adds a note, so a second table has rows to compare.
  Future<String> addNote(String title) => LocalNotesRepository(
    NotesDao(db),
    syncHelper,
  ).insertNote(
    NotesCompanion(
      title: Value(title),
      body: const Value('File the affidavit'),
      createdAt: const Value(1),
    ),
  );

  Future<void> close() => db.close();
}

/// Seeds a side with reference data, two cases (one retired) and a note.
Future<({String aliveId, String deadId})> _seed(_Side side) async {
  final ids = await side.seedReferenceData();
  final aliveId = await side.addCase(
    '110/2021',
    courtId: ids.courtId,
    onBehalfId: ids.onBehalfId,
  );
  final deadId = await side.addCase(
    '111/2021',
    courtId: ids.courtId,
    onBehalfId: ids.onBehalfId,
  );
  await side.casesDao.delete(deadId, 4242);
  await side.addNote('Reminder');
  return (aliveId: aliveId, deadId: deadId);
}

/// An exported file, the archive metadata the source held when it was written,
/// and the opened copy a restore would use.
typedef _Export = ({
  OpenedBackup opened,
  BackupArchiveState archiveBefore,
  Uint8List bytes,
});

/// Exports [side] and opens the written file again.
Future<_Export> _export(_Side side) async {
  final archiveBefore = await side.backup.readArchiveState();
  final sink = _RecordingSink();
  await side.backup.exportSnapshot(
    sink: sink,
    appVersion: '0.0.229',
    recoverySecret: _secret,
    exportedAt: 1700000000000,
    kdfIterations: 1000,
  );
  return (
    opened: await openBackupFile(bytes: sink.written!, recoverySecret: _secret),
    archiveBefore: archiveBefore,
    bytes: sink.written!,
  );
}

/// A plaintext envelope file with a hand-written payload, for damaged-file tests.
Uint8List _legacyFile(Map<String, dynamic> tables) => Uint8List.fromList(
  utf8.encode(
    BackupEnvelope.create(
      appVersion: '0.0.227',
      exportedAt: 1,
      payload: <String, dynamic>{kBackupTablesSection: tables},
    ).encode(),
  ),
);

/// The `sync_metadata` rows that are not the archive record.
///
/// No backup can contain its **own** archive record: the export writes the file
/// first and only records `archive.*` afterwards, so a failed write can never
/// leave a "complete" archive behind. A restore therefore reproduces the archive
/// metadata the file was written *with*, which these tests assert separately.
List<Map<String, dynamic>> _withoutArchiveRecord(Object? rows) => (rows as List)
    .cast<Map<String, dynamic>>()
    .where((row) => !(row['key'] as String).startsWith('archive.'))
    .toList();

/// Asserts that [target] now holds exactly the same rows as [source].
///
/// Compared one table at a time so a failure names the table that drifted
/// rather than dumping every table at once.
Future<void> _expectSameData(_Side target, _Side source) async {
  final expected = await source.backup.collectTables();
  final actual = await target.backup.collectTables();
  expect(actual.keys.toSet(), expected.keys.toSet());
  for (final table in backupTableOrder) {
    if (table == 'sync_metadata') {
      expect(
        _withoutArchiveRecord(actual[table]),
        _withoutArchiveRecord(expected[table]),
        reason: 'table $table (excluding the archive record)',
      );
      continue;
    }
    expect(actual[table], expected[table], reason: 'table $table');
  }
}

/// Expects opening [bytes] or importing them into [side] to fail with [failure].
///
/// Both steps are inside the assertion because a damaged file is refused while
/// opening and a collision or a failed insert while importing, and the caller
/// only ever sees one failure either way.
Future<void> _expectRefused(
  _Side side,
  Uint8List bytes,
  BackupRestoreFailure failure, {
  bool replaceExisting = false,
  String? ownerId,
}) async {
  await expectLater(
    openBackupFile(bytes: bytes, recoverySecret: _secret).then(
      (opened) => side.backup.restoreSnapshot(
        backup: opened,
        ownerId: ownerId ?? side.ownerId,
        replaceExisting: replaceExisting,
      ),
    ),
    throwsA(
      isA<BackupRestoreException>().having(
        (error) => error.failure,
        'failure',
        failure,
      ),
    ),
  );
}

void main() {
  late _Side source;
  late _Side target;

  setUpAll(() {
    // Two independent in-memory databases are the point of this suite, which is
    // exactly what Drift's multiple-database warning flags.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    source = await _Side.open();
    target = await _Side.open();
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  group('restoreSnapshot round trip', () {
    test('reproduces the source database in an empty one', () async {
      await _seed(source);
      expect(await target.backup.hasExistingData(), isFalse);

      final exported = await _export(source);
      final result = await target.backup.restoreSnapshot(
        backup: exported.opened,
        ownerId: target.ownerId,
      );

      // Every table matches row for row, byte for byte: ids, sync columns,
      // tombstones and queue payloads all survive the round trip.
      await _expectSameData(target, source);
      // The archive record came across exactly as the file carried it.
      expect(
        (await target.backup.readArchiveState()).checksum,
        exported.archiveBefore.checksum,
      );
      expect(result.kind, BackupFileKind.encrypted);
      expect(result.schemaVersion, kBackupSchemaVersion);
      expect(result.tableCount, backupTableOrder.length);
      expect(result.replacedExisting, isFalse);
      expect(result.rowCount, greaterThan(0));
      expect(await target.backup.hasExistingData(), isTrue);
    });

    test('keeps ids, sync columns, tombstones and queued writes', () async {
      final seeded = await _seed(source);
      final result = await target.backup.restoreSnapshot(
        backup: (await _export(source)).opened,
        ownerId: target.ownerId,
      );

      final sourceCases = await source.backup.collectTables();
      final restoredCases = (await target.backup.collectTables())['cases'] as List;
      final alive = restoredCases
          .cast<Map<String, dynamic>>()
          .singleWhere((row) => row['id'] == seeded.aliveId);
      final dead = restoredCases
          .cast<Map<String, dynamic>>()
          .singleWhere((row) => row['id'] == seeded.deadId);

      expect(alive['case_number'], '110/2021');
      expect(dead['case_number'], '111/2021');
      // The tombstone and its sync columns are intact, not re-created.
      expect(dead['is_deleted'], 1);
      expect(dead['updated_at'], 4242);
      expect(dead['last_modified_by'], (sourceCases['cases'] as List)
          .cast<Map<String, dynamic>>()
          .singleWhere((row) => row['id'] == seeded.deadId)['last_modified_by']);
      expect(alive.keys, containsAll(<String>['version', 'updated_at', 'is_deleted', 'synced_at', 'last_modified_by']));

      // Pending queue entries come back with their payloads and their ids.
      final queue = (await target.backup.collectTables())['sync_queue'] as List;
      final caseRows = queue
          .cast<Map<String, dynamic>>()
          .where((row) => row['entity_id'] == seeded.aliveId)
          .toList();
      expect(caseRows, hasLength(1));
      expect(caseRows.single['operation'], 'insert');
      expect(caseRows.single['payload'], isNotNull);
      expect(caseRows.single['id'], isNotNull);
      expect(result.rowCount, greaterThanOrEqualTo(queue.length));
    });

    test('restores a legacy plaintext backup too', () async {
      await _seed(source);

      final result = await target.backup.restoreSnapshot(
        ownerId: target.ownerId,
        backup: await openBackupFile(
          bytes: _legacyFile(<String, dynamic>{'notes': <Map<String, dynamic>>[]}),
          recoverySecret: '',
        ),
      );

      expect(result.kind, BackupFileKind.legacyPlaintext);
      expect(result.rowCount, 0);
    });

    test('replaces existing data only when told to', () async {
      await _seed(source);
      final other = await _seed(target);

      // Without permission the restore is refused and changes nothing.
      await _expectRefused(
        target,
        _legacyFile(<String, dynamic>{'notes': <Map<String, dynamic>>[]}),
        BackupRestoreFailure.conflictNeedsConfirmation,
      );
      final afterRefusal = await target.backup.collectTables();
      expect(
        (afterRefusal['cases'] as List)
            .cast<Map<String, dynamic>>()
            .map((row) => row['id']),
        containsAll(<String>[other.aliveId, other.deadId]),
      );

      // With permission the target is replaced, not merged.
      final result = await target.backup.restoreSnapshot(
        backup: (await _export(source)).opened,
        ownerId: target.ownerId,
        replaceExisting: true,
      );

      expect(result.replacedExisting, isTrue);
      await _expectSameData(target, source);
      final numbers = (await target.backup.collectTables())['cases'] as List;
      expect(
        numbers.cast<Map<String, dynamic>>().map((row) => row['id']),
        isNot(contains(other.aliveId)),
      );
    });

    test('replacing into an empty database deletes nothing', () async {
      await _seed(source);

      final result = await target.backup.restoreSnapshot(
        backup: (await _export(source)).opened,
        ownerId: target.ownerId,
        replaceExisting: true,
      );

      expect(result.replacedExisting, isFalse);
      await _expectSameData(target, source);
    });
  });

  group('restore never partially imports', () {
    /// Two rows that cannot both exist: `sync_metadata` is keyed by `key`.
    Map<String, dynamic> duplicateKeyPayload() => <String, dynamic>{
      'sync_metadata': <Map<String, dynamic>>[
        <String, dynamic>{'key': 'archive.state', 'value': 'complete', 'updated_at': 1},
        <String, dynamic>{'key': 'archive.state', 'value': 'complete', 'updated_at': 2},
      ],
    };

    test('a failed insert rolls the whole import back', () async {
      await _expectRefused(
        target,
        _legacyFile(duplicateKeyPayload()),
        BackupRestoreFailure.importFailed,
      );

      expect(await target.backup.hasExistingData(), isFalse);
    });

    test('a failed replace leaves the previous data intact', () async {
      final kept = await _seed(target);
      final before = await target.backup.collectTables();

      await _expectRefused(
        target,
        _legacyFile(duplicateKeyPayload()),
        BackupRestoreFailure.importFailed,
        replaceExisting: true,
      );

      expect(await target.backup.collectTables(), before);
      expect(
        (before['cases'] as List)
            .cast<Map<String, dynamic>>()
            .map((row) => row['id']),
        contains(kept.aliveId),
      );
    });

    test('an unknown table, a bad column or a non-scalar value is refused', () async {
      final before = await target.backup.collectTables();

      await _expectRefused(
        target,
        _legacyFile(<String, dynamic>{'secret_table': <Map<String, dynamic>>[]}),
        BackupRestoreFailure.damagedFile,
      );
      await _expectRefused(
        target,
        _legacyFile(<String, dynamic>{
          'notes': <Map<String, dynamic>>[
            <String, dynamic>{'id" ) VALUES (1); DROP TABLE notes; --': 1},
          ],
        }),
        BackupRestoreFailure.damagedFile,
        replaceExisting: true,
      );
      await _expectRefused(
        target,
        _legacyFile(<String, dynamic>{
          'notes': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'n1', 'body': <String, dynamic>{'nested': true}},
          ],
        }),
        BackupRestoreFailure.damagedFile,
        replaceExisting: true,
      );
      await _expectRefused(
        target,
        _legacyFile(<String, dynamic>{
          'notes': <Map<String, dynamic>>[<String, dynamic>{}],
        }),
        BackupRestoreFailure.damagedFile,
        replaceExisting: true,
      );
      await _expectRefused(
        target,
        Uint8List.fromList(
          utf8.encode(
            BackupEnvelope.create(
              appVersion: '0.0.227',
              exportedAt: 1,
              payload: <String, dynamic>{'tables': 'not a map'},
            ).encode(),
          ),
        ),
        BackupRestoreFailure.damagedFile,
      );

      // Nothing was imported and the rejected SQL never ran: the table is intact.
      expect(await target.backup.collectTables(), before);
      expect(await target.backup.hasExistingData(), isFalse);
      final notes = await target.db.customSelect('SELECT COUNT(*) AS n FROM notes').getSingle();
      expect(notes.data['n'], 0);
    });

    test('a newer schema version is refused before any write', () async {
      await _seed(target);
      final before = await target.backup.collectTables();

      await _expectRefused(
        target,
        Uint8List.fromList(
          utf8.encode(
            BackupEnvelope.create(
              appVersion: '0.0.999',
              exportedAt: 1,
              payload: <String, dynamic>{kBackupTablesSection: <String, dynamic>{}},
              schemaVersion: kBackupSchemaVersion + 1,
            ).encode(),
          ),
        ),
        BackupRestoreFailure.unsupportedVersion,
        replaceExisting: true,
      );

      expect(await target.backup.collectTables(), before);
    });
  });

  group('restore preconditions', () {
    test('hasExistingData counts a queued write', () async {
      expect(await target.backup.hasExistingData(), isFalse);

      final ids = await target.seedReferenceData();
      await target.addCase(
        '110/2021',
        courtId: ids.courtId,
        onBehalfId: ids.onBehalfId,
      );

      expect(await target.backup.hasExistingData(), isTrue);
    });

    test('hasExistingData counts a lone tombstone', () async {
      // Retire the only note and drop the queue entry its insert produced, so
      // the database holds nothing but one soft-delete tombstone. A restore that
      // ignored tombstones would happily wipe that.
      await target.addNote('Reminder');
      await target.db.customStatement('DELETE FROM sync_queue');
      await target.db
          .update(target.db.notes)
          .write(const NotesCompanion(isDeleted: Value(true)));

      final nonEmpty = <String>[];
      for (final name in backupTableOrder) {
        final count = await target.db
            .customSelect('SELECT COUNT(*) AS n FROM "$name"')
            .getSingle();
        if ((count.data['n'] as int) > 0) nonEmpty.add(name);
      }
      expect(nonEmpty, <String>['notes']);
      final notes = (await target.backup.collectTables())['notes'] as List;
      expect(notes, hasLength(1));
      expect((notes.single as Map<String, dynamic>)['is_deleted'], 1);

      expect(await target.backup.hasExistingData(), isTrue);
    });

    test('every schema column is an importable snake_case name', () {
      // The importer interpolates column names into its INSERT statement, so it
      // only accepts names matching this pattern; this pins that the schema
      // itself never produces a name the importer would refuse to restore.
      final pattern = RegExp(r'^[a-z][a-z0-9_]*$');
      for (final table in target.db.allTables) {
        for (final column in table.$columns) {
          expect(
            pattern.hasMatch(column.name),
            isTrue,
            reason: '${table.actualTableName}.${column.name}',
          );
        }
      }
    });
  });

  group('restoring whose file it is', () {
    /// An account this device has nothing to do with.
    const String stranger = '33333333-3333-4333-8333-333333333333';

    /// One note row owned by [ownerId], in the plaintext shape an older build
    /// wrote — which is also the shape an Excel sheet is handed in as.
    Uint8List fileOwning(String ownerId) => _legacyFile(<String, dynamic>{
      'notes': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'note-1',
          'user_id': ownerId,
          'title': 'Theirs',
          'body': 'File the affidavit',
          'is_deleted': 0,
          'created_at': 1,
          'updated_at': 2,
        },
      ],
    });

    test('another account\'s file is refused and nothing is written', () async {
      // The reported failure: another account's backup restored "fine" and then
      // refused to sync, because every row on the device named somebody else.
      await _seed(source);

      await _expectRefused(
        target,
        (await _export(source)).bytes,
        BackupRestoreFailure.anotherAccount,
        ownerId: stranger,
        replaceExisting: true,
      );
      await _expectRefused(
        target,
        fileOwning(stranger),
        BackupRestoreFailure.anotherAccount,
        replaceExisting: true,
      );

      expect(await target.backup.hasExistingData(), isFalse);
    });

    test('this device may restore its own file', () async {
      await _seed(source);
      final bytes = (await _export(source)).bytes;

      // The same file, restored as the identity that wrote it.
      final result = await target.backup.restoreSnapshot(
        backup: await openBackupFile(bytes: bytes, recoverySecret: _secret),
        ownerId: source.ownerId,
      );

      expect(result.ownership, BackupOwnership.mine);
      // Nothing needed stamping: every row already named this identity.
      expect(result.stampedRows, 0);
      await _expectSameData(target, source);
    });

    test('a file that names no owner restores and is stamped', () async {
      await target.backup.restoreSnapshot(
        backup: await openBackupFile(
          bytes: _legacyFile(<String, dynamic>{
            'notes': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'note-1',
                'title': 'Typed by hand',
                'body': 'File the affidavit',
                'created_at': 1,
                'updated_at': 2,
              },
            ],
          }),
          recoverySecret: '',
        ),
        ownerId: target.ownerId,
      );

      final note = (await target.backup.collectTables())['notes'];
      final row = (note! as List).cast<Map<String, dynamic>>().single;
      // The row the user typed into the workbook is now this device's own, so
      // the next sync pushes it instead of refusing it.
      expect(row['user_id'], target.ownerId);
    });

    test('a hand-filled sample workbook names nobody and is accepted', () async {
      // The user's exact case: the downloaded template, typed into by hand. Its
      // owner cells still hold the column-name placeholders, which cannot be an
      // account id — so the file is not refused, unlike a real export.
      final ids = await target.seedReferenceData();
      final template = await target.backup.buildExcelTemplateWorkbook(
        appVersion: '0.0.266',
      );

      final opened = target.backup.openExcelBackup(template);

      expect(
        target.backup.checkRestorable(opened, ownerId: target.ownerId),
        BackupOwnership.ownerless,
      );
      // A real export of this diary, by contrast, names this device throughout:
      // the user has typed a case of their own, so the sheet carries the id the
      // app stamped it with.
      await target.addCase(
        '110/2021',
        courtId: ids.courtId,
        onBehalfId: ids.onBehalfId,
      );
      final own = target.backup.openExcelBackup(
        await target.backup.buildExcelWorkbook(
          appVersion: '0.0.266',
          exportedAt: 1,
        ),
      );
      expect(
        target.backup.checkRestorable(own, ownerId: target.ownerId),
        BackupOwnership.mine,
      );
    });

    test("a colleague's rows are accepted and keep their author", () async {
      const colleague = '22222222-2222-4222-8222-222222222222';
      const firm = '44444444-4444-4444-8444-444444444444';

      final result = await target.backup.restoreSnapshot(
        backup: await openBackupFile(
          bytes: _legacyFile(<String, dynamic>{
            'notes': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'note-1',
                'user_id': colleague,
                'firm_id': firm,
                'title': "A colleague's note",
                'body': 'File the affidavit',
                'is_deleted': 0,
                'created_at': 1,
                'updated_at': 2,
              },
            ],
          }),
          recoverySecret: '',
        ),
        ownerId: target.ownerId,
        firmId: firm,
      );

      // A firm's rows are shared, so an associate's own backup is not "somebody
      // else's file" here — and their authorship survives the import.
      expect(result.ownership, BackupOwnership.mine);
      expect(result.stampedRows, 0);
      final row =
          ((await target.backup.collectTables())['notes']! as List)
              .cast<Map<String, dynamic>>()
              .single;
      expect(row['user_id'], colleague);
      expect(row['firm_id'], firm);
    });
  });
}
