/// Security tests for the authenticated-encrypted backup container
/// (Task 15 Phase 2).
///
/// The container must round-trip with the right recovery secret and **fail
/// closed** on everything else: a wrong secret, an altered ciphertext, tag,
/// nonce, salt, KDF parameter or header field, and a checksum that disagrees
/// with the decrypted bytes. It must also never carry the secret or the
/// plaintext into the file it writes.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/backup/backup_cipher.dart';
import 'package:legal_case_diary/core/backup/backup_format.dart';

/// The secret every fixture uses unless a test overrides it.
const String _secret = 'correct horse battery staple';

/// The plaintext every fixture seals unless a test overrides it.
const String _plaintext = '{"schema_version":1,"payload":{"tables":{}}}';

/// Seals [_plaintext] with a fast (test-only) PBKDF2 count.
Future<EncryptedBackup> _seal({
  String secret = _secret,
  String plaintext = _plaintext,
  int iterations = 1000,
  List<int>? salt,
  List<int>? nonce,
}) => encryptBackup(
  plaintext: utf8.encode(plaintext),
  recoverySecret: secret,
  appVersion: '0.0.228',
  createdAt: 1700000000000,
  iterations: iterations,
  salt: salt,
  nonce: nonce,
);

/// Decodes the base64 [field] of [container], flips its first bit, re-encodes.
EncryptedBackup _flip(EncryptedBackup container, String field) {
  final json = container.toJson();
  final bytes = base64.decode(json[field] as String);
  bytes[0] = bytes[0] ^ 0x01;
  json[field] = base64.encode(bytes);
  return EncryptedBackup.fromJson(json);
}

/// Expects [container] to be refused with [failure] for [secret].
Future<void> _expectRefused(
  EncryptedBackup container,
  BackupDecryptionFailure failure, {
  String secret = _secret,
}) async {
  await expectLater(
    decryptBackup(container, recoverySecret: secret),
    throwsA(
      isA<BackupDecryptionException>().having(
        (error) => error.failure,
        'failure',
        failure,
      ),
    ),
  );
}

