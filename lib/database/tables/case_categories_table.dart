/// Case categories nested under a canonical court category.
///
/// Case categories are editable push/pull reference data for AD/HCD. Their
/// case types reference these rows through [case_category_id]; lower-court
/// case types remain scoped directly by their court category.
library;

import 'package:drift/drift.dart';

import 'court_categories_table.dart';

/// A case category such as Civil Cases or Writ Cases.
@DataClassName('CaseCategory')
class CaseCategories extends Table {
  /// Stable deterministic seed ID or UUID for a custom row.
  TextColumn get id => text()();

  /// Canonical court category that owns this case category.
  TextColumn get courtCategoryId => text().references(CourtCategories, #id)();

  /// English seed/custom display name.
  TextColumn get name => text()();

  /// Display order within the court category.
  IntColumn get orderIndex => integer()();

  /// Built-in versus user-created case category.
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();

  /// Whether the user/firm has modified a built-in row.
  BoolColumn get isUserModified =>
      boolean().withDefault(const Constant(false))();

  /// Creator for custom individual categories; null for built-ins.
  TextColumn get userId => text().nullable()();

  /// Firm scope for custom firm categories; null for built-ins/individuals.
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
