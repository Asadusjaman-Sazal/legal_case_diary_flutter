/// Tests for the to-do kind of note (Task 11's Notes screen).
///
/// A to-do is a note whose `items` holds a checklist: the FAB asks for the kind
/// when a note is created, the editor's body becomes Keep's list, ticking a row
/// drops it below the unticked ones, and the card shows the first few rows with
/// a count of the rest. `body` mirrors the item texts so the existing title+body
/// search finds a to-do by what is on its list — which is what the last test
/// pins, since nothing else would notice that mirror going missing.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/notes/data/local/notes_dao.dart';
import 'package:legal_case_diary/features/notes/data/note_items.dart';
import 'package:legal_case_diary/features/notes/data/notes_repository.dart';
import 'package:legal_case_diary/features/notes/presentation/note_detail_screen.dart';
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
  late LocalSettingsRepository settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    identity = LocalIdentityService(prefs);
    db = AppDatabase(NativeDatabase.memory());
    final sync = SyncWriteHelper(SyncQueueDao(db), identity);
    notes = LocalNotesRepository(NotesDao(db), sync);
    settings = LocalSettingsRepository(UserPreferencesDao(db), identity);
  });

  tearDown(() async => db.close());

  /// Pumps a bounded number of frames.
  ///
  /// The notes library holds a live Drift stream subscription, so this suite
  /// waits for the widgets under test instead of `pumpAndSettle`, which would
  /// wait for the frame pipeline itself to go quiet.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
  }

  /// Seeds a to-do note straight through the repository.
  Future<Note> seedTodo(
    List<NoteItem> items, {
    String title = 'Filing',
  }) async {
    final id = await notes.insertNote(
      NotesCompanion(
        title: Value(title),
        body: Value(noteItemsAsBody(items)),
        items: Value(encodeNoteItems(items)),
      ),
    );
    return (await notes.getById(id))!;
  }

  /// Tears the widgets down at the end of a widget test.
  ///
  /// The library and the editor hold live Drift stream subscriptions, so the
  /// tree is taken down inside the test body — before the suite's `db.close()`
  /// — and given a frame for the streams to release.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// Pumps the Notes library with the app's providers, router and strings.
  Future<void> pumpNotesScreen(WidgetTester tester) async {
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const NotesScreen())],
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
          caseWritePermissionsProvider.overrideWith(
            (_) async => const CaseWritePermissions(canAdd: true, canEdit: true),
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await settle(tester);
  }

  /// Pumps a host that pushes the editor, so the editor's own Save can pop it.
  Future<void> pumpEditor(
    WidgetTester tester, {
    Note? note,
    bool isTodo = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWith((_) async => db),
          localIdentityServiceProvider.overrideWith((_) => identity),
          settingsRepositoryProvider.overrideWith((_) async => settings),
          notesRepositoryProvider.overrideWith((_) async => notes),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                key: const ValueKey('open-note'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NoteDetailScreen(note: note, isTodo: isTodo),
                  ),
                ),
                child: const Text('Open Note'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-note')));
    await settle(tester);
  }

  /// Text currently in checklist row [index].
  String rowText(WidgetTester tester, int index) => tester
      .widget<TextField>(find.byKey(ValueKey('todo-item-$index')))
      .controller!
      .text;

  /// Painted style of checklist row [index].
  TextStyle rowStyle(WidgetTester tester, int index) => tester
      .widget<TextField>(find.byKey(ValueKey('todo-item-$index')))
      .style!;

  group('note item codec', () {
    test('a note with no items decodes as a text note', () {
      expect(decodeNoteItems(null), isNull);
      expect(decodeNoteItems(''), isNull);
      expect(decodeNoteItems('not json'), isNull);
      expect(decodeNoteItems('{"text":"One"}'), isNull);
    });

    test('an empty checklist is still a checklist', () {
      expect(decodeNoteItems('[]'), isEmpty);
      expect(encodeNoteItems(const []), '[]');
    });

    test('items round-trip through storage', () {
      const items = [
        NoteItem(text: 'Call client'),
        NoteItem(text: 'Reply to notice', done: true),
      ];
      expect(decodeNoteItems(encodeNoteItems(items)), items);
    });

    test('a mistyped stored row degrades instead of breaking the editor', () {
      expect(decodeNoteItems('[{"text":5,"done":"yes"}]'), const [
        NoteItem(text: ''),
      ]);
    });

    test('the body mirror is one item text per line', () {
      expect(
        noteItemsAsBody(const [
          NoteItem(text: 'Call client'),
          NoteItem(text: 'Reply to notice'),
        ]),
        'Call client\nReply to notice',
      );
    });
  });

  group('the editor', () {
    testWidgets('ticking an item drops it below the unticked rows and strikes '
        'it through', (tester) async {
      final note = await seedTodo(const [
        NoteItem(text: 'One'),
        NoteItem(text: 'Two'),
        NoteItem(text: 'Three'),
      ]);
      await pumpEditor(tester, note: note);

      await tester.tap(find.byKey(const ValueKey('todo-checkbox-0')));
      await settle(tester);

      expect(rowText(tester, 0), 'Two');
      expect(rowText(tester, 2), 'One');
      expect(rowStyle(tester, 2).decoration, TextDecoration.lineThrough);
      // The rows above the ticked one keep their own order and style.
      expect(rowStyle(tester, 0).decoration, isNull);
      await unmount(tester);
    });

    testWidgets('unticking puts an item back in its own place', (tester) async {
      final note = await seedTodo(const [
        NoteItem(text: 'One'),
        NoteItem(text: 'Two'),
        NoteItem(text: 'Three'),
      ]);
      await pumpEditor(tester, note: note);

      await tester.tap(find.byKey(const ValueKey('todo-checkbox-1')));
      await settle(tester);
      // Ticked: below every unticked row.
      expect(rowText(tester, 0), 'One');
      expect(rowText(tester, 1), 'Three');
      expect(rowText(tester, 2), 'Two');
      expect(rowStyle(tester, 2).decoration, TextDecoration.lineThrough);

      await tester.tap(find.byKey(const ValueKey('todo-checkbox-2')));
      await settle(tester);
      // Unticked: back between 'One' and 'Three', where it started — not at the
      // bottom of the list, and no longer struck through.
      expect(rowText(tester, 0), 'One');
      expect(rowText(tester, 1), 'Two');
      expect(rowText(tester, 2), 'Three');
      expect(rowStyle(tester, 1).decoration, isNull);
      await unmount(tester);
    });

    testWidgets('the Add Item button reads white', (tester) async {
      await pumpEditor(tester, isTodo: true);

      final label = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('todo-add-item')),
          matching: find.text('Add Item'),
        ),
      );
      expect(label.style?.color, AppColors.onPrimary);
      await unmount(tester);
    });

    testWidgets('a new to-do saves its items, drops blank rows and mirrors '
        'them into the body', (tester) async {
      await pumpEditor(tester, isTodo: true);
      expect(find.byKey(const ValueKey('todo-add-item')), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Filing');
      await tester.enterText(find.byKey(const ValueKey('todo-item-0')), 'Call client');
      await tester.tap(find.byKey(const ValueKey('todo-add-item')));
      await settle(tester);
      await tester.enterText(
        find.byKey(const ValueKey('todo-item-1')),
        'Reply to notice',
      );
      await tester.tap(find.byKey(const ValueKey('todo-checkbox-1')));
      await settle(tester);
      // A row left blank must not become an item.
      await tester.tap(find.byKey(const ValueKey('todo-add-item')));
      await settle(tester);

      await tester.tap(find.byIcon(Icons.check));
      await settle(tester);

      final stored = (await notes.listAll()).single;
      expect(stored.title, 'Filing');
      expect(decodeNoteItems(stored.items), const [
        NoteItem(text: 'Call client'),
        NoteItem(text: 'Reply to notice', done: true),
      ]);
      expect(stored.body, 'Call client\nReply to notice');
      await unmount(tester);
    });
  });

  group('the notes screen', () {
    testWidgets('the add button offers a text note and a to-do', (
      tester,
    ) async {
      await pumpNotesScreen(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await settle(tester);

      expect(find.byKey(const ValueKey('add-note-text')), findsOneWidget);
      expect(find.byKey(const ValueKey('add-note-todo')), findsOneWidget);
      expect(find.text('Text Note'), findsOneWidget);
      expect(find.text('To-Do'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('choosing To-Do opens the editor as a checklist', (
      tester,
    ) async {
      await pumpNotesScreen(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('add-note-todo')));
      await settle(tester);

      expect(find.byKey(const ValueKey('todo-add-item')), findsOneWidget);
      // A new to-do opens with one empty row ready to type into.
      expect(find.byKey(const ValueKey('todo-item-0')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a to-do card shows three items and counts the rest', (
      tester,
    ) async {
      await seedTodo(const [
        NoteItem(text: 'Call client'),
        NoteItem(text: 'Reply to notice', done: true),
        NoteItem(text: 'File vakalatnama'),
        NoteItem(text: 'Collect certified copy'),
        NoteItem(text: 'Pay court fee'),
      ]);
      await pumpNotesScreen(tester);

      expect(find.text('Call client'), findsOneWidget);
      expect(find.text('File vakalatnama'), findsOneWidget);
      // The fourth and fifth rows are the count, not the text.
      expect(find.text('Collect certified copy'), findsNothing);
      expect(find.text('+2 More'), findsOneWidget);

      final doneStyle = tester
          .widget<Text>(find.text('Reply to notice'))
          .style!;
      expect(doneStyle.decoration, TextDecoration.lineThrough);
      await unmount(tester);
    });
  });

  group('search', () {
    test('finds a to-do by its item text through the body mirror', () async {
      await seedTodo(const [NoteItem(text: 'Reply to notice')]);

      expect(await notes.search('reply'), hasLength(1));
      expect(await notes.search('nomatch'), isEmpty);
    });

    test('the checklist travels in the sync payload', () async {
      await seedTodo(const [NoteItem(text: 'Call client')]);

      final row = (await SyncQueueDao(db).getAll()).single;
      expect(row.payload, contains('items'));
      expect(row.changedFields, contains('items'));
    });
  });
}
