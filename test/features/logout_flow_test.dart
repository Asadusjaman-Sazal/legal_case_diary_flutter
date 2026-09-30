/// Tests for the branched logout (Task 19 Phase 6).
///
/// The rule every branch serves is one sentence — *nothing that exists only on
/// this device may be destroyed without a copy* — so that is what these pin: the
/// branch is chosen from where the data actually lives, the mandatory sync really
/// gates the wipe, the export really gates it too (a cancelled or failed copy
/// deletes nothing and ends no session), and the wipe is the complete scope.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/auth/data/logout_flow.dart';
import 'package:legal_case_diary/features/settings/data/backup_repository.dart';
import 'package:legal_case_diary/sync/sync_metadata_dao.dart';
import 'package:legal_case_diary/sync/sync_service.dart';
import 'package:legal_case_diary/sync/sync_transport.dart';

/// A sink that keeps what it was handed, or refuses on demand.
class _RecordingSink implements BackupArchiveSink {
  Uint8List? bytes;
  bool fail = false;

  @override
  Future<String> write({
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (fail) throw Exception('disk full');
    this.bytes = bytes;
    return 'C:/tmp/$fileName';
  }
}

void main() {
  late AppDatabase db;
  var ended = 0;

  setUp(() async {
    ended = 0;
    db = AppDatabase(NativeDatabase.memory());
    await db.customSelect('select 1').get();
  });

  tearDown(() async => db.close());

  LogoutFlow flow({
    bool premium = true,
    bool online = true,
    Future<BacklogOutcome?> Function()? push,
    BackupArchiveSink? sink,
  }) => LogoutFlow(
    db: db,
    premium: premium,
    online: online,
    runBacklogPush: push ?? () async => const BacklogOutcome(),
    endSession: () async => ended++,
    sink: sink ?? _RecordingSink(),
    kdfIterations: 1000,
  );

  Future<void> queueRow({String state = 'pending'}) async {
    await db
        .into(db.syncQueue)
        .insert(
          SyncQueueCompanion.insert(
            entityType: 'note',
            entityId: 'n1',
            operation: 'update',
            mutationId: 'mut-$state',
            basePayload: '{}',
            changedFields: '["title"]',
            payload: '{"id":"n1"}',
            preMutationPayload: '{}',
            createdAt: 0,
            state: state,
          ),
        );
  }

  /// One row in every class the wipe must reach, so an incomplete scope fails.
  Future<void> seedEveryClass() async {
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
    await queueRow();
    await db
        .into(db.userPreferences)
        .insert(
          UserPreferencesCompanion.insert(userId: 'user-1', updatedAt: 0),
        );
    await SyncMetadataDao(db).setValue('cursor.cases', 'x');
    await SyncMetadataDao(db).setValue(archiveStateKey, archiveStateComplete);
  }

  Future<void> expectEverythingGone() async {
    expect(await db.select(db.notes).get(), isEmpty);
    expect(await db.select(db.syncQueue).get(), isEmpty);
    expect(await db.select(db.userPreferences).get(), isEmpty);
    expect(await db.select(db.syncMetadata).get(), isEmpty);
    expect(await db.select(db.seedMigrations).get(), isEmpty);
  }

  group('branch selection', () {
    test('premium + online sends first', () async {
      await queueRow();
      final plan = await flow().plan();
      expect(plan.branch, LogoutBranch.syncedThenWiped);
      expect(plan.unsyncedCount, 1);
      expect(plan.needsSync, isTrue);
      expect(plan.needsExport, isFalse);
    });

    test('premium + offline with unsynced work blocks', () async {
      await queueRow();
      final plan = await flow(online: false).plan();
      expect(plan.branch, LogoutBranch.blockedOffline);
      expect(plan.needsWarning, isTrue);
      expect(plan.needsExport, isTrue);
    });

    test('premium + offline with nothing unsynced is a clean wipe', () async {
      final plan = await flow(online: false).plan();
      expect(plan.branch, LogoutBranch.cleanWipe);
      expect(plan.needsExport, isFalse);
      expect(plan.needsWarning, isFalse);
    });

    test('a free account always exports, online or not', () async {
      for (final online in [true, false]) {
        final plan = await flow(premium: false, online: online).plan();
        expect(plan.branch, LogoutBranch.freeExportThenWipe);
        expect(plan.needsExport, isTrue, reason: 'no cloud copy exists');
        expect(plan.needsWarning, isFalse);
      }
    });
  });

  group('mandatory sync', () {
    test('a cleared queue completes the logout', () async {
      await seedEveryClass();
      // The fake push clears the queue, as an accepted mutation would.
      final result = await flow(
        push: () async {
          await db.delete(db.syncQueue).go();
          return const BacklogOutcome(pushed: 1);
        },
      ).syncThenComplete();

      expect(result, LogoutResult.completed);
      expect(ended, 1);
      await expectEverythingGone();
    });

    test(
      'a queue that cannot be cleared wipes nothing and signs nobody out',
      () async {
        await seedEveryClass();
        // A row the server permanently refused: still there after the pass.
        final result = await flow(
          push: () async => const BacklogOutcome(blocked: 1),
        ).syncThenComplete();

        expect(result, LogoutResult.syncFailed);
        expect(ended, 0);
        expect(await db.select(db.notes).get(), hasLength(1));
        expect(await db.select(db.syncQueue).get(), hasLength(1));
      },
    );

    test('a transport failure fails the branch', () async {
      await queueRow();
      final result = await flow(
        push: () async => const BacklogOutcome(
          failure: SyncFailure(
            'offline',
            kind: SyncFailureKind.network,
            retryable: true,
          ),
        ),
      ).syncThenComplete();

      expect(result, LogoutResult.syncFailed);
      expect(ended, 0);
    });

    test('a refusal to start fails the branch', () async {
      await queueRow();
      final result = await flow(push: () async => null).syncThenComplete();
      expect(result, LogoutResult.syncFailed);
      expect(ended, 0);
    });

    test('a clean wipe needs neither sync nor copy', () async {
      await seedEveryClass();
      final result = await flow().wipeAndComplete();
      expect(result, LogoutResult.completed);
      expect(ended, 1);
      await expectEverythingGone();
    });
  });

  group('export gate', () {
    test('the copy is written, then everything goes', () async {
      await seedEveryClass();
      final sink = _RecordingSink();
      final flowUnderTest = flow(sink: sink, premium: false);
      final result = await flowUnderTest.exportThenComplete(
        passphrase: 'correct-horse',
      );

      expect(result, LogoutResult.completed);
      expect(ended, 1);
      expect(flowUnderTest.lastArchivePath, isNotNull);
      // Encrypted, not readable JSON.
      expect(utf8.decode(sink.bytes!), isNot(contains('court_categories')));
      // The logout keeps nothing: the archive receipt describes the account that
      // is leaving, so unlike recovery it does not survive.
      await expectEverythingGone();
      expect(
        await db.select(db.syncMetadata).get(),
        isEmpty,
        reason: 'a logout preserves no metadata at all',
      );
    });

    test(
      'an empty passphrase cancels the logout and deletes nothing',
      () async {
        await seedEveryClass();
        final result = await flow(
          premium: false,
        ).exportThenComplete(passphrase: '');

        expect(result, LogoutResult.exportCancelled);
        expect(ended, 0);
        expect(await db.select(db.notes).get(), hasLength(1));
        expect(await db.select(db.syncQueue).get(), hasLength(1));
      },
    );

    test('a copy that cannot be written deletes nothing', () async {
      await seedEveryClass();
      final sink = _RecordingSink()..fail = true;
      final result = await flow(
        sink: sink,
        premium: false,
      ).exportThenComplete(passphrase: 'correct-horse');

      expect(result, LogoutResult.exportFailed);
      expect(ended, 0);
      expect(await db.select(db.notes).get(), hasLength(1));
      expect(await db.select(db.syncQueue).get(), hasLength(1));
    });
  });
}
