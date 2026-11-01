/// The rules that decide which files in the diary folder are the app's own.
///
/// A restore lists the folder through [backupFileNamePattern], so every name the
/// app has written must be recognised. The automatic backup uses one fixed
/// name, written through a temporary file and renamed into place, so it
/// replaces itself without a sweep; a manual backup keeps its timestamped name
/// and is never touched.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:legal_case_diary/features/settings/data/backup_file_gateway.dart';
import 'package:legal_case_diary/features/settings/data/backup_repository.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('lcb_gateway');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  /// Writes an empty file with [name] into the temp folder.
  void seed(String name) => File(p.join(dir.path, name)).writeAsBytesSync([]);

  group('backupFileNamePattern', () {
    test('accepts a manual backup', () {
      expect(
        backupFileNamePattern.hasMatch('Backup_20-09-26_11-06-07am'),
        isTrue,
      );
    });

    test('accepts the fixed automatic backup, so a restore can list it', () {
      // The whole point of the automatic copy is that it can be restored; a
      // name the listing rule rejects would make it invisible.
      expect(backupFileNamePattern.hasMatch('AutomaticBackup'), isTrue);
    });

    test('accepts the timestamped automatic names older releases wrote', () {
      // They stay restorable even though the current job replaces one fixed
      // file.
      expect(
        backupFileNamePattern.hasMatch('AutomaticBackup_20-09-26_11-06-07am'),
        isTrue,
      );
    });

    test('rejects anything else', () {
      for (final name in const <String>[
        'AutomaticBackup_20-09-26_11-06-07', // no am/pm
        'AutomaticBackup_2-09-26_11-06-07am', // unpadded
        'Automatic_20-09-26_11-06-07am', // wrong stem
        'MyBackup_20-09-26_11-06-07am', // not the app's
        'AutomaticBackup_20-09-26_11-06-07am (1)', // a copy
      ]) {
        expect(backupFileNamePattern.hasMatch(name), isFalse, reason: name);
      }
    });
  });

  test(
    'listBackupFiles finds an automatic backup beside a manual one',
    () async {
      seed(automaticBackupFileName);
      seed('Backup_20-09-26_11-06-07am.lcbak');
      seed('holiday-photo.jpg');

      final listed = [
        for (final f in await listBackupFiles(dir)) p.basename(f.path),
      ];

      expect(listed, hasLength(2));
      expect(listed, contains(automaticBackupFileName));
      expect(listed, contains('Backup_20-09-26_11-06-07am.lcbak'));
    },
  );

  test('an atomic write replaces the fixed file and leaves no temp', () async {
    final sink = BackupFolderSink(
      directoryProvider: () async => dir,
      atomic: true,
    );

    await sink.write(
      fileName: automaticBackupFileName,
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
    );
    await sink.write(
      fileName: automaticBackupFileName,
      bytes: Uint8List.fromList(<int>[4, 5, 6]),
    );

    final names = dir
        .listSync()
        .whereType<File>()
        .map((file) => p.basename(file.path))
        .toList();
    expect(names, <String>[automaticBackupFileName]);
    expect(
      File(p.join(dir.path, automaticBackupFileName)).readAsBytesSync(),
      <int>[4, 5, 6],
    );
  });
}
