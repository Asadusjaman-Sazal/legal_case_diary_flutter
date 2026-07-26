/// Conflict log table: rejected mutation + authoritative-row conflict log.
/// Mirrored to Supabase in Part B (Task 19).
/// Implemented in Task 03 Phase 2.
library;

import 'package:drift/drift.dart';

/// A rejected mutation conflict record.
@DataClassName('ConflictLogRow')
class ConflictLog extends Table {
  /// UUID primary key shared with the Supabase mirror.
  TextColumn get id => text()();

  /// Stable ID of the rejected logical mutation.
  TextColumn get mutationId => text()();

  /// Entity type (`case`, `case_history`, `note`, `reference`).
  TextColumn get entityType => text()();

  /// UUID of the conflicted record.
  TextColumn get entityId => text()();

  /// Server version the attempted mutation was based on.
  IntColumn get baseVersion => integer()();

  /// JSON snapshot of the common base.
  TextColumn get basePayload => text()();

  /// JSON payload the client attempted to apply.
  TextColumn get submittedPayload => text()();

  /// JSON array of intentionally changed fields.
  TextColumn get changedFields => text()();

  /// Authoritative server version returned by push_changes.
  IntColumn get serverVersion => integer()();

  /// Authoritative row returned by push_changes.
  TextColumn get serverPayload => text()();

  /// `unresolved`, `rebased`, `user_resolved`, or `discarded`.
  TextColumn get resolutionState => text()();

  /// Conflict timestamp (epoch ms).
  IntColumn get conflictAt => integer()();

  /// Resolution timestamp (epoch ms); null while unresolved.
  IntColumn get resolvedAt => integer().nullable()();

  /// UI acknowledgement only.
  BoolColumn get isDismissed => boolean().withDefault(const Constant(false))();

  // Global sync columns.
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get lastModifiedBy => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
