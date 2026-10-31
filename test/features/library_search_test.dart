/// Search-box tests for the Notes and Case Reference libraries.
///
/// Both screens rendered the shared `ScopedSearchBar` as the first row of their
/// scrolling list — so it scrolled away with the rows, sat inside the list's
/// padding, and was thrown away entirely whenever the library was empty. The bar
/// is now mounted by `CasesScreenModal`, exactly as on the case-list screens:
/// under the header, above the list, and on screen even with nothing to filter.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/constants/app_spacing.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/core/theme/app_theme.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/database/seed_migration_runner.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/features/case_reference/data/local/case_references_dao.dart';
import 'package:legal_case_diary/features/case_reference/data/reference_repository.dart';
import 'package:legal_case_diary/features/case_reference/presentation/case_reference_screen.dart';
import 'package:legal_case_diary/features/case_reference/presentation/reference_library.dart';
import 'package:legal_case_diary/features/cases/presentation/cases_screen_modal.dart';
import 'package:legal_case_diary/features/notes/data/local/notes_dao.dart';
import 'package:legal_case_diary/features/notes/data/notes_repository.dart';
import 'package:legal_case_diary/features/notes/presentation/notes_screen.dart';
import 'package:legal_case_diary/features/settings/data/local/user_preferences_dao.dart';
import 'package:legal_case_diary/features/settings/data/settings_repository.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_menu_card.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:legal_case_diary/shared/widgets/add_edit_case_sheet.dart';
import 'package:legal_case_diary/sync/sync_queue_dao.dart';
import 'package:legal_case_diary/sync/sync_write_helper.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late LocalIdentityService identity;
  late LocalNotesRepository notes;
  late LocalReferenceRepository references;
  late LocalSettingsRepository settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    identity = LocalIdentityService(prefs);
    db = AppDatabase(NativeDatabase.memory());
    final sync = SyncWriteHelper(SyncQueueDao(db), identity);
    notes = LocalNotesRepository(NotesDao(db), sync);
    references = LocalReferenceRepository(CaseReferencesDao(db), sync);
    settings = LocalSettingsRepository(UserPreferencesDao(db), identity);
  });

  tearDown(() async => db.close());

  test('tags are split, canonicalized and listed alphabetically', () {
    expect(referenceTags(' bail,  Evidence ,, bail '), ['bail', 'Evidence']);
    expect(
      canonicalReferenceTags(' bail,  Evidence ,, bail '),
      'bail, Evidence',
    );
    expect(canonicalReferenceTags(' , '), isNull);
    expect(tagVocabulary(<String?>['trial, bail', 'Bail, evidence', null]), [
      'bail',
      'evidence',
      'trial',
    ]);
  });

  /// Pumps a bounded number of frames.
  ///
  /// Both libraries hold a live Drift stream subscription, so this suite waits
  /// for the widgets under test instead of `pumpAndSettle` — that would wait for
  /// the frame pipeline itself to go quiet.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
  }

  /// The app's providers for these two libraries, shared by every pump below.
  ///
  /// A free account, stated rather than assumed: these two libraries carry the
  /// same header as the case lists, and sync is off for free.
  List<Override> libraryOverrides() => [
    sharedPreferencesProvider.overrideWithValue(prefs),
    databaseProvider.overrideWith((_) async => db),
    localIdentityServiceProvider.overrideWith((_) => identity),
    settingsRepositoryProvider.overrideWith((_) async => settings),
    notesRepositoryProvider.overrideWith((_) async => notes),
    referenceRepositoryProvider.overrideWith((_) async => references),
    caseWritePermissionsProvider.overrideWith(
      (_) async => const CaseWritePermissions(canAdd: true, canEdit: true),
    ),
    premiumAccessProvider.overrideWith((ref) async => false),
  ];

  /// Pumps one library with the app's providers, router and localizations.
  Future<void> pumpLibrary(WidgetTester tester, Widget screen) async {
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => screen)],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: libraryOverrides(),
        child: MaterialApp.router(
          // The app's own theme, so `titleMedium` resolves to the semibold face
          // the empty state is expected to borrow from the case lists.
          theme: AppTheme.lightTheme(const Locale('en')),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await settle(tester);
  }

  /// Tears the widgets down before the test ends.
  ///
  /// Disposing the provider container while Drift's query streams are still
  /// live schedules a timer, which the test binding reports as pending; pumping
  /// a bare tree here lets it fire inside the test.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// Opens the scoped search bar from the header's search icon.
  Future<void> openSearch(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.search));
    await settle(tester);
  }

  Future<void> seedNote(String id, String title, String body) =>
      notes.insertNote(
        NotesCompanion(
          id: Value(id),
          userId: Value(identity.getId()),
          title: Value(title),
          body: Value(body),
          createdAt: const Value(1),
          updatedAt: const Value(1),
        ),
      );

  Future<void> seedReference(
    String id,
    String citation,
    String description, {
    String? statute,
    String? parties,
    String? section,
    String? caseNote,
    String? tags,
  }) => references.insertReference(
    CaseReferencesCompanion(
      id: Value(id),
      userId: Value(identity.getId()),
      referenceAndPageNo: Value(citation),
      parties: Value(parties),
      statute: Value(statute),
      sectionOrArticle: Value(section),
      titleAndDescription: Value(description),
      caseNote: Value(caseNote),
      tags: Value(tags),
      createdAt: const Value(1),
      updatedAt: const Value(1),
    ),
  );

  testWidgets('both libraries open the bar above the list, empty or not', (
    tester,
  ) async {
    for (final screen in <Widget>[
      const NotesScreen(),
      const CaseReferenceScreen(),
    ]) {
      final name = screen.runtimeType.toString();
      await pumpLibrary(tester, screen);

      // Closed until the header's search icon opens it, as on the case lists.
      expect(find.byType(ScopedSearchBar), findsNothing, reason: name);
      await openSearch(tester);

      expect(find.byType(ScopedSearchBar), findsOneWidget, reason: name);
      // Mounted by the modal, not as the list's first row: the old inline
      // placement also lost the bar as soon as the library had no rows.
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(ScopedSearchBar),
        ),
        findsNothing,
        reason: '$name keeps the bar inside the list',
      );
      // The bar sits above the body: the scrolled rows when the library has
      // any, the centred "nothing yet" message when it has none — the empty
      // state has no list at all, exactly like the case lists'.
      final listFinder = find.byType(ListView);
      final body = listFinder.evaluate().isNotEmpty
          ? listFinder.first
          : find
                .descendant(
                  of: find.byType(Expanded),
                  matching: find.byType(Center),
                )
                .first;
      final bar = tester.getRect(find.byType(ScopedSearchBar));
      expect(
        bar.bottom,
        lessThanOrEqualTo(tester.getRect(body).top + 0.01),
        reason: '$name does not sit the bar above the body',
      );

      // The (x) closes the search, as on the case lists.
      await tester.tap(find.byIcon(Icons.close));
      await settle(tester);
      expect(find.byType(ScopedSearchBar), findsNothing, reason: name);

      await unmount(tester);
    }
  });

  testWidgets(
    'an empty library centres its message, semibold, like the case lists',
    (tester) async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      final screens = <(Widget, String)>[
        (const NotesScreen(), l.notesScreen_empty),
        (const CaseReferenceScreen(), l.caseReferenceScreen_empty),
      ];

      for (final (screen, message) in screens) {
        final name = screen.runtimeType.toString();
        await pumpLibrary(tester, screen);

        final messageRect = tester.getRect(find.text(message));
        final bodyRect = tester.getRect(
          find
              .descendant(
                of: find.byType(Expanded),
                matching: find.byType(Center),
              )
              .first,
        );
        // Middle of the body, not the top of a list.
        expect(
          (messageRect.center.dy - bodyRect.center.dy).abs(),
          lessThan(1.0),
          reason: '$name does not centre its message vertically',
        );
        expect(
          (messageRect.center.dx - bodyRect.center.dx).abs(),
          lessThan(1.0),
          reason: '$name does not centre its message horizontally',
        );

        // The Active Cases weight and size: titleMedium.
        final style = tester.widget<Text>(find.text(message)).style;
        expect(style?.fontWeight, FontWeight.w600, reason: name);
        expect(style?.fontSize, 16.0, reason: name);

        await unmount(tester);
      }
    },
  );

  testWidgets('the Notes query filters the library and can be cleared', (
    tester,
  ) async {
    await seedNote('note-1', 'Bail application', 'Filed before the CMM.');
    await seedNote('note-2', 'Property dispute', 'Partition suit.');
    await pumpLibrary(tester, const NotesScreen());

    await openSearch(tester);
    await tester.enterText(find.byType(TextField), 'bail');
    await settle(tester);

    expect(find.text('Bail application'), findsOneWidget);
    expect(find.text('Property dispute'), findsNothing);

    // The (x) closes the search and clears it, so the list comes back whole.
    await tester.tap(find.byIcon(Icons.close));
    await settle(tester);
    expect(find.text('Property dispute'), findsOneWidget);
    await openSearch(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '',
    );

    await unmount(tester);
  });

  testWidgets(
    'Case Reference reads as a law list, then that law\'s references',
    (tester) async {
      // Seeded so the law names land under their own category heading.
      await SeedMigrationRunner(db).runMigrations();
      await seedReference(
        'ref-1',
        '45 DLR (AD) 1',
        'Bail guidelines.',
        statute: 'The Penal Code, 1860',
      );
      await seedReference(
        'ref-2',
        '46 DLR (AD) 2',
        'Bail conditions.',
        statute: 'The Penal Code, 1860',
      );
      await seedReference('ref-3', '12 BLC 99', 'Partition.', statute: null);
      await pumpLibrary(tester, const CaseReferenceScreen());

      // Level 1: law names only — under the law's category, with its count. The
      // citations themselves belong to the law's own page.
      expect(find.text('Criminal Law'), findsOneWidget);
      expect(find.text('The Penal Code, 1860'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('law-row-The Penal Code, 1860')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      // The row wears the Account & Profile sub-menu card, minus its icon.
      expect(
        tester
            .widget<SettingsMenuCard>(
              find.byKey(const ValueKey('law-row-The Penal Code, 1860')),
            )
            .icon,
        isNull,
      );
      expect(find.text('No statute'), findsOneWidget);
      expect(find.textContaining('45 DLR'), findsNothing);

      // Tapping the law opens its references, and only its own.
      await tester.tap(find.text('The Penal Code, 1860'));
      await settle(tester);
      expect(find.textContaining('45 DLR'), findsOneWidget);
      expect(find.textContaining('46 DLR'), findsOneWidget);
      expect(find.textContaining('12 BLC'), findsNothing);

      // The arrow returns to the law list.
      await tester.tap(find.byKey(const ValueKey('law-back')));
      await settle(tester);
      expect(find.text('The Penal Code, 1860'), findsOneWidget);
      expect(find.textContaining('45 DLR'), findsNothing);

      await unmount(tester);
    },
  );

  testWidgets('the open law survives leaving the screen and coming back', (
    tester,
  ) async {
    await SeedMigrationRunner(db).runMigrations();
    await seedReference(
      'ref-1',
      '45 DLR (AD) 1',
      'Bail guidelines.',
      statute: 'The Penal Code, 1860',
    );

    // One ProviderScope for both visits, as the app has: only the screen is
    // swapped, the way a bottom-nav tab replaces the page.
    final showingReferences = ValueNotifier<bool>(true);
    addTearDown(showingReferences.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => ValueListenableBuilder<bool>(
            valueListenable: showingReferences,
            builder: (context, showReferences, _) => showReferences
                ? const CaseReferenceScreen()
                : const Scaffold(body: SizedBox.shrink()),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: libraryOverrides(),
        child: MaterialApp.router(
          theme: AppTheme.lightTheme(const Locale('en')),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await settle(tester);

    // Inside the law.
    await tester.tap(find.text('The Penal Code, 1860'));
    await settle(tester);
    expect(find.byKey(const ValueKey('law-back')), findsOneWidget);
    expect(find.textContaining('45 DLR'), findsOneWidget);

    // Leave for another bottom-nav screen, then come back.
    showingReferences.value = false;
    await settle(tester);
    showingReferences.value = true;
    await settle(tester);

    // Still inside the same law, not the law list.
    expect(find.byKey(const ValueKey('law-back')), findsOneWidget);
    expect(find.textContaining('45 DLR'), findsOneWidget);
    expect(find.text('Criminal Law'), findsNothing);

    await unmount(tester);
  });

  testWidgets('an official citation is marked, read-only and pinnable', (
    tester,
  ) async {
    // The admin-curated library is a pull-only cache: it appears in the same
    // levels as the user's own citations, but this device may only pin it.
    await db
        .into(db.sharedCaseReferences)
        .insert(
          SharedCaseReferencesCompanion.insert(
            id: 'official-1',
            referenceAndPageNo: '29 DLR (AD) 69',
            statute: const Value('The Penal Code, 1860'),
            sectionOrArticle: const Value('Section 54'),
            titleAndDescription: const Value('Bail guidelines.'),
          ),
        );
    await pumpLibrary(tester, const CaseReferenceScreen());

    // It builds its own law row, so the library's first level lists it like
    // any other law that holds references.
    expect(find.text('The Penal Code, 1860'), findsOneWidget);
    await tester.tap(find.text('The Penal Code, 1860'));
    await settle(tester);

    expect(find.text('Official'), findsOneWidget);
    expect(find.textContaining('29 DLR'), findsOneWidget);

    // Line 1 centres the citation, the Official mark and the menu on one line,
    // and the menu wears the card's own 4 px edge (user request).
    final citationCenter = tester.getCenter(find.textContaining('29 DLR'));
    final officialCenter = tester.getCenter(find.text('Official'));
    final menuCenter = tester.getCenter(
      find.byKey(const ValueKey('reference-menu')),
    );
    expect((citationCenter.dy - officialCenter.dy).abs(), lessThan(0.5));
    expect((citationCenter.dy - menuCenter.dy).abs(), lessThan(0.5));
    final menuShape =
        tester
                .widget<PopupMenuButton<String>>(
                  find.byKey(const ValueKey('reference-menu')),
                )
                .shape!
            as RoundedRectangleBorder;
    expect(
      menuShape.borderRadius,
      BorderRadius.circular(AppSpacing.cardRadius),
    );
    expect(menuShape.side.color, AppColors.cardBorder);

    // Tapping the card opens no editor: the entry is the admins' to change.
    await tester.tap(find.textContaining('29 DLR'));
    await settle(tester);
    expect(find.byKey(const ValueKey('reference-title')), findsNothing);

    // Its menu offers Pin and not Delete.
    await tester.tap(find.byKey(const ValueKey('reference-menu')));
    await settle(tester);
    expect(find.byKey(const ValueKey('reference-pin')), findsOneWidget);
    expect(find.byKey(const ValueKey('reference-delete')), findsNothing);

    // Pinning writes this device's own pin row and queues nothing: an official
    // row is never pushed anywhere.
    await tester.tap(find.byKey(const ValueKey('reference-pin')));
    await settle(tester);
    final pins = await db.select(db.sharedCaseReferencePins).get();
    expect(pins.single.referenceId, 'official-1');
    expect(await SyncQueueDao(db).getUnresolved(), isEmpty);

    await unmount(tester);
  });

  testWidgets('search finds a citation whatever law it is filed under', (
    tester,
  ) async {
    await seedReference(
      'ref-1',
      '45 DLR (AD) 1',
      'Bail guidelines.',
      statute: 'The Penal Code, 1860',
    );
    await seedReference(
      'ref-2',
      '12 BLC 99',
      'Partition of ancestral land.',
      statute: 'The Code of Civil Procedure, 1908',
    );
    await pumpLibrary(tester, const CaseReferenceScreen());
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    // From the law list the query reads the citation cards, not the law names,
    // so a citation's own words find it with no law open.
    await openSearch(tester);
    await tester.enterText(find.byType(TextField), 'dlr');
    await settle(tester);
    expect(find.textContaining('45 DLR'), findsOneWidget);
    expect(find.textContaining('12 BLC'), findsNothing);
    expect(
      find.byKey(const ValueKey('law-row-The Penal Code, 1860')),
      findsNothing,
    );

    // A query matching nothing says so, rather than hiding behind the laws.
    await tester.enterText(find.byType(TextField), 'no such citation');
    await settle(tester);
    expect(find.text(l.sharedDialogs_noResults), findsOneWidget);

    // The same holds on a law's page: the query leaves that law and reads the
    // whole library, so another law's citation is found.
    await tester.tap(find.byIcon(Icons.close));
    await settle(tester);
    await tester.tap(find.text('The Code of Civil Procedure, 1908'));
    await settle(tester);
    await openSearch(tester);
    await tester.enterText(find.byType(TextField), 'dlr');
    await settle(tester);
    expect(find.textContaining('45 DLR'), findsOneWidget);
    expect(find.textContaining('12 BLC'), findsNothing);

    // Clearing the query returns to the level being read.
    await tester.enterText(find.byType(TextField), '');
    await settle(tester);
    expect(find.textContaining('12 BLC'), findsOneWidget);
    expect(find.textContaining('45 DLR'), findsNothing);

    await unmount(tester);
  });

  testWidgets('an official citation is found by search, wherever it is filed', (
    tester,
  ) async {
    // The user's own card sits under one law; the official citation under
    // another. The official cache's search used to compare against a `%…%`
    // pattern, so no official row could ever match and results looked as if
    // only the user's own (first) law existed.
    await seedReference(
      'ref-1',
      '45 DLR (AD) 1',
      'Bail guidelines.',
      statute: 'The Penal Code, 1860',
    );
    await db
        .into(db.sharedCaseReferences)
        .insert(
          SharedCaseReferencesCompanion.insert(
            id: 'official-1',
            referenceAndPageNo: '68 DLR (AD) 290',
            statute: const Value('The Code of Criminal Procedure, 1898'),
            sectionOrArticle: const Value('Section 161'),
            titleAndDescription: const Value('Investigation by the police.'),
          ),
        );
    await pumpLibrary(tester, const CaseReferenceScreen());

    // From the law list, the official card is found across the whole library.
    await openSearch(tester);
    await tester.enterText(find.byType(TextField), '68 dlr');
    await settle(tester);
    expect(find.text('68 DLR (AD) 290'), findsOneWidget);
    expect(find.text('45 DLR (AD) 1'), findsNothing);

    // From inside the law that holds only the official citation — the
    // reported flow — the same card is found.
    await tester.tap(find.byIcon(Icons.close));
    await settle(tester);
    await tester.tap(find.text('The Code of Criminal Procedure, 1898'));
    await settle(tester);
    await openSearch(tester);
    await tester.enterText(find.byType(TextField), '68 DLR');
    await settle(tester);
    expect(find.text('68 DLR (AD) 290'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('the shared Add Case Reference form saves a citation', (
    tester,
  ) async {
    // The user's window and the Admin Panel's official window now draw one
    // shared form (0.0.755). This pins the user's side of it: its own title,
    // and a save that lands in the user's own library.
    await pumpLibrary(tester, const CaseReferenceScreen());
    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);
    expect(find.text('Add Case Reference'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('reference-form-citation')),
      '68 DLR (AD) 290',
    );
    await tester.tap(find.byKey(const ValueKey('reference-form-save')));
    // The save crosses the allowance check, the database and then the route's
    // pop animation, so pump until the window is gone rather than for a fixed
    // number of frames.
    for (
      var i = 0;
      i < 40 &&
          find.byKey(const ValueKey('reference-title')).evaluate().isNotEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byKey(const ValueKey('reference-title')), findsNothing);
    final rows = await CaseReferencesDao(db).getAll();
    expect(rows.single.referenceAndPageNo, '68 DLR (AD) 290');
    // With no law chosen it is reachable under No statute, as before.
    expect(find.text('No statute'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets(
    'a citation keeps its case note and tags, and both are searchable',
    (tester) async {
      await seedReference(
        'ref-1',
        '45 DLR (AD) 1',
        'Bail guidelines.',
        statute: 'The Penal Code, 1860',
        parties: 'State v. Karim',
        caseNote: 'Witness turned hostile.',
        tags: 'bail, evidence',
      );
      await seedReference(
        'ref-2',
        '12 BLC 99',
        'Partition.',
        statute: 'The Penal Code, 1860',
        parties: 'Rahman v. Salam',
        caseNote: 'Survey record missing.',
        tags: 'bail',
      );
      await pumpLibrary(tester, const CaseReferenceScreen());

      // The parties, each tag as its own chip, and the case note all read.
      await tester.tap(find.text('The Penal Code, 1860'));
      await settle(tester);
      expect(find.text('State v. Karim'), findsOneWidget);
      expect(find.text('evidence'), findsOneWidget);
      expect(find.text('Witness turned hostile.'), findsOneWidget);
      expect(find.text('bail'), findsNWidgets(2));

      // The parties, the case note and a tag each find their citation.
      await openSearch(tester);
      await tester.enterText(find.byType(TextField), 'hostile');
      await settle(tester);
      expect(find.textContaining('45 DLR'), findsOneWidget);
      expect(find.textContaining('12 BLC'), findsNothing);

      await tester.enterText(find.byType(TextField), 'karim');
      await settle(tester);
      expect(find.textContaining('45 DLR'), findsOneWidget);
      expect(find.textContaining('12 BLC'), findsNothing);

      await tester.enterText(find.byType(TextField), 'evidence');
      await settle(tester);
      expect(find.textContaining('45 DLR'), findsOneWidget);
      expect(find.textContaining('12 BLC'), findsNothing);

      // A shared tag finds every citation carrying it.
      await tester.enterText(find.byType(TextField), 'bail');
      await settle(tester);
      expect(find.textContaining('45 DLR'), findsOneWidget);
      expect(find.textContaining('12 BLC'), findsOneWidget);

      await unmount(tester);
    },
  );

  testWidgets('every shown line keeps the first line gap above it', (
    tester,
  ) async {
    await seedReference(
      'ref-1',
      '45 DLR (AD) 1',
      'Bail guidelines.',
      statute: 'The Penal Code, 1860',
      parties: 'State v. Karim',
      section: 'Section 54',
      caseNote: 'Witness turned hostile.',
      tags: 'bail, evidence',
    );
    // No Act/Law, Section or Tags: the case note must still take the same gap
    // above it (user request).
    await seedReference(
      'ref-2',
      '12 BLC 99',
      'Partition.',
      parties: 'Rahman v. Salam',
      caseNote: 'Survey record missing.',
    );
    await pumpLibrary(tester, const CaseReferenceScreen());
    await openSearch(tester);

    double gap(Finder above, Finder below) =>
        tester.getTopLeft(below).dy - tester.getBottomLeft(above).dy;

    // A card with every line shown uses the first line's gap throughout.
    await tester.enterText(find.byType(TextField), '45 DLR');
    await settle(tester);
    final heading = find.byKey(const ValueKey('reference-card-heading'));
    expect(gap(heading, find.text('State v. Karim')), closeTo(4, 0.01));
    expect(
      gap(find.text('State v. Karim'), find.text('The Penal Code, 1860')),
      closeTo(4, 0.01),
    );
    expect(
      gap(find.text('The Penal Code, 1860'), find.text('Section 54')),
      closeTo(4, 0.01),
    );
    expect(
      gap(find.text('Section 54'), find.text('Witness turned hostile.')),
      closeTo(6, 0.01),
    );
    expect(
      gap(
        find.text('Witness turned hostile.'),
        find.byKey(const ValueKey('reference-card-tags')),
      ),
      closeTo(6, 0.01),
    );

    // A card with empty lines skipped keeps the same gap above the next line.
    await tester.enterText(find.byType(TextField), '12 BLC');
    await settle(tester);
    expect(
      gap(
        find.byKey(const ValueKey('reference-card-heading')),
        find.text('Rahman v. Salam'),
      ),
      closeTo(4, 0.01),
    );
    expect(
      gap(find.text('Rahman v. Salam'), find.text('Survey record missing.')),
      closeTo(6, 0.01),
    );

    await unmount(tester);
  });

  testWidgets(
    'the shared form reuses an existing tag and saves the case note',
    (tester) async {
      await seedReference(
        'ref-1',
        '45 DLR (AD) 1',
        'Bail guidelines.',
        tags: 'evidence, trial',
      );
      await pumpLibrary(tester, const CaseReferenceScreen());
      await tester.tap(find.byType(FloatingActionButton));
      await settle(tester);

      await tester.enterText(
        find.byKey(const ValueKey('reference-form-citation')),
        '68 DLR (AD) 290',
      );
      await tester.enterText(
        find.byKey(const ValueKey('reference-form-parties')),
        'State v. Karim',
      );
      await tester.enterText(
        find.byKey(const ValueKey('reference-form-case-note')),
        'Client in custody.',
      );

      // The Tags box lists the library's existing tags alphabetically.
      await tester.drag(
        find.byKey(const ValueKey('reference-form-scroll')),
        const Offset(0, -400),
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('reference-tags-menu')));
      for (
        var i = 0;
        i < 10 &&
            find
                .byKey(const ValueKey('reference-tag-option-evidence'))
                .evaluate()
                .isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final evidence = tester.getTopLeft(
        find.byKey(const ValueKey('reference-tag-option-evidence')),
      );
      final trial = tester.getTopLeft(
        find.byKey(const ValueKey('reference-tag-option-trial')),
      );
      expect(evidence.dy, lessThan(trial.dy));
      await tester.tap(
        find.byKey(const ValueKey('reference-tag-option-evidence')),
      );
      await settle(tester);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('reference-form-tags')),
            )
            .controller!
            .text,
        'evidence',
      );

      await tester.tap(find.byKey(const ValueKey('reference-form-save')));
      for (
        var i = 0;
        i < 40 &&
            find.byKey(const ValueKey('reference-title')).evaluate().isNotEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final saved = (await CaseReferencesDao(db).getAll()).firstWhere(
        (row) => row.referenceAndPageNo == '68 DLR (AD) 290',
      );
      expect(saved.caseNote, 'Client in custody.');
      expect(saved.parties, 'State v. Karim');
      expect(saved.tags, 'evidence');

      await unmount(tester);
    },
  );

  testWidgets('Notes and Case Reference can be pulled down to sync', (
    tester,
  ) async {
    // Neither screen had any pull gesture at all: the populated list was a plain
    // ListView and the empty state a bare `Center`. Both are now scrollables
    // under a RefreshIndicator, so the gesture exists whether or not there is
    // anything to show.
    for (final screen in <Widget>[
      const NotesScreen(),
      const CaseReferenceScreen(),
    ]) {
      await pumpLibrary(tester, screen);

      expect(
        find.byType(RefreshIndicator),
        findsOneWidget,
        reason: '${screen.runtimeType} offered no pull-to-sync',
      );
      await unmount(tester);
    }
  });

  testWidgets('a free account sees the sync-off cloud and no count here too', (
    tester,
  ) async {
    // The reported defect on these two screens specifically: saving a note or a
    // case reference queues a mutation (every write path does, so a later upgrade
    // can send it), and the header answered with a synced checkmark carrying the
    // count — for an account that syncs nothing at all.
    await seedNote('note-1', 'Bail application', 'Filed before the CMM.');
    await seedReference('ref-1', '45 DLR (AD) 1', 'Bail guidelines.');

    for (final screen in <Widget>[
      const NotesScreen(),
      const CaseReferenceScreen(),
    ]) {
      final name = screen.runtimeType.toString();
      await pumpLibrary(tester, screen);

      expect(
        find.byIcon(Icons.cloud_off_outlined),
        findsOneWidget,
        reason: '$name does not wear the sync-off cloud',
      );
      expect(
        find.byIcon(Icons.cloud_done_outlined),
        findsNothing,
        reason: '$name wears the synced checkmark for a free account',
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('cases-modal-sync-button')),
          matching: find.byType(Badge),
        ),
        findsNothing,
        reason: '$name puts a pending count on the sync button',
      );

      await unmount(tester);
    }
  });

  testWidgets('the Add Case Reference title band is the app black', (
    tester,
  ) async {
    // The band was the ink navy the other headers wear; the app's one black is
    // the same #000000 the Quick Update window's band uses.
    await pumpLibrary(tester, const CaseReferenceScreen());
    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);

    final band = tester.widget<Container>(
      find.byKey(const ValueKey('reference-title')),
    );
    expect(band.color, AppColors.secondary);

    await unmount(tester);
  });
}
