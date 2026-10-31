/// Case references table: precedents and citations library.
/// Implemented in Task 03 Phase 2.
library;

import 'package:drift/drift.dart';

/// A precedent, citation, or case reference entry.
@DataClassName('CaseReference')
class CaseReferences extends Table {
  /// UUID primary key.
  TextColumn get id => text()();

  /// Owner.
  TextColumn get userId => text()();

  /// Firm scope; null for individual lawyers.
  TextColumn get firmId => text().nullable()();

  /// Reference and page number.
  TextColumn get referenceAndPageNo => text()();

  /// The parties to the case, e.g. `State vs. Md. Karim`.
  TextColumn get parties => text().nullable()();

  /// Statute or act name.
  TextColumn get statute => text().nullable()();

  /// Section or article number.
  TextColumn get sectionOrArticle => text().nullable()();

  /// Title and description.
  TextColumn get titleAndDescription => text().nullable()();

  /// Additional comments or notes.
  TextColumn get commentsNotes => text().nullable()();

  /// A note on the case itself, beside the case summary.
  TextColumn get caseNote => text().nullable()();

  /// Comma-separated tags used to group and find citations.
  TextColumn get tags => text().nullable()();

  /// Pinned references appear first.
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
