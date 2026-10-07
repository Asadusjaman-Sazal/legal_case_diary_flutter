/// The app's error log: what it keeps, what it must never keep, and that it
/// outlives the process that wrote it.
///
/// The detail tests matter most. A label alone cannot be fixed from — a
/// framework error lists as `FlutterError` and nothing else — so an entry keeps
/// the failure's own message (0.0.406), flattened and bounded, and this file
/// pins that it is there for a typed failure, for an uncaught error, and on the
/// way back through the store.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/errors/error_log.dart';
import 'package:legal_case_diary/core/errors/error_log_store.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';

/// A store that keeps the log's text in memory, so no test touches a file.
class _MemoryStore implements ErrorLogStore {
  String? contents;

  @override
  Future<String?> read() async => contents;

  @override
  Future<void> write(String value) async => contents = value;

  @override
  Future<void> clear() async {
    contents = null;
  }
}

void main() {
  group('ErrorLog', () {
    test('keeps the newest first and forgets past its cap', () async {
      final log = ErrorLog(maxEntries: 3);

      for (final area in <String>['a', 'b', 'c', 'd', 'e']) {
        await log.record(area, StateError(area));
      }

      expect(log.entries, hasLength(3));
      expect(
        log.entries.map((e) => e.area),
        <String>['e', 'd', 'c'],
        reason: 'newest first, and the cap is a hard ceiling',
      );
    });

    test('a typed failure logs its kind as the label and its reply as the detail', () async {
      // The policy changed by the user's own instruction (0.0.406): the log
      // used to withhold the server's text entirely, and a row like
      // `AuthFailure(unknown)` was therefore unfixable. The kind still leads —
      // entries must stay scannable — but the reply is kept, because the report
      // is plain text the user reads and sends, not a silent export.
      final log = ErrorLog();

      await log.record(
        'auth.recover',
        const AuthFailure(
          AuthFailureKind.invalidCredentials,
          serverMessage: 'user asad.msnd@gmail.com was not found',
        ),
      );

      expect(log.entries.single.label, 'AuthFailure(invalidCredentials)');
      expect(log.entries.single.area, 'auth.recover');
      expect(log.entries.single.detail, 'user asad.msnd@gmail.com was not found');
      expect(
        encodeErrorLog(log.entries),
        contains('user asad.msnd@gmail.com was not found'),
      );
    });

    test('an uncaught error keeps its message, flattened', () async {
      final log = ErrorLog();

      await log.record(
        'cases.save',
        StateError('a message with\n  data in it'),
      );

      expect(log.entries.single.label, 'StateError');
      expect(log.entries.single.detail, 'Bad state: a message with data in it');
    });

    test('a message longer than the cap is cut with an ellipsis', () async {
      final log = ErrorLog();

      await log.record('sync.push', StateError('x' * 900));

      final detail = log.entries.single.detail!;
      expect(detail.length, maxErrorDetailLength + 1, reason: 'cap plus …');
      expect(detail, endsWith('…'));
    });

    test('a failure with nothing beyond its kind keeps no detail', () async {
      final log = ErrorLog();

      await log.record('sync.push', const AuthFailure(AuthFailureKind.network));

      expect(log.entries.single.label, 'AuthFailure(network)');
      // No server reply and no cause: the kind is the whole story, so the row
      // must not grow a line that repeats it.
      expect(log.entries.single.detail, isNull);
    });

    test('what was written survives a restart', () async {
      final store = _MemoryStore();

      await ErrorLog(store: store).record('sync.push', StateError('boom'));

      final restarted = ErrorLog(store: store);
      await restarted.load();

      expect(restarted.entries.single.area, 'sync.push');
      expect(restarted.entries.single.label, 'StateError');
      expect(restarted.entries.single.detail, 'Bad state: boom');
    });

    test('clearing empties the log on the device and in its store', () async {
      final store = _MemoryStore();
      final log = ErrorLog(store: store);
      await log.record('sync.pull', StateError('boom'));

      await log.clear();

      expect(log.entries, isEmpty);
      expect(store.contents, isNull);
    });

    test('an unreadable store is discarded, not fatal', () async {
      final store = _MemoryStore()..contents = 'not json at all';
      final log = ErrorLog(store: store);

      await log.load();

      expect(log.entries, isEmpty);
    });

    test('unreadable entries are skipped and readable ones kept', () {
      expect(parseErrorLog('[{"at": 1, "area": "a"}]'), isEmpty);
      expect(parseErrorLog('[]'), isEmpty);
      expect(parseErrorLog('{}'), isEmpty);

      final parsed = parseErrorLog(
        '[{"at": 7, "area": "sync.push", "label": "StateError"}, 4]',
      );

      expect(parsed, hasLength(1));
      expect(parsed.single.at, 7);
      expect(parsed.single.label, 'StateError');
      // Entries written before the detail field existed still load, without one.
      expect(parsed.single.detail, isNull);
    });

    test('an entry detail round-trips through the stored shape', () {
      final parsed = parseErrorLog(
        '[{"at": 7, "area": "framework", "label": "FlutterError",'
        ' "detail": "A RenderFlex overflowed by 12 pixels."}]',
      );

      expect(parsed.single.detail, 'A RenderFlex overflowed by 12 pixels.');
      // And an empty detail is read as none rather than as an empty line.
      expect(
        parseErrorLog('[{"at": 7, "area": "a", "label": "b", "detail": ""}]')
            .single
            .detail,
        isNull,
      );
    });
  });

  group('a screen that rebuilds from the log', () {
    testWidgets('is told after the frame, never from inside it', (
      tester,
    ) async {
      // The reported defect this pins: on the device, Settings > About > Support
      // hung the app (an ANR, one thread pinned at ~100%, 200 `framework`
      // entries logged in three minutes). Support and Diagnostics are the only
      // two screens in the app that rebuild from this log, and the global
      // capture records an error from inside the failing frame — so a
      // synchronous notify rebuilt the screen that was mid-failure. Rebuilding
      // it re-ran the layout that failed, which reported the error again, which
      // notified again: a loop that never yielded a frame. Waiting one turn for
      // the notification is what breaks it, and this test fails if that wait is
      // removed — the build throws `setState() called during build` instead.
      final log = ErrorLog();
      var builds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              // Stands in for Support's preview card: it rebuilds whenever the
              // log changes.
              ListenableBuilder(
                listenable: log,
                builder: (context, _) {
                  builds++;
                  return const SizedBox.shrink();
                },
              ),
              _RecordsWhileBuilding(log: log),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(log.entries, hasLength(1));
      // Told afterwards…
      expect(builds, 2);
    });
  });
}

/// Records one failure from inside its own build — a frame that hits the log
/// while it is still being built, which is what the capture does.
class _RecordsWhileBuilding extends StatefulWidget {
  const _RecordsWhileBuilding({required this.log});

  final ErrorLog log;

  @override
  State<_RecordsWhileBuilding> createState() => _RecordsWhileBuildingState();
}

class _RecordsWhileBuildingState extends State<_RecordsWhileBuilding> {
  var _recorded = false;

  @override
  Widget build(BuildContext context) {
    if (!_recorded) {
      _recorded = true;
      unawaited(widget.log.record('test.area', StateError('during build')));
    }
    return const SizedBox.shrink();
  }
}
