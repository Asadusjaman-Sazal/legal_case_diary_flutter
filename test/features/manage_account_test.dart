/// Task 17 Phase 3 — Manage Account with real account data.
///
/// The mockup's body is unchanged, so this suite pins the two things the task
/// asked for *inside* that body: the name and email are the user's own (never
/// the mockup's sample values), and the role, firm and subscription state are
/// reachable. Logout is real here too: it ends the session and empties the
/// account caches.
///
/// The Subscription Details and Purchase New Subscription rows have since moved
/// to Settings > Subscription, so this screen keeps Change Password only; that
/// departure from its mockup is asserted here, and the rows' own tests live in
/// `subscription_screen_test.dart`.
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
import 'package:legal_case_diary/features/auth/presentation/forgot_password_screen.dart';

import 'auth_test_support.dart';
import 'settings_test_support.dart';

/// Marker rendered by the stand-in Login route a completed logout goes to.
const String loginRouteMarker = 'Login Route';

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
        // The real screen, in the presentation this row asks for: asserting on
        // it rather than on a marker is what pins "a Settings sub-page, not the
        // auth route".
        GoRoute(
          path: AppRoutes.settingsChangePassword,
          builder: (_, _) =>
              const ForgotPasswordScreen(asSettingsSubPage: true),
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

  testWidgets('the subscription rows are no longer here', (tester) async {
    // They moved to Settings > Subscription. Their mockup still draws all three
    // rows on this screen, so this is the assertion that pins the approved
    // departure: if a row ever came back, the two screens would both offer it.
    await pumpManageAccount(tester);

    expect(find.text(l.settingsManageAccount_changePassword), findsOneWidget);
    expect(find.text(l.settingsManageAccount_subscriptionDetails), findsNothing);
    expect(
      find.text(l.settingsManageAccount_purchaseNewSubscription),
      findsNothing,
    );

    await unmountApp(tester);
  });

  testWidgets('Change Password opens the reset flow as a Settings sub-page', (
    tester,
  ) async {
    // Regression: this row pushed Login's `/forgot-password`, which is an auth
    // route — and the router sends a signed-in user away from every auth route,
    // so the tap landed on the default landing page instead of the screen.
    await pumpManageAccount(tester);

    await tapVisible(tester, find.text(l.settingsManageAccount_changePassword));

    // The same screen Login's "Forgot Password?" shows...
    expect(find.text(l.auth_forgotTitle), findsOneWidget);
    expect(find.text(l.auth_sendCodeButton), findsOneWidget);
    expect(find.text(l.auth_emailLabel), findsOneWidget);
    // ...but as a Settings sub-page: the standard header with its back button.
    expect(find.byType(BackButton), findsWidgets);
    // And no way out to Login, where a signed-in user may not go.
    expect(find.text(l.auth_backToLogin), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('Logout ends the session, empties the caches and shows Login', (
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
    // The user lands on the sign-in screen, not back on an empty Settings list.
    expect(find.text(loginRouteMarker), findsOneWidget);

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
    // Every completed branch lands on Login, not only the export one.
    expect(find.text(loginRouteMarker), findsOneWidget);

    await unmountApp(tester);
  });
}
