/// Diagnostic bundle for the Sync Status screen (Task 19 Phase 4).
///
/// A bundle is a snapshot of what the sync queue is doing, for support: the
/// entry list with its states, retry counts and last errors, plus the handful of
/// sync metadata values that say when the device last talked to the server. It is
/// **metadata only by default** — no payloads, so no case content leaves the
/// device — and including payloads is a separate, explicit consent the screen
/// asks for. Either way the result is written through Task 15 Phase 2's
/// authenticated container ([encryptBackup]), never as readable JSON, and the
/// bundle itself records its own expiry so the file cannot silently outlive its
/// usefulness (§12.3.1).
library;

import 'dart:convert';
import 'dart:typed_data';

import '../constants/app_version.dart';
import 'backup_cipher.dart';
import 'backup_format.dart';

/// Marker written into every bundle, so a reader knows what it is holding.
const String kDiagnosticBundleFormat = 'legal-case-diary-diagnostics';

/// The bundle layout version. Bump when a section's shape changes.
///
/// Version 2 added the app's own error log under `errors`.
const int kDiagnosticBundleFormatVersion = 2;

/// How long a bundle is expected to be kept: seven days.
///
/// The screen shows this in its reminder, and [buildDiagnosticBundle] records
/// the resulting instant, so the file states its own deletion date rather than
/// relying on whoever reads it to remember one.
const Duration diagnosticBundleRetention = Duration(days: 7);

/// The bundle's file extension. Deliberately not `.lcbak`: a diagnostics file is
/// not a restorable backup, and the restore picker must not offer it.
const String diagnosticBundleExtension = 'lcdiag';

/// Default bundle file name for an export taken at [generatedAt].
///
/// UTC `legal-case-diary-diagnostics-YYYYMMDD-HHMMSS.lcdiag`, matching the
/// backup naming convention so exported files sort together.
String defaultDiagnosticBundleFileName(int generatedAt) =>
    'legal-case-diary-diagnostics-${_fileStamp(generatedAt)}'
    '.$diagnosticBundleExtension';

/// One queue entry's diagnostic record.
typedef DiagnosticEntry = Map<String, dynamic>;

/// Builds the bundle's plaintext structure.
///
/// [entries] is the queue list to describe; [metadata] is a small map of
/// `sync_metadata` values the caller has already read (for example
/// `last_successful_sync_at`), so this function stays pure and testable. When
/// [includePayloads] is false the payload columns are **omitted entirely**
/// rather than blanked, so a metadata-only bundle carries no case content at
/// all.
///
/// [errors] is the app's own error log: the failures that never reached the
/// queue — a refused sign-in, a failed payment, a framework assertion. It is
/// metadata by construction, because an `ErrorLogEntry` holds a time, an area
/// and a redacted label, never a case field and never a raw server message.
Map<String, dynamic> buildDiagnosticBundle({
  required List<DiagnosticEntry> entries,
  required Map<String, String?> metadata,
  required bool includePayloads,
  required int generatedAt,
  List<DiagnosticEntry> errors = const <DiagnosticEntry>[],
}) => <String, dynamic>{
  'format': kDiagnosticBundleFormat,
  'format_version': kDiagnosticBundleFormatVersion,
  'app_version': appVersion,
  'generated_at': generatedAt,
  'expires_at': generatedAt + diagnosticBundleRetention.inMilliseconds,
  'includes_payloads': includePayloads,
  'counts': _stateCounts(entries),
  'metadata': metadata,
  'entries': entries,
  'errors': errors,
};

/// Describes one queue row for the bundle.
///
/// The metadata columns are always present because they are what a support
/// reader needs first; the payload columns appear only on explicit consent.
DiagnosticEntry diagnosticEntryFor({
  required String entityType,
  required String entityId,
  required String operation,
  required String state,
  required int retryCount,
  required int createdAt,
  int? lastAttemptAt,
  String? lastError,
  int? baseVersion,
  String? changedFields,
  String? basePayload,
  String? payload,
  String? preMutationPayload,
  required bool includePayloads,
}) => <String, dynamic>{
  'entity_type': entityType,
  'entity_id': entityId,
  'operation': operation,
  'state': state,
  'retry_count': retryCount,
  'created_at': createdAt,
  'last_attempt_at': lastAttemptAt,
  'last_error': lastError,
  if (includePayloads) ...<String, dynamic>{
    'base_version': baseVersion,
    'changed_fields': _decode(changedFields),
    'base_payload': _decode(basePayload),
    'payload': _decode(payload),
    'pre_mutation_payload': _decode(preMutationPayload),
  },
};

/// The written bundle: where it went, what it is, and how big it is.
class DiagnosticBundleResult {
  /// Creates a bundle result.
  const DiagnosticBundleResult({
    required this.path,
    required this.checksum,
    required this.bundle,
    required this.byteLength,
  });

  /// The location the platform reported for the saved file.
  final String path;

  /// SHA-256 of the exact bytes written, for support to verify against.
  final String checksum;

  /// The plaintext structure that was sealed, kept for tests and for the
  /// screen's confirmation text.
  final Map<String, dynamic> bundle;

  /// Size of the encrypted file in bytes.
  final int byteLength;
}

/// Seals [bundle] and writes it through [write].
///
/// The container is the same authenticated format every other export uses, so a
/// bundle cannot be produced unencrypted; [recoverySecret] must therefore be
/// non-empty ([encryptBackup] enforces it). [kdfIterations] is injectable so a
/// test need not pay a full PBKDF2 stretch.
Future<DiagnosticBundleResult> exportDiagnosticBundle({
  required Map<String, dynamic> bundle,
  required String recoverySecret,
  required Future<String> Function({
    required String fileName,
    required Uint8List bytes,
  })
  write,
  int? generatedAt,
  String? fileName,
  int kdfIterations = kBackupKdfIterations,
}) async {
  final stamp = generatedAt ?? DateTime.now().toUtc().millisecondsSinceEpoch;
  final container = await encryptBackup(
    plaintext: utf8.encode(jsonEncode(bundle)),
    recoverySecret: recoverySecret,
    appVersion: appVersion,
    createdAt: stamp,
    iterations: kdfIterations,
  );
  final bytes = Uint8List.fromList(utf8.encode(container.encode()));
  final path = await write(
    fileName: fileName ?? defaultDiagnosticBundleFileName(stamp),
    bytes: bytes,
  );
  return DiagnosticBundleResult(
    path: path,
    checksum: checksumOfBytes(bytes),
    bundle: bundle,
    byteLength: bytes.length,
  );
}

/// Entry counts per queue state, so the bundle answers "how bad is it?" first.
Map<String, int> _stateCounts(List<DiagnosticEntry> entries) {
  final counts = <String, int>{};
  for (final entry in entries) {
    final state = entry['state'];
    if (state is! String) continue;
    counts[state] = (counts[state] ?? 0) + 1;
  }
  return counts;
}

/// Parses a stored JSON column for readability, keeping the raw text when it is
/// not JSON at all (an empty snapshot, say).
Object? _decode(String? json) {
  if (json == null || json.isEmpty) return null;
  try {
    return jsonDecode(json);
  } on FormatException {
    return json;
  }
}

/// UTC `YYYYMMDD-HHMMSS`, the stamp the bundle's default file name carries.
String _fileStamp(int at) {
  final stamp = DateTime.fromMillisecondsSinceEpoch(at, isUtc: true);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${stamp.year}${two(stamp.month)}${two(stamp.day)}'
      '-${two(stamp.hour)}${two(stamp.minute)}${two(stamp.second)}';
}
