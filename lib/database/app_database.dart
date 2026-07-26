/// Local encrypted Drift database definition.
/// Assembles all tables for Task 03.
library;

import 'package:drift/drift.dart';

import 'tables/case_history_table.dart';
import 'tables/cases_table.dart';
import 'tables/case_types_table.dart';
import 'tables/conflict_log_table.dart';
import 'tables/court_categories_table.dart';
import 'tables/courts_table.dart';
import 'tables/delete_requests_table.dart';
import 'tables/firm_members_table.dart';
import 'tables/firms_table.dart';
import 'tables/notes_table.dart';
import 'tables/on_behalfs_table.dart';
import 'tables/references_table.dart';
import 'tables/steps_table.dart';
import 'tables/sync_queue_table.dart';

part 'app_database.g.dart';

/// The main Drift database for the Legal Case Diary app.
@DriftDatabase(
  tables: [
    Cases,
    CaseHistory,
    CourtCategories,
    Courts,
    Steps,
    CaseTypes,
    OnBehalfs,
    Notes,
    CaseReferences,
    DeleteRequests,
    ConflictLog,
    Firms,
    FirmMembers,
    SyncQueue,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Creates the database using the provided [executor].
  AppDatabase(super.executor);

  /// Current schema version.
  @override
  int get schemaVersion => 1;
}
