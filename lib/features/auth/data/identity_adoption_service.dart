/// Adoption of placeholder-owned local data into the authenticated identity.
///
/// Part A had no accounts: every row this device wrote carries the stable
/// placeholder UUID in [LocalIdentityService] as its `user_id`/`last_modified_by`
/// (and the sync queue mirrors those values in its JSON payloads). The moment a
/// real account signs in, that ownership must become the authenticated
/// `auth.uid()` — **before** any authenticated repository writes, and **before**
/// the queue can be pushed, or the server would reject rows owned by a UUID it
/// has never seen.
///
/// Three rules shape this service:
///
/// * **One transaction.** Rows, queue payloads, base snapshots, notification
///   preferences and attribution either all move or none do.
/// * **Fail closed across accounts.** The device records the identity it belongs
///   to. If a *different* account signs in, nothing is rewritten and
///   [AuthFailureKind.accountMismatch] is raised: wiping or exporting for an
///   account switch is the logout flow's job, never adoption's.
/// * **Provenance is preserved separately.** Attribution is rewritten (the plan
///   is explicit about it), and what happened is recorded beside it in
///   `sync_metadata` — the placeholder id, the account, the timestamp and the
///   per-table counts — so the adoption stays auditable after the fact.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/services/local_identity_service.dart';
import '../../../database/app_database.dart';
import '../../../sync/sync_metadata_dao.dart';
import 'auth_repository.dart';

/// `sync_metadata` key holding the account this device's local data belongs to.
const String boundUserIdKey = 'auth.bound_user_id';

/// `sync_metadata` key holding the adoption audit record (JSON).
const String adoptionProvenanceKey = 'auth.adoption_provenance';

/// What one adoption attempt did.
class AdoptionOutcome {
  /// Creates an outcome.
  const AdoptionOutcome({
    required this.userId,
    this.placeholderUserId,
    this.rowsChanged = 0,
    this.queueEntriesChanged = 0,
    this.preferenceRowsChanged = 0,
    this.alreadyBound = false,
  });

  /// The authenticated account the data belongs to now.
  final String userId;

  /// The Part A placeholder identity the rows were moved from; null when this
  /// device never wrote anything before signing in.
  final String? placeholderUserId;

  /// Domain rows whose ownership or attribution moved.
  final int rowsChanged;

  /// Queue entries whose payload, base payload or pre-mutation snapshot moved.
  final int queueEntriesChanged;

  /// Per-user preference rows re-keyed (notification and general preferences).
  final int preferenceRowsChanged;

  /// True when the device was already bound to this same account.
  final bool alreadyBound;

  /// True when there was nothing to move and nothing to bind.
  bool get wasNoop => alreadyBound;
}

/// One table's adoption rule.
class _AdoptionTarget {
  const _AdoptionTarget({
    required this.table,
    required this.ownerColumn,
    this.firmColumn,
    this.auditColumns = const <String>[],
  });

  /// The Drift table, which supplies the SQL name and lets live queries refresh.
  final TableInfo table;

  /// Column identifying the row's owner (`user_id`, `requested_by`, …).
  final String ownerColumn;

  /// Column holding the firm scope, when the table has one.
  final String? firmColumn;

  /// Further attribution columns to move off the placeholder (`created_by`,
  /// `reviewed_by`, …). `last_modified_by` is always included.
  final List<String> auditColumns;
}

/// Moves placeholder-owned local data onto the authenticated identity.
class IdentityAdoptionService {
  /// Creates the service.
  IdentityAdoptionService(
    this._db,
    this._identity, {
    SyncMetadataDao? metadata,
  }) : _metadata = metadata ?? SyncMetadataDao(_db);

  final AppDatabase _db;
  final LocalIdentityService _identity;
  final SyncMetadataDao _metadata;

  /// The account this device's data currently belongs to, or null when unbound.
  Future<String?> boundUserId() => _metadata.getValue(boundUserIdKey);

