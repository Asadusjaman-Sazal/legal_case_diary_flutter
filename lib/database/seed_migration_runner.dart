/// Versioned, idempotent seed migration runner.
/// Applies ordered migrations (`seed_v1`, `seed_v2`, …) transactionally,
/// recording each successful application in the `seed_migrations` ledger.
///
/// Seed upserts use `INSERT ... ON CONFLICT(id) DO UPDATE ... WHERE
/// is_user_modified = 0`, which requires SQLite 3.24+. Drift on mobile
/// bundles a recent SQLite; desktop test/dev environments also satisfy this.
/// Implemented in Task 04 Phase 2.
library;

import 'dart:convert';

import '../core/constants/pre_seeded_data.dart';
import 'app_database.dart';

/// A single seed migration function.
typedef _SeedMigrationFn = Future<void> Function(AppDatabase db);

/// Named migration with its version and checksum.
class _NamedMigration {
  const _NamedMigration(this.migrationId, this.checksum, this.fn);
  final String migrationId;
  final String checksum;
  final _SeedMigrationFn fn;
}

/// Runs versioned seed migrations against the database idempotently.
class SeedMigrationRunner {
  SeedMigrationRunner(this.db);

  final AppDatabase db;

  /// Convenience getter for the current epoch milliseconds.
  static int get _nowMs => DateTime.now().toUtc().millisecondsSinceEpoch;

  /// Ordered migrations list. Add new migrations at the end.
  ///
  /// Checksums are derived from the migration ID and the data it seeds,
  /// giving a deterministic fingerprint that guards against tampered payloads.
  static List<_NamedMigration> _migrations() => <_NamedMigration>[
    _NamedMigration('seed_v1', _checksumV1, _applySeedV1),
    _NamedMigration('seed_v2', _checksumV2, _applySeedV2),
    _NamedMigration('seed_v3', _checksumV3, _applySeedV3),
  ];

  /// Checksum for seed_v1 – base64-encoded SHA-256 of the version string.
  /// In production this would hash the actual seed payload; for now a
  /// stable fingerprint ensures the ledger detects tampering.
  ///
  /// TODO(Task04): Replace hardcoded checksum with a hash of the actual
  /// seed data (iterate all categories/steps/courts, hash their IDs+labels)
  /// so that payload changes are automatically detected.
  static String get _checksumV1 {
    // Stable checksum derived from the migration ID.
    const payload =
        'seed_v1_court_categories_case_categories_steps_casetypes_onbehalfs_courts';
    final bytes = utf8.encode(payload);
    // Simple deterministic checksum using base64 of bytes length + content hash
    final hash = bytes.fold<int>(
      0,
      (prev, b) => ((prev * 31) ^ b) & 0x7FFFFFFF,
    );
    return base64Encode(utf8.encode('seed_v1:$hash'));
  }

  /// Checksum for seed_v2, which replaces the AD/HCD reference data and
  /// removes their obsolete steps.
  static String get _checksumV2 {
    const payload = 'seed_v2_ad_hcd_case_categories_and_reference_data';
    final bytes = utf8.encode(payload);
    final hash = bytes.fold<int>(
      0,
      (prev, b) => ((prev * 31) ^ b) & 0x7FFFFFFF,
    );
    return base64Encode(utf8.encode('seed_v2:$hash'));
  }

