/// Case types table: case types scoped by court and case category.
/// Implemented in Task 03 Phase 2.
library;

import 'package:drift/drift.dart';

import 'case_categories_table.dart';
import 'court_categories_table.dart';

/// A case type such as "Writ Petition" or "Criminal Case".
@DataClassName('CaseType')
class CaseTypes extends Table {
  /// UUID primary key.
  TextColumn get id => text()();

  /// Court category this case type belongs to.
  TextColumn get courtCategoryId => text().references(CourtCategories, #id)();

  /// Non-null only for AD/HCD types; lower-court types remain scoped by
  /// [courtCategoryId] alone.
  TextColumn get caseCategoryId =>
      text().nullable().references(CaseCategories, #id)();

  /// Display name of the case type.
  TextColumn get name => text()();

  /// Display order within the category.
  IntColumn get orderIndex => integer()();

  /// True if added by the user; false if pre-seeded.
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();

  /// Whether the user/firm has modified a pre-seeded row.
  BoolColumn get isUserModified =>
      boolean().withDefault(const Constant(false))();

  /// Creator of custom case type; null for pre-seeded.
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
