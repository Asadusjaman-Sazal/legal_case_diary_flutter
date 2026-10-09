/// Pure scheduling rules for the automatic backup job.
///
/// Everything here is plain Dart: no plugin, no platform channel, no database.
/// It answers two questions the background alarm isolate and the Settings screen
/// must agree on — *is a backup due now?* and *should it actually run (or must it
/// be skipped because encryption is on)?* — so the answer is unit-testable
/// without an emulator.
///
/// The schedule is a simple interval in days (Off = 0). The alarm fires daily;
/// the job runs a backup only on days the interval says it is due, so "Every 3
/// days" means "at most every 72 h from the last run", not a wall-clock weekday.
library;

/// Milliseconds in one day; the interval arithmetic is expressed in whole days.
const int millisecondsPerDay = 24 * 60 * 60 * 1000;

/// The `backup_schedule_days` prefs key lives in the metadata store; this value
/// (0) is the one the screen uses to mean "Off".
const int backupScheduleOff = 0;

/// A single backup schedule, derived from the stored interval in days.
class BackupSchedule {
  /// The stored interval in days; 0 means off.
  final int intervalDays;

  /// Creates a schedule from the stored [intervalDays].
  BackupSchedule(this.intervalDays);

  /// Whether a schedule is configured at all (interval > 0 days).
  bool get isEnabled => intervalDays > 0;

  /// Whether a backup is due at [nowEpochMs], given the last scheduled run at
  /// [lastRunEpochMs].
  ///
  /// Never due while off. The first run after a schedule is enabled is treated
  /// as due immediately (no last run yet), so turning the schedule on produces a
  /// backup without waiting a full interval.
  bool isDue({
    required int nowEpochMs,
    int? lastRunEpochMs,
  }) {
    if (!isEnabled) return false;
    if (lastRunEpochMs == null) return true;
    return nowEpochMs >= lastRunEpochMs + intervalDays * millisecondsPerDay;
  }
}

/// Why the automatic backup did or did not run, for the alarm job to act on.
enum BackupJobDecision {
  /// The schedule is off; nothing to do.
  disabled,

  /// Encryption is on, so the job must skip and ask the user to back up by hand.
  encryptionOnSkips,

  /// A plain backup is due now.
  run,
}

/// Decides what the automatic-backup job should do right now.
///
/// [encryptBackups] is the stored per-user preference: with it on, the job
/// cannot write a plain backup silently (the user chose to encrypt; a plain
/// file would contradict that) and it cannot ask for the passphrase in the
/// background (the passphrase is never stored) — so the honest result is a skip
/// that points the user at the manual backup.
BackupJobDecision decideBackupJob({
  required BackupSchedule schedule,
  required bool encryptBackups,
  required int nowEpochMs,
  int? lastRunEpochMs,
}) {
  if (!schedule.isEnabled) return BackupJobDecision.disabled;
  // Nothing is due today: an enabled schedule that is not yet due does nothing,
  // and must not nag. Only a day a backup *would* have run can skip-or-run.
  if (!schedule.isDue(nowEpochMs: nowEpochMs, lastRunEpochMs: lastRunEpochMs)) {
    return BackupJobDecision.disabled;
  }
  return encryptBackups
      ? BackupJobDecision.encryptionOnSkips
      : BackupJobDecision.run;
}