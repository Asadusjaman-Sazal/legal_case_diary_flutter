/// Tests for the branched logout's windows (Task 19 Phase 6).
///
/// The flow itself is pinned by `logout_flow_test.dart`; this suite pins the
/// **orchestration** — which branch opens which window, in what order, and what
/// the user is left holding after each answer. The two dialogs exist for the two
/// moments the plan names: the offline block that names the sync the changes
/// need, and the warning that names exactly what logging out now discards. Both
/// stand in front of the one rule every branch serves: *nothing that exists only
/// on this device may be destroyed without a copy*.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/auth/data/logout_flow.dart';
import 'package:legal_case_diary/features/auth/presentation/logout_dialogs.dart';
import 'package:legal_case_diary/features/settings/data/backup_metadata_store.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:legal_case_diary/sync/sync_service.dart';

import 'auth_test_support.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  var ended = 0;

  setUp(() async {
    ended = 0;
    // Encryption is off by default; the logout path reads the preference.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    await db.customSelect('select 1').get();
  });

  tearDown(() async => db.close());

  /// The flow under test: the branch is stated, the session end is counted, and
  /// the safety copy stays in memory.
  Override flowOverride({
    required bool premium,
    bool online = true,
    Future<BacklogOutcome?> Function()? push,
    RecordingArchiveSink? sink,
  }) => logoutFlowProvider.overrideWith((ref) async {
    return LogoutFlow(
      db: db,
      premium: premium,
      online: online,
      runBacklogPush: push ?? () async => const BacklogOutcome(),
      endSession: () async => ended++,
      sink: sink ?? RecordingArchiveSink(),
      kdfIterations: 1,
    );
  });

  /// Pumps a button whose press is the only entry point into the logout.
  Future<void> pumpLogout(WidgetTester tester, Override override) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          override,
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Center(
                // Keyed, because a branch's own confirm label is also "Log Out".
                child: TextButton(
                  key: const Key('logout-button'),
                  onPressed: () => runBranchedLogout(context, ref),
                  child: const Text('Log Out'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Presses that one entry point.
  Future<void> tapLogout(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle();
  }

  /// Taps a window's own action, scoped to the dialog so the page's trigger
  /// (also labelled "Log Out") cannot be hit by mistake.
  Future<void> tapDialogAction(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text(label)),
    );
    await tester.pumpAndSettle();
  }

  /// One local row and one queued mutation, so an incomplete wipe fails.
  Future<void> seedWork() async {
    await db
        .into(db.notes)
        .insert(
          NotesCompanion.insert(
            id: 'n1',
            userId: 'user-1',
            title: 'Local',
            body: 'Body',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db
        .into(db.syncQueue)
        .insert(
          SyncQueueCompanion.insert(
            entityType: 'notes',
            entityId: 'n1',
            operation: 'insert',
            mutationId: 'mut-1',
            basePayload: '{}',
            changedFields: '["title"]',
            payload: '{"id":"n1"}',
            preMutationPayload: '{}',
            createdAt: 0,
            state: 'pending',
          ),
        );
  }

  Future<void> expectNothingLeft() async {
    expect(await db.select(db.notes).get(), isEmpty);
    expect(await db.select(db.syncQueue).get(), isEmpty);
  }

  Future<void> expectWorkIntact() async {
    expect(await db.select(db.notes).get(), hasLength(1));
    expect(await db.select(db.syncQueue).get(), hasLength(1));
  }

  testWidgets('a clean wipe logs out at once, asking nothing', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    // Premium with nothing unsynced: the server already holds every row, so the
    // wipe destroys no unique copy and there is nothing to warn about.
    await pumpLogout(
      tester,
      flowOverride(premium: true, online: false),
    );

    await tapLogout(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(ended, 1);
    expect(find.text(l.settingsManageAccount_loggedOut), findsOneWidget);
  });

  testWidgets('a free account backs its data up, then wipes', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    final sink = RecordingArchiveSink();
    await seedWork();
    await prefs.setBool(backupEncryptionEnabledKey, true);
    await pumpLogout(
      tester,
      flowOverride(premium: false, sink: sink),
    );

    await tapLogout(tester);
    await completeLogoutPassphrase(tester, l, 'correct-horse');

    expect(sink.writes, 1, reason: 'the copy is written before the wipe');
    expect(ended, 1);
    await expectNothingLeft();
    // The user is told where the copy went, so it is findable afterwards.
    expect(find.text(l.logout_backedUpTo(sink.lastPath!)), findsOneWidget);
  });

  testWidgets('cancelling the passphrase deletes nothing', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    final sink = RecordingArchiveSink();
    await seedWork();
    await prefs.setBool(backupEncryptionEnabledKey, true);
    await pumpLogout(
      tester,
      flowOverride(premium: false, sink: sink),
    );

    await tapLogout(tester);
    expect(find.text(l.settingsBackupRestore_passphraseTitle), findsOneWidget);
    await tester.tap(find.text(l.sharedActions_cancel));
    await tester.pumpAndSettle();

    // No copy, so no wipe and no sign-out: the logout is what was cancelled.
    expect(sink.writes, 0);
    expect(ended, 0);
    await expectWorkIntact();
    expect(find.text(l.logout_exportCancelled), findsOneWidget);
  });

  testWidgets('the offline block asks twice, in order, then exports', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    final sink = RecordingArchiveSink();
    await seedWork();
    await prefs.setBool(backupEncryptionEnabledKey, true);
    await pumpLogout(
      tester,
      flowOverride(premium: true, online: false, sink: sink),
    );

    await tapLogout(tester);

    // First the plain block, which names the sync the changes need...
    expect(find.text(l.logout_connectToSync), findsOneWidget);
    expect(find.text(l.logout_unsyncedWarningBody), findsNothing);
    await tapDialogAction(tester, l.logout_logOutAnyway);

    // ...and then the warning, which names what logging out now costs.
    expect(find.text(l.logout_unsyncedWarningTitle), findsOneWidget);
    await tapDialogAction(tester, l.logout_proceed);

    await completeLogoutPassphrase(tester, l, 'correct-horse');

    expect(sink.writes, 1);
    expect(ended, 1);
    await expectNothingLeft();
  });

  testWidgets('declining the offline block ends the logout untouched', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    final sink = RecordingArchiveSink();
    await seedWork();
    await pumpLogout(
      tester,
      flowOverride(premium: true, online: false, sink: sink),
    );

    await tapLogout(tester);
    await tester.tap(find.text(l.sharedActions_cancel));
    await tester.pumpAndSettle();

    expect(sink.writes, 0);
    expect(ended, 0);
    await expectWorkIntact();
    expect(find.byType(TextFormField), findsNothing, reason: 'no export came');
  });

  testWidgets('a sync that cannot clear the queue warns, then exports', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    final sink = RecordingArchiveSink();
    await seedWork();
    // A pass that refuses to start (a rejected session, a blocked row): the
    // online branch must not pretend the queue can be sent.
    await prefs.setBool(backupEncryptionEnabledKey, true);
    await pumpLogout(
      tester,
      flowOverride(premium: true, sink: sink, push: () async => null),
    );

    await tapLogout(tester);

    expect(find.text(l.logout_unsyncedWarningTitle), findsOneWidget);
    await tapDialogAction(tester, l.logout_proceed);
    await completeLogoutPassphrase(tester, l, 'correct-horse');

    expect(sink.writes, 1, reason: 'the fallback still protects the data');
    expect(ended, 1);
    await expectNothingLeft();
  });
}
