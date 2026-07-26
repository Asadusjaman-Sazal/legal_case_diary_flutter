/// Steps table: procedural steps scoped by court category.
/// Implemented in Task 03 Phase 2.
library;

import 'package:drift/drift.dart';

import 'court_categories_table.dart';

/// A procedural step such as "Hearing" or "Judgment".
@DataClassName('Step')
class Steps extends Table {
  /// UUID primary key.
  TextColumn get id => text()();

  /// Court category this step belongs to.
  TextColumn get courtCategoryId => text().references(CourtCategories, #id)();

  /// Display name of the step.
  TextColumn get stepName => text()();

  /// Display order within the category.
  IntColumn get orderIndex => integer()();

  /// True if added by the user; false if pre-seeded.
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();

  /// Whether the user/firm has modified a pre-seeded row.
  BoolColumn get isUserModified => boolean().withDefault(const Constant(false))();

  /// Creator of custom step; null for pre-seeded.
  TextColumn get userId => text().nullable()();

  /// Firm scope; null for individuals & pre-seeded rows.
  TextColumn get firmId => text().nullable()();

  // Global sync columns.
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get lastModifiedBy => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
