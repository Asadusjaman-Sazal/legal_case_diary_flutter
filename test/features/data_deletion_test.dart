/// Tests for the data-deletion service behind Manage Account's two cards
/// (0.0.473).
///
/// The service is the whole of the feature's behaviour: the screen only picks a
/// card, asks for ticks and shows the sentence that comes back. So this suite
/// pins what a deletion really does to the database — which rows go, which stay,
/// what the queue is told, and when the cloud copy counts as gone — against a
/// real in-memory Drift database.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/data_deletion_service.dart';
import 'package:legal_case_diary/features/case_reference/data/local/case_references_dao.dart';
import 'package:legal_case_diary/features/case_reference/data/reference_repository.dart';
import 'package:legal_case_diary/features/cases/data/case_repository.dart';
import 'package:legal_case_diary/features/cases/data/local/case_history_dao.dart';
import 'package:legal_case_diary/features/cases/data/local/cases_dao.dart';
import 'package:legal_case_diary/features/notes/data/local/notes_dao.dart';
import 'package:legal_case_diary/features/notes/data/notes_repository.dart';
import 'package:legal_case_diary/features/settings/data/case_types_repository.dart';
import 'package:legal_case_diary/features/settings/data/court_categories_repository.dart';
import 'package:legal_case_diary/features/settings/data/courts_repository.dart';
import 'package:legal_case_diary/features/settings/data/local/case_types_dao.dart';
import 'package:legal_case_diary/features/settings/data/local/court_categories_dao.dart';
import 'package:legal_case_diary/features/settings/data/local/courts_dao.dart';
import 'package:legal_case_diary/features/settings/data/local/on_behalfs_dao.dart';
import 'package:legal_case_diary/features/settings/data/local/steps_dao.dart';
import 'package:legal_case_diary/features/settings/data/on_behalfs_repository.dart';
import 'package:legal_case_diary/features/settings/data/steps_repository.dart';
import 'package:legal_case_diary/sync/recovery_lock.dart';
import 'package:legal_case_diary/sync/sync_queue_dao.dart';
import 'package:legal_case_diary/sync/sync_service.dart';
import 'package:legal_case_diary/sync/sync_write_helper.dart';

/// One in-memory database with the repositories and helpers a deletion needs.
class _Harness {
  _Harness._(this.db, this.syncHelper);

  /// Opens a fresh empty database with its own local identity.
  static Future<_Harness> open() async {
    final db = AppDatabase(NativeDatabase.memory());
    final prefs = await SharedPreferences.getInstance();
    return _Harness._(
      db,
      SyncWriteHelper(SyncQueueDao(db), LocalIdentityService(prefs)),
    );
  }

  final AppDatabase db;
  final SyncWriteHelper syncHelper;

  SyncQueueDao get queue => SyncQueueDao(db);

  /// The service under test, with the cloud half a test decides.
  DataDeletionService service({Future<BacklogOutcome?> Function()? push}) =>
      DataDeletionService(db: db, syncHelper: syncHelper, pushBacklog: push);

  Future<void> close() => db.close();

  /// A custom court category, a custom court and a custom on-behalf.
  Future<({String categoryId, String courtId, String onBehalfId})>
  addReferenceData() async {
    final categoryId =
        await LocalCourtCategoriesRepository(
          CourtCategoriesDao(db),
          syncHelper,
        ).insert(
          CourtCategoriesCompanion(
            nameKey: const Value('my_category'),
            courtLevel: const Value('lower'),
            orderIndex: const Value(1),
          ),
        );
    final courtId = await LocalCourtsRepository(CourtsDao(db), syncHelper)
        .insert(
          CourtsCompanion(
            courtName: const Value('My Court'),
            higherLowerCourts: const Value('lower_courts'),
            courtCategoryId: Value(categoryId),
          ),
        );
    final onBehalfId =
        await LocalOnBehalfsRepository(OnBehalfsDao(db), syncHelper).insert(
          OnBehalfsCompanion(
            courtCategoryId: Value(categoryId),
            name: const Value('Plaintiff'),
            orderIndex: const Value(1),
          ),
        );
    return (categoryId: categoryId, courtId: courtId, onBehalfId: onBehalfId);
  }

