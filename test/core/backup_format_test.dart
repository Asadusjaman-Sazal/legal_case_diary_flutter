/// Unit tests for the versioned backup envelope (Task 15 Phase 1).
///
/// The envelope is the canonical local format every export path shares, so its
/// checksum and version rules are pinned here before the encryption and restore
/// layers build on it.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/backup/backup_format.dart';

void main() {
  /// A small payload shaped like the real one: a `tables` section of row lists.
  Map<String, dynamic> samplePayload() => <String, dynamic>{
    kBackupTablesSection: <String, dynamic>{
      'cases': <Map<String, dynamic>>[
        <String, dynamic>{'id': 'case-1', 'case_number': '110/2021', 'version': 3},
      ],
      'notes': <Map<String, dynamic>>[],
    },
  };

  group('BackupEnvelope', () {
    test('create computes the payload checksum', () {
      final payload = samplePayload();
      final envelope = BackupEnvelope.create(
        appVersion: '0.0.227',
        exportedAt: 1000,
        payload: payload,
      );

      expect(envelope.schemaVersion, kBackupSchemaVersion);
      expect(envelope.checksum, checksumOfPayload(payload));
      expect(envelope.verifyChecksum(), isTrue);
      expect(envelope.tables.keys, ['cases', 'notes']);
    });

    test('encode/decode round-trips and the checksum still verifies', () {
      final original = BackupEnvelope.create(
        appVersion: '0.0.227',
        exportedAt: 1234,
        payload: samplePayload(),
      );

      final restored = BackupEnvelope.decode(original.encode());

      expect(restored.schemaVersion, original.schemaVersion);
      expect(restored.appVersion, original.appVersion);
      expect(restored.exportedAt, original.exportedAt);
      expect(restored.checksum, original.checksum);
      expect(restored.payload, original.payload);
      expect(restored.verifyChecksum(), isTrue);
    });

    test('a tampered payload fails the checksum', () {
      final envelope = BackupEnvelope.create(
        appVersion: '0.0.227',
        exportedAt: 5,
        payload: samplePayload(),
      );

      final tampered = BackupEnvelope(
        schemaVersion: envelope.schemaVersion,
        appVersion: envelope.appVersion,
        exportedAt: envelope.exportedAt,
        checksum: envelope.checksum,
        payload: <String, dynamic>{
          kBackupTablesSection: <String, dynamic>{
            'cases': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'case-1', 'case_number': '999/2021'},
            ],
          },
        },
      );

      expect(tampered.verifyChecksum(), isFalse);
    });

    test('a payload without a tables section yields no tables', () {
      final envelope = BackupEnvelope.create(
        appVersion: '0.0.227',
        exportedAt: 5,
        payload: <String, dynamic>{},
      );
      expect(envelope.tables, isEmpty);
    });

    test('checksumOfBytes is the hex SHA-256 of the bytes', () {
      final bytes = utf8.encode('hello');
      expect(checksumOfBytes(bytes), sha256.convert(bytes).toString());
    });
  });

  group('BackupEnvelope version rules', () {
    Map<String, dynamic> envelopeJson({Object? schemaVersion = 1}) =>
        <String, dynamic>{
          'schema_version': schemaVersion,
          'app_version': '0.0.227',
          'exported_at': 10,
          'checksum': 'abc',
          'payload': samplePayload(),
        };

    test('the current version is accepted', () {
      final envelope = BackupEnvelope.fromJson(envelopeJson());
      expect(envelope.schemaVersion, kBackupSchemaVersion);
    });

    test('a newer version is refused with a typed exception', () {
      expect(
        () => BackupEnvelope.fromJson(
          envelopeJson(schemaVersion: kBackupSchemaVersion + 1),
        ),
        throwsA(
          isA<UnsupportedBackupVersionException>()
              .having((e) => e.foundVersion, 'foundVersion', 2)
              .having((e) => e.supportedVersion, 'supportedVersion', 1),
        ),
      );
    });

    test('a missing or invalid schema version is refused', () {
      expect(
        () => BackupEnvelope.fromJson(envelopeJson(schemaVersion: null)),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BackupEnvelope.fromJson(envelopeJson(schemaVersion: 'one')),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BackupEnvelope.fromJson(envelopeJson(schemaVersion: 0)),
        throwsA(isA<FormatException>()),
      );
    });

    test('missing envelope fields are refused', () {
      final json = envelopeJson()..remove('checksum');
      expect(
        () => BackupEnvelope.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('decode refuses a non-object document', () {
      expect(
        () => BackupEnvelope.decode('[]'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
