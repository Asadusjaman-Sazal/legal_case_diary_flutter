/// Conflict resolver tests — Task 19 Phase 3.
///
/// The resolver is the single answer path for both the push worker and the delta
/// pull, so it is exercised directly here against an in-memory Drift database:
/// a disjoint edit rebases itself, a collision or a tombstone is preserved and
/// frozen, and each of the Review screen's three answers leaves the queue, the
/// local row and the conflict record in the state the plan requires.
library;

import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/sync/conflict_log_dao.dart';
import 'package:legal_case_diary/sync/conflict_resolution.dart';
import 'package:legal_case_diary/sync/sync_conflict_log.dart';
import 'package:legal_case_diary/sync/sync_queue_dao.dart';

/// A `notes` server row.
Map<String, dynamic> noteServer(
  String id, {
  String title = 'Server',
  int version = 2,
  bool isDeleted = false,
}) =>
    <String, dynamic>{
      'id': id,
      'user_id': 'user-1',
      'title': title,
      'body': 'Body',
      'is_pinned': false,
      'created_at': 0,
      'updated_at': 0,
      'version': version,
      'is_deleted': isDeleted,
      'server_updated_at': '2026-09-30T10:00:00.000000+00:00',
    };

void main() {
  late AppDatabase db;
  late SyncQueueDao queue;
  late ConflictResolver resolver;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.customSelect('select 1').get();
    queue = SyncQueueDao(db);
    resolver = ConflictResolver(
      db: db,
      queue: queue,
      currentUserId: 'user-1',
      conflictDao: ConflictLogDao(db),
    );
  });

  tearDown(() => db.close());

  Future<SyncQueueRow> enqueue({
    String entityId = 'n1',
    Map<String, dynamic> basePayload = const <String, dynamic>{},
    Map<String, dynamic> payload = const <String, dynamic>{},
    int? baseVersion,
  }) async {
    await queue.insert(
      SyncQueueCompanion.insert(
        entityType: 'note',
        entityId: entityId,
        operation: 'update',
        mutationId: 'mut-$entityId',
        baseVersion: Value(baseVersion),
        basePayload: jsonEncode(basePayload),
        changedFields: jsonEncode(payload.keys.toList()),
        payload: jsonEncode(payload),
        preMutationPayload: '{}',
        createdAt: 0,
        state: 'pending',
      ),
    );
    return (await queue.getAll()).last;
  }

  Future<Note> localNote(String id) =>
      (db.select(db.notes)..where((row) => row.id.equals(id))).getSingle();

  group('reconcile', () {
    test('a disjoint change is rebased, never frozen, and logged as answered',
        () async {
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: 'n1',
              userId: 'user-1',
              title: 'Base',
              body: 'Mine Body',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      final row = await enqueue(
        basePayload: <String, dynamic>{'id': 'n1', 'body': 'Body'},
        payload: <String, dynamic>{'id': 'n1', 'body': 'Mine Body'},
        baseVersion: 1,
      );

      final needsReview = await resolver.reconcile(
        row: row,
        serverRow: noteServer('n1', title: 'Server', version: 2),
      );

      expect(needsReview, isFalse, reason: 'nobody has to look at this');
      final merged = (await queue.getAll())
          .firstWhere((r) => r.entityType == 'note' && r.entityId == 'n1');
      expect(merged.state, 'pending');
      expect(merged.baseVersion, 2);
      expect(merged.mutationId, isNot('mut-n1'));
      final payload = jsonDecode(merged.payload) as Map<String, dynamic>;
      expect(payload['body'], 'Mine Body', reason: 'the local edit survives');
      expect(payload['title'], 'Server', reason: 'the server change survives');

      final conflict = (await db.select(db.conflictLog).get()).single;
      expect(conflict.mergeableConflict, isTrue);
      expect(conflict.resolutionState, conflictRebased);
      expect(conflict.resolvedAt, isNotNull);
      // The local row already shows the merged state.
      expect((await localNote('n1')).title, 'Server');
    });

    test('an overlapping change is preserved and its entity frozen', () async {
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: 'n1',
              userId: 'user-1',
              title: 'Mine',
              body: 'Body',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      final row = await enqueue(
        basePayload: <String, dynamic>{'id': 'n1', 'title': 'Base'},
        payload: <String, dynamic>{'id': 'n1', 'title': 'Mine'},
        baseVersion: 1,
      );

      final needsReview = await resolver.reconcile(
        row: row,
        serverRow: noteServer('n1', version: 3),
      );

      expect(needsReview, isTrue);
      final queued = (await queue.getAll())
          .firstWhere((r) => r.entityType == 'note' && r.entityId == 'n1');
      expect(queued.state, 'conflict_pending');
      expect(queued.payload, jsonEncode(<String, dynamic>{'id': 'n1', 'title': 'Mine'}));
      expect((await localNote('n1')).title, 'Mine',
          reason: 'the queued edit is never overwritten');

      final conflict = (await db.select(db.conflictLog).get()).single;
      expect(conflict.resolutionState, conflictUnresolved);
      expect(conflict.mergeableConflict, isFalse);
      expect(conflict.serverVersion, 3);
      expect(jsonDecode(conflict.submittedPayload)['title'], 'Mine');
      expect(jsonDecode(conflict.basePayload)['title'], 'Base');
    });

    test('a tombstone always needs a person, even with disjoint fields',
        () async {
      final row = await enqueue(
        basePayload: <String, dynamic>{'id': 'n1', 'body': 'Body'},
        payload: <String, dynamic>{'id': 'n1', 'body': 'Mine Body'},
        baseVersion: 1,
      );

      final needsReview = await resolver.reconcile(
        row: row,
        serverRow: noteServer('n1', isDeleted: true, version: 4),
      );

      expect(needsReview, isTrue);
      final queued = (await queue.getAll())
          .firstWhere((r) => r.entityType == 'note' && r.entityId == 'n1');
      expect(queued.state, 'conflict_pending');
      expect((await db.select(db.conflictLog).get()).single.resolutionState,
          conflictUnresolved);
    });
  });

  group('resolution', () {
    Future<ConflictLogRow> loggedConflict() async {
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: 'n1',
              userId: 'user-1',
              title: 'Mine',
              body: 'Body',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      final row = await enqueue(
        basePayload: <String, dynamic>{
          'id': 'n1',
          'user_id': 'user-1',
          'title': 'Base',
          'body': 'Body',
          'is_pinned': false,
          'created_at': 0,
          'updated_at': 0,
          'is_deleted': false,
        },
        payload: <String, dynamic>{
          'id': 'n1',
          'user_id': 'user-1',
          'title': 'Mine',
          'body': 'Body',
          'is_pinned': false,
          'created_at': 0,
          'updated_at': 1,
          'is_deleted': false,
        },
        baseVersion: 1,
      );
      await resolver.reconcile(
        row: row,
        serverRow: noteServer('n1', version: 3, title: 'Theirs'),
      );
      return (await db.select(db.conflictLog).get()).single;
    }

    test('resolveWithFields writes one new mutation and marks it user resolved',
        () async {
      final conflict = await loggedConflict();

      await resolver.resolveWithFields(
        conflict,
        chosen: <String, dynamic>{'title': 'Theirs'},
      );

      final rows = await queue.getAll();
      final noteRows = rows
          .where((r) => r.entityType == 'note' && r.entityId == 'n1')
          .toList();
      final open = noteRows.where((r) => r.state != 'resolved').toList();
      expect(open, hasLength(1), reason: 'the answer replaces the frozen rows');
      expect(open.single.operation, 'update');
      expect(open.single.baseVersion, 3);
      expect(jsonDecode(open.single.payload)['title'], 'Theirs');

      final answered = await resolver.conflicts.getById(conflict.id);
      expect(answered!.resolutionState, conflictUserResolved);
      expect(answered.resolvedAt, isNotNull);
      expect((await localNote('n1')).title, 'Theirs');

      // The answer is mirrored as an update, so other devices see it answered.
      final mirror = rows.where((r) => r.entityType == 'conflict_log').toList();
      expect(mirror, hasLength(2), reason: 'the insert and the resolution');
      expect(mirror.last.operation, 'update');
      expect(mirror.last.entityId, conflict.id);
    });

    test('rebaseOntoNewRecord copies the work onto a new id', () async {
      final conflict = await loggedConflict();

      await resolver.rebaseOntoNewRecord(conflict);

      final rows = await queue.getAll();
      final copies = rows
          .where((r) => r.entityType == 'note' && r.entityId != 'n1')
          .toList();
      expect(copies, hasLength(1));
      expect(copies.single.operation, 'insert');
      final payload = jsonDecode(copies.single.payload) as Map<String, dynamic>;
      expect(payload['title'], 'Mine', reason: 'the preserved edit travels');
      expect(payload['id'], copies.single.entityId);
      expect(payload.containsKey('version'), isFalse);
      expect(payload.containsKey('last_modified_by'), isFalse);
      expect((await resolver.conflicts.getById(conflict.id))!.resolutionState,
          conflictUserResolved);
    });

    test('discard rolls the authoritative row back and marks it discarded',
        () async {
      final conflict = await loggedConflict();

      await resolver.discard(conflict);

      expect((await localNote('n1')).title, 'Theirs');
      final queued = (await queue.getAll())
          .where((r) => r.entityType == 'note' && r.entityId == 'n1')
          .toList();
      expect(queued.every((r) => r.state == 'resolved'), isTrue,
          reason: 'the discarded work leaves the queue');
      expect((await resolver.conflicts.getById(conflict.id))!.resolutionState,
          conflictDiscarded);
    });
  });

  group('conflict log', () {
    test('a dismissal does not resolve a conflict', () async {
      await queue.insert(
        SyncQueueCompanion.insert(
          entityType: 'note',
          entityId: 'n1',
          operation: 'update',
          mutationId: 'mut-n1',
          basePayload: jsonEncode(<String, dynamic>{'id': 'n1', 'title': 'Base'}),
          changedFields: jsonEncode(const <String>['title']),
          payload: jsonEncode(<String, dynamic>{'id': 'n1', 'title': 'Mine'}),
          preMutationPayload: '{}',
          createdAt: 0,
          state: 'pending',
        ),
      );
      final row = (await queue.getAll()).single;
      await resolver.reconcile(
        row: row,
        serverRow: noteServer('n1', version: 2),
      );
      final conflict = (await db.select(db.conflictLog).get()).single;

      await resolver.conflicts.dismiss(conflict.id, 1);

      final still = await resolver.conflicts.watchUnresolved().first;
      expect(still, hasLength(1),
          reason: 'the banner clears only on a real resolution');
    });
  });
}