  /// The built-in baseline a fresh install reads: `is_custom = 0` rows written
  /// straight into the tables, which no repository can create.
  Future<void> addBuiltInReferenceData() async {
    await db
        .into(db.courtCategories)
        .insert(
          CourtCategoriesCompanion(
            id: const Value('builtin_category'),
            nameKey: const Value('appellate_division'),
            courtLevel: const Value('higher'),
            orderIndex: const Value(1),
            isCustom: const Value(false),
            updatedAt: const Value(1),
          ),
        );
    await db
        .into(db.courts)
        .insert(
          CourtsCompanion(
            id: const Value('builtin_court'),
            courtName: const Value('Appellate Division'),
            higherLowerCourts: const Value('higher_courts'),
            courtCategoryId: const Value('builtin_category'),
            isCustom: const Value(false),
            updatedAt: const Value(1),
          ),
        );
  }

  /// A custom step and a custom case type under [categoryId].
  Future<void> addCustomStepAndCaseType(String categoryId) async {
    await LocalStepsRepository(StepsDao(db), syncHelper).insert(
      StepsCompanion(
        courtCategoryId: Value(categoryId),
        stepName: const Value('My Step'),
        orderIndex: const Value(1),
      ),
    );
    await LocalCaseTypesRepository(CaseTypesDao(db), syncHelper).insert(
      CaseTypesCompanion(
        courtCategoryId: Value(categoryId),
        name: const Value('My Case Type'),
        orderIndex: const Value(1),
      ),
    );
  }

  /// One case, and the id it was given.
  Future<String> addCase({
    required String courtId,
    required String onBehalfId,
    String number = '110/2021',
  }) => LocalCaseRepository(CasesDao(db), CaseHistoryDao(db), syncHelper)
      .insertCase(
        CasesCompanion(
          caseNumber: Value(number),
          petitioner: const Value('Alice'),
          respondent: const Value('Bob'),
          courtId: Value(courtId),
          caseType: const Value('Civil'),
          onBehalfId: Value(onBehalfId),
        ),
      );

  /// One hearing entry for [caseId].
  Future<String> addHistory(String caseId) async {
    const id = 'history-1';
    await db
        .into(db.caseHistory)
        .insert(
          CaseHistoryCompanion(
            id: const Value(id),
            caseId: Value(caseId),
            userId: Value(syncHelper.currentUserId),
            hearingDate: const Value(1),
            createdBy: Value(syncHelper.currentUserId),
            sourceMutationId: const Value('mutation-1'),
            baseCaseVersion: const Value(1),
            resultCaseVersion: const Value(2),
            updatedAt: const Value(1),
          ),
        );
    return id;
  }

  /// One note.
  Future<String> addNote([String title = 'Reminder']) =>
      LocalNotesRepository(NotesDao(db), syncHelper).insertNote(
        NotesCompanion(
          title: Value(title),
          body: const Value('File the affidavit'),
          createdAt: const Value(1),
        ),
      );

  /// One case reference.
  Future<String> addReference() =>
      LocalReferenceRepository(
        CaseReferencesDao(db),
        syncHelper,
      ).insertReference(
        CaseReferencesCompanion(
          referenceAndPageNo: const Value('12 MLR 34'),
          createdAt: const Value(1),
        ),
      );

  /// How many live (non-tombstoned) rows [table] holds.
  Future<int> live(String table) async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS n FROM "$table" WHERE is_deleted = 0')
        .getSingle();
    return row.data['n']! as int;
  }

  /// The queue rows for one entity, whatever their state.
  Future<List<SyncQueueRow>> entriesFor(String entityType, String id) =>
      queue.getByEntity(entityType, id);

  /// The queue rows still waiting to be pushed that name [id] of any type.
  Future<List<SyncQueueRow>> openEntriesFor(String id) async =>
      (await queue.getUnresolved())
          .where((row) => row.entityId == id)
          .toList(growable: false);
}

