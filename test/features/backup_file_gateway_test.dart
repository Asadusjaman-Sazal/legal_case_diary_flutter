/// What a restore lists from the diary folder.
///
/// Every file is listed, whatever its name or extension: the folder is the app's
/// own backup home, and the restore engine — not the listing rule — decides what
/// can be opened. A name rule hid a real backup before, so there is none.
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

  test('listBackupFiles lists every file in the folder', () async {
    seed(automaticBackupFileName);
    seed('Backup_20-09-26_11-06-07am.lcbak');
    // A backup copied, downloaded or renamed by the user: the phone's file
    // manager shows it, so the restore list must too.
    seed('Copy of backup.lcbak');
    seed('EXPORT.XLSX');
    seed('automatic-backup.json');
    seed('holiday-photo.jpg');

    final listed = [
      for (final f in await listBackupFiles(dir)) p.basename(f.path),
    ];

    // Nothing is filtered by name or extension: the folder is the app's own,
    // and a file that cannot be restored is refused by the engine, not hidden.
    expect(listed, hasLength(6));
    expect(listed, contains(automaticBackupFileName));
    expect(listed, contains('Backup_20-09-26_11-06-07am.lcbak'));
    expect(listed, contains('Copy of backup.lcbak'));
    expect(listed, contains('EXPORT.XLSX'));
    expect(listed, contains('automatic-backup.json'));
    expect(listed, contains('holiday-photo.jpg'));
  });

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