void main() {
  group('encryptBackup / decryptBackup', () {
    test('round-trips the plaintext with the correct secret', () async {
      final container = await _seal();

      final clear = await decryptBackup(container, recoverySecret: _secret);

      expect(utf8.decode(clear), _plaintext);
    });

    test('records a versioned header with public KDF parameters only', () async {
      final container = await _seal(iterations: 4096);

      expect(container.format, kEncryptedBackupFormat);
      expect(container.formatVersion, kEncryptedBackupFormatVersion);
      expect(container.kdf, kBackupKdfName);
      expect(container.kdfIterations, 4096);
      expect(container.cipher, kBackupCipherName);
      expect(container.appVersion, '0.0.228');
      expect(container.createdAt, 1700000000000);
      expect(container.saltBytes, hasLength(kBackupSaltLength));
      expect(container.nonceBytes, hasLength(kBackupNonceLength));
      expect(container.checksum, checksumOfBytes(utf8.encode(_plaintext)));
      // AEAD output only: the ciphertext must not be the plaintext.
      expect(container.ciphertext, isNot(equals(base64.encode(utf8.encode(_plaintext)))));
      expect(container.tag, isNotEmpty);
      // The header is JSON, and re-reading it reproduces the same container.
      expect(EncryptedBackup.decode(container.encode()).toJson(), container.toJson());
    });

    test('the written file carries neither the secret nor the plaintext', () async {
      final container = await _seal();
      final file = container.encode();
      final bytes = utf8.encode(file);

      expect(file, isNot(contains(_secret)));
      expect(file, isNot(contains('schema_version'))); // not the envelope
      expect(bytes, isNot(equals(utf8.encode(_plaintext))));
      expect(container.describe(), isNot(contains(_secret)));
      expect(container.toString(), isNot(contains(_secret)));
    });

    test('every call gets a fresh salt and nonce', () async {
      final first = await _seal();
      final second = await _seal();

      expect(first.kdfSalt, isNot(second.kdfSalt));
      expect(first.nonce, isNot(second.nonce));
      expect(first.ciphertext, isNot(second.ciphertext));
      // Both still decrypt: nothing is bound to a single ciphertext.
      expect(
        utf8.decode(await decryptBackup(first, recoverySecret: _secret)),
        _plaintext,
      );
      expect(
        utf8.decode(await decryptBackup(second, recoverySecret: _secret)),
        _plaintext,
      );
    });

    test('is byte-for-byte reproducible with injected salt and nonce', () async {
      final salt = Uint8List.fromList(List<int>.filled(kBackupSaltLength, 7));
      final nonce = Uint8List.fromList(List<int>.filled(kBackupNonceLength, 9));

      final first = await _seal(salt: salt, nonce: nonce);
      final second = await _seal(salt: salt, nonce: nonce);

      expect(first.encode(), second.encode());
      expect(first.kdfSalt, base64.encode(salt));
      expect(first.nonce, base64.encode(nonce));
    });

    test('round-trips with the full default iteration count', () async {
      final container = await _seal(iterations: kBackupKdfIterations);

      expect(kBackupKdfIterations, greaterThanOrEqualTo(100000));
      expect(container.kdfIterations, kBackupKdfIterations);
      expect(
        utf8.decode(await decryptBackup(container, recoverySecret: _secret)),
        _plaintext,
      );
    });
  });

  group('fail-closed rules', () {
    test('a wrong secret is refused', () async {
      final container = await _seal();

      await _expectRefused(
        container,
        BackupDecryptionFailure.wrongSecretOrTampered,
        secret: 'wrong horse battery staple',
      );
    });

    test('an empty secret cannot seal or open a backup', () async {
      await expectLater(_seal(secret: ''), throwsA(isA<ArgumentError>()));
      final container = await _seal();
      await expectLater(
        decryptBackup(container, recoverySecret: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('no refusal quotes the secret or any key material', () async {
      final container = await _seal();
      try {
        await decryptBackup(container, recoverySecret: 'wrong horse battery staple');
        fail('the wrong secret should have been refused');
      } on BackupDecryptionException catch (error) {
        expect(error.message, isNot(contains('wrong horse battery staple')));
        expect(error.toString(), isNot(contains('wrong horse battery staple')));
      }
      try {
        await _seal(secret: '');
        fail('an empty secret should have been refused');
      } on ArgumentError catch (error) {
        // An empty secret is never carried in the error either.
        expect(error.invalidValue, isNull);
      }
    });

    test('a tampered ciphertext, tag, nonce or salt is refused', () async {
      final container = await _seal();

      for (final field in <String>['ciphertext', 'tag', 'nonce', 'kdf_salt']) {
        await _expectRefused(
          _flip(container, field),
          BackupDecryptionFailure.wrongSecretOrTampered,
        );
      }
    });

    test('weakened KDF parameters are refused', () async {
      final container = await _seal(iterations: 4096);
      final json = container.toJson()..['kdf_iterations'] = 1;

      await _expectRefused(
        EncryptedBackup.fromJson(json),
        BackupDecryptionFailure.wrongSecretOrTampered,
      );
      // Same for a header the KDF does not read: it is authenticated too.
      final aged = container.toJson()..['created_at'] = 1;
      await _expectRefused(
        EncryptedBackup.fromJson(aged),
        BackupDecryptionFailure.wrongSecretOrTampered,
      );
      final renamed = container.toJson()..['app_version'] = '0.0.1';
      await _expectRefused(
        EncryptedBackup.fromJson(renamed),
        BackupDecryptionFailure.wrongSecretOrTampered,
      );
    });

    test('a tampered checksum is refused', () async {
      final container = await _seal();
      final json = container.toJson()
        ..['checksum'] = checksumOfBytes(utf8.encode('something else'));

      await _expectRefused(
        EncryptedBackup.fromJson(json),
        BackupDecryptionFailure.checksumMismatch,
      );
    });

    test('a newer container version is refused as unsupported', () async {
      final container = await _seal();
      final json = container.toJson()
        ..['format_version'] = kEncryptedBackupFormatVersion + 1;

      await _expectRefused(
        EncryptedBackup.fromJson(json),
        BackupDecryptionFailure.unsupportedVersion,
      );
    });

    test('a malformed file is refused before any decryption', () async {
      void expectMalformed(void Function() parse) => expect(
        parse,
        throwsA(
          isA<BackupDecryptionException>().having(
            (error) => error.failure,
            'failure',
            BackupDecryptionFailure.malformed,
          ),
        ),
      );

      expectMalformed(() => EncryptedBackup.decode('not json at all'));
      expectMalformed(() => EncryptedBackup.decode('[1,2,3]'));

      final container = await _seal();
      // A missing field, a wrong type and invalid base64 all land as malformed.
      expectMalformed(() => EncryptedBackup.fromJson(container.toJson()..remove('tag')));
      expectMalformed(
        () => EncryptedBackup.fromJson(container.toJson()..['kdf_iterations'] = 'lots'),
      );
      expectMalformed(
        () => EncryptedBackup.fromJson(container.toJson()..['nonce'] = 'not base64 !!'),
      );
      // A plain JSON envelope (or any other JSON file) is not a container.
      expectMalformed(
        () => EncryptedBackup.fromJson(
          jsonDecode('{"schema_version":1,"app_version":"0.0.228"}')
              as Map<String, dynamic>,
        ),
      );

      // Readable containers that declare the wrong parameters are refused at
      // decryption rather than at parse time.
      await _expectRefused(
        EncryptedBackup.fromJson(
          container.toJson()..['kdf_salt'] = base64.encode(const <int>[1, 2, 3]),
        ),
        BackupDecryptionFailure.malformed,
      );
      await _expectRefused(
        EncryptedBackup.fromJson(container.toJson()..['cipher'] = 'aes-128-cbc'),
        BackupDecryptionFailure.malformed,
      );
      await _expectRefused(
        EncryptedBackup.fromJson(container.toJson()..['kdf'] = 'scrypt'),
        BackupDecryptionFailure.malformed,
      );
    });
  });
}
