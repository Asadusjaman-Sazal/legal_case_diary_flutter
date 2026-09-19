/// Source-level guards for the notification system (Task 13 Phase 1).
///
/// Two rules cannot be checked by running the app on a test host, because the
/// Android alarm isolate never exists here: the background job must stay purely
/// local (plan §12.3) and the Android-only packages must stay behind the single
/// gateway file. Both are cheap to verify by reading the sources, and both would
/// otherwise rot silently as the feature grows.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _folder = 'lib/core/notifications/';

/// Files that make up the notification system.
List<File> _sources() => Directory(_folder)
    .listSync()
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    .toList();

/// Import URIs of one source file, as written in the file.
List<String> _imports(File file) => RegExp(r"import\s+'([^']+)'")
    .allMatches(file.readAsStringSync())
    .map((match) => match.group(1)!)
    .toList();

void main() {
  test('the notification sources exist', () {
    expect(_sources().map((f) => f.uri.pathSegments.last), contains('notification_alarm_callback.dart'));
  });

  test('nothing on the notification path imports a network package', () {
    const forbidden = <String>[
      'supabase_flutter',
      'http/',
      'dio',
      'web_socket_channel',
      'url_launcher',
      'connectivity_plus',
    ];
    for (final file in _sources()) {
      for (final import in _imports(file)) {
        for (final package in forbidden) {
          expect(
            import.contains(package),
            isFalse,
            reason: '${file.path} imports $import — the job must stay local '
                '(plan §12.3: no background network, GPS or Supabase calls).',
          );
        }
      }
    }
  });

  test('the background job never reaches a sync or network API by name', () {
    // Comments are stripped: the file documents the rule it obeys.
    final job = File('${_folder}notification_alarm_callback.dart')
        .readAsLinesSync()
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');
    for (final symbol in <String>[
      'Supabase',
      'sync_queue',
      'SyncWriteHelper',
      'HttpClient',
    ]) {
      expect(
        job.contains(symbol),
        isFalse,
        reason: '$symbol appears in the alarm job — it must read the local '
            'database only.',
      );
    }
  });

  test('Android-only packages are imported by the gateway alone', () {
    const androidOnly = <String>[
      'android_alarm_manager_plus',
      'flutter_local_notifications',
      'android_intent_plus',
      'device_info_plus',
    ];
    for (final file in _sources()) {
      final fileName = file.uri.pathSegments.last;
      for (final import in _imports(file)) {
        for (final package in androidOnly) {
          if (!import.contains(package)) continue;
          expect(
            fileName,
            'android_notification_gateway.dart',
            reason: '$fileName imports $package — the platform packages belong '
                'behind the gateway, so call sites and the Windows port stay '
                'free of them.',
          );
        }
      }
    }
  });

  test('the alarm entry point stays annotated for the AOT compiler', () {
    final job = File('${_folder}notification_alarm_callback.dart')
        .readAsStringSync();
    expect(
      job.contains("@pragma('vm:entry-point')"),
      isTrue,
      reason: 'AndroidAlarmManager resolves the job by callback handle; without '
          'the annotation a release build can strip it.',
    );
    expect(job.contains('Future<void> notificationAlarmCallback()'), isTrue);
  });
}
