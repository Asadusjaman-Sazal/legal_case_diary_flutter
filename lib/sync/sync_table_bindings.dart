/// Local write helpers for one synced entity type.
///
/// The push worker and the delta pull both need to write a specific Drift table
/// without knowing its type at compile time (the entity arrives as a string).
/// Each [SyncTableBinding] closes over the generated Drift table and data class
/// for one entity, so the generic caller stays a single map lookup and there is
/// no per-call `switch` scattered through the sync code.
library;

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'entity_tables.dart';

/// Mark a local row as confirmed by the server.
typedef MarkSynced =
    Future<void> Function(
      AppDatabase db,
      String id,
      int? version,
      int syncedAt,
    );

/// Upsert an authoritative server row (snake_case keys) into the local table.
typedef ApplyServerRow =
    Future<void> Function(AppDatabase db, Map<String, dynamic> serverRow);

/// Remove a local row by id.
///
/// Used by Sync Status Discard for the one case where a record should genuinely
/// disappear locally: the server has been asked and has no such row, so the
/// local copy was provisional and never existed anywhere else (Task 19 Phase 4).
typedef DeleteLocalRow = Future<void> Function(AppDatabase db, String id);

/// The local read/write pair for one entity type.
class SyncTableBinding {
  /// Creates a binding for [entityType] / [tableName].
  const SyncTableBinding({
    required this.entityType,
    required this.tableName,
    required this.markSynced,
    required this.applyServerRow,
    required this.deleteLocal,
  });

  /// The queue's singular entity type.
  final String entityType;

  /// The table the entity maps to.
  final String tableName;

  /// Sets `version` and `synced_at` on a local row after an accepted push.
  final MarkSynced markSynced;

  /// Upserts a pulled/returned authoritative row into the local table.
  final ApplyServerRow applyServerRow;

  /// Deletes a local row by id (Sync Status Discard of a provisional record).
  final DeleteLocalRow deleteLocal;
}

