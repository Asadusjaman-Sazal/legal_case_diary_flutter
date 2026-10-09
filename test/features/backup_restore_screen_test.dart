/// Tests for the Backup & Restore screen (Task 15 Phase 4).
///
/// The screen is the only place the user touches the Task 15 engine, so these
/// tests drive the real one — a real encrypted database, the real export engine
/// and the real import transaction — and fake only the platform file dialogs.
/// They pin what the mockup's controls say, what the dialogs ask, and what the
/// status card reports after each outcome.
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/backup/backup_cipher.dart';
import 'package:legal_case_diary/core/backup/backup_format.dart';
import 'package:legal_case_diary/core/providers/backup_providers.dart';
import 'package:legal_case_diary/core/providers/print_providers.dart';
import 'package:path/path.dart' as p;
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/services/app_share_service.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/settings/data/backup_file_gateway.dart';
import 'package:legal_case_diary/features/settings/data/backup_metadata_store.dart';
import 'package:legal_case_diary/features/settings/data/backup_repository.dart';
import 'package:legal_case_diary/features/settings/presentation/backup_restore_screen.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_menu_card.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';

import '../core/backup_scheduler_test_support.dart';
import '../core/print_test_support.dart';

/// Records what the screen asked the platform dialogs to do.
class _FakeBackupGateway implements BackupFileGateway {
  /// Location reported by the "Save to…" dialog.
  String savePath = '/storage/emulated/0/Download/legal-case-diary.lcbak';

  /// File offered by the picker; null means the user cancelled.
  PickedBackupFile? picked;

  /// When true the save dialog is dismissed instead of writing.
  bool cancelSave = false;

  /// When set, the save dialog throws instead of writing.
  Object? saveError;

  /// When set, the picker throws instead of returning.
  Object? pickError;

  /// Bytes the export engine handed to the save dialog.
  Uint8List? savedBytes;

  /// Whether the fake also writes those bytes to [savePath].
  ///
  /// Off by default, because the real Android save dialog usually returns a
  /// `content://` location that is not a filesystem path — the case the share
  /// flow has to work around.
  bool writeToDisk = false;

  /// File name the export engine asked for.
  String? savedName;

  @override
  Future<String> write({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final failure = saveError;
    if (failure != null) throw failure;
    if (cancelSave) throw const BackupSaveCancelledException();
    savedName = fileName;
    savedBytes = bytes;
    // A real platform write, when the test wants a file that exists.
    if (writeToDisk) File(savePath).writeAsBytesSync(bytes, flush: true);
    return savePath;
  }

  @override
  Future<PickedBackupFile?> pick() async {
    final failure = pickError;
    if (failure != null) throw failure;
    return picked;
  }
}

/// A recorded folder sink that returns a real folder path without disk I/O.
///
/// The real [BackupFolderSink] does async disk writes, which never complete
/// under a widget test's fake clock — so tests fake the sink and read what it
/// recorded. [restoreFolder] is where a test can pre-place a file to restore.
class _FakeFolderSink implements BackupArchiveSink {
  /// The diary folder path this sink reports having written into.
  final Directory folder;

  /// File name asked for last.
  String? savedName;

  /// Bytes written last.
  Uint8List? savedBytes;

  _FakeFolderSink(this.folder);

  @override
  Future<String> write({
    required String fileName,
    required Uint8List bytes,
  }) async {
    savedName = fileName;
    savedBytes = bytes;
    // Synchronous write on purpose: a real async write never completes under
    // the widget test's fake clock, and the restore path reads this file.
    File(p.join(folder.path, fileName)).writeAsBytesSync(bytes, flush: true);
    return p.join(folder.path, fileName);
  }
}

/// A folder sink that always fails, to force the fallback to the save dialog.
class _ThrowingFolderSink implements BackupArchiveSink {
  const _ThrowingFolderSink();

