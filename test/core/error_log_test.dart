/// The app's error log: what it keeps, what it must never keep, and that it
/// outlives the process that wrote it.
///
/// The redaction test is the one that matters most. A diagnostics file leaves
/// the device and reaches a support conversation, so "no raw server text" is a
/// promise the log has to keep mechanically, not by convention.
library;

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
}
