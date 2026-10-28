/// The plain-text report a user hands over when the app will not behave.
///
/// The encrypted diagnostic bundle already answers "what did sync do", and it
/// answers it well — but it is sealed with the **backup passphrase**, which is
/// precisely the one thing a user stuck on a broken screen neither has to hand
/// over nor should ever be asked for. So it cannot be the report that arrives
/// with a first message, and this is.
///
/// Three properties make it work as an ordinary WhatsApp or email message:
///
/// * **It is plain text the user can read first.** An [ErrorLogEntry] is a time,
///   an area, a label produced by `describeErrorForLog`, and the failure's own
///   message. That message can quote a server's reply, which is exactly what
///   makes an error fixable — so it is part of the report, and the report is
///   shown, copied and sent by the user, never in the background.
/// * **It carries no file.** No attachment, no app to install, no passphrase.
///   It can be pasted anywhere.
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

/// One entry as it appears in the report: when, where, what failed — and, when
/// the failure carried a message, that message on an indented line of its own,
/// so the columns above it stay aligned.
String diagnosticEntryLine(ErrorLogEntry entry) {
  final head =
      '${diagnosticStamp(DateTime.fromMillisecondsSinceEpoch(entry.at))}'
      ' | ${entry.area} | ${entry.label}';
  final detail = entry.detail;
  return detail == null ? head : '$head\n    $detail';
}

/// Builds the report text for [entries], newest first.
///
/// [generatedAt] defaults to now and [version] to the bundled app version;
/// both are parameters only so a test can pin them. An empty [entries] still
/// produces the header — "Errors Recorded: 0" is itself the answer to "is
/// anything wrong?", and the caller decides whether an empty log is worth
/// sending at all.
/// [phone] ("Redmi Note 10 · Android 13") and [language] ("English") come from
/// the caller, because only it knows the device and the active locale. Each
/// line is **omitted when unknown** rather than printed blank, so a report is
/// never wrong — just shorter. This one header backs both the copied report and
/// the Support message, so the two cannot quote different facts.
String buildDiagnosticsReport({
  required List<ErrorLogEntry> entries,
  DateTime? generatedAt,
  String? version,
  String? phone,
  String? language,
}) {
  final at = generatedAt ?? DateTime.now();
  final shown = entries.take(diagnosticsReportEntryLimit).toList();
  final device = phone?.trim() ?? '';
  final lang = language?.trim() ?? '';

  return <String>[
    'Legal Case Diary — Diagnostics',
    'App Version: ${version ?? appVersion}',
    if (device.isNotEmpty) 'Phone: $device',
    if (lang.isNotEmpty) 'App Language: $lang',
    'Generated: ${diagnosticStamp(at)}',
    'Errors Recorded: ${entries.length}'
        '${entries.length > shown.length ? ' (Showing ${shown.length})' : ''}',
    if (shown.isEmpty) 'No errors have been recorded.' else '',
    for (final entry in shown) diagnosticEntryLine(entry),
  ].join('\n');
}
