/// Delete requests repository: the associate side of the firm delete workflow.
///
/// Local implementation in Task 05 Phase 3; Task 20 Phase 3 makes it the real
/// creation path the plan's *Associate Deletion Policy* asks for.
///
/// **Table class: push/pull domain.** `delete_requests` rows are authored here,
/// queued through `sync_queue` under `entity_type = 'delete_request'` and pushed
/// by `push_changes`, exactly like a case or a note — which is what makes the
/// whole workflow **offline-capable** (the task's item 2). Nothing in this file
/// talks to the network.
///
/// Three facts the row must carry, and none of them is invented:
///
/// * **`firm_id`** — the request is firm-scoped, and both the RLS insert policy
///   (`firm_id = current_firm_id()`) and the server's own `sync_can_write` check
///   the same equality. A NULL there is not "no firm", it is a refused insert, so
///   the caller passes the account's firm id rather than leaving it blank;
/// * **`entity_snapshot`** — the target as it stood when the request was made,
///   which is what a reviewer reads and what proves the request meant *this*
///   version of the record;
/// * **`target_base_version`** — the version observed, which Phase 4's approval
///   compares against the server's current one so a materially changed record can
///   never be deleted on the strength of an old snapshot.
///
/// The requester's own still-pending request can be **refreshed** (the record
/// changed under it, so the snapshot is re-taken) or **cancelled** (withdrawn).
/// Cancelling a request that was never pushed compacts away to nothing: an
/// insert followed by a delete is a row the server never needed to know about.
///
/// The **reviewer** side (Task 20 Phase 4) writes through [approve] and
/// [reject]. Both are ordinary queued updates on the request row — the reviewer's
/// device never deletes anything itself, and the row's own version is the
/// optimistic-concurrency base. The one meaning `push_changes` cannot infer from
/// a plain update is *approval*, so [approve] sends `status = 'approved'`, which
/// is the branch that locks the target, re-checks it against
/// `target_base_version`, tombstones it atomically and resolves the request;
/// rejection is an ordinary update because keeping the record is exactly the
/// default. A **reconfirm** is simply another [approve] against the version the
/// server parked the request on when it first found the target stale — the
/// screen words it differently, nothing below needs to know.
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
  /// Creates a delete request for the given entity and returns its id.
  ///
  /// [firmId] is the account's own firm, read by the caller from the cached
  /// profile: team deletion is a firm-scoped decision, and a request with no firm
  /// is one the server would refuse.
  ///
  /// [requesterName] is the requester's own display name — the one profile row
  /// every device holds is its own, so this is known offline. The server derives
  /// the column from `profiles` and overwrites this on the way up, so it is a
  /// best-effort value that makes the request readable before the first sync
  /// rather than the authority on anybody's name.
  Future<String> createRequest({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> entitySnapshot,
    required int targetBaseVersion,
    required String firmId,
    required String requesterName,
  });

  /// Re-takes the snapshot and the observed version of a pending request.
  ///
  /// The requester's own way of saying "the record moved on — this is what I am
  /// asking to delete now". Refused for anything that is not their own pending
  /// request, which is exactly the scope RLS grants.
  Future<void> refreshSnapshot({
    required String id,
    required Map<String, dynamic> entitySnapshot,
    required int targetBaseVersion,
  });

  /// Withdraws a pending request.
  ///
  /// A soft-delete, never a hard one: `delete_requests` has no DELETE policy
  /// because the row is audit history (plan §1). A request that never reached the
  /// server therefore disappears completely, which is the honest outcome — it was
  /// never a fact anywhere but here.
  Future<void> cancel(String id);

  /// Approves a request, deleting the record it names.
  ///
  /// The reviewer's decision, queued locally and pushed later — reviews stage
  /// offline like every other mutation and the server stays authoritative. The
  /// server re-checks the target against the version the request records; a
  /// target that moved is **not** deleted, and the request is parked for a
  /// reconfirm — another [approve] — instead. [reviewNote] is the optional
  /// reason.
  Future<void> approve(String id, {String? reviewNote});

  /// Rejects a request, keeping the record.
  ///
  /// The request stays as audit history with `status = 'rejected'`, the note and
  /// the reviewer recorded; on the requester's next sync it reaches their device
  /// through the ordinary pull, which is how they are told.
  Future<void> reject(String id, {String? reviewNote});

  /// Lists all non-deleted delete requests.
  Future<List<DeleteRequest>> listAll({int? limit, int? offset});

  /// Reactive stream of all non-deleted delete requests.
  Stream<List<DeleteRequest>> watchAll({int? limit, int? offset});

  /// Reactive stream of one requester's own requests, newest first.
  Stream<List<DeleteRequest>> watchMine(String requestedBy);

  /// Returns a delete request by id, or null if not found/deleted.
  Future<DeleteRequest?> getById(String id);
}

