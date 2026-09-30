/// Tests for the Sync Status helpers and actions (Task 19 Phase 4).
///
/// The filter helpers are pure, so they are pinned directly. Retry and Discard
/// are exercised over a real in-memory database and a fake transport, because
/// what matters about Discard is which of its four endings happens and what the
/// local record looks like afterwards — the "authoritative-row rollback/pull" the
/// plan asks for, and the offline fallback that must not invent anything.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/sync/sync_queue_dao.dart';
import 'package:legal_case_diary/sync/sync_status_providers.dart';
import 'package:legal_case_diary/sync/sync_transport.dart';

/// One queue row with every column set, for the pure filter tests.
SyncQueueRow _queued(
  int id,
  String entityType,
  String entityId,
  String operation,
  String mutationId,
  int createdAt,
  String state,
) => SyncQueueRow(
  id: id,
  entityType: entityType,
  entityId: entityId,
  operation: operation,
  mutationId: mutationId,
  baseVersion: null,
  basePayload: '{}',
  changedFields: '[]',
  payload: '{}',
  preMutationPayload: '{}',
  createdAt: createdAt,
  retryCount: 0,
  lastAttemptAt: null,
  state: state,
  lastError: null,
);

/// A complete `notes` row as the server returns it.
Map<String, dynamic> _serverNote({String title = 'Server Title'}) =>
    <String, dynamic>{
      'id': 'n1',
      'user_id': 'user-1',
      'title': title,
      'body': 'Body',
      'is_pinned': false,
      'created_at': 0,
      'updated_at': 0,
      'version': 2,
      'is_deleted': false,
      'server_updated_at': '2026-09-30T10:00:00.000000+00:00',
    };

/// A transport that answers one `fetchRow` per call, or fails on demand.
class _FakeTransport implements SyncTransport {
  _FakeTransport({this.row});

  /// What `fetchRow` returns; null models a row the server does not have.
  Map<String, dynamic>? row;

  /// When true, `fetchRow` throws — the "could not ask" case.
  bool offline = false;

