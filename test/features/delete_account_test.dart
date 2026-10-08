/// Delete Account — the warning, the refusals, and the wired deletion (0.0.411).
///
/// The Delete Account card used to warn nothing and do nothing (the last Part A
/// placeholder on the Settings surface). What it does now is one flow, and each
/// step of it is pinned here against a faked server:
///
/// * **nothing is deleted without the warning** — Cancel, and a dismissed
///   window, leave the account and its data exactly as they were;
/// * the warning is **worded for this account's plan**, because a free
///   account's diary has never left the device while a premium one's is in the
///   cloud as well;
/// * **offline it refuses** — the account row is on the server, so there is no
///   local-only deletion to fall back to and nothing local is touched either;
/// * a **refusal** (a firm account) and a **failure** each stop with their own
///   sentence, and both leave the device as it was;
/// * a confirmed deletion **wipes this device and ends the session**, landing
///   the user on Login with a fresh install's database.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_deletion_repository.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/profiles_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_repository.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/manage_account_screen.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/data/local_auth_service.dart';
import 'package:legal_case_diary/sync/connectivity_monitor.dart';

import 'auth_test_support.dart';
import 'settings_test_support.dart';

/// Marker rendered by the stand-in Login route a completed deletion lands on.
const String loginRouteMarker = 'Login Route';

/// The deletion boundary, driven by the test instead of the network.
class FakeAccountDeletionRepository implements AccountDeletionRepository {
  /// Creates the fake, answering [outcome] every time.
  FakeAccountDeletionRepository(this.outcome);

  /// What the server would answer.
  AccountDeletionOutcome outcome;

  /// How many times the server was asked to remove this account.
  int calls = 0;

  @override
  Future<AccountDeletionOutcome> deleteAccount() async {
    calls++;
    return outcome;
  }
}

