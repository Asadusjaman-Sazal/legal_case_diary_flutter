/// Deleting the user's own data — Manage Account's *Delete Local & Cloud Data*
/// and *Delete Local Data*.
///
/// **The request (0.0.473, user request).** A premium account needs a way to
/// throw its work away and start fresh without giving up the account, and a free
/// one needs the same for the diary that only ever lived on this device. Both walk
/// a tick list — cases, notes, case references and the reference data the user
/// added — and remove exactly what was ticked, leaving the profile, the
/// subscription and the settings alone.
///
/// **One delete path, the app's own.** Every row goes through the repository that
/// already owns its delete: `LocalCaseRepository.deleteCase`, the notes and
/// reference repositories, and the five editable reference repositories for
/// custom rows. So a deletion here is made of the same soft delete, the same
/// `sync_queue` entry and the same offline compaction matrix as a deletion made
/// from a case card — a row that was never pushed has its pending insert dropped
/// instead of queued as a delete the server would refuse as an unknown id, and a
/// pushed row is queued as a tombstone. Nothing new was invented for this screen,
/// and there is no server-side half: the premium action simply runs a backlog
/// push afterwards, which is what carries the tombstones to Supabase and lets
/// every other device of the account learn about them.
///
/// **What is deliberately not here.** The per-case notification preference rows
/// are a per-user preference class the request keeps (notification choices
/// survive), and the app's notification job only alerts for cases that still
/// exist, so an orphaned row changes nothing the user can see or hear; Supabase
/// cascades it when the case's tombstone is purged. `delete_requests` and
/// `conflict_log` are a request queue and a rejected-mutation log, not the user's
/// data: the firm case — the only place a request exists — is refused wholesale
/// (see `manage_account_screen.dart`), and a conflict row for a record that just
/// disappeared is already rendered as "no identity" by the Sync Status screen
/// (0.0.471).
///
/// **All or nothing.** The whole deletion runs in one transaction, so a failure
/// (the extended-offline recovery lock, an unreadable database) leaves every row
/// exactly where it was and reports [DataDeletionResult.failed] rather than a
/// half-emptied diary.
///
/// **Cost, deliberately.** The deletion walks the rows one at a time through each
/// repository, which is what keeps it on the same path a single delete takes and
/// lets it inherit the compaction matrix, instead of growing a second bulk SQL
/// writer that would have to be kept in step with that path. The ceiling is a very
/// large diary: every row pays its own queue read inside the one transaction, so
/// tens of thousands of rows would spend noticeable time with the card's spinner
/// up. ponytail: reuse the repository per row until that is measured; the upgrade
/// is one bulk pass per table that writes the tombstones and their queue rows in
/// one statement set.
library;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../sync/sync_queue_dao.dart';
import '../../../sync/sync_service.dart';
import '../../../sync/sync_write_helper.dart';
import '../../case_reference/data/local/case_references_dao.dart';
import '../../case_reference/data/reference_repository.dart';
import '../../cases/data/case_history_repository.dart';
import '../../cases/data/case_repository.dart';
import '../../cases/data/local/case_history_dao.dart';
import '../../cases/data/local/cases_dao.dart';
import '../../notes/data/local/notes_dao.dart';
import '../../notes/data/notes_repository.dart';
import '../../settings/data/case_types_repository.dart';
import '../../settings/data/court_categories_repository.dart';
import '../../settings/data/courts_repository.dart';
import '../../settings/data/local/case_types_dao.dart';
import '../../settings/data/local/court_categories_dao.dart';
import '../../settings/data/local/courts_dao.dart';
import '../../settings/data/local/on_behalfs_dao.dart';
import '../../settings/data/local/steps_dao.dart';
import '../../settings/data/on_behalfs_repository.dart';
import '../../settings/data/steps_repository.dart';

/// The kinds of the user's own data the Danger Zone's tick list offers.
enum DataDeletionCategory {
  /// Cases, together with their hearing history.
  cases,

  /// Notes.
  notes,

  /// Case references.
  caseReferences,

  /// The reference data the user added — court categories, court names, steps,
  /// case types and on-behalfs — and never the built-in baseline, which every
  /// install reads and which the app's own delete paths refuse to remove.
  customSeedData,
}

/// What one deletion removed, and what became of the cloud copies.
class DataDeletionResult {
  /// Creates a result.
  const DataDeletionResult({
    required this.counts,
    this.cloudSent = false,
    this.failed = false,
  });

