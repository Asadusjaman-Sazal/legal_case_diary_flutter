/// Tests for the diagnostic bundle (Task 19 Phase 4).
///
/// The two things the plan is explicit about are what these pin: the bundle is
/// **metadata only** unless payloads were explicitly consented to, and the file
/// that reaches the disk is the authenticated container rather than readable
/// JSON — so an unencrypted export is not a code path that exists.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/backup/backup_cipher.dart';
import 'package:legal_case_diary/core/backup/diagnostic_bundle.dart';

/// One queue row's diagnostic record, with every column available.
Map<String, dynamic> _entry({required bool includePayloads}) =>
    diagnosticEntryFor(
      entityType: 'case',
      entityId: 'c1',
      operation: 'update',
      state: 'blocked',
      retryCount: 4,
      createdAt: 1000,
      lastAttemptAt: 2000,
      lastError: 'permission_denied',
      baseVersion: 2,
      changedFields: '["case_number"]',
      basePayload: '{"id":"c1","case_number":"000"}',
      payload: '{"id":"c1","case_number":"123"}',
      preMutationPayload: '{"id":"c1","case_number":"000"}',
      includePayloads: includePayloads,
    );

void main() {
  test('a metadata-only bundle carries no payload column at all', () {
    final bundle = buildDiagnosticBundle(
      entries: [_entry(includePayloads: false)],
      metadata: const {'last_successful_sync_at': '99'},
      includePayloads: false,
      generatedAt: 5000,
    );

    final entry = (bundle['entries'] as List).single as Map<String, dynamic>;
    // Omitted, not blanked: a metadata-only bundle must hold no case content.
    expect(entry.keys, isNot(contains('payload')));
    expect(entry.keys, isNot(contains('base_payload')));
    expect(entry.keys, isNot(contains('changed_fields')));
    expect(entry.keys, isNot(contains('pre_mutation_payload')));
    // The columns a support reader needs first are always present.
    expect(entry['state'], 'blocked');
    expect(entry['retry_count'], 4);
    expect(entry['last_attempt_at'], 2000);
    expect(entry['last_error'], 'permission_denied');
  });

  test('payloads appear only when consented, decoded for the reader', () {
    final bundle = buildDiagnosticBundle(
      entries: [_entry(includePayloads: true)],
      metadata: const {},
      includePayloads: true,
      generatedAt: 5000,
    );

    final entry = (bundle['entries'] as List).single as Map<String, dynamic>;
    expect(entry['payload'], <String, dynamic>{
      'id': 'c1',
      'case_number': '123',
    });
    expect(entry['changed_fields'], <String>['case_number']);
    expect(entry['base_version'], 2);
    expect(bundle['includes_payloads'], true);
  });

  test('the bundle counts states and states its own expiry', () {
    final bundle = buildDiagnosticBundle(
      entries: [
        _entry(includePayloads: false),
        diagnosticEntryFor(
          entityType: 'note',
          entityId: 'n1',
          operation: 'update',
          state: 'conflict_pending',
          retryCount: 1,
          createdAt: 1000,
          includePayloads: false,
        ),
      ],
      metadata: const {},
      includePayloads: false,
      generatedAt: 5000,
    );

    expect(bundle['format'], kDiagnosticBundleFormat);
    expect(bundle['counts'], <String, int>{
      'blocked': 1,
      'conflict_pending': 1,
    });
    expect(
      bundle['expires_at'],
      5000 + diagnosticBundleRetention.inMilliseconds,
    );
  });

  test('the default file name is stamped, sortable and not a backup', () {
    final name = defaultDiagnosticBundleFileName(0);
    expect(name, 'legal-case-diary-diagnostics-19700101-000000.lcdiag');
    expect(name, endsWith('.$diagnosticBundleExtension'));
    expect(name, isNot(endsWith('.lcbak')));
  });

  test('an export is sealed, and an empty secret is refused', () async {
    Uint8List? written;
    String? writtenName;
    Future<String> write({
      required String fileName,
      required Uint8List bytes,
    }) async {
      writtenName = fileName;
      written = bytes;
      return 'C:/tmp/$fileName';
    }

    final bundle = buildDiagnosticBundle(
      entries: [_entry(includePayloads: false)],
      metadata: const {'last_successful_sync_at': '99'},
      includePayloads: false,
      generatedAt: 5000,
    );
    final result = await exportDiagnosticBundle(
      bundle: bundle,
      recoverySecret: 'correct-horse',
      write: write,
      generatedAt: 5000,
      kdfIterations: 1000,
    );

    expect(writtenName, defaultDiagnosticBundleFileName(5000));
    expect(result.path, 'C:/tmp/$writtenName');
    expect(result.checksum, isNotEmpty);

    // What reached the disk is the container, not JSON — and it holds no
    // readable case content.
    final text = utf8.decode(written!);
    expect(text, isNot(contains('case_number')));
    final container = EncryptedBackup.decode(text);
    expect(container.format, kEncryptedBackupFormat);

    // The passphrase reopens exactly the bundle that was built.
    final plaintext = await decryptBackup(
      container,
      recoverySecret: 'correct-horse',
    );
    final opened = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
    expect(opened['format'], kDiagnosticBundleFormat);
    expect((opened['entries'] as List), hasLength(1));

    // An empty secret would be an unprotected export, so it is refused.
    expect(
      () => exportDiagnosticBundle(
        bundle: bundle,
        recoverySecret: '',
        write: write,
        kdfIterations: 1000,
      ),
      throwsArgumentError,
    );
  });
}
