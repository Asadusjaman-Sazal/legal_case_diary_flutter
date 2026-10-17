/// Extended-offline recovery lock (Task 19 Phase 5).
///
/// The server keeps a soft-deleted row for 365 days and then purges it. A device
/// that has been away longer than that cannot tell a row it never saw from one
/// that was deleted while it was gone — so if it simply pushed its queued work,
/// it would resurrect data the firm deliberately removed (the Zombie Data rule,
/// Sync Plan §3). The buffer the plan chose is **335 days**, and the comparison
/// is always against **this device's** own `last_successful_sync_at`, never
/// `profiles.last_successful_sync_at`, because another device's recent sync would
/// mask exactly the gap this check exists to find.
///
/// **Firm mode only, by decision.** The risk this guards against is *another*
/// writer deleting or changing a row while this device was away. In individual
/// mode there is no other writer — the diary has one author — so there is nothing
/// that could have been deleted behind the device's back, and locking a
/// single-author diary out of its own edits would be pure harm. [shouldRecover]
/// therefore requires firm mode, and the whole flow (lock, safety copy, wipe) is
/// skipped for an individual account.
///
/// The flag itself lives in the durable `sync_metadata` table, so the lock
/// survives process termination: a device killed while locked comes back locked,
/// and every later launch restores the blocking flow until recovery succeeds.
library;

import '../database/app_database.dart';
import 'sync_metadata_dao.dart';

/// `sync_metadata` key holding the durable recovery-required flag.
const String recoveryRequiredKey = 'extended_offline_recovery_required';

/// `sync_metadata` key holding the atomic recovery checkpoint.
///
/// Written in the same transaction as the wipe, so a device that dies midway
/// through recovery can tell "the wipe committed" from "it did not" — and either
/// way the lock is still set and the flow starts again.
const String recoveryCheckpointKey = 'atomic_recovery_checkpoint';

/// How long a device may stay away before a fresh reconstruction is required.
///
/// 335 days: the plan's 30-day buffer under the server's 365-day tombstone
/// retention (`20261017120000_firm_mode_retention_window.sql`), so a device that
/// recovers always had time to do so before the server started forgetting what it
/// had deleted. The pair moves together — raising this without raising the
/// server's retention would let a late device push a resurrection.
const Duration recoveryOfflineThreshold = Duration(days: 335);

/// Whether this device must recover before it may write again.
///
/// Pure, so the rule is pinned by a test without a database. Returns false when
/// there has never been a successful sync on this device (nothing to compare, and
/// a fresh install is what the initial pull is for) and false for an individual
/// account, which has no other writer to have changed anything behind it.
bool shouldRecover({
  required bool firmMode,
  required int? lastSuccessfulSyncAt,
  required int now,
  Duration threshold = recoveryOfflineThreshold,
}) {
  if (!firmMode) return false;
  if (lastSuccessfulSyncAt == null) return false;
  return now - lastSuccessfulSyncAt >= threshold.inMilliseconds;
}

/// Thrown when a local mutation is attempted while the recovery lock is set.
///
/// Repositories reject every mutation while the lock is on (the plan's rule), and
/// the blocking screen is what the user actually meets; this is the belt to that
/// brace, so a path that bypasses the UI still fails loudly instead of queueing
/// work that the coming reconstruction would silently discard.
class RecoveryRequiredException implements Exception {
  /// Creates the exception.
  const RecoveryRequiredException();

  @override
  String toString() =>
      'RecoveryRequiredException: this device must finish extended-offline '
      'recovery before it can write again.';
}

/// Reads, engages and clears the durable recovery flag.
class RecoveryLock {
  /// Creates the lock over [db].
  RecoveryLock(this.db) : _metadata = SyncMetadataDao(db);

  /// The local database the flag lives in.
  final AppDatabase db;

  final SyncMetadataDao _metadata;

  /// Whether the lock is currently set.
  Future<bool> isRequired() async =>
      await _metadata.getValue(recoveryRequiredKey) == 'true';

  /// Live view of the flag, for the blocking overlay.
  Stream<bool> watchRequired() =>
      _metadata.watchValue(recoveryRequiredKey).map((value) => value == 'true');

  /// Engages the lock and records the checkpoint **in one durable transaction**.
  ///
  /// This is committed before any export or network work, so a crash between the
  /// decision and the safety copy leaves the device locked rather than half
  /// recovered — the direction that loses nothing. The checkpoint holds the
  /// instant the lock was engaged, so the app can tell how long a device has been
  /// waiting once it comes back.
  Future<void> engage({int? at}) async {
    final stamp = at ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    await db.transaction(() async {
      await _metadata.setValue(recoveryRequiredKey, 'true', updatedAt: stamp);
      await _metadata.setValue(
        recoveryCheckpointKey,
        '$stamp',
        updatedAt: stamp,
      );
    });
  }

  /// Clears the lock and the checkpoint **in one durable transaction**.
  ///
  /// Called only after the wipe, the seed reconstruction and the full pull have
  /// all committed, so the flag's absence means the fresh database is real.
  Future<void> clear() async {
    await db.transaction(() async {
      await _metadata.deleteValue(recoveryRequiredKey);
      await _metadata.deleteValue(recoveryCheckpointKey);
    });
  }

  /// The instant the checkpoint was last written, if the lock was ever engaged.
  Future<int?> checkpoint() async {
    final raw = await _metadata.getIntValue(recoveryCheckpointKey);
    return raw;
  }
}
