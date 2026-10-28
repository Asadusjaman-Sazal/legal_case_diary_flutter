/// Accounts & Profile menu — the sectioned layout.
///
/// The menu is grouped under two labelled headers: **Profile** (Profile) and
/// **Account** (Manage Account, App Lock, Devices). **Subscription** moved to
/// its own Settings entry under Firm at 0.0.701 and is pinned in
/// `subscription_menu_screen_test`; **Firm** did the same at 0.0.663 and is
/// pinned in `firm_menu_screen_test`. Devices is offered
/// only where the plan holds more than one device — Pro and the chamber tiers —
/// so Free and Starter never see it. These tests pin this structure: section
/// labels, rows, their order, the Devices rule and each row's destination.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
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

  testWidgets('groups the rows under Profile and Account', (tester) async {
    await pumpMenu(
      tester,
      seed: (db) => seedIndividual(db, premium: true, tier: 'pro'),
    );

    // Section labels. "Profile" is both the section label and its row title.
    expect(
      find.text(l.settingsAccountProfile_sectionProfile),
      findsNWidgets(2),
    );
    expect(find.text(l.settingsAccountProfile_sectionAccount), findsOneWidget);
    // Subscription is its own Settings entry now (0.0.701), as Firm was at
    // 0.0.663, so neither section is drawn here.
    expect(find.text(l.settingsSubscription_title), findsNothing);
    expect(find.text(l.settingsFirm_title), findsNothing);

    // Account rows.
    expect(find.text(l.settingsAccountProfile_profileSubtitle), findsOneWidget);
    expect(find.text(l.settingsScreen_manageAccount), findsOneWidget);
    expect(find.text(l.settingsAppLock_title), findsOneWidget);
    expect(find.text(l.devices_title), findsOneWidget);

    // Four rows in total; Change Password is not offered from here, and the
    // subscription and firm rows live behind their own Settings entries.
    expect(find.byType(SettingsMenuCard), findsNWidgets(4));
    expect(find.text(l.settingsManageAccount_changePassword), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('the sections and rows keep their order', (tester) async {
    // Ordering is asserted by geometry, so a reordering cannot pass unseen.
    await pumpMenu(
      tester,
      seed: (db) => seedIndividual(db, premium: true, tier: 'pro'),
    );

    final accountY = tester
        .getTopLeft(find.text(l.settingsAccountProfile_sectionAccount))
        .dy;
    final manageY = tester
        .getTopLeft(find.text(l.settingsScreen_manageAccount))
        .dy;
    final lockY = tester.getTopLeft(find.text(l.settingsAppLock_title)).dy;
    final devicesY = tester.getTopLeft(find.text(l.devices_title)).dy;

    expect(manageY, greaterThan(accountY));
    expect(lockY, greaterThan(manageY));
    expect(devicesY, greaterThan(lockY));

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

  testWidgets('the Account section offers no Security row', (tester) async {
    // A free individual sees three cards — Profile, Manage Account and App
    // Lock — so none is a Security entry that only lost its label, Devices is
    // not offered, and the subscription rows have their own Settings entry.
    await pumpMenu(tester, seed: (db) => seedIndividual(db, premium: false));

    expect(find.byType(SettingsMenuCard), findsNWidgets(3));
    expect(find.text(l.settingsScreen_manageAccount), findsOneWidget);
    expect(find.text(l.settingsAppLock_title), findsOneWidget);
    expect(find.text(l.devices_title), findsNothing);
    expect(find.text(l.settingsSubscription_managePlanTitle), findsNothing);
    expect(find.text(l.payments_historyTitle), findsNothing);
    expect(find.text(l.settingsManageAccount_changePassword), findsNothing);

    await unmountApp(tester);
  });
}
