/// Court categories table: stable machine-keyed categories that scope courts,
/// steps, case types, and on-behalf options. Implemented in Task 03 Phase 2.
library;

import 'package:drift/drift.dart';

/// Court category row.
///
/// Pre-seeded stable IDs: appellate_division, high_court_division,
/// district_sessions_criminal, district_courts_civil,
/// chief_judicial_magistrate, chief_metropolitan_magistrate,
/// executive_magistrate, tribunals.
@DataClassName('CourtCategory')
class CourtCategories extends Table {
  /// Stable machine key (e.g. `appellate_division`).
  TextColumn get id => text()();

  /// Localization key resolved through app translations.
  TextColumn get nameKey => text()();

  /// `appellate`, `high_court`, or `lower`.
  TextColumn get courtLevel => text()();

  /// Canonical display order.
  IntColumn get orderIndex => integer()();

  /// Bangladesh division for user-created lower-court categories; null for
  /// built-in categories, which are global. A category added inside a district
  /// is scoped to that division + district only.
  TextColumn get division => text().nullable()();

  /// Bangladesh district for user-created lower-court categories; null for
  /// built-in categories. See [division].
  TextColumn get district => text().nullable()();

  /// Built-in vs user-created category.
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();

  /// Whether the user/firm has modified a pre-seeded row.
  BoolColumn get isUserModified => boolean().withDefault(const Constant(false))();

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