  /// How many rows each ticked category removed.
  final Map<DataDeletionCategory, int> counts;

  /// Whether the deletes were pushed: false when nothing was pushed (the free
  /// action, which never touches the network), when the push could not run, or
  /// when the server has not accepted every delete yet — the three cases the
  /// screen words the same way, because in all of them the cloud copy is still
  /// to come.
  final bool cloudSent;

  /// Whether the deletion did not run at all. Nothing was changed.
  final bool failed;

  /// How many rows [category] removed.
  int countOf(DataDeletionCategory category) => counts[category] ?? 0;

  /// How many rows the whole deletion removed.
  int get total => counts.values.fold(0, (sum, value) => sum + value);
}

/// Removes the ticked categories of the user's own data.
class DataDeletionService {
  /// Creates the service over the local database and the shared write helper.
  ///
  /// [pushBacklog] is the cloud half, injected: production passes
  /// `SyncService.runBacklogPush`, which sends the queued tombstones and is
  /// itself the gate (no client, offline, sync switched off or not entitled all
  /// return null without sending anything). A test passes a recorder.
  DataDeletionService({
    required this.db,
    required this.syncHelper,
    this.pushBacklog,
  });

  /// The database whose rows are deleted.
  final AppDatabase db;

  /// The helper every repository writes its queue entry through.
  final SyncWriteHelper syncHelper;

  /// Sends the queued deletes to the account, or null when this build cannot.
  final Future<BacklogOutcome?> Function()? pushBacklog;

  /// Deletes [scope] locally, then — when [cloud] — pushes the deletes.
  ///
  /// Never throws: the outcome is a [DataDeletionResult], because the caller's
  /// only decision is which sentence to show.
  Future<DataDeletionResult> delete({
    required Set<DataDeletionCategory> scope,
    required bool cloud,
  }) async {
    if (scope.isEmpty) {
      return const DataDeletionResult(counts: <DataDeletionCategory, int>{});
    }

    final counts = <DataDeletionCategory, int>{};
    // Every entity this run deleted, by queue entity type, so the cloud half can
    // ask its own queue a precise question afterwards instead of guessing from
    // the outcome counts (which describe the whole account's backlog).
    final deleted = <String, Set<String>>{};

    try {
      await db.transaction(() async {
        // Cases first on purpose: the custom reference rows a *remaining* case
        // still points at are kept (see `_deleteCustomSeedData`), and a run that
        // ticks both categories must therefore take the cases out first or it
        // would keep reference rows for cases that are about to go.
        if (scope.contains(DataDeletionCategory.cases)) {
          counts[DataDeletionCategory.cases] = await _deleteCases(deleted);
        }
        if (scope.contains(DataDeletionCategory.notes)) {
          counts[DataDeletionCategory.notes] = await _deleteNotes(deleted);
        }
        if (scope.contains(DataDeletionCategory.caseReferences)) {
          counts[DataDeletionCategory.caseReferences] = await _deleteReferences(
            deleted,
          );
        }
        if (scope.contains(DataDeletionCategory.customSeedData)) {
          counts[DataDeletionCategory.customSeedData] =
              await _deleteCustomSeedData(deleted);
        }
      });
    } on Object {
      // The transaction rolled back, so nothing was deleted — including whatever
      // had already been touched inside it.
      return const DataDeletionResult(
        counts: <DataDeletionCategory, int>{},
        failed: true,
      );
    }

    if (!cloud || pushBacklog == null) {
      return DataDeletionResult(counts: counts);
    }

    try {
      await pushBacklog!();
    } on Object {
      // The deletes are queued and the worker retries them; the counts above are
      // still what this device deleted.
    }
    return DataDeletionResult(
      counts: counts,
      cloudSent: !await _hasUnpushedDeletes(deleted),
    );
  }

