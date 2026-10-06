/// Tests for opening a backup file (Task 15 Phase 3).
///
/// Opening is the whole "can this file be trusted?" chain — read, decrypt,
/// authenticate, verify, version-check, upgrade — and it must reject every bad
/// file with the right reason *before* the database is involved.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/backup/backup_cipher.dart';
import 'package:legal_case_diary/core/backup/backup_format.dart';
import 'package:legal_case_diary/core/backup/backup_restore.dart';

/// The recovery secret every encrypted fixture uses.
const String _secret = 'correct horse battery staple';

/// A payload shaped like the real one: one section, one table, raw rows.
Map<String, dynamic> _payload({Map<String, dynamic>? tables}) => <String, dynamic>{
  kBackupTablesSection: tables ?? <String, dynamic>{'notes': <Map<String, dynamic>>[{'id': 'n1', 'body': 'File the affidavit'}]},
};

/// Seals a Phase 1 envelope into a Phase 2 container and returns the file bytes.
Future<Uint8List> _encryptedBytes({
  String secret = _secret,
  int schemaVersion = 1,
  Map<String, dynamic>? payload,
  int containerVersion = kEncryptedBackupFormatVersion,
  String appVersion = '0.0.228',
  int exportedAt = 1700000000000,
}) async {
  final envelope = BackupEnvelope.create(
    appVersion: appVersion,
    exportedAt: exportedAt,
    payload: payload ?? _payload(),
    schemaVersion: schemaVersion,
  );
  final container = await encryptBackup(
    plaintext: utf8.encode(envelope.encode()),
    recoverySecret: secret,
    appVersion: appVersion,
    createdAt: exportedAt,
    iterations: 1000,
  );
  final document = container.toJson()..['format_version'] = containerVersion;
  return Uint8List.fromList(utf8.encode(jsonEncode(document)));
}

/// A plaintext envelope written by a pre-encryption build (0.0.227 and earlier).
Uint8List _legacyBytes({
  int schemaVersion = 1,
  Map<String, dynamic>? payload,
  String appVersion = '0.0.227',
}) => Uint8List.fromList(
  utf8.encode(
    BackupEnvelope.create(
      appVersion: appVersion,
      exportedAt: 1700000000000,
      payload: payload ?? _payload(),
      schemaVersion: schemaVersion,
    ).encode(),
  ),
);

/// Expects [bytes] to be refused with [failure].
Future<void> _expectRefused(
  List<int> bytes,
  BackupRestoreFailure failure, {
  String secret = _secret,
}) async {
  await expectLater(
    openBackupFile(bytes: bytes, recoverySecret: secret),
    throwsA(
      isA<BackupRestoreException>().having(
        (error) => error.failure,
        'failure',
        failure,
      ),
    ),
  );
}

