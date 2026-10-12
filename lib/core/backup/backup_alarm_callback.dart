/// The automatic-backup job, run by Android's alarm manager.
///
/// **Enforced rule (plan §12.3):** this file and everything it calls works
/// purely against the local, encrypted Drift database and the local filesystem.
/// There is no network call, no GPS use and no Supabase request on this path,
/// and there must never be one.
///
/// The job runs in the alarm service's own isolate, so it builds its own
/// database and reads SharedPreferences directly instead of Riverpod providers.
library;

import 'dart:developer' as dev;
import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../database/app_database.dart';
import '../../database/database_factory.dart';
import '../../features/settings/data/backup_file_gateway.dart';
import '../../features/settings/data/backup_metadata_store.dart';
import '../../features/settings/data/backup_repository.dart';
import '../constants/app_version.dart';
import '../l10n/app_translations.dart';
import '../l10n/generated/app_localizations.dart';
import '../notifications/android_notification_gateway.dart';
import '../notifications/notification_plan.dart';
import 'backup_schedule.dart';

/// Prefs key holding the active language code (`lib/shared/providers/locale_provider.dart`).
const String _localeKey = 'app_locale';

/// Entry point the alarm service executes in its background isolate.
///
/// Top-level and `@pragma('vm:entry-point')` on purpose: the AOT compiler must
/// keep it, and `AndroidAlarmManager` resolves it by callback handle.
@pragma('vm:entry-point')
Future<void> backupAlarmCallback(int alarmId) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  try {
    await runAutomaticBackupJob();
  } catch (error, stackTrace) {
    // A failed job must never crash the alarm service; the next launch or
    // settings change re-arms the schedule anyway.
    dev.log(
      'Automatic backup job failed',
      name: 'backup',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Runs the automatic backup if the stored schedule says it is due.
///
/// [nowEpochMs] and [lastRunEpochMs] are injectable so the cadence can be
/// tested. Three outcomes per [decideBackupJob]:
///
/// * **disabled** — the schedule is off, or the interval has not elapsed since
///   the last backup: nothing is done.
/// * **encryptionOnSkips** — the user chose to encrypt, so a background job
///   must not write a plain file silently, and it cannot ask for the passphrase;
///   it posts a notice pointing at the manual backup instead.
/// * **run** — a plain backup is due: it is exported into the diary folder and
///   recorded as the last successful backup.
Future<BackupJobDecision> runAutomaticBackupJob({
  int? nowEpochMs,
  int? lastRunEpochMs,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final schedule = BackupSchedule(
    prefs.getInt(backupScheduleDaysKey) ?? defaultBackupScheduleDays,
  );
  final encrypt = prefs.getBool(backupEncryptionEnabledKey) ?? false;
  final last = lastRunEpochMs ?? prefs.getInt(lastSuccessfulBackupAtKey);

  final decision = decideBackupJob(
    schedule: schedule,
    encryptBackups: encrypt,
    nowEpochMs: nowEpochMs ?? DateTime.now().millisecondsSinceEpoch,
    lastRunEpochMs: last,
  );

  // Re-arm the next daily check so the chain survives without the app ever
  // being opened, exactly like the hearing-alert job. An enabled schedule
  // re-arms whatever this run did (backed up, skipped, or merely not yet due);
  // a disabled one stops the chain here — `syncSchedule` is what cancels an
  // alarm the user turned Off.
  if (schedule.isEnabled) {
    await AndroidNotificationGateway.scheduleBackupAlarm(
      callback: backupAlarmCallback,
      precision: alarmPrecisionFor(
        exactAllowed: await AndroidNotificationGateway.exactAlarmsAllowed(),
      ),
    );
  }

  if (decision == BackupJobDecision.run) {
    final db = AppDatabase(await DatabaseFactory().createExecutor());
    try {
      final folder = await backgroundBackupDirectory();
      if (!await folder.exists()) await folder.create(recursive: true);
      final now = nowEpochMs ?? DateTime.now().millisecondsSinceEpoch;
      final result = await BackupRepository(db).exportSnapshot(
        sink: BackupFolderSink(directoryProvider: () async => folder),
        appVersion: appVersion,
        // Automatic backups are always plain: a passphrase cannot be asked for
        // in the background, and the user's encryption-on choice means "skip,
        // not downgrade" (see `decideBackupJob`).
        recoverySecret: null,
        exportedAt: now,
        // A stem of its own, so the sweep below can tell this file from the
        // manual backups sharing the folder (user request).
        fileName: automaticBackupFileName(now),
      );
      await prefs.setInt(lastSuccessfulBackupAtKey, result.envelope.exportedAt);
      await prefs.setString(lastBackupPathKey, result.path);
      // The automatic backup is **replaced**, not accumulated (user request): a
      // file per day would quietly fill the folder, and the point of the
      // automatic copy is that there is always one, not that there is a
      // history. Deleting **after** the write means a failure leaves yesterday's
      // file in place rather than none at all.
      await pruneAutomaticBackups(
        folder,
        keep: result.path.split(Platform.pathSeparator).last,
      );
    } finally {
      await db.close();
    }
  } else if (decision == BackupJobDecision.encryptionOnSkips) {
    if (Platform.isAndroid) {
      final translations = AppTranslations(
        lookupAppLocalizations(Locale(_languageCode(prefs))),
      );
      final l = translations.raw;
      await AndroidNotificationGateway.presentBackupSkippedNotice(
        title: l.backupScheduled_skipNoticeTitle,
        body: l.backupScheduled_skipNoticeBody,
        channelName: l.backupScheduled_noticeChannelName,
        channelDescription: l.backupScheduled_noticeChannelDescription,
      );
    }
  }

  return decision;
}

/// The stored language code, defaulting to English.
String _languageCode(SharedPreferences prefs) =>
    prefs.getString(_localeKey) ?? 'en';