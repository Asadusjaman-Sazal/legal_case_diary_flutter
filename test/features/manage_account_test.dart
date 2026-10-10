/// Task 17 Phase 3 — Manage Account with real account data.
///
/// The mockup's body is unchanged, so this suite pins the two things the task
/// asked for *inside* that body: the name and email are the user's own (never
/// the mockup's sample values), and the role, firm and subscription state are
/// reachable. Logout is real here too: it ends the session and empties the
/// account caches.
///
/// **The action column, as the user asked for it (0.0.411).** The profile
/// summary keeps the avatar, name and email only — the small inline Logout under
/// the address is gone; a **full-size Logout** card takes its place, the same
/// card as **Delete Account** below it. **Change Password** is back on this
/// screen, directly after Logout, and a red bold **Danger Zone** label
/// introduces the destructive card. The subscription rows stay on
/// **Subscription** (`subscription_screen_test.dart`). The deletion flow itself
/// has its own suite, `delete_account_test.dart`.
library;

import 'package:drift/drift.dart' show Value;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/auth/data/logout_flow.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/firms_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/profiles_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_name_store.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_repository.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/manage_account_screen.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/data/local_auth_service.dart';
import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/features/settings/data/backup_metadata_store.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_menu_card.dart';
import 'package:legal_case_diary/sync/connectivity_monitor.dart';

import 'auth_test_support.dart';
import 'settings_test_support.dart';

/// Marker rendered by the stand-in Login route a completed logout goes to.
const String loginRouteMarker = 'Login Route';

/// One note, so a free account *has* work for the logout to offer a copy of.
Future<void> _seedNote(AppDatabase db) => db
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

