/// Last-backup metadata and the automatic-backup schedule (Task 15 Phase 4).
///
/// The Backup & Restore screen shows when and where the last successful backup
/// went, and remembers the schedule the user picked. Both live in
/// [SharedPreferences] (the task's requirement, and the keys Phase 6's monthly
/// nudge reads), not in the database — the database is exactly what a restore
/// replaces, so its own record cannot be the thing the screen reports on.
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

  /// Creates a metadata snapshot.
  const BackupMetadata({
    this.lastSuccessfulAt,
    this.lastPath,
    this.scheduleDays = defaultBackupScheduleDays,
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
    );
  }
}

/// Public provider for the last-backup metadata and the schedule.
final backupMetadataProvider =
    NotifierProvider<BackupMetadataNotifier, BackupMetadata>(
      BackupMetadataNotifier.new,
    );
