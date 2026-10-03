/// The plain-text report a user hands over when the app will not behave.
///
/// The encrypted diagnostic bundle already answers "what did sync do", and it
/// answers it well — but it is sealed with the **backup passphrase**, which is
/// precisely the one thing a user stuck on a broken screen neither has to hand
/// over nor should ever be asked for. So it cannot be the report that arrives
/// with a first message, and this is.
///
/// Three properties make it safe to send through an ordinary WhatsApp or email:
///
/// * **It is redacted by construction.** An [ErrorLogEntry] is a time, an area
///   and a label produced by `describeErrorForLog` — never a case field, never a
///   token, never a raw `PostgrestException.message`. This function only
///   formats those three fields; there is nothing here that could leak, and
///   nothing for it to redact.
/// * **It is plain text.** No file to attach, no app to install, no passphrase.
///   It can be read in the preview before it is sent and pasted anywhere.
/// * **It is fixed-width and Latin.** One `yyyy-MM-dd HH:mm:ss` stamp per line,
///   `area` and `label` in separate columns, so a reader can line entries up
///   against a log on another machine. Bengali numerals would work against that.
///
/// The headings are authored English, not localized, because the report is
/// read by the developer while the Bengali user's own description ends the
/// message — the app's localized copy belongs to the message around it, not to
/// a machine dump inside it.
library;

import 'package:intl/intl.dart';

import '../../../core/constants/app_version.dart';
import '../../../core/errors/error_log.dart';

/// How many entries the report carries at most.
///
/// Newest first, because the failure a user is reporting is the one that just
/// happened. Twenty-five lines is a paragraph WhatsApp renders without
/// scrolling to be useful, and the full log — up to 200 entries — is still one
/// tap away on the Diagnostics screen or in the encrypted bundle.
const int diagnosticsReportEntryLimit = 25;

/// The one stamp format the Diagnostics screen and this report share.
///
/// Deliberately Latin digits and an unambiguous layout: an entry is compared
/// with a log on another machine, not read as prose.
final DateFormat _stamp = DateFormat('yyyy-MM-dd HH:mm:ss');

/// Formats [when] the way every diagnostic record in this app is stamped.
String diagnosticStamp(DateTime when) => _stamp.format(when);

/// One entry as it appears in the report: when, where, what failed.
String diagnosticEntryLine(ErrorLogEntry entry) =>
    '${diagnosticStamp(DateTime.fromMillisecondsSinceEpoch(entry.at))}'
    ' | ${entry.area} | ${entry.label}';

/// Builds the report text for [entries], newest first.
///
/// [generatedAt] defaults to now and [version] to the bundled app version;
/// both are parameters only so a test can pin them. An empty [entries] still
/// produces the header — "Errors Recorded: 0" is itself the answer to "is
/// anything wrong?", and the caller decides whether an empty log is worth
/// sending at all.
String buildDiagnosticsReport({
  required List<ErrorLogEntry> entries,
  DateTime? generatedAt,
  String? version,
}) {
  final at = generatedAt ?? DateTime.now();
  final shown = entries.take(diagnosticsReportEntryLimit).toList();

  return <String>[
    'Legal Case Diary — Diagnostics',
    'App Version: ${version ?? appVersion}',
    'Generated: ${diagnosticStamp(at)}',
    'Errors Recorded: ${entries.length}'
        '${entries.length > shown.length ? ' (Showing ${shown.length})' : ''}',
    if (shown.isEmpty) 'No Errors Have Been Recorded.' else '',
    for (final entry in shown) diagnosticEntryLine(entry),
  ].join('\n');
}
