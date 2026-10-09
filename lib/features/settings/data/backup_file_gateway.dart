/// Backup file gateway (Task 15 Phase 4).
///
/// **The only file that imports `file_picker`**, so the rest of the app — and
/// every test — talks to the platform's save/open dialogs through this seam
/// (the same boundary pattern as `print_service.dart` and
/// `android_notification_gateway.dart`).
///
/// It also implements [BackupArchiveSink], so the export engine writes through
/// the very dialog the user chose: `BackupRepository.exportSnapshot` stays the
/// single export path (Sync Plan §5) and only the destination changes.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'backup_repository.dart';

/// A backup file the user selected to restore from.
class PickedBackupFile {
  /// File name as the picker reported it (shown in the confirmation).
  final String name;

  /// Filesystem path when the platform exposes one; null for a content URI.
  final String? path;

  /// The file's bytes, already read so no further I/O is needed.
  final Uint8List bytes;

  /// Creates a picked backup file.
  const PickedBackupFile({
    required this.name,
    required this.path,
    required this.bytes,
  });
}

/// Thrown when the user dismisses the "Save to…" dialog.
///
/// Not an error: the caller reports nothing and nothing was recorded, because
/// the archive is only recorded after a successful write.
class BackupSaveCancelledException implements Exception {
  /// Creates the cancellation marker.
  const BackupSaveCancelledException();

  @override
  String toString() => 'The backup save dialog was dismissed.';
}

/// The platform's save and open dialogs for backup files.
abstract interface class BackupFileGateway implements BackupArchiveSink {
  /// Asks the user for a backup file; null when the dialog is dismissed.
  Future<PickedBackupFile?> pick();
}

/// `file_picker`-backed gateway used by the running app.
class FilePickerBackupGateway implements BackupFileGateway {
  /// Creates the gateway.
  const FilePickerBackupGateway();

  /// Asks the user where to save the encrypted backup and writes it there.
  ///
  /// Returns the location to show the user: a filesystem path when the platform
  /// exposes one, otherwise the content URI the storage framework returned.
  @override
  Future<String> write({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final location = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      // The container is not any registered type, so the octet-stream default
      // keeps Android from renaming it to a `.bin`.
      mimeType: 'application/octet-stream',
    );
    if (location == null) throw const BackupSaveCancelledException();
    return location.scheme == 'file'
        ? location.toFilePath()
        : location.toString();
  }

  /// Asks the user for a backup file to restore from.
  ///
  /// No extension filter is applied: `.lcbak` is not a type Android knows, and a
  /// filtered picker can hide every file. The chosen file is validated instead —
  /// `openBackupFile` refuses anything that is not a backup.
  @override
  Future<PickedBackupFile?> pick() async {
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null) return null;
    return PickedBackupFile(
      name: file.name,
      path: file.path,
      bytes: await file.readAsBytes(),
    );
  }
}

/// The folder the app writes user-facing backups into: the documents directory.
///
/// Names the "Internal storage/LegalCaseDiary" folder that surfaces in file
/// managers, so a backup is a file a non-technical user can find without a
/// "Save to…" dialog deciding a location for them. All three requested
/// backups — Local, Excel and the restores they serve — share this home, which
/// is also what lets restore skip the picker when the folder holds one file.
Future<Directory> backupDocumentsDirectory() async {
  final base = await getApplicationDocumentsDirectory();
  return Directory('${base.path}${Platform.pathSeparator}LegalCaseDiary');
}

/// A [BackupArchiveSink] that writes into the app's own documents directory.
///
/// The automatic exports use it — the extended-offline safety copy (Task 19
/// Phase 5) and the logout export (Task 19 Phase 6) both run while the app is
/// locked or being wiped, when there is nobody to answer a Save-to window. The
/// file is the same encrypted container the manual export writes, and its path
/// is returned so the caller can record it and show it to the user.
class LocalArchiveSink implements BackupArchiveSink {
  /// Creates the sink, optionally over a directory a test controls.
  const LocalArchiveSink({this.directoryProvider});

  /// The directory the file is written into; documents by default.
  final Future<Directory> Function()? directoryProvider;

