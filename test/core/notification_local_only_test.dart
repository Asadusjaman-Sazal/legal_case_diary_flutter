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
List<String> _imports(File file) => RegExp(
  r"import\s+'([^']+)'",
).allMatches(file.readAsStringSync()).map((match) => match.group(1)!).toList();

void main() {
  test('the notification sources exist', () {
    expect(
      _sources().map((f) => f.uri.pathSegments.last),
      contains('notification_alarm_callback.dart'),
    );
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
            reason:
                '${file.path} imports $import — the job must stay local '
                '(plan §12.3: no background network, GPS or Supabase calls).',
          );
        }
      }
    }
  });

  test('a sync with no armed reminder leaves the alarm service alone', () {
    // Found the hard way: cancelling both reminder ids on every sync called the
    // alarm plugin when nothing was armed, and on the widget-test host that
    // await never returned — the Add/Edit sheet stayed open and two unrelated
    // acceptance tests failed. The armed list is the guard, so it is pinned.
    final gateway = File(
      '${_folder}android_notification_gateway.dart',
    ).readAsStringSync();

    expect(
      gateway.contains('if (armed.isEmpty) return;'),
      isTrue,
      reason:
          'Cancelling reminders must return before any platform call when '
          'none was ever armed.',
    );
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
        reason:
            '$symbol appears in the alarm job — it must read the local '
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
            reason:
                '$fileName imports $package — the platform packages belong '
                'behind the gateway, so call sites and the Windows port stay '
                'free of them.',
          );
        }
      }
    }
  });

  test('the alert body is posted with a BigText style', () {
    // There is no Android notification to inspect on the test host, so the rule
    // that keeps the expanded view readable is guarded at source level: with no
    // style, Android lays the text out itself and ellipsises a line, which is
    // how a long `Petitioner vs Respondent` line was cut short.
    final gateway = File(
      '${_folder}android_notification_gateway.dart',
    ).readAsStringSync();

    expect(
      gateway.contains('styleInformation: BigTextStyleInformation(body)'),
      isTrue,
      reason: 'The alert body must be handed to Android as BigText text.',
    );
    expect(gateway.contains('body: alert.body'), isTrue);
  });

  test('the job carries the case step and result into the alert body', () {
    // The step/result line is only as good as the wiring that fills it, and the
    // job itself needs a real database and the alarm isolate to run.
    final job = File(
      '${_folder}notification_alarm_callback.dart',
    ).readAsStringSync();

    expect(
      job.contains('lastStep: row.lastStep'),
      isTrue,
      reason: 'The alert lists the case step, so the candidate must carry it.',
    );
    expect(
      job.contains('result: row.result'),
      isTrue,
      reason:
          'An AD/HCD case has no step, so the alert needs its Result — a '
          'silent drop here would leave those cases without that line.',
    );
  });

  test('the battery-optimization check names one protocol on both sides', () {
    // The Dart half and `MainActivity.kt` are two ends of one method channel
    // with no compile-time link: a rename on either side would silently leave
    // the setup guide's battery step un-ticked, and the test host cannot answer
    // the question the channel carries.
    final gateway = File(
      '${_folder}android_notification_gateway.dart',
    ).readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/com/legumsoft/legalcasediary/MainActivity.kt',
    ).readAsStringSync();

    expect(
      gateway.contains("'com.legumsoft.legalcasediary/device_setup'"),
      isTrue,
      reason: 'The gateway must ask the channel the host activity serves.',
    );
    expect(
      activity.contains('"com.legumsoft.legalcasediary/device_setup"'),
      isTrue,
    );
    expect(gateway.contains("'isIgnoringBatteryOptimizations'"), isTrue);
    expect(
      activity.contains('"isIgnoringBatteryOptimizations"'),
      isTrue,
      reason: 'The activity must still answer the method the gateway calls.',
    );
    expect(
      activity.contains('isIgnoringBatteryOptimizations(packageName)'),
      isTrue,
      reason: 'The answer must come from the OS, not from a stored guess.',
    );
  });

  test('the alarm entry point stays annotated for the AOT compiler', () {
    final job = File(
      '${_folder}notification_alarm_callback.dart',
    ).readAsStringSync();
    expect(
      job.contains("@pragma('vm:entry-point')"),
      isTrue,
      reason:
          'AndroidAlarmManager resolves the job by callback handle; without '
          'the annotation a release build can strip it.',
    );
    expect(
      job.contains('Future<void> notificationAlarmCallback(int alarmId)'),
      isTrue,
      reason:
          'The alarm hands the job its id, which is how a run knows which '
          'time slot it is posting for.',
    );
    expect(
      job.contains('AndroidNotificationGateway.alertMinutesForId(alarmId)'),
      isTrue,
      reason:
          'The alarm id is the only thing carrying the slot into the job '
          'isolate; dropping it would post every case at every slot.',
    );
  });
}
