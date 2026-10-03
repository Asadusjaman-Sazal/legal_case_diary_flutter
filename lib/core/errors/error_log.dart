/// The app's own error log — the one place a failure is remembered.
///
/// Two jobs, and only two: keep the last [ErrorLog.maxEntries] failures in
/// memory so a screen can show them, and persist them through an
/// [ErrorLogStore] so they outlive the process that hit them. It is deliberately
/// dumb — no filtering, no retry, no network — because the machinery that
/// reports a fault must not be able to fail in the same way the fault did.
///
/// **What is never written.** No case data, no tokens, no passwords, and no raw
/// server message: `AuthFailure.serverMessage` and `PostgrestException.message`
/// can carry fragments of a request or of the data in it, and Task 15's rules
/// already say a diagnostics file is metadata. An entry holds the time, the area
/// it happened in, a short label for the failure, and the app version.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'error_log_store.dart';

/// A failure that can describe itself for the log without leaking anything.
///
/// Implemented by the app's typed failures, so an entry can name *which* kind
/// went wrong — `AuthFailure(network)` — while a raw server text stays where it
/// belongs: in the failure the screen may show, never in an exported file.
abstract interface class DiagnosableFailure {
  /// A short, redacted label naming the failure and its kind.
  String get diagnosticLabel;
}

/// One recorded failure.
class ErrorLogEntry {
  /// Creates an entry. [at] is epoch milliseconds, UTC-agnostic on purpose:
  /// it is a device timestamp and the log says so.
  const ErrorLogEntry({required this.at, required this.area, required this.label});

  /// When it happened, epoch milliseconds.
  final int at;

  /// Where it happened, as `feature.operation` (for example `sync.push`).
  final String area;

  /// What failed, as produced by [describeErrorForLog].
  final String label;

  /// The stored shape. Flat on purpose, so a reader can eyeball it.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'at': at,
    'area': area,
    'label': label,
  };

  /// Reads an entry back, or null when the stored shape is not one.
  static ErrorLogEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final at = json['at'];
    final area = json['area'];
    final label = json['label'];
    if (at is! int || area is! String || label is! String) return null;
    return ErrorLogEntry(at: at, area: area, label: label);
  }
}

/// A one-line, redacted description of [error] for the log.
///
/// Deliberately narrow. A typed failure answers with its kind; anything else
/// falls back to its runtime type, and **never** to its message.
String describeErrorForLog(Object error) {
  if (error is DiagnosableFailure) return error.diagnosticLabel;
  if (error is TimeoutException) return 'Timeout';
  return error.runtimeType.toString();
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
  Future<void> record(String area, Object error) async {
    _entries.insert(
      0,
      ErrorLogEntry(
        at: DateTime.now().millisecondsSinceEpoch,
        area: area,
        label: describeErrorForLog(error),
      ),
    );
    if (_entries.length > maxEntries) {
      _entries.removeRange(maxEntries, _entries.length);
    }
    notifyListeners();
    await _persist();
  }

  /// Forgets everything, in memory and in the file.
  Future<void> clear() async {
    _entries.clear();
    notifyListeners();
    await store?.clear();
  }

  Future<void> _persist() async {
    final store = this.store;
    if (store == null) return;
    await store.write(encodeErrorLog(_entries));
  }
}
