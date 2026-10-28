/// The plain-text diagnostics report: the one form of the error log that can
/// actually leave the phone.
///
/// It reaches a support conversation through an ordinary WhatsApp message, so
/// the three things worth pinning are that it is readable and unambiguous, that
/// it carries the failure's own message — the reason the report exists (0.0.406)
/// — and that the user reads it before it is ever sent, because it now can quote
/// a server's reply.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/errors/error_log.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/settings/data/diagnostics_report.dart';

/// The instant every stamp in this group is measured from, so no test depends on
/// the wall clock.
final DateTime _at = DateTime(2026, 10, 3, 14, 22, 1);

ErrorLogEntry _entry(String area, String label, {int? at}) => ErrorLogEntry(
  at: at ?? _at.millisecondsSinceEpoch,
  area: area,
  label: label,
);

void main() {
  test('a stamp is the fixed-width, Latin layout a reader can line up', () {
    expect(diagnosticStamp(_at), '2026-10-03 14:22:01');
  });

  test('names the app version, the moment and how many errors there are', () {
    final report = buildDiagnosticsReport(
      entries: [_entry('auth.signIn', 'AuthFailure(network)')],
      generatedAt: _at,
      version: '9.9.9',
    );

    expect(report, contains('App Version: 9.9.9'));
    expect(report, contains('Generated: 2026-10-03 14:22:01'));
    expect(report, contains('Errors Recorded: 1'));
  });

  test('writes one line per entry: when, where, what failed', () {
    final report = buildDiagnosticsReport(
      entries: [_entry('auth.signIn', 'AuthFailure(network)')],
      generatedAt: _at,
    );

    expect(
      report,
      contains('2026-10-03 14:22:01 | auth.signIn | AuthFailure(network)'),
    );
  });

  test('keeps the order it was given, which is newest first', () {
    final report = buildDiagnosticsReport(
      entries: [
        _entry('sync.push', 'SyncFailure(network)'),
        _entry('auth.signIn', 'AuthFailure(unavailable)'),
      ],
      generatedAt: _at,
    );

    expect(
      report.indexOf('sync.push'),
      lessThan(report.indexOf('auth.signIn')),
      reason: 'the log hands over newest first and the report must not reorder',
    );
  });

  test('caps the dump and says how much it left out', () {
    final report = buildDiagnosticsReport(
      entries: <ErrorLogEntry>[
        for (var i = 0; i < diagnosticsReportEntryLimit + 10; i++)
          _entry('sync.push', 'SyncFailure(server)', at: 1000 + i),
      ],
      generatedAt: _at,
    );

    expect(
      report,
      contains(
        'Errors Recorded: ${diagnosticsReportEntryLimit + 10} '
        '(Showing $diagnosticsReportEntryLimit)',
      ),
    );
    expect(
      report.split('\n').where((line) => line.contains('SyncFailure(server)')),
      hasLength(diagnosticsReportEntryLimit),
    );
  });

  test('an empty log still reports a count, and no entries', () {
    final report = buildDiagnosticsReport(entries: const [], generatedAt: _at);

    expect(report, contains('Errors Recorded: 0'));
    expect(report, contains('No errors have been recorded.'));
    expect(report, isNot(contains(' | ')));
  });

  test('carries the failure\'s own message, because that is what gets fixed', () async {
    // The chain, not just the formatter. The policy changed by the user's own
    // instruction (0.0.406): a report whose lines name only `FlutterError` or
    // `AuthFailure(unknown)` cannot be acted on, so the message the log kept is
    // handed over too — on its own indented line, under the aligned columns.
    final log = ErrorLog();
    await log.record(
      'auth.signIn',
      const AuthFailure(
        AuthFailureKind.invalidCredentials,
        serverMessage: 'user asad.msnd@gmail.com was not found',
      ),
    );

    final report = buildDiagnosticsReport(
      entries: log.entries,
      generatedAt: _at,
    );

    expect(report, contains('AuthFailure(invalidCredentials)'));
    expect(
      report,
      contains('\n    user asad.msnd@gmail.com was not found'),
      reason: 'the message sits under its entry, indented',
    );
  });
}
