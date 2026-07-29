/// Delete requests repository.
/// Local implementation in Task 05 Phase 3; full firm workflow in Part B.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/repositories/base_local_repository.dart';
import '../../../database/app_database.dart';
import '../../../sync/sync_write_helper.dart';
import '../../../sync/delete_requests_dao.dart';

/// Delete requests repository interface.
abstract class DeleteRequestsRepository {
  /// Creates a delete request for the given entity.
  Future<String> createRequest({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> entitySnapshot,
    required int targetBaseVersion,
  });

  /// Lists all non-deleted delete requests.
  Future<List<DeleteRequest>> listAll({int? limit, int? offset});

  /// Reactive stream of all non-deleted delete requests.
  Stream<List<DeleteRequest>> watchAll({int? limit, int? offset});

  /// Returns a delete request by id, or null if not found/deleted.
  Future<DeleteRequest?> getById(String id);
}

/// Local Drift-backed implementation of [DeleteRequestsRepository].
class LocalDeleteRequestsRepository with BaseLocalRepository implements DeleteRequestsRepository {
  final DeleteRequestsDao _dao;

  @override
  final SyncWriteHelper syncHelper;

  /// Creates a repository backed by [dao] and [syncHelper].
  LocalDeleteRequestsRepository(this._dao, this.syncHelper);

  @override
  Future<String> createRequest({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> entitySnapshot,
    required int targetBaseVersion,
  }) async {
    final now = BaseLocalRepository.nowMillis;
    final id = const Uuid().v4();
    final userId = currentUserId;

    final companion = DeleteRequestsCompanion(
      id: Value(id),
      firmId: const Value<String?>(null),
      entityType: Value(entityType),
      entityId: Value(entityId),
      entitySnapshot: Value(jsonEncode(entitySnapshot)),
      targetBaseVersion: Value(targetBaseVersion),
      requestedBy: Value(userId),
      status: const Value('pending'),
      reviewNote: const Value.absent(),
      reviewedBy: const Value.absent(),
      createdAt: Value(now),
      updatedAt: Value(now),
      lastModifiedBy: Value(userId),
      isDeleted: const Value(false),
    );

    await _dao.insert(companion);

    final inserted = await _dao.getById(id);
    final payload = BaseLocalRepository.toSyncPayload(inserted!.toJson());
    await syncHelper.recordInsert(
      entityType: 'delete_request',
      entityId: id,
      payload: payload,
      changedFields: payload.keys.toList(),
    );

    return id;
  }

  @override
  Future<List<DeleteRequest>> listAll({int? limit, int? offset}) => _dao.getAll(limit: limit, offset: offset);

  @override
  Stream<List<DeleteRequest>> watchAll({int? limit, int? offset}) => _dao.watchAll(limit: limit, offset: offset);

  @override
  Future<DeleteRequest?> getById(String id) => _dao.getById(id);
}
