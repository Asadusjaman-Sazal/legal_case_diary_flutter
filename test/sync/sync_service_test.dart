/// SyncService tests — Task 18 Phase 2.
///
/// The service is exercised through a real [ProviderContainer] with the network
/// boundary faked, so the gates, the single-in-flight rule and the backoff are
/// tested as they ship.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/sync/connectivity_monitor.dart';
import 'package:legal_case_diary/sync/sync_metadata_dao.dart';
import 'package:legal_case_diary/sync/sync_queue_dao.dart';
import 'package:legal_case_diary/sync/sync_service.dart';
import 'package:legal_case_diary/sync/sync_transport.dart';

class _FakeTransport implements SyncTransport {
  final List<List<Map<String, dynamic>>> calls = <List<Map<String, dynamic>>>[];
  final List<String> pulledTables = <String>[];
  final Map<String, List<Map<String, dynamic>>> pages =
      <String, List<Map<String, dynamic>>>{};
  Object? error;
  DateTime? server;

  @override
  Future<List<Map<String, dynamic>>> pushChanges(
    List<Map<String, dynamic>> rows,
  ) async {
    calls.add(rows);
    final failure = error;
    if (failure != null) throw failure;
    return rows
        .map((row) => <String, dynamic>{
              'mutation_id': row['mutation_id'],
              'status': 'accepted',
              'version': 1,
              'entity_id': row['entity_id'],
              'entity_type': row['entity_type'],
            })
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPage(
    String table, {
    String? sinceTime,
    String? sinceId,
    int limit = 200,
  }) async {
    pulledTables.add(table);
    return pages[table] ?? const <Map<String, dynamic>>[];
  }

  @override
  Future<DateTime?> serverTime() async => server;
}

void main() {
  late AppDatabase db;
  late _FakeTransport transport;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.customSelect('select 1').get();
    transport = _FakeTransport();
  });

  tearDown(() => db.close());

  ProviderContainer container({required bool entitled, required bool online}) {
    final value = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWith((ref) async => db),
        accountCacheUserIdProvider.overrideWithValue('user-1'),
        accountProfileProvider.overrideWith((ref) => Stream.value(null)),
        premiumAccessProvider.overrideWith((ref) async => entitled),
        isOnlineProvider.overrideWith((ref) => Stream.value(online)),
        syncServiceProvider.overrideWith(
          (ref) => SyncService(ref, transportOverride: () => transport),
        ),
      ],
    );
    addTearDown(value.dispose);
    return value;
  }

  Future<void> enqueue(String id) => SyncQueueDao(db).insert(
        SyncQueueCompanion.insert(
          entityType: 'court',
          entityId: id,
          operation: 'insert',
          mutationId: 'mut-$id',
          basePayload: '{}',
          changedFields: jsonEncode(const <String>['id']),
          payload: jsonEncode(<String, dynamic>{'id': id}),
          preMutationPayload: '{}',
          createdAt: 0,
          state: 'pending',
        ),
      );

  test('does not sync when the account is not entitled', () async {
    await enqueue('c1');
    final value = container(entitled: false, online: true);
    final service = value.read(syncServiceProvider);

    await service.syncNow();

    expect(transport.calls, isEmpty);
    expect((await SyncQueueDao(db).getAll()).single.state, 'pending');
  });

  test('does not sync when offline', () async {
    await enqueue('c1');
    final value = container(entitled: true, online: false);
    final service = value.read(syncServiceProvider);
    // Start the connectivity stream and let its first value land.
    final subscription = value.listen(isOnlineProvider, (previous, next) {});
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);

    await service.syncNow();

    expect(transport.calls, isEmpty);
  });

  test('drains the queue when entitled and online', () async {
    await enqueue('c1');
    final value = container(entitled: true, online: true);
    final service = value.read(syncServiceProvider);

    await service.syncNow();

    expect(transport.calls, hasLength(1));
    expect((await SyncQueueDao(db).getAll()).single.state, 'resolved');
  });

  test('never runs two pushes at once', () async {
    await enqueue('c1');
    await enqueue('c2');
    final value = container(entitled: true, online: true);
    final service = value.read(syncServiceProvider);

    await Future.wait(<Future<void>>[service.syncNow(), service.syncNow()]);

    // The second request was coalesced while the first ran; the queue was
    // already empty by the time it could run, so there is exactly one call.
    expect(transport.calls, hasLength(1));
  });

  test('a retryable failure starts a backoff window', () async {
    await enqueue('c1');
    transport.error = const SyncFailure(
      'offline',
      kind: SyncFailureKind.network,
      retryable: true,
    );
    final value = container(entitled: true, online: true);
    final service = value.read(syncServiceProvider);

    await service.syncNow();
    expect(transport.calls, hasLength(1));

    // A second, non-forced run inside the window is skipped entirely.
    await service.syncNow();
    expect(transport.calls, hasLength(1));
  });

  test('a write-coalescing drain pushes but never pulls', () async {
    await enqueue('c1');
    final value = container(entitled: true, online: true);
    final service = value.read(syncServiceProvider);

    await service.syncNow();

    expect(transport.calls, hasLength(1));
    expect(transport.pulledTables, isEmpty);
  });

  test('a pull drain pulls every synced table after the push', () async {
    await enqueue('c1');
    final value = container(entitled: true, online: true);
    final service = value.read(syncServiceProvider);

    await service.syncNow(pull: true);

    expect(transport.pulledTables, hasLength(12));
    expect(transport.pulledTables.first, 'court_categories');
    expect((await SyncQueueDao(db).getAll()).single.state, 'resolved');
    final metadata = SyncMetadataDao(db);
    expect(await metadata.getIntValue(lastSuccessfulSyncAtKey), isNotNull);
  });

  test('the drain applies the compaction matrix before pushing', () async {
    final dao = SyncQueueDao(db);
    Future<void> enqueueUpdate(int createdAt, String courtName) => dao.insert(
          SyncQueueCompanion.insert(
            entityType: 'court',
            entityId: 'c1',
            operation: 'update',
            mutationId: 'mut-$createdAt',
            baseVersion: const Value(4),
            basePayload:
                jsonEncode(<String, dynamic>{'id': 'c1', 'court_name': 'Old'}),
            changedFields: jsonEncode(const <String>['court_name']),
            payload: jsonEncode(<String, dynamic>{
              'id': 'c1',
              'court_name': courtName,
            }),
            preMutationPayload: '{}',
            createdAt: createdAt,
            state: 'pending',
          ),
        );

    await enqueueUpdate(1, 'First');
    await enqueueUpdate(2, 'Second');
    final value = container(entitled: true, online: true);
    final service = value.read(syncServiceProvider);

    await service.syncNow();

    expect(transport.calls, hasLength(1));
    expect(
      transport.calls.single,
      hasLength(1),
      reason: 'one mutation per entity per batch',
    );
    expect(transport.calls.single.single['payload']['court_name'], 'Second');
    final rows = await dao.getByEntity('court', 'c1');
    expect(rows.single.mutationId, 'mut-1',
        reason: 'the earliest row keeps the run identity');
    expect(rows.single.state, 'resolved');
  });

  test('a push-only drain stamps last_successful_sync_at', () async {
    await enqueue('c1');
    final value = container(entitled: true, online: true);
    final service = value.read(syncServiceProvider);

    await service.syncNow();

    expect(transport.pulledTables, isEmpty);
    expect(
      await SyncMetadataDao(db).getIntValue(lastSuccessfulSyncAtKey),
      isNotNull,
    );
  });

  test('a pulled page is applied and its cursor stored', () async {
    await db.into(db.courtCategories).insert(
          CourtCategoriesCompanion.insert(
            id: 'cat-1',
            nameKey: 'cat',
            courtLevel: 'lower',
            orderIndex: 0,
            updatedAt: 0,
          ),
        );
    transport.pages['courts'] = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'c9',
        'court_name': 'Pulled Court',
        'higher_lower_courts': 'Lower Court',
        'court_category_id': 'cat-1',
        'order_index': 0,
        'is_custom': true,
        'is_user_modified': false,
        'updated_at': 5,
        'version': 1,
        'is_deleted': false,
        'server_updated_at': '2026-09-30T10:00:00.000001+00:00',
      },
    ];
    final value = container(entitled: true, online: true);
    final service = value.read(syncServiceProvider);

    await service.syncNow(pull: true);

    final court = await (db.select(db.courts)..where((r) => r.id.equals('c9')))
        .getSingle();
    expect(court.courtName, 'Pulled Court');
    final cursor = await SyncMetadataDao(db).getCursor('courts');
    expect(cursor?.id, 'c9');
    expect(cursor?.time, '2026-09-30T10:00:00.000001+00:00');
  });

  test('a device clock more than two minutes off records the offset and warns',
      () async {
    transport.server = DateTime.now().toUtc().add(const Duration(minutes: 9));
    final value = container(entitled: true, online: true);
    final service = value.read(syncServiceProvider);

    await service.syncNow(pull: true);

    expect(service.notice.value, SyncNotice.clockSkew);
    final offset = await SyncMetadataDao(db).getIntValue(clockOffsetMsKey);
    expect(offset, isNotNull);
    expect(offset! > const Duration(minutes: 8).inMilliseconds, isTrue);
  });

  test('a server clock within the threshold records the offset silently',
      () async {
    transport.server = DateTime.now().toUtc().add(const Duration(seconds: 20));
    final value = container(entitled: true, online: true);
    final service = value.read(syncServiceProvider);

    await service.syncNow(pull: true);

    expect(service.notice.value, isNull);
    expect(
      await SyncMetadataDao(db).getIntValue(clockOffsetMsKey),
      isNotNull,
    );
  });
}
