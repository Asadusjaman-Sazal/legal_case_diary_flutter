/// Task 17 Phase 4 — offline sessions never gate the diary, and a rejected
/// session asks for a sign-in without touching local data.
///
/// The plan's *Offline Session Expiry* rule has two halves and this suite pins
/// both: with no connection, an expired token is a state the user cannot act on,
/// so the diary simply opens (no notice, nothing asked of them); a reject the
/// server actually issued while the device is online shows the one notice that
/// offers the sign-in — and **never deletes anything**, including a queue that
/// still holds unsynced work.
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_repository.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/account_refresh_scope.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/data/local_auth_service.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_gate.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_viewmodel.dart';
import 'package:legal_case_diary/features/auth/presentation/session_state.dart';
import 'package:legal_case_diary/features/settings/data/backup_metadata_store.dart';
import 'package:legal_case_diary/sync/connectivity_monitor.dart';

import 'auth_test_support.dart';
import 'account_mode_test.dart' show FakeProfileRepository, firstStreamValue;

/// A [ConnectivityMonitor] the test drives by hand.
class FakeConnectivityMonitor implements ConnectivityMonitor {
  /// Creates a monitor that answers [initial] and then reports [changes].
  FakeConnectivityMonitor({this.initial = true});

  /// What [isOnline] answers.
  bool initial;

  final StreamController<bool> _changes = StreamController<bool>.broadcast();

  /// Reports [online] as the current state.
  void emit(bool online) {
    initial = online;
    _changes.add(online);
  }

  /// Closes the change stream.
  Future<void> dispose() => _changes.close();

  @override
  Future<bool> isOnline() async => initial;

  @override
  Stream<bool> get onlineChanges => _changes.stream;
}

/// Seeds the reference chain a case needs, then the case itself.
Future<void> seedCase(AppDatabase db, {String owner = 'user-1'}) async {
  await db
      .into(db.courtCategories)
      .insert(
        const CourtCategoriesCompanion(
          id: Value('category-1'),
          nameKey: Value('courtCategory_appellateDivision'),
          courtLevel: Value('appellate'),
          orderIndex: Value(1),
          updatedAt: Value(1),
        ),
      );
  await db
      .into(db.courts)
      .insert(
        const CourtsCompanion(
          id: Value('court-1'),
          courtName: Value('Supreme Court'),
          higherLowerCourts: Value('higher_courts'),
          courtCategoryId: Value('category-1'),
          updatedAt: Value(1),
        ),
      );
  await db
      .into(db.onBehalfs)
      .insert(
        const OnBehalfsCompanion(
          id: Value('on-behalf-1'),
          courtCategoryId: Value('category-1'),
          name: Value('Petitioner'),
          orderIndex: Value(1),
          updatedAt: Value(1),
        ),
      );
  await db
      .into(db.cases)
      .insert(
        CasesCompanion(
          id: const Value('case-1'),
          userId: Value(owner),
          courtId: const Value('court-1'),
          caseType: const Value('Civil'),
          caseNumber: const Value('OFFLINE/2026'),
          petitioner: const Value('Alice'),
          respondent: const Value('Bob'),
          onBehalfId: const Value('on-behalf-1'),
          lastModifiedBy: Value(owner),
          createdAt: const Value(1),
          updatedAt: const Value(1),
        ),
      );
  await db
      .into(db.syncQueue)
      .insert(
        SyncQueueCompanion(
          entityType: const Value('cases'),
          entityId: const Value('case-1'),
          operation: const Value('insert'),
          mutationId: const Value('mutation-1'),
          basePayload: const Value('{}'),
          changedFields: const Value('["petitioner"]'),
          payload: Value('{"id":"case-1","user_id":"$owner"}'),
          preMutationPayload: const Value('{}'),
          createdAt: const Value(1),
          state: const Value('pending'),
        ),
      );
}

/// Overrides connectivity with a fixed answer.
Override onlineOverride(bool online) =>
    isOnlineProvider.overrideWith((_) => Stream<bool>.value(online));

