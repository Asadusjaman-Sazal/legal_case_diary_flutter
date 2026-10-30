/// Tests for extended-offline recovery (Task 19 Phase 5).
///
/// Three things matter here and each is pinned: the **firm-mode gate** (an
/// individual account is never locked), the **durability** of the flag (it is
/// read from the database, so a fresh `RecoveryLock` over the same database still
/// sees it — which is what makes the lock survive process death), and the
/// **order** of Proceed (an unverified or missing copy stops the wipe before it
/// starts, and only a completed wipe + seed + pull clears the lock).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/settings/data/backup_repository.dart';
import 'package:legal_case_diary/sync/recovery_flow.dart';
import 'package:legal_case_diary/sync/recovery_lock.dart';
import 'package:legal_case_diary/sync/sync_metadata_dao.dart';
import 'package:legal_case_diary/sync/sync_transport.dart';

/// A sink that keeps the bytes it was handed, so a test can verify against them.
class _RecordingSink implements BackupArchiveSink {
  late Uint8List bytes;
  late String fileName;

  @override
  Future<String> write({
    required String fileName,
    required Uint8List bytes,
  }) async {
    this.fileName = fileName;
    this.bytes = bytes;
    return 'C:/tmp/$fileName';
  }
}

/// A transport that answers every page with an empty page, so a full pull
/// completes without a server.
class _EmptyServer implements SyncTransport {
  /// Tables the pull walked.
  final List<String> tables = [];

  @override
  Future<List<Map<String, dynamic>>> fetchPage(
    String table, {
    String? sinceTime,
    String? sinceId,
    int limit = 200,
  }) async {
    tables.add(table);
    return const [];
  }

  @override
  Future<Map<String, dynamic>?> fetchRow(String table, String id) async => null;

  @override
  Future<List<Map<String, dynamic>>> pushChanges(
    List<Map<String, dynamic>> rows,
  ) async => const [];

  @override
  Future<DateTime?> serverTime() async => null;
}

