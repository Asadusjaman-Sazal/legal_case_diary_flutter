/// Tests for the Lower Court Categories flow (Task 12 Phase 3).
///
/// Covers the shared district derivation (only categories with courts in the
/// district, plus the user's own district-scoped ones, in the Add/Edit Case
/// form order), the district scoping of categories the user adds, the screen
/// itself, and the Add/Edit Case form picking the added category up.
library;

import 'dart:async';

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
import 'package:legal_case_diary/database/seed_migration_runner.dart';
import 'package:legal_case_diary/features/settings/data/court_categories_repository.dart';
import 'package:legal_case_diary/features/settings/data/courts_repository.dart';
import 'package:legal_case_diary/features/settings/data/district_court_categories.dart';
import 'package:legal_case_diary/features/settings/data/local/court_categories_dao.dart';
import 'package:legal_case_diary/features/settings/data/local/courts_dao.dart';
import 'package:legal_case_diary/features/settings/presentation/edit_court_steps/lower_court_category_list_screen.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:legal_case_diary/shared/widgets/add_edit_case_sheet.dart';
import 'package:legal_case_diary/sync/sync_queue_dao.dart';
import 'package:legal_case_diary/sync/sync_write_helper.dart';

/// Built-in civil category (has a court in Dhaka in these tests).
const _civilNameKey = 'lowerCourtCategory_districtCourtsCivil';

/// Built-in sessions category (deliberately without courts).
const _sessionsNameKey = 'lowerCourtCategory_districtSessionsCriminal';

const _civil = CourtCategory(
  id: districtCourtsCivilId,
  nameKey: _civilNameKey,
  courtLevel: 'lower',
  orderIndex: 1,
  isCustom: false,
  isUserModified: false,
  updatedAt: 0,
  isDeleted: false,
);

const _sessions = CourtCategory(
  id: districtSessionsCriminalId,
  nameKey: _sessionsNameKey,
  courtLevel: 'lower',
  orderIndex: 2,
  isCustom: false,
  isUserModified: false,
  updatedAt: 0,
  isDeleted: false,
);

const _dhakaCustom = CourtCategory(
  id: 'custom-dhaka',
  nameKey: 'Custom Sessions Court',
  courtLevel: 'lower',
  orderIndex: 9,
  division: divisionDhakaId,
  district: 'dhaka',
  isCustom: true,
  isUserModified: false,
  updatedAt: 0,
  isDeleted: false,
);

const _faridpurCustom = CourtCategory(
  id: 'custom-faridpur',
  nameKey: 'Faridpur Special Court',
  courtLevel: 'lower',
  orderIndex: 10,
  division: divisionDhakaId,
  district: 'faridpur',
  isCustom: true,
  isUserModified: false,
  updatedAt: 0,
  isDeleted: false,
);

const _dhakaCourt = Court(
  id: 'court-dhaka-civil',
  courtName: 'District and Sessions Judge Court, Dhaka',
  higherLowerCourts: lowerCourtsOption,
  division: divisionDhakaId,
  district: 'dhaka',
  courtCategoryId: districtCourtsCivilId,
  orderIndex: 0,
  isCustom: false,
  isUserModified: false,
  updatedAt: 0,
  isDeleted: false,
);

