/// Widget tests for the Sync Status screen (Task 19 Phase 4).
///
/// They pin the four things the plan asks the screen to guarantee: every
/// unfinished row is visible under "All", the chips filter without hiding
/// anything from that list, Retry puts a blocked row back in the queue, Discard
/// asks first and then rolls the record back, and an export cannot include case
/// content without an explicit consent step.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/sync/presentation/sync_status_screen.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';

/// A complete `notes` row, for the pre-mutation snapshot Discard restores.
Map<String, dynamic> _note({String title = 'Base Title'}) => <String, dynamic>{
  'id': 'n1',
  'user_id': 'user-1',
  'title': title,
  'body': 'Body',
  'is_pinned': false,
  'created_at': 0,
  'updated_at': 0,
  'version': 1,
  'is_deleted': false,
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
      initialLocation: AppRoutes.settingsSyncStatus,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Text('Home screen')),
        ),
        GoRoute(
          path: AppRoutes.settingsSyncStatus,
          builder: (context, state) => const SyncStatusScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
  });

  tearDown(() async => db.close());

  /// Inserts one local note row.
  Future<void> insertNote(String title) => db
      .into(db.notes)
      .insert(
        NotesCompanion.insert(
          id: 'n1',
          userId: 'user-1',
          title: title,
          body: 'Body',
          createdAt: 0,
          updatedAt: 0,
        ),
      );

  /// Inserts one queue entry in [state].
  Future<void> insertQueue({
    required String state,
    String entityType = 'note',
    String entityId = 'n1',
    String mutationId = 'mut-1',
    String operation = 'update',
    int retryCount = 0,
    String? lastError,
  }) => db
      .into(db.syncQueue)
      .insert(
        SyncQueueCompanion.insert(
          entityType: entityType,
          entityId: entityId,
          operation: operation,
          mutationId: mutationId,
          basePayload: jsonEncode(_note()),
          changedFields: jsonEncode(const <String>['title']),
          payload: jsonEncode(_note(title: 'My Title')),
          preMutationPayload: jsonEncode(_note()),
          createdAt: 0,
          retryCount: Value(retryCount),
          state: state,
          lastError: Value(lastError),
        ),
      );

  Future<void> pumpApp(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWith((_) async => db),
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
  /// The queue stream schedules a zero-duration timer when it closes, and
  /// flutter_test fails a test whose timers are still pending — so the app is
  /// unmounted inside the body whether it passed or threw.
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

  testWidgets('an empty queue shows the empty state and no rows', (
    tester,
  ) async {
    await withApp(tester, () async {
      await pumpApp(tester);

      expect(find.text('Sync Status'), findsOneWidget);
      expect(find.text('Nothing Is Waiting To Sync'), findsOneWidget);
      // The chips are still there, at zero, so the screen reads as empty.
      expect(find.text('All 0'), findsOneWidget);
      expect(find.text('Blocked 0'), findsOneWidget);
    });
  });

  testWidgets('a queued deletion is visibly marked pending', (tester) async {
    await insertQueue(state: 'pending', operation: 'delete');

    await withApp(tester, () async {
      await pumpApp(tester);

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      // The state pill says `pending`, which is true of every queued edit; the
      // extra pill is what makes a *destructive* provisional action visible as
      // one (Task 20 Phase 2 item 4, plan §1).
      expect(find.text(l.syncStatus_pendingDeletion), findsOneWidget);
      expect(find.text(l.syncStatus_statePending), findsOneWidget);
    });
  });

  testWidgets('an ordinary queued edit carries no deletion marker', (
    tester,
  ) async {
    await insertQueue(state: 'pending');

    await withApp(tester, () async {
      await pumpApp(tester);

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l.syncStatus_pendingDeletion), findsNothing);
    });
  });

  testWidgets('All lists every held row and the chips filter it', (
    tester,
  ) async {
    await insertQueue(
      state: 'blocked',
      entityType: 'note',
      entityId: 'n1',
      mutationId: 'mut-1',
      retryCount: 4,
      lastError: 'permission_denied',
    );
    await insertQueue(
      state: 'conflict_pending',
      entityType: 'case',
      entityId: 'c1',
      mutationId: 'mut-2',
    );
    await withApp(tester, () async {
      await pumpApp(tester);

      expect(find.text('All 2'), findsOneWidget);
      expect(find.text('Blocked 1'), findsOneWidget);
      expect(find.text('Conflicted 1'), findsOneWidget);
      expect(find.text('Note Update'), findsOneWidget);
      expect(find.text('Case Update'), findsOneWidget);
      // The window is wide enough for the retry count and the error.
      expect(find.textContaining('Attempted 4 Times'), findsOneWidget);
      expect(find.text('Last Error: permission_denied'), findsOneWidget);

      await tester.tap(find.text('Blocked 1'));
      await tester.pumpAndSettle();

      expect(find.text('Note Update'), findsOneWidget);
      expect(find.text('Case Update'), findsNothing);
    });
  });

  testWidgets('Retry returns a blocked entry to the queue', (tester) async {
    await insertQueue(
      state: 'blocked',
      retryCount: 4,
      lastError: 'permission_denied',
    );
    await withApp(tester, () async {
      await pumpApp(tester);

      await tester.tap(find.text('Retry'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      final row = (await db.select(db.syncQueue).get()).single;
      expect(row.state, 'pending');
      expect(row.retryCount, 0);
      expect(row.lastError, isNull);
    });
  });

  testWidgets('Discard confirms first, then rolls the record back', (
    tester,
  ) async {
    await insertQueue(state: 'blocked');
    await insertNote('My Title');
    await withApp(tester, () async {
      await pumpApp(tester);

      // Discard lives behind the overflow menu.
      await tester.tap(find.byKey(const ValueKey('sync-status-entry-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard').last);
      await tester.pumpAndSettle();

      // A confirmation, because it throws queued work away.
      expect(find.text('Discard This Change?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Discard'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(await db.select(db.syncQueue).get(), isEmpty);
      // No Supabase client in a test, so Discard took the snapshot path.
      expect((await db.select(db.notes).get()).single.title, 'Base Title');
    });
  });

  testWidgets('the export sheet defaults to metadata and gates payloads', (
    tester,
  ) async {
    await insertQueue(state: 'blocked');
    await withApp(tester, () async {
      await pumpApp(tester);

      await tester.tap(find.byKey(const ValueKey('sync-status-export')));
      await tester.pumpAndSettle();

      expect(find.text('Metadata Only'), findsOneWidget);
      expect(find.text('Include Payloads'), findsOneWidget);
      expect(
        find.textContaining('Delete This File After Seven Days'),
        findsOneWidget,
      );

      // Including case content is a separate, explicit consent.
      await tester.tap(find.text('Include Payloads'));
      await tester.pumpAndSettle();
      expect(find.text('Include Case Content?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Include Case Content?'), findsNothing);
    });
  });
}
