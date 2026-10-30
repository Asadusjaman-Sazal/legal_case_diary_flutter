/// Delta-pull tests — Task 18 Phase 3.
///
/// The worker is driven against an in-memory Drift database and a fake server
/// that implements the composite `(server_updated_at, id)` cursor itself, so the
/// properties that matter can actually be tested: no row is skipped across a
/// page, a table or an empty boundary; a failed commit replays rather than
/// skips; and a pulled row never overwrites unpublished local work.
library;

import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/sync/entity_tables.dart';
import 'package:legal_case_diary/sync/pull_worker.dart';
import 'package:legal_case_diary/sync/sync_metadata_dao.dart';
import 'package:legal_case_diary/sync/sync_queue_dao.dart';
import 'package:legal_case_diary/sync/sync_transport.dart';

/// One request the worker made, as the server saw it.
class _Request {
  _Request(this.table, this.sinceTime, this.sinceId, this.limit);

  final String table;
  final String? sinceTime;
  final String? sinceId;
  final int limit;
}

/// A fake server that pages with the real composite-cursor rule.
class _Server implements SyncTransport {
  final Map<String, List<Map<String, dynamic>>> rows =
      <String, List<Map<String, dynamic>>>{};
  final List<_Request> requests = <_Request>[];

  /// Thrown instead of a page when set.
  Object? error;