void main() {
  late _Harness h;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    h = await _Harness.open();
  });

  tearDown(() => h.close());

  group('what a deletion removes', () {
    test('cases take their hearing history and nothing else goes', () async {
      final ids = await h.addReferenceData();
      await h.addCase(courtId: ids.courtId, onBehalfId: ids.onBehalfId);
      await h.addHistory((await CasesDao(h.db).getAll()).single.id);
      await h.addNote();
      await h.addReference();

      final result = await h.service().delete(
        scope: const <DataDeletionCategory>{DataDeletionCategory.cases},
        cloud: false,
      );

      expect(result.failed, isFalse);
      expect(result.countOf(DataDeletionCategory.cases), 1);
      expect(await h.live('cases'), 0);
      expect(
        await h.live('case_history'),
        0,
        reason: 'the history went with it',
      );
      // Everything the user did not tick is untouched — the whole point of the
      // tick list.
      expect(await h.live('notes'), 1);
      expect(await h.live('case_references'), 1);
      expect(result.cloudSent, isFalse, reason: 'the free path never pushes');
    });

    test('notes only: the cases stay where they are', () async {
      final ids = await h.addReferenceData();
      await h.addCase(courtId: ids.courtId, onBehalfId: ids.onBehalfId);
      await h.addNote();
      await h.addReference();

      final result = await h.service().delete(
        scope: const <DataDeletionCategory>{DataDeletionCategory.notes},
        cloud: false,
      );

      expect(result.countOf(DataDeletionCategory.notes), 1);
      expect(await h.live('notes'), 0);
      expect(await h.live('cases'), 1);
      expect(await h.live('case_references'), 1);
    });

    test('a row the server never saw leaves no delete behind', () async {
      final ids = await h.addReferenceData();
      final caseId = await h.addCase(
        courtId: ids.courtId,
        onBehalfId: ids.onBehalfId,
      );
      // The case was inserted here and never pushed, so the queue holds a
      // pending insert for it.
      expect(await h.entriesFor('case', caseId), hasLength(1));

      await h.service().delete(
        scope: const <DataDeletionCategory>{DataDeletionCategory.cases},
        cloud: false,
      );

      // The compaction matrix drops the insert with its delete: there is nothing
      // for the server to hear about, so nothing is queued. (The reference rows
      // this case needed are the test's own pending inserts and are not ours.)
      expect(await h.entriesFor('case', caseId), isEmpty);
      expect(await h.openEntriesFor(caseId), isEmpty);
    });

    test('a row the server holds is queued as a tombstone', () async {
      final ids = await h.addReferenceData();
      final caseId = await h.addCase(
        courtId: ids.courtId,
        onBehalfId: ids.onBehalfId,
      );
      // As if the insert had been pushed and its receipt settled.
      await h.queue.resolveEntity('case', caseId);

      await h.service().delete(
        scope: const <DataDeletionCategory>{DataDeletionCategory.cases},
        cloud: false,
      );

      // The settled insert stays as the record of what the server already
      // holds; the only *open* entry is the tombstone.
      final open = await h.openEntriesFor(caseId);
      expect(open, hasLength(1));
      expect(open.single.operation, 'delete');
      expect(open.single.state, 'pending');
    });
  });

  group('custom seed data', () {
    test(
      'the rows the user added go and the built-in baseline stays',
      () async {
        await h.addBuiltInReferenceData();
        final ids = await h.addReferenceData();
        await h.addCustomStepAndCaseType(ids.categoryId);

        final result = await h.service().delete(
          scope: const <DataDeletionCategory>{
            DataDeletionCategory.customSeedData,
          },
          cloud: false,
        );

        // A category, a court, an on-behalf, a step and a case type.
        expect(result.countOf(DataDeletionCategory.customSeedData), 5);
        expect(await h.live('court_categories'), 1, reason: 'the built-in one');
        expect(await h.live('courts'), 1, reason: 'the built-in one');
        expect(await h.live('steps'), 0);
        expect(await h.live('case_types'), 0);
        expect(await h.live('on_behalfs'), 0);
      },
    );

    test('a custom court a remaining case points at is kept', () async {
      final ids = await h.addReferenceData();
      await h.addCustomStepAndCaseType(ids.categoryId);
      await h.addCase(courtId: ids.courtId, onBehalfId: ids.onBehalfId);

      final result = await h.service().delete(
        scope: const <DataDeletionCategory>{
          DataDeletionCategory.customSeedData,
        },
        cloud: false,
      );

      // The court and the on-behalf are what the case table references by id, and
      // the category is what those two still name, so all three are held back;
      // the step and the case type are text on the case and go.
      expect(result.countOf(DataDeletionCategory.customSeedData), 2);
      expect(await h.live('courts'), 1, reason: 'the case still points at it');
      expect(await h.live('court_categories'), 1);
      expect(await h.live('on_behalfs'), 1);
      expect(await h.live('steps'), 0);
      expect(await h.live('case_types'), 0);
      expect(await h.live('cases'), 1);
    });

    test('ticking cases as well frees the court it pointed at', () async {
      final ids = await h.addReferenceData();
      await h.addCase(courtId: ids.courtId, onBehalfId: ids.onBehalfId);

      final result = await h.service().delete(
        scope: const <DataDeletionCategory>{
          DataDeletionCategory.cases,
          DataDeletionCategory.customSeedData,
        },
        cloud: false,
      );

      expect(result.countOf(DataDeletionCategory.cases), 1);
      expect(result.countOf(DataDeletionCategory.customSeedData), 3);
      expect(await h.live('cases'), 0);
      expect(await h.live('courts'), 0);
      expect(await h.live('court_categories'), 0);
      expect(await h.live('on_behalfs'), 0);
    });
  });

  group('the cloud half', () {
    test('the premium path pushes and reports the copies gone', () async {
      final ids = await h.addReferenceData();
      await h.addCase(courtId: ids.courtId, onBehalfId: ids.onBehalfId);
      var pushes = 0;

      final result = await h
          .service(
            push: () async {
              pushes++;
              return const BacklogOutcome(pushed: 1);
            },
          )
          .delete(
            scope: const <DataDeletionCategory>{DataDeletionCategory.cases},
            cloud: true,
          );

      expect(pushes, 1);
      expect(result.cloudSent, isTrue);
    });

    test('a delete still sitting in the queue is reported as pending', () async {
      final ids = await h.addReferenceData();
      final caseId = await h.addCase(
        courtId: ids.courtId,
        onBehalfId: ids.onBehalfId,
      );
      await h.queue.resolveEntity('case', caseId);

      // A push that could not place the delete (offline, refused, paused): the
      // queue still holds it, so the account's copy is not gone yet.
      final pending = await h
          .service(push: () async => const BacklogOutcome())
          .delete(
            scope: const <DataDeletionCategory>{DataDeletionCategory.cases},
            cloud: true,
          );
      expect(pending.cloudSent, isFalse);

      // The same deletion, pushed successfully, reports the copy gone.
      final sent = await h
          .service(
            push: () async {
              await h.queue.resolveEntity('case', caseId);
              return const BacklogOutcome(pushed: 1);
            },
          )
          .delete(
            scope: const <DataDeletionCategory>{DataDeletionCategory.cases},
            cloud: true,
          );
      expect(sent.cloudSent, isTrue);
    });

    test('the free path never touches the network', () async {
      final ids = await h.addReferenceData();
      await h.addCase(courtId: ids.courtId, onBehalfId: ids.onBehalfId);
      var pushes = 0;

      final result = await h
          .service(
            push: () async {
              pushes++;
              return const BacklogOutcome(pushed: 1);
            },
          )
          .delete(
            scope: const <DataDeletionCategory>{DataDeletionCategory.cases},
            cloud: false,
          );

      expect(pushes, 0);
      expect(result.cloudSent, isFalse);
      expect(await h.live('cases'), 0, reason: 'the local delete still ran');
    });

    test('nothing ticked deletes nothing and pushes nothing', () async {
      final ids = await h.addReferenceData();
      await h.addCase(courtId: ids.courtId, onBehalfId: ids.onBehalfId);
      var pushes = 0;

      final result = await h
          .service(
            push: () async {
              pushes++;
              return const BacklogOutcome();
            },
          )
          .delete(scope: const <DataDeletionCategory>{}, cloud: true);

      expect(result.total, 0);
      expect(pushes, 0);
      expect(await h.live('cases'), 1);
    });

    test('a failure leaves every row exactly where it was', () async {
      final ids = await h.addReferenceData();
      await h.addCase(courtId: ids.courtId, onBehalfId: ids.onBehalfId);
      await h.addNote();
      // The extended-offline lock refuses every queued write, which is the one
      // way a deletion can fail midway: the transaction must roll back whole.
      await RecoveryLock(h.db).engage();

      final result = await h.service().delete(
        scope: const <DataDeletionCategory>{
          DataDeletionCategory.cases,
          DataDeletionCategory.notes,
        },
        cloud: false,
      );

      expect(result.failed, isTrue);
      expect(result.total, 0);
      expect(await h.live('cases'), 1);
      expect(await h.live('notes'), 1);
    });
  });
}
