/// Free → premium backlog push tests — Task 18 Phase 4.
///
/// A whole free-period queue is built, then pushed through the real service with
/// a fake network boundary: the compaction pass, the FK-ordered micro-batches,
/// the preserved `conflict_pending`/`blocked` rows and the full pull from the
/// minimum sentinel are all exercised as they ship, over an in-memory database.
library;

import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/sync/connectivity_monitor.dart';
import 'package:legal_case_diary/sync/queue_compaction.dart';
import 'package:legal_case_diary/sync/sync_metadata_dao.dart';
import 'package:legal_case_diary/sync/sync_queue_dao.dart';
import 'package:legal_case_diary/sync/sync_service.dart';
import 'package:legal_case_diary/sync/sync_transport.dart';
import 'package:legal_case_diary/sync/sync_write_helper.dart';

/// A transport whose batches and pages the test decides.
class _BacklogServer implements SyncTransport {
  /// One entry per `push_changes` call.
  final List<List<Map<String, dynamic>>> batches = <List<Map<String, dynamic>>>[];

  /// The tables requested so far, with the cursor each request carried.
  final List<({String table, String? sinceTime, String? sinceId})> pages =
      <({String table, String? sinceTime, String? sinceId})>[];

  /// Pulled rows per table; empty by default.
  final Map<String, List<Map<String, dynamic>>> rows =
      <String, List<Map<String, dynamic>>>{};

  /// Explicit results keyed by `mutation_id`; when null every row is accepted.
  Map<String, Map<String, dynamic>>? results;

  /// Thrown instead of a response when set.
  Object? error;

