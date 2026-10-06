/// The branched logout (Task 19 Phase 6).
///
/// Sync Plan §5, and the reason it has branches at all: a single "sync before
/// wipe" rule would deadlock exactly the users who most need to be able to log
/// out — a free account, which has no cloud copy to sync to, and an offline
/// premium account, which cannot reach the server at all.
///
/// The rule underneath every branch is one sentence: **nothing that exists only
/// on this device may be destroyed without a copy.** So the branch depends on
/// where the user's data actually lives:
///
/// * **Premium + online** — the server holds everything that has synced, and the
///   queued mutations are the only thing that has not. Those are sent first
///   (mandatory), and only then is the device wiped. No local export is needed,
///   because the copy that matters is already on the server.
/// * **Premium + offline with unsynced work** — the work exists nowhere else and
///   cannot be sent, so the logout is **blocked** with an explicit way past it.
///   Taking that way always writes the encrypted safety copy first.
/// * **Free** — the local database *is* the only copy of everything, not just of
///   the queue, so a free logout **always** exports before wiping.
/// * **Nothing unsynced to lose** (premium, offline, empty queue) — a clean wipe:
///   there is no work that exists nowhere else.
///
/// The wipe itself is [BackupRepository.wipeAllTables], the same complete scope
/// extended-offline recovery uses (every domain row and tombstone, the queue, the
/// pull-only caches, the per-user preferences and notification configuration, the
/// cursors, the seeded reference data and its ledger, and the rest of the
/// sync/recovery metadata), so a fresh login starts against a fresh database —
/// followed by the initial pull for a premium account, as the Addendum requires.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backup/backup_cipher.dart';
import '../../../core/constants/app_version.dart';
import '../../../database/app_database.dart';
import '../../../features/settings/data/backup_file_gateway.dart';
import '../../../features/settings/data/backup_repository.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../sync/connectivity_monitor.dart';
import '../../../sync/sync_queue_dao.dart';
import '../../../sync/sync_service.dart';
import '../../accounts_and_profile/data/account_mode.dart';
import '../presentation/auth_viewmodel.dart';

/// Which logout branch applies.
enum LogoutBranch {
  /// (a) Premium + online: send the queued work, then wipe.
  syncedThenWiped,

  /// (b) Premium + offline with unsynced work: blocked, with an explicit way past.
  blockedOffline,

  /// (c) Free: export everything, then wipe.
  freeExportThenWipe,

  /// Nothing exists only on this device, so the wipe needs no copy.
  cleanWipe,
}

/// What a logout would do, decided before anything is destroyed.
class LogoutPlan {
  /// Creates a plan.
  const LogoutPlan({required this.branch, required this.unsyncedCount});

  /// Which branch applies.
  final LogoutBranch branch;

  /// How many queue entries still need the server.
  final int unsyncedCount;

  /// Whether this branch must write a safety copy before the wipe may run.
  bool get needsExport =>
      branch == LogoutBranch.freeExportThenWipe ||
      branch == LogoutBranch.blockedOffline;

  /// Whether this branch must warn, because the copies can be lost.
  bool get needsWarning => branch == LogoutBranch.blockedOffline;

  /// Whether this branch must send the queue before it may wipe.
  bool get needsSync => branch == LogoutBranch.syncedThenWiped;
}

/// How a logout attempt ended.
enum LogoutResult {
  /// Wiped and signed out.
  completed,

  /// The mandatory sync could not clear the queue; the caller falls back to the
  /// warning-and-export path rather than leaving the user stuck.
  syncFailed,

  /// The user declined to set a passphrase, so no copy could be written and
  /// nothing was deleted.
  exportCancelled,

  /// The copy could not be written; nothing was deleted.
  exportFailed,
}

/// Runs the branched logout.
class LogoutFlow {
  /// Creates the flow.
  LogoutFlow({
    required this.db,
    required this.premium,
    required this.online,
    required this.runBacklogPush,
    required this.endSession,
    this.sink = const LocalArchiveSink(),
    this.kdfIterations = kBackupKdfIterations,
  });

  /// The local database that is exported and then wiped.
  final AppDatabase db;

  /// Whether this account syncs at all.
  final bool premium;

  /// Whether the device currently has a link.
  final bool online;

  /// The mandatory sync, injected so a test needs no engine: production passes
  /// `SyncService.runBacklogPush`. A null result means the pass refused to start
  /// (offline, no client, not entitled), which the caller treats as a failure.
  final Future<BacklogOutcome?> Function() runBacklogPush;

  /// Ends the session and empties the account caches, injected for the same
  /// reason: production passes `AuthViewModel.signOut`.
  final Future<void> Function() endSession;

  /// Where the safety copy is written.
  ///
  /// Production passes [logoutArchiveSinkProvider] (the Save-to gateway); the
  /// `LocalArchiveSink` default only serves direct construction in a test that
  /// does not inject one.
  final BackupArchiveSink sink;

  /// Injected so a test need not pay a full PBKDF2 stretch.
  final int kdfIterations;

  SyncQueueDao get _queue => SyncQueueDao(db);

