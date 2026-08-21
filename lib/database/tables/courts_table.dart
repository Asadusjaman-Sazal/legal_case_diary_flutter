/// Courts table: stores specific court names and their hierarchy.
/// Implemented in Task 03 Phase 2.
library;

import 'package:drift/drift.dart';

import 'court_categories_table.dart';

/// A specific court (e.g. "Chief Judicial Magistrate Court, Dhaka").
@DataClassName('Court')
class Courts extends Table {
  /// UUID primary key.
  TextColumn get id => text()();

  /// Court name (Bengali or English).
  TextColumn get courtName => text()();

  /// `higher_courts` or `lower_courts`.
  TextColumn get higherLowerCourts => text()();

  /// Bangladesh division; only for lower courts.
  TextColumn get division => text().nullable()();

  /// Bangladesh district; only for lower courts.
  TextColumn get district => text().nullable()();

  /// Required court category.
  TextColumn get courtCategoryId => text().references(CourtCategories, #id)();

  /// Display order from the canonical seed list.
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();

  /// True if added by the user; false if pre-seeded.
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();

  /// Whether the user/firm has modified a pre-seeded row.
  BoolColumn get isUserModified =>
      boolean().withDefault(const Constant(false))();

  /// Creator of custom court; null for pre-seeded.
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