void main() {
  late AuthTestHarness harness;
  late AppLocalizations l;

  setUp(() {
    harness = AuthTestHarness(
      auth: FakeAuthRepository(
        identity: const AuthIdentity(
          userId: 'user-1',
          email: 'advocate.asad@law.com',
        ),
      ),
    );
  });

  tearDown(() async {
    await harness.tearDown();
    await harness.auth.dispose();
  });

  /// Pumps the screen on a router, then seeds [seed] once adoption has run.
  ///
  /// Adoption empties the pull-only caches on the first auth read, so anything
  /// seeded before the first frame would be wiped by design.
  Future<void> pumpManageAccount(
    WidgetTester tester, {
    Future<void> Function(AppDatabase db)? seed,
    List<Override> overrides = const <Override>[],
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpSettingsRouter(
      tester,
      location: AppRoutes.settingsManageAccount,
      overrides: await harness.setUp(extra: overrides),
      routes: [
        GoRoute(
          path: AppRoutes.settingsManageAccount,
          builder: (_, _) => const ManageAccountScreen(),
        ),
        // Where a completed logout lands: Login is a top-level route, so the
        // screen must leave the shell for it rather than pop back to Settings.
        GoRoute(
          path: AppRoutes.login,
          builder: (_, _) => const Scaffold(body: Text(loginRouteMarker)),
        ),
      ],
    );
    l = await AppLocalizations.delegate.load(const Locale('en'));

    if (seed != null) {
      await seed(harness.db);
      await tester.pumpAndSettle();
    }
  }

  /// Taps the Logout card, which starts an indeterminate spinner.
  ///
  /// From the tap, the card shows a `CircularProgressIndicator` for the flow's
  /// duration, so `pumpAndSettle` can never settle — a bounded pump is the
  /// honest wait (the same rule the drawer suite follows). For a branch with no
  /// dialog (a synced account), the whole flow runs to Login on this single tap.
  Future<void> tapLogout(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await pumpUntilLogoutDone(tester);
  }

  testWidgets('shows the signed-in account, never the mockup sample', (
    tester,
  ) async {
    harness = AuthTestHarness(
      auth: FakeAuthRepository(
        identity: const AuthIdentity(
          userId: 'user-1',
          email: 'advocate.asad@law.com',
        ),
      ),
      preferences: const <String, Object>{
        profileFieldsKey:
            '{"fullName":"Adv. Rahim Uddin","barAssociation":"Dhaka Bar"}',
      },
    );
    await pumpManageAccount(tester);

    expect(find.text('Adv. Rahim Uddin'), findsOneWidget);
    expect(find.text('advocate.asad@law.com'), findsOneWidget);
    expect(find.text('Asadusjaman'), findsNothing);
    expect(find.text('A'), findsOneWidget, reason: 'the real initial');

    await unmountApp(tester);
  });

  testWidgets('a firm owner\'s server name fills the blank local record', (
    tester,
  ) async {
    // The name assertion that shared the subscription test: the sheet moved to
    // Settings > Subscription, but this screen is still what resolves the name.
    await pumpManageAccount(
      tester,
      seed: (db) async {
        await ProfilesDao(db).upsert(
          ProfilesCompanion(
            id: const Value('user-1'),
            fullName: const Value('Adv. Rahim Uddin'),
            role: const Value(AccountRole.owner),
            firmId: const Value('firm-1'),
            subscriptionStatus: const Value('active'),
            createdAt: const Value(1),
          ),
        );
        await FirmsDao(db).upsert(
          FirmsCompanion(
            id: const Value('firm-1'),
            name: const Value('Rahman & Associates'),
            ownerId: const Value('user-1'),
            subscriptionStatus: const Value('active'),
            createdAt: const Value(1),
          ),
        );
      },
    );

    expect(find.text('Adv. Rahim Uddin'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('Change Password is here again, the subscription rows are not', (
    tester,
  ) async {
    // Change Password came back from the Security sub-page (0.0.411) and the
    // subscription rows stayed on Subscription: if one of those ever came back
    // too, two screens would offer it.
    await pumpManageAccount(tester);

    expect(find.text(l.settingsManageAccount_changePassword), findsOneWidget);
    expect(
      find.text(l.settingsManageAccount_subscriptionDetails),
      findsNothing,
    );
    expect(
      find.text(l.settingsManageAccount_purchaseNewSubscription),
      findsNothing,
    );

    await unmountApp(tester);
  });

  testWidgets('the action column is Logout, Change Password, Danger Zone, Delete', (
    tester,
  ) async {
    await pumpManageAccount(tester);

    // The action cards are one widget, so "the Logout button is the same size as
    // the Delete Account button" is a property of the code rather than a promise
    // two layouts have to keep in step — and the Delete Data card the user asked
    // to sit between them (0.0.473) is the same card again.
    final cards = find.byType(SettingsActionCard);
    expect(cards, findsNWidgets(3));
    for (var index = 1; index < 3; index++) {
      expect(
        tester.getSize(cards.at(index)).width,
        tester.getSize(cards.at(0)).width,
      );
    }
    // And the Logout card is exactly as tall as the one-line Change Password row
    // beside it: one card shape, one 44 px content row. (The destructive card is
    // taller only when their own subtitle wraps, which is a wrapped supporting
    // line rather than anything about the Logout button's size.)
    expect(
      tester.getSize(cards.at(0)).height,
      // Change Password's row: the first one; App Lock joined below it (0.0.420)
      // and is a second row of the same height.
      tester.getSize(find.byType(SettingsSubMenuRow).first).height,
    );

    // The section heading is the error colour, in bold.
    final label = tester.widget<Text>(
      find.text(l.settingsManageAccount_dangerZone),
    );
    expect(label.style?.color, AppColors.error);
    expect(label.style?.fontWeight, FontWeight.w700);

    // Order, by geometry: the profile card, then Logout, then Change Password,
    // then the label, then Delete Data, then Delete Account.
    final emailBottom = tester
        .getBottomLeft(find.text('advocate.asad@law.com'))
        .dy;
    final logoutTop = tester.getTopLeft(cards.at(0)).dy;
    final passwordTop = tester
        .getTopLeft(find.text(l.settingsManageAccount_changePassword))
        .dy;
    final dangerTop = tester
        .getTopLeft(find.text(l.settingsManageAccount_dangerZone))
        .dy;
    final deleteTop = tester.getTopLeft(cards.at(2)).dy;

    expect(
      logoutTop,
      greaterThan(emailBottom),
      reason: 'Logout is a card below the profile summary, not a button in it',
    );
    expect(passwordTop, greaterThan(logoutTop));
    expect(dangerTop, greaterThan(passwordTop));
    expect(deleteTop, greaterThan(dangerTop));
    // One logout affordance on the whole screen: the profile card has none.
    expect(find.byIcon(Icons.logout), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('every action row paints its ripple on itself (0.0.419)', (
    tester,
  ) async {
    // The defect this pins: the cards were opaque Containers over an InkWell,
    // so the splash painted on a Material *behind* the card and the tap gave no
    // feedback at all. The fix makes the card its own Material. What proves it:
    // the ink controller each InkWell resolves to must be the render object of
    // the Material *inside its own card* — in the buggy shape there is no
    // Material in the card, and the controller was one shared with the whole
    // screen. Covers every card on this screen; the two Subscription rows are
    // the same widgets, pinned in their own suite.
    await pumpManageAccount(tester);

    // Where one InkWell's splash paints, for the card [finder] is inside.
    MaterialInkController splashSurfaceOf(Finder card) {
      final ink = find
          .descendant(of: card, matching: find.byType(InkWell))
          .evaluate()
          .single;
      final material = find.descendant(
        of: card,
        matching: find.byType(Material),
      );
      expect(material, findsOneWidget, reason: 'the card is its own Material');
      return Material.of(ink);
    }

    final cards = find.byType(SettingsActionCard);
    final logoutSurface = splashSurfaceOf(cards.at(0));
    final dataSurface = splashSurfaceOf(cards.at(1));
    final deleteSurface = splashSurfaceOf(cards.at(2));
    final passwordSurface = splashSurfaceOf(
      find.byType(SettingsSubMenuRow).first,
    );

    // A shared controller is exactly what the old opaque-Container shape
    // produced: every card's splash resolved to the one screen-level Material
    // behind them all. Distinct controllers are the fixed shape.
    expect(logoutSurface, isNot(same(dataSurface)));
    expect(logoutSurface, isNot(same(deleteSurface)));
    expect(dataSurface, isNot(same(deleteSurface)));
    expect(logoutSurface, isNot(same(passwordSurface)));
    expect(dataSurface, isNot(same(passwordSurface)));
    expect(deleteSurface, isNot(same(passwordSurface)));

    // And each card really is its own Material — the assertion inside
    // splashSurfaceOf — so the distinct controllers are the distinct cards.
    for (var index = 0; index < 3; index++) {
      expect(
        find.descendant(of: cards.at(index), matching: find.byType(Material)),
        findsOneWidget,
      );
    }

    await unmountApp(tester);
  });

  testWidgets('Logout ends the session, empties the caches and shows Login', (
    tester,
  ) async {
    // A free account holding its own work has no cloud copy of it, so its logout
    // offers the copy (Task 19 Phase 6): on Yes the encrypted safety copy is
    // written first, and the wipe and the sign-out happen only after it lands.
    final sink = RecordingArchiveSink();
    await pumpManageAccount(
      tester,
      overrides: [logoutFlowOverride(premium: false, sink: sink)],
      seed: (db) async {
        await ProfilesDao(db).upsert(
          const ProfilesCompanion(
            id: Value('user-1'),
            fullName: Value('Adv. Rahim Uddin'),
            role: Value(AccountRole.individual),
            subscriptionStatus: Value('free'),
            createdAt: Value(1),
          ),
        );
        await _seedNote(db);
      },
    );
    await harness.prefs.setString(authUserIdKey, 'user-1');
    // Encryption on, so the export asks for a passphrase as this test expects.
    await harness.prefs.setBool(backupEncryptionEnabledKey, true);

    await tapLogout(tester, find.text(l.settingsManageAccount_logout));
    await completeLogoutPassphrase(
      tester,
      l,
      'correct-horse',
      boundedPumps: true,
    );

    expect(sink.writes, 1, reason: 'the copy is written before the wipe');
    expect(harness.auth.signOutCalls, 1);
    // The pull-only cache is emptied and the cached account is forgotten, but
    // the local diary is never touched.
    expect(await ProfilesDao(harness.db).getAll(), isEmpty);
    expect(LocalAuthService(harness.prefs).cachedUserId, isNull);
    expect(find.text(l.logout_backedUpTo(sink.lastPath!)), findsOneWidget);
    // The user lands on the sign-in screen, not back on an empty Settings list.
    expect(find.text(loginRouteMarker), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('Logout cancelling the backup keeps the session and the data', (
    tester,
  ) async {
    // A dismissed passphrase window cancels the logout rather than the export —
    // the user asked for a copy, so nothing is deleted and the account stays
    // signed in.
    final sink = RecordingArchiveSink();
    await pumpManageAccount(
      tester,
      overrides: [logoutFlowOverride(premium: false, sink: sink)],
      seed: (db) async {
        await ProfilesDao(db).upsert(
          const ProfilesCompanion(
            id: Value('user-1'),
            fullName: Value('Adv. Rahim Uddin'),
            role: Value(AccountRole.individual),
            subscriptionStatus: Value('free'),
            createdAt: Value(1),
          ),
        );
        await _seedNote(db);
      },
    );

    await harness.prefs.setBool(backupEncryptionEnabledKey, true);
    await tapLogout(tester, find.text(l.settingsManageAccount_logout));
    await answerLogoutBackup(tester, l, boundedPumps: true);
    await tester.tap(find.text(l.sharedActions_cancel));
    // Cancelling ends the flow, so the spinner clears — wait for it.
    await pumpUntilLogoutDone(tester);

    expect(sink.writes, 0);
    expect(harness.auth.signOutCalls, 0);
    expect(await ProfilesDao(harness.db).getAll(), hasLength(1));
    expect(find.text(l.logout_exportCancelled), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('a synced account logs out at once, asking nothing', (
    tester,
  ) async {
    // Premium with an empty queue: the server already holds everything, so the
    // wipe destroys no unique copy and there is nothing to ask about.
    await pumpManageAccount(
      tester,
      overrides: [logoutFlowOverride(premium: true)],
      seed: (db) => ProfilesDao(db).upsert(
        ProfilesCompanion(
          id: const Value('user-1'),
          fullName: const Value('Adv. Rahim Uddin'),
          role: const Value(AccountRole.individual),
          subscriptionStatus: const Value('active'),
          subscriptionExpiry: Value(
            DateTime.now()
                .toUtc()
                .add(const Duration(days: 30))
                .millisecondsSinceEpoch,
          ),
          createdAt: const Value(1),
        ),
      ),
    );

    await tapLogout(tester, find.text(l.settingsManageAccount_logout));

    expect(find.byType(AlertDialog), findsNothing);
    expect(harness.auth.signOutCalls, 1);
    expect(find.text(l.settingsManageAccount_loggedOut), findsOneWidget);
    // Every completed branch lands on Login, not only the export one.
    expect(find.text(loginRouteMarker), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('the Logout card shows a spinner while the flow is running', (
    tester,
  ) async {
    // Held open so the spinner is observable: the whole flow stays in flight
    // until the test releases it.
    final gate = Completer<void>();
    await pumpManageAccount(
      tester,
      overrides: [
        logoutFlowProvider.overrideWith((ref) async {
          final db = await ref.watch(databaseProvider.future);
          return LogoutFlow(
            db: db,
            premium: true,
            online: false,
            runBacklogPush: () async => null,
            endSession: () => gate.future,
          );
        }),
      ],
    );

    await tester.ensureVisible(find.text(l.settingsManageAccount_logout));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.settingsManageAccount_logout));
    await tester.pump();

    // The Logout card's icon is a progress spinner while the flow runs.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Releasing the flow clears the spinner and reaches Login.
    gate.complete();
    await pumpUntilLogoutDone(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(loginRouteMarker), findsOneWidget);

    await unmountApp(tester);
  });

  group('Delete Data (0.0.473, user request)', () {
    /// Live (non-tombstoned) rows of [table].
    Future<int> liveRows(String table) async {
      final row = await harness.db
          .customSelect(
            'SELECT COUNT(*) AS n FROM "$table" WHERE is_deleted = 0',
          )
          .getSingle();
      return row.data['n']! as int;
    }

    /// One case reference, so a deletion has something it must leave alone.
    Future<void> seedReference(AppDatabase db) => db
        .into(db.caseReferences)
        .insert(
          CaseReferencesCompanion(
            id: const Value('r1'),
            userId: const Value('user-1'),
            referenceAndPageNo: const Value('12 MLR 34'),
            createdAt: const Value(0),
            updatedAt: const Value(0),
          ),
        );

    /// A premium individual account: an expiry in the future.
    Future<void> seedPremium(AppDatabase db) => ProfilesDao(db).upsert(
      ProfilesCompanion(
        id: const Value('user-1'),
        fullName: const Value('Adv. Rahim Uddin'),
        role: const Value(AccountRole.individual),
        subscriptionStatus: const Value('active'),
        subscriptionExpiry: Value(
          DateTime.now()
              .toUtc()
              .add(const Duration(days: 30))
              .millisecondsSinceEpoch,
        ),
        createdAt: const Value(1),
      ),
    );

    testWidgets('a free account gets the local card and no cloud one', (
      tester,
    ) async {
      await pumpManageAccount(tester);

      expect(
        find.text(l.settingsManageAccount_deleteLocalData),
        findsOneWidget,
      );
      expect(
        find.text(l.settingsManageAccount_deleteLocalAndCloudData),
        findsNothing,
        reason: 'a free account has no cloud copy to delete',
      );

      await unmountApp(tester);
    });

    testWidgets('a premium account gets the cloud card and no local one', (
      tester,
    ) async {
      await pumpManageAccount(tester, seed: seedPremium);

      expect(
        find.text(l.settingsManageAccount_deleteLocalAndCloudData),
        findsOneWidget,
      );
      expect(find.text(l.settingsManageAccount_deleteLocalData), findsNothing);

      await unmountApp(tester);
    });

    testWidgets('ticking Notes deletes the notes and leaves the rest', (
      tester,
    ) async {
      await pumpManageAccount(
        tester,
        seed: (db) async {
          await _seedNote(db);
          await seedReference(db);
        },
      );

      await tester.ensureVisible(
        find.text(l.settingsManageAccount_deleteLocalData),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.settingsManageAccount_deleteLocalData));
      await tester.pumpAndSettle();

      // The tick list opens with nothing ticked, so the red action is disabled —
      // a stray tap cannot delete anything.
      expect(
        find.text(l.settingsManageAccount_deleteDataTitle),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('data-deletion-confirm')),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.text(l.settingsManageAccount_deleteDataCustomSeedDataHint),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('data-deletion-notes')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('data-deletion-confirm')));
      await tester.pumpAndSettle();

      expect(await liveRows('notes'), 0);
      expect(
        await liveRows('case_references'),
        1,
        reason: 'only what was ticked goes',
      );
      expect(find.text(l.settingsManageAccount_deleteDataDone), findsOneWidget);

      await unmountApp(tester);
    });

    testWidgets('dismissing the tick list deletes nothing', (tester) async {
      await pumpManageAccount(tester, seed: _seedNote);

      await tester.ensureVisible(
        find.text(l.settingsManageAccount_deleteLocalData),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.settingsManageAccount_deleteLocalData));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('data-deletion-notes')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.sharedActions_cancel));
      await tester.pumpAndSettle();

      expect(await liveRows('notes'), 1);
      expect(find.text(l.settingsManageAccount_deleteDataDone), findsNothing);

      await unmountApp(tester);
    });

    testWidgets('a firm account is told why nothing is deleted', (
      tester,
    ) async {
      // The diary is shared with colleagues, so there is no personal copy to
      // delete — the same reason Delete Account refuses a firm account.
      await pumpManageAccount(
        tester,
        seed: (db) async {
          await _seedNote(db);
          await ProfilesDao(db).upsert(
            const ProfilesCompanion(
              id: Value('user-1'),
              fullName: Value('Adv. Rahim Uddin'),
              role: Value(AccountRole.owner),
              firmId: Value('firm-1'),
              subscriptionStatus: Value('active'),
              createdAt: Value(1),
            ),
          );
        },
      );

      await tester.ensureVisible(
        find.text(l.settingsManageAccount_deleteLocalData),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.settingsManageAccount_deleteLocalData));
      await tester.pumpAndSettle();

      expect(
        find.text(l.settingsManageAccount_deleteDataFirmRefused),
        findsOneWidget,
      );
      expect(
        find.text(l.settingsManageAccount_deleteDataTitle),
        findsNothing,
        reason: 'the tick list never opens for a firm account',
      );
      expect(await liveRows('notes'), 1);

      await unmountApp(tester);
    });

    testWidgets('the cloud card refuses without a connection', (tester) async {
      // Nothing is deleted offline: the deletes would only reach the account
      // later, and the user asked for both copies gone.
      await pumpManageAccount(
        tester,
        seed: (db) async {
          await seedPremium(db);
          await _seedNote(db);
        },
        overrides: <Override>[
          isOnlineProvider.overrideWith((ref) => Stream<bool>.value(false)),
        ],
      );

      await tester.ensureVisible(
        find.text(l.settingsManageAccount_deleteLocalAndCloudData),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(l.settingsManageAccount_deleteLocalAndCloudData),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(l.settingsManageAccount_deleteDataNeedsConnection),
        findsOneWidget,
      );
      expect(find.text(l.settingsManageAccount_deleteDataTitle), findsNothing);
      expect(await liveRows('notes'), 1);

      await unmountApp(tester);
    });

    testWidgets('the cloud card deletes locally when there is a link', (
      tester,
    ) async {
      // A premium account, online, in a build with no backend: the local rows go
      // and the account's copies stay queued, which is the honest sentence. (The
      // pushed case is pinned in `data_deletion_test.dart`.)
      await pumpManageAccount(
        tester,
        seed: (db) async {
          await seedPremium(db);
          await _seedNote(db);
        },
      );

      await tester.ensureVisible(
        find.text(l.settingsManageAccount_deleteLocalAndCloudData),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(l.settingsManageAccount_deleteLocalAndCloudData),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('data-deletion-notes')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('data-deletion-confirm')));
      await tester.pumpAndSettle();

      expect(await liveRows('notes'), 0);
      expect(
        find.text(l.settingsManageAccount_deleteDataCloudPending),
        findsOneWidget,
      );

      await unmountApp(tester);
    });
  });
}