void main() {
  group('districtCourtCategories', () {
    test('hides built-in categories with no court in the district', () {
      final visible = districtCourtCategories(
        categories: const [_civil, _sessions, _dhakaCustom],
        courts: const [_dhakaCourt],
        division: divisionDhakaId,
        district: 'dhaka',
      );

      expect(visible.map((item) => item.id), [
        districtCourtsCivilId,
        'custom-dhaka',
      ]);
    });

    test('keeps a custom category in its own district only', () {
      final dhaka = districtCourtCategories(
        categories: const [_civil, _dhakaCustom, _faridpurCustom],
        courts: const [_dhakaCourt],
        division: divisionDhakaId,
        district: 'dhaka',
      );
      final faridpur = districtCourtCategories(
        categories: const [_civil, _dhakaCustom, _faridpurCustom],
        courts: const [_dhakaCourt],
        division: divisionDhakaId,
        district: 'faridpur',
      );

      expect(dhaka.map((item) => item.id), contains('custom-dhaka'));
      expect(dhaka.map((item) => item.id), isNot(contains('custom-faridpur')));
      expect(faridpur.map((item) => item.id), contains('custom-faridpur'));
      expect(faridpur.map((item) => item.id), isNot(contains('custom-dhaka')));
      // The pre-seeded category has no Faridpur court, so it is hidden there.
      expect(faridpur.map((item) => item.id), isNot(contains(
        districtCourtsCivilId,
      )));
    });

    test('returns every lower category until a district is chosen', () {
      final visible = districtCourtCategories(
        categories: const [_civil, _sessions, _dhakaCustom],
        courts: const [_dhakaCourt],
        division: null,
        district: null,
      );

      expect(visible, hasLength(3));
    });

    test('ignores higher-court categories', () {
      final visible = districtCourtCategories(
        categories: const [
          CourtCategory(
            id: appellateDivisionId,
            nameKey: 'courtCategory_appellateDivision',
            courtLevel: 'appellate',
            orderIndex: 0,
            isCustom: false,
            isUserModified: false,
            updatedAt: 0,
            isDeleted: false,
          ),
          _civil,
        ],
        courts: const [_dhakaCourt],
        division: divisionDhakaId,
        district: 'dhaka',
      );

      expect(visible.map((item) => item.id), [districtCourtsCivilId]);
    });
  });

  group('the pre-seeded hierarchy', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await SeedMigrationRunner(db).runMigrations();
    });

    tearDown(() async {
      await db.close();
    });

    Future<List<String>> district(String districtId) async =>
        districtCourtCategories(
          categories: await CourtCategoriesDao(db).getAll(),
          courts: await CourtsDao(db).getAll(),
          division: divisionDhakaId,
          district: districtId,
        ).map((item) => item.id).toList();

    test('Dhaka offers every category it has courts for, in form order',
        () async {
      // Dhaka has no tribunals in the seed, and tribunals is not a seeded
      // category at all, so it never appears. The rest come back in the same
      // `order_index` serial the Add/Edit Case form reads.
      expect(await district('dhaka'), [
        districtCourtsCivilId,
        districtSessionsCriminalId,
        metropolitanSessionsJudgeCriminalId,
        chiefJudicialMagistrateId,
        chiefMetropolitanMagistrateId,
        executiveMagistrateId,
      ]);
    });

    test('a district without metropolitan or specialised courts omits them',
        () async {
      expect(await district('gopalganj'), [
        districtCourtsCivilId,
        districtSessionsCriminalId,
        chiefJudicialMagistrateId,
        executiveMagistrateId,
      ]);
    });
  });

  group('category ordering helpers', () {
    test('a new category sorts after every existing lower category', () {
      expect(
        nextLowerCourtCategoryOrderIndex(const [_civil, _sessions]),
        _sessions.orderIndex + 1,
      );
    });

    test('reordering reuses the slots the district already occupies', () {
      const tribunal = CourtCategory(
        id: 'tribunal',
        nameKey: 'lowerCourtCategory_tribunals',
        courtLevel: 'lower',
        orderIndex: 5,
        isCustom: false,
        isUserModified: false,
        updatedAt: 0,
        isDeleted: false,
      );
      final targets = reorderedCategoryOrderIndexes(
        canonical: const [_civil, _sessions, _dhakaCustom, tribunal],
        reordered: const [_dhakaCustom, _civil],
      );

      // The district's two categories swap the slots they already hold, and
      // the untouched category keeps its own order.
      expect(targets[_civil.id], 9);
      expect(targets[_dhakaCustom.id], 1);
      expect(canonicalOrder(const [_civil, _sessions, _dhakaCustom, tribunal]),
          [1, 2, 9, 5]);
    });
  });

  group('court categories repository', () {
    late AppDatabase db;
    late CourtCategoriesRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      db = AppDatabase(NativeDatabase.memory());
      final prefs = await SharedPreferences.getInstance();
      final identity = LocalIdentityService(prefs);
      repo = LocalCourtCategoriesRepository(
        CourtCategoriesDao(db),
        SyncWriteHelper(SyncQueueDao(db), identity),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('a category added for a district keeps that scope', () async {
      final id = await repo.insert(
        const CourtCategoriesCompanion(
          nameKey: Value('District Tribunal'),
          courtLevel: Value('lower'),
          orderIndex: Value(9),
          division: Value(divisionRajshahiId),
          district: Value('bogra'),
        ),
      );

      final saved = await repo.getById(id);

      expect(saved!.isCustom, isTrue);
      expect(saved.division, divisionRajshahiId);
      expect(saved.district, 'bogra');
    });

    test('a user-added category can be deleted, a built-in one cannot',
        () async {
      final id = await repo.insert(
        const CourtCategoriesCompanion(
          nameKey: Value('District Tribunal'),
          courtLevel: Value('lower'),
          orderIndex: Value(9),
          division: Value(divisionRajshahiId),
          district: Value('bogra'),
        ),
      );
      await repo.delete((await repo.getById(id))!);
      expect(await repo.getById(id), isNull);

      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await db
          .into(db.courtCategories)
          .insert(
            CourtCategoriesCompanion.insert(
              id: districtCourtsCivilId,
              nameKey: _civilNameKey,
              courtLevel: 'lower',
              orderIndex: 1,
              updatedAt: now,
            ),
          );

      await expectLater(
        repo.delete((await repo.getById(districtCourtsCivilId))!),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('LowerCourtCategoryListScreen', () {
    late _FakeCourtsRepository courtsRepo;
    late _FakeCourtCategoriesRepository categoriesRepo;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      courtsRepo = _FakeCourtsRepository(const [_dhakaCourt]);
      categoriesRepo = _FakeCourtCategoriesRepository(
        const [_civil, _sessions],
      );
    });

    tearDown(() async {
      await categoriesRepo.dispose();
    });

    Future<void> pumpScreen(
      WidgetTester tester, {
      String district = 'dhaka',
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            courtsRepositoryProvider.overrideWith((ref) async => courtsRepo),
            courtCategoriesRepositoryProvider.overrideWith(
              (ref) async => categoriesRepo,
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: LowerCourtCategoryListScreen(
              division: divisionDhakaId,
              district: district,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('lists only the categories with courts in the district',
        (tester) async {
      await pumpScreen(tester);

      expect(find.text('District Judge Court (Civil)'), findsOneWidget);
      expect(find.text('Sessions Judge Court (Criminal)'), findsNothing);
      // Built-in categories cannot be deleted, so they show no delete action.
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('the add button matches the Add Case button and adds a '
        'district-scoped category', (tester) async {
      await pumpScreen(tester);

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.backgroundColor, Colors.black);
      expect(fab.foregroundColor, Colors.white);
      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: find.byType(FloatingActionButton),
                matching: find.byIcon(Icons.add),
              ),
            )
            .size,
        28,
      );
      // Bottom-right, exactly where the Add Case button sits.
      final size = tester.getSize(find.byType(MaterialApp));
      final centre = tester.getCenter(find.byType(FloatingActionButton));
      expect(centre.dx, greaterThan(size.width / 2));
      expect(centre.dy, greaterThan(size.height / 2));

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Metropolitan Court');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Metropolitan Court'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      final saved = (await categoriesRepo.listAll()).firstWhere(
        (item) => item.nameKey == 'Metropolitan Court',
      );
      expect(saved.division, divisionDhakaId);
      expect(saved.district, 'dhaka');
      expect(saved.courtLevel, 'lower');
      expect(saved.orderIndex, 3);

      // The same district list elsewhere must not show it.
      await pumpScreen(tester, district: 'faridpur');
      expect(find.text('Metropolitan Court'), findsNothing);
      expect(find.text('No court categories in this district yet.'),
          findsOneWidget);
    });

    testWidgets('renames a category through the edit dialog', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller
            ?.text,
        'District Judge Court (Civil)',
      );

      await tester.enterText(find.byType(TextFormField), 'Civil Court');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Civil Court'), findsOneWidget);
      expect(
        (await categoriesRepo.getById(districtCourtsCivilId))!.nameKey,
        'Civil Court',
      );
    });

    testWidgets('deletes a category the user added after confirmation',
        (tester) async {
      await pumpScreen(tester);
      await categoriesRepo.insert(
        const CourtCategoriesCompanion(
          nameKey: Value('Metropolitan Court'),
          courtLevel: Value('lower'),
          orderIndex: Value(9),
          division: Value(divisionDhakaId),
          district: Value('dhaka'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Metropolitan Court'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Metropolitan Court'), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });
  });

  group('Add/Edit Case form', () {
    testWidgets('offers the district-scoped category of its district',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            caseWritePermissionsProvider.overrideWith(
              (ref) async =>
                  const CaseWritePermissions(canAdd: true, canEdit: true),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: const Scaffold(
              body: AddEditCaseSheet(
                lookupData: AddEditCaseLookupData(
                  courtCategories: [_civil, _sessions, _dhakaCustom],
                  courts: [_dhakaCourt],
                  lastAddCaseHigherLowerCourt: lowerCourtsOption,
                  lastAddCaseDivision: divisionDhakaId,
                  lastAddCaseDistrict: 'dhaka',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('add-edit-court-category')));
      await tester.pumpAndSettle();

      // The pre-seeded category with a Dhaka court and the user's own
      // Dhaka-only category are both listed; the court-less one is not.
      expect(find.text('District Judge Court (Civil)'), findsOneWidget);
      expect(find.text('Custom Sessions Court'), findsOneWidget);
      expect(find.text('Sessions Judge Court (Criminal)'), findsNothing);
    });
  });
}

/// Convenience accessor documenting the canonical order expectation.
List<int> canonicalOrder(List<CourtCategory> categories) =>
    categories.map((item) => item.orderIndex).toList();

/// In-memory courts repository: the screen only ever reads the list, and a
/// plain stream keeps Drift's query-timer machinery out of widget tests.
class _FakeCourtsRepository implements CourtsRepository {
  _FakeCourtsRepository(this.courts);

  final List<Court> courts;

  @override
  Stream<List<Court>> watchAll({int? limit, int? offset}) async* {
    yield courts;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

/// In-memory court categories repository with change notifications.
class _FakeCourtCategoriesRepository implements CourtCategoriesRepository {
  _FakeCourtCategoriesRepository(List<CourtCategory> initial)
    : _items = List<CourtCategory>.of(initial);

  final List<CourtCategory> _items;
  final StreamController<List<CourtCategory>> _changes =
      StreamController<List<CourtCategory>>.broadcast();
  int _created = 0;

  @override
  Stream<List<CourtCategory>> watchAll({int? limit, int? offset}) async* {
    yield List<CourtCategory>.of(_items);
    yield* _changes.stream;
  }

  @override
  Future<List<CourtCategory>> listAll({int? limit, int? offset}) async =>
      List<CourtCategory>.of(_items);

  @override
  Future<CourtCategory?> getById(String id) async =>
      _items.where((item) => item.id == id).firstOrNull;

  @override
  Future<String> insert(CourtCategoriesCompanion companion) async {
    final id = 'created-${_created++}';
    _items.add(
      CourtCategory(
        id: id,
        nameKey: companion.nameKey.value,
        courtLevel: companion.courtLevel.value,
        orderIndex: companion.orderIndex.value,
        division: companion.division.present ? companion.division.value : null,
        district: companion.district.present ? companion.district.value : null,
        isCustom: true,
        isUserModified: false,
        updatedAt: 0,
        isDeleted: false,
      ),
    );
    _notify();
    return id;
  }

  @override
  Future<void> update(
    CourtCategoriesCompanion companion, {
    CourtCategory? base,
  }) async {
    final index = _items.indexWhere(
      (item) => item.id == companion.id.value,
    );
    _items[index] = _items[index].copyWithCompanion(companion);
    _notify();
  }

  @override
  Future<void> delete(CourtCategory category) async {
    _items.removeWhere((item) => item.id == category.id);
    _notify();
  }

  /// Releases the change stream once a test is done with it.
  Future<void> dispose() => _changes.close();

  void _notify() => _changes.add(List<CourtCategory>.of(_items));
}