  /// Soft-deletes every live case and its hearing history.
  Future<int> _deleteCases(Map<String, Set<String>> deleted) async {
    // History first, so the FK-safe order matches the export order walked
    // backwards; both deletes are soft, so no constraint is at stake either way.
    final history = await (db.select(
      db.caseHistory,
    )..where((row) => row.isDeleted.equals(false))).get();
    final historyRepository = LocalCaseHistoryRepository(
      CaseHistoryDao(db),
      syncHelper,
    );
    for (final row in history) {
      await historyRepository.deleteHistory(row);
      _track(deleted, 'case_history', row.id);
    }

    final cases = await (db.select(
      db.cases,
    )..where((row) => row.isDeleted.equals(false))).get();
    final caseRepository = LocalCaseRepository(
      CasesDao(db),
      CaseHistoryDao(db),
      syncHelper,
    );
    for (final row in cases) {
      await caseRepository.deleteCase(row);
      _track(deleted, 'case', row.id);
    }
    return cases.length;
  }

  /// Soft-deletes every live note.
  Future<int> _deleteNotes(Map<String, Set<String>> deleted) async {
    final rows = await (db.select(
      db.notes,
    )..where((row) => row.isDeleted.equals(false))).get();
    final repository = LocalNotesRepository(NotesDao(db), syncHelper);
    for (final row in rows) {
      await repository.deleteNote(row);
      _track(deleted, 'note', row.id);
    }
    return rows.length;
  }

  /// Soft-deletes every live case reference.
  Future<int> _deleteReferences(Map<String, Set<String>> deleted) async {
    final rows = await (db.select(
      db.caseReferences,
    )..where((row) => row.isDeleted.equals(false))).get();
    final repository = LocalReferenceRepository(
      CaseReferencesDao(db),
      syncHelper,
    );
    for (final row in rows) {
      await repository.deleteReference(row);
      _track(deleted, 'reference', row.id);
    }
    return rows.length;
  }

  /// Soft-deletes the reference rows the user added, across the five editable
  /// reference tables.
  ///
  /// Only `is_custom` rows: a built-in row is the baseline every install reads,
  /// the repositories refuse to delete one, and an *edited* built-in row is that
  /// same baseline with the user's wording on it rather than data of their own
  /// (the request's "custom seed data", as decided with the user).
  ///
  /// **A reference row something still points at is kept.** The case table
  /// references `courts` and `on_behalfs` by id, and all five editable tables
  /// reference `court_categories`, so deleting one of those would leave a row on
  /// this device pointing at a row it no longer holds — a case whose court name
  /// would not resolve. (A step and a case type are stored *on the case* as text,
  /// so neither has a reference to break.) Leavers go before the rows they point
  /// at — steps and case types, then on-behalfs and courts, then the categories
  /// last against whatever is still standing — and ticking Cases as well deletes
  /// those cases first, so then nothing is held back.
  Future<int> _deleteCustomSeedData(Map<String, Set<String>> deleted) async {
    final surviving = await (db.select(
      db.cases,
    )..where((row) => row.isDeleted.equals(false))).get();
    final referencedCourtIds = <String>{
      for (final row in surviving) row.courtId,
    };
    final referencedOnBehalfIds = <String>{
      for (final row in surviving) row.onBehalfId,
    };

    var count = 0;

    // Steps and case types first: nothing points at either by id.
    final steps = await _customRows(
      db.steps,
      (row) => row.isCustom.equals(true) & row.isDeleted.equals(false),
    );
    final stepRepository = LocalStepsRepository(StepsDao(db), syncHelper);
    for (final row in steps) {
      await stepRepository.delete(row);
      _track(deleted, 'step', row.id);
      count++;
    }

    final caseTypes = await _customRows(
      db.caseTypes,
      (row) => row.isCustom.equals(true) & row.isDeleted.equals(false),
    );
    final caseTypeRepository = LocalCaseTypesRepository(
      CaseTypesDao(db),
      syncHelper,
    );
    for (final row in caseTypes) {
      await caseTypeRepository.delete(row);
      _track(deleted, 'case_type', row.id);
      count++;
    }

    final courts = await _customRows(
      db.courts,
      (row) => row.isCustom.equals(true) & row.isDeleted.equals(false),
    );
    final courtRepository = LocalCourtsRepository(CourtsDao(db), syncHelper);
    for (final row in courts) {
      if (referencedCourtIds.contains(row.id)) continue;
      await courtRepository.delete(row);
      _track(deleted, 'court', row.id);
      count++;
    }

    final onBehalfs = await _customRows(
      db.onBehalfs,
      (row) => row.isCustom.equals(true) & row.isDeleted.equals(false),
    );
    final onBehalfRepository = LocalOnBehalfsRepository(
      OnBehalfsDao(db),
      syncHelper,
    );
    for (final row in onBehalfs) {
      if (referencedOnBehalfIds.contains(row.id)) continue;
      await onBehalfRepository.delete(row);
      _track(deleted, 'on_behalf', row.id);
      count++;
    }

    // Categories last, against the rows still standing: a category a kept court,
    // a kept on-behalf, a built-in step or case type, or a case category still
    // names is kept with them.
    final stillReferencedCategoryIds = await _liveCategoryReferences();
    final categories = await _customRows(
      db.courtCategories,
      (row) => row.isCustom.equals(true) & row.isDeleted.equals(false),
    );
    final categoryRepository = LocalCourtCategoriesRepository(
      CourtCategoriesDao(db),
      syncHelper,
    );
    for (final row in categories) {
      if (stillReferencedCategoryIds.contains(row.id)) continue;
      await categoryRepository.delete(row);
      _track(deleted, 'court_category', row.id);
      count++;
    }

    return count;
  }

