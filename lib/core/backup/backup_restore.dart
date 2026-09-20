/// Opening a backup file for restore (Task 15 Phase 3).
///
/// **Pure Dart:** no Flutter, no Drift, no plugins, so the whole "can this file
/// be trusted?" chain is unit-testable and identical for every restore path.
/// The order is fixed and matters: parse → **decrypt and authenticate** →
/// verify the envelope's checksum → refuse a newer schema version → run the
/// per-version payload adapters → hand the caller a validated payload. Nothing
/// in this file touches the database, so a file that fails any step cannot have
/// half-imported anything.
///
/// Table/column validation deliberately lives with the database code that builds
/// the `INSERT` statements (see `features/settings/data/backup_repository.dart`),
/// because that is where the schema's table list already is.
library;

import 'dart:convert';

import 'backup_cipher.dart';
import 'backup_format.dart';

/// How a backup file was written.
enum BackupFileKind {
  /// The Phase 2 authenticated-encrypted container (this build's format).
  encrypted,

  /// A plaintext JSON envelope written by a build before encryption existed
  /// (0.0.227 and earlier). Still restorable — it is a real user's only copy —
  /// but the caller should say that it was never encrypted.
  legacyPlaintext,
}

/// Why a backup could not be opened or imported.
///
/// Every value is a distinct user-facing message once Phase 4's screen maps it
/// to a localized string; no value ever carries the recovery secret, key
/// material or case data.
enum BackupRestoreFailure {
  /// Not a backup file: unreadable JSON, no recognizable envelope, or a
  /// container whose own header declares KDF/cipher parameters this build
  /// cannot use.
  invalidFile,

  /// Written by a newer build — either the container format or the payload
  /// schema is beyond what this app version understands.
  unsupportedVersion,

  /// The AEAD tag did not verify: wrong recovery passphrase, or the file was
  /// altered (ciphertext, tag, nonce, salt, header field).
  wrongSecretOrTampered,

  /// The file authenticated but is internally inconsistent — a payload checksum
  /// that disagrees, no table snapshot, an unknown or malformed table, a column
  /// name that is not part of the schema, or a value that is not a SQLite
  /// scalar.
  damagedFile,

  /// The database already holds data and the caller has not been told to
  /// replace it. Nothing was written; the caller asks the user, then either
  /// cancels or calls again with `replaceExisting: true`.
  conflictNeedsConfirmation,

  /// The import transaction failed and was rolled back completely; the database
  /// is exactly as it was before the attempt.
  importFailed,
}

/// Thrown when a backup cannot be opened or imported.
///
/// [message] is diagnostics-oriented and never localized — Phase 4 maps
/// [failure] to a localized string and never shows this text to the user.
class BackupRestoreException implements Exception {
  /// Which rule rejected the file or the import.
  final BackupRestoreFailure failure;

  /// Human-readable detail for logs; contains no secret and no case data.
  final String message;

  /// Creates the exception for a rejected file or a failed import.
  const BackupRestoreException(this.failure, this.message);

  @override
  String toString() => 'BackupRestoreException(${failure.name}): $message';
}

/// A backup file that has been decrypted, authenticated, upgraded and accepted.
class OpenedBackup {
  /// How the file was written.
  final BackupFileKind kind;

  /// Payload schema version as read from the file (before any upgrade).
  final int schemaVersion;

  /// App version that produced the file.
  final String appVersion;

  /// Export time in epoch milliseconds.
  final int exportedAt;

  /// The payload after the per-version adapters ran.
  final Map<String, dynamic> payload;

  /// Creates an opened backup.
  const OpenedBackup({
    required this.kind,
    required this.schemaVersion,
    required this.appVersion,
    required this.exportedAt,
    required this.payload,
  });

  /// The payload's per-table row snapshot, or an empty map when it has none.
  Map<String, dynamic> get tables {
    final raw = payload[kBackupTablesSection];
    return raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
  }
}

/// Transforms a payload from one schema version to the next.
typedef BackupPayloadAdapter =
    Map<String, dynamic> Function(Map<String, dynamic> payload);

/// Payload adapters, keyed by the version they upgrade **from**.
///
/// Empty at schema version 1: there is nothing older to upgrade yet. Every
/// future bump of [kBackupSchemaVersion] that changes the payload shape adds its
/// adapter here, and `migrateBackupPayload` refuses (rather than guesses) when a
/// step in the chain is missing.
const Map<int, BackupPayloadAdapter> backupPayloadAdapters =
    <int, BackupPayloadAdapter>{};

/// Upgrades [payload] from [fromVersion] to [toVersion], one adapter per step.
///
/// Throws [BackupRestoreException] with
/// [BackupRestoreFailure.unsupportedVersion] when a step has no adapter, so an
/// unknown shape is never imported half-upgraded.
Map<String, dynamic> migrateBackupPayload(
  Map<String, dynamic> payload, {
  required int fromVersion,
  int toVersion = kBackupSchemaVersion,
  Map<int, BackupPayloadAdapter> adapters = backupPayloadAdapters,
}) {
  var current = payload;
  for (var version = fromVersion; version < toVersion; version++) {
    final adapter = adapters[version];
    if (adapter == null) {
      throw BackupRestoreException(
        BackupRestoreFailure.unsupportedVersion,
        'This build has no upgrade path from backup schema version $version, '
        'so the file cannot be restored here.',
      );
    }
    current = adapter(current);
  }
  return current;
}

