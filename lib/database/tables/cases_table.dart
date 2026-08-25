/// Cases table: stores case information (parties, dates, court, status).
/// Implemented in Task 03 Phase 2.
library;

import 'package:drift/drift.dart';

import 'case_categories_table.dart';
import 'courts_table.dart';
import 'on_behalfs_table.dart';

/// A single legal case tracked by the lawyer/firm.
@DataClassName('Case')
class Cases extends Table {
  /// UUID primary key.
  TextColumn get id => text()();

  /// Owner (lawyer) who created the case.
  TextColumn get userId => text()();

  /// Firm scope; null for individual lawyers.
  TextColumn get firmId => text().nullable()();

  /// Court this case belongs to.
  TextColumn get courtId => text().references(Courts, #id)();

  /// Case type (e.g. "Criminal", "Civil").
  TextColumn get caseType => text()();

  /// AD/HCD case-category scope for the selected case type.
  TextColumn get caseCategoryId =>
      text().nullable().references(CaseCategories, #id)();

  /// Single text entity such as "110/2021".
  TextColumn get caseNumber => text()();

  /// AD/HCD judicial bench or judge names.
  TextColumn get honorableJudges => text().nullable()();

  /// Optional tender number; stored as text to preserve leading zeroes.
  TextColumn get tenderNumber => text().nullable()();

  /// Case number from the previous court.
  TextColumn get previousCourtCase => text().nullable()();

  /// District where the case originated.
  TextColumn get districtOfOrigin => text().nullable()();

  /// Petitioner party label.
  TextColumn get petitioner => text()();

  /// Petitioner's lead counsel.
  TextColumn get petitionerLeadCounsel => text().nullable()();

  /// Respondent party label.
  TextColumn get respondent => text()();

  /// Respondent's lead counsel.
  TextColumn get respondentLeadCounsel => text().nullable()();

  /// Client representation role (e.g. Plaintiff, Defendant).
  TextColumn get onBehalfId => text().references(OnBehalfs, #id)();

  /// Complete party phone number, stored in international format.
  TextColumn get partyPhone => text().nullable()();

  /// Case description or specific legal sections.
  TextColumn get caseTitleAndSection => text().nullable()();

  /// Case summary/remarks.
  TextColumn get caseRemarks => text().nullable()();

  /// Next hearing date (epoch ms).
  IntColumn get nextDate => integer().nullable()();

  /// Most recent court step, denormalized for fast list display.
  TextColumn get lastStep => text().nullable()();

  /// Notes or results from the last date.
  TextColumn get notesResults => text().nullable()();

  /// Separate result text used for AD/HCD disposal detection.
  TextColumn get result => text().nullable()();

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