  @override
  Future<List<Map<String, dynamic>>> pushChanges(
    List<Map<String, dynamic>> changes,
  ) async {
    batches.add(changes);
    final failure = error;
    if (failure != null) throw failure;
    final explicit = results;
    return changes
        .map((row) => explicit?[row['mutation_id']] ??
            <String, dynamic>{
              'mutation_id': row['mutation_id'],
              'entity_type': row['entity_type'],
              'entity_id': row['entity_id'],
              'status': 'accepted',
              'version': (row['base_version'] as int? ?? 0) + 1,
            })
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPage(
    String table, {
    String? sinceTime,
    String? sinceId,
    int limit = syncPullPageSize,
  }) async {
    pages.add((table: table, sinceTime: sinceTime, sinceId: sinceId));
    final failure = error;
    if (failure != null) throw failure;
    return rows[table] ?? const <Map<String, dynamic>>[];
  }

  @override
  Future<Map<String, dynamic>?> fetchRow(String table, String id) async {
    for (final row in rows[table] ?? const <Map<String, dynamic>>[]) {
      if (row['id'] == id) return row;
    }
    return null;
  }

  @override
  Future<DateTime?> serverTime() async => DateTime.now().toUtc();

  /// Every mutation sent, across every batch.
  List<Map<String, dynamic>> get sent =>
      <Map<String, dynamic>>[for (final batch in batches) ...batch];
}

void main() {
  late AppDatabase db;
  late SyncQueueDao queue;
  late SyncMetadataDao metadata;
  late SyncWriteHelper helper;
  late _BacklogServer server;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    db = AppDatabase(NativeDatabase.memory());
    await db.customSelect('select 1').get();
    queue = SyncQueueDao(db);
    metadata = SyncMetadataDao(db);
    helper = SyncWriteHelper(queue, LocalIdentityService(await SharedPreferences.getInstance()));
    server = _BacklogServer();
  });

  tearDown(() => db.close());

  ProviderContainer container() {
    final value = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWith((ref) async => db),
        accountCacheUserIdProvider.overrideWithValue('user-1'),
        accountProfileProvider.overrideWith((ref) => Stream.value(null)),
        premiumAccessProvider.overrideWith((ref) async => true),
        isOnlineProvider.overrideWith((ref) => Stream.value(true)),
        syncServiceProvider.overrideWith(
          (ref) => SyncService(ref, transportOverride: () => server),
        ),
      ],
    );
    addTearDown(value.dispose);
    return value;
  }

  Future<void> enqueue({
    required String entityType,
    required String entityId,
    String operation = 'update',
    String state = 'pending',
    Map<String, dynamic> payload = const <String, dynamic>{},
    List<String> changedFields = const <String>[],
    String? mutationId,
    int? baseVersion,
    String? basePayload,
    int createdAt = 0,
  }) =>
      queue.insert(
        SyncQueueCompanion.insert(
          entityType: entityType,
          entityId: entityId,
          operation: operation,
          mutationId: mutationId ?? 'mut-$entityType-$entityId-$createdAt',
          baseVersion: Value(baseVersion),
          basePayload: basePayload ?? '{}',
          changedFields: jsonEncode(changedFields),
          payload: jsonEncode(payload),
          preMutationPayload: '{}',
          createdAt: createdAt,
          state: state,
        ),
      );

  group('planQueueCompaction', () {
    SyncQueueRow row(
      int id,
      String operation,
      Map<String, dynamic> payload,
      List<String> fields, {
      int createdAt = 0,
    }) =>
        SyncQueueRow(
          id: id,
          entityType: 'note',
          entityId: 'n1',
          operation: operation,
          mutationId: 'mut-$id',
          baseVersion: 1,
          basePayload: '{}',
          changedFields: jsonEncode(fields),
          payload: jsonEncode(payload),
          preMutationPayload: '{}',
          createdAt: createdAt,
          retryCount: 0,
          state: 'pending',
        );

    test('insert + update keeps the insert, the latest payload and every field',
        () {
      final plan = planQueueCompaction(<SyncQueueRow>[
        row(1, 'insert', <String, dynamic>{'title': 'First'}, <String>['title']),
        row(2, 'update', <String, dynamic>{'title': 'Latest'}, <String>['body'],
            createdAt: 1),
      ])!;

      expect(plan.dropAll, isFalse);
      expect(plan.survivorId, 1, reason: 'the earliest row keeps the identity');
      expect(plan.operation, 'insert');
      expect(jsonDecode(plan.payload!), <String, dynamic>{'title': 'Latest'});
      expect(jsonDecode(plan.changedFields!), <String>['title', 'body']);
    });

    test('insert + delete cancels out entirely', () {
      final plan = planQueueCompaction(<SyncQueueRow>[
        row(1, 'insert', <String, dynamic>{}, <String>[]),
        row(2, 'delete', <String, dynamic>{}, <String>[], createdAt: 1),
      ])!;
      expect(plan.dropAll, isTrue);
    });

    test('update + delete collapses to a single delete', () {
      final plan = planQueueCompaction(<SyncQueueRow>[
        row(1, 'update', <String, dynamic>{'title': 'A'}, <String>[]),
        row(2, 'delete', <String, dynamic>{'is_deleted': true}, <String>[],
            createdAt: 1),
      ])!;
      expect(plan.operation, 'delete');
      expect(jsonDecode(plan.payload!), <String, dynamic>{'is_deleted': true});
    });

    test('a delete followed by an edit is left alone', () {
      expect(
        planQueueCompaction(<SyncQueueRow>[
          row(1, 'delete', <String, dynamic>{}, <String>[]),
          row(2, 'update', <String, dynamic>{}, <String>[], createdAt: 1),
        ]),
        isNull,
      );
    });

    test('a single row has nothing to compact', () {
      expect(
        planQueueCompaction(<SyncQueueRow>[
          row(1, 'update', <String, dynamic>{}, <String>[]),
        ]),
        isNull,
      );
    });
  });

  test('compacts the run, pushes FK-ordered micro-batches, then full pulls',
      () async {
    // Two accumulated pending rows for one note: the shape the write path can
    // leave behind, and exactly what the pre-push compaction exists for.
    await enqueue(
      entityType: 'note',
      entityId: 'n1',
      operation: 'insert',
      payload: <String, dynamic>{'id': 'n1', 'title': 'First'},
      changedFields: <String>['title'],
      mutationId: 'mut-oldest',
    );
    await enqueue(
      entityType: 'note',
      entityId: 'n1',
      operation: 'update',
      payload: <String, dynamic>{'id': 'n1', 'title': 'Latest'},
      changedFields: <String>['body'],
      createdAt: 1,
    );
    // A config table, so the batch order is observable.
    await enqueue(
      entityType: 'court',
      entityId: 'c1',
      operation: 'insert',
      payload: <String, dynamic>{'id': 'c1'},
      createdAt: 2,
    );
    // A cursor from an earlier session must not survive the full pull.
    await metadata.setCursor(
      'courts',
      const SyncCursor(time: '2026-01-01T00:00:00+00:00', id: 'stale'),
    );

    final outcome = await container().read(syncServiceProvider).runBacklogPush();

    expect(outcome!.compacted, 1, reason: 'two rows became one');
    expect(outcome.pushed, 2);
    expect(outcome.failure, isNull);

    final sent = server.sent;
    expect(sent, hasLength(2));
    expect(sent.first['entity_type'], 'court', reason: 'config tables first');
    final compacted = sent.last;
    expect(compacted['mutation_id'], 'mut-oldest');
    expect(
      jsonDecode(jsonEncode(compacted['payload'])),
      <String, dynamic>{'id': 'n1', 'title': 'Latest'},
    );
    expect(compacted['changed_fields'], <String>['title', 'body']);
    expect((await queue.getAll()).every((row) => row.state == 'resolved'), isTrue);

    // The pull is a full pull: every table starts at the minimum sentinel.
    expect(server.pages, hasLength(14));
    expect(server.pages.every((page) => page.sinceTime == null), isTrue);
    expect(
      (await metadata.getCursor('courts'))?.id,
      isNot('stale'),
      reason: 'the stale cursor was forgotten and replaced',
    );
  });

  test('a pulled row from the firm lands in the freshly pulled device',
      () async {
    server.rows['courts'] = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'c9',
        'court_name': 'Pulled Court',
        'higher_lower_courts': 'Lower Court',
        'court_category_id': 'cat-1',
        'order_index': 0,
        'is_custom': false,
        'is_user_modified': false,
        'updated_at': 0,
        'version': 1,
        'is_deleted': false,
        'server_updated_at': '2026-09-30T10:00:00.000000+00:00',
      },
    ];
    await db.into(db.courtCategories).insert(
          CourtCategoriesCompanion.insert(
            id: 'cat-1',
            nameKey: 'cat',
            courtLevel: 'lower',
            orderIndex: 0,
            updatedAt: 0,
          ),
        );

    final outcome = await container().read(syncServiceProvider).runBacklogPush();

    expect(outcome!.pulled, 1);
    final court = await (db.select(db.courts)..where((row) => row.id.equals('c9')))
        .getSingle();
    expect(court.courtName, 'Pulled Court');
  });

  test('a conflict_pending row is preserved, never pushed, and still reported',
      () async {
    await enqueue(
      entityType: 'note',
      entityId: 'n1',
      state: 'conflict_pending',
      payload: <String, dynamic>{'id': 'n1'},
    );
    await enqueue(
      entityType: 'court',
      entityId: 'c1',
      operation: 'insert',
      payload: <String, dynamic>{'id': 'c1'},
      createdAt: 1,
    );

    final outcome = await container().read(syncServiceProvider).runBacklogPush();

    expect(outcome!.conflictPending, 1);
    expect(server.sent, hasLength(1));
    expect(server.sent.single['entity_type'], 'court');
    final frozen = (await queue.getAll())
        .firstWhere((row) => row.entityType == 'note');
    expect(frozen.state, 'conflict_pending');
    expect(frozen.payload, jsonEncode(<String, dynamic>{'id': 'n1'}));
  });

  test('a blocked row stays blocked and is never force-retried', () async {
    await enqueue(
      entityType: 'note',
      entityId: 'n1',
      state: 'blocked',
      payload: <String, dynamic>{'id': 'n1'},
    );

    final outcome = await container().read(syncServiceProvider).runBacklogPush();

    expect(outcome!.blocked, 1);
    expect(server.sent, isEmpty);
    final blocked = (await queue.getAll()).single;
    expect(blocked.state, 'blocked');
    expect(blocked.retryCount, 0, reason: 'no attempt was made');
  });

  test('a permanent rejection during the backlog stays visible', () async {
    await enqueue(
      entityType: 'court',
      entityId: 'c1',
      operation: 'insert',
      payload: <String, dynamic>{'id': 'c1'},
      mutationId: 'mut-bad',
    );
    server.results = <String, Map<String, dynamic>>{
      'mut-bad': <String, dynamic>{
        'mutation_id': 'mut-bad',
        'status': 'rejected',
        'error_code': 'validation_failed',
        'message': 'bad payload',
      },
    };

    final outcome = await container().read(syncServiceProvider).runBacklogPush();

    expect(outcome!.blocked, 1);
    final row = (await queue.getAll()).single;
    expect(row.state, 'blocked');
    expect(row.lastError, 'bad payload');
  });

  test('a transport failure keeps the queue and skips the pull', () async {
    await enqueue(
      entityType: 'court',
      entityId: 'c1',
      operation: 'insert',
      payload: <String, dynamic>{'id': 'c1'},
    );
    server.error = const SyncFailure(
      'offline',
      kind: SyncFailureKind.network,
      retryable: true,
    );

    final outcome = await container().read(syncServiceProvider).runBacklogPush();

    expect(outcome!.failure, isNotNull);
    expect(outcome.pushed, 0);
    expect(outcome.pulled, 0);
    expect(server.pages, isEmpty, reason: 'a pull would fail on the same link');
    expect((await queue.getAll()).single.state, 'pending');
  });

  test('a Part A write reaches the server with its sync columns unchanged',
      () async {
    // Exactly what a repository hands the helper: the row's snapshot plus the
    // sync columns Part A already maintained, with no migration of any kind.
    await helper.recordInsert(
      entityType: 'note',
      entityId: 'n1',
      payload: <String, dynamic>{
        'id': 'n1',
        'user_id': 'user-1',
        'title': 'Written While Free',
        'body': 'Body',
        'is_deleted': false,
        'updated_at': 111,
        'synced_at': null,
        'last_modified_by': 'user-1',
      },
      changedFields: <String>['id', 'title'],
    );

    await container().read(syncServiceProvider).runBacklogPush();

    final mutation = server.sent.single;
    expect(mutation['entity_type'], 'note');
    expect(mutation['base_version'], isNull, reason: 'a first insert has no base');
    expect(mutation['payload'], <String, dynamic>{
      'id': 'n1',
      'user_id': 'user-1',
      'title': 'Written While Free',
      'body': 'Body',
      'is_deleted': false,
      'updated_at': 111,
      'synced_at': null,
      'last_modified_by': 'user-1',
    });
    final local = (await queue.getAll()).single;
    expect(local.state, 'resolved');
    expect(local.mutationId, mutation['mutation_id']);
  });
}
