/// The app's own error log — the one place a failure is remembered.
///
/// Two jobs, and only two: keep the last [ErrorLog.maxEntries] failures in
/// memory so a screen can show them, and persist them through an
/// [ErrorLogStore] so they outlive the process that hit them. It is deliberately
/// dumb — no filtering, no retry, no network — because the machinery that
/// reports a fault must not be able to fail in the same way the fault did.
///
/// **What an entry holds (0.0.406).** The time, the area, a short label, and the
/// failure's own message. The message was once withheld — a `serverMessage` or a
/// `PostgrestException.message` can quote a request or the data in it — but a
/// label alone cannot be acted on: a framework error records as the bare word
/// `FlutterError`, and `AuthFailure(unknown)` is only the start of the story.
/// The risk is answered where the text can go, not by hiding it: it is shown on
/// the Diagnostics screen and leaves the device only inside a report the user
/// copies or sends, which they can read first. No password, token, passphrase or
/// case payload is ever recorded, because nothing on this path reads one.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'error_log_store.dart';

/// A failure that can describe itself for the log.
///
/// Implemented by the app's typed failures, so an entry can name *which* kind
/// went wrong — `AuthFailure(network)` — and, beside it, keep the underlying
/// text that makes the kind actionable.
abstract interface class DiagnosableFailure {
  /// A short label naming the failure and its kind.
  String get diagnosticLabel;

  /// The failure's own message — the server's reply, the underlying cause — or
  /// null when [diagnosticLabel] already says everything.
  String? get diagnosticDetail;
}

/// One recorded failure.
class ErrorLogEntry {
  /// Creates an entry. [at] is epoch milliseconds, UTC-agnostic on purpose:
  /// it is a device timestamp and the log says so.
  const ErrorLogEntry({
    required this.at,
    required this.area,
    required this.label,
    this.detail,
  });

  /// When it happened, epoch milliseconds.
  final int at;

  /// Where it happened, as `feature.operation` (for example `sync.push`).
  final String area;

  /// What failed, as produced by [describeErrorForLog].
  final String label;

  /// The failure's own message, so the error can be identified and fixed — a
  /// framework error's text, a server's reply — or null when there is none.
  final String? detail;

  /// The stored shape. Flat on purpose, so a reader can eyeball it. [detail] is
  /// left out entirely when null, so an entry with nothing to add keeps the
  /// shape it has always had.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'at': at,
    'area': area,
    'label': label,
    if (detail != null) 'detail': detail,
  };

  /// Reads an entry back, or null when the stored shape is not one.
  static ErrorLogEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final at = json['at'];
    final area = json['area'];
    final label = json['label'];
    if (at is! int || area is! String || label is! String) return null;
    final detail = json['detail'];
    return ErrorLogEntry(
      at: at,
      area: area,
      label: label,
      detail: detail is String && detail.isNotEmpty ? detail : null,
    );
  }
}

/// Records [error] as having happened in [area], without waiting for the write.
///
/// **This is the choke point for a failure the user saw.** The global capture in
/// `error_capture.dart` only sees what escaped; but this app catches almost
/// everything, turns it into a typed failure and shows a banner, so a user
/// stuck on a broken screen usually produces *no* uncaught error at all. A
/// domain ViewModel calls this as it lets a failure out of the layer that owns
/// it, which is the one point every screen's banner passes through.
///
/// Not awaited on purpose: the caller is a failure path already, and making it
/// wait for a disk write would turn a diagnostics aid into a second failure.
void recordFailure(ErrorLog log, String area, Object error) =>
    unawaited(log.record(area, error));

/// A one-line, redacted description of [error] for the log.
///
/// Deliberately narrow. A typed failure answers with its kind; anything else
/// falls back to its runtime type. The message goes in the entry's
/// [ErrorLogEntry.detail], not here: a label is what a reader scans, and it
/// must stay short and comparable across entries.
String describeErrorForLog(Object error) {
  if (error is DiagnosableFailure) return error.diagnosticLabel;
  if (error is TimeoutException) return 'Timeout';
  return error.runtimeType.toString();
}

/// The longest detail kept for a single entry.
///
/// Long enough for a framework error's text and a server's reply; short enough
/// that 200 entries and a 25-entry report stay readable blocks rather than dumps
/// of whole stack-bearing messages.
const int maxErrorDetailLength = 500;

/// One flat form of [text] for an entry's detail: whitespace collapsed to
/// single spaces, so a multi-line message stays one block, and long text cut
/// with an ellipsis.
String? summarizeErrorDetail(String? text) {
  if (text == null) return null;
  final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.isEmpty) return null;
  if (flat.length <= maxErrorDetailLength) return flat;
  return '${flat.substring(0, maxErrorDetailLength)}…';
}