  /// Writes [bytes] into `<documents>/backups/<fileName>` and returns its path.
  @override
  Future<String> write({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final base =
        await (directoryProvider?.call() ?? getApplicationDocumentsDirectory());
    final directory = Directory(
      '${base.path}${Platform.pathSeparator}backups',
    );
    if (!await directory.exists()) await directory.create(recursive: true);
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}

/// A directory sink that resolves to the backup home folder.
///
/// This is the *diary's* "Internal storage/LegalCaseDiary" — a folder a
/// non-technical user can find in their file manager. A failure bubbles up as
/// the natural [FileSystemException]; the caller falls back to the system save
/// dialog rather than silently losing the backup.
class BackupFolderSink implements BackupArchiveSink {
  /// Creates the sink, optionally over a directory a test controls.
  const BackupFolderSink({this.directoryProvider});

  /// The folder to write into; [backupDocumentsDirectory] by default.
  final Future<Directory> Function()? directoryProvider;

  @override
  Future<String> write({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final dir = await (directoryProvider?.call() ?? backupDocumentsDirectory());
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}

/// Writes into the diary folder, falling back to the system save dialog when
/// the folder cannot be created or written.
///
/// This is what makes "Backup to Local Storage" and "Backup as Excel File"
/// dialog-free: the folder is the default, and the picker is the safety net the
/// user asked for — a backup that cannot reach its folder is not silently lost.
class BackupFolderFirstSink implements BackupArchiveSink {
  /// The primary folder sink.
  final BackupArchiveSink folder;

  /// The dialog-backed sink used when [folder] fails.
  final BackupArchiveSink fallback;

  /// Creates a folder-first sink.
  const BackupFolderFirstSink({required this.folder, required this.fallback});

  @override
  Future<String> write({
    required String fileName,
    required Uint8List bytes,
  }) async {
    try {
      return await folder.write(fileName: fileName, bytes: bytes);
    } on FileSystemException {
      // The diary folder is not writable — ask the user where to save instead.
      return fallback.write(fileName: fileName, bytes: bytes);
    }
  }
}

/// Lists the backup files in [dir], sorted by name ascending.
///
/// A file counts as a backup when its name matches the app's own default file
/// name — so the folder does not confuse a PDF or a photo left here with a
/// backup, while still accepting every file this app wrote. The sort orders a
/// restore by file name, which is timestamp-ordered because the app's default
/// names are.
Future<List<File>> listBackupFiles(Directory dir) async {
  final entries = dir.existsSync()
      ? dir.listSync().whereType<File>()
      : <File>[];
  final backups = <File>[
    for (final f in entries)
      if (_isBackupFileName(p.basename(f.path))) f,
  ]..sort((a, b) => a.path.compareTo(b.path));
  return backups;
}

/// Whether a file name is one the app itself would have chosen for a backup.
///
/// Accepts both saved formats a restore can open — the `.lcbak` container and
/// the `.xlsx` workbook — under the same `Backup_dd-mm-yy_hh-mm-ssam/pm` stem.
bool _isBackupFileName(String name) {
  for (final ext in const ['.lcbak', '.xlsx']) {
    if (name.endsWith(ext)) {
      return backupFileNamePattern.hasMatch(
        name.substring(0, name.length - ext.length),
      );
    }
  }
  return false;
}

/// Matches `Backup_dd-mm-yy_hh-mm-ssam` / `Backup_dd-mm-yy_hh-mm-sspm`.
final RegExp backupFileNamePattern = RegExp(
  r'^Backup_\d{2}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}(?:am|pm)$',
);

/// The diary folder backups live in; tests override it with a temp directory.
final backupFolderDirectoryProvider = Provider<Future<Directory> Function()>(
  (_) => backupDocumentsDirectory,
);

/// Provider for the backup file dialogs; tests override it with a fake.
final backupFileGatewayProvider = Provider<BackupFileGateway>(
  (ref) => const FilePickerBackupGateway(),
);

/// The folder sink for backup actions; tests override it with a fake.
final backupFolderSinkProvider = Provider<BackupArchiveSink>(
  (ref) => BackupFolderSink(
    directoryProvider: ref.watch(backupFolderDirectoryProvider),
  ),
);

/// The folder-first composite sink the screen's Local/Excel actions use.
///
/// Kept as its own provider so tests can inject a folder sink that throws, yet
/// keep the [backupFileGatewayProvider] picker as a real dialog fake.
final backupFolderFirstSinkProvider = Provider<BackupArchiveSink>(
  (ref) => BackupFolderFirstSink(
    folder: ref.watch(backupFolderSinkProvider),
    fallback: ref.watch(backupFileGatewayProvider),
  ),
);

/// A [BackupArchiveSink] that also keeps a copy the share sheet can attach.
///
/// Used by Backup to Google Drive: the backup itself is written through the same
/// Save-to dialog as the local action — so the file the user keeps and the file
/// the status card reports are one and the same — and a second copy is left in a
/// location the platform's share sheet can read.
///
/// The copy exists because the Save-to dialog may hand back a `content://` URI
/// (Android's storage framework), and no share sheet can attach one. When the
/// chosen location is a real file it is shared as it is; otherwise the same
/// encrypted bytes are written to the app's temporary directory. That copy sits
/// in the cache, which the platform may clear at any time — it is a courier, not
/// the backup, which is why [savedPath] is what callers record.
class ShareableBackupSink implements BackupArchiveSink {
  /// The dialog-backed gateway the backup is written through.
  final BackupFileGateway gateway;

  /// Where the user's own file went; null until [write] succeeds.
  String? savedPath;

  /// A path the share sheet can attach; null until [write] succeeds.
  String? sharePath;

  /// Creates the sink.
  ShareableBackupSink(this.gateway);

  @override
  Future<String> write({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final written = await gateway.write(fileName: fileName, bytes: bytes);
    savedPath = written;
    sharePath = await _shareablePath(written, fileName, bytes);
    return written;
  }

  /// [written] when the platform gave a real file, otherwise a temporary copy.
  ///
  /// The copy is written synchronously on purpose: this is a one-shot write of
  /// bytes that are already in memory, it happens under the export's progress
  /// window, and it keeps the whole export a single uninterrupted sequence
  /// instead of handing the event loop a write whose completion is not
  /// observable by the caller.
  static Future<String> _shareablePath(
    String written,
    String fileName,
    Uint8List bytes,
  ) async {
    if (File(written).existsSync()) return written;
    final directory = await getTemporaryDirectory();
    final copy = File('${directory.path}${Platform.pathSeparator}$fileName');
    copy.writeAsBytesSync(bytes, flush: true);
    return copy.path;
  }
}
