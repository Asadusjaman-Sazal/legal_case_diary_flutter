/// Shared test double for the automatic-backup scheduler.
///
/// The real scheduler arms an Android alarm, so widget tests over the Backup &
/// Restore screen and the app root drive a [FakeBackupScheduler] instead and
/// assert what the UI asked it to do.
library;

import 'package:legal_case_diary/core/backup/backup_scheduler.dart';

/// Records every scheduler call; controls nothing a test needs answered.
class FakeBackupScheduler implements BackupScheduler {
  /// Times [initialize] was called.
  int initializeCalls = 0;

  /// Times [syncSchedule] was called (one per schedule write).
  int syncScheduleCalls = 0;

  /// Times [cancelAll] was called (logout / account switch).
  int cancelAllCalls = 0;

  /// Times [runNow] was called.
  int runNowCalls = 0;

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  Future<void> syncSchedule() async => syncScheduleCalls++;

  @override
  Future<void> cancelAll() async => cancelAllCalls++;

  @override
  Future<void> runNow() async => runNowCalls++;
}