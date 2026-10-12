/// The rules that decide which files in the diary folder are the app's own.
///
/// Two behaviours matter, and both are about *not* losing data. A restore lists
/// the folder through [backupFileNamePattern], so a name it does not recognise
/// is a backup the user cannot restore — which is why the automatic backup's own
/// stem is accepted there. And the automatic backup is replaced rather than
/// accumulated, so a sweep must delete yesterday's automatic file while never
/// touching a manual backup a user chose to keep.
library;

import 'dart:io';

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

    test('accepts the automatic backup, so a restore can still list it', () {
      // The whole point of the automatic copy is that it can be restored; a
      // name the listing rule rejects would make it invisible.
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

  test('listBackupFiles finds an automatic backup beside a manual one', () async {
    final automatic = automaticBackupFileName(1700000000000);
    seed(automatic);
    seed('Backup_20-09-26_11-06-07am.lcbak');
    seed('holiday-photo.jpg');

    final listed = [for (final f in await listBackupFiles(dir)) p.basename(f.path)];

    expect(listed, hasLength(2));
    expect(listed, contains(automatic));
    expect(listed, contains('Backup_20-09-26_11-06-07am.lcbak'));
  });

  group('pruneAutomaticBackups', () {
    test('sweeps the previous automatic files and keeps the new one', () async {
      seed('AutomaticBackup_18-09-26_03-00-00am.lcbak');
      seed('AutomaticBackup_19-09-26_03-00-00am.lcbak');
      seed('AutomaticBackup_20-09-26_03-00-00am.lcbak');

      final removed = await pruneAutomaticBackups(
        dir,
        keep: 'AutomaticBackup_20-09-26_03-00-00am.lcbak',
      );

      expect(removed, hasLength(2));
      final left = dir.listSync().map((f) => p.basename(f.path)).toList();
      expect(left, <String>['AutomaticBackup_20-09-26_03-00-00am.lcbak']);
    });

    test('never touches a manual backup sharing the folder', () async {
      // A manual backup is something the user chose to keep, and the sweep
      // exists only to stop the *automatic* file piling up.
      seed('Backup_18-09-26_11-06-07am.lcbak');
      seed('Backup_19-09-26_11-06-07am.xlsx');
      seed('AutomaticBackup_19-09-26_03-00-00am.lcbak');
      seed('AutomaticBackup_20-09-26_03-00-00am.lcbak');

      await pruneAutomaticBackups(
        dir,
        keep: 'AutomaticBackup_20-09-26_03-00-00am.lcbak',
      );

      final left = dir.listSync().map((f) => p.basename(f.path)).toList()
        ..sort();
      expect(left, <String>[
        'AutomaticBackup_20-09-26_03-00-00am.lcbak',
        'Backup_18-09-26_11-06-07am.lcbak',
        'Backup_19-09-26_11-06-07am.xlsx',
      ]);
    });

    test('a folder that does not exist is not an error', () async {
      // The job creates the folder before writing, but a sweep that runs after
      // a failure must not throw on top of it.
      final missing = Directory(p.join(dir.path, 'gone'));
      expect(
        await pruneAutomaticBackups(missing, keep: 'anything.lcbak'),
        isEmpty,
      );
    });

    test('with nothing to sweep it removes nothing', () async {
      seed('AutomaticBackup_20-09-26_03-00-00am.lcbak');
      expect(
        await pruneAutomaticBackups(
          dir,
          keep: 'AutomaticBackup_20-09-26_03-00-00am.lcbak',
        ),
        isEmpty,
      );
    });
  });
}
