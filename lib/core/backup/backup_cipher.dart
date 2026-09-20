/// Authenticated-encrypted backup container (Task 15 Phase 2).
///
/// **Pure Dart:** no Flutter, no Drift, no plugins. The container *wraps* the
/// versioned envelope from `backup_format.dart`: the envelope's bytes are the
/// plaintext, so the restore path (Phase 3) decrypts first, authenticates, and
/// only then decodes the envelope inside. Plan §12.3.1 requires exactly this
/// shape — versioned header, KDF parameters, nonce, ciphertext, authentication
/// tag and checksum — because a plaintext export must never reach shared
/// storage.
///
/// Key material rules (Plan §12.3.1): the recovery secret is **never** stored,
/// logged, put in an exception or written into the file. Only the KDF's public
/// parameters (algorithm, iteration count, salt) and the AEAD's public nonce go
/// into the header; the derived key lives for the length of one call and is
/// zeroed afterwards.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'backup_format.dart';

/// Marker written in the container's `format` header field.
const String kEncryptedBackupFormat = 'legal-case-diary-encrypted-backup';

/// Format version of the container (its own version, independent of
/// [kBackupSchemaVersion], which versions the payload inside).
const int kEncryptedBackupFormatVersion = 1;

/// KDF named in the container header.
const String kBackupKdfName = 'pbkdf2-hmac-sha256';

/// AEAD cipher named in the container header.
const String kBackupCipherName = 'aes-256-gcm';

/// Derived key length in bits — AES-256.
const int kBackupKeyBits = 256;

/// PBKDF2 iteration count used by this build.
///
/// OWASP's PBKDF2-HMAC-SHA256 floor for stored passwords is 600k, which costs
/// several seconds in pure Dart on a mid-range phone; 210k is OWASP's earlier
/// recommendation and keeps one export near a second on the host. The count
/// travels in the file, so a later build can raise it without breaking existing
/// backups.
/// ponytail: pure-Dart KDF. Measured ~1 s per export on the host VM, so a low-end
/// phone will take a few seconds and the export must show progress rather than
/// block a frame. Upgrade path, no format change needed: derive on a worker
/// isolate, or switch to `cryptography_flutter`'s platform implementation.
const int kBackupKdfIterations = 210000;

/// Salt length in bytes for the KDF.
const int kBackupSaltLength = 16;

/// Nonce length in bytes for AES-GCM (the mode's standard 96-bit nonce).
const int kBackupNonceLength = 12;

/// Why a backup could not be decrypted. Every case fails closed: no bytes are
/// ever returned for a file that does not authenticate.
enum BackupDecryptionFailure {
  /// The file is not a container, or a header field is missing/invalid.
  malformed,

  /// The container's format version is newer than this build understands.
  unsupportedVersion,

  /// The AEAD tag did not verify: wrong recovery secret, or the ciphertext,
  /// nonce, salt, KDF parameters or authenticated header were altered.
  wrongSecretOrTampered,

  /// The plaintext authenticated but does not match the header's checksum.
  /// Redundant with the AEAD on purpose — the record of *what* was exported is
  /// checked against the bytes that came back before any import can start.
  checksumMismatch,
}

/// Thrown when [decryptBackup] refuses a file.
///
/// The [message] is built here and is deliberately not localized: Phase 3's UI
/// maps [failure] to a localized string. Neither the message nor
/// [toString] ever carries the recovery secret or derived key material.
class BackupDecryptionException implements Exception {
  /// Which fail-closed rule rejected the file.
  final BackupDecryptionFailure failure;

  /// Human-readable detail for logs; never contains secret material.
  final String message;

  /// Creates the exception for a rejected file.
  const BackupDecryptionException(this.failure, this.message);

  @override
  String toString() =>
      'BackupDecryptionException(${failure.name}): $message';
}

/// The authenticated-encrypted backup file: a versioned header plus the
/// encrypted envelope.
class EncryptedBackup {
  /// Container format marker (`format` header field).
  final String format;

  /// Container format version (`format_version` header field).
  final int formatVersion;

  /// App version that wrote the file (`app_version` header field).
  final String appVersion;

