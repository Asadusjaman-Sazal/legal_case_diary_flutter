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
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/core/theme/app_theme.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/case_reference/data/local/case_references_dao.dart';
import 'package:legal_case_diary/features/case_reference/data/reference_repository.dart';
import 'package:legal_case_diary/features/case_reference/presentation/case_reference_screen.dart';
import 'package:legal_case_diary/features/cases/presentation/cases_screen_modal.dart';
import 'package:legal_case_diary/features/notes/data/local/notes_dao.dart';
import 'package:legal_case_diary/features/notes/data/notes_repository.dart';
import 'package:legal_case_diary/features/notes/presentation/notes_screen.dart';
import 'package:legal_case_diary/features/settings/data/local/user_preferences_dao.dart';
import 'package:legal_case_diary/features/settings/data/settings_repository.dart';
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

  /// Pumps one library with the app's providers, router and localizations.
  Future<void> pumpLibrary(WidgetTester tester, Widget screen) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => screen),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWith((_) async => db),
          localIdentityServiceProvider.overrideWith((_) => identity),
          settingsRepositoryProvider.overrideWith((_) async => settings),
          notesRepositoryProvider.overrideWith((_) async => notes),
          referenceRepositoryProvider.overrideWith((_) async => references),
          caseWritePermissionsProvider.overrideWith(
            (_) async => const CaseWritePermissions(canAdd: true, canEdit: true),
          ),
        ],
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

  Future<void> seedReference(String id, String citation, String description) =>
      references.insertReference(
        CaseReferencesCompanion(
          id: Value(id),
          userId: Value(identity.getId()),
          referenceAndPageNo: Value(citation),
          titleAndDescription: Value(description),
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
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, '');

    await unmount(tester);
  });

  testWidgets('the Case Reference query filters the library', (tester) async {
    await seedReference('ref-1', '45 DLR (AD) 1', 'Bail guidelines.');
    await seedReference('ref-2', '12 BLC 99', 'Partition of ancestral land.');
    await pumpLibrary(tester, const CaseReferenceScreen());

    await openSearch(tester);
    await tester.enterText(find.byType(TextField), 'dlr');
    await settle(tester);

    expect(find.textContaining('45 DLR'), findsOneWidget);
    expect(find.textContaining('12 BLC'), findsNothing);

    await unmount(tester);
  });
}
