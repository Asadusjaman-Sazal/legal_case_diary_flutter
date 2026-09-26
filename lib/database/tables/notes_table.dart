/// Notes table: free-form notes visible/editable to all firm members.
/// Implemented in Task 03 Phase 2.
library;

import 'package:drift/drift.dart';

/// A user or firm note.
@DataClassName('Note')
class Notes extends Table {
  /// UUID primary key.
  TextColumn get id => text()();

  /// Owner.
  TextColumn get userId => text()();

  /// Firm scope; null for individual lawyers.
  TextColumn get firmId => text().nullable()();

  /// Note title.
  TextColumn get title => text()();

  /// Note body.
  ///
  /// For a to-do note this mirrors the item texts, one per line, so the existing
  /// title+body search finds a to-do by what is on its list without parsing
  /// JSON. The checklist itself renders from [items].
  TextColumn get body => text()();

  /// To-do checklist as a JSON array of `{text, done}` objects, in display
  /// order. Null for a plain text note; an empty to-do stores `[]`, so its kind
  /// never changes just because it has nothing on it yet.
  TextColumn get items => text().nullable()();

  /// Pinned notes appear first.
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();

  /// Creation timestamp (epoch ms).
  IntColumn get createdAt => integer()();

  // Global sync columns.
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get lastModifiedBy => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