  /// Export time in epoch milliseconds (`created_at` header field).
  final int createdAt;

  /// KDF name (`kdf` header field).
  final String kdf;

  /// KDF iteration count (`kdf_iterations` header field).
  final int kdfIterations;

  /// Base64 KDF salt (`kdf_salt` header field).
  final String kdfSalt;

  /// Cipher name (`cipher` header field).
  final String cipher;

  /// Base64 AES-GCM nonce (`nonce` header field).
  final String nonce;

  /// Base64 ciphertext (`ciphertext` header field).
  final String ciphertext;

  /// Base64 AES-GCM authentication tag (`tag` header field).
  final String tag;

  /// SHA-256 of the plaintext envelope, hex-encoded (`checksum` field).
  final String checksum;

  /// Creates a container from already-encoded parts.
  const EncryptedBackup({
    required this.format,
    required this.formatVersion,
    required this.appVersion,
    required this.createdAt,
    required this.kdf,
    required this.kdfIterations,
    required this.kdfSalt,
    required this.cipher,
    required this.nonce,
    required this.ciphertext,
    required this.tag,
    required this.checksum,
  });

  /// Parses a container, rejecting anything malformed.
  ///
  /// Throws [BackupDecryptionException] with [BackupDecryptionFailure.malformed]
  /// when the text is not a container or a field is missing, of the wrong type,
  /// or not valid base64 — a file that cannot be read is a file that cannot be
  /// restored, so it is refused here rather than half-read.
  factory EncryptedBackup.fromJson(Map<String, dynamic> json) {
    String stringField(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw BackupDecryptionException(
          BackupDecryptionFailure.malformed,
          'Backup container has no valid "$key".',
        );
      }
      return value;
    }

    int intField(String key) {
      final value = json[key];
      if (value is! int || value < 0) {
        throw BackupDecryptionException(
          BackupDecryptionFailure.malformed,
          'Backup container has no valid "$key".',
        );
      }
      return value;
    }

    void requireBase64(String key, String value) {
      try {
        base64.decode(value);
      } on FormatException {
        throw BackupDecryptionException(
          BackupDecryptionFailure.malformed,
          'Backup container field "$key" is not valid base64.',
        );
      }
    }

    final container = EncryptedBackup(
      format: stringField('format'),
      formatVersion: intField('format_version'),
      appVersion: stringField('app_version'),
      createdAt: intField('created_at'),
      kdf: stringField('kdf'),
      kdfIterations: intField('kdf_iterations'),
      kdfSalt: stringField('kdf_salt'),
      cipher: stringField('cipher'),
      nonce: stringField('nonce'),
      ciphertext: stringField('ciphertext'),
      tag: stringField('tag'),
      checksum: stringField('checksum'),
    );
    requireBase64('kdf_salt', container.kdfSalt);
    requireBase64('nonce', container.nonce);
    requireBase64('ciphertext', container.ciphertext);
    requireBase64('tag', container.tag);
    return container;
  }

  /// Decodes the container's JSON text.
  factory EncryptedBackup.decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const BackupDecryptionException(
        BackupDecryptionFailure.malformed,
        'Backup file is not a container.',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const BackupDecryptionException(
        BackupDecryptionFailure.malformed,
        'Backup file is not a container.',
      );
    }
    return EncryptedBackup.fromJson(decoded);
  }

  /// The header fields the AEAD authenticates (everything except the ciphertext,
  /// the tag — which *is* the authentication — and the checksum, which is
  /// checked against the decrypted plaintext so the two failures stay
  /// distinguishable).
  Map<String, dynamic> authenticatedHeader() => <String, dynamic>{
    'format': format,
    'format_version': formatVersion,
    'app_version': appVersion,
    'created_at': createdAt,
    'kdf': kdf,
    'kdf_iterations': kdfIterations,
    'kdf_salt': kdfSalt,
    'cipher': cipher,
    'nonce': nonce,
  };

  /// The container as a JSON map, in a stable key order.
  Map<String, dynamic> toJson() => <String, dynamic>{
    ...authenticatedHeader(),
    'ciphertext': ciphertext,
    'tag': tag,
    'checksum': checksum,
  };

  /// Serializes the container for writing to disk.
  String encode() => jsonEncode(toJson());

  /// Salt bytes, or null when the header's base64 is invalid.
  Uint8List? get saltBytes => _tryBase64(kdfSalt);

  /// Nonce bytes, or null when the header's base64 is invalid.
  Uint8List? get nonceBytes => _tryBase64(nonce);

  /// A one-line description safe for logs and diagnostics: the public header
  /// only, so no salt, nonce, ciphertext or key material can leak through it.
  String describe() =>
      '$format v$formatVersion ($cipher, $kdf × $kdfIterations, '
      '${ciphertext.length} b64 ciphertext) from app $appVersion';

  @override
  String toString() => 'EncryptedBackup(${describe()})';
}

