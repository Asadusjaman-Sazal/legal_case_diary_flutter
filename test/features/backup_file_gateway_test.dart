/// The rules that decide which files in the diary folder a restore can open.
///
/// A restore lists every `.lcbak` container and `.xlsx` workbook in the folder,
/// whatever the file is called, so a backup the user renamed or copied in is not
/// hidden. Anything else in the folder — a photo, a note — is ignored.
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

  test('listBackupFiles lists every backup, whatever it is called', () async {
    seed(automaticBackupFileName);
    seed('Backup_20-09-26_11-06-07am.lcbak');
    // A backup copied, downloaded or renamed by the user: the phone's file
    // manager shows it, so the restore list must too.
    seed('Copy of backup.lcbak');
    seed('EXPORT.XLSX');
    seed('holiday-photo.jpg');
    seed('notes.txt');
    seed('not-a-backup.lcbak.txt');

    final listed = [
      for (final f in await listBackupFiles(dir)) p.basename(f.path),
    ];

    expect(listed, hasLength(4));
    expect(listed, contains(automaticBackupFileName));
    expect(listed, contains('Backup_20-09-26_11-06-07am.lcbak'));
    expect(listed, contains('Copy of backup.lcbak'));
    expect(listed, contains('EXPORT.XLSX'));
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
