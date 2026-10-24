/// Accounts & Profile menu — the sectioned layout.
///
/// The menu is grouped under three labelled headers: **Profile** (Profile),
/// **Account** (Manage Account, App Lock, Devices, Subscription) and **Firm**
/// (Manage Associates, shown only when that entry is offered). Subscription
/// moved here from the main Settings list, and App Lock and Devices moved here
/// from Manage Account (0.0.611, user request). Devices is offered only where
/// the plan holds more than one device — Pro and the chamber tiers — so Free
/// and Starter never see it. The **Security** row that briefly held Change
/// Password is gone (0.0.411). These tests pin that structure — the section
/// labels, the rows, their order, and the Devices visibility rule; the Manage
/// Associates visibility rules stay in `manage_associates_test.dart`.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/profiles_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_repository.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/accounts_profile_menu_screen.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_menu_card.dart';

import 'auth_test_support.dart';
import 'settings_test_support.dart';

/// Markers rendered by the stand-in destination routes.
const String subscriptionMarker = 'Subscription Route';
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
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpSettingsRouter(
      tester,
      location: AppRoutes.settingsAccountProfile,
      overrides: await harness.setUp(),
      routes: [
        GoRoute(
          path: AppRoutes.settingsAccountProfile,
          builder: (_, _) => const AccountsProfileMenuScreen(),
        ),
        GoRoute(
          path: AppRoutes.settingsSubscription,
          builder: (_, _) => const Scaffold(body: Text(subscriptionMarker)),
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

  testWidgets('groups the rows under Profile, Account and Firm', (tester) async {
    await pumpMenu(
      tester,
      seed: (db) => seedIndividual(db, premium: true, tier: 'pro'),
    );

    // Section labels.
    // "Profile" is both the section label and its row title.
    expect(find.text(l.settingsAccountProfile_sectionProfile), findsNWidgets(2));
    expect(find.text(l.settingsAccountProfile_sectionAccount), findsOneWidget);
    expect(find.text(l.settingsAccountProfile_sectionFirm), findsOneWidget);

    // Rows. The Profile card is asserted by its unique subtitle, because its
    // title is the same word as its section label.
    expect(find.text(l.settingsAccountProfile_profileSubtitle), findsOneWidget);
    expect(find.text(l.settingsScreen_manageAccount), findsOneWidget);
    expect(find.text(l.settingsAppLock_title), findsOneWidget);
    expect(find.text(l.devices_title), findsOneWidget);
    expect(find.text(l.settingsSubscription_title), findsOneWidget);
    expect(find.text(l.manageAssociates_title), findsOneWidget);
    // Six rows in total, and Change Password is not offered from here: it lives
    // on Manage Account again (0.0.411).
    expect(find.byType(SettingsMenuCard), findsNWidgets(6));
    expect(find.text(l.settingsManageAccount_changePassword), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('the Account section comes before the Firm section', (
    tester,
  ) async {
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
    final firmY =
        tester.getTopLeft(find.text(l.settingsAccountProfile_sectionFirm)).dy;

    expect(manageY, greaterThan(accountY));
    expect(lockY, greaterThan(manageY));
    expect(devicesY, greaterThan(lockY));
    expect(subscriptionY, greaterThan(devicesY));
    expect(firmY, greaterThan(subscriptionY));

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

  testWidgets('Subscription opens the Subscription screen', (tester) async {
    await pumpMenu(tester);

    await tester.tap(find.text(l.settingsSubscription_title));
    await tester.pumpAndSettle();

    expect(find.text(subscriptionMarker), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('the Account section offers no Security row', (tester) async {
    // The row and its sub-page are gone (0.0.411). A free individual sees four
    // cards (Profile, Manage Account, App Lock, Subscription) — so none is a
    // Security entry that only lost its label, and Devices is not offered.
    await pumpMenu(tester, seed: (db) => seedIndividual(db, premium: false));

    expect(find.byType(SettingsMenuCard), findsNWidgets(4));
    expect(find.text(l.settingsScreen_manageAccount), findsOneWidget);
    expect(find.text(l.settingsAppLock_title), findsOneWidget);
    expect(find.text(l.devices_title), findsNothing);
    expect(find.text(l.settingsSubscription_title), findsOneWidget);
    expect(find.text(l.settingsManageAccount_changePassword), findsNothing);

    await unmountApp(tester);
  });
}