/// Encrypts [plaintext] into an authenticated container (§12.3.1).
///
/// The key is derived from [recoverySecret] with PBKDF2-HMAC-SHA256 over a fresh
/// random salt, and the payload is sealed with AES-256-GCM over a fresh random
/// nonce; both randomness sources are injectable so tests can pin them.
///
/// Throws [ArgumentError] for an empty secret — an empty passphrase is an
/// unencrypted file. The error deliberately quotes no part of the secret.
Future<EncryptedBackup> encryptBackup({
  required List<int> plaintext,
  required String recoverySecret,
  required String appVersion,
  required int createdAt,
  int iterations = kBackupKdfIterations,
  List<int>? salt,
  List<int>? nonce,
  Random? random,
}) async {
  if (recoverySecret.isEmpty) {
    throw ArgumentError(
      'A backup recovery secret must not be empty; an empty secret would '
      'leave the export unprotected.',
    );
  }
  if (iterations < 1) {
    throw ArgumentError.value(iterations, 'iterations');
  }

  final saltBytes = salt == null
      ? _randomBytes(kBackupSaltLength, random)
      : _expectLength(salt, kBackupSaltLength, 'salt');
  final nonceBytes = nonce == null
      ? _randomBytes(kBackupNonceLength, random)
      : _expectLength(nonce, kBackupNonceLength, 'nonce');

  // The header is built first because it is the AEAD's associated data, so its
  // KDF parameters, format version and nonce are authenticated along with the
  // ciphertext and cannot be swapped for weaker ones.
  final header = <String, dynamic>{
    'format': kEncryptedBackupFormat,
    'format_version': kEncryptedBackupFormatVersion,
    'app_version': appVersion,
    'created_at': createdAt,
    'kdf': kBackupKdfName,
    'kdf_iterations': iterations,
    'kdf_salt': base64.encode(saltBytes),
    'cipher': kBackupCipherName,
    'nonce': base64.encode(nonceBytes),
  };

  final key = await _deriveKey(
    recoverySecret: recoverySecret,
    salt: saltBytes,
    iterations: iterations,
  );
  try {
    final box = await AesGcm.with256bits().encrypt(
      plaintext,
      secretKey: key,
      nonce: nonceBytes,
      aad: utf8.encode(jsonEncode(header)),
    );
    return EncryptedBackup(
      format: header['format'] as String,
      formatVersion: header['format_version'] as int,
      appVersion: appVersion,
      createdAt: createdAt,
      kdf: header['kdf'] as String,
      kdfIterations: iterations,
      kdfSalt: header['kdf_salt'] as String,
      cipher: header['cipher'] as String,
      nonce: header['nonce'] as String,
      ciphertext: base64.encode(box.cipherText),
      tag: base64.encode(box.mac.bytes),
      checksum: checksumOfBytes(plaintext),
    );
  } finally {
    key.destroy();
  }
}