  @override
  Future<List<Map<String, dynamic>>> fetchPage(
    String table, {
    String? sinceTime,
    String? sinceId,
    int limit = syncPullPageSize,
  }) async {
    requests.add(_Request(table, sinceTime, sinceId, limit));
    final failure = error;
    if (failure != null) throw failure;

    final all = <Map<String, dynamic>>[...?rows[table]]..sort(_compare);
    if (sinceTime == null || sinceId == null) return all.take(limit).toList();

    return all
        .where((row) {
          final time = row['server_updated_at'] as String;
          final id = row['id'] as String;
          if (time.compareTo(sinceTime) > 0) return true;
          return time == sinceTime && id.compareTo(sinceId) > 0;
        })
        .take(limit)
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> fetchRow(String table, String id) async {
    for (final row in rows[table] ?? const <Map<String, dynamic>>[]) {
      if (row['id'] == id) return row;
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> pushChanges(
    List<Map<String, dynamic>> changes,
  ) async => const <Map<String, dynamic>>[];

  @override
  Future<DateTime?> serverTime() async => null;

  static int _compare(Map<String, dynamic> a, Map<String, dynamic> b) {
    final byTime = (a['server_updated_at'] as String? ?? '').compareTo(
      b['server_updated_at'] as String? ?? '',
    );
    if (byTime != 0) return byTime;
    return (a['id'] as String).compareTo(b['id'] as String);
  }
}

/// A `court_categories` server row.
Map<String, dynamic> categoryRow(String id, String time) => <String, dynamic>{
  'id': id,
  'name_key': 'cat',
  'court_level': 'lower',
  'order_index': 0,
  'is_custom': false,
  'is_user_modified': false,
  'updated_at': 0,
  'version': 1,
  'is_deleted': false,
  'server_updated_at': time,
};

/// A `courts` server row under the fixture category.
Map<String, dynamic> courtRow(
  String id,
  String time, {
  String name = 'Court',
  bool isDeleted = false,
  int version = 1,
}) => <String, dynamic>{
  'id': id,
  'court_name': name,
  'higher_lower_courts': 'Lower Court',
  'court_category_id': 'cat-1',
  'order_index': 0,
  'is_custom': false,
  'is_user_modified': false,
  'updated_at': 0,
  'version': version,
  'is_deleted': isDeleted,
  'server_updated_at': time,
};

/// A `notes` server row.
Map<String, dynamic> noteRow(
  String id,
  String time, {
  String title = 'Server Title',
}) => <String, dynamic>{
  'id': id,
  'user_id': 'user-1',
  'title': title,
  'body': 'Body',
  'is_pinned': false,
  'created_at': 0,
  'updated_at': 0,
  'version': 2,
  'is_deleted': false,
  'server_updated_at': time,
};

void main() {
  late AppDatabase db;
  late SyncQueueDao queue;
  late SyncMetadataDao metadata;
  late _Server server;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.customSelect('select 1').get();
    await db
        .into(db.courtCategories)
        .insert(
          CourtCategoriesCompanion.insert(
            id: 'cat-1',
            nameKey: 'cat',
            courtLevel: 'lower',
            orderIndex: 0,
            updatedAt: 0,
          ),
        );
    queue = SyncQueueDao(db);
    metadata = SyncMetadataDao(db);
    server = _Server();
  });

  tearDown(() => db.close());

  PullWorker worker({int pageSize = syncPullPageSize}) => PullWorker(
    db: db,
    metadata: metadata,
    queue: queue,
    transport: server,
    currentUserId: 'user-1',
    pageSize: pageSize,
  );

  Future<void> enqueue({
    required String entityType,
    required String entityId,
    String state = 'pending',
    Map<String, dynamic> payload = const <String, dynamic>{},
    Map<String, dynamic> basePayload = const <String, dynamic>{},
    int createdAt = 0,
    int? baseVersion,
  }) => queue.insert(
    SyncQueueCompanion.insert(
      entityType: entityType,
      entityId: entityId,
      operation: 'update',
      mutationId: 'mut-$entityType-$entityId',
      baseVersion: Value(baseVersion),
      basePayload: jsonEncode(basePayload),
      changedFields: jsonEncode(payload.keys.toList()),
      payload: jsonEncode(payload),
      preMutationPayload: '{}',
      createdAt: createdAt,
      state: state,
    ),
  );

  Future<List<Court>> localCourts() => db.select(db.courts).get();

  test('walks every synced table in dependency order', () async {
    final outcome = await worker().pullAll();

    expect(outcome.tables, 13);
    expect(
      server.requests.map((request) => request.table).toSet(),
      syncPullTablesInDependencyOrder.toSet(),
    );
    expect(server.requests.first.table, 'court_categories');
  });

  test(
    'pages until a short page, without skipping same-timestamp rows',
    () async {
      const time = '2026-09-30T10:00:00.000000+00:00';
      for (final id in <String>['a1', 'b2', 'c3', 'd4', 'e5']) {
        server.rows['courts'] = <Map<String, dynamic>>[
          ...?server.rows['courts'],
          courtRow(id, time),
        ];
      }

      final outcome = await worker(pageSize: 2).pullAll();

      final ids = (await localCourts()).map((row) => row.id).toSet();
      expect(ids, <String>{'a1', 'b2', 'c3', 'd4', 'e5'});
      expect(outcome.rows, 5);

      final requests = server.requests
          .where((request) => request.table == 'courts')
          .toList();
      expect(requests, hasLength(3), reason: '2 + 2 + 1, then the empty page');
      expect(
        requests[0].sinceTime,
        isNull,
        reason: 'a first pull is a full pull',
      );
      expect(requests[1].sinceTime, time);
      expect(
        requests[1].sinceId,
        'b2',
        reason: 'the tie-breaker is the row id',
      );

      final cursor = await metadata.getCursor('courts');
      expect(cursor?.time, time);
      expect(cursor?.id, 'e5');
    },
  );

  test('a second pull resumes from the stored cursor', () async {
    server.rows['courts'] = <Map<String, dynamic>>[
      courtRow('c1', '2026-09-30T10:00:00.000000+00:00'),
    ];
    await worker().pullAll();
    server.requests.clear();

    server.rows['courts'] = <Map<String, dynamic>>[
      ...server.rows['courts']!,
      courtRow('c2', '2026-09-30T11:00:00.000000+00:00'),
    ];
    await worker().pullAll();

    final request = server.requests.firstWhere(
      (entry) => entry.table == 'courts',
    );
    expect(request.sinceId, 'c1');
    expect(request.sinceTime, '2026-09-30T10:00:00.000000+00:00');
    expect((await localCourts()).map((row) => row.id).toSet(), <String>{
      'c1',
      'c2',
    });
  });

  test('an empty page completes the table and invents no cursor', () async {
    final outcome = await worker().pullAll();

    expect(outcome.rows, 0);
    for (final table in syncPullTablesInDependencyOrder) {
      expect(await metadata.getCursor(table), isNull);
    }
  });

  test('a full pull ignores the stored cursors', () async {
    server.rows['courts'] = <Map<String, dynamic>>[
      courtRow('c1', '2026-09-30T10:00:00.000000+00:00'),
    ];
    await worker().pullAll();
    expect(await metadata.getCursor('courts'), isNotNull);
    server.requests.clear();

    await worker().pullAll(fromSentinel: true);

    final request = server.requests.firstWhere(
      (entry) => entry.table == 'courts',
    );
    expect(request.sinceTime, isNull);
    expect(request.sinceId, isNull);
  });

  test(
    'a crash inside the page transaction replays rather than skips',
    () async {
      const time = '2026-09-30T10:00:00.000000+00:00';
      server.rows['courts'] = <Map<String, dynamic>>[
        courtRow('c1', time),
        // A row the local mapping cannot read: it aborts the page transaction.
        <String, dynamic>{
          ...courtRow('c2', time),
          'updated_at': 'not a number',
        },
        courtRow('c3', time),
      ];

      await expectLater(worker().pullAll(), throwsA(anything));

      expect(
        await metadata.getCursor('courts'),
        isNull,
        reason: 'the cursor must not advance past an uncommitted page',
      );
      expect(
        await localCourts(),
        isEmpty,
        reason: 'the page rolled back whole',
      );

      // The next run re-reads the same page from the same cursor and completes.
      server.rows['courts'] = <Map<String, dynamic>>[
        courtRow('c1', time),
        courtRow('c2', time),
        courtRow('c3', time),
      ];
      await worker().pullAll();

      expect((await localCourts()).map((row) => row.id).toSet(), <String>{
        'c1',
        'c2',
        'c3',
      });
    },
  );

  test('a transport failure leaves every cursor and row untouched', () async {
    server.rows['courts'] = <Map<String, dynamic>>[
      courtRow('c1', '2026-09-30T10:00:00.000000+00:00'),
    ];
    server.error = const SyncFailure(
      'offline',
      kind: SyncFailureKind.network,
      retryable: true,
    );

    await expectLater(worker().pullAll(), throwsA(isA<SyncFailure>()));

    expect(await metadata.getCursor('courts'), isNull);
    expect(await localCourts(), isEmpty);
  });

  test('each table keeps its own cursor', () async {
    server.rows['courts'] = <Map<String, dynamic>>[
      courtRow('c1', '2026-09-30T10:00:00.000000+00:00'),
    ];
    server.rows['notes'] = <Map<String, dynamic>>[
      noteRow('n1', '2026-09-30T12:00:00.000000+00:00'),
    ];

    await worker().pullAll();

    expect(
      (await metadata.getCursor('courts'))!.time,
      '2026-09-30T10:00:00.000000+00:00',
    );
    expect(
      (await metadata.getCursor('notes'))!.time,
      '2026-09-30T12:00:00.000000+00:00',
    );
    expect(
      await metadata.getCursor('notes'),
      isNot(await metadata.getCursor('courts')),
    );
  });

  test(
    'a page that cannot advance ends the table instead of looping',
    () async {
      server.rows['courts'] = <Map<String, dynamic>>[
        <String, dynamic>{...courtRow('c1', '2026-09-30T10:00:00Z')}
          ..remove('server_updated_at'),
      ];

      final outcome = await worker(pageSize: 1).pullAll();

      expect(outcome.rows, 1);
      expect(await metadata.getCursor('courts'), isNull);
      expect(
        server.requests.where((entry) => entry.table == 'courts'),
        hasLength(1),
      );
    },
  );

  group('pull-side merge', () {
    test('a pulled row never overwrites a pending local edit', () async {
      await db
          .into(db.notes)
          .insert(
            NotesCompanion.insert(
              id: 'n1',
              userId: 'user-1',
              title: 'Mine',
              body: 'Body',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      await enqueue(
        entityType: 'note',
        entityId: 'n1',
        baseVersion: 1,
        basePayload: {'id': 'n1', 'title': 'Base'},
        payload: {'id': 'n1', 'title': 'Mine'},
      );
      server.rows['notes'] = <Map<String, dynamic>>[
        noteRow('n1', '2026-09-30T10:00:00.000000+00:00', title: 'Server'),
      ];

      final outcome = await worker().pullAll();

      expect(outcome.conflicts, 1);
      final note = await (db.select(
        db.notes,
      )..where((row) => row.id.equals('n1'))).getSingle();
      expect(note.title, 'Mine', reason: 'the queued edit is preserved');
      final queued = (await queue.getAll())
          .where((row) => row.entityType == 'note')
          .single;
      expect(
        queued.state,
        'conflict_pending',
        reason: 'the entity is frozen for review',
      );

      final conflict = (await db.select(db.conflictLog).get()).single;
      expect(conflict.entityId, 'n1');
      expect(conflict.resolutionState, 'unresolved');
      expect(conflict.serverVersion, 2);
      expect(
        jsonDecode(conflict.serverPayload)['title'],
        'Server',
        reason: 'the authoritative row travels in the conflict log',
      );
      expect(jsonDecode(conflict.submittedPayload)['title'], 'Mine');
      expect(
        jsonDecode(conflict.basePayload)['title'],
        'Base',
        reason: 'three-way reconciliation needs the common base',
      );
    });

    test(
      'a pulled tombstone hides the record and keeps the queued edit',
      () async {
        await db
            .into(db.notes)
            .insert(
              NotesCompanion.insert(
                id: 'n1',
                userId: 'user-1',
                title: 'Mine',
                body: 'Body',
                createdAt: 0,
                updatedAt: 0,
              ),
            );
        await enqueue(
          entityType: 'note',
          entityId: 'n1',
          payload: {'id': 'n1'},
        );
        server.rows['notes'] = <Map<String, dynamic>>[
          <String, dynamic>{
            ...noteRow('n1', '2026-09-30T10:00:00.000000+00:00'),
            'is_deleted': true,
          },
        ];

        await worker().pullAll();

        final note = await (db.select(
          db.notes,
        )..where((row) => row.id.equals('n1'))).getSingle();
        expect(note.isDeleted, isTrue);
        expect((await db.select(db.conflictLog).get()), hasLength(1));
        final queued = (await queue.getAll())
            .where((row) => row.entityType == 'note')
            .single;
        expect(queued.state, 'conflict_pending');
        expect(queued.payload, jsonEncode(<String, dynamic>{'id': 'n1'}));
      },
    );

    test('a frozen entity is not re-logged on the next pull', () async {
      await enqueue(
        entityType: 'note',
        entityId: 'n1',
        payload: {'id': 'n1', 'title': 'Mine'},
      );
      server.rows['notes'] = <Map<String, dynamic>>[
        noteRow('n1', '2026-09-30T10:00:00.000000+00:00'),
      ];
      await worker().pullAll();

      // A newer server row for the same, still-frozen entity is inside the
      // delta on the next run; it must not log a second conflict.
      server.rows['notes'] = <Map<String, dynamic>>[
        ...server.rows['notes']!,
        noteRow(
          'n1',
          '2026-09-30T11:00:00.000000+00:00',
          title: 'Server Again',
        ),
      ];
      await worker().pullAll();

      final conflicts = await db.select(db.conflictLog).get();
      expect(conflicts, hasLength(1));
      expect(
        jsonDecode(conflicts.single.serverPayload)['title'],
        'Server Title',
        reason:
            'the first, recorded conflict is not rewritten by the newer row',
      );
    });

    test(
      'a blocked entry is left alone and does not become a conflict',
      () async {
        await enqueue(
          entityType: 'note',
          entityId: 'n1',
          state: 'blocked',
          payload: {'id': 'n1', 'title': 'Mine'},
        );
        server.rows['notes'] = <Map<String, dynamic>>[
          noteRow('n1', '2026-09-30T10:00:00.000000+00:00', title: 'Server'),
        ];

        final outcome = await worker().pullAll();

        expect(outcome.conflicts, 0);
        expect(await db.select(db.conflictLog).get(), isEmpty);
        expect((await queue.getAll()).single.state, 'blocked');
        expect(await db.select(db.notes).get(), isEmpty);
      },
    );

    test('a resolved queue entry no longer blocks the server row', () async {
      await enqueue(
        entityType: 'note',
        entityId: 'n1',
        state: 'resolved',
        payload: {'id': 'n1'},
      );
      server.rows['notes'] = <Map<String, dynamic>>[
        noteRow('n1', '2026-09-30T10:00:00.000000+00:00', title: 'Server'),
      ];

      final outcome = await worker().pullAll();

      expect(outcome.conflicts, 0);
      final note = await (db.select(
        db.notes,
      )..where((row) => row.id.equals('n1'))).getSingle();
      expect(note.title, 'Server');
      expect(note.syncedAt, isNotNull);
    });
  });

  group('pure helpers', () {
    test('the composite pull filter is the OR over both columns', () {
      expect(
        syncPullFilter('T', 'id'),
        'server_updated_at.gt.T,and(server_updated_at.eq.T,id.gt.id)',
      );
    });

    test('decodeServerTime reads the scalar and the row form', () {
      expect(
        decodeServerTime('2026-09-30T10:00:00+00:00'),
        DateTime.utc(2026, 9, 30, 10),
      );
      expect(
        decodeServerTime(<String, dynamic>{
          'sync_server_time': '2026-09-30T10:00:00Z',
        }),
        DateTime.utc(2026, 9, 30, 10),
      );
      expect(decodeServerTime('nonsense'), isNull);
      expect(decodeServerTime(null), isNull);
    });

    test('a cursor round-trips and a malformed one reads as absent', () {
      final cursor = SyncCursor(time: 'T', id: 'i');
      expect(SyncCursor.decode(jsonEncode(cursor.toJson()))!.id, 'i');
      expect(SyncCursor.decode(null), isNull);
      expect(SyncCursor.decode(''), isNull);
      expect(SyncCursor.decode('not json'), isNull);
      expect(SyncCursor.decode('{"time":"T"}'), isNull);
      expect(SyncCursor.decode('{"time":"","id":"i"}'), isNull);
    });
  });
}
