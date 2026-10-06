/// Last-backup metadata, the automatic-backup schedule, and the encryption
/// preference (Task 15 Phase 4).
///
/// The Backup & Restore screen shows when and where the last successful backup
/// went, remembers the schedule the user picked, and remembers whether backups
/// should be encrypted ([encryptBackups], off until the user turns it on). All
/// three live in
/// [SharedPreferences] (the task's requirement, and the keys Phase 6's monthly
/// nudge reads), not in the database — the database is exactly what a restore
/// replaces, so its own record cannot be the thing the screen reports on. The
/// encryption flag is a per-user preference, so it too stays out of the database
/// and is consulted by every backup/restore path.
///
/// Task 12 left the schedule choice in memory and handed its persistence to
/// Task 15. Choosing a schedule only *stores* the interval here: nothing runs
/// on a schedule until Part B's background executor exists.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/providers/shared_preferences_provider.dart';

/// Preference key holding the epoch-ms of the last successful backup.
///
/// Read by Phase 6's monthly nudge, so the name is part of the task's contract.
const String lastSuccessfulBackupAtKey = 'last_successful_backup_at';

/// Preference key holding the location the last backup was written to.
const String lastBackupPathKey = 'last_backup_path';

/// Preference key holding the chosen automatic-backup interval in days.
const String backupScheduleDaysKey = 'backup_schedule_days';

/// Preference key holding the epoch-ms of the last monthly backup nudge.
///
/// Phase 6's "at most once per calendar month" rule, and the task names the key,
/// so the name is part of the task's contract. Recorded when the nudge is shown
/// rather than when it is dismissed, so a launch the user abandons still counts
/// as asked (the same rule the OEM setup guide follows).
const String lastBackupNudgeAtKey = 'last_backup_nudge_at';

/// Preference key holding whether backups are encrypted with a passphrase.
///
/// **Off by default**, so a fresh install writes plain backups and asks for no
/// passphrase until the user turns encryption on in Settings > Backup & Restore.
/// A per-user preference (it guards this user's own files), so it lives with the
/// rest of the backup preferences rather than in the database a restore replaces.
const String backupEncryptionEnabledKey = 'backup_encryption_enabled';

/// Interval the mockup shows selected on a fresh install ("Everyday").
const int defaultBackupScheduleDays = 1;

/// What the Backup & Restore screen displays and stores.
class BackupMetadata {
  /// Epoch-ms of the last successful backup, or null when none was made.
  final int? lastSuccessfulAt;

  /// Location of the last successful backup, or null when none was made.
  final String? lastPath;

  /// Chosen automatic-backup interval in days; 0 means "Off".
  final int scheduleDays;

  /// Whether a backup is sealed with a passphrase. False until the user opts in.
  final bool encryptBackups;

  /// Epoch-ms of the last monthly backup nudge, or null when never shown.
  final int? lastNudgedAt;

  /// Creates a metadata snapshot.
  const BackupMetadata({
    this.lastSuccessfulAt,
    this.lastPath,
    this.scheduleDays = defaultBackupScheduleDays,
    this.encryptBackups = false,
    this.lastNudgedAt,
  });

  /// Whether a backup has ever completed on this device.
  bool get hasBackup => lastSuccessfulAt != null;
}

/// Reads and writes [BackupMetadata] through [SharedPreferences].
class BackupMetadataNotifier extends Notifier<BackupMetadata> {
  late final SharedPreferences _prefs;

  @override
  BackupMetadata build() {
    _prefs = ref.read(sharedPreferencesProvider);
    return BackupMetadata(
      lastSuccessfulAt: _prefs.getInt(lastSuccessfulBackupAtKey),
      lastPath: _prefs.getString(lastBackupPathKey),
      scheduleDays:
          _prefs.getInt(backupScheduleDaysKey) ?? defaultBackupScheduleDays,
      encryptBackups: _prefs.getBool(backupEncryptionEnabledKey) ?? false,
      lastNudgedAt: _prefs.getInt(lastBackupNudgeAtKey),
    );
  }

  /// Records a completed backup at [at] (epoch ms) written to [path].
  ///
  /// Called only after the export engine confirmed the file was written, so the
  /// status card can never claim a backup that failed.
  Future<void> recordSuccess({required int at, required String path}) async {
    await _prefs.setInt(lastSuccessfulBackupAtKey, at);
    await _prefs.setString(lastBackupPathKey, path);
    state = BackupMetadata(
      lastSuccessfulAt: at,
      lastPath: path,
      scheduleDays: state.scheduleDays,
      encryptBackups: state.encryptBackups,
      lastNudgedAt: state.lastNudgedAt,
    );
  }

  /// Stores the chosen automatic-backup interval.
  Future<void> setScheduleDays(int days) async {
    if (days == state.scheduleDays) return;
    await _prefs.setInt(backupScheduleDaysKey, days);
    state = BackupMetadata(
      lastSuccessfulAt: state.lastSuccessfulAt,
      lastPath: state.lastPath,
      scheduleDays: days,
      encryptBackups: state.encryptBackups,
      lastNudgedAt: state.lastNudgedAt,
    );
  }

  /// Turns passphrase encryption of backups on or off.
  ///
  /// Only this flag is stored: the passphrase itself is still asked fresh on
  /// every backup and restore and is never written down.
  Future<void> setEncryptBackups(bool enabled) async {
    if (enabled == state.encryptBackups) return;
    await _prefs.setBool(backupEncryptionEnabledKey, enabled);
    state = BackupMetadata(
      lastSuccessfulAt: state.lastSuccessfulAt,
      lastPath: state.lastPath,
      scheduleDays: state.scheduleDays,
      encryptBackups: enabled,
      lastNudgedAt: state.lastNudgedAt,
    );
  }

  /// Records that the monthly nudge was shown at [at] (epoch ms).
  ///
  /// Written when the banner appears, not when it is dismissed: the rule is "at
  /// most once per calendar month", and a user who closes the app without
  /// touching the banner has still been reminded. A backup later the same month
  /// is recorded as usual, and the next nudge waits for the next month.
  Future<void> recordNudge({required int at}) async {
    await _prefs.setInt(lastBackupNudgeAtKey, at);
    state = BackupMetadata(
      lastSuccessfulAt: state.lastSuccessfulAt,
      lastPath: state.lastPath,
      scheduleDays: state.scheduleDays,
      encryptBackups: state.encryptBackups,
      lastNudgedAt: at,
    );
  }

  /// Forgets the stored backup history and schedule (logout/account switch), so
  /// the next account does not inherit the previous holder's backup metadata.
  Future<void> reset() async {
    await _prefs.remove(lastSuccessfulBackupAtKey);
    await _prefs.remove(lastBackupPathKey);
    await _prefs.remove(backupScheduleDaysKey);
    await _prefs.remove(backupEncryptionEnabledKey);
    await _prefs.remove(lastBackupNudgeAtKey);
    state = const BackupMetadata();
  }
}

/// Public provider for the last-backup metadata and the schedule.
final backupMetadataProvider =
    NotifierProvider<BackupMetadataNotifier, BackupMetadata>(
      BackupMetadataNotifier.new,
    );
