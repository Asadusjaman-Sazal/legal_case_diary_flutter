/// Subscription screen, and the Settings entry that opens it.
///
/// Both rows were Manage Account's, so this pins that they arrived intact: the
/// same wording, the same icons, and the same paywall. What the details row
/// opens is pinned in `subscription_details_screen_test.dart`, which owns the
/// sub-page it now navigates to. It also pins the entry point, because "Go Premium" was
/// an approved departure from the Settings main mockup and removing it puts that
/// screen back on its mockup — while the Subscription entry that replaces it is
/// a fresh departure with no mockup to conform to, which is why the order is
/// asserted rather than left to a screenshot.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
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
    List<Override> overrides = const <Override>[],
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpSettingsRouter(
      tester,
      location: AppRoutes.settingsSubscription,
      overrides: [...await harness.setUp(), ...overrides],
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
        // The details row is a sub-page now, so the harness has to know where it
        // goes even though these tests only assert the row is there.
        GoRoute(
          path: AppRoutes.settingsSubscriptionDetails,
          builder: (_, _) => const Scaffold(body: Text('Subscription Details')),
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

  testWidgets('a chamber member is offered Subscription Details alone', (
    tester,
  ) async {
    // A member has no plan of their own to buy (Phase 9): the chamber's owner
    // buys and renews it. The details row stays — it is where the member reads
    // the chamber's plan and expiry.
    await pumpSubscription(
      tester,
      overrides: [firmMemberProvider.overrideWithValue(true)],
    );

    expect(find.text(l.settingsSubscription_title), findsOneWidget);
    expect(
      find.text(l.settingsManageAccount_subscriptionDetails),
      findsOneWidget,
    );
    expect(
      find.text(l.settingsManageAccount_purchaseNewSubscription),
      findsNothing,
    );
    expect(find.byIcon(Icons.star_outline), findsOneWidget);
    expect(find.byIcon(Icons.add_shopping_cart_outlined), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('Purchase New Subscription opens the paywall', (tester) async {
    await pumpSubscription(tester);

    await tester.tap(
      find.text(l.settingsManageAccount_purchaseNewSubscription),
    );
    await tester.pumpAndSettle();

    expect(find.text(subscriptionPaywallMarker), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('the Settings list no longer offers Subscription', (tester) async {
    // Subscription moved into the Account & Profile menu's Account group, which
    // `accounts_profile_menu_test.dart` pins on that side. Here: neither Go
    // Premium (removed earlier) nor Subscription may sit in the Settings list,
    // so the paywall is reachable from exactly one place.
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
    expect(find.text(l.settingsSubscription_title), findsNothing);
    expect(find.text(l.settingsScreen_backupAndRestore), findsOneWidget);

    await unmountApp(tester);
  });
}
