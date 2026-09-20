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

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
