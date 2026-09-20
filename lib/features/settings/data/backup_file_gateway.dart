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

/// Provider for the backup file dialogs; tests override it with a fake.
final backupFileGatewayProvider = Provider<BackupFileGateway>(
  (ref) => const FilePickerBackupGateway(),
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
