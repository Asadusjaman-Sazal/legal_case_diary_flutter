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
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/backup/backup_cipher.dart';
import 'package:legal_case_diary/core/backup/backup_format.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/settings/data/backup_file_gateway.dart';
import 'package:legal_case_diary/features/settings/data/backup_metadata_store.dart';
import 'package:legal_case_diary/features/settings/presentation/backup_restore_screen.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';

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
    return savePath;
  }

  @override
  Future<PickedBackupFile?> pick() async {
    final failure = pickError;
    if (failure != null) throw failure;
    return picked;
  }
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

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late _FakeBackupGateway gateway;

  setUpAll(() {
    // One in-memory database per test is the point here.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    gateway = _FakeBackupGateway();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
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

  /// Taps an action button by its mockup label.
  Future<void> tapAction(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
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

    expect(find.text('Backup & Restore'), findsWidgets);
    expect(find.text('BACKUP & RESTORE'), findsOneWidget);
    expect(find.text('Backup to Local Storage'), findsOneWidget);
    expect(find.text('Backup to Google Drive'), findsOneWidget);
    expect(find.text('Restore from backup'), findsOneWidget);
    expect(find.text('AUTOMATIC BACKUP'), findsOneWidget);
    expect(find.text('Everyday'), findsOneWidget);
    expect(find.text('BACKUP STATUS'), findsOneWidget);
    expect(find.text('Last successful backup'), findsOneWidget);
    // The status card is honest until a backup exists.
    expect(find.text('No backup has been made yet.'), findsOneWidget);
    expect(find.byKey(const ValueKey('backup-status-path')), findsNothing);
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

  testWidgets('the schedule choice is stored', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Every 7 days'));
    await tester.pumpAndSettle();

    expect(prefs.getInt(backupScheduleDaysKey), 7);
  });

  testWidgets('backup asks for the passphrase twice, then saves the file', (
    tester,
  ) async {
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

    // The file written through the save dialog is the encrypted container, and
    // it really opens with the passphrase the user chose.
    final bytes = gateway.savedBytes;
    expect(bytes, isNotNull);
    expect(gateway.savedName, endsWith('.lcbak'));
    final container = EncryptedBackup.decode(utf8.decode(bytes!));
    expect(container.format, kEncryptedBackupFormat);
    final plaintext = await decryptBackup(
      container,
      recoverySecret: 'correct horse',
    );
    final envelope = BackupEnvelope.decode(utf8.decode(plaintext));
    expect(envelope.tables.keys, contains('cases'));

    // The user is told where it went, and the status card records it.
    expect(
      find.text('Backup saved to /storage/emulated/0/Download/legal-case-diary.lcbak'),
      findsOneWidget,
    );
    expect(
      prefs.getString(lastBackupPathKey),
      '/storage/emulated/0/Download/legal-case-diary.lcbak',
    );
    expect(prefs.getInt(lastSuccessfulBackupAtKey), envelope.exportedAt);
    expect(find.text('/storage/emulated/0/Download/legal-case-diary.lcbak'), findsOneWidget);
  });

  testWidgets('a cancelled passphrase dialog exports nothing', (tester) async {
    await pumpScreen(tester);

    await tapAction(tester, 'Backup to Local Storage');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(gateway.savedBytes, isNull);
    expect(prefs.getInt(lastSuccessfulBackupAtKey), isNull);
    expect(find.text('No backup has been made yet.'), findsOneWidget);
  });

  testWidgets('a dismissed save dialog records nothing', (tester) async {
    gateway.cancelSave = true;
    await pumpScreen(tester);

    await tapAction(tester, 'Backup to Local Storage');
    await enterPassphrase(
      tester,
      passphrase: 'correct horse',
      confirmation: 'correct horse',
      confirmLabel: 'Encrypt and save',
    );

    // No success message, and the status card still says no backup was made —
    // the archive is only recorded after the file really exists.
    expect(find.textContaining('Backup saved to'), findsNothing);
    expect(prefs.getInt(lastSuccessfulBackupAtKey), isNull);
    expect(find.text('No backup has been made yet.'), findsOneWidget);
  });

  testWidgets('a failed export is reported and records nothing', (
    tester,
  ) async {
    gateway.saveError = StateError('disk full');
    await pumpScreen(tester);

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

    await tapAction(tester, 'Restore from backup');
    // A legacy plaintext file opens without a passphrase.
    await enterPassphrase(
      tester,
      passphrase: '',
      confirmLabel: 'Open backup',
    );

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
    await seedLocalRow();
    gateway.picked = _legacyBackup(notes: 1);
    await pumpScreen(tester);

    await tapAction(tester, 'Restore from backup');
    await enterPassphrase(
      tester,
      passphrase: '',
      confirmLabel: 'Open backup',
    );

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
        .customSelect('SELECT COUNT(*) AS n FROM sync_metadata')
        .getSingle();
    expect(untouched.data['n'], 1);

    // Choosing Replace does the restore and reports it.
    await tapAction(tester, 'Restore from backup');
    await enterPassphrase(
      tester,
      passphrase: '',
      confirmLabel: 'Open backup',
    );
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final restored = await db.customSelect('SELECT COUNT(*) AS n FROM notes').getSingle();
    final replaced = await db
        .customSelect('SELECT COUNT(*) AS n FROM sync_metadata')
        .getSingle();
    expect(restored.data['n'], 1);
    expect(replaced.data['n'], 0);
  });

  testWidgets('a wrong passphrase is reported and changes nothing', (
    tester,
  ) async {
    await seedLocalRow();
    gateway.picked = await _encryptedBackup('the real passphrase');
    await pumpScreen(tester);

    await tapAction(tester, 'Restore from backup');
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

    await tapAction(tester, 'Restore from backup');
    await enterPassphrase(
      tester,
      passphrase: '',
      confirmLabel: 'Open backup',
    );

    expect(
      find.text('That file is not a backup made by this app.'),
      findsOneWidget,
    );
  });

  testWidgets('a picker that refuses to open is reported', (tester) async {
    gateway.pickError = StateError('no content provider');
    await pumpScreen(tester);

    await tapAction(tester, 'Restore from backup');

    expect(find.text('Could not open that file.'), findsOneWidget);
    expect(find.text('Open this backup'), findsNothing);
  });

  testWidgets('the cloud action still reports that it is not available', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tapAction(tester, 'Backup to Google Drive');

    expect(find.text('Cloud backup is not available yet'), findsOneWidget);
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