void main() {
  group('Session state', () {
    late AuthTestHarness harness;

    setUp(() => harness = AuthTestHarness());
    tearDown(() async {
      await harness.tearDown();
      await harness.auth.dispose();
    });

    /// Builds a container, waits for the connectivity answer, and reads the
    /// session state.
    Future<SessionStatus> statusWith({
      required bool online,
      AuthSessionEvent? event,
      bool cachedAccount = false,
    }) async {
      if (cachedAccount) {
        harness = AuthTestHarness(
          preferences: const <String, Object>{authUserIdKey: 'user-1'},
        );
      }
      final container = ProviderContainer(
        overrides: [...await harness.setUp(), onlineOverride(online)],
      );
      addTearDown(container.dispose);
      // The connectivity stream has to have answered, or the state would be
      // resolved against "unknown" instead of the value under test.
      await firstStreamValue(container, isOnlineProvider);
      await container.read(authViewModelProvider.future);
      if (event != null) harness.auth.emit(event);
      await Future<void>.delayed(Duration.zero);
      return container.read(sessionStatusProvider);
    }

    test('no account at all is simply signed out', () async {
      expect(await statusWith(online: true), SessionStatus.signedOut);
    });

    test('a live session is usable', () async {
      harness = AuthTestHarness(
        auth: FakeAuthRepository(
          identity: const AuthIdentity(userId: 'user-1'),
        ),
      );

      expect(await statusWith(online: false), SessionStatus.usable);
    });

    test('a cached account offline is stale, not locked out', () async {
      // No live session, but this device knows whose diary it holds and there is
      // no connection to refresh anything: the plan's "offline, token stale".
      expect(
        await statusWith(online: false, cachedAccount: true),
        SessionStatus.staleOffline,
      );
    });

    test('a rejected session while online needs a sign-in', () async {
      harness = AuthTestHarness(
        auth: FakeAuthRepository(
          identity: const AuthIdentity(userId: 'user-1'),
        ),
      );

      expect(
        await statusWith(
          online: true,
          cachedAccount: true,
          event: const AuthSessionEvent(sessionExpired: true),
        ),
        SessionStatus.reLoginRequired,
      );
    });

    test('the same rejection offline asks for nothing', () async {
      harness = AuthTestHarness(
        auth: FakeAuthRepository(
          identity: const AuthIdentity(userId: 'user-1'),
        ),
      );

      // Nothing the user could do about it offline, so nothing is asked.
      expect(
        await statusWith(
          online: false,
          cachedAccount: true,
          event: const AuthSessionEvent(sessionExpired: true),
        ),
        SessionStatus.staleOffline,
      );
    });
  });

  group('An expired session never touches local data', () {
    late AuthTestHarness harness;

    tearDown(() async {
      await harness.tearDown();
      await harness.auth.dispose();
    });

    test('an offline launch with a stale token still reaches case data', () async {
      harness = AuthTestHarness(
        preferences: const <String, Object>{authUserIdKey: 'user-1'},
      );
      final overrides = await harness.setUp();
      await seedCase(harness.db);
      final container = ProviderContainer(
        overrides: [...overrides, onlineOverride(false)],
      );
      addTearDown(container.dispose);
      await firstStreamValue(container, isOnlineProvider);

      // The gate is satisfied from local facts, and the data is readable.
      expect(await container.read(authGateRequiredProvider.future), isFalse);
      expect((await harness.db.select(harness.db.cases).get()).length, 1);
    });

    test('a rejected session leaves the diary and the queue exactly as they were', () async {
      harness = AuthTestHarness(
        auth: FakeAuthRepository(
          identity: const AuthIdentity(userId: 'user-1'),
        ),
      );
      final overrides = await harness.setUp();
      await seedCase(harness.db);
      final container = ProviderContainer(
        overrides: [...overrides, onlineOverride(true)],
      );
      addTearDown(container.dispose);
      await firstStreamValue(container, isOnlineProvider);
      await container.read(authViewModelProvider.future);

      harness.auth.emit(const AuthSessionEvent(sessionExpired: true));
      await Future<void>.delayed(Duration.zero);

      expect(container.read(sessionStatusProvider), SessionStatus.reLoginRequired);
      // The plan's rule: never wipe local data while `sync_queue` has pending
      // rows. Here nothing is wiped at all — the branched logout (Task 19) is the
      // only flow that may discard unsynced work, and only with the user.
      expect((await harness.db.select(harness.db.cases).get()).length, 1);
      expect((await harness.db.select(harness.db.syncQueue).get()).length, 1);
    });
  });

  group('The notice', () {
    late AuthTestHarness harness;

    setUp(() => harness = AuthTestHarness());
    tearDown(() async {
      await harness.tearDown();
      await harness.auth.dispose();
    });

    /// Pumps the notice above a stand-in app on a tiny router.
    Future<void> pumpNotice(
      WidgetTester tester, {
      required bool online,
      AuthSessionEvent? event,
      List<Override> overrides = const <Override>[],
    }) async {
      if (event != null) {
        harness = AuthTestHarness(
          auth: FakeAuthRepository(
            identity: const AuthIdentity(userId: 'user-1'),
          ),
          preferences: const <String, Object>{authUserIdKey: 'user-1'},
        );
      }
      final router = GoRouter(
        initialLocation: '/app',
        routes: [
          GoRoute(
            path: '/app',
            builder: (_, _) => const Scaffold(body: Text('The Diary')),
          ),
          GoRoute(
            path: AppRoutes.login,
            builder: (_, _) => const Scaffold(body: Text('Login Route')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...await harness.setUp(),
            onlineOverride(online),
            ...overrides,
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            // Mounted the way the app mounts it: above the navigator, inside
            // the Material app, so it reaches every screen.
            builder: (context, child) => SessionExpiryNotice(
              router: router,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (event != null) {
        harness.auth.emit(event);
        await tester.pumpAndSettle();
      }
    }

    testWidgets('a rejected online session offers the sign-in', (tester) async {
      // The tap runs the same branched logout every other sign-out uses, so this
      // free account really is asked for a passphrase before its data goes. The
      // copy stays in memory: the branch, not the file, is what is under test.
      final sink = RecordingArchiveSink();
      await pumpNotice(
        tester,
        online: true,
        event: const AuthSessionEvent(sessionExpired: true),
        overrides: [logoutFlowOverride(premium: false, sink: sink)],
      );
      final l = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.text(l.auth_sessionExpired), findsOneWidget);
      expect(find.text(l.auth_sessionExpiredAction), findsOneWidget);
      // The screen behind it is untouched and still on display.
      expect(find.text('The Diary'), findsOneWidget);

      // Encryption on, so the free account's copy asks for a passphrase below.
      await harness.prefs.setBool(backupEncryptionEnabledKey, true);
      await tester.tap(find.text(l.auth_sessionExpiredAction));
      await tester.pumpAndSettle();

      // Nothing is deleted on the mere detection of the rejection, and the notice
      // is only the way in.
      await completeLogoutPassphrase(tester, l, 'correct-horse');

      expect(sink.writes, 1);
      expect(harness.auth.signOutCalls, 1);
      expect(find.text('Login Route'), findsOneWidget);

      await unmountApp(tester);
    });

    testWidgets('nothing is shown for an offline stale session', (tester) async {
      await pumpNotice(tester, online: false);
      final l = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.text(l.auth_sessionExpired), findsNothing);
      expect(find.text('The Diary'), findsOneWidget);

      await unmountApp(tester);
    });
  });

  group('Reconnect', () {
    testWidgets('coming back online pulls the account again', (tester) async {
      final harness = AuthTestHarness(
        auth: FakeAuthRepository(
          identity: const AuthIdentity(userId: 'user-1'),
        ),
      );
      addTearDown(() async {
        await harness.tearDown();
        await harness.auth.dispose();
      });
      final repository = FakeProfileRepository()..refreshResult = true;
      final monitor = FakeConnectivityMonitor();
      addTearDown(monitor.dispose);

      final overrides = await harness.setUp();
      repository.database = harness.db;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            connectivityMonitorProvider.overrideWithValue(monitor),
            profileRepositoryProvider.overrideWith((_) async => repository),
          ],
          child: const AccountRefreshScope(child: SizedBox.shrink()),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.refreshCalls, 1, reason: 'once on launch');

      // The link drops, then comes back: the reconnect refresh is the transition,
      // not the first answer, so both ends are reported.
      monitor.emit(false);
      await tester.pumpAndSettle();
      monitor.emit(true);
      await tester.pumpAndSettle();

      expect(repository.refreshCalls, 2, reason: 'again on reconnect');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });
  });
}
