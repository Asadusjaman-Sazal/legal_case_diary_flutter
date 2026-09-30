/// Push worker tests — Task 18 Phase 2.
///
/// Everything runs against an in-memory Drift database and a fake
/// [SyncTransport], so the whole batch/ordering/result-handling path is
/// exercised with no server and no Supabase instance.
library;

import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/sync/push_worker.dart';
import 'package:legal_case_diary/sync/sync_queue_dao.dart';
import 'package:legal_case_diary/sync/sync_service.dart';
import 'package:legal_case_diary/sync/sync_transport.dart';

/// A transport whose every call the test decides.
class FakeTransport implements SyncTransport {
  /// The rows of each call, in order.
  final List<List<Map<String, dynamic>>> calls = <List<Map<String, dynamic>>>[];

  /// Error thrown instead of a response.
  Object? error;

  /// Explicit results; when null every submitted row is accepted at version 1.
  List<Map<String, dynamic>>? results;

  @override
  Future<List<Map<String, dynamic>>> pushChanges(
    List<Map<String, dynamic>> rows,
  ) async {
    calls.add(rows);
    final failure = error;
    if (failure != null) throw failure;
    final explicit = results;
    if (explicit != null) return explicit;
    return rows
        .map((row) => <String, dynamic>{
              'mutation_id': row['mutation_id'],
              'entity_type': row['entity_type'],
              'entity_id': row['entity_id'],
              'status': 'accepted',
              'version': 1,
            })
        .toList();
  }

  /// The last batch submitted.
  List<Map<String, dynamic>> get last => calls.last;

  /// This worker never pulls, so the delta-pull half answers "nothing".
  @override
  Future<List<Map<String, dynamic>>> fetchPage(
    String table, {
    String? sinceTime,
    String? sinceId,
    int limit = 200,
  }) async => const <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>?> fetchRow(String table, String id) async => null;

  @override
  Future<DateTime?> serverTime() async => null;
}

/// camelCase -> snake_case, for building server-shaped test rows.
Map<String, dynamic> toSnake(Map<String, dynamic> json) => json.map(
      (key, value) => MapEntry(
        key.replaceAllMapped(
          RegExp('([A-Z])'),
          (m) => '_${m.group(1)!.toLowerCase()}',
        ),
        value,
      ),
    );

int _mutationSeed = 0;