/// Opens [bytes] as a backup file: decrypt, authenticate, verify, upgrade.
///
/// [recoverySecret] is used only when the file is an encrypted container; a
/// legacy plaintext envelope needs no secret, so callers may pass whatever the
/// user typed.
///
/// [adapters] and [targetSchemaVersion] are injectable so the upgrade chain can
/// be exercised before a second schema version exists.
///
/// Throws [BackupRestoreException] for every reason in [BackupRestoreFailure]
/// except the two database-side ones ([BackupRestoreFailure.conflictNeedsConfirmation]
/// and [BackupRestoreFailure.importFailed], which the repository raises).
Future<OpenedBackup> openBackupFile({
  required List<int> bytes,
  required String recoverySecret,
  Map<int, BackupPayloadAdapter> adapters = backupPayloadAdapters,
  int targetSchemaVersion = kBackupSchemaVersion,
}) async {
  final document = _parseJsonObject(bytes);
  final BackupFileKind kind;
  final BackupEnvelope envelope;
  if (document['format'] == kEncryptedBackupFormat) {
    kind = BackupFileKind.encrypted;
    envelope = await _openEncrypted(document, recoverySecret);
  } else {
    kind = BackupFileKind.legacyPlaintext;
    envelope = _openLegacyEnvelope(document);
  }

  // Redundant with the AEAD for an encrypted file (the container's own checksum
  // covers the same bytes) but it is the only integrity check a legacy plaintext
  // file has, so it always runs.
  if (!envelope.verifyChecksum()) {
    throw const BackupRestoreException(
      BackupRestoreFailure.damagedFile,
      'The backup contents do not match the checksum recorded with them.',
    );
  }

  return OpenedBackup(
    kind: kind,
    schemaVersion: envelope.schemaVersion,
    appVersion: envelope.appVersion,
    exportedAt: envelope.exportedAt,
    payload: migrateBackupPayload(
      envelope.payload,
      fromVersion: envelope.schemaVersion,
      toVersion: targetSchemaVersion,
      adapters: adapters,
    ),
  );
}

/// Decodes the file's bytes into a JSON object.
Map<String, dynamic> _parseJsonObject(List<int> bytes) {
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
  } on FormatException {
    throw const BackupRestoreException(
      BackupRestoreFailure.invalidFile,
      'The selected file is not readable JSON.',
    );
  }
  if (decoded is! Map<String, dynamic>) {
    throw const BackupRestoreException(
      BackupRestoreFailure.invalidFile,
      'The selected file is not a backup document.',
    );
  }
  return decoded;
}

/// Decrypts and authenticates an encrypted container, then reads the envelope.
Future<BackupEnvelope> _openEncrypted(
  Map<String, dynamic> document,
  String recoverySecret,
) async {
  final EncryptedBackup container;
  try {
    container = EncryptedBackup.fromJson(document);
  } on BackupDecryptionException catch (error) {
    throw BackupRestoreException(
      BackupRestoreFailure.invalidFile,
      'The backup container header is not usable: ${error.message}',
    );
  }

  final List<int> plaintext;
  try {
    plaintext = await decryptBackup(container, recoverySecret: recoverySecret);
  } on BackupDecryptionException catch (error) {
    throw BackupRestoreException(
      switch (error.failure) {
        // A header this build cannot use is not a backup file it can open.
        BackupDecryptionFailure.malformed => BackupRestoreFailure.invalidFile,
        BackupDecryptionFailure.unsupportedVersion =>
          BackupRestoreFailure.unsupportedVersion,
        BackupDecryptionFailure.wrongSecretOrTampered =>
          BackupRestoreFailure.wrongSecretOrTampered,
        // A decrypted plaintext that disagrees with the recorded checksum is
        // damage, not a bad passphrase: the tag already proved the secret.
        BackupDecryptionFailure.checksumMismatch =>
          BackupRestoreFailure.damagedFile,
      },
      error.message,
    );
  }
  return _envelopeFromJson(_parseJsonObject(plaintext));
}

/// Reads a plaintext envelope written before encryption existed.
BackupEnvelope _openLegacyEnvelope(Map<String, dynamic> document) =>
    _envelopeFromJson(document);

/// Builds the envelope from already-decoded JSON, mapping its version refusal.
BackupEnvelope _envelopeFromJson(Map<String, dynamic> decoded) {
  try {
    return BackupEnvelope.fromJson(decoded);
  } on UnsupportedBackupVersionException catch (error) {
    throw BackupRestoreException(
      BackupRestoreFailure.unsupportedVersion,
      error.toString(),
    );
  } on FormatException catch (error) {
    throw BackupRestoreException(
      BackupRestoreFailure.invalidFile,
      error.message,
    );
  }
}
