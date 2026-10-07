/// The app's error log: what it keeps, what it must never keep, and that it
/// outlives the process that wrote it.
///
/// The redaction test is the one that matters most. A diagnostics file leaves
/// the device and reaches a support conversation, so "no raw server text" is a
/// promise the log has to keep mechanically, not by convention.
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

    test('a typed failure is logged by kind, never by its server text', () async {
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
      expect(
        encodeErrorLog(log.entries),
        isNot(contains('asad.msnd@gmail.com')),
        reason: 'a raw server message must never reach an exported file',
      );
    });

    test('an unknown error is named by type and nothing else', () async {
      final log = ErrorLog();

      await log.record('cases.save', StateError('a message with data in it'));

      expect(log.entries.single.label, 'StateError');
      expect(encodeErrorLog(log.entries), isNot(contains('a message with')));
    });

    test('what was written survives a restart', () async {
      final store = _MemoryStore();

      await ErrorLog(store: store).record('sync.push', StateError('boom'));

      final restarted = ErrorLog(store: store);
      await restarted.load();

      expect(restarted.entries.single.area, 'sync.push');
      expect(restarted.entries.single.label, 'StateError');
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