void main() {
  late AppDatabase db;
  late SyncQueueDao queue;
  late FakeTransport transport;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    // Open (creates tables) and satisfy the reference FKs the tests need.
    await db.customSelect('select 1').get();
    await db.into(db.courtCategories).insert(
          CourtCategoriesCompanion.insert(
            id: 'cat-1',
            nameKey: 'cat',
            courtLevel: 'lower',
            orderIndex: 0,
            updatedAt: 0,
          ),
        );
    await db.into(db.onBehalfs).insert(
          OnBehalfsCompanion.insert(
            id: 'ob-1',
            courtCategoryId: 'cat-1',
            name: 'Petitioner',
            orderIndex: 0,
            updatedAt: 0,
          ),
        );
    queue = SyncQueueDao(db);
    transport = FakeTransport();
  });

  tearDown(() => db.close());

  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
    String? mutationId,
    int? baseVersion,
    Map<String, dynamic>? basePayload,
    Map<String, dynamic>? preMutationPayload,
    int createdAt = 0,
    String state = 'pending',
  }) async {
    await queue.insert(
      SyncQueueCompanion.insert(
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        mutationId: mutationId ?? 'mut-${++_mutationSeed}',
        baseVersion: Value(baseVersion),
        basePayload: jsonEncode(basePayload ?? <String, dynamic>{}),
        changedFields: jsonEncode(payload.keys.toList()),
        payload: jsonEncode(payload),
        preMutationPayload: jsonEncode(preMutationPayload ?? <String, dynamic>{}),
        createdAt: createdAt,
        state: state,
      ),
    );
  }

  PushWorker worker() => PushWorker(
        db: db,
        queue: queue,
        transport: transport,
        currentUserId: 'user-1',
        batchSize: 50,
      );

  test('sends one batch in dependency order, then created_at', () async {
    await enqueue(
      entityType: 'note',
      entityId: 'n1',
      operation: 'insert',
      payload: {'id': 'n1'},
      createdAt: 3,
    );
    await enqueue(
      entityType: 'court',
      entityId: 'c1',
      operation: 'insert',
      payload: {'id': 'c1'},
      createdAt: 1,
    );
    await enqueue(
      entityType: 'case_type',
      entityId: 't1',
      operation: 'insert',
      payload: {'id': 't1'},
      createdAt: 2,
    );

    final outcome = await worker().flushBatch();

    expect(outcome.attempted, 3);
    expect(
      transport.last.map((row) => row['entity_type']).toList(),
      <String>['court', 'case_type', 'note'],
      reason: 'config tables first, then leaves',
    );
  });

  test('writes last_attempt_at before the attempt', () async {
    await enqueue(
      entityType: 'court',
      entityId: 'c1',
      operation: 'insert',
      payload: {'id': 'c1'},
    );
    await worker().flushBatch();
    final rows = await queue.getAll();
    expect(rows.single.lastAttemptAt, isNotNull);
  });

  test('skips an entity frozen on a conflict, later entries included', () async {
    await enqueue(
      entityType: 'court',
      entityId: 'c1',
      operation: 'insert',
      payload: {'id': 'c1'},
      state: 'conflict_pending',
    );
    await enqueue(
      entityType: 'court',
      entityId: 'c1',
      operation: 'update',
      payload: {'id': 'c1'},
      createdAt: 2,
    );
    await enqueue(
      entityType: 'note',
      entityId: 'n1',
      operation: 'insert',
      payload: {'id': 'n1'},
      createdAt: 3,
    );

    final outcome = await worker().flushBatch();

    expect(outcome.attempted, 1);
    expect(transport.last.single['entity_type'], 'note');
  });

  test('an accepted row is marked synced and its queue entry resolved', () async {
    await db.into(db.courts).insert(
          CourtsCompanion.insert(
            id: 'c1',
            courtName: 'Court',
            higherLowerCourts: 'Lower Court',
            courtCategoryId: 'cat-1',
            updatedAt: 0,
          ),
        );
    await enqueue(
      entityType: 'court',
      entityId: 'c1',
      operation: 'insert',
      payload: {'id': 'c1'},
    );

    final outcome = await worker().flushBatch();

    expect(outcome.applied, 1);
    final court = await (db.select(db.courts)..where((r) => r.id.equals('c1')))
        .getSingle();
    expect(court.version, 1);
    expect(court.syncedAt, isNotNull);
    expect((await queue.getAll()).single.state, 'resolved');
  });

  test('compaction folds a provisional history into its case update', () async {
    await db.into(db.courts).insert(
          CourtsCompanion.insert(
            id: 'c1',
            courtName: 'Court',
            higherLowerCourts: 'Lower Court',
            courtCategoryId: 'cat-1',
            updatedAt: 0,
          ),
        );
    await db.into(db.cases).insert(
          CasesCompanion.insert(
            id: 'k1',
            userId: 'user-1',
            courtId: 'c1',
            caseType: 'Civil',
            caseNumber: 'K-1',
            petitioner: 'P',
            respondent: 'R',
            onBehalfId: 'ob-1',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await enqueue(
      entityType: 'case',
      entityId: 'k1',
      operation: 'update',
      baseVersion: 1,
      basePayload: {'id': 'k1', 'next_date': 1000},
      payload: {'id': 'k1', 'next_date': 2000},
      mutationId: 'mut-case',
      createdAt: 1,
    );
    await enqueue(
      entityType: 'case_history',
      entityId: 'h1',
      operation: 'insert',
      payload: {
        'id': 'h1',
        'case_id': 'k1',
        'source_mutation_id': 'mut-hist',
        'hearing_date': 1000,
        'next_date': 2000,
      },
      mutationId: 'mut-hist',
      createdAt: 2,
    );

    transport.results = <Map<String, dynamic>>[
      {
        'mutation_id': 'mut-case',
        'entity_type': 'case',
        'entity_id': 'k1',
        'status': 'accepted',
        'version': 2,
        'history': {
          'id': 'h1',
          'case_id': 'k1',
          'user_id': 'user-1',
          'hearing_date': 1000,
          'next_date': 2000,
          'created_by': 'user-1',
          'source_mutation_id': 'mut-hist',
          'base_case_version': 1,
          'result_case_version': 2,
          'updated_at': 5,
          'version': 1,
          'is_deleted': false,
        },
      },
    ];

    final outcome = await worker().flushBatch();

    expect(outcome.attempted, 1, reason: 'the preview is not pushed separately');
    expect(transport.last.single['entity_type'], 'case');
    expect(transport.last.single['provisional_history'], isNotNull);
    final rows = await queue.getAll();
    expect(
      rows.every((row) => row.state == 'resolved'),
      isTrue,
      reason: 'both the case update and its paired preview are resolved',
    );
    final history = await (db.select(db.caseHistory)
          ..where((r) => r.id.equals('h1')))
        .getSingle();
    expect(history.version, 1);
    expect(history.resultCaseVersion, 2);
  });

  test('an unattached provisional history is never pushed on its own', () async {
    // A quick update conflicted, so the case entity is frozen; a later quick
    // update queued a fresh case row plus its own provisional preview.
    await enqueue(
      entityType: 'case',
      entityId: 'k1',
      operation: 'update',
      baseVersion: 1,
      basePayload: {'id': 'k1', 'next_date': 1000},
      payload: {'id': 'k1', 'next_date': 1500},
      mutationId: 'mut-frozen',
      createdAt: 1,
      state: 'conflict_pending',
    );
    await enqueue(
      entityType: 'case',
      entityId: 'k1',
      operation: 'update',
      baseVersion: 1,
      basePayload: {'id': 'k1', 'next_date': 1500},
      payload: {'id': 'k1', 'next_date': 2000},
      mutationId: 'mut-fresh',
      createdAt: 2,
    );
    await enqueue(
      entityType: 'case_history',
      entityId: 'h1',
      operation: 'insert',
      payload: {'id': 'h1', 'case_id': 'k1', 'next_date': 2000},
      mutationId: 'mut-hist',
      createdAt: 3,
    );
    await enqueue(
      entityType: 'note',
      entityId: 'n1',
      operation: 'insert',
      payload: {'id': 'n1'},
      createdAt: 4,
    );

    final outcome = await worker().flushBatch();

    expect(outcome.attempted, 1);
    expect(
      transport.last.map((row) => row['entity_type']).toList(),
      <String>['note'],
      reason: 'the frozen case and its preview both stay behind',
    );
    final history = (await queue.getAll())
        .where((row) => row.entityType == 'case_history')
        .single;
    expect(
      history.state,
      'pending',
      reason: 'kept, so a repaired case update can still fold it in',
    );
  });

  test('a lone provisional history attempts nothing', () async {
    await enqueue(
      entityType: 'case_history',
      entityId: 'h1',
      operation: 'insert',
      payload: {'id': 'h1', 'case_id': 'k1', 'next_date': 2000},
      mutationId: 'mut-hist',
    );

    final outcome = await worker().flushBatch();

    expect(outcome.isEmpty, isTrue);
    expect(transport.calls, isEmpty);
    final row = (await queue.getAll()).single;
    expect(row.state, 'pending');
    expect(row.retryCount, 0, reason: 'it never became an attempt');
  });

  test('a history edit is still pushed on its own', () async {
    await enqueue(
      entityType: 'case_history',
      entityId: 'h1',
      operation: 'update',
      baseVersion: 1,
      basePayload: {'id': 'h1', 'case_id': 'k1', 'result': 'Old'},
      payload: {'id': 'h1', 'case_id': 'k1', 'result': 'New'},
      mutationId: 'mut-hist',
    );

    final outcome = await worker().flushBatch();

    expect(outcome.attempted, 1);
    expect(transport.last.single['operation'], 'update');
  });

  test('an overlapping conflict writes conflict_log and freezes the entity',
      () async {
    await enqueue(
      entityType: 'court',
      entityId: 'c1',
      operation: 'update',
      baseVersion: 1,
      basePayload: {'id': 'c1', 'court_name': 'Old'},
      payload: {'id': 'c1', 'court_name': 'Mine'},
      mutationId: 'mut-1',
    );
    transport.results = <Map<String, dynamic>>[
      {
        'mutation_id': 'mut-1',
        'status': 'conflict',
        'version': 3,
        'row': {
          'id': 'c1',
          'court_name': 'Theirs',
          'version': 3,
          'is_deleted': false,
        },
        'message': 'changed',
      },
    ];

    final outcome = await worker().flushBatch();

    expect(outcome.conflicts, 1);
    final conflicts = await queue.db.select(queue.db.conflictLog).get();
    expect(conflicts, hasLength(1));
    expect(conflicts.single.entityId, 'c1');
    expect(conflicts.single.resolutionState, 'unresolved');
    expect(conflicts.single.mergeableConflict, isFalse);
    final rows = await queue.getAll();
    // The rejected entry is now conflict_pending; a mirror entry is queued.
    expect(
      rows.where((r) => r.entityId == 'c1' && r.state == 'conflict_pending'),
      hasLength(1),
    );
    expect(rows.where((r) => r.entityType == 'conflict_log'), hasLength(1));
  });

  test('a disjoint conflict rebases itself and needs no person', () async {
    await db.into(db.courts).insert(
          CourtsCompanion.insert(
            id: 'c1',
            courtName: 'Old',
            higherLowerCourts: 'Lower Court',
            courtCategoryId: 'cat-1',
            updatedAt: 0,
          ),
        );
    final court =
        await (db.select(db.courts)..where((r) => r.id.equals('c1'))).getSingle();
    await enqueue(
      entityType: 'court',
      entityId: 'c1',
      operation: 'update',
      baseVersion: 1,
      basePayload: {'id': 'c1', 'court_name': 'Old', 'order_index': 0},
      payload: {'id': 'c1', 'court_name': 'Old', 'order_index': 5},
      mutationId: 'mut-1',
    );
    transport.results = <Map<String, dynamic>>[
      {
        'mutation_id': 'mut-1',
        'status': 'conflict',
        'version': 3,
        'row': toSnake(court.toJson())
          ..['court_name'] = 'Theirs'
          ..['version'] = 3,
        'message': 'changed',
      },
    ];

    final outcome = await worker().flushBatch();

    // A rebase is already an answer, so it freezes nothing and asks nobody.
    expect(outcome.conflicts, 0);
    final logged = (await queue.db.select(queue.db.conflictLog).get()).single;
    expect(logged.entityId, 'c1');
    expect(logged.mergeableConflict, isTrue);
    expect(logged.resolutionState, 'rebased');
    expect(logged.resolvedAt, isNotNull);

    final row = (await queue.getAll())
        .firstWhere((r) => r.entityType == 'court' && r.entityId == 'c1');
    expect(row.state, 'pending', reason: 'the merged edit is sent again');
    expect(row.baseVersion, 3, reason: 'rebased onto the server version');
    expect(row.mutationId, isNot('mut-1'), reason: 'a fresh mutation id');
    expect(jsonDecode(row.payload)['order_index'], 5,
        reason: 'the local edit is preserved');
    expect(jsonDecode(row.payload)['court_name'], 'Theirs',
        reason: 'the server value is kept where the local side did not change it');
  });

  test('a tombstone applies the server row and hides the record', () async {
    await db.into(db.courts).insert(
          CourtsCompanion.insert(
            id: 'c1',
            courtName: 'Court',
            higherLowerCourts: 'Lower Court',
            courtCategoryId: 'cat-1',
            updatedAt: 0,
          ),
        );
    await enqueue(
      entityType: 'court',
      entityId: 'c1',
      operation: 'update',
      baseVersion: 1,
      payload: {'id': 'c1'},
      mutationId: 'mut-1',
    );
    final court = await (db.select(db.courts)..where((r) => r.id.equals('c1')))
        .getSingle();
    transport.results = <Map<String, dynamic>>[
      {
        'mutation_id': 'mut-1',
        'status': 'tombstone',
        'version': 2,
        'row': toSnake(court.toJson())
          ..['is_deleted'] = true
          ..['version'] = 2,
        'message': 'deleted',
      },
    ];

    await worker().flushBatch();

    final after = await (db.select(db.courts)..where((r) => r.id.equals('c1')))
        .getSingle();
    expect(after.isDeleted, isTrue);
  });

  test('a permission rejection rolls the row back and resolves the entry', () async {
    await db.into(db.notes).insert(
          NotesCompanion.insert(
            id: 'n1',
            userId: 'user-1',
            title: 'Original',
            body: 'Body',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    final original = await (db.select(db.notes)..where((r) => r.id.equals('n1')))
        .getSingle();
    await enqueue(
      entityType: 'note',
      entityId: 'n1',
      operation: 'update',
      baseVersion: 1,
      payload: {'id': 'n1', 'title': 'Edited'},
      preMutationPayload: toSnake(original.toJson()),
      mutationId: 'mut-1',
    );
    transport.results = <Map<String, dynamic>>[
      {
        'mutation_id': 'mut-1',
        'status': 'rejected',
        'error_code': 'permission_denied',
        'message': 'no',
      },
    ];

    final outcome = await worker().flushBatch();

    expect(outcome.permissionRollback, isTrue);
    final after = await (db.select(db.notes)..where((r) => r.id.equals('n1')))
        .getSingle();
    expect(after.title, 'Original', reason: 'rolled back to the pre-mutation snapshot');
    expect((await queue.getAll()).single.state, 'resolved');
  });

  test('a permanent rejection blocks the entry', () async {
    await enqueue(
      entityType: 'court',
      entityId: 'c1',
      operation: 'update',
      baseVersion: 1,
      payload: {'id': 'c1'},
      mutationId: 'mut-1',
    );
    transport.results = <Map<String, dynamic>>[
      {
        'mutation_id': 'mut-1',
        'status': 'rejected',
        'error_code': 'validation_failed',
        'message': 'bad',
      },
    ];

    final outcome = await worker().flushBatch();

    expect(outcome.blocked, 1);
    final row = (await queue.getAll()).single;
    expect(row.state, 'blocked');
    expect(row.lastError, 'bad');
  });

  test('a retryable failure increments retry, and the tenth blocks', () async {
    await enqueue(
      entityType: 'court',
      entityId: 'c1',
      operation: 'insert',
      payload: {'id': 'c1'},
      mutationId: 'mut-1',
    );
    transport.error = const SyncFailure(
      'offline',
      kind: SyncFailureKind.network,
      retryable: true,
    );

    for (var attempt = 1; attempt <= 9; attempt++) {
      await worker().flushBatch();
    }
    var after = (await queue.getAll()).single;
    expect(after.state, 'pending');
    expect(after.retryCount, 9);

    await worker().flushBatch();
    after = (await queue.getAll()).single;
    expect(after.state, 'blocked');
    expect(after.retryCount, 10);
  });

  test('a non-retryable failure blocks immediately', () async {
    await enqueue(
      entityType: 'court',
      entityId: 'c1',
      operation: 'insert',
      payload: {'id': 'c1'},
      mutationId: 'mut-1',
    );
    transport.error = const SyncFailure(
      'no session',
      kind: SyncFailureKind.unauthorized,
      retryable: false,
    );

    await worker().flushBatch();

    expect((await queue.getAll()).single.state, 'blocked');
  });

  group('decodePushResults', () {
    test('reads the results array from a decoded map', () {
      final results = decodePushResults(<String, dynamic>{
        'results': <dynamic>[
          {'mutation_id': 'a', 'status': 'accepted'},
        ],
      });
      expect(results.single['status'], 'accepted');
    });

    test('decodes a JSON string response', () {
      final results = decodePushResults('{"results":[{"mutation_id":"a"}]}');
      expect(results.single['mutation_id'], 'a');
    });

    test('a malformed response is empty, never a throw', () {
      expect(decodePushResults(null), isEmpty);
      expect(decodePushResults('not json'), isEmpty);
      expect(decodePushResults(<String, dynamic>{}), isEmpty);
    });
  });

  group('syncBackoffDelay', () {
    test('doubles from 30s and caps at 30m', () {
      expect(syncBackoffDelay(1), const Duration(seconds: 30));
      expect(syncBackoffDelay(2), const Duration(minutes: 1));
      expect(syncBackoffDelay(3), const Duration(minutes: 2));
      expect(syncBackoffDelay(4), const Duration(minutes: 4));
      expect(syncBackoffDelay(20), syncRetryMax);
    });
  });
}
