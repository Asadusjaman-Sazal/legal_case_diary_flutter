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

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// The folder the app writes user-facing backups into: the public Downloads
/// directory on Android.
///
/// On Android this is `/storage/emulated/0/Download/LegalCaseDiary` — the one
/// folder on the device (besides `Android`, `DCIM`, `Download` etc.) that a
/// non-technical user can find in a file manager or over USB, and the location
/// the user asked for ("Internal storage/LegalCaseDiary"). Straight writes to
/// this shared location need no permission on modern Android. Where the
/// platform has no public Downloads directory (a test host, say; or a platform
/// whose native channel is absent), it falls back to the app's private
/// documents directory so code and tests still have a home.
/// All three requested backups — Local, Excel and the restores they serve —
/// share this folder, which is also what lets restore skip the picker when the
/// folder holds one file.
Future<Directory> backupDocumentsDirectory() async {
  final base =
      (await sharedDownloadsDirectory()) ??
      await getApplicationDocumentsDirectory();
  return Directory('${base.path}${Platform.pathSeparator}LegalCaseDiary');
}

/// The device's true public Downloads folder, or null when none is available.
///
/// path_provider's Android paths are all **app-scoped** (`Android/data/<pkg>`)
/// and invisible in a file manager, so the public `/storage/emulated/0/Download`
/// is asked of the Android host directly. A missing or unhandled channel is
/// answered null and the caller falls back to the private documents directory —
/// never a crash.
Future<Directory?> sharedDownloadsDirectory() async {
  try {
    const channel = MethodChannel(
      'com.legumsoft.legalcasediary/public_downloads',
    );
    final path = await channel.invokeMethod<String>('path');
    return path == null || path.isEmpty ? null : Directory(path);
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}

/// The diary backup folder, resolved **without any host channel**.
///
/// The background alarm isolate cannot call a `MethodChannel` served by the
/// activity (the host channels are foreground-only), so the automatic-backup job
/// resolves the public Downloads folder by its stable well-known Android path
/// instead. When that is not usable — a test host, or a platform without that
/// path — it falls back to the private documents directory, which the job can
/// always reach. This keeps the automatic backup correct on the device while
/// staying safe to run anywhere.
Future<Directory> backgroundBackupDirectory() async {
  if (Platform.isAndroid) {
    final pubDownloads = Directory('/storage/emulated/0/Download');
    if (await pubDownloads.exists()) {
      return Directory(
        '${pubDownloads.path}${Platform.pathSeparator}LegalCaseDiary',
      );
    }
  }
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
    final directory = Directory('${base.path}${Platform.pathSeparator}backups');
    if (!await directory.exists()) await directory.create(recursive: true);
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}

/// A directory sink that resolves to the backup home folder.
///
/// This is the *diary's* "Internal storage/LegalCaseDiary" — a folder a
/// non-technical user can find in their file manager (under Downloads on
/// Android, actually shared storage). A failure bubbles up as the natural
/// [FileSystemException]; the caller falls back to the system save dialog
/// rather than silently losing the backup.
class BackupFolderSink implements BackupArchiveSink {
  /// Creates the sink, optionally over a directory a test controls.
  const BackupFolderSink({this.directoryProvider, this.atomic = false});

  /// The folder to write into; [backupDocumentsDirectory] by default.
  final Future<Directory> Function()? directoryProvider;

  /// When true, write to a sibling `.tmp` file and rename it over [fileName].
  ///
  /// The automatic backup uses this fixed-name replacement; a manual backup
  /// keeps the plain write and its timestamped name.
  final bool atomic;

  @override
  Future<String> write({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final dir = await (directoryProvider?.call() ?? backupDocumentsDirectory());
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    if (!atomic) {
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    }
    final temp = File('${file.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    try {
      await temp.rename(file.path);
    } on FileSystemException {
      // POSIX (Android/iOS) replaces an existing file atomically above; a
      // Windows test host needs the old file removed before the rename.
      if (await file.exists()) await file.delete();
      await temp.rename(file.path);
    }
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

/// Lists every file in [dir], sorted by path.
///
/// The folder is the app's own backup folder, and the restore engine validates
/// whatever is chosen — so **no name rule here**. Two narrower rules (the app's
/// stamp pattern, then the `.lcbak`/`.xlsx` extension) still left the user's
/// automatic backup unlisted while the phone's file manager showed it, and a
/// listing rule cannot prove a file is not a backup without opening it. A file
/// that cannot be restored is refused by the engine with its own message.
///
/// The sort orders a restore by path, which is timestamp-ordered for the names
/// the app chooses for itself.
Future<List<File>> listBackupFiles(Directory dir) async {
  final entries = dir.existsSync()
      ? dir.listSync().whereType<File>().toList()
      : <File>[];
  return entries..sort((a, b) => a.path.compareTo(b.path));
}

/// The diary folder backups live in; tests override it with a temp directory.
final backupFolderDirectoryProvider = Provider<Future<Directory> Function()>(
  (_) => backupDocumentsDirectory,
);

/// Provider for the backup file dialogs; tests override it with a fake.
final backupFileGatewayProvider = Provider<BackupFileGateway>(
  (ref) => const FilePickerBackupGateway(),
);

/// The host's own view of the diary folder.
///
/// A plain directory scan and the phone's file index can disagree after a rename:
/// the file manager shows a backup the app's listing does not. The host lists
/// MediaStore's Downloads index and the directory and merges them, so the restore
/// window shows every backup the phone knows. It also opens the system document
/// picker **at** the diary folder — the picker honours `EXTRA_INITIAL_URI`, which
/// is the only start location Android offers.
class BackupFolderGateway {
  /// Creates the gateway.
  const BackupFolderGateway();

  static const MethodChannel _channel = MethodChannel(
    'com.legumsoft.legalcasediary/backup_folder',
  );

  /// The backup files the phone knows in the diary folder.
  ///
  /// Empty when there is no host channel (tests, desktop), so the caller keeps its
  /// own directory scan in that case.
  Future<List<File>> list() async {
    try {
      final rows = await _channel.invokeListMethod<Object?>('list') ?? const [];
      final files = <File>[];
      for (final row in rows) {
        if (row is Map && row['path'] is String) {
          files.add(File(row['path'] as String));
        }
      }
      return files;
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  /// Opens the system picker at the diary folder.
  ///
  /// [available] is false when the host has no such channel, so the caller can
  /// fall back to the plain picker; [file] is null when the user backed out.
  Future<({bool available, PickedBackupFile? file})> open() async {
    try {
      final row = await _channel.invokeMapMethod<String, Object?>('open');
      if (row == null) return (available: true, file: null);
      final name = row['name'];
      final bytes = row['bytes'];
      return (
        available: true,
        file: PickedBackupFile(
          name: name is String ? name : 'backup',
          path: null,
          bytes: bytes is Uint8List ? bytes : Uint8List(0),
        ),
      );
    } on MissingPluginException {
      return (available: false, file: null);
    } on PlatformException {
      return (available: false, file: null);
    }
  }
}

/// The host folder gateway; tests override it with a fake.
final backupFolderGatewayProvider = Provider<BackupFolderGateway>(
  (ref) => const BackupFolderGateway(),
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
