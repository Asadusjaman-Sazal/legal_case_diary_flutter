/// Tests for the Edit Court Names walkthrough (Task 12 Phase 3).
///
/// The screen used to show a single "Supreme Court of Bangladesh" card and, one
/// district down, every court of the district at once. It now splits the
/// Supreme Court into its two divisions, offers a district's court categories
/// as sub-menu cards (the same list the Add/Edit Case form derives), and lists
/// the court names of one category. These tests cover the division cards, the
/// routes they push, the category picker, and the category-scoped court list.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/constants/pre_seeded_data.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/settings/data/court_categories_repository.dart';
import 'package:legal_case_diary/features/settings/data/courts_repository.dart';
import 'package:legal_case_diary/features/settings/presentation/edit_court_steps/court_list_screen.dart';
import 'package:legal_case_diary/features/settings/presentation/edit_court_steps/district_court_category_screen.dart';
import 'package:legal_case_diary/features/settings/presentation/edit_court_steps/edit_court_names_category_screen.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';

/// Built-in civil category (has a Dhaka court in these tests).
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

/// A seeded category with no court in Dhaka: it must not be offered there.
const _executive = CourtCategory(
  id: executiveMagistrateId,
  nameKey: 'lowerCourtCategory_executiveMagistrate',
  courtLevel: 'lower',
  orderIndex: 5,
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

const _dhakaCivilCourt = Court(
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

/// Another Dhaka category's court: it must never appear under [_civil].
const _dhakaSessionsCourt = Court(
  id: 'court-dhaka-sessions',
  courtName: 'Sessions Judge Court, Dhaka',
  higherLowerCourts: lowerCourtsOption,
  division: divisionDhakaId,
  district: 'dhaka',
  courtCategoryId: districtSessionsCriminalId,
  orderIndex: 1,
  isCustom: false,
  isUserModified: false,
  updatedAt: 0,
  isDeleted: false,
);

/// A court the user added to their own Dhaka category.
const _customDhakaCourt = Court(
  id: 'court-dhaka-custom',
  courtName: 'Metropolitan Court, Dhaka',
  higherLowerCourts: lowerCourtsOption,
  division: divisionDhakaId,
  district: 'dhaka',
  courtCategoryId: 'custom-dhaka',
  orderIndex: 0,
  isCustom: true,
  isUserModified: false,
  updatedAt: 0,
  isDeleted: false,
);

const _appellateCourt = Court(
  id: 'court-higher_courts-appellate_division-court_no_1',
  courtName: 'COURT NO. 1',
  higherLowerCourts: higherCourtsOption,
  courtCategoryId: appellateDivisionId,
  orderIndex: 0,
  isCustom: false,
  isUserModified: false,
  updatedAt: 0,
  isDeleted: false,
);

const _highCourtCourt = Court(
  id: 'court-higher_courts-high_court_division-annex_building_court_no_1',
  courtName: 'Annex Building Court No. 1',
  higherLowerCourts: higherCourtsOption,
  courtCategoryId: highCourtDivisionId,
  orderIndex: 0,
  isCustom: false,
  isUserModified: false,
  updatedAt: 0,
  isDeleted: false,
);

/// Where a screen navigated to, captured by the test routers below.
class _Navigation {
  String? location;
  Object? extra;
}

void main() {
  late SharedPreferences prefs;
  late _FakeCourtsRepository courtsRepo;
  late _FakeCourtCategoriesRepository categoriesRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    courtsRepo = _FakeCourtsRepository(const [
      _dhakaCivilCourt,
      _dhakaSessionsCourt,
      _customDhakaCourt,
      _appellateCourt,
      _highCourtCourt,
    ]);
    categoriesRepo = _FakeCourtCategoriesRepository(const [
      _civil,
      _sessions,
      _executive,
      _dhakaCustom,
    ]);
  });

  tearDown(() async {
    await courtsRepo.dispose();
    await categoriesRepo.dispose();
  });

  /// Pumps one screen backed by the fake repositories.
  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    Locale locale = const Locale('en'),
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
          locale: locale,
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Pumps a screen inside a router that records the routes it pushes.
  Future<void> pumpWithRouter(
    WidgetTester tester,
    Widget screen,
    _Navigation navigation,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => screen),
        GoRoute(
          path: AppRoutes.settingsCourtList,
          builder: (context, state) {
            navigation.location = state.uri.toString();
            navigation.extra = state.extra;
            return Scaffold(appBar: AppBar(), body: const Text('court list'));
          },
        ),
        GoRoute(
          path: AppRoutes.settingsCourtCategory,
          builder: (context, state) {
            navigation.location = state.uri.toString();
            navigation.extra = state.extra;
            return Scaffold(appBar: AppBar(), body: const Text('divisions'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          courtsRepositoryProvider.overrideWith((ref) async => courtsRepo),
          courtCategoriesRepositoryProvider.overrideWith(
            (ref) async => categoriesRepo,
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('EditCourtNamesCategoryScreen', () {
    testWidgets('is titled Edit Court Names and shows the Supreme Court as its '
        'two divisions', (tester) async {
      await pumpScreen(tester, const EditCourtNamesCategoryScreen());

      expect(find.text('Edit Court Names'), findsOneWidget);
      expect(find.text('Appellate Division'), findsOneWidget);
      expect(find.text('High Court Division'), findsOneWidget);
      expect(find.text('Supreme Court of Bangladesh'), findsNothing);
      expect(find.text('Lower Courts'), findsOneWidget);
    });

    testWidgets('the division cards open that division\'s court names', (
      tester,
    ) async {
      final navigation = _Navigation();
      await pumpWithRouter(
        tester,
        const EditCourtNamesCategoryScreen(),
        navigation,
      );

      await tester.tap(find.text('Appellate Division'));
      await tester.pumpAndSettle();
      expect(navigation.location, contains('higherLower=higher_courts'));
      expect(navigation.location, contains('category=$appellateDivisionId'));
      // The label travels with the route so the header can name the division.
      expect(navigation.extra, 'courtCategory_appellateDivision');

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('High Court Division'));
      await tester.pumpAndSettle();
      expect(navigation.location, contains('category=$highCourtDivisionId'));
      expect(navigation.extra, 'courtCategory_highCourtDivision');
    });

    testWidgets('the Lower Courts card opens the division picker', (
      tester,
    ) async {
      final navigation = _Navigation();
      await pumpWithRouter(
        tester,
        const EditCourtNamesCategoryScreen(),
        navigation,
      );

      await tester.tap(find.text('Lower Courts'));
      await tester.pumpAndSettle();

      expect(navigation.location, AppRoutes.settingsCourtCategory);
    });
  });

  group('CourtListScreen per division', () {
    Future<void> pumpDivision(
      WidgetTester tester, {
      required String categoryId,
      required String nameKey,
    }) => pumpScreen(
      tester,
      CourtListScreen(
        category: categoryId,
        higherLower: higherCourtsOption,
        categoryNameKey: nameKey,
      ),
    );

    testWidgets('lists only that division\'s court names', (tester) async {
      await pumpDivision(
        tester,
        categoryId: appellateDivisionId,
        nameKey: 'courtCategory_appellateDivision',
      );

      expect(find.text('COURT NO. 1'), findsOneWidget);
      expect(find.text('Annex Building Court No. 1'), findsNothing);
      // The header names the division, so the two screens are distinguishable.
      expect(find.text('Appellate Division'), findsOneWidget);
    });

    testWidgets('the other division shows its own names', (tester) async {
      await pumpDivision(
        tester,
        categoryId: highCourtDivisionId,
        nameKey: 'courtCategory_highCourtDivision',
      );

      expect(find.text('Annex Building Court No. 1'), findsOneWidget);
      expect(find.text('COURT NO. 1'), findsNothing);
      expect(find.text('High Court Division'), findsOneWidget);
    });

    testWidgets('seeded court names follow the active language', (
      tester,
    ) async {
      // A real pre-seeded court, so the Bengali label comes from the seed data
      // exactly like the Add/Edit Case form reads it.
      final seed = allSeedCourts.firstWhere(
        (court) =>
            court.higherLowerCourts == lowerCourtsOption &&
            court.district == 'dhaka',
      );
      final court = Court(
        id: seed.id,
        courtName: seed.courtNameEn,
        higherLowerCourts: seed.higherLowerCourts,
        division: seed.division,
        district: seed.district,
        courtCategoryId: seed.courtCategoryId,
        orderIndex: seed.orderIndex,
        isCustom: false,
        isUserModified: false,
        updatedAt: 0,
        isDeleted: false,
      );
      await courtsRepo.dispose();
      courtsRepo = _FakeCourtsRepository([court]);

      await pumpScreen(
        tester,
        CourtListScreen(
          category: seed.courtCategoryId,
          higherLower: lowerCourtsOption,
          division: seed.division,
          district: seed.district,
        ),
        locale: const Locale('bn'),
      );

      expect(find.text(courtLabelBn[seed.id]!), findsOneWidget);
      expect(find.text(seed.courtNameEn), findsNothing);
    });
  });

  group('DistrictCourtCategoryScreen', () {
    Future<void> pumpDistrict(
      WidgetTester tester, {
      String district = 'dhaka',
    }) => pumpScreen(
      tester,
      DistrictCourtCategoryScreen(
        division: divisionDhakaId,
        district: district,
      ),
    );

    testWidgets('offers the district\'s categories, in the form\'s order', (
      tester,
    ) async {
      await pumpDistrict(tester);

      expect(find.text('Dhaka Court Categories'), findsOneWidget);
      // The seeded categories with a Dhaka court and the user's own one; the
      // seeded category with no court there is not offered.
      expect(find.text('District Judge Court (Civil)'), findsOneWidget);
      expect(find.text('Sessions Judge Court (Criminal)'), findsOneWidget);
      expect(find.text('Custom Sessions Court'), findsOneWidget);
      expect(find.text('Executive Magistrate & Other Courts'), findsNothing);
    });

    testWidgets('says so when a district has no categories yet', (
      tester,
    ) async {
      await pumpDistrict(tester, district: 'faridpur');

      expect(
        find.text('No court categories in this district yet.'),
        findsOneWidget,
      );
      expect(find.text('District Judge Court (Civil)'), findsNothing);
    });

    testWidgets('a category card opens that category\'s court names', (
      tester,
    ) async {
      final navigation = _Navigation();
      await pumpWithRouter(
        tester,
        const DistrictCourtCategoryScreen(
          division: divisionDhakaId,
          district: 'dhaka',
        ),
        navigation,
      );

      await tester.tap(find.text('District Judge Court (Civil)'));
      await tester.pumpAndSettle();

      expect(navigation.location, contains('higherLower=lower_courts'));
      expect(navigation.location, contains('division=$divisionDhakaId'));
      expect(navigation.location, contains('district=dhaka'));
      expect(navigation.location, contains('category=$districtCourtsCivilId'));
      expect(navigation.extra, _civilNameKey);
    });
  });

  group('CourtListScreen per district category', () {
    Future<void> pumpCategory(
      WidgetTester tester, {
      required String categoryId,
      required String nameKey,
    }) => pumpScreen(
      tester,
      CourtListScreen(
        category: categoryId,
        higherLower: lowerCourtsOption,
        division: divisionDhakaId,
        district: 'dhaka',
        categoryNameKey: nameKey,
      ),
    );

    testWidgets('lists only the courts of that category', (tester) async {
      await pumpCategory(
        tester,
        categoryId: districtCourtsCivilId,
        nameKey: _civilNameKey,
      );

      expect(find.text(_dhakaCivilCourt.courtName), findsOneWidget);
      // The same district's other category stays out of this list.
      expect(find.text(_dhakaSessionsCourt.courtName), findsNothing);
      expect(find.text(_customDhakaCourt.courtName), findsNothing);
      expect(find.text('District Judge Court (Civil)'), findsOneWidget);
    });

    testWidgets('adds a court to the category it is listing, through the Add '
        'Case style button', (tester) async {
      await pumpCategory(
        tester,
        categoryId: districtCourtsCivilId,
        nameKey: _civilNameKey,
      );

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
      await tester.enterText(find.byType(TextFormField), 'Magistrate Court');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Magistrate Court'), findsOneWidget);
      final added = (await courtsRepo.listAll()).firstWhere(
        (court) => court.courtName == 'Magistrate Court',
      );
      expect(added.courtCategoryId, districtCourtsCivilId);
      expect(added.division, divisionDhakaId);
      expect(added.district, 'dhaka');
      expect(added.higherLowerCourts, lowerCourtsOption);
    });

    testWidgets('offers delete only on courts the user added', (tester) async {
      await pumpCategory(
        tester,
        categoryId: districtCourtsCivilId,
        nameKey: _civilNameKey,
      );
      // A pre-seeded court cannot be deleted, so it offers no delete action.
      expect(find.text(_dhakaCivilCourt.courtName), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsNothing);

      await pumpCategory(
        tester,
        categoryId: 'custom-dhaka',
        nameKey: 'Custom Sessions Court',
      );
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(
        (await courtsRepo.listAll()).map((court) => court.id),
        isNot(contains(_customDhakaCourt.id)),
      );
    });

    testWidgets('renames a court through the edit dialog', (tester) async {
      await pumpCategory(
        tester,
        categoryId: districtCourtsCivilId,
        nameKey: _civilNameKey,
      );

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller
            ?.text,
        _dhakaCivilCourt.courtName,
      );

      await tester.enterText(find.byType(TextFormField), 'Civil Court, Dhaka');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Civil Court, Dhaka'), findsOneWidget);
    });
  });
}

/// In-memory courts repository: the screens only read streams (and add, edit or
/// delete one court), and plain streams keep Drift's query-timer machinery out
/// of widget tests.
class _FakeCourtsRepository implements CourtsRepository {
  _FakeCourtsRepository(List<Court> courts) : _items = List<Court>.of(courts);

  final List<Court> _items;
  final StreamController<List<Court>> _changes =
      StreamController<List<Court>>.broadcast();
  int _created = 0;

  @override
  Stream<List<Court>> watchAll({int? limit, int? offset}) async* {
    yield List<Court>.of(_items);
    yield* _changes.stream;
  }

  @override
  Stream<List<Court>> watchByCategory(String categoryId) async* {
    List<Court> matching(List<Court> courts) => courts
        .where((court) => court.courtCategoryId == categoryId)
        .toList(growable: false);

    yield matching(_items);
    yield* _changes.stream.map(matching);
  }

  @override
  Future<List<Court>> listAll({int? limit, int? offset}) async =>
      List<Court>.of(_items);

  @override
  Future<String> insert(CourtsCompanion companion) async {
    final id = 'created-${_created++}';
    _items.add(
      Court(
        id: id,
        courtName: companion.courtName.value,
        higherLowerCourts: companion.higherLowerCourts.value,
        division: companion.division.present ? companion.division.value : null,
        district: companion.district.present ? companion.district.value : null,
        courtCategoryId: companion.courtCategoryId.value,
        orderIndex: companion.orderIndex.value,
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
  Future<void> update(CourtsCompanion companion, {Court? base}) async {
    final index = _items.indexWhere((court) => court.id == companion.id.value);
    _items[index] = _items[index].copyWithCompanion(companion);
    _notify();
  }

  @override
  Future<void> delete(Court court) async {
    _items.removeWhere((item) => item.id == court.id);
    _notify();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  /// Releases the change stream once a test is done with it.
  Future<void> dispose() => _changes.close();

  void _notify() => _changes.add(List<Court>.of(_items));
}

/// In-memory court categories repository with change notifications.
class _FakeCourtCategoriesRepository implements CourtCategoriesRepository {
  _FakeCourtCategoriesRepository(List<CourtCategory> initial)
    : _items = List<CourtCategory>.of(initial);

  final List<CourtCategory> _items;
  final StreamController<List<CourtCategory>> _changes =
      StreamController<List<CourtCategory>>.broadcast();

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  /// Releases the change stream once a test is done with it.
  Future<void> dispose() => _changes.close();
}