/// Every binding, keyed by entity type.
final Map<String, SyncTableBinding>
syncTableBindings = <String, SyncTableBinding>{
  'case': SyncTableBinding(
    entityType: 'case',
    tableName: 'cases',
    deleteLocal: (db, id) =>
        (db.delete(db.cases)..where((row) => row.id.equals(id))).go(),
    markSynced: (db, id, version, syncedAt) =>
        (db.update(db.cases)..where((row) => row.id.equals(id))).write(
          CasesCompanion(version: Value(version), syncedAt: Value(syncedAt)),
        ),
    applyServerRow: (db, row) => db
        .into(db.cases)
        .insertOnConflictUpdate(Case.fromJson(_camel(row)).toCompanion(false)),
  ),
  'case_history': SyncTableBinding(
    entityType: 'case_history',
    tableName: 'case_history',
    deleteLocal: (db, id) =>
        (db.delete(db.caseHistory)..where((row) => row.id.equals(id))).go(),
    markSynced: (db, id, version, syncedAt) =>
        (db.update(db.caseHistory)..where((row) => row.id.equals(id))).write(
          CaseHistoryCompanion(
            version: Value(version),
            syncedAt: Value(syncedAt),
          ),
        ),
    applyServerRow: (db, row) => db
        .into(db.caseHistory)
        .insertOnConflictUpdate(
          CaseHistoryRow.fromJson(_camel(row)).toCompanion(false),
        ),
  ),
  'note': SyncTableBinding(
    entityType: 'note',
    tableName: 'notes',
    deleteLocal: (db, id) =>
        (db.delete(db.notes)..where((row) => row.id.equals(id))).go(),
    markSynced: (db, id, version, syncedAt) =>
        (db.update(db.notes)..where((row) => row.id.equals(id))).write(
          NotesCompanion(version: Value(version), syncedAt: Value(syncedAt)),
        ),
    applyServerRow: (db, row) => db
        .into(db.notes)
        .insertOnConflictUpdate(Note.fromJson(_camel(row)).toCompanion(false)),
  ),
  'reference': SyncTableBinding(
    entityType: 'reference',
    tableName: 'case_references',
    deleteLocal: (db, id) =>
        (db.delete(db.caseReferences)..where((row) => row.id.equals(id))).go(),
    markSynced: (db, id, version, syncedAt) =>
        (db.update(db.caseReferences)..where((row) => row.id.equals(id))).write(
          CaseReferencesCompanion(
            version: Value(version),
            syncedAt: Value(syncedAt),
          ),
        ),
    applyServerRow: (db, row) => db
        .into(db.caseReferences)
        .insertOnConflictUpdate(
          CaseReference.fromJson(_camel(row)).toCompanion(false),
        ),
  ),
  'court_category': SyncTableBinding(
    entityType: 'court_category',
    tableName: 'court_categories',
    deleteLocal: (db, id) =>
        (db.delete(db.courtCategories)..where((row) => row.id.equals(id))).go(),
    markSynced: (db, id, version, syncedAt) =>
        (db.update(
          db.courtCategories,
        )..where((row) => row.id.equals(id))).write(
          CourtCategoriesCompanion(
            version: Value(version),
            syncedAt: Value(syncedAt),
          ),
        ),
    applyServerRow: (db, row) => db
        .into(db.courtCategories)
        .insertOnConflictUpdate(
          CourtCategory.fromJson(_camel(row)).toCompanion(false),
        ),
  ),
  'case_category': SyncTableBinding(
    entityType: 'case_category',
    tableName: 'case_categories',
    deleteLocal: (db, id) =>
        (db.delete(db.caseCategories)..where((row) => row.id.equals(id))).go(),
    markSynced: (db, id, version, syncedAt) =>
        (db.update(db.caseCategories)..where((row) => row.id.equals(id))).write(
          CaseCategoriesCompanion(
            version: Value(version),
            syncedAt: Value(syncedAt),
          ),
        ),
    applyServerRow: (db, row) => db
        .into(db.caseCategories)
        .insertOnConflictUpdate(
          CaseCategory.fromJson(_camel(row)).toCompanion(false),
        ),
  ),
  'court': SyncTableBinding(
    entityType: 'court',
    tableName: 'courts',
    deleteLocal: (db, id) =>
        (db.delete(db.courts)..where((row) => row.id.equals(id))).go(),
    markSynced: (db, id, version, syncedAt) =>
        (db.update(db.courts)..where((row) => row.id.equals(id))).write(
          CourtsCompanion(version: Value(version), syncedAt: Value(syncedAt)),
        ),
    applyServerRow: (db, row) => db
        .into(db.courts)
        .insertOnConflictUpdate(Court.fromJson(_camel(row)).toCompanion(false)),
  ),
  'step': SyncTableBinding(
    entityType: 'step',
    tableName: 'steps',
    deleteLocal: (db, id) =>
        (db.delete(db.steps)..where((row) => row.id.equals(id))).go(),
    markSynced: (db, id, version, syncedAt) =>
        (db.update(db.steps)..where((row) => row.id.equals(id))).write(
          StepsCompanion(version: Value(version), syncedAt: Value(syncedAt)),
        ),
    applyServerRow: (db, row) => db
        .into(db.steps)
        .insertOnConflictUpdate(Step.fromJson(_camel(row)).toCompanion(false)),
  ),
  'case_type': SyncTableBinding(
    entityType: 'case_type',
    tableName: 'case_types',
    deleteLocal: (db, id) =>
        (db.delete(db.caseTypes)..where((row) => row.id.equals(id))).go(),
    markSynced: (db, id, version, syncedAt) =>
        (db.update(db.caseTypes)..where((row) => row.id.equals(id))).write(
          CaseTypesCompanion(
            version: Value(version),
            syncedAt: Value(syncedAt),
          ),
        ),
    applyServerRow: (db, row) => db
        .into(db.caseTypes)
        .insertOnConflictUpdate(
          CaseType.fromJson(_camel(row)).toCompanion(false),
        ),
  ),
  'on_behalf': SyncTableBinding(
    entityType: 'on_behalf',
    tableName: 'on_behalfs',
    deleteLocal: (db, id) =>
        (db.delete(db.onBehalfs)..where((row) => row.id.equals(id))).go(),
    markSynced: (db, id, version, syncedAt) =>
        (db.update(db.onBehalfs)..where((row) => row.id.equals(id))).write(
          OnBehalfsCompanion(
            version: Value(version),
            syncedAt: Value(syncedAt),
          ),
        ),
    applyServerRow: (db, row) => db
        .into(db.onBehalfs)
        .insertOnConflictUpdate(
          OnBehalf.fromJson(_camel(row)).toCompanion(false),
        ),
  ),
  'law': SyncTableBinding(
    entityType: 'law',
    tableName: 'laws',
    deleteLocal: (db, id) =>
        (db.delete(db.laws)..where((row) => row.id.equals(id))).go(),
    markSynced: (db, id, version, syncedAt) =>
        (db.update(db.laws)..where((row) => row.id.equals(id))).write(
          LawsCompanion(version: Value(version), syncedAt: Value(syncedAt)),
        ),
    applyServerRow: (db, row) => db
        .into(db.laws)
        .insertOnConflictUpdate(Law.fromJson(_camel(row)).toCompanion(false)),
  ),
  'delete_request': SyncTableBinding(
    entityType: 'delete_request',
    tableName: 'delete_requests',
    deleteLocal: (db, id) =>
        (db.delete(db.deleteRequests)..where((row) => row.id.equals(id))).go(),
    markSynced: (db, id, version, syncedAt) =>
        (db.update(db.deleteRequests)..where((row) => row.id.equals(id))).write(
          DeleteRequestsCompanion(
            version: Value(version),
            syncedAt: Value(syncedAt),
          ),
        ),
    applyServerRow: (db, row) => db
        .into(db.deleteRequests)
        .insertOnConflictUpdate(
          DeleteRequest.fromJson(_camel(row)).toCompanion(false),
        ),
  ),
  'conflict_log': SyncTableBinding(
    entityType: 'conflict_log',
    tableName: 'conflict_log',
    deleteLocal: (db, id) =>
        (db.delete(db.conflictLog)..where((row) => row.id.equals(id))).go(),
    markSynced: (db, id, version, syncedAt) =>
        (db.update(db.conflictLog)..where((row) => row.id.equals(id))).write(
          ConflictLogCompanion(
            version: Value(version),
            syncedAt: Value(syncedAt),
          ),
        ),
    applyServerRow: (db, row) => db
        .into(db.conflictLog)
        .insertOnConflictUpdate(
          ConflictLogRow.fromJson(_camelConflictLog(row)).toCompanion(false),
        ),
  ),
};

