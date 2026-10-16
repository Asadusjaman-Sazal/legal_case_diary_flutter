/// Tests for the reference-row in-use rule (`reference_in_use_checker.dart`)
/// and for the three screens that read it.
///
/// §3.2: a reference row a **live** dependent row still names cannot be deleted.
/// The server refuses that tombstone (`enforce_reference_not_in_use`, 0.0.530),
/// and the app withholds the action so an offline delete is never queued and
/// then rejected. The rule has one home, so these tests pin it directly — one
/// case per parent — and then pin the three screens' behaviour with a firm
/// **member** account, which is the account most likely to be gated by mistake.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/constants/pre_seeded_data.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_repository.dart';
import 'package:legal_case_diary/features/cases/data/case_repository.dart';
import 'package:legal_case_diary/features/cases/data/local/case_history_dao.dart';
import 'package:legal_case_diary/features/cases/data/local/cases_dao.dart';
import 'package:legal_case_diary/features/settings/data/case_types_repository.dart';
import 'package:legal_case_diary/features/settings/data/court_categories_repository.dart';
import 'package:legal_case_diary/features/settings/data/courts_repository.dart';
import 'package:legal_case_diary/features/settings/data/local/case_types_dao.dart';
import 'package:legal_case_diary/features/settings/data/local/court_categories_dao.dart';
import 'package:legal_case_diary/features/settings/data/local/courts_dao.dart';
import 'package:legal_case_diary/features/settings/data/local/on_behalfs_dao.dart';
import 'package:legal_case_diary/features/settings/data/local/steps_dao.dart';
import 'package:legal_case_diary/features/settings/data/on_behalfs_repository.dart';
import 'package:legal_case_diary/features/settings/data/reference_in_use_checker.dart';
import 'package:legal_case_diary/features/settings/data/steps_repository.dart';
import 'package:legal_case_diary/features/settings/presentation/edit_court_steps/court_list_screen.dart';
import 'package:legal_case_diary/features/settings/presentation/edit_court_steps/item_list_screen.dart';
import 'package:legal_case_diary/features/settings/presentation/edit_court_steps/lower_court_category_list_screen.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:legal_case_diary/sync/sync_queue_dao.dart';
import 'package:legal_case_diary/sync/sync_write_helper.dart';

/// One in-memory database with the repositories the fixtures are written
/// through, exactly as the app writes them.
class _Harness {
  _Harness._(this.db, this.syncHelper);

  static Future<_Harness> open() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final db = AppDatabase(NativeDatabase.memory());
    final prefs = await SharedPreferences.getInstance();
    return _Harness._(
      db,
      SyncWriteHelper(SyncQueueDao(db), LocalIdentityService(prefs)),
    );
  }

  final AppDatabase db;
  final SyncWriteHelper syncHelper;

  Future<void> close() => db.close();

  /// A custom court category in Dhaka, as the Lower Court Categories screen
  /// creates one.
  Future<String> addCategory({required int order}) =>
      LocalCourtCategoriesRepository(CourtCategoriesDao(db), syncHelper).insert(
        CourtCategoriesCompanion(
          nameKey: const Value('my_category'),
          courtLevel: const Value('lower'),
          division: Value(divisionDhakaId),
          district: const Value('dhaka'),
          orderIndex: Value(order),
        ),
      );

  Future<String> addCourt({required String categoryId}) =>
      LocalCourtsRepository(CourtsDao(db), syncHelper).insert(
        CourtsCompanion(
          courtName: const Value('My Court'),
          higherLowerCourts: const Value(lowerCourtsOption),
          division: Value(divisionDhakaId),
          district: const Value('dhaka'),
          courtCategoryId: Value(categoryId),
          orderIndex: const Value(1),
        ),
      );

  Future<String> addOnBehalf({required String categoryId}) =>
      LocalOnBehalfsRepository(OnBehalfsDao(db), syncHelper).insert(
        OnBehalfsCompanion(
          courtCategoryId: Value(categoryId),
          name: const Value('Plaintiff'),
          orderIndex: const Value(1),
        ),
      );

  Future<String> addStep({required String categoryId}) =>
      LocalStepsRepository(StepsDao(db), syncHelper).insert(
        StepsCompanion(
          courtCategoryId: Value(categoryId),
          stepName: const Value('Filing'),
          orderIndex: const Value(1),
        ),
      );

  Future<String> addCaseType({required String categoryId}) =>
      LocalCaseTypesRepository(CaseTypesDao(db), syncHelper).insert(
        CaseTypesCompanion(
          courtCategoryId: Value(categoryId),
          name: const Value('Civil'),
          orderIndex: const Value(1),
        ),
      );

  /// A case category is a server-side parent the app has no screen for, so it
  /// is written straight into the table — the checker must still count it.
  Future<String> addCaseCategory({required String courtCategoryId}) async {
    const id = 'my_case_category';
    await db
        .into(db.caseCategories)
        .insert(
          CaseCategoriesCompanion(
            id: const Value(id),
            courtCategoryId: Value(courtCategoryId),
            name: const Value('Civil'),
            orderIndex: const Value(1),
            updatedAt: const Value(1),
          ),
        );
    return id;
  }

  Future<String> addCase({
    required String courtId,
    required String onBehalfId,
  }) => LocalCaseRepository(CasesDao(db), CaseHistoryDao(db), syncHelper)
      .insertCase(
        CasesCompanion(
          caseNumber: const Value('110/2021'),
          petitioner: const Value('Alice'),
          respondent: const Value('Bob'),
          courtId: Value(courtId),
          caseType: const Value('Civil'),
          onBehalfId: Value(onBehalfId),
        ),
      );

  // Tombstone helpers: the soft delete the app performs, written directly so a
  // test can stage one dependent kind at a time.
  Future<void> tombstoneCase(String id) =>
      (db.update(db.cases)..where((row) => row.id.equals(id))).write(
        const CasesCompanion(isDeleted: Value(true)),
      );

  Future<void> tombstoneCourt(String id) =>
      (db.update(db.courts)..where((row) => row.id.equals(id))).write(
        const CourtsCompanion(isDeleted: Value(true)),
      );

  Future<void> tombstoneOnBehalf(String id) =>
      (db.update(db.onBehalfs)..where((row) => row.id.equals(id))).write(
        const OnBehalfsCompanion(isDeleted: Value(true)),
      );

  Future<void> tombstoneStep(String id) =>
      (db.update(db.steps)..where((row) => row.id.equals(id))).write(
        const StepsCompanion(isDeleted: Value(true)),
      );

  Future<void> tombstoneCaseType(String id) =>
      (db.update(db.caseTypes)..where((row) => row.id.equals(id))).write(
        const CaseTypesCompanion(isDeleted: Value(true)),
      );

  Future<void> tombstoneCaseCategory(String id) =>
      (db.update(db.caseCategories)..where((row) => row.id.equals(id))).write(
        const CaseCategoriesCompanion(isDeleted: Value(true)),
      );
}