  /// The tables whose rows follow the user, with the column that owns them.
  ///
  /// Orders match the schema: `notes`, `case_references` and the reference
  /// tables carry a nullable owner (a built-in row belongs to nobody, so it is
  /// never adopted); `delete_requests` and `conflict_log` name their columns
  /// differently, and `conflict_log` has no owner column at all — only
  /// attribution, since the log is already scoped to this device's own rows.
  List<_AdoptionTarget> get _targets => <_AdoptionTarget>[
    _AdoptionTarget(
      table: _db.cases,
      ownerColumn: 'user_id',
      firmColumn: 'firm_id',
    ),
    _AdoptionTarget(
      table: _db.caseHistory,
      ownerColumn: 'user_id',
      firmColumn: 'firm_id',
      auditColumns: const <String>['created_by'],
    ),
    _AdoptionTarget(
      table: _db.notes,
      ownerColumn: 'user_id',
      firmColumn: 'firm_id',
    ),
    _AdoptionTarget(
      table: _db.caseReferences,
      ownerColumn: 'user_id',
      firmColumn: 'firm_id',
    ),
    _AdoptionTarget(
      table: _db.courtCategories,
      ownerColumn: 'user_id',
      firmColumn: 'firm_id',
    ),
    _AdoptionTarget(
      table: _db.caseCategories,
      ownerColumn: 'user_id',
      firmColumn: 'firm_id',
    ),
    _AdoptionTarget(
      table: _db.courts,
      ownerColumn: 'user_id',
      firmColumn: 'firm_id',
    ),
    _AdoptionTarget(table: _db.steps, ownerColumn: 'user_id', firmColumn: 'firm_id'),
    _AdoptionTarget(
      table: _db.caseTypes,
      ownerColumn: 'user_id',
      firmColumn: 'firm_id',
    ),
    _AdoptionTarget(
      table: _db.onBehalfs,
      ownerColumn: 'user_id',
      firmColumn: 'firm_id',
    ),
    _AdoptionTarget(
      table: _db.deleteRequests,
      ownerColumn: 'requested_by',
      firmColumn: 'firm_id',
      auditColumns: const <String>['reviewed_by'],
    ),
    _AdoptionTarget(
      table: _db.conflictLog,
      ownerColumn: 'last_modified_by',
    ),
  ];

  /// Adopts this device's offline rows into [identity], atomically.
  ///
  /// [firmId] is the firm the account belongs to when the caller already knows
  /// it (the join-a-firm flow returns it). When it is null the rows keep their
  /// existing scope: an individual account has no firm, and the server
  /// re-scopes a firm member's rows on the push that follows a fresh
  /// `profiles` pull.
  ///
  /// Throws [AuthFailure] with [AuthFailureKind.accountMismatch] when the device
  /// is already bound to a different account, having written nothing.
  Future<AdoptionOutcome> adopt(AuthIdentity identity, {String? firmId}) {
    return _db.transaction(() async {
      final userId = identity.userId;
      final bound = await _metadata.getValue(boundUserIdKey);

      if (bound == userId) {
        return AdoptionOutcome(userId: userId, alreadyBound: true);
      }
      if (bound != null && bound != userId) {
        // Fail closed: never expose one account's diary to another. The
        // branched logout flow (premium/offline/free) owns wiping or exporting.
        throw const AuthFailure(AuthFailureKind.accountMismatch);
      }

      // `peekId` never mints an identity: an install that has not written
      // anything yet has no placeholder row to adopt, and creating one here
      // would only add a second UUID that must never reach the server.
      final placeholder = _identity.peekId();
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      var rowsChanged = 0;
      var queueEntries = 0;
      var preferenceRows = 0;
      final perTable = <String, int>{};

      if (placeholder != null && placeholder != userId) {
        for (final target in _targets) {
          final changed = await _adoptTable(
            target,
            placeholder: placeholder,
            userId: userId,
            firmId: firmId,
          );
          if (changed > 0) {
            perTable[target.table.actualTableName] = changed;
            rowsChanged += changed;
          }
        }

        queueEntries = await _adoptQueuePayloads(
          placeholder: placeholder,
          userId: userId,
          firmId: firmId,
        );
        preferenceRows = await _rekeyPreferences(
          placeholder: placeholder,
          userId: userId,
        );
      }

      // The pull-only caches belong to whoever was signed in when they were
      // pulled. A cached profile or firm name from an earlier session must never
      // be shown to the account signing in now; they are refilled from the
      // server by the profile refresh.
      await _db.delete(_db.profiles).go();
      await _db.delete(_db.firms).go();
      await _db.delete(_db.firmMembers).go();

      await _metadata.setValue(boundUserIdKey, userId, updatedAt: now);
      await _metadata.setValue(
        adoptionProvenanceKey,
        jsonEncode(<String, dynamic>{
          'placeholderUserId': placeholder,
          'adoptedUserId': userId,
          'firmId': firmId,
          'adoptedAt': now,
          'rows': perTable,
          'queueEntries': queueEntries,
          'preferenceRows': preferenceRows,
        }),
        updatedAt: now,
      );

      return AdoptionOutcome(
        userId: userId,
        placeholderUserId: placeholder,
        rowsChanged: rowsChanged,
        queueEntriesChanged: queueEntries,
        preferenceRowsChanged: preferenceRows,
      );
    });
  }

