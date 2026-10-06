/// The extended-offline recovery flow (Task 19 Phase 5).
///
/// Four steps, in the order the plan fixes them, and the order is the safety
/// property: the **lock is committed first**, the **safety copy** is written
/// before anything is erased, **Proceed** verifies that copy before it wipes
/// anything, and only a wipe + seed reconstruction + full authenticated pull that
/// all succeeded clears the lock. Any failure at any step leaves the lock set, so
/// the device simply starts the flow again — it never ends up half recovered.
///
/// The export is the ordinary Task 15 path ([BackupRepository.exportSnapshot]),
/// which already snapshots every table — including `sync_queue` (the pending,
/// blocked and conflicted rows) and `sync_metadata` — into the versioned
/// encrypted container. The only difference is the destination: a
/// [LocalArchiveSink] writes into the app's own documents directory instead of
/// through the Save-to dialog, because the app is locked and there is nobody to
/// answer a window.
///
/// **Firm mode only.** See `recovery_lock.dart`: an individual account has no
/// other writer, so nothing can have been deleted behind it and it is never
/// locked.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backup/backup_cipher.dart';
import '../core/backup/backup_format.dart';
import '../core/constants/app_version.dart';
import '../core/providers/repository_providers.dart';
import '../database/app_database.dart';
import '../database/seed_migration_runner.dart';
import '../features/accounts_and_profile/data/account_mode.dart';
import '../features/settings/data/backup_file_gateway.dart';
import '../features/settings/data/backup_repository.dart';
import '../shared/providers/database_provider.dart';
import 'pull_worker.dart';
import 'recovery_lock.dart';
import 'sync_metadata_dao.dart';
import 'sync_queue_dao.dart';
import 'sync_transport.dart';

/// How a recovery attempt ended.
enum RecoveryOutcome {
  /// The wipe, the reconstruction and the pull all committed; the lock is clear.
  recovered,

  /// No completed safety copy is recorded, so there is nothing to verify.
  noSafetyCopy,

  /// The recorded copy could not be read, or its checksum does not match.
  archiveUnverifiable,

  /// The device has no usable link, which the authenticated pull requires.
  offline,

  /// Something failed mid-recovery; the lock is still set and may be retried.
  failed,
}

/// The recorded safety copy, if one exists.
typedef SafetyCopyState = ({String? path, String? checksum, bool complete});

/// Runs the extended-offline recovery.
class RecoveryFlow {
  /// Creates the flow.
  RecoveryFlow({
    required this.db,
    required this.firmMode,
    required this.currentUserId,
    required this.transport,
    int Function()? clock,
    Future<Uint8List> Function(String path)? readArchive,
  }) : _clock = clock ?? _now,
       _readArchive = readArchive ?? _readFile;

  /// The local database that is exported and then reconstructed.
  final AppDatabase db;

  /// Whether this account is a firm member. Individual mode never recovers.
  final bool firmMode;

  /// Injected into the pull's conflict mirrors, exactly like every other write.
  final String currentUserId;

  /// The REST transport the authenticated full pull needs; null with no backend.
  final SyncTransport? transport;

  final int Function() _clock;
  final Future<Uint8List> Function(String path) _readArchive;

  /// The lock, engaged by [checkOnReconnect] and cleared by [proceed].
  RecoveryLock get lock => RecoveryLock(db);

  /// Runs the per-device check and engages the lock when the device is too far
  /// behind — or returns whether it is already locked.
  ///
  /// It reads **this device's** own `last_successful_sync_at`, never the profile's
  /// copy: another device's recent sync would hide exactly the gap being looked
  /// for. It is a no-op in individual mode.
  Future<bool> checkOnReconnect() async {
    if (!firmMode) return false;
    final lock = this.lock;
    if (await lock.isRequired()) return true;

    final lastSuccess = await SyncMetadataDao(
      db,
    ).getIntValue(lastSuccessfulSyncAtKey);
    final now = _clock();
    if (!shouldRecover(
      firmMode: true,
      lastSuccessfulSyncAt: lastSuccess,
      now: now,
    )) {
      return false;
    }
    await lock.engage(at: now);
    return true;
  }

  /// The last recorded safety copy.
  Future<SafetyCopyState> safetyCopy() async {
    final archive = await BackupRepository(db).readArchiveState();
    return (
      path: archive.path,
      checksum: archive.checksum,
      complete: archive.hasCompletedArchive,
    );
  }

  /// Writes the automatic safety copy. When [passphrase] is non-null the copy is
  /// sealed with it; when null (encryption off, the default) it is written
  /// unencrypted.
  ///
  /// A passphrase is never generated and never stored: an archive nobody can open
  /// would be worse than no archive at all. Returns the recorded copy, or null
  /// when the write failed and nothing was recorded.
  Future<SafetyCopyState?> saveSafetyCopy({
    String? passphrase,
    int kdfIterations = kBackupKdfIterations,
    BackupArchiveSink sink = const LocalArchiveSink(),
  }) async {
    try {
      await BackupRepository(db).exportSnapshot(
        sink: sink,
        appVersion: appVersion,
        recoverySecret: passphrase,
        kdfIterations: kdfIterations,
      );
    } on Object {
      // Nothing is recorded on a failed write, so the screen simply offers the
      // step again rather than claiming a copy that does not exist.
      return null;
    }
    return safetyCopy();
  }

