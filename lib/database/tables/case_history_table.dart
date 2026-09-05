/// Case history table: immutable procedural history for each case.
/// Implemented in Task 03 Phase 2.
library;

import 'package:drift/drift.dart';

import 'cases_table.dart';

/// Immutable history event created when an accepted mutation changes a case.
@DataClassName('CaseHistoryRow')
class CaseHistory extends Table {
  /// UUID primary key.
  TextColumn get id => text()();

  /// Parent case.
  TextColumn get caseId => text().references(Cases, #id)();

  /// Denormalized owner for Realtime/RLS scoping.
  TextColumn get userId => text()();

  /// Denormalized firm scope; null for individuals.
  TextColumn get firmId => text().nullable()();

  /// Date of the hearing (epoch ms).
  IntColumn get hearingDate => integer()();

  /// Court procedure step at this hearing.
  TextColumn get lastStep => text().nullable()();

  /// Next date set at this hearing (epoch ms).
  IntColumn get nextDate => integer().nullable()();

  /// What happened at the hearing.
  TextColumn get noteResult => text().nullable()();

  /// AD/HCD result for this hearing (null for lower courts, which use steps).
  /// Snapshot of the case's `result` at the time the entry was frozen.
  TextColumn get result => text().nullable()();

  /// UUID of the user who logged this entry.
  TextColumn get createdBy => text()();

  /// Unique idempotency key of the accepted mutation that created this row.
  TextColumn get sourceMutationId => text().unique()();

  /// Case version the accepted mutation was based on.
  IntColumn get baseCaseVersion => integer()();

  /// Server-assigned case version produced by the accepted mutation.
  IntColumn get resultCaseVersion => integer()();

  // Global sync columns.
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get lastModifiedBy => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