/// One note, so a wipe has something of the user's to destroy.
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

  /// Pumps Manage Account on its own route, with a local profile row and one
  /// note of the user's own, and returns nothing — assertions read the harness.
  Future<void> pumpManageAccount(
    WidgetTester tester, {
    required AccountDeletionRepository deletion,
    bool online = true,
    bool premium = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final overrides = <Override>[
      accountDeletionRepositoryProvider.overrideWithValue(deletion),
      isOnlineProvider.overrideWith((ref) => Stream<bool>.value(online)),
      logoutFlowOverride(premium: premium),
    ];

    await pumpSettingsRouter(
      tester,
      location: AppRoutes.settingsManageAccount,
      overrides: await harness.setUp(extra: overrides),
      routes: [
        GoRoute(
          path: AppRoutes.settingsManageAccount,
          builder: (_, _) => const ManageAccountScreen(),
        ),
        // Where a completed deletion lands: Login is a top-level route, so the
        // screen leaves the shell for it rather than popping back to Settings.
        GoRoute(
          path: AppRoutes.login,
          builder: (_, _) => const Scaffold(body: Text(loginRouteMarker)),
        ),
      ],
    );
    l = await AppLocalizations.delegate.load(const Locale('en'));
    // A device already in use: the remembered account is what the sign-out at
    // the end of a successful deletion must clear.
    await harness.prefs.setString(authUserIdKey, 'user-1');

    await ProfilesDao(harness.db).upsert(
      ProfilesCompanion(
        id: const Value('user-1'),
        fullName: const Value('Adv. Rahim Uddin'),
        role: const Value(AccountRole.individual),
        subscriptionStatus: Value(premium ? 'active' : 'free'),
        // Entitlement is derived from the expiry + 48 h grace — never from the
        // status flag — so a premium fixture needs a real future date.
        subscriptionExpiry: Value(
          premium
              ? DateTime.now()
                    .toUtc()
                    .add(const Duration(days: 30))
                    .millisecondsSinceEpoch
              : null,
        ),
        createdAt: const Value(1),
      ),
    );
    await _seedNote(harness.db);
    await tester.pumpAndSettle();
  }

  /// Taps the Delete Account card, scrolling it into view first.
  Future<void> tapDeleteCard(WidgetTester tester) async {
    final card = find.text(l.settingsManageAccount_deleteAccount);
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
  }

  /// Answers the warning: taps **Delete Account** in the window.
  Future<void> confirmDelete(WidgetTester tester) async {
    expect(
      find.text(l.settingsManageAccount_deleteDialogTitle),
      findsOneWidget,
      reason: 'the warning comes before anything is destroyed',
    );
    await tester.tap(
      find.widgetWithText(TextButton, l.settingsManageAccount_deleteAccount),
    );
    await tester.pumpAndSettle();
  }

  /// The account's own work is still on the device.
  Future<void> expectNothingDeleted() async {
    expect(await ProfilesDao(harness.db).getAll(), hasLength(1));
    expect(await harness.db.select(harness.db.notes).get(), hasLength(1));
    expect(harness.auth.signOutCalls, 0);
    expect(LocalAuthService(harness.prefs).cachedUserId, 'user-1');
  }

  testWidgets('a free account is warned that its device data goes', (
    tester,
  ) async {
    final deletion = FakeAccountDeletionRepository(AccountDeletionOutcome.deleted);
    await pumpManageAccount(tester, deletion: deletion);

    await tapDeleteCard(tester);

    // The free sentence, not the premium one: this diary never reached a cloud.
    expect(find.text(l.settingsManageAccount_deleteWarningFree), findsOneWidget);
    expect(
      find.text(l.settingsManageAccount_deleteWarningPremium),
      findsNothing,
    );

    await tester.tap(find.widgetWithText(TextButton, l.sharedActions_cancel));
    await tester.pumpAndSettle();

    expect(deletion.calls, 0, reason: 'Cancel deletes nothing');
    await expectNothingDeleted();
    expect(find.text(loginRouteMarker), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('a premium account is warned that its cloud data goes too', (
    tester,
  ) async {
    final deletion = FakeAccountDeletionRepository(AccountDeletionOutcome.deleted);
    await pumpManageAccount(tester, deletion: deletion, premium: true);

    await tapDeleteCard(tester);

    expect(
      find.text(l.settingsManageAccount_deleteWarningPremium),
      findsOneWidget,
    );
    expect(find.text(l.settingsManageAccount_deleteWarningFree), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, l.sharedActions_cancel));
    await tester.pumpAndSettle();
    expect(deletion.calls, 0);

    await unmountApp(tester);
  });

  testWidgets('offline it refuses and deletes nothing', (tester) async {
    // The account exists on the server, so there is no local-only deletion: the
    // honest answer is to say a connection is needed and leave the diary alone.
    final deletion = FakeAccountDeletionRepository(AccountDeletionOutcome.deleted);
    await pumpManageAccount(tester, deletion: deletion, online: false);

    await tapDeleteCard(tester);
    await confirmDelete(tester);

    expect(deletion.calls, 0, reason: 'nothing is sent to the server offline');
    await expectNothingDeleted();
    expect(find.text(l.settingsManageAccount_deleteNeedsConnection), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('a refused deletion says why and keeps the account', (tester) async {
    // A firm member's rows are partly the firm's, so the server refuses and the
    // screen passes its reason on. Nothing local is touched either.
    final deletion = FakeAccountDeletionRepository(
      AccountDeletionOutcome.refusedFirm,
    );
    await pumpManageAccount(tester, deletion: deletion);

    await tapDeleteCard(tester);
    await confirmDelete(tester);

    expect(find.text(l.settingsManageAccount_deleteFirmRefused), findsOneWidget);
    expect(deletion.calls, 1);
    await expectNothingDeleted();

    await unmountApp(tester);
  });

  testWidgets('a failed deletion is reported and keeps the account', (
    tester,
  ) async {
    final deletion = FakeAccountDeletionRepository(AccountDeletionOutcome.failed);
    await pumpManageAccount(tester, deletion: deletion);

    await tapDeleteCard(tester);
    await confirmDelete(tester);

    expect(find.text(l.settingsManageAccount_deleteFailed), findsOneWidget);
    expect(deletion.calls, 1);
    await expectNothingDeleted();

    await unmountApp(tester);
  });

  testWidgets('a confirmed deletion wipes the device and ends the session', (
    tester,
  ) async {
    final deletion = FakeAccountDeletionRepository(AccountDeletionOutcome.deleted);
    await pumpManageAccount(tester, deletion: deletion);

    await tapDeleteCard(tester);
    await confirmDelete(tester);

    expect(deletion.calls, 1);
    // The server removed the account, so this device goes back to what an
    // install starts from — the logout flow's own wipe — and signs out.
    expect(await harness.db.select(harness.db.notes).get(), isEmpty);
    expect(await ProfilesDao(harness.db).getAll(), isEmpty);
    expect(harness.auth.signOutCalls, 1);
    expect(LocalAuthService(harness.prefs).cachedUserId, isNull);
    expect(find.text(l.settingsManageAccount_deleted), findsOneWidget);
    // And the user lands on the sign-in screen, not on an emptied Settings list.
    expect(find.text(loginRouteMarker), findsOneWidget);

    await unmountApp(tester);
  });
}