  /// Works out which branch applies, without changing anything.
  Future<LogoutPlan> plan() async {
    final unsynced = (await _queue.getUnresolved()).length;

    // A free account has no cloud copy of anything — not just of the queue — so
    // it always exports, whatever the link says.
    if (!premium) {
      return LogoutPlan(
        branch: LogoutBranch.freeExportThenWipe,
        unsyncedCount: unsynced,
      );
    }
    if (!online) {
      // Offline with nothing unsynced: the server holds everything, so the wipe
      // destroys no unique copy and needs no export and no warning.
      return LogoutPlan(
        branch: unsynced == 0
            ? LogoutBranch.cleanWipe
            : LogoutBranch.blockedOffline,
        unsyncedCount: unsynced,
      );
    }
    return LogoutPlan(
      branch: LogoutBranch.syncedThenWiped,
      unsyncedCount: unsynced,
    );
  }

  /// Branch (a): send the queued work, then wipe.
  ///
  /// It succeeds only when the queue is genuinely clear afterwards. A row the
  /// server permanently refused, or one frozen on a conflict, can never sync, and
  /// the caller handles that by falling back to the warning-and-export path —
  /// the alternative would be an account trapped on the device forever.
  Future<LogoutResult> syncThenComplete() async {
    final outcome = await runBacklogPush();
    final remaining = await _queue.getUnresolved();
    if (outcome == null || outcome.failure != null || remaining.isNotEmpty) {
      return LogoutResult.syncFailed;
    }
    await _wipeAndEnd();
    return LogoutResult.completed;
  }

  /// The branch with nothing to send and nothing unique to preserve: just wipe.
  Future<LogoutResult> wipeAndComplete() async {
    await _wipeAndEnd();
    return LogoutResult.completed;
  }

  /// Branches (b) and (c): write the safety copy, then wipe.
  ///
  /// The copy is written **before** the wipe and the wipe does not run if it
  /// could not be written, which is the whole point of the branch. A dismissed
  /// Save-to window is a cancellation, not a failure: nothing was written, so
  /// nothing is deleted and the account stays signed in.
  ///
  /// [passphrase] is null when encryption is off (the default): the copy is then
  /// written as readable JSON. When encryption is on it is the user's passphrase,
  /// and an empty one is treated as a cancelled copy rather than a weak one.
  Future<LogoutResult> exportThenComplete({String? passphrase}) async {
    if (passphrase != null && passphrase.isEmpty) {
      return LogoutResult.exportCancelled;
    }
    final SafetyCopyResult copy;
    try {
      copy = await _writeSafetyCopy(passphrase);
    } on BackupSaveCancelledException {
      return LogoutResult.exportCancelled;
    } on Object {
      return LogoutResult.exportFailed;
    }
    if (copy.path.isEmpty) return LogoutResult.exportFailed;
    await _wipeAndEnd();
    return LogoutResult.completed;
  }

  /// The path of the safety copy a completed [exportThenComplete] wrote, for the
  /// message the user is shown.
  String? lastArchivePath;

  /// Writes the export and records where it went.
  Future<SafetyCopyResult> _writeSafetyCopy(String? passphrase) async {
    final result = await BackupRepository(db).exportSnapshot(
      sink: sink,
      appVersion: appVersion,
      recoverySecret: passphrase,
      kdfIterations: kdfIterations,
    );
    lastArchivePath = result.path;
    return SafetyCopyResult(path: result.path, checksum: result.checksum);
  }

  /// The complete wipe, then the sign-out.
  ///
  /// The wipe runs first so that a failure leaves the account signed in and the
  /// data intact — the retryable direction. Nothing is preserved: a logout ends
  /// one account's device, so the archive receipt belongs to the account that is
  /// leaving.
  Future<void> _wipeAndEnd() async {
    await BackupRepository(db).wipeAllTables();
    await endSession();
  }
}

/// The receipt of a logout safety copy.
class SafetyCopyResult {
  /// Creates a receipt.
  const SafetyCopyResult({required this.path, required this.checksum});

  /// Where the file was written.
  final String path;

  /// Its SHA-256, for support to verify against.
  final String checksum;
}

/// Where a logout safety copy is written.
///
/// The **same gateway as `Backup to Local Storage`** — a Save-to window — so the
/// copy lands where the user chose and the Restore picker can open it again.
/// That is the plan's "exactly the same manner and format", and it is what makes
/// the *"you can restore it after logging back in"* promise true: the extended-
/// offline safety copy (Task 19 Phase 5) is the one that must be dialog-less,
/// because the app is locked and nobody can answer a window, and it keeps its own
/// `LocalArchiveSink` for exactly that reason. A test overrides this with a
/// recording sink.
final logoutArchiveSinkProvider = Provider<BackupArchiveSink>(
  (ref) => ref.watch(backupFileGatewayProvider),
);

/// The flow for this account and this device state.
final logoutFlowProvider = FutureProvider<LogoutFlow>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return LogoutFlow(
    db: db,
    premium: await ref.watch(premiumAccessProvider.future),
    online: ref.watch(isOnlineProvider).value ?? false,
    runBacklogPush: () => ref.read(syncServiceProvider).runBacklogPush(),
    endSession: () => ref.read(authViewModelProvider.notifier).signOut(),
    sink: ref.watch(logoutArchiveSinkProvider),
  );
});
