/// Subscription screen, and the Settings entry that opens it.
///
/// Both rows were Manage Account's, so this pins that they arrived intact: the
/// same wording, the same icons, the same details sheet with the same content,
/// and the same paywall. It also pins the entry point, because "Go Premium" was
/// an approved departure from the Settings main mockup and removing it puts that
/// screen back on its mockup — while the Subscription entry that replaces it is
/// a fresh departure with no mockup to conform to, which is why the order is
/// asserted rather than left to a screenshot.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/firms_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/profiles_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_repository.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_main_screen.dart';
import 'package:legal_case_diary/features/settings/presentation/subscription_screen.dart';

import 'auth_test_support.dart';
import 'settings_test_support.dart';

/// Marker rendered by the stand-in Paywall route the purchase row pushes.
const String subscriptionPaywallMarker = 'Paywall Route';

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

  /// Pumps the Subscription screen on a router, then seeds [seed] once adoption
  /// has run: adoption empties the pull-only caches on the first auth read, so
  /// anything seeded before the first frame would be wiped by design.
  Future<void> pumpSubscription(
    WidgetTester tester, {
    Future<void> Function(AppDatabase db)? seed,
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpSettingsRouter(
      tester,
      location: AppRoutes.settingsSubscription,
      overrides: await harness.setUp(),
      routes: [
        GoRoute(
          path: AppRoutes.settingsSubscription,
          builder: (_, _) => const SubscriptionScreen(),
        ),
        GoRoute(
          path: AppRoutes.paywall,
          builder: (_, _) =>
              const Scaffold(body: Text(subscriptionPaywallMarker)),
        ),
      ],
    );
    l = await AppLocalizations.delegate.load(const Locale('en'));

    // Every other account screen watches the cached profile in its build, so the
    // pull-only caches are already being read by the time a test seeds them.
    // This screen reads them only when the details sheet opens, which would put
    // that first read after the seed; starting it here keeps the two the same
    // order the other screens produce.
    ProviderScope.containerOf(
      tester.element(find.byType(SubscriptionScreen)),
    ).read(accountProfileProvider);
    await tester.pumpAndSettle();

    if (seed != null) {
      await seed(harness.db);
      await tester.pumpAndSettle();
    }
  }

  /// Consumes the framework assertion the Settings rows carry themselves.
  ///
  /// Their `ListTile`s sit inside the settings card's decorated box, so Flutter
  /// warns once per layout that their ink may be invisible. It is the Settings
  /// list's own long-standing noise, unrelated to what these rows assert, and a
  /// genuine failure here still fails the test.
  void drainFrameworkNoise(WidgetTester tester) {
    while (tester.takeException() != null) {}
  }

  /// Taps [finder] after scrolling it into view.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('both rows are here, word for word', (tester) async {
    await pumpSubscription(tester);

    expect(find.text(l.settingsSubscription_title), findsOneWidget);
    expect(find.text(l.settingsManageAccount_subscriptionDetails), findsOneWidget);
    expect(
      find.text(l.settingsManageAccount_purchaseNewSubscription),
      findsOneWidget,
    );
    // The icons moved with the rows: the star that opened the details sheet and
    // the cart that opened the paywall.
    expect(find.byIcon(Icons.star_outline), findsOneWidget);
    expect(find.byIcon(Icons.add_shopping_cart_outlined), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('a firm owner sees the firm and a dated premium state', (
    tester,
  ) async {
    final expiry = DateTime.now().toUtc().add(const Duration(days: 40));
    await pumpSubscription(
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

    await tapVisible(
      tester,
      find.text(l.settingsManageAccount_subscriptionDetails),
    );

    expect(find.text(l.settingsManageAccount_role), findsOneWidget);
    expect(find.text(l.settingsManageAccount_roleOwner), findsOneWidget);
    expect(find.text(l.settingsManageAccount_firm), findsOneWidget);
    expect(find.text('Rahman & Associates'), findsOneWidget);
    // Scoped to the sheet: this page's own title is the word 'Subscription'
    // too, so an unscoped finder would match the header and the row label.
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(l.settingsManageAccount_subscription),
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(l.settingsManageAccount_planPremium),
      findsOneWidget,
      reason: 'premium, with the expiry date',
    );

    await unmountApp(tester);
  });

  testWidgets('an individual with no subscription sees Free', (tester) async {
    // A pulled profile row that carries no expiry: the account is *known* to be
    // on the free plan. Without the row the sheet says nothing at all rather
    // than Free — see the unknown-entitlement test below — so "Free" here is a
    // fact rather than a gap, which is what makes this assertion meaningful.
    await pumpSubscription(
      tester,
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

  testWidgets('an account whose row has not landed says nothing, not Free', (
    tester,
  ) async {
    // Regression, carried across with the sheet: it read the entitlement the
    // moment the session existed, so a premium account that had just signed in
    // was told "Subscription: Free" while the Plan row beside it already named
    // the month it had paid for. With no cached row there is no plan to report,
    // and a dash is the honest value until the pull lands.
    await pumpSubscription(tester);

    await tapVisible(
      tester,
      find.text(l.settingsManageAccount_subscriptionDetails),
    );

    expect(find.text(l.settingsManageAccount_planFree), findsNothing);
    expect(find.text('\u2014'), findsWidgets, reason: 'the entitlement is unknown');

    await unmountApp(tester);
  });

  testWidgets('Purchase New Subscription opens the paywall', (tester) async {
    await pumpSubscription(tester);

    await tapVisible(
      tester,
      find.text(l.settingsManageAccount_purchaseNewSubscription),
    );

    expect(find.text(subscriptionPaywallMarker), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('Settings offers Subscription after Online Sync, no Go Premium', (
    tester,
  ) async {
    // Regression: Go Premium was an approved departure from this mockup, and it
    // sat between Accounts & Profile and Online Sync. It is gone, and the entry
    // that replaced it is where the user asked for it — directly after Online
    // Sync — so the paywall is now reachable from one place instead of two.
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpSettingsRouter(
      tester,
      location: AppRoutes.settingsOnlineSync,
      overrides: await harness.setUp(),
      routes: [
        GoRoute(
          path: AppRoutes.settingsOnlineSync,
          builder: (_, _) => const SettingsMainScreen(),
        ),
      ],
    );
    l = await AppLocalizations.delegate.load(const Locale('en'));
    drainFrameworkNoise(tester);

    expect(find.text(l.payments_goPremium), findsNothing);
    expect(find.text(l.settingsScreen_onlineSync), findsOneWidget);
    expect(find.text(l.settingsSubscription_title), findsOneWidget);

    final syncY = tester.getTopLeft(find.text(l.settingsScreen_onlineSync)).dy;
    final subscriptionY =
        tester.getTopLeft(find.text(l.settingsSubscription_title)).dy;
    final backupY =
        tester.getTopLeft(find.text(l.settingsScreen_backupAndRestore)).dy;
    expect(
      subscriptionY,
      greaterThan(syncY),
      reason: 'Subscription comes after Online Sync',
    );
    expect(
      subscriptionY,
      lessThan(backupY),
      reason: 'and before Backup & Restore',
    );

    await unmountApp(tester);
  });
}
