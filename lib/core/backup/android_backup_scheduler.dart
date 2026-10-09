/// Android implementation of [BackupScheduler].
///
/// Arms one daily backup alarm through the notification gateway's low-level
/// helpers (the single boundary for `android_alarm_manager_plus`). The alarm
/// fires once a day; the job itself checks whether today's firing is actually
/// due under the stored multi-day interval, so "Every 3 days" stays a plain
/// cadence computed by [BackupSchedule.isDue], not a wall-clock weekday.
library;

import '../notifications/android_notification_gateway.dart';
import '../notifications/notification_plan.dart';
import 'backup_alarm_callback.dart';
import 'backup_scheduler.dart';

/// Arms the daily automatic-backup alarm through the notification gateway.
class AndroidBackupScheduler implements BackupScheduler {
  /// Reads the stored schedule preference. Injectable so tests can drive this
  /// without SharedPreferences.
  final Future<int> Function() readScheduleDays;

  /// Creates the scheduler, reading the schedule from [readScheduleDays].
  AndroidBackupScheduler({required this.readScheduleDays});

  @override
  Future<void> initialize() async {
    try {
      // Re-arm on every launch: OEM battery managers and app updates can drop
      // an armed alarm, and this is the cheapest place to restore it.
      await syncSchedule();
    } catch (error, stack) {
      AndroidNotificationGateway.reportFailure(error, stack);
    }
  }

  @override
  Future<void> syncSchedule() async {
    try {
      final days = await readScheduleDays();
      if (days <= 0) {
        await AndroidNotificationGateway.cancelBackupAlarm();
        return;
      }
      await AndroidNotificationGateway.scheduleBackupAlarm(
        callback: backupAlarmCallback,
        precision: alarmPrecisionFor(
          exactAllowed: await AndroidNotificationGateway.exactAlarmsAllowed(),
        ),
      );
    } catch (error, stack) {
      // A failed (re-)arm must never take the app down; the next launch or
      // settings change tries again.
      AndroidNotificationGateway.reportFailure(error, stack);
    }
  }

  @override
  Future<void> cancelAll() async {
    try {
      await AndroidNotificationGateway.cancelBackupAlarm();
    } catch (error, stack) {
      AndroidNotificationGateway.reportFailure(error, stack);
    }
  }

  /// Runs the backup job once, now — the same logic the daily alarm fires.
  @override
  Future<void> runNow() async {
    // Directly invokes the job; the schedule check inside decides what happens.
    await runAutomaticBackupJob();
  }
}