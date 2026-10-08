/// Accounts & Profile menu — the sectioned layout.
///
/// The menu was reorganised into three labelled groups: **Profile** (Profile),
/// **Account** (Manage Account, Subscription, Security) and **Firm** (Manage
/// Associates, shown only when that entry is offered). Subscription moved here
/// from the main Settings list and Security is new, holding the Change Password
/// row that left Manage Account. These tests pin that structure — the section
/// labels, the rows, and where the two new rows go; the Manage Associates
/// visibility rules stay in `manage_associates_test.dart`.
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

import 'auth_test_support.dart';
import 'settings_test_support.dart';

/// Marker rendered by each stand-in destination route.
const String subscriptionMarker = 'Subscription Route';
const String securityMarker = 'Security Route';

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
          path: AppRoutes.settingsSecurity,
          builder: (_, _) => const Scaffold(body: Text(securityMarker)),
        ),
      ],
    );
    l = await AppLocalizations.delegate.load(const Locale('en'));

    if (seed != null) {
      await seed(harness.db);
      await tester.pumpAndSettle();
    }
  }

  /// An individual with the given entitlement.
  Future<void> seedIndividual(AppDatabase db, {required bool premium}) =>
      ProfilesDao(db).upsert(
        ProfilesCompanion(
          id: const Value('user-1'),
          fullName: const Value('Adv. Rahim Uddin'),
          role: const Value(AccountRole.individual),
          subscriptionStatus: Value(premium ? 'active' : 'free'),
          subscriptionExpiry: Value(premium ? _premiumExpiryMs : null),
          createdAt: const Value(1),
        ),
      );

  testWidgets('groups the rows under Profile, Account and Firm', (tester) async {
    await pumpMenu(tester, seed: (db) => seedIndividual(db, premium: true));

    // Section labels.
    // "Profile" is both the section label and its row title.
    expect(find.text(l.settingsAccountProfile_sectionProfile), findsNWidgets(2));
    expect(find.text(l.settingsAccountProfile_sectionAccount), findsOneWidget);
    expect(find.text(l.settingsAccountProfile_sectionFirm), findsOneWidget);

    // Rows. The Profile card is asserted by its unique subtitle, because its
    // title is the same word as its section label.
    expect(find.text(l.settingsAccountProfile_profileSubtitle), findsOneWidget);
    expect(find.text(l.settingsScreen_manageAccount), findsOneWidget);
    expect(find.text(l.settingsSubscription_title), findsOneWidget);
    expect(find.text(l.settingsAccountProfile_security), findsOneWidget);
    expect(find.text(l.manageAssociates_title), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('the Account section comes before the Firm section', (
    tester,
  ) async {
    // Ordering is asserted by geometry, so a reordering cannot pass unseen.
    await pumpMenu(tester, seed: (db) => seedIndividual(db, premium: true));

    final accountY =
        tester.getTopLeft(find.text(l.settingsAccountProfile_sectionAccount)).dy;
    final securityY =
        tester.getTopLeft(find.text(l.settingsAccountProfile_security)).dy;
    final firmY =
        tester.getTopLeft(find.text(l.settingsAccountProfile_sectionFirm)).dy;

    expect(securityY, greaterThan(accountY));
    expect(firmY, greaterThan(securityY));

    await unmountApp(tester);
  });

  testWidgets('hides the Firm section when Manage Associates is hidden', (
    tester,
  ) async {
    // An empty "Firm" header must never dangle above nothing.
    await pumpMenu(tester, seed: (db) => seedIndividual(db, premium: false));

    expect(find.text(l.manageAssociates_title), findsNothing);
    expect(find.text(l.settingsAccountProfile_sectionFirm), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('Subscription opens the Subscription screen', (tester) async {
    await pumpMenu(tester);

    await tester.tap(find.text(l.settingsSubscription_title));
    await tester.pumpAndSettle();

    expect(find.text(subscriptionMarker), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('Security opens the Security screen', (tester) async {
    await pumpMenu(tester);

    await tester.tap(find.text(l.settingsAccountProfile_security));
    await tester.pumpAndSettle();

    expect(find.text(securityMarker), findsOneWidget);

    await unmountApp(tester);
  });
}