  @override
  Future<String> write({
    required String fileName,
    required Uint8List bytes,
  }) async => throw const FileSystemException('folder not writable');
}

/// A plaintext envelope file with [notes] rows, as an older build wrote it.
PickedBackupFile _legacyBackup({int notes = 3, String name = 'old-backup.json'}) {
  final file = BackupEnvelope.create(
    appVersion: '0.0.227',
    exportedAt: DateTime.utc(2026, 9, 20, 5, 6, 7).millisecondsSinceEpoch,
    payload: <String, dynamic>{
      kBackupTablesSection: <String, dynamic>{
        'notes': <Map<String, dynamic>>[
          for (var i = 0; i < notes; i++)
            <String, dynamic>{
              'id': 'note-$i',
              'user_id': 'user-1',
              'title': 'Reminder $i',
              'body': 'File the affidavit',
              'is_deleted': 0,
              'created_at': 1,
              'updated_at': 2,
            },
        ],
      },
    },
  );
  return PickedBackupFile(
    name: name,
    path: null,
    bytes: Uint8List.fromList(utf8.encode(file.encode())),
  );
}

/// An encrypted container file sealed with [secret].
Future<PickedBackupFile> _encryptedBackup(String secret) async {
  final envelope = BackupEnvelope.create(
    appVersion: '0.0.229',
    exportedAt: 1700000000000,
    payload: <String, dynamic>{
      kBackupTablesSection: <String, dynamic>{'notes': <Map<String, dynamic>>[]},
    },
  );
  final container = await encryptBackup(
    plaintext: utf8.encode(envelope.encode()),
    recoverySecret: secret,
    appVersion: '0.0.229',
    createdAt: 1700000000000,
    iterations: 1000,
  );
  return PickedBackupFile(
    name: 'legal-case-diary-backup.lcbak',
    path: null,
    bytes: Uint8List.fromList(utf8.encode(container.encode())),
  );
}

/// Points `path_provider` at [directory].
///
/// The share flow asks it for the app's temporary directory, and no plugin
/// answers on a test host, so the channel is mocked with a real folder.
void _mockTemporaryDirectory(Directory directory) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => directory.path,
      );
}

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late _FakeBackupGateway gateway;
  late RecordingShareService shareService;
  late FakeBackupScheduler backupScheduler;
  late Directory tempDir;
  late Directory folder;

  setUpAll(() {
    // One in-memory database per test is the point here.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    gateway = _FakeBackupGateway();
    shareService = RecordingShareService();
    backupScheduler = FakeBackupScheduler();
    // The share flow keeps its courier copy through `path_provider`; every
    // test gets a real directory that is removed again afterwards.
    tempDir = Directory.systemTemp.createTempSync('lcb_backup_screen');
    addTearDown(() {
      try {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows can still hold a handle for a moment; the OS clears its own
        // temp directory, so a locked leftover is not worth failing a test for.
      }
    });
    // The diary folder a backup is written into and restored from.
    folder = tempDir.createTempSync('lcb_folder');
    addTearDown(() {
      try {
        if (folder.existsSync()) folder.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows can still hold a handle for a moment; the OS clears its own
        // temp directory, so a locked leftover is not worth failing a test for.
      }
    });
    _mockTemporaryDirectory(tempDir);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    BackupArchiveSink? folderSink,
  }) async {
    folderSink ??= _FakeFolderSink(folder);
    // Tall viewport: the whole mockup body is on one screen and every section
    // under test is built (an off-screen widget would fail for the wrong reason).
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          backupFileGatewayProvider.overrideWithValue(gateway),
          backupFolderDirectoryProvider.overrideWithValue(() async => folder),
          backupFolderSinkProvider.overrideWithValue(folderSink),
          backupSchedulerProvider.overrideWithValue(backupScheduler),
          appShareServiceProvider.overrideWithValue(shareService),
          // Everything else about the export stays real; only the key
          // derivation is cheap, because its default stretch pauses between
          // batches and the fake clock here never advances those pauses.
          backupKdfIterationsProvider.overrideWithValue(1000),
          // The screen re-opens the database after a restore; the override
          // keeps that reload pointing at this test's in-memory instance.
          databaseProvider.overrideWith((ref) async => db),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const BackupRestoreScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// A row in a portable table, so the database counts as holding data.
  Future<void> seedLocalRow() => db.customInsert(
    'INSERT INTO sync_metadata ("key", "value", "updated_at") '
    "VALUES ('archive.state', 'complete', 1)",
  );

  /// Opens one collapsible section, which closes whichever was open.
  Future<void> openSection(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(ValueKey('backup-section-toggle-$id')));
    await tester.pumpAndSettle();
  }

  /// Taps an action button by its mockup label.
  ///
  /// Every action lives in the Backup & Restore section, which starts closed, so
  /// this opens it if it is not already showing — the same tap the user makes
  /// before pressing one. A test that taps two actions in a row leaves the
  /// section open between them, so the open is conditional rather than a toggle.
  Future<void> tapAction(WidgetTester tester, String label) async {
    if (find.text(label).evaluate().isEmpty) {
      await openSection(tester, 'backup');
    }
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  /// A note row, so the database holds data in a table the Excel workbook
  /// carries — which is the scope a workbook restore measures.
  Future<void> seedNote() => db.customInsert(
    'INSERT INTO notes ("id", "user_id", "title", "body", "created_at", '
    '"updated_at") VALUES ('
    "'existing-note', 'user-1', 'Existing', 'Body', 1, 2)",
  );

  /// Writes [file]'s bytes into the diary folder under its own name.
  ///
  /// This stands in for the platform having saved a backup there. The name must
  /// match the app's default backup file shape so the folder scan accepts it.
  /// Synchronous on purpose: a widget test's fake clock never completes an
  /// async disk write.
  Future<void> placeInFolder(PickedBackupFile file) async {
    File(p.join(folder.path, file.name)).writeAsBytesSync(file.bytes);
  }

  //// Bytes of the single backup the diary folder now holds, if any.
  Uint8List? folderBackupBytes() {
    final files = folder
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.lcbak'))
        .toList();
    if (files.isEmpty) return null;
    return files.single.readAsBytesSync();
  }

  /// The absolute path the Local backup wrote (the folder's `.lcbak` file).
  String? folderSavePath() {
    final files = folder
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.lcbak'))
        .toList();
    return files.isEmpty ? null : files.single.path;
  }

  /// Bytes of the single workbook the diary folder now holds, if any.
  Uint8List? folderExcelBytes() {
    final files = folder
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.xlsx'))
        .toList();
    if (files.isEmpty) return null;
    return files.single.readAsBytesSync();
  }

  /// The absolute path the Excel backup wrote (the folder's `.xlsx` file).
  String? folderExcelPath() {
    final files = folder
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.xlsx'))
        .toList();
    return files.isEmpty ? null : files.single.path;
  }


  /// Turns passphrase encryption on in the stored preferences, exactly as the
  /// Encryption On Backup section's Enable button does.
  Future<void> enableEncryption() =>
      prefs.setBool(backupEncryptionEnabledKey, true);

  /// A workbook file, written by the real export engine for [db]'s contents.
  Future<PickedBackupFile> excelBackup({String name = 'Backup_20-09-26_11-06-07am.xlsx'}) async {
    final bytes = await BackupRepository(db).buildExcelWorkbook(
      appVersion: '0.0.262',
      exportedAt: DateTime.utc(2026, 9, 20, 5, 6, 7).millisecondsSinceEpoch,
    );
    return PickedBackupFile(name: name, path: null, bytes: bytes);
  }

  /// The workbook's parts, keyed by part path.
  Map<String, String> workbookParts(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    return <String, String>{
      for (final file in archive.files)
        if (file.isFile) file.name: utf8.decode(file.readBytes()!),
    };
  }

  /// Rewrites one string inside one workbook part and re-zips it.
  Uint8List breakWorkbook(Uint8List bytes, String part, String from, String to) {
    final parts = workbookParts(bytes);
    parts[part] = parts[part]!.replaceFirst(from, to);
    final archive = Archive();
    for (final entry in parts.entries) {
      final encoded = utf8.encode(entry.value);
      archive.add(ArchiveFile(entry.key, encoded.length, encoded));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// Fills a passphrase dialog and confirms it.
  Future<void> enterPassphrase(
    WidgetTester tester, {
    required String passphrase,
    String? confirmation,
    required String confirmLabel,
  }) async {
    await tester.enterText(find.byType(TextFormField).first, passphrase);
    if (confirmation != null) {
      await tester.enterText(find.byType(TextFormField).at(1), confirmation);
    }
    await tester.tap(find.text(confirmLabel));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the mockup sections with no backup yet', (tester) async {
    await pumpScreen(tester);

    // The screen title and the section label both read the same words.
    expect(find.text('Backup & Restore'), findsWidgets);
    // Every section heading is on screen whatever is open...
    expect(find.text('Encryption On Backup'), findsOneWidget);
    expect(find.text('Automatic Backup'), findsOneWidget);
    expect(find.text('Excel Backup Format'), findsOneWidget);
    expect(find.text('Backup Status'), findsOneWidget);

    // ...and every section starts closed, so none of the options are showing
    // until the user taps a heading.
    expect(find.text('Backup to Local Storage'), findsNothing);
    expect(find.text('Backup as Excel File'), findsNothing);
    expect(find.text('Backup to Google Drive'), findsNothing);
    expect(find.text('Restore from Backup'), findsNothing);
    // Each collapsible heading is the app's standard sub-menu button — the very
    // control the Account & Profile menu uses — with an expand chevron.
    expect(find.byType(SettingsMenuCard), findsNWidgets(4));

    // Nothing inside any section is built while they are closed.
    expect(find.text('Everyday'), findsNothing);

    // Backup Status is not a button: it keeps the mockup's plain heading and is
    // always open, so there is nothing here to tap.
    expect(
      find.byKey(const ValueKey('backup-section-toggle-status')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('backup-section-chevron-status')),
      findsNothing,
    );
    expect(find.text('Last Successful Backup'), findsOneWidget);
    expect(find.text('No backup has been made yet.'), findsOneWidget);
    expect(find.byKey(const ValueKey('backup-status-path')), findsNothing);
  });

  testWidgets('only one section is open at a time', (tester) async {
    await pumpScreen(tester);

    // Every section starts closed, so its chevron points down...
    expect(
      tester
          .widget<Icon>(
            find.byKey(const ValueKey('backup-section-chevron-backup')),
          )
          .icon,
      Icons.expand_more,
    );

    // ...and opening the first reveals its four actions, in the mockup's order
    // with the Excel backup directly after the local one, chevron turned up.
    await openSection(tester, 'backup');
    expect(find.text('Backup to Local Storage'), findsOneWidget);
    expect(
      tester
          .widget<Icon>(
            find.byKey(const ValueKey('backup-section-chevron-backup')),
          )
          .icon,
      Icons.expand_less,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('backup-excel'))).dy,
      greaterThan(
        tester.getTopLeft(find.byKey(const ValueKey('backup-local'))).dy,
      ),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('backup-excel'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('backup-drive'))).dy,
      ),
    );

    // Opening the schedule closes the section that was open: the user never has
    // two sets of options on screen at once.
    await openSection(tester, 'automatic');
    expect(find.text('Everyday'), findsOneWidget);
    expect(find.text('Backup to Local Storage'), findsNothing);
    expect(
      tester
          .widget<Icon>(
            find.byKey(const ValueKey('backup-section-chevron-backup')),
          )
          .icon,
      Icons.expand_more,
    );

    // And opening a third closes the second.
    await openSection(tester, 'excel');
    expect(find.text('Everyday'), findsNothing);
    expect(find.byKey(const ValueKey('backup-excel-template')), findsOneWidget);

    // Tapping the open heading shuts it, leaving every section closed.
    await openSection(tester, 'excel');
    expect(find.byKey(const ValueKey('backup-excel-template')), findsNothing);
  });

  testWidgets('the Excel format section states the format and offers a sample', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openSection(tester, 'excel');

    // The four sheet names the reader matches on, exactly as it spells them.
    expect(find.textContaining('Cases, Case History, Notes and Case References'), findsOneWidget);
    expect(find.textContaining('Keep the sheet names'), findsOneWidget);
    expect(find.textContaining('row\'s id blank'), findsOneWidget);
    // And the honest limit of the format.
    expect(find.textContaining('not a complete backup'), findsOneWidget);
    // The sample's extra reference sheets are explained where it is downloaded.
    expect(find.textContaining('plus a Guide sheet'), findsOneWidget);
  });

  testWidgets('the Excel note says the workbook is not encrypted', (
    tester,
  ) async {
    await pumpScreen(tester);
    // The note sits under the action card, inside the section that starts closed.
    await openSection(tester, 'backup');
    expect(find.textContaining('is not encrypted'), findsOneWidget);
  });

  testWidgets('the Excel backup writes a workbook and records it', (
    tester,
  ) async {
    await seedNote();
    await pumpScreen(tester);

    await tapAction(tester, 'Backup as Excel File');

    // No passphrase is asked for: a spreadsheet cannot be sealed.
    expect(find.text('Protect this backup'), findsNothing);
    final bytes = folderExcelBytes();
    expect(bytes, isNotNull);
    // The file really is our workbook, built from what the diary holds.
    final parts = workbookParts(bytes!);
    expect(parts.keys, contains('xl/worksheets/sheet2.xml'));
    expect(parts['xl/workbook.xml'], contains('name="Cases"'));

    expect(prefs.getString(lastBackupPathKey), folderExcelPath());
    expect(find.textContaining('Excel file saved to'), findsOneWidget);
  });

  testWidgets('the template button saves a workbook of headers', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openSection(tester, 'excel');

    await tester.tap(find.byKey(const ValueKey('backup-excel-template')));
    await tester.pumpAndSettle();

    expect(gateway.savedName, 'legal-case-diary-template.xlsx');
    final parts = workbookParts(gateway.savedBytes!);
    // The sample carries the same headers the reader validates, so it can never
    // show the user a column the app would refuse.
    final cases = parts['xl/worksheets/sheet2.xml']!;
    expect(cases, contains('<t xml:space="preserve">case_number</t>'));
    // And it carries the reference sheets and the Guide the user reads, in
    // addition to the four data sheets a backup has.
    expect(parts['xl/workbook.xml'], contains('name="Courts"'));
    expect(parts['xl/workbook.xml'], contains('name="Case Types"'));
    expect(parts['xl/workbook.xml'], contains('name="Steps"'));
    expect(parts['xl/workbook.xml'], contains('name="On Behalfs"'));
    expect(parts['xl/workbook.xml'], contains('name="Guide"'));
    expect(find.textContaining('Template saved to'), findsOneWidget);
  });

  testWidgets('restoring a workbook skips the passphrase and asks about its sheets', (
    tester,
  ) async {
    await seedNote();
    // Data outside the workbook's four tables, which a workbook restore must
    // leave alone.
    await db.customInsert(
      'INSERT INTO sync_metadata ("key", "value", "updated_at") '
      "VALUES ('outside.scope', 'kept', 1)",
    );
    await placeInFolder(await excelBackup());
    await pumpScreen(tester);

    await tapAction(tester, 'Restore from Backup');

    // A workbook carries no passphrase, and the window says which sheets go.
    expect(find.text('Open this backup'), findsNothing);
    expect(find.text('Replace the data in these sheets?'), findsOneWidget);
    expect(
      find.text('Cases, Case History, Notes, Case References'),
      findsOneWidget,
    );

    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // The note the workbook carried is what the diary holds now...
    final notes = await db
        .customSelect('SELECT COUNT(*) AS n FROM notes')
        .getSingle();
    expect(notes.data['n'], 1);
    // ...and everything outside the four sheets survived untouched, which is the
    // whole point of scoping the replace to the file's own tables.
    final kept = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM sync_metadata '
          "WHERE \"key\" = 'outside.scope'",
        )
        .getSingle();
    expect(kept.data['n'], 1);
  });

  testWidgets('a workbook that is off-format names the sheet and the column', (
    tester,
  ) async {
    await seedNote();
    await placeInFolder(
      PickedBackupFile(
        name: 'Backup_20-09-26_11-06-07am.xlsx',
        path: null,
        // One column renamed, as a user tidying the headers might do.
        bytes: breakWorkbook(
          (await excelBackup()).bytes,
          'xl/worksheets/sheet2.xml',
          '<t xml:space="preserve">case_number</t>',
          '<t xml:space="preserve">case_no</t>',
        ),
      ),
    );
    await pumpScreen(tester);

    await tapAction(tester, 'Restore from Backup');

    expect(find.text('Open this backup'), findsNothing);
    // The message points at the sheet and the exact header to restore.
    expect(
      find.text(
        'The Cases sheet has a column this format does not define: case_no',
      ),
      findsOneWidget,
    );
    // And nothing was replaced on the way to finding out.
    expect(find.text('Replace the data in these sheets?'), findsNothing);
    final notes = await db
        .customSelect('SELECT COUNT(*) AS n FROM notes')
        .getSingle();
    expect(notes.data['n'], 1);
  });

  testWidgets('shows the stored backup date and location on open', (
    tester,
  ) async {
    await prefs.setInt(
      lastSuccessfulBackupAtKey,
      DateTime.utc(2026, 9, 20, 5, 6, 7).millisecondsSinceEpoch,
    );
    await prefs.setString(lastBackupPathKey, '/storage/backup.lcbak');

    await pumpScreen(tester);

    // 05:06 UTC is 11:06 in Bangladesh, the timezone every date on the app uses.
    expect(find.text('20/09/26, 11:06 AM'), findsOneWidget);
    expect(find.text('/storage/backup.lcbak'), findsOneWidget);
  });

  testWidgets('the schedule choice is stored and re-arms the alarm', (
    tester,
  ) async {
    await pumpScreen(tester);

    await openSection(tester, 'automatic');
    await tester.tap(find.text('Every 7 days'));
    await tester.pumpAndSettle();

    // The choice is stored, and the scheduler is asked to (re-)arm for it —
    // otherwise the setting would be saved but never acted on.
    expect(prefs.getInt(backupScheduleDaysKey), 7);
    expect(backupScheduler.syncScheduleCalls, 1);
  });

  testWidgets('the Encryption On Backup section explains and switches the setting', (
    tester,
  ) async {
    await pumpScreen(tester);

    // The setting is off to begin with, and the copy names both sides of the
    // trade-off: what the passphrase protects, and the cost of forgetting it.
    await openSection(tester, 'encryption');
    // Paragraph copy reads in sentence case; only headings and labels are
    // Title Case.
    expect(find.text('Encryption is currently off'), findsOneWidget);
    expect(
      find.textContaining('anyone who gets it cannot read your case data'),
      findsOneWidget,
    );
    expect(
      find.textContaining('If you forget it, that backup can never be restored'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('backup-encryption-enable')), findsOneWidget);
    expect(find.byKey(const ValueKey('backup-encryption-disable')), findsOneWidget);

    // Enable stores it; Disable puts it back.
    await tester.tap(find.byKey(const ValueKey('backup-encryption-enable')));
    await tester.pumpAndSettle();
    expect(prefs.getBool(backupEncryptionEnabledKey), isTrue);
    expect(find.text('Encryption is currently on'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('backup-encryption-disable')));
    await tester.pumpAndSettle();
    expect(prefs.getBool(backupEncryptionEnabledKey), isFalse);
    expect(find.text('Encryption is currently off'), findsOneWidget);
  });

  testWidgets('with encryption off a backup is written unencrypted, asking nothing', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tapAction(tester, 'Backup to Local Storage');

    // No passphrase window: encryption is off by default.
    expect(find.text('Protect this backup'), findsNothing);
    final bytes = folderBackupBytes();
    expect(bytes, isNotNull);
    // The file is the readable envelope, not the sealed container.
    final decoded = jsonDecode(utf8.decode(bytes!)) as Map<String, dynamic>;
    expect(decoded['format'], isNot(kEncryptedBackupFormat));
    expect(decoded, contains('schema_version'));
    expect(
      (decoded['payload'] as Map<String, dynamic>),
      contains(kBackupTablesSection),
    );
    // And it is recorded exactly like an encrypted one, at the folder path.
    expect(prefs.getString(lastBackupPathKey), folderSavePath());
    expect(find.textContaining('Backup saved to'), findsOneWidget);
  });

  testWidgets('backup asks for the passphrase twice, then saves the file', (
    tester,
  ) async {
    await enableEncryption();
    await pumpScreen(tester);

    await tapAction(tester, 'Backup to Local Storage');

    // The window explains that the passphrase is the only way back in.
    expect(find.text('Protect this backup'), findsOneWidget);
    expect(
      find.text(
        'The backup is encrypted with this passphrase. It is not stored '
        'anywhere, so without it the file can never be restored.',
      ),
      findsOneWidget,
    );
    expect(find.byType(TextFormField), findsNWidgets(2));

    // A typo in the confirmation field is caught before anything is written.
    await enterPassphrase(
      tester,
      passphrase: 'correct horse',
      confirmation: 'correct hors',
      confirmLabel: 'Encrypt and save',
    );
    expect(find.text('The two passphrases do not match.'), findsOneWidget);
    expect(gateway.savedBytes, isNull);

    await enterPassphrase(
      tester,
      passphrase: 'correct horse',
      confirmation: 'correct horse',
      confirmLabel: 'Encrypt and save',
    );

    // The file written into the diary folder is the encrypted container, and
    // it really opens with the passphrase the user chose.
    final bytes = folderBackupBytes();
    expect(bytes, isNotNull);
    final container = EncryptedBackup.decode(utf8.decode(bytes!));
    expect(container.format, kEncryptedBackupFormat);
    final plaintext = await decryptBackup(
      container,
      recoverySecret: 'correct horse',
    );
    final envelope = BackupEnvelope.decode(utf8.decode(plaintext));
    expect(envelope.tables.keys, contains('cases'));

    // The user is told where it went, and the status card records it.
    final saved = folderSavePath()!;
    expect(
      find.text('Backup saved to $saved'),
      findsOneWidget,
    );
    expect(prefs.getString(lastBackupPathKey), saved);
    expect(prefs.getInt(lastSuccessfulBackupAtKey), envelope.exportedAt);
    expect(find.text(saved), findsOneWidget);
  });

  testWidgets('a cancelled passphrase dialog exports nothing', (tester) async {
    await enableEncryption();
    await pumpScreen(tester);

    await tapAction(tester, 'Backup to Local Storage');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(gateway.savedBytes, isNull);
    expect(prefs.getInt(lastSuccessfulBackupAtKey), isNull);
    expect(find.text('No backup has been made yet.'), findsOneWidget);
  });

  testWidgets('fallback save dialog dismissed records nothing', (tester) async {
    await enableEncryption();
    gateway.cancelSave = true;
    await pumpScreen(
      tester,
      folderSink: const _ThrowingFolderSink(),
    );

    await tapAction(tester, 'Backup to Local Storage');
    await enterPassphrase(
      tester,
      passphrase: 'correct horse',
      confirmation: 'correct horse',
      confirmLabel: 'Encrypt and save',
    );

    // The folder failed, the fallback save dialog was dismissed: nothing was
    // written, and the archive is only recorded when the file really exists.
    expect(find.textContaining('Backup saved to'), findsNothing);
    expect(prefs.getInt(lastSuccessfulBackupAtKey), isNull);
    expect(find.text('No backup has been made yet.'), findsOneWidget);
  });

  testWidgets('a failed export is reported and records nothing', (
    tester,
  ) async {
    await enableEncryption();
    gateway.saveError = StateError('disk full');
    await pumpScreen(
      tester,
      folderSink: const _ThrowingFolderSink(),
    );

    await tapAction(tester, 'Backup to Local Storage');
    await enterPassphrase(
      tester,
      passphrase: 'correct horse',
      confirmation: 'correct horse',
      confirmLabel: 'Encrypt and save',
    );

    expect(find.text('Could not create the backup.'), findsOneWidget);
    expect(prefs.getInt(lastSuccessfulBackupAtKey), isNull);
  });

  testWidgets('restoring into an empty database does not ask to replace', (
    tester,
  ) async {
    gateway.picked = _legacyBackup();
    await pumpScreen(tester);

    await tapAction(tester, 'Restore from Backup');
    // A plaintext file opens without a passphrase window.
    expect(find.text('Open this backup'), findsNothing);

    expect(find.text('Replace all current data?'), findsNothing);
    expect(find.text('Restore complete'), findsOneWidget);
    expect(find.text('3 records restored.'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final notes = await db.customSelect('SELECT COUNT(*) AS n FROM notes').getSingle();
    expect(notes.data['n'], 3);
  });

  testWidgets('restoring over existing data asks first and can be cancelled', (
    tester,
  ) async {
    // Existing data in a table the file itself carries: that is what a scoped
    // restore has to ask about before it replaces anything. The row in
    // `sync_metadata` stands for data the file does not carry.
    await seedNote();
    await seedLocalRow();
    gateway.picked = _legacyBackup(notes: 1);
    await pumpScreen(tester);

    await tapAction(tester, 'Restore from Backup');

    // The window shows what the file holds before anything is replaced.
    expect(find.text('Replace all current data?'), findsOneWidget);
    expect(find.text('old-backup.json'), findsOneWidget);
    expect(find.text('20/09/26, 11:06 AM'), findsOneWidget);
    expect(find.text('0.0.227'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(
      find.text(
        'Everything currently on this device will be replaced. '
        'This cannot be undone.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Restore complete'), findsNothing);
    final untouched = await db
        .customSelect('SELECT COUNT(*) AS n FROM notes')
        .getSingle();
    expect(untouched.data['n'], 1);

    // Choosing Replace does the restore and reports it.
    await tapAction(tester, 'Restore from Backup');
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final restored = await db
        .customSelect('SELECT COUNT(*) AS n FROM notes')
        .getSingle();
    final outsideScope = await db
        .customSelect('SELECT COUNT(*) AS n FROM sync_metadata')
        .getSingle();
    expect(restored.data['n'], 1);
    // The file carries only `notes`, so that is all the replace touches: the
    // `sync_metadata` row survives, where the pre-scoping engine wiped every
    // portable table whatever the file held.
    expect(outsideScope.data['n'], 1);
  });

  testWidgets('a wrong passphrase is reported and changes nothing', (
    tester,
  ) async {
    await seedLocalRow();
    gateway.picked = await _encryptedBackup('the real passphrase');
    await pumpScreen(tester);

    await tapAction(tester, 'Restore from Backup');
    await enterPassphrase(
      tester,
      passphrase: 'not the passphrase',
      confirmLabel: 'Open backup',
    );

    expect(
      find.text('Wrong passphrase, or the backup file has been changed.'),
      findsOneWidget,
    );
    expect(find.text('Replace all current data?'), findsNothing);
    final rows = await db
        .customSelect('SELECT COUNT(*) AS n FROM sync_metadata')
        .getSingle();
    expect(rows.data['n'], 1);
  });

  testWidgets('a file that is not a backup is reported', (tester) async {
    gateway.picked = PickedBackupFile(
      name: 'holiday.jpg',
      path: null,
      bytes: Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0x00]),
    );
    await pumpScreen(tester);

    await tapAction(tester, 'Restore from Backup');

    expect(
      find.text('That file is not a backup made by this app.'),
      findsOneWidget,
    );
  });

  testWidgets('a picker that refuses to open is reported', (tester) async {
    gateway.pickError = StateError('no content provider');
    await pumpScreen(tester);

    await tapAction(tester, 'Restore from Backup');

    expect(find.text('Could not open that file.'), findsOneWidget);
    expect(find.text('Open this backup'), findsNothing);
  });

  testWidgets('the Drive action makes a folder backup, then offers to send it', (
    tester,
  ) async {
    await enableEncryption();
    await pumpScreen(tester);

    // It asks for the passphrase exactly like the local action, because it is
    // the same backup — the app never uploads anything itself.
    await tapAction(tester, 'Backup to Google Drive');
    expect(find.text('Protect this backup'), findsOneWidget);
    await enterPassphrase(
      tester,
      passphrase: 'correct horse',
      confirmation: 'correct horse',
      confirmLabel: 'Encrypt and save',
    );

    // The file is written into the diary folder and recorded before any
    // sharing is offered, and it is the encrypted container, not plaintext.
    final bytes = folderBackupBytes();
    expect(bytes, isNotNull);
    expect(
      EncryptedBackup.decode(utf8.decode(bytes!)).format,
      kEncryptedBackupFormat,
    );
    expect(prefs.getString(lastBackupPathKey), folderSavePath());
    expect(prefs.getInt(lastSuccessfulBackupAtKey), isNotNull);

    // The offer window names the file that was just saved, and nothing has been
    // shared yet.
    expect(find.text('Send to Google Drive?'), findsOneWidget);
    expect(find.textContaining('Your backup is saved.'), findsOneWidget);
    expect(find.text(folderSavePath()!), findsWidgets);
    expect(shareService.files, isEmpty);

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    // The sheet attaches the very file the backup was saved as — a real path in
    // the public folder, so no copy is needed.
    final shared = shareService.files.single;
    expect(shared.subject, 'Legal Case Diary backup');
    expect(shared.path, folderSavePath());
  });

  testWidgets('declining the Drive offer keeps the backup and shares nothing', (
    tester,
  ) async {
    await enableEncryption();
    await pumpScreen(tester);

    await tapAction(tester, 'Backup to Google Drive');
    await enterPassphrase(
      tester,
      passphrase: 'correct horse',
      confirmation: 'correct horse',
      confirmLabel: 'Encrypt and save',
    );
    expect(find.text('Send to Google Drive?'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    // Declining the sheet is not a failed backup: the file and its record stay.
    expect(shareService.files, isEmpty);
    expect(prefs.getString(lastBackupPathKey), folderSavePath());
    expect(find.text('No backup has been made yet.'), findsNothing);
  });

  testWidgets('a cancelled passphrase window writes and shares nothing', (
    tester,
  ) async {
    await enableEncryption();
    await pumpScreen(tester);

    await tapAction(tester, 'Backup to Google Drive');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(folderBackupBytes(), isNull);
    expect(find.text('Send to Google Drive?'), findsNothing);
    expect(shareService.files, isEmpty);
  });

  testWidgets('a share sheet that cannot open is reported', (tester) async {
    await enableEncryption();
    shareService.outcome = AppShareOutcome.failed;
    await pumpScreen(tester);

    await tapAction(tester, 'Backup to Google Drive');
    await enterPassphrase(
      tester,
      passphrase: 'correct horse',
      confirmation: 'correct horse',
      confirmLabel: 'Encrypt and save',
    );
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Could not open the share sheet.'), findsOneWidget);
    // The backup itself is unaffected by a share that never happened.
    expect(prefs.getString(lastBackupPathKey), folderSavePath());
  });

  testWidgets('a folder that cannot be written falls back to the save dialog', (
    tester,
  ) async {
    await enableEncryption();
    gateway.cancelSave = true;
    await pumpScreen(
      tester,
      folderSink: const _ThrowingFolderSink(),
    );

    await tapAction(tester, 'Backup to Google Drive');
    await enterPassphrase(
      tester,
      passphrase: 'correct horse',
      confirmation: 'correct horse',
      confirmLabel: 'Encrypt and save',
    );

    // The folder failed, so the fallback save dialog was dismissed: nothing
    // written, no share offer.
    expect(find.text('Send to Google Drive?'), findsNothing);
    expect(shareService.files, isEmpty);
    expect(prefs.getInt(lastSuccessfulBackupAtKey), isNull);
  });

  testWidgets('a single backup in the folder restores directly, no picker', (
    tester,
  ) async {
    await placeInFolder(_legacyBackup(name: 'Backup_01-02-26_09-30-15am.lcbak'));
    gateway.picked = null; // The picker must never be asked.
    await pumpScreen(tester);

    await tapAction(tester, 'Restore from Backup');

    // No choice popup and no platform picker: the folder's only file restores.
    expect(
      find.text('Choose the backup to restore'),
      findsNothing,
    );
    expect(find.text('Open this backup'), findsNothing);
    expect(find.text('Restore complete'), findsOneWidget);
    expect(find.text('3 records restored.'), findsOneWidget);
  });

  testWidgets('with several backups the folder lists them in a choice popup', (
    tester,
  ) async {
    await placeInFolder(
      _legacyBackup(name: 'Backup_01-02-26_09-30-15am.lcbak', notes: 2),
    );
    await placeInFolder(
      _legacyBackup(name: 'Backup_02-02-26_09-30-15pm.lcbak', notes: 3),
    );
    gateway.picked = null;
    await pumpScreen(tester);

    await tapAction(tester, 'Restore from Backup');

    // Both files are listed in the popup, and the popup is the rounder-corner
    // dialog the user asked for, replacing the platform picker.
    expect(
      find.text('Choose the backup to restore'),
      findsOneWidget,
    );
    expect(find.text('Backup_01-02-26_09-30-15am.lcbak'), findsOneWidget);
    expect(find.text('Backup_02-02-26_09-30-15pm.lcbak'), findsOneWidget);

    // The popup uses a slightly rounder corner than the app's default dialog.
    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    final shape = dialog.shape! as RoundedRectangleBorder;
    expect(
      (shape.borderRadius as BorderRadius).topLeft.x,
      greaterThan(8.0),
    );

    await tester.tap(find.text('Backup_02-02-26_09-30-15pm.lcbak'));
    await tester.pumpAndSettle();

    // The chosen file's data is what gets restored.
    expect(find.text('Restore complete'), findsOneWidget);
    expect(find.text('3 records restored.'), findsOneWidget);
  });

  testWidgets('an empty or missing folder falls back to the platform picker', (
    tester,
  ) async {
    // No files placed in the folder → the picker is used, exactly the fallback
    // the user asked to keep.
    gateway.picked = _legacyBackup(name: 'old-backup.json');
    await pumpScreen(tester);

    await tapAction(tester, 'Restore from Backup');

    // The legacy named file (not a `Backup_...` stem) is unreachable via the
    // folder scan, so the picker returns it.
    expect(find.text('Restore complete'), findsOneWidget);
    expect(find.text('3 records restored.'), findsOneWidget);
  });

  test('only the file gateway imports the platform picker', () {
    // The plugin is a platform channel that only answers on a device, so the
    // rule is read from the sources: everything else goes through the gateway.
    const folder = 'lib/features/settings/';
    final offenders = <String>[];
    for (final entity in Directory(folder).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('backup_file_gateway.dart')) continue;
      if (entity.readAsStringSync().contains('package:file_picker')) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty);
  });

  test('the backup flow stays offline (Part A)', () {
    const forbidden = <String>[
      'supabase_flutter',
      'package:http/',
      'package:dio',
      'web_socket_channel',
    ];
    for (final path in <String>[
      'lib/features/settings/presentation/backup_restore_screen.dart',
      'lib/features/settings/presentation/backup_dialogs.dart',
      'lib/features/settings/data/backup_repository.dart',
      'lib/features/settings/data/backup_file_gateway.dart',
      'lib/features/settings/data/backup_metadata_store.dart',
    ]) {
      final source = File(path).readAsStringSync();
      for (final package in forbidden) {
        expect(
          source.contains(package),
          isFalse,
          reason: '$path must stay offline — the whole backup path is local.',
        );
      }
    }
  });
}
