/// Factory that builds a SQLite3MultipleCiphers-encrypted Drift [QueryExecutor].
/// Implemented in Task 03 Phase 1.
///
/// Uses the official Drift-recommended SQLite3MultipleCiphers backend, bundled
/// by the `sqlite3` package build hook (see `hooks:` in `pubspec.yaml`).
library;

import 'dart:developer' as dev;
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart';

import 'encryption_key_manager.dart';

/// Thrown when the factory cannot safely open the database, e.g. the key is
/// missing while an encrypted database file already exists.
class DatabaseFactoryException implements Exception {
  /// Human-readable explanation.
  final String message;

  /// Creates an exception with [message].
  DatabaseFactoryException(this.message);

  @override
  String toString() => 'DatabaseFactoryException: $message';
}

/// Creates the per-platform file-backed [QueryExecutor] used by [AppDatabase].
class DatabaseFactory {
  static const _defaultName = 'app_database';

  /// Key manager used to load or create the database key. If omitted, a new
  /// [EncryptionKeyManager] is created lazily on the first call to
  /// [createExecutor].
  final EncryptionKeyManager? keyManager;

  /// Base name of the database file (`.db` is appended automatically).
  final String name;

  /// Optional directory provider for tests. Defaults to
  /// [getApplicationDocumentsDirectory] when omitted.
  final Future<Directory> Function()? directoryProvider;

  /// Creates a factory.
  DatabaseFactory({
    this.keyManager,
    this.name = _defaultName,
    this.directoryProvider,
  });

  /// Builds the encrypted [QueryExecutor].
  ///
  /// If the database file already exists but no key can be loaded, a
  /// [DatabaseFactoryException] is thrown instead of silently overwriting data.
  Future<QueryExecutor> createExecutor() async {
    final directory =
        await (directoryProvider?.call() ?? getApplicationDocumentsDirectory());
    final file = File(p.join(directory.path, '$name.db'));

    final keyManager = this.keyManager ?? EncryptionKeyManager();
    final key = await _loadKey(keyManager, file);

    return NativeDatabase.createInBackground(
      file,
      setup: (database) => _applyKey(database, key),
    );
  }

  /// Loads the encryption key, guarding against silent data loss when the
  /// database file exists but the key is missing.
  Future<String> _loadKey(EncryptionKeyManager keyManager, File dbFile) async {
    final dbExists = await dbFile.exists();
    if (dbExists && !await keyManager.hasKey()) {
      throw DatabaseFactoryException(
        'Encrypted database exists but key is missing. Restore from backup.',
      );
    }
    return keyManager.getOrCreateKey();
  }

  /// Applies the SQLite3MultipleCiphers key and verifies that encryption is
  /// actually available.
  ///
  /// On Windows/Linux during local development, if SQLite3MultipleCiphers was
  /// not bundled, the database may fall back to an unencrypted file only in
  /// debug builds and with a logged warning. Release builds on any platform
  /// require encryption and will throw if it is unavailable.
  void _applyKey(CommonDatabase database, String key) {
    final hasCipher = _hasCipher(database);

    if (!hasCipher) {
      final isDesktopDev =
          (Platform.isWindows || Platform.isLinux) && kDebugMode;
      if (isDesktopDev) {
        dev.log(
          'SQLite3MultipleCiphers is not available on this desktop build. '
          'Falling back to an unencrypted database for local development only.',
          name: 'DatabaseFactory',
        );
        return;
      }
      throw DatabaseFactoryException(
        'Database encryption is not available on this platform.',
      );
    }

    // Use the SQLCipher-compatible hex-literal format so the key is never
    // interpreted as a string with special characters.
    database.execute("PRAGMA key = \"x'$key'\";");
  }

  /// Returns `true` if the bundled SQLite supports Multiple Ciphers.
  bool _hasCipher(CommonDatabase database) {
    try {
      return database.select('PRAGMA cipher;').isNotEmpty;
    } on Exception catch (e, stack) {
      dev.log(
        'Unable to query PRAGMA cipher; assuming encryption unavailable.',
        name: 'DatabaseFactory',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }
}