void main() {
  group('looksLikeEncryptedBackup', () {
    test('tells the sealed container from a plaintext file and junk', () async {
      // The restore flow prompts for a passphrase only when this is true.
      expect(looksLikeEncryptedBackup(await _encryptedBytes()), isTrue);
      expect(looksLikeEncryptedBackup(_legacyBytes()), isFalse);
      expect(looksLikeEncryptedBackup(utf8.encode('not json at all')), isFalse);
      expect(
        looksLikeEncryptedBackup(Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF])),
        isFalse,
      );
    });
  });

  group('openBackupFile', () {
    test('opens an encrypted backup and reports it as encrypted', () async {
      final opened = await openBackupFile(
        bytes: await _encryptedBytes(),
        recoverySecret: _secret,
      );

      expect(opened.kind, BackupFileKind.encrypted);
      expect(opened.schemaVersion, kBackupSchemaVersion);
      expect(opened.appVersion, '0.0.228');
      expect(opened.exportedAt, 1700000000000);
      expect((opened.tables['notes'] as List).single, {
        'id': 'n1',
        'body': 'File the affidavit',
      });
    });

    test('opens a legacy plaintext envelope, with or without a secret', () async {
      final opened = await openBackupFile(
        bytes: _legacyBytes(),
        recoverySecret: _secret,
      );

      expect(opened.kind, BackupFileKind.legacyPlaintext);
      expect(opened.appVersion, '0.0.227');
      expect(opened.tables['notes'], hasLength(1));
      // A plaintext file needs no passphrase, so an empty one still opens.
      final withoutSecret = await openBackupFile(
        bytes: _legacyBytes(),
        recoverySecret: '',
      );
      expect(withoutSecret.kind, BackupFileKind.legacyPlaintext);
    });

    test('a wrong secret is refused as a secret failure', () async {
      await _expectRefused(
        await _encryptedBytes(),
        BackupRestoreFailure.wrongSecretOrTampered,
        secret: 'not the passphrase',
      );
    });

    test('a tampered ciphertext or header is refused', () async {
      final original = jsonDecode(utf8.decode(await _encryptedBytes()))
          as Map<String, dynamic>;

      final tamperedBody = Map<String, dynamic>.from(original);
      final ciphertext = base64.decode(tamperedBody['ciphertext'] as String);
      ciphertext[0] = ciphertext[0] ^ 0x01;
      tamperedBody['ciphertext'] = base64.encode(ciphertext);
      await _expectRefused(
        utf8.encode(jsonEncode(tamperedBody)),
        BackupRestoreFailure.wrongSecretOrTampered,
      );

      // The header is authenticated too, so an edited KDF count is refused.
      final tamperedHeader = Map<String, dynamic>.from(original)
        ..['kdf_iterations'] = 1;
      await _expectRefused(
        utf8.encode(jsonEncode(tamperedHeader)),
        BackupRestoreFailure.wrongSecretOrTampered,
      );

      // The container's own checksum is not part of the AEAD, so altering it is
      // caught by the checksum comparison instead — and still refused.
      final tamperedChecksum = Map<String, dynamic>.from(original)
        ..['checksum'] = List<String>.filled(64, '0').join();
      await _expectRefused(
        utf8.encode(jsonEncode(tamperedChecksum)),
        BackupRestoreFailure.damagedFile,
      );
    });

    test('a newer container or payload version is refused as unsupported', () async {
      await _expectRefused(
        await _encryptedBytes(containerVersion: kEncryptedBackupFormatVersion + 1),
        BackupRestoreFailure.unsupportedVersion,
      );
      await _expectRefused(
        await _encryptedBytes(schemaVersion: kBackupSchemaVersion + 1),
        BackupRestoreFailure.unsupportedVersion,
      );
      await _expectRefused(
        _legacyBytes(schemaVersion: kBackupSchemaVersion + 1),
        BackupRestoreFailure.unsupportedVersion,
      );
    });

    test('a file that is not a backup is refused as invalid', () async {
      await _expectRefused(
        utf8.encode('this is not a backup at all'),
        BackupRestoreFailure.invalidFile,
      );
      await _expectRefused(
        utf8.encode('[1,2,3]'),
        BackupRestoreFailure.invalidFile,
      );
      // An empty JSON object: neither a container nor a versioned envelope.
      await _expectRefused(utf8.encode('{}'), BackupRestoreFailure.invalidFile);
      await _expectRefused(
        utf8.encode('{"schema_version":1}'),
        BackupRestoreFailure.invalidFile,
      );
      // Binary that is not UTF-8.
      await _expectRefused(const <int>[0xFF, 0xFE, 0x00], BackupRestoreFailure.invalidFile);

      // A container whose header this build cannot use, and one with invalid
      // base64 key parameters.
      final document = jsonDecode(utf8.decode(await _encryptedBytes()))
          as Map<String, dynamic>;
      await _expectRefused(
        utf8.encode(jsonEncode(Map<String, dynamic>.from(document)..['cipher'] = 'aes-128-cbc')),
        BackupRestoreFailure.invalidFile,
      );
      await _expectRefused(
        utf8.encode(jsonEncode(Map<String, dynamic>.from(document)..['kdf_salt'] = 'not base64 !!')),
        BackupRestoreFailure.invalidFile,
      );
    });

    test('a payload that no longer matches its checksum is refused', () async {
      // A legacy plaintext file is the only one whose payload checksum can be
      // edited without the AEAD noticing, so it is the honest way to test it.
      final envelope = jsonDecode(utf8.decode(_legacyBytes()))
          as Map<String, dynamic>;
      final payload = envelope['payload'] as Map<String, dynamic>;
      (payload[kBackupTablesSection] as Map<String, dynamic>)['notes'] =
          <Map<String, dynamic>>[{'id': 'n1', 'body': 'tampered'}];

      await _expectRefused(
        utf8.encode(jsonEncode(envelope)),
        BackupRestoreFailure.damagedFile,
      );
    });

    test('runs the injected adapters for an older payload version', () async {
      final opened = await openBackupFile(
        bytes: await _encryptedBytes(payload: _payload(tables: <String, dynamic>{'notes': []})),
        recoverySecret: _secret,
        targetSchemaVersion: 2,
        adapters: <int, BackupPayloadAdapter>{
          1: (payload) => <String, dynamic>{
            ...payload,
            kBackupTablesSection: <String, dynamic>{
              'notes': <Map<String, dynamic>>[],
              'new_table': <Map<String, dynamic>>[],
            },
          },
        },
      );

      expect(opened.schemaVersion, 1); // as read from the file
      expect(opened.tables.keys, contains('new_table'));
    });
  });

  group('migrateBackupPayload', () {
    test('returns the payload untouched when no upgrade is needed', () {
      final payload = _payload();
      expect(migrateBackupPayload(payload, fromVersion: 1), same(payload));
      expect(migrateBackupPayload(payload, fromVersion: 1, toVersion: 1), same(payload));
    });

    test('applies one adapter per version, in order', () {
      final migrated = migrateBackupPayload(
        <String, dynamic>{'steps': <String>[]},
        fromVersion: 1,
        toVersion: 3,
        adapters: <int, BackupPayloadAdapter>{
          1: (payload) => <String, dynamic>{
            ...payload,
            'steps': <String>[...payload['steps'] as List<String>, 'one'],
          },
          2: (payload) => <String, dynamic>{
            ...payload,
            'steps': <String>[...payload['steps'] as List<String>, 'two'],
          },
        },
      );

      expect(migrated['steps'], <String>['one', 'two']);
    });

    test('refuses a step it has no adapter for', () {
      expect(
        () => migrateBackupPayload(
          <String, dynamic>{},
          fromVersion: 1,
          toVersion: 3,
          adapters: <int, BackupPayloadAdapter>{
            1: (payload) => payload,
          },
        ),
        throwsA(
          isA<BackupRestoreException>().having(
            (error) => error.failure,
            'failure',
            BackupRestoreFailure.unsupportedVersion,
          ),
        ),
      );
    });

    test('the shipped adapter registry is empty at the current version', () {
      // It only fills up when a schema bump changes the payload shape.
      expect(backupPayloadAdapters, isEmpty);
      expect(kBackupSchemaVersion, 1);
    });
  });
}
