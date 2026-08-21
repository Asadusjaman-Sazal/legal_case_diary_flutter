/// Local encrypted Drift database definition.
/// Assembles all tables for Task 03 and provides sync-aware query helpers.
library;

import 'package:drift/drift.dart';

import 'tables/case_history_table.dart';
import 'tables/case_categories_table.dart';
import 'tables/cases_table.dart';
import 'tables/case_types_table.dart';
import 'tables/conflict_log_table.dart';
import 'tables/court_categories_table.dart';
import 'tables/courts_table.dart';
import 'tables/delete_requests_table.dart';
import 'tables/case_notification_preferences_table.dart';
import 'tables/firm_members_table.dart';
import 'tables/firms_table.dart';
import 'tables/notes_table.dart';
import 'tables/profiles_table.dart';
import 'tables/seed_migrations_table.dart';
import 'tables/sync_metadata_table.dart';
import 'tables/user_preferences_table.dart';
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
    CaseCategories,
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
    Profiles,
    SyncQueue,
    SyncMetadata,
    SeedMigrations,
    UserPreferences,
    CaseNotificationPreferences,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Creates the database using the provided [executor].
  AppDatabase(super.executor);

  /// Current schema version.
  @override
  int get schemaVersion => 4;

  /// Migration strategy for the local Drift database.
  ///
  /// [onCreate] creates all tables at schema version 4. [onUpgrade] migrates
  /// from v1→v2 by adding `order_index` columns, then v2→v3 by replacing
  /// the two legacy party phone columns with the single `party_phone` column,
  /// then v3→v4 by adding case categories, case-type links, and court order.
  /// [beforeOpen] enables foreign-key enforcement.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(caseTypes, caseTypes.orderIndex);
        await m.addColumn(onBehalfs, onBehalfs.orderIndex);
      }
      if (from < 3) {
        await customStatement('ALTER TABLE cases ADD COLUMN party_phone TEXT');
        await customStatement(
          'UPDATE cases SET party_phone = COALESCE('
          'petitioner_phone, respondent_phone)',
        );
        await customStatement('ALTER TABLE cases DROP COLUMN petitioner_phone');
        await customStatement('ALTER TABLE cases DROP COLUMN respondent_phone');
      }
      if (from < 4) {
        await m.createTable(caseCategories);
        await m.addColumn(caseTypes, caseTypes.caseCategoryId);
        await m.addColumn(courts, courts.orderIndex);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
    },
  );

  // --------------------------------------------------------------------------
  // Standing query helpers — all UI queries should filter `is_deleted = 0`.
  // --------------------------------------------------------------------------

  /// Active (non-deleted) cases.
  Selectable<Case> get activeCases =>
      select(cases)..where((row) => row.isDeleted.equals(false));

  /// Active (non-deleted) case history entries.
  Selectable<CaseHistoryRow> get activeCaseHistory =>
      select(caseHistory)..where((row) => row.isDeleted.equals(false));

  /// Active (non-deleted) courts.
  Selectable<Court> get activeCourts =>
      select(courts)..where((row) => row.isDeleted.equals(false));

  /// Active (non-deleted) case categories.
  Selectable<CaseCategory> get activeCaseCategories =>
      select(caseCategories)..where((row) => row.isDeleted.equals(false));

  /// Active (non-deleted) steps.
  Selectable<Step> get activeSteps =>
      select(steps)..where((row) => row.isDeleted.equals(false));

  /// Active (non-deleted) case types.
  Selectable<CaseType> get activeCaseTypes =>
      select(caseTypes)..where((row) => row.isDeleted.equals(false));

  /// Active (non-deleted) on-behalf options.
  Selectable<OnBehalf> get activeOnBehalfs =>
      select(onBehalfs)..where((row) => row.isDeleted.equals(false));

  /// Active (non-deleted) notes.
  Selectable<Note> get activeNotes =>
      select(notes)..where((row) => row.isDeleted.equals(false));

  /// Active (non-deleted) case references.
  Selectable<CaseReference> get activeCaseReferences =>
      select(caseReferences)..where((row) => row.isDeleted.equals(false));

  /// Active (non-deleted) delete requests.
  Selectable<DeleteRequest> get activeDeleteRequests =>
      select(deleteRequests)..where((row) => row.isDeleted.equals(false));

  /// Active (non-deleted) court categories.
  Selectable<CourtCategory> get activeCourtCategories =>
      select(courtCategories)..where((row) => row.isDeleted.equals(false));

  /// Active (non-deleted) conflict log entries.
  Selectable<ConflictLogRow> get activeConflictLog =>
      select(conflictLog)..where((row) => row.isDeleted.equals(false));

  // --------------------------------------------------------------------------
  // Purge policy stub (full implementation in Part B).
  // --------------------------------------------------------------------------

  /// Purges soft-deleted rows older than 90 days **only when** they have been
  /// successfully synced (`synced_at` is not null and `synced_at >= updated_at`).
  ///
  /// In Part A nothing ever syncs, so the guard below ensures unsynced
  /// tombstones are never purged. Hard deletes are intentionally avoided.
  Future<void> purgeSoftDeletedRecords() async {
    const retentionDays = 90;
    final cutoff = DateTime.now().toUtc().subtract(
      const Duration(days: retentionDays),
    );
    final cutoffMs = cutoff.millisecondsSinceEpoch;

    // Guard: only purge rows that were soft-deleted after a successful sync.
    // In Part A, synced_at is always null, so the WHERE below makes this a
    // no-op while keeping the correct future behavior encoded in code.
    await transaction(() async {
      await _purgeSyncableTable('cases', cutoffMs);
      await _purgeSyncableTable('case_history', cutoffMs);
      await _purgeSyncableTable('court_categories', cutoffMs);
      await _purgeSyncableTable('case_categories', cutoffMs);
      await _purgeSyncableTable('courts', cutoffMs);
      await _purgeSyncableTable('steps', cutoffMs);
      await _purgeSyncableTable('case_types', cutoffMs);
      await _purgeSyncableTable('on_behalfs', cutoffMs);
      await _purgeSyncableTable('notes', cutoffMs);
      await _purgeSyncableTable('case_references', cutoffMs);
      await _purgeSyncableTable('delete_requests', cutoffMs);
      await _purgeSyncableTable('conflict_log', cutoffMs);
    });
  }

  /// Deletes soft-deleted rows from [tableName] that are older than the cutoff
  /// and have been successfully synced. Uses raw SQL so the column-to-column
  /// comparison (`synced_at >= updated_at`) is expressed directly.
  Future<void> _purgeSyncableTable(String tableName, int cutoffMs) async {
    await customStatement(
      'DELETE FROM "$tableName" WHERE is_deleted = 1 '
      'AND updated_at < ? AND synced_at IS NOT NULL AND synced_at >= updated_at',
      [cutoffMs],
    );
  }
}
