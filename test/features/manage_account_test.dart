/// Task 17 Phase 3 — Manage Account with real account data.
///
/// The mockup's body is unchanged, so this suite pins the two things the task
/// asked for *inside* that body: the name and email are the user's own (never
/// the mockup's sample values), and the role, firm and subscription state are
/// reachable — behind the row the mockup draws, as the Subscription Details
/// sheet. Logout is real here too: it ends the session and empties the account
/// caches.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/firms_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/profiles_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_name_store.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_repository.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/manage_account_screen.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/data/local_auth_service.dart';

import 'auth_test_support.dart';
import 'settings_test_support.dart';

/// Marker rendered by the stand-in routes the two links push.
const String resetRouteMarker = 'Reset Password Route';
const String paywallRouteMarker = 'Paywall Route';

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
        GoRoute(
          path: AppRoutes.forgotPassword,
          builder: (_, _) => const Scaffold(body: Text(resetRouteMarker)),
        ),
        GoRoute(
          path: AppRoutes.paywall,
          builder: (_, _) => const Scaffold(body: Text(paywallRouteMarker)),
        ),
      ],
    );
    l = await AppLocalizations.delegate.load(const Locale('en'));

    if (seed != null) {
      await seed(harness.db);
      await tester.pumpAndSettle();
    }
  }

  /// Taps [finder] after scrolling it into view.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
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

  testWidgets('a firm owner sees the firm and a dated premium state', (
    tester,
  ) async {
    final expiry = DateTime.now().toUtc().add(const Duration(days: 40));
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
            subscriptionExpiry: Value(expiry.millisecondsSinceEpoch),
            createdAt: const Value(1),
          ),
        );
      },
    );

    // The server's name fills the blank local record.
    expect(find.text('Adv. Rahim Uddin'), findsOneWidget);

    await tapVisible(
      tester,
      find.text(l.settingsManageAccount_subscriptionDetails),
    );

    expect(find.text(l.settingsManageAccount_role), findsOneWidget);
    expect(find.text(l.settingsManageAccount_roleOwner), findsOneWidget);
    expect(find.text(l.settingsManageAccount_firm), findsOneWidget);
    expect(find.text('Rahman & Associates'), findsOneWidget);
    expect(find.text(l.settingsManageAccount_subscription), findsOneWidget);
    expect(
      find.textContaining(l.settingsManageAccount_planPremium),
      findsOneWidget,
      reason: 'premium, with the expiry date',
    );

    await unmountApp(tester);
  });

  testWidgets('an individual with no subscription sees Free', (tester) async {
    await pumpManageAccount(tester);

    await tapVisible(
      tester,
      find.text(l.settingsManageAccount_subscriptionDetails),
    );

    expect(find.text(l.settingsManageAccount_roleIndividual), findsOneWidget);
    expect(find.text(l.settingsManageAccount_planFree), findsOneWidget);
    // No firm in individual mode, so no Firm row.
    expect(find.text(l.settingsManageAccount_firm), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('Change Password opens the reset flow', (tester) async {
    await pumpManageAccount(tester);

    await tapVisible(tester, find.text(l.settingsManageAccount_changePassword));

    expect(find.text(resetRouteMarker), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('Purchase New Subscription opens the paywall', (tester) async {
    await pumpManageAccount(tester);

    await tapVisible(
      tester,
      find.text(l.settingsManageAccount_purchaseNewSubscription),
    );

    expect(find.text(paywallRouteMarker), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('Logout ends the session, empties the caches and returns', (
    tester,
  ) async {
    // A free account has no cloud copy of anything it holds, so its logout is the
    // export-then-wipe branch (Task 19 Phase 6): the encrypted safety copy is
    // written first, and the wipe and the sign-out happen only after it lands.
    final sink = RecordingArchiveSink();
    await pumpManageAccount(
      tester,
      overrides: [logoutFlowOverride(premium: false, sink: sink)],
      seed: (db) => ProfilesDao(db).upsert(
        const ProfilesCompanion(
          id: Value('user-1'),
          fullName: Value('Adv. Rahim Uddin'),
          role: Value(AccountRole.individual),
          subscriptionStatus: Value('free'),
          createdAt: Value(1),
        ),
      ),
    );
    await harness.prefs.setString(authUserIdKey, 'user-1');

    await tapVisible(tester, find.text(l.settingsManageAccount_logout));
    await completeLogoutPassphrase(tester, l, 'correct-horse');

    expect(sink.writes, 1, reason: 'the copy is written before the wipe');
    expect(harness.auth.signOutCalls, 1);
    // The pull-only cache is emptied and the cached account is forgotten, but
    // the local diary is never touched.
    expect(await ProfilesDao(harness.db).getAll(), isEmpty);
    expect(LocalAuthService(harness.prefs).cachedUserId, isNull);
    expect(find.text(l.logout_backedUpTo(sink.lastPath!)), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('Logout cancelling the backup keeps the session and the data', (
    tester,
  ) async {
    // The copy is the wipe's precondition, so declining to set a passphrase
    // cancels the logout rather than the export: nothing is deleted and the
    // account stays signed in.
    final sink = RecordingArchiveSink();
    await pumpManageAccount(
      tester,
      overrides: [logoutFlowOverride(premium: false, sink: sink)],
      seed: (db) => ProfilesDao(db).upsert(
        const ProfilesCompanion(
          id: Value('user-1'),
          fullName: Value('Adv. Rahim Uddin'),
          role: Value(AccountRole.individual),
          subscriptionStatus: Value('free'),
          createdAt: Value(1),
        ),
      ),
    );

    await tapVisible(tester, find.text(l.settingsManageAccount_logout));
    await tester.tap(find.text(l.sharedActions_cancel));
    await tester.pumpAndSettle();

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

    await tapVisible(tester, find.text(l.settingsManageAccount_logout));

    expect(find.byType(AlertDialog), findsNothing);
    expect(harness.auth.signOutCalls, 1);
    expect(find.text(l.settingsManageAccount_loggedOut), findsOneWidget);

    await unmountApp(tester);
  });
}
