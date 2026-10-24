/// Accounts & Profile menu — the sectioned layout.
///
/// The menu is grouped under four labelled headers: **Profile** (Profile),
/// **Account** (Manage Account, App Lock, Devices), **Subscription** (Manage
/// Plan, Subscription Plans, Subscription History) and **Firm** (Manage
/// Associates, shown only when that entry is offered). The Subscription section
/// replaced the one intermediate Subscription screen at 0.0.624; a chamber
/// member sees Manage Plan and History but not the plans. Devices is offered
/// only where the plan holds more than one device — Pro and the chamber tiers —
/// so Free and Starter never see it. These tests pin that structure: section
/// labels, rows, their order, the Devices rule, the member rule and each row's
/// destination. The Manage Associates visibility rules stay in
/// `manage_associates_test.dart`.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/profiles_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_repository.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/accounts_profile_menu_screen.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_menu_card.dart';

import 'auth_test_support.dart';
import 'settings_test_support.dart';

/// Markers rendered by the stand-in destination routes.
const String managePlanMarker = 'Manage Plan Route';
const String plansMarker = 'Subscription Plans Route';
const String historyMarker = 'Subscription History Route';
const String appLockMarker = 'App Lock Route';
const String devicesMarker = 'Devices Route';

/// Epoch ms 30 days from now: an active premium entitlement for the caches.
int get _premiumExpiryMs =>
    DateTime.now().toUtc().add(const Duration(days: 30)).millisecondsSinceEpoch;

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

  /// Pumps the menu on its own route, then seeds [seed] once adoption has run.
  Future<void> pumpMenu(
    WidgetTester tester, {
    Future<void> Function(AppDatabase db)? seed,
    List<Override> extra = const <Override>[],
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpSettingsRouter(
      tester,
      location: AppRoutes.settingsAccountProfile,
      overrides: [...await harness.setUp(), ...extra],
      routes: [
        GoRoute(
          path: AppRoutes.settingsAccountProfile,
          builder: (_, _) => const AccountsProfileMenuScreen(),
        ),
        GoRoute(
          path: AppRoutes.settingsSubscriptionDetails,
          builder: (_, _) => const Scaffold(body: Text(managePlanMarker)),
        ),
        GoRoute(
          path: AppRoutes.paywall,
          builder: (_, _) => const Scaffold(body: Text(plansMarker)),
        ),
        GoRoute(
          path: AppRoutes.settingsSubscriptionHistory,
          builder: (_, _) => const Scaffold(body: Text(historyMarker)),
        ),
        GoRoute(
          path: AppRoutes.settingsAppLock,
          builder: (_, _) => const Scaffold(body: Text(appLockMarker)),
        ),
        GoRoute(
          path: AppRoutes.settingsDevices,
          builder: (_, _) => const Scaffold(body: Text(devicesMarker)),
        ),
      ],
    );
    l = await AppLocalizations.delegate.load(const Locale('en'));

    if (seed != null) {
      await seed(harness.db);
      await tester.pumpAndSettle();
    }
  }

  /// An individual with the given entitlement and stored tier.
  Future<void> seedIndividual(
    AppDatabase db, {
    required bool premium,
    String tier = 'free',
  }) => ProfilesDao(db).upsert(
    ProfilesCompanion(
      id: const Value('user-1'),
      fullName: const Value('Adv. Rahim Uddin'),
      role: const Value(AccountRole.individual),
      tier: Value(tier),
      subscriptionStatus: Value(premium ? 'active' : 'free'),
      subscriptionExpiry: Value(premium ? _premiumExpiryMs : null),
      createdAt: const Value(1),
    ),
  );

  testWidgets('groups the rows under Profile, Account, Subscription and Firm', (
    tester,
  ) async {
    await pumpMenu(
      tester,
      seed: (db) => seedIndividual(db, premium: true, tier: 'pro'),
    );

    // Section labels. "Profile" is both the section label and its row title.
    expect(find.text(l.settingsAccountProfile_sectionProfile), findsNWidgets(2));
    expect(find.text(l.settingsAccountProfile_sectionAccount), findsOneWidget);
    expect(find.text(l.settingsSubscription_title), findsOneWidget);
    expect(find.text(l.settingsAccountProfile_sectionFirm), findsOneWidget);

    // Account rows.
    expect(find.text(l.settingsAccountProfile_profileSubtitle), findsOneWidget);
    expect(find.text(l.settingsScreen_manageAccount), findsOneWidget);
    expect(find.text(l.settingsAppLock_title), findsOneWidget);
    expect(find.text(l.devices_title), findsOneWidget);

    // Subscription rows, each with its own subtitle.
    expect(find.text(l.settingsSubscription_managePlanTitle), findsOneWidget);
    expect(
      find.text(l.settingsManageAccount_purchaseNewSubscription),
      findsOneWidget,
    );
    expect(find.text(l.payments_historyTitle), findsOneWidget);
    expect(find.text(l.settingsAccountProfile_managePlanSubtitle), findsOneWidget);
    expect(
      find.text(l.settingsAccountProfile_subscriptionPlansSubtitle),
      findsOneWidget,
    );
    expect(
      find.text(l.settingsAccountProfile_subscriptionHistorySubtitle),
      findsOneWidget,
    );

    expect(find.text(l.manageAssociates_title), findsOneWidget);
    // Eight rows in total; Change Password is not offered from here.
    expect(find.byType(SettingsMenuCard), findsNWidgets(8));
    expect(find.text(l.settingsManageAccount_changePassword), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('the sections and rows keep their order', (tester) async {
    // Ordering is asserted by geometry, so a reordering cannot pass unseen.
    await pumpMenu(
      tester,
      seed: (db) => seedIndividual(db, premium: true, tier: 'pro'),
    );

    final accountY =
        tester.getTopLeft(find.text(l.settingsAccountProfile_sectionAccount)).dy;
    final manageY =
        tester.getTopLeft(find.text(l.settingsScreen_manageAccount)).dy;
    final lockY = tester.getTopLeft(find.text(l.settingsAppLock_title)).dy;
    final devicesY = tester.getTopLeft(find.text(l.devices_title)).dy;
    final subscriptionY =
        tester.getTopLeft(find.text(l.settingsSubscription_title)).dy;
    final planY =
        tester.getTopLeft(find.text(l.settingsSubscription_managePlanTitle)).dy;
    final plansY =
        tester.getTopLeft(
          find.text(l.settingsManageAccount_purchaseNewSubscription),
        ).dy;
    final historyY = tester.getTopLeft(find.text(l.payments_historyTitle)).dy;
    final firmY =
        tester.getTopLeft(find.text(l.settingsAccountProfile_sectionFirm)).dy;

    expect(manageY, greaterThan(accountY));
    expect(lockY, greaterThan(manageY));
    expect(devicesY, greaterThan(lockY));
    expect(subscriptionY, greaterThan(devicesY));
    expect(planY, greaterThan(subscriptionY));
    expect(plansY, greaterThan(planY));
    expect(historyY, greaterThan(plansY));
    expect(firmY, greaterThan(historyY));

    await unmountApp(tester);
  });

  testWidgets('Devices is hidden on Starter, which holds one device', (
    tester,
  ) async {
    await pumpMenu(
      tester,
      seed: (db) => seedIndividual(db, premium: true, tier: 'starter'),
    );

    // App Lock is offered to every plan; Devices starts at Pro.
    expect(find.text(l.settingsAppLock_title), findsOneWidget);
    expect(find.text(l.devices_title), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('App Lock opens its screen', (tester) async {
    await pumpMenu(
      tester,
      seed: (db) => seedIndividual(db, premium: true, tier: 'pro'),
    );

    await tester.tap(find.text(l.settingsAppLock_title));
    await tester.pumpAndSettle();

    expect(find.text(appLockMarker), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('Devices opens the Devices screen', (tester) async {
    await pumpMenu(
      tester,
      seed: (db) => seedIndividual(db, premium: true, tier: 'pro'),
    );

    await tester.tap(find.text(l.devices_title));
    await tester.pumpAndSettle();

    expect(find.text(devicesMarker), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('Manage Plan opens the plan screen', (tester) async {
    await pumpMenu(tester);

    await tester.tap(find.text(l.settingsSubscription_managePlanTitle));
    await tester.pumpAndSettle();

    expect(find.text(managePlanMarker), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('Subscription Plans opens the plans screen', (tester) async {
    await pumpMenu(tester);

    await tester.tap(
      find.text(l.settingsManageAccount_purchaseNewSubscription),
    );
    await tester.pumpAndSettle();

    expect(find.text(plansMarker), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('Subscription History opens the history screen', (tester) async {
    await pumpMenu(tester);

    await tester.tap(find.text(l.payments_historyTitle));
    await tester.pumpAndSettle();

    expect(find.text(historyMarker), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('a chamber member is not offered Subscription Plans', (
    tester,
  ) async {
    await pumpMenu(
      tester,
      extra: [firmMemberProvider.overrideWithValue(true)],
    );

    expect(find.text(l.settingsSubscription_managePlanTitle), findsOneWidget);
    expect(find.text(l.payments_historyTitle), findsOneWidget);
    expect(
      find.text(l.settingsManageAccount_purchaseNewSubscription),
      findsNothing,
    );

    await unmountApp(tester);
  });

  testWidgets('hides the Firm section when Manage Associates is hidden', (
    tester,
  ) async {
    // An empty "Firm" header must never dangle above nothing.
    await pumpMenu(tester, seed: (db) => seedIndividual(db, premium: false));

    expect(find.text(l.manageAssociates_title), findsNothing);
    expect(find.text(l.settingsAccountProfile_sectionFirm), findsNothing);
    // A free individual has no multi-device support either.
    expect(find.text(l.devices_title), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('the Account section offers no Security row', (tester) async {
    // A free individual sees six cards — Profile, Manage Account, App Lock,
    // Manage Plan, Subscription Plans, Subscription History — so none is a
    // Security entry that only lost its label, and Devices is not offered.
    await pumpMenu(tester, seed: (db) => seedIndividual(db, premium: false));

    expect(find.byType(SettingsMenuCard), findsNWidgets(6));
    expect(find.text(l.settingsScreen_manageAccount), findsOneWidget);
    expect(find.text(l.settingsAppLock_title), findsOneWidget);
    expect(find.text(l.devices_title), findsNothing);
    expect(find.text(l.settingsSubscription_managePlanTitle), findsOneWidget);
    expect(
      find.text(l.settingsManageAccount_purchaseNewSubscription),
      findsOneWidget,
    );
    expect(find.text(l.payments_historyTitle), findsOneWidget);
    expect(find.text(l.settingsManageAccount_changePassword), findsNothing);

    await unmountApp(tester);
  });
}
