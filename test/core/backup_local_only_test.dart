/// Source-level guards for the automatic-backup job.
///
/// Two rules cannot be checked on a test host, because the Android alarm
/// isolate never exists here: the backup job must stay purely local (plan
/// §12.3) and the background entry point must be kept by the AOT compiler.
/// Both are cheap to verify by reading the sources, and both would otherwise
/// rot silently as the feature grows.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _backupFolder = 'lib/core/backup/';

/// Files that make up the backup scheduler system.
List<File> _sources() => Directory(_backupFolder)
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
  test('the backup job source exists', () {
    expect(
      _sources().map((f) => f.uri.pathSegments.last),
      contains('backup_alarm_callback.dart'),
    );
  });

  test('nothing on the backup job path imports a network package', () {
    // The scheduler + job files. `backup_cipher.dart` is the crypto engine and
    // is not part of this path.
    const forbidden = <String>[
      'supabase_flutter',
      'http/',
      'dio',
      'web_socket_channel',
      'url_launcher',
      'connectivity_plus',
    ];
    for (final name in <String>[
      'backup_alarm_callback.dart',
      'backup_scheduler.dart',
      'android_backup_scheduler.dart',
      'backup_schedule.dart',
    ]) {
      final file = File('$_backupFolder$name');
      for (final import in _imports(file)) {
        for (final package in forbidden) {
          expect(
            import.contains(package),
            isFalse,
            reason: '$name imports $import — the job must stay local '
                '(plan §12.3: no background network, GPS or Supabase calls).',
          );
        }
      }
    }
  });

  test('the backup job entry point is kept and named as the host expects', () {
    final source = File('${_backupFolder}backup_alarm_callback.dart')
        .readAsStringSync();
    expect(source.contains("@pragma('vm:entry-point')"), isTrue);
    expect(
      source.contains('Future<void> backupAlarmCallback(int alarmId)'),
      isTrue,
    );
  });

  test('the backup job never reaches a sync or network API by name', () {
    final job = File('${_backupFolder}backup_alarm_callback.dart')
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
        reason: '$symbol appears in the backup job — it must read the local '
            'database and filesystem only.',
      );
    }
  });

  test('the backup alarm id range is distinct from the alert ids', () {
    // A collision would make each job cancel or misread the other's alarm.
    final gateway = File(
      'lib/core/notifications/android_notification_gateway.dart',
    ).readAsStringSync();
    expect(gateway.contains('backupAlarmIdBase'), isTrue);
    expect(
      gateway.contains('alertAlarmIdBase = 1301 + 24 * 60'),
      isTrue,
      reason: 'the alert base moved — re-check the backup base does not collide',
    );
    expect(
      gateway.contains('backupAlarmIdBase = 1301 + 24 * 60 + 100'),
      isTrue,
      reason: 'the backup base changed — update this guard and check overlap',
    );
  });
}