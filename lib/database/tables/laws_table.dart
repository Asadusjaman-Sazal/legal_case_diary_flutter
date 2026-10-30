/// Laws table: the editable list of Act/Statute names a case reference cites.
///
/// Table class (AGENTS.md rule 4): **push/pull domain** — editable and
/// firm-shared in firm mode, exactly like `courts`. The app ships a default
/// list under stable seed ids, and a user (or their chamber) may add a name of
/// their own; a built-in row may be renamed but never deleted.
///
/// This table holds the *names* only. A case reference keeps its statute as
/// text, so an existing row still shows what it always showed even if the law
/// list changes — the list supplies the dropdown's options and the display
/// order, nothing else.
library;

import 'package:drift/drift.dart';

/// One law (Act, Ordinance or Statute) a case reference may cite.
@DataClassName('Law')
class Laws extends Table {
  /// Stable seed id for a built-in law, or a UUID for a user-added one.
  TextColumn get id => text()();

  /// Display name, e.g. `The Penal Code, 1860`.
  TextColumn get name => text()();

  /// The law category this name is listed under, as a stable ID from
  /// `seedLawCategories` (`criminal_law`, `family_personal_law`, …).
  ///
  /// A heading rather than a row: the seven categories are code, and the
  /// heading's label resolves through the matching `lawCategory_*` ARB key, so
  /// the list groups the same way in the app whatever the language. A blank
  /// value is a row an older build wrote before categories existed; it lists
  /// under Other until a seed migration fills it.
  TextColumn get category => text().withDefault(const Constant(''))();

  /// Display order; seeded laws keep their seed order, a new name is appended.
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();

  /// True if added by the user/firm; false if pre-seeded.
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();

  /// Whether the user/firm has renamed a pre-seeded law.
  BoolColumn get isUserModified =>
      boolean().withDefault(const Constant(false))();

  /// Creator of a custom law; null for pre-seeded rows.
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
