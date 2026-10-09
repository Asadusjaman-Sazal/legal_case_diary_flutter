/// Riverpod providers for the automatic-backup scheduler.
///
/// Tests override `backupSchedulerProvider` with a fake, exactly like
/// `notificationSchedulerProvider`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/data/backup_metadata_store.dart';
import '../backup/android_backup_scheduler.dart';
import '../backup/backup_scheduler.dart';

/// The platform automatic-backup scheduler.
final backupSchedulerProvider = Provider<BackupScheduler>((ref) {
  return AndroidBackupScheduler(
    readScheduleDays: () async =>
        ref.read(backupMetadataProvider).scheduleDays,
  );
});