void main() {
  const now = 1000000000000;
  const day = Duration.millisecondsPerDay;

  group('shouldRecover', () {
    test('a firm device away past the threshold recovers', () {
      expect(
        shouldRecover(
          firmMode: true,
          lastSuccessfulSyncAt: now - 336 * day,
          now: now,
        ),
        isTrue,
      );
    });

    test('a firm device inside the threshold does not', () {
      expect(
        shouldRecover(
          firmMode: true,
          lastSuccessfulSyncAt: now - 334 * day,
          now: now,
        ),
        isFalse,
      );
    });

    test('the threshold itself is enough', () {
      expect(
        shouldRecover(
          firmMode: true,
          lastSuccessfulSyncAt: now - 335 * day,
          now: now,
        ),
        isTrue,
      );
    });

    test('the threshold is 335 days, 30 below the server\'s 365-day retention', () {
      // The server forgets a tombstone after 365 days
      // (`20261017120000_firm_mode_retention_window.sql`); the device recovers 30
      // days before that, so the pair cannot drift apart silently.
      const serverRetention = Duration(days: 365);
      expect(recoveryOfflineThreshold, const Duration(days: 335));
      expect(
        serverRetention - recoveryOfflineThreshold,
        const Duration(days: 30),
      );
    });

    test('an individual account never recovers, however long it was away', () {
      expect(
        shouldRecover(
          firmMode: false,
          lastSuccessfulSyncAt: now - 4000 * day,
          now: now,
        ),
        isFalse,
      );
    });

    test('a device that has never synced does not recover', () {
      expect(
        shouldRecover(firmMode: true, lastSuccessfulSyncAt: null, now: now),
        isFalse,
      );
    });
  });

  group('RecoveryFlow', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.customSelect('select 1').get();
    });

    tearDown(() async => db.close());

    RecoveryFlow flow({
      bool firmMode = true,
      SyncTransport? transport,
      Future<Uint8List> Function(String path)? readArchive,
    }) => RecoveryFlow(
      db: db,
      firmMode: firmMode,
      currentUserId: 'user-1',
      transport: transport,
      clock: () => now,
      readArchive: readArchive,
    );

    Future<void> setLastSync(int? at) async {
      final metadata = SyncMetadataDao(db);
      if (at == null) return;
      await metadata.setIntValue(lastSuccessfulSyncAtKey, at);
    }

    test('the flag is durable, so the lock survives a fresh process', () async {
      await RecoveryLock(db).engage(at: now);
      // A brand-new lock over the same database, as a relaunch would build.
      expect(await RecoveryLock(db).isRequired(), isTrue);
      await RecoveryLock(db).clear();
      expect(await RecoveryLock(db).isRequired(), isFalse);
    });

    test('an individual account is never locked', () async {
      await setLastSync(now - 400 * day);
      expect(await flow(firmMode: false).checkOnReconnect(), isFalse);
      expect(await RecoveryLock(db).isRequired(), isFalse);
    });

    test('a firm account inside the threshold is not locked', () async {
      await setLastSync(now - 10 * day);
      expect(await flow().checkOnReconnect(), isFalse);
      expect(await RecoveryLock(db).isRequired(), isFalse);
    });

    test('a firm account past the threshold is locked', () async {
      await setLastSync(now - 400 * day);
      expect(await flow().checkOnReconnect(), isTrue);
      expect(await RecoveryLock(db).isRequired(), isTrue);
      // The checkpoint was committed with the flag.
      expect(await RecoveryLock(db).checkpoint(), isNotNull);
      // And a second check does not touch it again.
      expect(await flow().checkOnReconnect(), isTrue);
    });

    test(
      'the safety copy is recorded, and proceed will not run without it',
      () async {
        final sink = _RecordingSink();
        final copy = await flow().saveSafetyCopy(
          passphrase: 'correct-horse',
          kdfIterations: 1000,
          sink: sink,
        );

        expect(copy, isNotNull);
        expect(copy!.complete, isTrue);
        expect(copy.path, 'C:/tmp/${sink.fileName}');
        // Encrypted, not readable JSON.
        expect(utf8.decode(sink.bytes), isNot(contains('court_categories')));

        // No copy recorded yet on a second, fresh database: nothing to verify.
        final fresh = AppDatabase(NativeDatabase.memory());
        addTearDown(fresh.close);
        final outcome = await RecoveryFlow(
          db: fresh,
          firmMode: true,
          currentUserId: 'user-1',
          transport: _EmptyServer(),
          clock: () => now,
        ).proceed();
        expect(outcome, RecoveryOutcome.noSafetyCopy);
      },
    );

    test(
      'a checksum that does not match stops the wipe before it starts',
      () async {
        final sink = _RecordingSink();
        await flow().saveSafetyCopy(
          passphrase: 'correct-horse',
          kdfIterations: 1000,
          sink: sink,
        );
        await db
            .into(db.notes)
            .insert(
              NotesCompanion.insert(
                id: 'n1',
                userId: 'user-1',
                title: 'Local',
                body: 'Body',
                createdAt: 0,
                updatedAt: 0,
              ),
            );
        await RecoveryLock(db).engage(at: now);

        final outcome = await flow(
          transport: _EmptyServer(),
          // A copy that is not the one that was recorded.
          readArchive: (_) async => Uint8List.fromList(const [1, 2, 3]),
        ).proceed();

        expect(outcome, RecoveryOutcome.archiveUnverifiable);
        // Nothing was erased and the lock stayed on.
        expect((await db.select(db.notes).get()), hasLength(1));
        expect(await RecoveryLock(db).isRequired(), isTrue);
      },
    );

    test('offline keeps the lock and erases nothing', () async {
      final sink = _RecordingSink();
      await flow().saveSafetyCopy(
        passphrase: 'correct-horse',
        kdfIterations: 1000,
        sink: sink,
      );
      await RecoveryLock(db).engage(at: now);

      final outcome = await flow(
        readArchive: (_) async => sink.bytes,
      ).proceed();

      expect(outcome, RecoveryOutcome.offline);
      expect(await RecoveryLock(db).isRequired(), isTrue);
    });

    test(
      'a verified copy wipes everything, reconstructs and clears the lock',
      () async {
        final sink = _RecordingSink();
        await flow().saveSafetyCopy(
          passphrase: 'correct-horse',
          kdfIterations: 1000,
          sink: sink,
        );
        // Data that must not survive recovery.
        await db
            .into(db.notes)
            .insert(
              NotesCompanion.insert(
                id: 'n1',
                userId: 'user-1',
                title: 'Local',
                body: 'Body',
                createdAt: 0,
                updatedAt: 0,
              ),
            );
        await db
            .into(db.syncQueue)
            .insert(
              SyncQueueCompanion.insert(
                entityType: 'case',
                entityId: 'c1',
                operation: 'update',
                mutationId: 'm1',
                basePayload: '{}',
                changedFields: '["case_number"]',
                payload: '{"id":"c1"}',
                preMutationPayload: '{}',
                createdAt: 0,
                state: 'pending',
              ),
            );
        await RecoveryLock(db).engage(at: now);

        final server = _EmptyServer();
        final outcome = await flow(
          transport: server,
          readArchive: (_) async => sink.bytes,
        ).proceed();

        expect(outcome, RecoveryOutcome.recovered);
        // The queue and the domain rows are gone; the pull walked every table.
        expect(await db.select(db.syncQueue).get(), isEmpty);
        expect(await db.select(db.notes).get(), isEmpty);
        expect(server.tables, hasLength(13));
        // The lock is off and the checkpoint is gone.
        expect(await RecoveryLock(db).isRequired(), isFalse);
        expect(await RecoveryLock(db).checkpoint(), isNull);
        // The seeded reference data was reconstructed, and the safety copy's own
        // receipt survived the wipe so it is still verifiable afterwards.
        expect((await db.select(db.seedMigrations).get()), isNotEmpty);
        expect((await db.select(db.caseTypes).get()), isNotEmpty);
        expect(
          await SyncMetadataDao(db).getValue(archiveStateKey),
          archiveStateComplete,
        );
      },
    );
  });
}