/// The binding for [entityType], or null for an entity outside the class.
SyncTableBinding? syncBindingFor(String entityType) =>
    syncTableBindings[entityType];

/// Snake -> camel, with `synced_at` stamped to now (a pulled row is by
/// definition server-confirmed) so the 90-day tombstone purge can run.
Map<String, dynamic> _camel(Map<String, dynamic> serverRow) {
  final camel = snakeToCamelMap(serverRow);
  camel['syncedAt'] = DateTime.now().toUtc().millisecondsSinceEpoch;
  return camel;
}

/// `conflict_log` is the one table whose client `created_at` differs from the
/// server's: the server column is a `timestamptz`, the local column epoch ms.
Map<String, dynamic> _camelConflictLog(Map<String, dynamic> serverRow) {
  final camel = _camel(serverRow);
  final createdAt = camel['createdAt'];
  if (createdAt is String) {
    camel['createdAt'] =
        DateTime.tryParse(createdAt)?.toUtc().millisecondsSinceEpoch ??
        camel['conflictAt'] ??
        DateTime.now().toUtc().millisecondsSinceEpoch;
  } else if (createdAt == null) {
    camel['createdAt'] =
        camel['conflictAt'] ?? DateTime.now().toUtc().millisecondsSinceEpoch;
  }
  return camel;
}