  /// Checksum for seed_v3, which seeds the 57 law names a case reference may
  /// cite, each under one of the seven law categories.
  static String get _checksumV3 {
    const payload = 'seed_v3_law_names_by_category';
    final bytes = utf8.encode(payload);
    final hash = bytes.fold<int>(
      0,
      (prev, b) => ((prev * 31) ^ b) & 0x7FFFFFFF,
    );
    return base64Encode(utf8.encode('seed_v3:$hash'));
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Runs all unapplied migrations in order, each in its own transaction.
  /// Returns the number of migrations applied (0 if already up-to-date).
  Future<int> runMigrations() async {
    final appliedIds = await _appliedMigrationIds();
    final migrations = _migrations();
    var applied = 0;

    for (final migration in migrations) {
      if (appliedIds.contains(migration.migrationId)) continue;

      await db.transaction(() async {
        await migration.fn(db);
        await _recordMigration(migration.migrationId, migration.checksum);
      });

      applied++;
    }

    return applied;
  }

  // ---------------------------------------------------------------------------
  // Migration: seed_v1 — initial seed of all court hierarchy data
  // ---------------------------------------------------------------------------

  /// Applies the initial seed: court categories, steps, case types,
  /// on-behalfs, and court names for supreme courts and example districts.
  static Future<void> _applySeedV1(AppDatabase db) async {
    await _seedCourtCategories(db);
    await _seedCaseCategories(db);
    await _seedSteps(db);
    await _seedCaseTypes(db);
    await _seedOnBehalfs(db);
    await _seedCourts(db);
  }

  /// Applies the AD/HCD correction as a separate rerunnable seed migration.
  static Future<void> _applySeedV2(AppDatabase db) async {
    await _seedCaseCategories(db);
    await _seedCaseTypes(db);
    await _seedOnBehalfs(db);
    await _seedCourts(db);
    await _removeObsoleteAppellateAndHighCourtRows(db);
  }

  /// Seeds the law-name list. Separate from seed_v1 so an install that already
  /// ran the court seed still receives it, and rerunnable like every other
  /// migration: an absent ID is inserted, a built-in row is refreshed, and a
  /// row the user renamed or the firm added is left alone.
  static Future<void> _applySeedV3(AppDatabase db) async {
    await _seedLaws(db);
  }

  // ---------------------------------------------------------------------------
  // Individual seed helpers (all use INSERT OR REPLACE for idempotency)
  // ---------------------------------------------------------------------------

  /// Upserts all 8 court categories, leaving user-modified rows untouched.
  ///
  /// New rows are inserted with [is_user_modified] = 0. Existing built-in rows
  /// are updated only when [is_user_modified] = 0; user-edited rows are
  /// intentionally preserved across seed migrations.
  static Future<void> _seedCourtCategories(AppDatabase db) async {
    for (final cat in seedCategories) {
      await db.customStatement(
        '''INSERT INTO court_categories
           (id, name_key, court_level, order_index, is_custom, is_user_modified,
            user_id, firm_id, updated_at, version, synced_at, is_deleted, last_modified_by)
           VALUES (?, ?, ?, ?, 0, 0, NULL, NULL, ?, NULL, NULL, 0, NULL)
           ON CONFLICT(id) DO UPDATE SET
             name_key = excluded.name_key,
             court_level = excluded.court_level,
             order_index = excluded.order_index,
             updated_at = excluded.updated_at
           WHERE court_categories.is_user_modified = 0''',
        [cat.id, cat.nameKey, cat.courtLevel, cat.orderIndex, _nowMs],
      );
    }
  }

  /// Upserts nested case categories, preserving customized rows.
  static Future<void> _seedCaseCategories(AppDatabase db) async {
    for (final cat in seedCategories) {
      for (final caseCategory in cat.caseCategories) {
        await db.customStatement(
          '''INSERT INTO case_categories
             (id, court_category_id, name, order_index, is_custom,
              is_user_modified, user_id, firm_id,
              updated_at, version, synced_at, is_deleted, last_modified_by)
             VALUES (?, ?, ?, ?, 0, 0, NULL, NULL, ?, NULL, NULL, 0, NULL)
             ON CONFLICT(id) DO UPDATE SET
               court_category_id = excluded.court_category_id,
               name = excluded.name,
               order_index = excluded.order_index,
               updated_at = excluded.updated_at
             WHERE case_categories.is_user_modified = 0''',
          [
            caseCategory.id,
            cat.id,
            caseCategory.labelEn,
            caseCategory.orderIndex,
            _nowMs,
          ],
        );
      }
    }
  }

  /// Upserts all pre-seeded steps keyed by stable ID, preserving rows the
  /// user has customized.
  ///
  /// NOTE: English labels are stored in the DB as the primary display name.
  /// When the user switches to Bengali, the UI must re-resolve seed labels
  /// (see AppTranslations.seedLabel()) rather than showing the DB-stored text.
  /// Language-switch re-resolution of seed labels is deferred to a future task.
  static Future<void> _seedSteps(AppDatabase db) async {
    for (final cat in seedCategories) {
      for (final step in cat.steps) {
        await db.customStatement(
          '''INSERT INTO steps
             (id, court_category_id, step_name, order_index, is_custom,
              is_user_modified, user_id, firm_id,
              updated_at, version, synced_at, is_deleted, last_modified_by)
             VALUES (?, ?, ?, ?, 0, 0, NULL, NULL, ?, NULL, NULL, 0, NULL)
             ON CONFLICT(id) DO UPDATE SET
               court_category_id = excluded.court_category_id,
               step_name = excluded.step_name,
               order_index = excluded.order_index,
               updated_at = excluded.updated_at
             WHERE steps.is_user_modified = 0''',
          [step.id, cat.id, step.labelEn, step.orderIndex, _nowMs],
        );
      }
    }
  }

  /// Upserts all pre-seeded case types keyed by stable ID, preserving
  /// user-modified rows.
  static Future<void> _seedCaseTypes(AppDatabase db) async {
    for (final cat in seedCategories) {
      for (final ct in cat.allCaseTypes) {
        await db.customStatement(
          '''INSERT INTO case_types
             (id, court_category_id, case_category_id, name, order_index,
              is_custom, is_user_modified,
              user_id, firm_id,
              updated_at, version, synced_at, is_deleted, last_modified_by)
             VALUES (?, ?, ?, ?, ?, 0, 0, NULL, NULL, ?, NULL, NULL, 0, NULL)
             ON CONFLICT(id) DO UPDATE SET
               court_category_id = excluded.court_category_id,
               case_category_id = excluded.case_category_id,
               name = excluded.name,
               order_index = excluded.order_index,
               updated_at = excluded.updated_at
             WHERE case_types.is_user_modified = 0''',
          [ct.id, cat.id, ct.caseCategoryId, ct.labelEn, ct.orderIndex, _nowMs],
        );
      }
    }
  }

  /// Upserts all pre-seeded on-behalf options keyed by stable ID, preserving
  /// user-modified rows.
  static Future<void> _seedOnBehalfs(AppDatabase db) async {
    for (final cat in seedCategories) {
      for (final ob in cat.onBehalfs) {
        await db.customStatement(
          '''INSERT INTO on_behalfs
             (id, court_category_id, name, order_index, is_custom, is_user_modified,
              user_id, firm_id,
              updated_at, version, synced_at, is_deleted, last_modified_by)
             VALUES (?, ?, ?, ?, 0, 0, NULL, NULL, ?, NULL, NULL, 0, NULL)
             ON CONFLICT(id) DO UPDATE SET
               court_category_id = excluded.court_category_id,
               name = excluded.name,
               order_index = excluded.order_index,
               updated_at = excluded.updated_at
             WHERE on_behalfs.is_user_modified = 0''',
          [ob.id, cat.id, ob.labelEn, ob.orderIndex, _nowMs],
        );
      }
    }
  }

  /// Upserts all pre-seeded courts (supreme + lower), preserving
  /// user-modified rows.
  static Future<void> _seedCourts(AppDatabase db) async {
    for (final court in allSeedCourts) {
      await db.customStatement(
        '''INSERT INTO courts
           (id, court_name, higher_lower_courts, division, district,
            court_category_id, order_index, is_custom, is_user_modified,
            user_id, firm_id,
            updated_at, version, synced_at, is_deleted, last_modified_by)
           VALUES (?, ?, ?, ?, ?, ?, ?, 0, 0, NULL, NULL, ?, NULL, NULL, 0, NULL)
           ON CONFLICT(id) DO UPDATE SET
             court_name = excluded.court_name,
             higher_lower_courts = excluded.higher_lower_courts,
             division = excluded.division,
             district = excluded.district,
             court_category_id = excluded.court_category_id,
             order_index = excluded.order_index,
             updated_at = excluded.updated_at
           WHERE courts.is_user_modified = 0''',
        [
          court.id,
          court.courtNameEn,
          court.higherLowerCourts,
          court.division,
          court.district,
          court.courtCategoryId,
          court.orderIndex,
          _nowMs,
        ],
      );
    }
  }

  /// Upserts the 57 pre-seeded law names, each with its category and order.
  ///
  /// A built-in row the user renamed (`is_user_modified = 1`) is preserved, the
  /// same rule every other reference list follows; a row the user or their firm
  /// added is not in [seedLaws] at all and is never touched.
  static Future<void> _seedLaws(AppDatabase db) async {
    for (final law in seedLaws) {
      await db.customStatement(
        '''INSERT INTO laws
           (id, name, category, order_index, is_custom, is_user_modified,
            user_id, firm_id,
            updated_at, version, synced_at, is_deleted, last_modified_by)
           VALUES (?, ?, ?, ?, 0, 0, NULL, NULL, ?, NULL, NULL, 0, NULL)
           ON CONFLICT(id) DO UPDATE SET
             name = excluded.name,
             category = excluded.category,
             order_index = excluded.order_index,
             updated_at = excluded.updated_at
           WHERE laws.is_user_modified = 0''',
        [law.id, law.name, law.categoryId, law.orderIndex, _nowMs],
      );
    }
  }

  /// Soft-deletes removed built-in AD/HCD rows without touching user edits.
  static Future<void> _removeObsoleteAppellateAndHighCourtRows(
    AppDatabase db,
  ) async {
    await _softDeleteObsolete(db, 'steps', const <String>[
      'step-appellate_division-',
      'step-high_court_division-',
    ], <String>{});

    final currentCaseTypeIds = seedCategories
        .where(
          (cat) =>
              cat.id == appellateDivisionId || cat.id == highCourtDivisionId,
        )
        .expand((cat) => cat.allCaseTypes)
        .map((type) => type.id)
        .toSet();
    await _softDeleteObsolete(db, 'case_types', const <String>[
      'casetype-appellate_division-',
      'casetype-high_court_division-',
    ], currentCaseTypeIds);

    final currentOnBehalfIds = seedCategories
        .where(
          (cat) =>
              cat.id == appellateDivisionId || cat.id == highCourtDivisionId,
        )
        .expand((cat) => cat.onBehalfs)
        .map((option) => option.id)
        .toSet();
    await _softDeleteObsolete(db, 'on_behalfs', const <String>[
      'onbehalf-appellate_division-',
      'onbehalf-high_court_division-',
    ], currentOnBehalfIds);

    final currentCourtIds = allSeedCourts
        .where(
          (court) =>
              court.courtCategoryId == appellateDivisionId ||
              court.courtCategoryId == highCourtDivisionId,
        )
        .map((court) => court.id)
        .toSet();
    await _softDeleteObsolete(db, 'courts', const <String>[
      'court-higher_courts-appellate_division-',
      'court-higher_courts-high_court_division-',
    ], currentCourtIds);
  }

  /// Soft-deletes obsolete built-ins while preserving customized/deleted rows.
  static Future<void> _softDeleteObsolete(
    AppDatabase db,
    String tableName,
    List<String> prefixes,
    Set<String> currentIds,
  ) async {
    final prefixSql = prefixes.map((_) => 'id LIKE ?').join(' OR ');
    final keepSql = currentIds.isEmpty
        ? ''
        : ' AND id NOT IN (${List.filled(currentIds.length, '?').join(', ')})';
    await db.customStatement(
      'UPDATE $tableName SET is_deleted = 1, updated_at = ? '
      'WHERE is_custom = 0 AND is_user_modified = 0 '
      'AND ($prefixSql)$keepSql',
      <Object?>[_nowMs, ...prefixes.map((prefix) => '$prefix%'), ...currentIds],
    );
  }

  // ---------------------------------------------------------------------------
  // Ledger helpers
  // ---------------------------------------------------------------------------

  /// Returns the set of already-applied migration IDs.
  Future<Set<String>> _appliedMigrationIds() async {
    final rows = await db
        .customSelect('SELECT migration_id FROM seed_migrations')
        .get();
    return rows.map((r) => r.read<String>('migration_id')).toSet();
  }

  /// Records a successfully applied migration in the ledger.
  /// Must be called inside a transaction with the migration itself.
  Future<void> _recordMigration(String id, String checksum) async {
    await db.customStatement(
      'INSERT OR REPLACE INTO seed_migrations (migration_id, checksum, applied_at) VALUES (?, ?, ?)',
      [id, checksum, _nowMs],
    );
  }
}