  @override
  Future<Map<String, dynamic>?> fetchRow(String table, String id) async {
    if (offline) throw Exception('offline');
    return row;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPage(
    String table, {
    String? sinceTime,
    String? sinceId,
    int limit = 200,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> pushChanges(
    List<Map<String, dynamic>> rows,
  ) async => const [];

  @override
  Future<DateTime?> serverTime() async => null;
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.customSelect('select 1').get();
  });

  tearDown(() async => db.close());

  SyncQueueRow row({
    String state = 'blocked',
    int retryCount = 4,
    String? lastError = 'permission_denied',
  }) => SyncQueueRow(
    id: 1,
    entityType: 'note',
    entityId: 'n1',
    operation: 'update',
    mutationId: 'mut-1',
    baseVersion: 1,
    basePayload: jsonEncode(_serverNote(title: 'Base Title')),
    changedFields: jsonEncode(const <String>['title']),
    payload: jsonEncode(_serverNote(title: 'My Title')),
    preMutationPayload: jsonEncode(_serverNote(title: 'Base Title')),
    createdAt: 0,
    retryCount: retryCount,
    lastAttemptAt: 2000,
    state: state,
    lastError: lastError,
  );

  Future<void> insertQueue(SyncQueueRow entry) async {
    await db
        .into(db.syncQueue)
        .insert(
          SyncQueueCompanion.insert(
            entityType: entry.entityType,
            entityId: entry.entityId,
            operation: entry.operation,
            mutationId: entry.mutationId,
            baseVersion: Value(entry.baseVersion),
            basePayload: entry.basePayload,
            changedFields: entry.changedFields,
            payload: entry.payload,
            preMutationPayload: entry.preMutationPayload,
            createdAt: entry.createdAt,
            retryCount: Value(entry.retryCount),
            lastAttemptAt: Value(entry.lastAttemptAt),
            state: entry.state,
            lastError: Value(entry.lastError),
          ),
        );
  }

  Future<void> insertNote(String title) => db
      .into(db.notes)
      .insert(
        NotesCompanion.insert(
          id: 'n1',
          userId: 'user-1',
          title: title,
          body: 'Body',
          createdAt: 0,
          updatedAt: 0,
        ),
      );

  group('filters', () {
    final rows = [
      _queued(1, 'note', 'a', 'update', 'm1', 0, 'pending'),
      _queued(2, 'note', 'b', 'insert', 'm2', 1, 'conflict_pending'),
      _queued(3, 'case', 'c', 'delete', 'm3', 2, 'blocked'),
    ];

    test('each filter matches only its own states', () {
      expect(
        rows.where((r) => syncStatusMatches(r, SyncStatusFilter.all)),
        hasLength(3),
      );
      expect(
        rows.where((r) => syncStatusMatches(r, SyncStatusFilter.pending)),
        hasLength(1),
      );
      expect(
        rows.where((r) => syncStatusMatches(r, SyncStatusFilter.conflicted)),
        hasLength(1),
      );
      expect(
        rows.where((r) => syncStatusMatches(r, SyncStatusFilter.blocked)),
        hasLength(1),
      );
    });

    test('counts agree with the filters, and attention excludes pending', () {
      final counts = syncStatusCounts(rows);
      expect(counts[SyncStatusFilter.all], 3);
      expect(counts[SyncStatusFilter.pending], 1);
      expect(counts[SyncStatusFilter.conflicted], 1);
      expect(counts[SyncStatusFilter.blocked], 1);
      // The badge counts only what needs a person.
      expect(syncStatusAttentionCount(rows), 2);
    });
  });

  group('discard', () {
    test('pulls the authoritative row back when the server has one', () async {
      await insertQueue(row());
      await insertNote('My Title');
      final transport = _FakeTransport(row: _serverNote());

      final actions = SyncStatusActions(
        db: db,
        queue: SyncQueueDao(db),
        transport: transport,
      );
      final outcome = await actions.discard(
        (await db.select(db.syncQueue).get()).single,
      );

      expect(outcome, SyncDiscardOutcome.rolledBackFromServer);
      expect((await db.select(db.syncQueue).get()), isEmpty);
      expect((await db.select(db.notes).get()).single.title, 'Server Title');
    });

    test('removes a provisional record the server never received', () async {
      await insertQueue(row());
      await insertNote('My Title');
      final transport = _FakeTransport();

      final actions = SyncStatusActions(
        db: db,
        queue: SyncQueueDao(db),
        transport: transport,
      );
      final outcome = await actions.discard(
        (await db.select(db.syncQueue).get()).single,
      );

      expect(outcome, SyncDiscardOutcome.removed);
      expect((await db.select(db.syncQueue).get()), isEmpty);
      expect((await db.select(db.notes).get()), isEmpty);
    });

    test('offline, restores the pre-mutation snapshot instead', () async {
      await insertQueue(row());
      await insertNote('My Title');
      final transport = _FakeTransport(row: _serverNote())..offline = true;

      final actions = SyncStatusActions(
        db: db,
        queue: SyncQueueDao(db),
        transport: transport,
      );
      final outcome = await actions.discard(
        (await db.select(db.syncQueue).get()).single,
      );

      expect(outcome, SyncDiscardOutcome.rolledBackLocally);
      expect((await db.select(db.syncQueue).get()), isEmpty);
      expect((await db.select(db.notes).get()).single.title, 'Base Title');
    });

    test(
      'offline with no snapshot, drops the mutation and invents nothing',
      () async {
        final entry = row();
        // An insert has no previous state to go back to.
        final insert = SyncQueueRow(
          id: entry.id,
          entityType: entry.entityType,
          entityId: entry.entityId,
          operation: 'insert',
          mutationId: entry.mutationId,
          baseVersion: null,
          basePayload: '{}',
          changedFields: entry.changedFields,
          payload: entry.payload,
          preMutationPayload: '{}',
          createdAt: entry.createdAt,
          retryCount: 0,
          lastAttemptAt: null,
          state: entry.state,
          lastError: null,
        );
        await insertQueue(insert);
        await insertNote('My Title');

        final actions = SyncStatusActions(db: db, queue: SyncQueueDao(db));
        final outcome = await actions.discard(
          (await db.select(db.syncQueue).get()).single,
        );

        expect(outcome, SyncDiscardOutcome.dropped);
        expect((await db.select(db.syncQueue).get()), isEmpty);
        // Nothing local was guessed at; the record is left alone.
        expect((await db.select(db.notes).get()).single.title, 'My Title');
      },
    );
  });

  test('retry returns a blocked entry to a clean pending state', () async {
    await insertQueue(row());
    final actions = SyncStatusActions(db: db, queue: SyncQueueDao(db));

    await actions.retry((await db.select(db.syncQueue).get()).single);

    final retried = (await db.select(db.syncQueue).get()).single;
    expect(retried.state, 'pending');
    expect(retried.retryCount, 0);
    expect(retried.lastError, isNull);
  });
}
