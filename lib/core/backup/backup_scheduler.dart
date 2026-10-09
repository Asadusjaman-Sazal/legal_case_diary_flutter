/// Platform abstraction over the automatic backup scheduler.
///
/// Mirrors `notification_scheduler.dart`: call sites (the app root, the Backup
/// & Restore screen) depend on this contract only, so the planned Windows port
/// swaps the implementation without rewriting callers.
library;

/// The platform automatic-backup scheduler contract.
///
/// The background job itself does not go through this interface, exactly like
/// notifications: it runs in the alarm isolate, where no Riverpod scope exists,
/// and talks to the gateway directly.
abstract class BackupScheduler {
  /// Arms (or re-arms on launch) the recurring backup alarm from the stored
  /// schedule. Idempotent, and must survive being called every launch.
  Future<void> initialize();

  /// (Re-)arms for the schedule stored right now; cancels when it is Off.
  Future<void> syncSchedule();

  /// Cancels the recurring backup alarm (account switch / logout / wipe).
  Future<void> cancelAll();

  /// Runs the backup job immediately, whatever the stored schedule.
  ///
  /// Used by tests; the alarm job is the production caller.
  Future<void> runNow();
}