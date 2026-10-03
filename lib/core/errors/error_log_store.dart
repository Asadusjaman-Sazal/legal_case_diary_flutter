/// Where the error log is kept between runs.
///
/// A seam, not a detail: the app writes the log through [ErrorLogStore] so a
/// widget test injects a memory store and never touches a real file, and so the
/// one place that decides *where* the log lives can be read on its own.
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Stores the log's encoded text.
abstract interface class ErrorLogStore {
  /// The stored text, or null when nothing has been written yet.
  Future<String?> read();

  /// Replaces the stored text.
  Future<void> write(String contents);

  /// Removes it.
  Future<void> clear();
}

/// A [ErrorLogStore] that keeps the log in a file.
///
/// [FileErrorLogStore.inSupportDirectory] is the only location the app uses:
/// **app-private support storage, never shared storage**, because the log is
/// internal diagnostics and must not appear in a file browser or a Downloads
/// folder. It is not encrypted: the private sandbox is the same protection the
/// encrypted database already relies on, and a key the app could lose would add
/// a failure mode to the one tool that exists to explain failures.
class FileErrorLogStore implements ErrorLogStore {
  /// Creates a store over [file].
  FileErrorLogStore(this.file);

  /// The file the log is kept in.
  final File file;

  /// The app's own support directory — never shared storage.
  static Future<FileErrorLogStore> inSupportDirectory() async {
    final directory = await getApplicationSupportDirectory();
    return FileErrorLogStore(
      File('${directory.path}${Platform.pathSeparator}error-log.json'),
    );
  }

  @override
  Future<String?> read() async =>
      await file.exists() ? file.readAsString() : null;

  @override
  Future<void> write(String contents) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(contents);
  }

  @override
  Future<void> clear() async {
    if (await file.exists()) await file.delete();
  }
}