  /// The rows of one reference table matching [filter].
  Future<List<D>> _customRows<T extends Table, D extends DataClass>(
    TableInfo<T, D> table,
    Expression<bool> Function(T row) filter,
  ) => (db.select(table)..where(filter)).get();

  /// Every `court_category_id` a live row of the five editable tables still
  /// names.
  ///
  /// Read table by table, explicitly: a generic helper over `TableInfo` infers
  /// the table as the bare `Table` (Drift's generic parameters are covariant), so
  /// the columns could not be named. Typed selects cost five short blocks and are
  /// checked against the schema, which is the trade worth making here.
  Future<Set<String>> _liveCategoryReferences() async {
    final ids = <String>{};

    final courts = await (db.select(
      db.courts,
    )..where((row) => row.isDeleted.equals(false))).get();
    ids.addAll(courts.map((row) => row.courtCategoryId));

    final steps = await (db.select(
      db.steps,
    )..where((row) => row.isDeleted.equals(false))).get();
    ids.addAll(steps.map((row) => row.courtCategoryId));

    final caseTypes = await (db.select(
      db.caseTypes,
    )..where((row) => row.isDeleted.equals(false))).get();
    ids.addAll(caseTypes.map((row) => row.courtCategoryId));

    final onBehalfs = await (db.select(
      db.onBehalfs,
    )..where((row) => row.isDeleted.equals(false))).get();
    ids.addAll(onBehalfs.map((row) => row.courtCategoryId));

    final caseCategories = await (db.select(
      db.caseCategories,
    )..where((row) => row.isDeleted.equals(false))).get();
    ids.addAll(caseCategories.map((row) => row.courtCategoryId));

    return ids;
  }

  /// Records that [id] of [entityType] was deleted by this run.
  void _track(Map<String, Set<String>> deleted, String entityType, String id) =>
      deleted.putIfAbsent(entityType, () => <String>{}).add(id);

  /// Whether any queue entry for a row this run deleted is still unresolved.
  ///
  /// One query for the whole check, and precise: an unrelated piece of pending
  /// work elsewhere in the account never makes the cloud half look unfinished.
  /// A row that never reached the server has no entry left at all (the
  /// compaction matrix dropped its insert with its delete), which is the same
  /// answer as a resolved one — the server holds nothing of it.
  Future<bool> _hasUnpushedDeletes(Map<String, Set<String>> deleted) async {
    if (deleted.isEmpty) return false;
    for (final row in await SyncQueueDao(db).getUnresolved()) {
      if (deleted[row.entityType]?.contains(row.entityId) ?? false) return true;
    }
    return false;
  }
}

/// The deletion service this app run uses.
///
/// The cloud half is wired here rather than on the screen, and it is deliberately
/// the engine's own `runBacklogPush` — the gate for "no client", "offline",
/// "sync switched off" and "not entitled" is inside it, so the screen never has
/// to learn how the queue reaches the server and a deletion can never bypass one
/// of those rules. The service only reports whether the deletes made it.
final dataDeletionServiceProvider = FutureProvider<DataDeletionService>((
  ref,
) async {
  final db = await ref.watch(databaseProvider.future);
  return DataDeletionService(
    db: db,
    syncHelper: await ref.watch(syncWriteHelperProvider.future),
    pushBacklog: () => ref.read(syncServiceProvider).runBacklogPush(),
  );
});
