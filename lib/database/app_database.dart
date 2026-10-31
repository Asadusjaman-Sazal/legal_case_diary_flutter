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
import 'tables/laws_table.dart';
import 'tables/notes_table.dart';
import 'tables/profiles_table.dart';
import 'tables/seed_migrations_table.dart';
import 'tables/shared_case_reference_pins_table.dart';
import 'tables/shared_case_references_table.dart';
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
    Laws,
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
    SharedCaseReferences,
    SharedCaseReferencePins,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Creates the database using the provided [executor].
  AppDatabase(super.executor);

  /// Current schema version.
  @override
  int get schemaVersion => 19;

  /// Migration strategy for the local Drift database.
  ///
  /// [onCreate] creates all tables at schema version 6. [onUpgrade] migrates
  /// from v1→v2 by adding `order_index` columns, then v2→v3 by replacing
  /// the two legacy party phone columns with the single `party_phone` column,
  /// then v3→v4 by adding case categories, case-type links, and court order,
  /// then v4→v5 by adding the AD/HCD case fields and result, then v5→v6 by
  /// adding the AD/HCD result snapshot to `case_history`, then v6→v7 by adding
  /// the division/district scope for user-created lower-court categories, then
  /// v7→v8 by adding the per-case notification time to
  /// `case_notification_preferences`, then v8→v9 by adding the to-do checklist
  /// to `notes`, then v9→v10 by adding `conflict_log.mergeable_conflict`, then
  /// v10→v11 by adding the admin payment-alert toggle, then v11→v12 by adding
  /// the stored subscription tier (`tier`, `tier_pending`, `tier_pending_from`)
  /// to the cached `profiles` and `firms` rows, then v12→v13 by adding the
  /// chamber logo's server-stamped path and version to the cached `firms` row,
  /// then v13→v14 by adding the profile picture's same two fields to `profiles`,
  /// then v14→v15 by adding the requester's display name to `delete_requests`,
  /// then v15→v16 by adding the law-name list (`laws`), then v16→v17 by adding
  /// the law category that list groups its names under, then v17→v18 by adding
  /// the server-wide references cache and its per-device pin table, then
  /// v18→v19 by adding the case note and tags to both reference libraries.
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
      if (from < 5) {
        await m.addColumn(cases, cases.caseCategoryId);
        await m.addColumn(cases, cases.honorableJudges);
        await m.addColumn(cases, cases.tenderNumber);
        await m.addColumn(cases, cases.previousCourtCase);
        await m.addColumn(cases, cases.districtOfOrigin);
        await m.addColumn(cases, cases.result);
      }
      if (from < 6) {
        await m.addColumn(caseHistory, caseHistory.result);
      }
      if (from < 7) {
        await m.addColumn(courtCategories, courtCategories.division);
        await m.addColumn(courtCategories, courtCategories.district);
      }
      if (from < 8) {
        await m.addColumn(
          caseNotificationPreferences,
          caseNotificationPreferences.timeMinutes,
        );
      }
      if (from < 9) {
        await m.addColumn(notes, notes.items);
      }
      if (from < 10) {
        await m.addColumn(conflictLog, conflictLog.mergeableConflict);
      }
      if (from < 11) {
        // The admin payment-alert toggle (Settings → Notifications). Its column
        // default is true, so every existing row reads as on, which is the
        // default the server column carries for the same reason.
        await m.addColumn(
          userPreferences,
          userPreferences.paymentAlertsEnabled,
        );
      }
      if (from < 12) {
        // The stored subscription tier (Task 21's ten-plan ladder). Additive and
        // defaulted: each column is added with `free`/null, so no existing row
        // is rewritten and no case data is touched — the upgrade only widens the
        // two cache tables. The next profile pull fills the real values.
        await m.addColumn(profiles, profiles.tier);
        await m.addColumn(profiles, profiles.tierPending);
        await m.addColumn(profiles, profiles.tierPendingFrom);
        await m.addColumn(firms, firms.tier);
        await m.addColumn(firms, firms.tierPending);
        await m.addColumn(firms, firms.tierPendingFrom);
      }
      if (from < 13) {
        // The chamber logo's cache fields (0.0.629). Additive and defaulted:
        // an older row reads "no logo, version 0", and the next profile pull
        // fills the real values.
        await m.addColumn(firms, firms.logoPath);
        await m.addColumn(firms, firms.logoVersion);
      }
      if (from < 14) {
        // The profile picture's cache fields (0.0.630). Additive and defaulted:
        // an older row reads "no remote picture, version 0", and the next pull
        // fills the real values.
        await m.addColumn(profiles, profiles.avatarPath);
        await m.addColumn(profiles, profiles.avatarVersion);
      }
      if (from < 15) {
        // The requester's name on a delete request. Additive and nullable: an
        // older request keeps a null here and the review screen falls back to
        // the profile lookup it used before, and the next pull of that row
        // brings the name the server derived.
        await m.addColumn(deleteRequests, deleteRequests.requesterName);
      }
      if (from < 16) {
        // The law-name list for case references. A brand-new table, so the
        // upgrade only adds it; `seed_v3` then fills the built-in names, so an
        // existing install comes out of the upgrade with the same list a fresh
        // install is created with.
        await m.createTable(laws);
      } else if (from < 17) {
        // A v16 install created `laws` before the list grouped its names under
        // a category. Additive and defaulted, so the column costs nothing and
        // `seed_v3` fills the category on the next open.
        await m.addColumn(laws, laws.category);
      }
      if (from < 18) {
        // The server-wide citation library and this device's pins on it. Both
        // are new tables, so the upgrade only creates them and no existing row
        // is touched; the next delta pull fills the cache.
        await m.createTable(sharedCaseReferences);
        await m.createTable(sharedCaseReferencePins);
      }
      if (from < 19) {
        // The Case Note and Tags on both reference libraries. Additive and
        // nullable, so every existing citation keeps reading exactly as it was
        // written; the next server pull fills the official cache's values.
        await m.addColumn(caseReferences, caseReferences.caseNote);
        await m.addColumn(caseReferences, caseReferences.tags);
        await m.addColumn(sharedCaseReferences, sharedCaseReferences.caseNote);
        await m.addColumn(sharedCaseReferences, sharedCaseReferences.tags);
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

  /// Active (non-deleted) law names.
  Selectable<Law> get activeLaws =>
      select(laws)..where((row) => row.isDeleted.equals(false));

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

  /// Live (non-deleted) official case references.
  Selectable<SharedCaseReference> get activeSharedCaseReferences =>
      select(sharedCaseReferences)..where((row) => row.isDeleted.equals(false));

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
      await _purgeSyncableTable('laws', cutoffMs);
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
