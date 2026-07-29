/// Unit tests for [SyncWriteHelper] and the offline compaction matrix.
library;

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/sync/sync_queue_dao.dart';
import 'package:legal_case_diary/sync/sync_write_helper.dart';

void main() {
  group('SyncWriteHelper', () {
    late AppDatabase db;
    late SyncQueueDao queue;
    late SyncWriteHelper helper;
    late LocalIdentityService identity;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
      queue = SyncQueueDao(db);
      final prefs = await SharedPreferences.getInstance();
      identity = LocalIdentityService(prefs);
      helper = SyncWriteHelper(queue, identity);
    });

    tearDown(() async {
      await db.close();
    });

    Map<String, dynamic> makePayload({String name = 'Test', bool isDeleted = false}) => <String, dynamic>{
      'id': 'entity-1',
      'name': name,
      'is_deleted': isDeleted,
    };

    test('records a pending insert', () async {
      await helper.recordInsert(
        entityType: 'case',
        entityId: 'entity-1',
        payload: makePayload(name: 'New'),
        changedFields: <String>['id', 'name'],
      );

      final rows = await queue.getAll();
      expect(rows, hasLength(1));
      expect(rows.first.operation, 'insert');
      expect(rows.first.state, 'pending');
      expect(rows.first.entityType, 'case');
      expect(rows.first.entityId, 'entity-1');
      expect(rows.first.baseVersion, isNull);
      expect(rows.first.retryCount, 0);
    });

    test('records a plain update when no prior row exists', () async {
      await helper.recordUpdate(
        entityType: 'case',
        entityId: 'entity-1',
        payload: makePayload(name: 'Updated'),
        changedFields: <String>['name'],
        basePayload: <String, dynamic>{'id': 'entity-1', 'name': 'Base'},
        baseVersion: 2,
        preMutationPayload: <String, dynamic>{'id': 'entity-1', 'name': 'Base'},
      );

      final rows = await queue.getAll();
      expect(rows, hasLength(1));
      expect(rows.first.operation, 'update');
      expect(rows.first.baseVersion, 2);
      final payload = jsonDecode(rows.first.payload) as Map<String, dynamic>;
      expect(payload['name'], 'Updated');
    });

    test('insert + update compacts to a single insert with latest payload', () async {
      await helper.recordInsert(
        entityType: 'case',
        entityId: 'entity-1',
        payload: makePayload(name: 'New'),
        changedFields: <String>['id', 'name'],
      );

      final firstRows = await queue.getAll();
      final firstMutationId = firstRows.first.mutationId;

      await helper.recordUpdate(
        entityType: 'case',
        entityId: 'entity-1',
        payload: makePayload(name: 'Updated'),
        changedFields: <String>['name'],
        basePayload: <String, dynamic>{'id': 'entity-1', 'name': 'New'},
        baseVersion: 3,
        preMutationPayload: <String, dynamic>{'id': 'entity-1', 'name': 'New'},
      );

      final rows = await queue.getAll();
      expect(rows, hasLength(1));
      expect(rows.first.operation, 'insert');
      expect(rows.first.mutationId, firstMutationId);
      final payload = jsonDecode(rows.first.payload) as Map<String, dynamic>;
      expect(payload['name'], 'Updated');
      expect(rows.first.baseVersion, isNull);
      expect(rows.first.basePayload, '{}');
      final changed = jsonDecode(rows.first.changedFields) as List<dynamic>;
      expect(changed, contains('id'));
      expect(changed, contains('name'));
    });

    test('insert + delete drops both rows', () async {
      await helper.recordInsert(
        entityType: 'case',
        entityId: 'entity-1',
        payload: makePayload(name: 'New'),
        changedFields: <String>['id', 'name'],
      );

      await helper.recordDelete(
        entityType: 'case',
        entityId: 'entity-1',
        payload: makePayload(name: 'New', isDeleted: true),
        changedFields: <String>['is_deleted'],
        preMutationPayload: <String, dynamic>{'id': 'entity-1', 'name': 'New'},
      );

      final rows = await queue.getAll();
      expect(rows, isEmpty);
    });

    test('update(s) + delete compacts to a single delete', () async {
      await helper.recordUpdate(
        entityType: 'case',
        entityId: 'entity-1',
        payload: makePayload(name: 'First Update'),
        changedFields: <String>['name'],
        basePayload: <String, dynamic>{'id': 'entity-1', 'name': 'Base'},
        baseVersion: 2,
        preMutationPayload: <String, dynamic>{'id': 'entity-1', 'name': 'Base'},
      );

      await helper.recordUpdate(
        entityType: 'case',
        entityId: 'entity-1',
        payload: makePayload(name: 'Second Update'),
        changedFields: <String>['name'],
        basePayload: <String, dynamic>{'id': 'entity-1', 'name': 'Base'},
        baseVersion: 2,
        preMutationPayload: <String, dynamic>{'id': 'entity-1', 'name': 'First Update'},
      );

      await helper.recordDelete(
        entityType: 'case',
        entityId: 'entity-1',
        payload: makePayload(name: 'Second Update', isDeleted: true),
        changedFields: <String>['is_deleted'],
        preMutationPayload: <String, dynamic>{'id': 'entity-1', 'name': 'Second Update'},
      );

      final rows = await queue.getAll();
      expect(rows, hasLength(1));
      expect(rows.first.operation, 'delete');
      expect(rows.first.baseVersion, 2);
      final payload = jsonDecode(rows.first.payload) as Map<String, dynamic>;
      expect(payload['name'], 'Second Update');
      expect(payload['is_deleted'], true);
      final pre = jsonDecode(rows.first.preMutationPayload) as Map<String, dynamic>;
      expect(pre['name'], 'Base');
    });

    test('multiple updates compact to a single update with union changed fields', () async {
      await helper.recordUpdate(
        entityType: 'case',
        entityId: 'entity-1',
        payload: makePayload(name: 'First'),
        changedFields: <String>['name'],
        basePayload: <String, dynamic>{'id': 'entity-1', 'name': 'Base'},
        baseVersion: 5,
        preMutationPayload: <String, dynamic>{'id': 'entity-1', 'name': 'Base'},
      );

      await helper.recordUpdate(
        entityType: 'case',
        entityId: 'entity-1',
        payload: makePayload(name: 'Second'),
        changedFields: <String>['name', 'next_date'],
        basePayload: <String, dynamic>{'id': 'entity-1', 'name': 'Base'},
        baseVersion: 5,
        preMutationPayload: <String, dynamic>{'id': 'entity-1', 'name': 'First'},
      );

      final rows = await queue.getAll();
      expect(rows, hasLength(1));
      expect(rows.first.operation, 'update');
      expect(rows.first.baseVersion, 5);
      final payload = jsonDecode(rows.first.payload) as Map<String, dynamic>;
      expect(payload['name'], 'Second');
      final changed = jsonDecode(rows.first.changedFields) as List<dynamic>;
      expect(changed, contains('name'));
      expect(changed, contains('next_date'));
    });

    test('does not compact when an existing row is conflict_pending', () async {
      await helper.recordInsert(
        entityType: 'case',
        entityId: 'entity-1',
        payload: makePayload(name: 'New'),
        changedFields: <String>['id', 'name'],
      );

      // Simulate a conflict_pending row by directly updating its state.
      final rows = await queue.getAll();
      await queue.updateState(rows.first.id, 'conflict_pending');

      await helper.recordUpdate(
        entityType: 'case',
        entityId: 'entity-1',
        payload: makePayload(name: 'After Conflict'),
        changedFields: <String>['name'],
        basePayload: <String, dynamic>{'id': 'entity-1', 'name': 'New'},
        baseVersion: 1,
        preMutationPayload: <String, dynamic>{'id': 'entity-1', 'name': 'New'},
      );

      final after = await queue.getAll();
      expect(after, hasLength(2));
      final states = after.map((r) => r.state).toList();
      expect(states, contains('conflict_pending'));
      expect(states, contains('pending'));
    });

    test('syncColumns exposes current timestamp and user id', () {
      final columns = helper.syncColumns();
      expect(columns.updatedAt, isPositive);
      expect(columns.lastModifiedBy, helper.currentUserId);
      expect(columns.syncedAt, isNull);
      expect(columns.isDeleted, false);

      final deletedColumns = helper.syncColumns(isDeleted: true);
      expect(deletedColumns.isDeleted, true);
    });

    test('currentUserId returns a stable UUID', () async {
      final a = helper.currentUserId;
      final b = helper.currentUserId;
      expect(a, isNotEmpty);
      expect(a, b);

      // A fresh service reading the same preferences returns the same id.
      final prefs = await SharedPreferences.getInstance();
      final identity2 = LocalIdentityService(prefs);
      expect(identity2.getId(), a);
    });
  });
}