/// Decrypts and authenticates [container] with [recoverySecret].
///
/// Fails **closed**: any header, KDF, tag or checksum problem throws
/// [BackupDecryptionException] and returns no bytes, so a corrupted or
/// tampered file can never be half-imported.
Future<Uint8List> decryptBackup(
  EncryptedBackup container, {
  required String recoverySecret,
}) async {
  if (recoverySecret.isEmpty) {
    throw ArgumentError(
      'A backup recovery secret must not be empty; an empty secret would '
      'leave the export unprotected.',
    );
  }
  if (container.format != kEncryptedBackupFormat) {
    throw BackupDecryptionException(
      BackupDecryptionFailure.malformed,
      'File is not a $kEncryptedBackupFormat container.',
    );
  }
  if (container.formatVersion > kEncryptedBackupFormatVersion) {
    throw BackupDecryptionException(
      BackupDecryptionFailure.unsupportedVersion,
      'Backup container version ${container.formatVersion} is newer than the '
      'supported version $kEncryptedBackupFormatVersion.',
    );
  }
  if (container.formatVersion < 1 ||
      container.kdf != kBackupKdfName ||
      container.cipher != kBackupCipherName ||
      container.kdfIterations < 1) {
    throw const BackupDecryptionException(
      BackupDecryptionFailure.malformed,
      'Backup container declares an unsupported KDF or cipher.',
    );
  }

  final saltBytes = container.saltBytes;
  final nonceBytes = container.nonceBytes;
  if (saltBytes == null || nonceBytes == null) {
    throw const BackupDecryptionException(
      BackupDecryptionFailure.malformed,
      'Backup container has invalid base64 key parameters.',
    );
  }
  if (saltBytes.length != kBackupSaltLength ||
      nonceBytes.length != kBackupNonceLength) {
    throw const BackupDecryptionException(
      BackupDecryptionFailure.malformed,
      'Backup container has malformed key parameters.',
    );
  }

  final key = await _deriveKey(
    recoverySecret: recoverySecret,
    salt: saltBytes,
    iterations: container.kdfIterations,
  );
  final Uint8List plaintext;
  try {
    final List<int> clear;
    try {
      clear = await AesGcm.with256bits().decrypt(
        SecretBox(
          base64.decode(container.ciphertext),
          nonce: nonceBytes,
          mac: Mac(base64.decode(container.tag)),
        ),
        secretKey: key,
        aad: utf8.encode(jsonEncode(container.authenticatedHeader())),
      );
    } on SecretBoxAuthenticationError {
      throw const BackupDecryptionException(
        BackupDecryptionFailure.wrongSecretOrTampered,
        'Backup did not authenticate: the recovery secret is wrong or the '
        'file has been altered.',
      );
    }
    plaintext = Uint8List.fromList(clear);
  } finally {
    key.destroy();
  }

  if (checksumOfBytes(plaintext) != container.checksum) {
    throw const BackupDecryptionException(
      BackupDecryptionFailure.checksumMismatch,
      'Backup decrypted but its contents do not match the recorded checksum.',
    );
  }
  return plaintext;
}

/// Derives the 256-bit AEAD key from [recoverySecret], zeroing the secret's
/// bytes afterwards so the only long-lived copy is the key itself.
Future<SecretKeyData> _deriveKey({
  required String recoverySecret,
  required Uint8List salt,
  required int iterations,
}) async {
  final secretBytes = Uint8List.fromList(utf8.encode(recoverySecret));
  try {
    final derived = await Pbkdf2.hmacSha256(
      iterations: iterations,
      bits: kBackupKeyBits,
    ).deriveKey(secretKey: SecretKey(secretBytes), nonce: salt);
    // The KDF's own key object shares its backing list with whatever reads it,
    // so the key this function returns keeps a private copy: destroying the
    // derived key must not empty the one the cipher is about to use.
    final key = SecretKeyData(
      Uint8List.fromList(await derived.extractBytes()),
      overwriteWhenDestroyed: true,
    );
    derived.destroy();
    return key;
  } finally {
    secretBytes.fillRange(0, secretBytes.length, 0);
  }
}

/// Decodes base64, or null when [value] is not valid base64.
Uint8List? _tryBase64(String value) {
  try {
    return base64.decode(value);
  } on FormatException {
    return null;
  }
}

/// [length] random bytes from the OS CSPRNG.
Uint8List _randomBytes(int length, Random? random) {
  final source = random ?? Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => source.nextInt(256)),
  );
}

/// Validates an injected salt/nonce length.
Uint8List _expectLength(List<int> bytes, int length, String name) {
  if (bytes.length != length) {
    throw ArgumentError.value(bytes.length, name, 'must be $length bytes');
  }
  return Uint8List.fromList(bytes);
}