void main() {
  late _Harness h;

  setUp(() async {
    h = await _Harness.open();
  });

  tearDown(() => h.close());

  group('the rule', () {
    test('a live case holds its court and its on-behalf, and the category '
        'behind them', () async {
      final category = await h.addCategory(order: 1);
      final court = await h.addCourt(categoryId: category);
      final onBehalf = await h.addOnBehalf(categoryId: category);
      await h.addCase(courtId: court, onBehalfId: onBehalf);

      final inUse = await readReferenceInUse(h.db);

      expect(inUse.courtIds, contains(court));
      expect(inUse.onBehalfIds, contains(onBehalf));
      expect(inUse.courtCategoryIds, contains(category));
    });

    test(
      'a tombstoned case holds neither its court nor its on-behalf',
      () async {
        final category = await h.addCategory(order: 1);
        final court = await h.addCourt(categoryId: category);
        final onBehalf = await h.addOnBehalf(categoryId: category);
        final theCase = await h.addCase(courtId: court, onBehalfId: onBehalf);

        final theCaseTombstone = await readReferenceInUse(h.db);
        expect(theCaseTombstone.courtIds, contains(court));
        expect(theCaseTombstone.onBehalfIds, contains(onBehalf));

        await h.tombstoneCase(theCase);
        final after = await readReferenceInUse(h.db);
        expect(after.courtIds, isNot(contains(court)));
        expect(after.onBehalfIds, isNot(contains(onBehalf)));
        // The category is still held: its courts and on-behalfs are live.
        expect(after.courtCategoryIds, contains(category));
      },
    );

    test('a category is held by each live kind in it and released once every '
        'one is a tombstone', () async {
      final category = await h.addCategory(order: 1);
      final court = await h.addCourt(categoryId: category);
      final onBehalf = await h.addOnBehalf(categoryId: category);
      final step = await h.addStep(categoryId: category);
      final caseType = await h.addCaseType(categoryId: category);
      final caseCategory = await h.addCaseCategory(courtCategoryId: category);

      // Five kinds, tombstoned one at a time: the last one standing is what
      // decides, so a rule that missed any single kind fails here.
      final holders = <String, Future<void> Function()>{
        'a court': () => h.tombstoneCourt(court),
        'a step': () => h.tombstoneStep(step),
        'a case type': () => h.tombstoneCaseType(caseType),
        'an on-behalf': () => h.tombstoneOnBehalf(onBehalf),
        'a case category': () => h.tombstoneCaseCategory(caseCategory),
      };

      for (final holder in holders.entries) {
        expect(
          (await readReferenceInUse(h.db)).courtCategoryIds,
          contains(category),
          reason: 'only ${holder.key} has gone so far',
        );
        await holder.value();
      }

      expect(
        (await readReferenceInUse(h.db)).courtCategoryIds,
        isNot(contains(category)),
        reason: 'every holder is a tombstone now',
      );
    });

    test('the watcher re-reads when a dependent is deleted', () async {
      final category = await h.addCategory(order: 1);
      final court = await h.addCourt(categoryId: category);
      final onBehalf = await h.addOnBehalf(categoryId: category);
      final theCase = await h.addCase(courtId: court, onBehalfId: onBehalf);

      final seen = <ReferenceInUse>[];
      final subscription = watchReferenceInUse(h.db).listen(seen.add);
      await _settle();
      expect(seen, isNotEmpty);
      expect(seen.last.courtIds, contains(court));

      await h.tombstoneCase(theCase);
      await _settle();

      expect(seen.length, greaterThan(1), reason: 'the watch did not re-read');
      expect(seen.last.courtIds, isNot(contains(court)));
      await subscription.cancel();
    });
  });

  group('the screens', () {
    /// Fixtures the three screens share: one custom category held by two live
    /// courts and two live on-behalfs, and one free custom court inside it.
    ///
    /// A category listed by the Lower Court Categories screen is always held —
    /// that screen lists a category *because* a live court of it exists in the
    /// district — so its Delete is withheld by construction, and the courts and
    /// on-behalfs screens are where a withheld action sits beside an offered one.
    Future<({String category, String usedCourt, String freeCourt})>
    fixtures() async {
      final category = await h.addCategory(order: 1);
      final usedCourt = await h.addCourt(categoryId: category);
      final freeCourt = await h.addCourt(categoryId: category);
      final usedOnBehalf = await h.addOnBehalf(categoryId: category);
      await h.addOnBehalf(categoryId: category);
      await h.addCase(courtId: usedCourt, onBehalfId: usedOnBehalf);
      return (category: category, usedCourt: usedCourt, freeCourt: freeCourt);
    }

    /// Pumps one screen as a **firm member** — an associate of a chamber — with
    /// the real local repositories over the in-memory ledger.
    Future<void> pumpAsMember(WidgetTester tester, Widget screen) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWith((ref) async => h.db),
            courtsRepositoryProvider.overrideWith(
              (ref) async =>
                  LocalCourtsRepository(CourtsDao(h.db), h.syncHelper),
            ),
            courtCategoriesRepositoryProvider.overrideWith(
              (ref) async => LocalCourtCategoriesRepository(
                CourtCategoriesDao(h.db),
                h.syncHelper,
              ),
            ),
            onBehalfsRepositoryProvider.overrideWith(
              (ref) async =>
                  LocalOnBehalfsRepository(OnBehalfsDao(h.db), h.syncHelper),
            ),
            // The account is a member of a chamber: the screens must not gate
            // Add, Edit or Reorder on that — only the in-use rule withholds
            // anything, and only Delete.
            firmModeProvider.overrideWithValue(true),
            accountRoleProvider.overrideWithValue(AccountRole.associate),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: screen,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a firm member is offered Add, Edit and Reorder on all three '
        'screens', (tester) async {
      final ids = await fixtures();

      await pumpAsMember(
        tester,
        CourtListScreen(
          category: ids.category,
          higherLower: lowerCourtsOption,
          division: divisionDhakaId,
          district: 'dhaka',
        ),
      );
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));
      expect(find.byIcon(Icons.drag_indicator), findsNWidgets(2));

      await pumpAsMember(
        tester,
        ItemListScreen(kind: ItemKind.onBehalf, categoryId: ids.category),
      );
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));
      expect(find.byIcon(Icons.drag_indicator), findsNWidgets(2));

      await pumpAsMember(
        tester,
        const LowerCourtCategoryListScreen(
          division: divisionDhakaId,
          district: 'dhaka',
        ),
      );
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.drag_indicator), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('Delete is offered only for a court and an on-behalf nothing '
        'live names', (tester) async {
      final ids = await fixtures();

      await pumpAsMember(
        tester,
        CourtListScreen(
          category: ids.category,
          higherLower: lowerCourtsOption,
          division: divisionDhakaId,
          district: 'dhaka',
        ),
      );
      // Two courts are listed; the live case names only one of them.
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      await pumpAsMember(
        tester,
        ItemListScreen(kind: ItemKind.onBehalf, categoryId: ids.category),
      );
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      await pumpAsMember(
        tester,
        const LowerCourtCategoryListScreen(
          division: divisionDhakaId,
          district: 'dhaka',
        ),
      );
      // The one listed custom category is held by a live court in this
      // district, so it keeps its place; Edit and Reorder are untouched.
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

      await _unmount(tester);
    });
  });
}

/// Lets Drift's stream invalidation and the rule's read run.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

/// Takes the screens down inside the test body.
///
/// Drift closes a query stream's cache one event-loop turn after its last
/// listener goes, in a `Timer.run`, and the framework looks for pending timers
/// once the widget tree has gone — so the unmount has to happen here, where a
/// frame can still run that timer, rather than in the framework's own teardown.
/// A bare `pump()` flushes microtasks only, hence the explicit small duration.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(const Duration(milliseconds: 1));
}
