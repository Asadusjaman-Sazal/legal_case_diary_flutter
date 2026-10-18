/// Widget tests for the conflict banner and the Review Conflict screen
/// (Task 19 Phase 3).
///
/// What they pin is the part the plan is emphatic about: the banner is not
/// dismissible, it clears only when a conflict's `resolution_state` leaves
/// `unresolved`, the screen shows both candidate values, and each answer writes
/// the mutation the resolver would have written.
library;

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/features/sync/presentation/review_conflict_screen.dart';
import 'package:legal_case_diary/features/sync/presentation/sync_conflict_banner.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:legal_case_diary/sync/sync_conflict_log.dart';

/// A full `notes` row as the server returns it.
Map<String, dynamic> _serverNote({
  String title = 'Server Title',
  bool isDeleted = false,
}) => <String, dynamic>{
  'id': 'n1',
  'user_id': 'user-1',
  'title': title,
  'body': 'Body',
  'is_pinned': false,
  'created_at': 0,
  'updated_at': 0,
  'version': 2,
  'is_deleted': isDeleted,
  'server_updated_at': '2026-09-30T10:00:00.000000+00:00',
};

void main() {
  late AppDatabase db;
  late GoRouter router;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    db = AppDatabase(NativeDatabase.memory());
    await db.customSelect('select 1').get();

    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: const Text('Home screen'),
            bottomNavigationBar: const SyncConflictBanner(),
          ),
        ),
        GoRoute(
          path: AppRoutes.settingsReviewConflict,
          builder: (context, state) => ReviewConflictScreen(
            conflictId: state.pathParameters['conflictId'] ?? '',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
  });

  tearDown(() async => db.close());

  /// Inserts one local conflict record.
  Future<void> logConflict({
    String resolutionState = conflictUnresolved,
    Map<String, dynamic>? server,
    Map<String, dynamic>? submitted,
  }) => db.into(db.conflictLog).insert(
    ConflictLogCompanion.insert(
      id: 'c1',
      mutationId: 'mut-n1',
      entityType: 'note',
      entityId: 'n1',
      baseVersion: 1,
      basePayload: jsonEncode(<String, dynamic>{'id': 'n1', 'title': 'Base'}),
      submittedPayload: jsonEncode(
        submitted ?? <String, dynamic>{'id': 'n1', 'title': 'My Title'},
      ),
      changedFields: jsonEncode(const <String>['title']),
      serverVersion: 2,
      serverPayload: jsonEncode(server ?? _serverNote()),
      resolutionState: resolutionState,
      conflictAt: 1,
      updatedAt: 1,
    ),
  );

  Future<void> pumpApp(WidgetTester tester, {bool chamber = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWith((_) async => db),
          // The chamber is stated rather than derived, so the test says only the
          // fact it is about (firm-mode §9.9).
          if (chamber) firmModeProvider.overrideWithValue(true),
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

  /// Runs one test body and always unmounts before it ends.
  ///
  /// `ConflictLogDao.watchUnresolved()` schedules a zero-duration timer when its
  /// stream closes, and flutter_test fails a test whose timers are still
  /// pending — and leaves the next test unable to settle. So the app is unmounted
  /// inside the body, whether the body passed or threw.
  Future<void> withApp(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    try {
      await body();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  /// Waits until [condition] is true, pumping in between.
  Future<void> settleUntil(
    WidgetTester tester,
    bool Function() condition,
  ) async {
    for (var i = 0; i < 40 && !condition(); i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('no conflict means no banner at all', (tester) async {
    await withApp(tester, () async {
      await pumpApp(tester);

      expect(find.textContaining('Needs Review'), findsNothing);
      expect(find.text('Home screen'), findsOneWidget);
    });
  });

  testWidgets('one unresolved conflict shows the banner and opens the screen',
      (tester) async {
    await logConflict();
    await withApp(tester, () async {
      await pumpApp(tester);

      expect(find.text('A Conflict Needs Review'), findsOneWidget);

      await tester.tap(find.text('A Conflict Needs Review'));
      await tester.pumpAndSettle();

      expect(find.text('Review Conflict'), findsOneWidget);
      expect(
        find.text(
          'You and another device changed the same fields. Choose the value to '
          'keep for each one.',
        ),
        findsOneWidget,
      );
      // Both candidate values are on screen: the server's and this device's.
      expect(find.text('Server Title'), findsOneWidget);
      expect(find.text('My Title'), findsOneWidget);
      expect(find.text('Server'), findsOneWidget);
      expect(find.text('Mine'), findsOneWidget);
    });
  });

  testWidgets('an already-answered conflict never reaches the banner', (
    tester,
  ) async {
    await logConflict(resolutionState: conflictUserResolved);
    await withApp(tester, () async {
      await pumpApp(tester);

      expect(find.textContaining('Needs Review'), findsNothing);
    });
  });

  testWidgets('saving the resolution writes the mutation and clears the banner',
      (tester) async {
    await logConflict();
    await withApp(tester, () async {
      await pumpApp(tester);

      await tester.tap(find.text('A Conflict Needs Review'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await settleUntil(
        tester,
        () => router.routerDelegate.currentConfiguration.uri.path == '/',
      );

      // Back on the home screen with nothing left to review.
      expect(find.text('Home screen'), findsOneWidget);
      expect(find.textContaining('Needs Review'), findsNothing);

      final conflict = (await db.select(db.conflictLog).get()).single;
      expect(conflict.resolutionState, conflictUserResolved);
      final queued = (await db.select(db.syncQueue).get())
          .where((row) => row.entityType == 'note')
          .toList();
      expect(queued, hasLength(1), reason: 'one replacement mutation');
      expect(queued.single.state, 'pending');
    });
  });

  testWidgets('a tombstone offers only the two explicit answers', (
    tester,
  ) async {
    // A real queue row carries the whole entity, and the copy onto a new record
    // is built from exactly that, so the fixture has to be complete too.
    await logConflict(
      server: _serverNote(isDeleted: true),
      submitted: <String, dynamic>{
        'id': 'n1',
        'user_id': 'user-1',
        'title': 'My Title',
        'body': 'Body',
        'is_pinned': false,
        'created_at': 0,
        'updated_at': 1,
        'is_deleted': false,
      },
    );
    await withApp(tester, () async {
      await pumpApp(tester);

      await tester.tap(find.text('A Conflict Needs Review'));
      await tester.pumpAndSettle();

      expect(find.text('Deleted On The Server'), findsOneWidget);
      expect(find.text('Keep As A New Record'), findsOneWidget);
      expect(find.text('Discard My Changes'), findsOneWidget);
      // No field chooser: a deleted row has nothing to reconcile field by field.
      expect(find.text('Server'), findsNothing);

      await tester.tap(find.text('Keep As A New Record'));
      await settleUntil(
        tester,
        () => router.routerDelegate.currentConfiguration.uri.path == '/',
      );

      final copies = (await db.select(db.syncQueue).get())
          .where((row) => row.entityType == 'note' && row.entityId != 'n1')
          .toList();
      expect(copies, hasLength(1));
      expect(copies.single.operation, 'insert');
      expect(
        (await db.select(db.conflictLog).get()).single.resolutionState,
        conflictUserResolved,
      );
    });
  });

  group('who the server says edited the row (firm-mode §9.9)', () {
    /// A server payload edited by [editorId], which is what the screen reads.
    Map<String, dynamic> editedBy(String editorId) => <String, dynamic>{
      ..._serverNote(),
      'last_modified_by': editorId,
    };

    /// A colleague: a real account id this device holds no profile row for.
    const colleague = '77777777-7777-4777-8777-777777777777';

    testWidgets('inside a chamber the other side is a member, not a device', (
      tester,
    ) async {
      await logConflict(server: editedBy(colleague));
      await withApp(tester, () async {
        await pumpApp(tester, chamber: true);

        await tester.tap(find.text('A Conflict Needs Review'));
        await tester.pumpAndSettle();

        // A chamber colleague is a person, and this device never holds their
        // name — so the screen says what it knows instead of blaming a device.
        expect(find.text('A Chamber Member Changed This Record'), findsOneWidget);
        expect(find.text('Edited By A Chamber Member'), findsOneWidget);
        expect(find.text('Another Device Changed This Record'), findsNothing);
        expect(find.text('Edited By Another Device'), findsNothing);
      });
    });

    testWidgets("outside a chamber the two-device wording is kept", (
      tester,
    ) async {
      // The regression pin: an individual account's other side really is its own
      // second device, so the wording that was there stays there.
      await logConflict(server: editedBy(colleague));
      await withApp(tester, () async {
        await pumpApp(tester);

        await tester.tap(find.text('A Conflict Needs Review'));
        await tester.pumpAndSettle();

        expect(find.text('Another Device Changed This Record'), findsOneWidget);
        expect(find.text('Edited By Another Device'), findsOneWidget);
        expect(find.text('A Chamber Member Changed This Record'), findsNothing);
      });
    });
  });
}
