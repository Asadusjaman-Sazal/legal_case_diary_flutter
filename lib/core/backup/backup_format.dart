/// Versioned JSON backup envelope — the canonical local snapshot format.
///
/// **Pure Dart:** no Flutter, no Drift, no plugins, so the format, its checksum
/// and its version rules are unit-testable and shared by every export the app
/// performs — the manual Backup to Local Storage and, in Part B, the logout
/// auto-export and the extended-offline safety archive (Sync Plan §5 requires
/// those paths to produce exactly this one format).
///
/// This file owns only the *outer* JSON document. Phase 2 wraps its serialized
/// bytes in the authenticated-encrypted container, so nothing here knows about
/// keys or ciphers.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Schema version of the envelope this build writes.
///
/// Bump when the payload shape changes. [BackupEnvelope.fromJson] accepts any
/// version from 1 up to this one and Phase 3's per-version adapters upgrade the
/// older ones, so a future schema change never breaks an existing backup.
const int kBackupSchemaVersion = 1;

/// Top-level payload section holding the per-table row snapshot.
const String kBackupTablesSection = 'tables';

/// Thrown when a file was written by a newer app build than this one.
///
/// The message is intentionally built here (not localized): the UI layer maps
/// this exception to a localized string when it reports the refusal.
class UnsupportedBackupVersionException implements Exception {
  /// Version found in the file.
  final int foundVersion;

  /// Highest version this build can restore.
  final int supportedVersion;

  /// Creates the exception for the two versions involved.
  const UnsupportedBackupVersionException({
    required this.foundVersion,
    required this.supportedVersion,
  });

  @override
  String toString() =>
      'Backup schema version $foundVersion is newer than the supported '
      'version $supportedVersion.';
}

/// A versioned, checksummed snapshot of the whole local app state.
class BackupEnvelope {
  /// Envelope schema version (`schema_version` key).
  final int schemaVersion;

  /// App version that produced the snapshot (`app_version` key).
  final String appVersion;

  /// Export time in epoch milliseconds (`exported_at` key).
  final int exportedAt;

  /// SHA-256 of the payload's JSON encoding (`checksum` key).
  final String checksum;

  /// Full snapshot payload; [kBackupTablesSection] holds the per-table rows.
  final Map<String, dynamic> payload;

  /// Creates an envelope with an already-computed [checksum].
  const BackupEnvelope({
    required this.schemaVersion,
    required this.appVersion,
    required this.exportedAt,
    required this.checksum,
    required this.payload,
  });

  /// Builds an envelope for [payload], computing its checksum.
  factory BackupEnvelope.create({
    required String appVersion,
    required int exportedAt,
    required Map<String, dynamic> payload,
    int schemaVersion = kBackupSchemaVersion,
  }) => BackupEnvelope(
    schemaVersion: schemaVersion,
    appVersion: appVersion,
    exportedAt: exportedAt,
    checksum: checksumOfPayload(payload),
    payload: payload,
  );

  /// Parses an envelope, rejecting a malformed or newer-than-supported file.
  ///
  /// Throws [FormatException] when a required field is missing or of the wrong
  /// type, and [UnsupportedBackupVersionException] when the file was written by
  /// a newer build.
  factory BackupEnvelope.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schema_version'];
    if (schemaVersion is! int || schemaVersion < 1) {
      throw const FormatException('Backup is missing a valid schema version.');
    }
    if (schemaVersion > kBackupSchemaVersion) {
      throw UnsupportedBackupVersionException(
        foundVersion: schemaVersion,
        supportedVersion: kBackupSchemaVersion,
      );
    }

    final appVersion = json['app_version'];
    final exportedAt = json['exported_at'];
    final checksum = json['checksum'];
    final payload = json['payload'];
    if (appVersion is! String ||
        exportedAt is! int ||
        checksum is! String ||
        payload is! Map<String, dynamic>) {
      throw const FormatException('Backup is missing required envelope fields.');
    }

    return BackupEnvelope(
      schemaVersion: schemaVersion,
      appVersion: appVersion,
      exportedAt: exportedAt,
      checksum: checksum,
      payload: payload,
    );
  }

  /// Decodes the file's JSON text into an envelope.
  factory BackupEnvelope.decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup file is not a JSON object.');
    }
    return BackupEnvelope.fromJson(decoded);
  }

  /// The envelope as a JSON map, in a stable key order.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'schema_version': schemaVersion,
    'app_version': appVersion,
    'exported_at': exportedAt,
    'checksum': checksum,
    'payload': payload,
  };

  /// Serializes the envelope for writing to disk.
  ///
  /// The payload's key order is preserved through a decode, so re-encoding a
  /// restored envelope reproduces the same bytes and the same checksum.
  String encode() => jsonEncode(toJson());

  /// Recomputes the payload checksum and compares it to the stored one.
  bool verifyChecksum() => checksum == checksumOfPayload(payload);

  /// The per-table row snapshot, or an empty map when the payload has none.
  Map<String, dynamic> get tables {
    final raw = payload[kBackupTablesSection];
    return raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
  }
}

/// SHA-256 of the payload's JSON encoding, hex-encoded.
String checksumOfPayload(Map<String, dynamic> payload) =>
    checksumOfBytes(utf8.encode(jsonEncode(payload)));

/// SHA-256 of arbitrary bytes, hex-encoded.
///
/// Used for the payload checksum and, once Phase 2 encrypts the file, for the
/// checksum recorded against the written archive.
String checksumOfBytes(List<int> bytes) =>
    sha256.convert(bytes).toString();
