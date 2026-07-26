/// Integration tests for SQLite3MultipleCiphers database encryption and key
/// management. Encryption-specific checks only run on platforms where
/// SQLite3MultipleCiphers is bundled.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:legal_case_diary/database/database_factory.dart';
import 'package:legal_case_diary/database/encryption_key_manager.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lcd_encrypt_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('EncryptionKeyManager', () {
    test('generates and returns the same key on subsequent calls', () async {
      final manager = EncryptionKeyManager.inMemory();
      final key1 = await manager.getOrCreateKey();
      final key2 = await manager.getOrCreateKey();
      expect(key1, key2);
      expect(key1.length, 64); // 32 bytes as hex.
    });

    test('deleteKey removes the stored key and generates a new one', () async {
      final manager = EncryptionKeyManager.inMemory();
      final key1 = await manager.getOrCreateKey();
      await manager.deleteKey();
      final key2 = await manager.getOrCreateKey();
      expect(key1, isNot(key2));
    });

    test('hasKey returns false before key is created and true after', () async {
      final manager = EncryptionKeyManager.inMemory();
      expect(await manager.hasKey(), false);
      await manager.getOrCreateKey();
      expect(await manager.hasKey(), true);
    });
  });

  group('DatabaseFactory', () {
    test('creates an executor for a new database', () async {
      final factory = DatabaseFactory(
        keyManager: EncryptionKeyManager.inMemory(),
        directoryProvider: () async => tempDir,
      );
      final executor = await factory.createExecutor();
      expect(executor, isNotNull);
      await executor.close();
    });

    test('throws when the database exists but key is missing', () async {
      // Simulate an existing database file without a stored key.
      final file = File(p.join(tempDir.path, 'app_database.db'));
      await file.create(recursive: true);

      final factory = DatabaseFactory(
        keyManager: EncryptionKeyManager.inMemory(),
        directoryProvider: () async => tempDir,
      );

      await expectLater(
        factory.createExecutor(),
        throwsA(isA<DatabaseFactoryException>()),
      );
    });
  });

  group('SQLite3MultipleCiphers encryption (mobile only)', () {
    final isCipherPlatform =
        Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

    const plaintext = 'Legal Case Diary secret fixture';

    test(
      'raw database bytes do not contain known plaintext',
      () async {
        final keyManager = EncryptionKeyManager.inMemory();
        final correctKey = await keyManager.getOrCreateKey();
        final dbPath = p.join(tempDir.path, 'app_database.db');

        // Create an encrypted database file by writing a known plaintext.
        final db = sqlite3.open(dbPath);
        try {
          db.execute("PRAGMA key = '$correctKey';");
          db.execute(
            'CREATE TABLE IF NOT EXISTS fixture(id INTEGER PRIMARY KEY, value TEXT);',
          );
          db.execute("INSERT INTO fixture VALUES (1, ?);", [plaintext]);
        } finally {
          db.close();
        }

        final bytes = await File(dbPath).readAsBytes();
        final fileContent = String.fromCharCodes(bytes);
        expect(fileContent.contains(plaintext), false);
      },
      skip: !isCipherPlatform,
    );

    test(
      'database rejects a wrong key without replacing data',
      () async {
        final keyManager = EncryptionKeyManager.inMemory();
        final correctKey = await keyManager.getOrCreateKey();
        final dbPath = p.join(tempDir.path, 'app_database.db');

        // Create an encrypted database file.
        final db = sqlite3.open(dbPath);
        try {
          db.execute("PRAGMA key = '$correctKey';");
          db.execute(
            'CREATE TABLE IF NOT EXISTS fixture(id INTEGER PRIMARY KEY, value TEXT);',
          );
          db.execute("INSERT INTO fixture VALUES (1, ?);", [plaintext]);
        } finally {
          db.close();
        }

        // Reopen with a wrong key and expect a failure on the first query.
        const wrongKey =
            '0000000000000000000000000000000000000000000000000000000000000000';
        final wrongDb = sqlite3.open(dbPath);
        try {
          wrongDb.execute("PRAGMA key = '$wrongKey';");
          expect(
            () => wrongDb.select('SELECT * FROM fixture;'),
            throwsA(anything),
          );
        } finally {
          wrongDb.close();
        }

        // Original data is still readable with the correct key.
        final reDb = sqlite3.open(dbPath);
        try {
          reDb.execute("PRAGMA key = '$correctKey';");
          final rows = reDb.select('SELECT value FROM fixture;');
          expect(rows.first['value'], plaintext);
        } finally {
          reDb.close();
        }
      },
      skip: !isCipherPlatform,
    );
  });
}
