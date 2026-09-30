/// Sync queue DAO: local data access for outbound mutation queue.
/// Implemented in Task 05 Phase 1.
library;

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'queue_compaction.dart';

/// Data Access Object for [SyncQueue] table operations.
class SyncQueueDao {
  /// Creates a DAO backed by [db].
  SyncQueueDao(this.db);

  /// The Drift database instance.
  final AppDatabase db;

  /// Returns all queue entries ordered by [createdAt] ascending.
  Future<List<SyncQueueRow>> getAll({int? limit, int? offset}) async {
    final query = db.select(db.syncQueue)
      ..orderBy([(row) => OrderingTerm(expression: row.createdAt)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Returns all pending queue entries ordered by [createdAt] ascending.
  Future<List<SyncQueueRow>> getPending({int? limit, int? offset}) async {
    final query = db.select(db.syncQueue)
      ..where((row) => row.state.equals('pending'))
      ..orderBy([(row) => OrderingTerm(expression: row.createdAt)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Returns queue entries for a specific entity.
  Future<List<SyncQueueRow>> getByEntity(
    String entityType,
    String entityId, {
    int? limit,
    int? offset,
  }) async {
    final query = db.select(db.syncQueue)
      ..where(
        (row) =>
            row.entityType.equals(entityType) & row.entityId.equals(entityId),
      )
      ..orderBy([(row) => OrderingTerm(expression: row.createdAt)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Returns a queue entry by its stable mutation id.
  Future<SyncQueueRow?> getByMutationId(String mutationId) async => (db.select(
    db.syncQueue,
  )..where((row) => row.mutationId.equals(mutationId))).getSingleOrNull();

  /// Returns every entry still waiting to be pushed, oldest first.
  ///
  /// Ordering by dependency rank happens in the worker, because it depends on
  /// the entity map rather than on a column.
  Future<List<SyncQueueRow>> getPushable({int? limit}) async {
    final query = db.select(db.syncQueue)
      ..where(
        (row) => row.state.equals('pending') | row.state.equals('pushing'),
      )
      ..orderBy([(row) => OrderingTerm(expression: row.createdAt)]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  /// Returns every entry still awaiting a terminal result (for the Sync Status
  /// screen and the backlog review).
  Future<List<SyncQueueRow>> getUnresolved() async =>
      (db.select(db.syncQueue)..where(
            (row) =>
                row.state.equals('pending') |
                row.state.equals('pushing') |
                row.state.equals('conflict_pending') |
                row.state.equals('blocked'),
          ))
          .get();

  /// The `entityType\u0000entityId` keys frozen on an unresolved conflict.
  ///
  /// One query, so the push worker can skip every entry of a frozen entity
  /// without asking per row.
  Future<Set<String>> getConflictPendingKeys() async {
    final rows = await (db.select(
      db.syncQueue,
    )..where((row) => row.state.equals('conflict_pending'))).get();
    return rows.map((row) => '${row.entityType}\u0000${row.entityId}').toSet();
  }

  /// Whether any entry for the entity is frozen on a conflict.
  Future<bool> hasConflictPending(String entityType, String entityId) async {
    final row =
        await (db.select(db.syncQueue)
              ..where(
                (row) =>
                    row.entityType.equals(entityType) &
                    row.entityId.equals(entityId) &
                    row.state.equals('conflict_pending'),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// Records the start of one push attempt: state `pushing`, plus the attempt
  /// timestamp the Addendum requires immediately before every attempt.
  Future<int> markAttempt(int id, int attemptedAt) =>
      updateState(id, 'pushing', lastAttemptAt: attemptedAt);

  /// Marks an entry resolved (its mutation was applied or reconciled).
  Future<int> resolve(int id) => updateState(id, 'resolved');

  /// Returns an entry to `pending` with a bumped retry count and the error.
  Future<int> incrementRetry(
    int id, {
    required int retryCount,
    required String error,
    required int attemptedAt,
  }) => updateState(
    id,
    'pending',
    retryCount: retryCount,
    lastError: error,
    lastAttemptAt: attemptedAt,
  );

  /// Stops automatic retries for an entry that needs a person.
  Future<int> block(int id, {required String error, int? retryCount}) =>
      updateState(id, 'blocked', lastError: error, retryCount: retryCount);

  /// Freezes an entry on an unresolved conflict.
  Future<int> markConflictPending(int id, {required String error}) =>
      updateState(id, 'conflict_pending', lastError: error);

  /// Freezes every still-open entry for one entity (compaction freeze).
  Future<void> freezeEntity(
    String entityType,
    String entityId, {
    required String error,
  }) async {
    await (db.update(db.syncQueue)..where(
          (row) =>
              row.entityType.equals(entityType) &
              row.entityId.equals(entityId) &
              row.state.isNotIn(const ['resolved']),
        ))
        .write(
          SyncQueueCompanion(
            state: const Value('conflict_pending'),
            lastError: Value(error),
          ),
        );
  }

  /// Rewrites a queued mutation as the rebased one (Task 19 Phase 3).
  ///
  /// The three-way reconciliation lays the non-colliding local edits over the
  /// authoritative row and sends the result again. Two things must change with
  /// the payload: the mutation id is **new** — the old one already has a server
  /// receipt, so replaying it would return the same rejection instead of
  /// applying the merged edit — and `base_version` is the server's, because that
  /// is now the version the edit was written against. The row returns to
  /// `pending` with a clean retry count so the next pass sends it.
  Future<int> rebaseMutation(
    int id, {
    required String mutationId,
    required int baseVersion,
    required String basePayload,
    required String payload,
    required String changedFields,
    required String preMutationPayload,
  }) => (db.update(db.syncQueue)..where((row) => row.id.equals(id))).write(
    SyncQueueCompanion(
      mutationId: Value(mutationId),
      baseVersion: Value(baseVersion),
      basePayload: Value(basePayload),
      payload: Value(payload),
      changedFields: Value(changedFields),
      preMutationPayload: Value(preMutationPayload),
      state: const Value('pending'),
      retryCount: const Value(0),
      lastError: const Value<String?>(null),
    ),
  );

  /// Marks every still-open entry for one entity resolved.
  ///
  /// The resolution writer's counterpart to [freezeEntity]: once a person has
  /// answered a conflict, the rows it was holding are no longer pending work —
  /// the answer replaces them, and leaving them `conflict_pending` would freeze
  /// the entity forever behind a conflict that is already solved.
  Future<int> resolveEntity(String entityType, String entityId) =>
      (db.update(db.syncQueue)..where(
            (row) =>
                row.entityType.equals(entityType) &
                row.entityId.equals(entityId) &
                row.state.isNotIn(const ['resolved']),
          ))
          .write(const SyncQueueCompanion(state: Value('resolved')));

  /// Reactive stream of all queue entries.
  Stream<List<SyncQueueRow>> watchAll({int? limit, int? offset}) {
    final query = db.select(db.syncQueue)
      ..orderBy([(row) => OrderingTerm(expression: row.createdAt)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.watch();
  }

  /// Reactive stream of every entry that still needs something — the Sync
  /// Status screen's list (Task 19 Phase 4).
  ///
  /// `resolved` rows are the only ones left out, because a resolved mutation is
  /// finished work rather than a queue entry. Nothing in the `pending`,
  /// `pushing`, `conflict_pending` or `blocked` states is ever filtered away
  /// here, which is what keeps every unfinished row visible (the plan's "no
  /// queue row may ever become permanently invisible"). Ordered oldest first,
  /// so the screen reads like the queue drains.
  Stream<List<SyncQueueRow>> watchOpen() =>
      (db.select(db.syncQueue)
            ..where((row) => row.state.isNotIn(const ['resolved']))
            ..orderBy([(row) => OrderingTerm(expression: row.createdAt)]))
          .watch();

  /// The Sync Status Retry action: return a `blocked` entry to `pending` with a
  /// clean retry count and no error, so the next drain attempts it again.
  ///
  /// Retrying is deliberately a *state* change rather than a push: the user's
  /// tap only makes the entry eligible again, and the ordinary trigger
  /// (a rise in the pending count) sends it — so a retry cannot bypass the
  /// coalescing window or the entitlement gate.
  Future<int> retry(int id) =>
      (db.update(db.syncQueue)..where((row) => row.id.equals(id))).write(
        const SyncQueueCompanion(
          state: Value('pending'),
          retryCount: Value(0),
          lastError: Value(null),
        ),
      );

  /// Compacts every entity's accumulated `pending` rows in one transaction and
  /// returns how many rows were removed.
  ///
  /// The Offline Compaction Matrix itself is [planQueueCompaction]; this method
  /// only groups the rows by entity and applies its plan. `conflict_pending`,
  /// `blocked` and `resolved` rows are never read here, so nothing the user still
  /// has to review can be compacted away (AGENTS.md rule 4, Task 18 Phase 4).
  Future<int> compactPending() async {
    final pending = await getPending();
    final byEntity = <String, List<SyncQueueRow>>{};
    for (final row in pending) {
      byEntity
          .putIfAbsent('${row.entityType}\u0000${row.entityId}', () => [])
          .add(row);
    }

    var removed = 0;
    await db.transaction(() async {
      for (final group in byEntity.values) {
        group.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        final plan = planQueueCompaction(group);
        if (plan == null) continue;

        if (plan.dropAll) {
          for (final row in group) {
            removed += await delete(row.id);
          }
          continue;
        }

        for (final row in group) {
          if (row.id == plan.survivorId) continue;
          removed += await delete(row.id);
        }
        await (db.update(
          db.syncQueue,
        )..where((row) => row.id.equals(plan.survivorId!))).write(
          SyncQueueCompanion(
            operation: Value(plan.operation!),
            payload: Value(plan.payload!),
            changedFields: Value(plan.changedFields!),
          ),
        );
      }
    });
    return removed;
  }

  /// Inserts a queue entry. Returns the row id.
  Future<int> insert(SyncQueueCompanion row) =>
      db.into(db.syncQueue).insert(row);

  /// Updates the state and optional diagnostics of a queue entry.
  ///
  /// Only the mutable columns are touched; the row's payload and mutation
  /// identity are preserved. Returns the number of rows updated.
  Future<int> updateState(
    int id,
    String state, {
    String? lastError,
    int? retryCount,
    int? lastAttemptAt,
  }) async {
    final companion = SyncQueueCompanion(
      state: Value(state),
      lastError: lastError == null ? const Value.absent() : Value(lastError),
      retryCount: retryCount == null ? const Value.absent() : Value(retryCount),
      lastAttemptAt: lastAttemptAt == null
          ? const Value.absent()
          : Value(lastAttemptAt),
    );
    return (db.update(
      db.syncQueue,
    )..where((row) => row.id.equals(id))).write(companion);
  }

  /// Deletes a queue entry by id.
  Future<int> delete(int id) async =>
      (db.delete(db.syncQueue)..where((row) => row.id.equals(id))).go();
}