  /// **Proceed**: verify the copy, then rebuild this device from the server.
  ///
  /// The wipe preserves only the archive's own record — the path, checksum and
  /// completion state of a file that lives outside the database. Everything else
  /// goes, including the tombstones, the queue, the pull-only caches, the
  /// preferences and notification configuration, the cursors, the seeded
  /// reference data and its ledger, and the rest of the recovery metadata. No
  /// session material is held in the database at all, so nothing has to be
  /// carried across: the signed-in session in platform storage is what
  /// authenticates the pull, and it is never touched.
  Future<RecoveryOutcome> proceed() async {
    final archive = await BackupRepository(db).readArchiveState();
    if (!archive.hasCompletedArchive) return RecoveryOutcome.noSafetyCopy;

    final path = archive.path!;
    final checksum = archive.checksum!;
    if (!await _verifyArchive(path, checksum)) {
      return RecoveryOutcome.archiveUnverifiable;
    }

    final transport = this.transport;
    if (transport == null) return RecoveryOutcome.offline;

    try {
      await _wipeAndCheckpoint();
      // The app's own baseline reference data first, then the authoritative rows
      // over the top, so a device that comes back holds exactly what the server
      // has plus the seeds every install starts from.
      await SeedMigrationRunner(db).runMigrations();
      await PullWorker(
        db: db,
        metadata: SyncMetadataDao(db),
        queue: SyncQueueDao(db),
        transport: transport,
        currentUserId: currentUserId,
      ).pullAll(fromSentinel: true);
      // Only now, with the fresh database real, does the lock come off.
      await lock.clear();
      return RecoveryOutcome.recovered;
    } on Object {
      // The lock stays set — `clear` was never reached — so the next launch
      // restores the blocking flow and the wipe simply runs again.
      return RecoveryOutcome.failed;
    }
  }

  /// Whether the recorded copy is the one that was written: read it back and
  /// compare its checksum.
  Future<bool> _verifyArchive(String path, String checksum) async {
    try {
      final bytes = await _readArchive(path);
      return checksumOfBytes(bytes) == checksum;
    } on Object {
      // An unreadable file (removed by the user, or a content URI) is not a
      // verified copy, and no wipe may follow it.
      return false;
    }
  }

  /// Erases every app-state table, then stamps the checkpoint, all in one
  /// durable transaction.
  ///
  /// The wipe itself is [BackupRepository.wipeAllTables] — the same complete
  /// scope a logout uses, so the two can never drift apart. It runs inside this
  /// transaction (as a nested savepoint), so the erase and the checkpoint commit
  /// together: either the device is untouched, or it is empty and knows it.
  Future<void> _wipeAndCheckpoint() async {
    final metadata = SyncMetadataDao(db);
    final stamp = _clock();
    await db.transaction(() async {
      // The archive's receipt survives, because it describes a file outside the
      // database and is what [proceed] verifies against on a retry. Everything
      // else — cursors, clock offset, the last successful sync, the recovery
      // metadata itself — is exactly what must be rebuilt.
      await BackupRepository(
        db,
      ).wipeAllTables(keepMetadataKeys: archiveMetadataKeys);
      await metadata.setValue(recoveryRequiredKey, 'true', updatedAt: stamp);
      await metadata.setValue(
        recoveryCheckpointKey,
        '$stamp',
        updatedAt: stamp,
      );
    });
  }

  static int _now() => DateTime.now().toUtc().millisecondsSinceEpoch;

  static Future<Uint8List> _readFile(String path) => File(path).readAsBytes();
}

/// The lock's service.
final recoveryLockProvider = FutureProvider<RecoveryLock>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return RecoveryLock(db);
});

/// Whether this device is currently locked, live, for the blocking overlay.
final recoveryRequiredProvider = StreamProvider<bool>((ref) async* {
  final db = await ref.watch(databaseProvider.future);
  yield* RecoveryLock(db).watchRequired();
});

/// The last recorded safety copy, live, for the screen's status line.
final recoverySafetyCopyProvider = StreamProvider<SafetyCopyState>((
  ref,
) async* {
  final db = await ref.watch(databaseProvider.future);
  final repository = BackupRepository(db);
  await for (final _ in SyncMetadataDao(db).watchValue(archiveStateKey)) {
    final archive = await repository.readArchiveState();
    yield (
      path: archive.path,
      checksum: archive.checksum,
      complete: archive.hasCompletedArchive,
    );
  }
});

/// The recovery flow for this account and this device state.
final recoveryFlowProvider = FutureProvider<RecoveryFlow>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final client = ref.watch(activeSupabaseClientProvider);
  return RecoveryFlow(
    db: db,
    firmMode: ref.watch(firmModeProvider),
    currentUserId: ref.watch(accountCacheUserIdProvider),
    transport: client == null ? null : SupabaseSyncTransport(client),
  );
});