/// The failure's own message, or null when there is nothing beyond the label.
///
/// A typed failure answers through [DiagnosableFailure.diagnosticDetail];
/// anything else falls back to `toString()` — the message, never the stack. An
/// error whose text is merely its own type name adds nothing to the label and
/// is left out.
String? describeErrorDetail(Object error) {
  final raw = error is DiagnosableFailure
      ? error.diagnosticDetail
      : error.toString();
  if (raw == null || raw.trim().isEmpty) return null;
  if (raw.trim() == error.runtimeType.toString()) return null;
  return raw;
}

/// Encodes [entries] for storage.
String encodeErrorLog(List<ErrorLogEntry> entries) =>
    jsonEncode(<Map<String, dynamic>>[for (final e in entries) e.toJson()]);

/// Reads back what [encodeErrorLog] wrote, skipping anything unreadable.
///
/// A log that cannot be parsed is discarded rather than fatal: it is a
/// diagnostic aid, and losing it must never be worse than the fault it records.
List<ErrorLogEntry> parseErrorLog(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <ErrorLogEntry>[];
    final entries = <ErrorLogEntry>[];
    for (final item in decoded) {
      final entry = ErrorLogEntry.fromJson(item);
      if (entry != null) entries.add(entry);
    }
    return entries;
  } on FormatException {
    return const <ErrorLogEntry>[];
  }
}

/// The in-memory ring of recent failures, persisted through [store].
///
/// A [ChangeNotifier], because a log nobody can see change is not a diagnostic:
/// the Diagnostics screen has to show a failure the moment it is recorded, and a
/// Clear has to visibly empty the list it was tapped on.
class ErrorLog extends ChangeNotifier {
  /// Creates a log. Without a [store] it lives only for this process, which is
  /// what widget tests want.
  ErrorLog({this.store, this.maxEntries = 200});

  /// Where the log is persisted; null keeps it in memory for this process only.
  final ErrorLogStore? store;

  /// How many entries are kept: enough to explain a session, bounded so a loop
  /// that fails a thousand times cannot fill the disk.
  final int maxEntries;

  final List<ErrorLogEntry> _entries = <ErrorLogEntry>[];

  /// The entries, newest first.
  List<ErrorLogEntry> get entries => List<ErrorLogEntry>.unmodifiable(_entries);

  /// Whether anything has been recorded.
  bool get isEmpty => _entries.isEmpty;

  /// Reads what a previous run left behind, before the first frame.
  Future<void> load() async {
    final store = this.store;
    if (store == null) return;
    final raw = await store.read();
    if (raw == null || raw.isEmpty) return;
    _entries
      ..clear()
      ..addAll(parseErrorLog(raw));
  }

  /// Records [error] as having happened in [area], then persists.
  ///
  /// [detail] overrides the failure's own message — the global capture passes a
  /// framework error's text with its library and context, which a bare
  /// `toString()` cannot supply. Whatever the source, it is flattened and
  /// bounded before it is stored.
  Future<void> record(String area, Object error, {String? detail}) async {
    _entries.insert(
      0,
      ErrorLogEntry(
        at: DateTime.now().millisecondsSinceEpoch,
        area: area,
        label: describeErrorForLog(error),
        detail: summarizeErrorDetail(detail ?? describeErrorDetail(error)),
      ),
    );
    if (_entries.length > maxEntries) {
      _entries.removeRange(maxEntries, _entries.length);
    }
    _notifyOutsideThisTurn();
    await _persist();
  }

  /// Tells listeners the log changed — after the turn that changed it, never
  /// from inside it.
  ///
  /// **This is what stops a screen from being rebuilt by the very failure it is
  /// reporting.** The global capture records an error from inside the frame that
  /// hit it, so a synchronous notify would call a listening screen's `setState`
  /// in the middle of that frame: rebuilding the screen re-runs the layout that
  /// failed, which reports the error again, which notifies again — a loop that
  /// never yields a frame. On the device this is what ANR'd the app on
  /// Settings > About > Support (200 `framework` entries logged in three minutes
  /// and one thread pinned at ~100%), and the two screens in the whole app that
  /// rebuild from this log are Support and Diagnostics.
  ///
  /// A microtask is enough and needs no binding: the frame's build and layout
  /// phases are one synchronous turn, so the notification lands once the frame
  /// has finished them and a listener may safely rebuild.
  void _notifyOutsideThisTurn() => scheduleMicrotask(notifyListeners);

  /// Forgets everything, in memory and in the file.
  Future<void> clear() async {
    _entries.clear();
    _notifyOutsideThisTurn();
    await store?.clear();
  }

  Future<void> _persist() async {
    final store = this.store;
    if (store == null) return;
    await store.write(encodeErrorLog(_entries));
  }
}