/// Local Drift-backed implementation of [DeleteRequestsRepository].
class LocalDeleteRequestsRepository
    with BaseLocalRepository
    implements DeleteRequestsRepository {
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
    required String firmId,
    required String requesterName,
  }) async {
    final now = BaseLocalRepository.nowMillis;
    final id = const Uuid().v4();
    final userId = currentUserId;

    final companion = DeleteRequestsCompanion(
      id: Value(id),
      firmId: Value(firmId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      entitySnapshot: Value(jsonEncode(entitySnapshot)),
      targetBaseVersion: Value(targetBaseVersion),
      requestedBy: Value(userId),
      requesterName: Value(requesterName.trim()),
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
  Future<void> refreshSnapshot({
    required String id,
    required Map<String, dynamic> entitySnapshot,
    required int targetBaseVersion,
  }) async {
    final existing = await _dao.getById(id);
    if (existing == null || existing.status != 'pending') return;

    final now = BaseLocalRepository.nowMillis;
    final userId = currentUserId;

    await _dao.update(
      DeleteRequestsCompanion(
        id: Value(id),
        entitySnapshot: Value(jsonEncode(entitySnapshot)),
        targetBaseVersion: Value(targetBaseVersion),
        updatedAt: Value(now),
        lastModifiedBy: Value(userId),
      ),
    );

    final updated = await _dao.getById(id);
    await syncHelper.recordUpdate(
      entityType: 'delete_request',
      entityId: id,
      payload: BaseLocalRepository.toSyncPayload(updated!.toJson()),
      changedFields: ['entity_snapshot', 'target_base_version', 'updated_at'],
      basePayload: BaseLocalRepository.toSyncPayload(existing.toJson()),
      baseVersion: existing.version,
      preMutationPayload: BaseLocalRepository.toSyncPayload(existing.toJson()),
    );
  }

  @override
  Future<void> cancel(String id) async {
    final existing = await _dao.getById(id);
    if (existing == null || existing.status != 'pending') return;

    final now = BaseLocalRepository.nowMillis;
    final userId = currentUserId;

    await _dao.delete(id, now);

    await syncHelper.recordDelete(
      entityType: 'delete_request',
      entityId: id,
      payload: BaseLocalRepository.toSyncPayload(<String, dynamic>{
        'id': id,
        'isDeleted': true,
        'updatedAt': now,
        'lastModifiedBy': userId,
      }),
      changedFields: ['is_deleted', 'updated_at', 'last_modified_by'],
      basePayload: BaseLocalRepository.toSyncPayload(existing.toJson()),
      baseVersion: existing.version,
      preMutationPayload: BaseLocalRepository.toSyncPayload(existing.toJson()),
    );
  }

  @override
  Future<void> approve(String id, {String? reviewNote}) =>
      _review(id, status: 'approved', reviewNote: reviewNote);

  @override
  Future<void> reject(String id, {String? reviewNote}) =>
      _review(id, status: 'rejected', reviewNote: reviewNote);

  /// Writes one reviewer decision: the local row first, then its queue entry.
  ///
  /// Only a request that is still `pending` (or parked as
  /// `stale_review_required`) can be decided; anything already resolved is left
  /// exactly as it is, because re-writing a decision is how an audit trail is
  /// corrupted. The version the device currently holds is the concurrency base,
  /// and the pre-mutation snapshot is the row as it stood, so a refusal can roll
  /// the provisional change straight back.
  Future<void> _review(
    String id, {
    required String status,
    String? reviewNote,
  }) async {
    final existing = await _dao.getById(id);
    if (existing == null) return;
    if (existing.status != 'pending' &&
        existing.status != 'stale_review_required') {
      return;
    }

    final now = BaseLocalRepository.nowMillis;
    final userId = currentUserId;

    await _dao.update(
      DeleteRequestsCompanion(
        id: Value(id),
        status: Value(status),
        reviewNote: Value(reviewNote),
        reviewedBy: Value(userId),
        updatedAt: Value(now),
        lastModifiedBy: Value(userId),
      ),
    );

    final updated = await _dao.getById(id);
    await syncHelper.recordUpdate(
      entityType: 'delete_request',
      entityId: id,
      payload: BaseLocalRepository.toSyncPayload(updated!.toJson()),
      changedFields: const [
        'status',
        'review_note',
        'reviewed_by',
        'updated_at',
      ],
      basePayload: BaseLocalRepository.toSyncPayload(existing.toJson()),
      baseVersion: existing.version,
      preMutationPayload: BaseLocalRepository.toSyncPayload(existing.toJson()),
    );
  }

  @override
  Future<List<DeleteRequest>> listAll({int? limit, int? offset}) =>
      _dao.getAll(limit: limit, offset: offset);

  @override
  Stream<List<DeleteRequest>> watchAll({int? limit, int? offset}) =>
      _dao.watchAll(limit: limit, offset: offset);

  @override
  Stream<List<DeleteRequest>> watchMine(String requestedBy) =>
      _dao.watchMine(requestedBy);

  @override
  Future<DeleteRequest?> getById(String id) => _dao.getById(id);
}