  /// Rewrites one table's owner, firm scope and attribution columns.
  ///
  /// Built from the generated table names and the schema's column names rather
  /// than by hand-assembling SQL per table, and every value is bound: the only
  /// interpolated text is a table or column name that comes from this file.
  Future<int> _adoptTable(
    _AdoptionTarget target, {
    required String placeholder,
    required String userId,
    String? firmId,
  }) async {
    final assignments = <String>['${target.ownerColumn} = ?'];
    final variables = <Variable>[Variable<String>(userId)];

    final firmColumn = target.firmColumn;
    if (firmColumn != null && firmId != null) {
      assignments.add('$firmColumn = ?');
      variables.add(Variable<String>(firmId));
    }

    // `last_modified_by` always follows the owner; the extra audit columns only
    // change where they still name the placeholder, so a row another account
    // touched keeps that account's attribution.
    assignments.add('last_modified_by = ?');
    variables.add(Variable<String>(userId));
    for (final column in target.auditColumns) {
      assignments.add(
        '$column = CASE WHEN $column = ? THEN ? ELSE $column END',
      );
      variables
        ..add(Variable<String>(placeholder))
        ..add(Variable<String>(userId));
    }

    variables.add(Variable<String>(placeholder));
    final sql =
        'UPDATE ${target.table.actualTableName} '
        'SET ${assignments.join(', ')} '
        'WHERE ${target.ownerColumn} = ?';

    return _db.customUpdate(
      sql,
      variables: variables,
      // Lets live queries watching this table refresh after adoption.
      updates: {target.table},
    );
  }

  /// Rewrites ownership inside the queue's JSON payloads.
  ///
  /// A queued mutation carries the row that was submitted, the base it was
  /// based on, and the snapshot used to roll a rejected permission-sensitive
  /// action back. All three would otherwise push placeholder ownership.
  Future<int> _adoptQueuePayloads({
    required String placeholder,
    required String userId,
    String? firmId,
  }) async {
    final rows = await _db.select(_db.syncQueue).get();
    var changed = 0;

    for (final row in rows) {
      final payload = _rewritePayload(row.payload, placeholder, userId, firmId);
      final basePayload = _rewritePayload(
        row.basePayload,
        placeholder,
        userId,
        firmId,
      );
      final preMutationPayload = _rewritePayload(
        row.preMutationPayload,
        placeholder,
        userId,
        firmId,
      );

      if (payload == row.payload &&
          basePayload == row.basePayload &&
          preMutationPayload == row.preMutationPayload) {
        continue;
      }

      await (_db.update(_db.syncQueue)..where((r) => r.id.equals(row.id))).write(
        SyncQueueCompanion(
          payload: Value(payload),
          basePayload: Value(basePayload),
          preMutationPayload: Value(preMutationPayload),
        ),
      );
      changed++;
    }

    return changed;
  }

  /// Re-keys the per-user preference rows.
  ///
  /// Preferences follow the *person*, never the firm: a lawyer who joins a firm
  /// keeps their language, view, navigation and notification settings, and no
  /// preference is ever merged into firm-shared reference data.
  Future<int> _rekeyPreferences({
    required String placeholder,
    required String userId,
  }) async {
    var changed = 0;

    final prefs = await (_db.update(_db.userPreferences)
          ..where((t) => t.userId.equals(placeholder)))
        .write(UserPreferencesCompanion(userId: Value(userId)));
    changed += prefs;

    final notifications = await (_db.update(_db.caseNotificationPreferences)
          ..where((t) => t.userId.equals(placeholder)))
        .write(CaseNotificationPreferencesCompanion(userId: Value(userId)));
    changed += notifications;

    return changed;
  }

  /// Replaces placeholder ownership inside one JSON payload.
  ///
  /// Only values that name the placeholder change: a foreign key to a case
  /// another device created, or a firm id, is left exactly as submitted.
  static String _rewritePayload(
    String payload,
    String placeholder,
    String userId,
    String? firmId,
  ) {
    Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException {
      // A payload that is not JSON is not ours to touch.
      return payload;
    }
    if (decoded is! Map<String, dynamic>) return payload;
    final map = decoded;

    var mutated = false;
    void swap(String key, String? replacement) {
      if (replacement == null) return;
      if (map[key] == placeholder) {
        map[key] = replacement;
        mutated = true;
      }
    }

    swap('user_id', userId);
    swap('last_modified_by', userId);
    swap('created_by', userId);
    swap('requested_by', userId);
    swap('reviewed_by', userId);
    swap('firm_id', firmId);

    return mutated ? jsonEncode(map) : payload;
  }
}
