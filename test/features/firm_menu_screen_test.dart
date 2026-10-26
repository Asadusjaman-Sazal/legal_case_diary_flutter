/// The Firm menu behind the Settings row (0.0.663).
///
/// The Settings list offers **Firm** to every account (user request); the page
/// keeps the rows' old visibility: an owner sees **Manage Firm** and the
/// **Delete Requests** queue, an associate sees the queue only, and an
/// individual sees **Create a Firm** (pinned in `manage_associates_test`). The
/// queue keeps its waiting count and opens its own screen.
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
import 'package:legal_case_diary/features/accounts_and_profile/presentation/firm_menu_screen.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_menu_card.dart';
import 'package:legal_case_diary/sync/delete_requests_dao.dart';

import 'auth_test_support.dart';
import 'settings_test_support.dart';

const String manageFirmMarker = 'Manage Firm Route';
const String deleteRequestsMarker = 'Delete Requests Route';

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

  /// Pumps the Firm menu on its own route, then seeds [seed] once adoption ran.
  Future<void> pumpFirm(
    WidgetTester tester, {
    Future<void> Function(AppDatabase db)? seed,
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpSettingsRouter(
      tester,
      location: AppRoutes.settingsFirm,
      overrides: await harness.setUp(),
      routes: [
        GoRoute(
          path: AppRoutes.settingsFirm,
          builder: (_, _) => const FirmMenuScreen(),
        ),
        GoRoute(
          path: AppRoutes.settingsManageAssociates,
          builder: (_, _) => const Scaffold(body: Text(manageFirmMarker)),
        ),
        GoRoute(
          path: AppRoutes.settingsDeleteRequests,
          builder: (_, _) => const Scaffold(body: Text(deleteRequestsMarker)),
        ),
      ],
    );
    l = await AppLocalizations.delegate.load(const Locale('en'));

    if (seed != null) {
      await seed(harness.db);
      await tester.pumpAndSettle();
    }
  }

  /// A cached profile that belongs to a chamber, which is what firm mode reads.
  Future<void> seedFirmMember(
    AppDatabase db, {
    String role = AccountRole.owner,
  }) => ProfilesDao(db).upsert(
    ProfilesCompanion(
      id: const Value('user-1'),
      fullName: const Value('Adv. Rahim Uddin'),
      role: Value(role),
      firmId: const Value('firm-1'),
      tier: const Value('firm'),
      subscriptionStatus: const Value('active'),
      subscriptionExpiry: Value(_premiumExpiryMs),
      createdAt: const Value(1),
    ),
  );

  testWidgets('the owner sees Manage Firm, then Delete Requests', (tester) async {
    await pumpFirm(tester, seed: (db) => seedFirmMember(db));

    expect(find.text(l.settingsFirm_title), findsOneWidget);
    expect(find.text(l.manageAssociates_title), findsOneWidget);
    expect(find.text(l.deleteRequests_title), findsOneWidget);
    // Every card on the page carries a line under its title.
    expect(
      find.text(l.settingsAccountProfile_deleteRequestsSubtitle),
      findsOneWidget,
    );
    for (final card in tester.widgetList<SettingsMenuCard>(
      find.byType(SettingsMenuCard),
    )) {
      expect(card.subtitle, isNotNull, reason: card.title);
    }
    // The queue sits directly after the roster card.
    expect(
      tester.getTopLeft(find.text(l.deleteRequests_title)).dy,
      greaterThan(tester.getTopLeft(find.text(l.manageAssociates_title)).dy),
    );

    await unmountApp(tester);
  });

  testWidgets('an associate is offered Delete Requests but not Manage Firm', (
    tester,
  ) async {
    await pumpFirm(
      tester,
      seed: (db) => seedFirmMember(db, role: AccountRole.associate),
    );

    // The queue is every member's; firm administration is the owner's alone.
    expect(find.text(l.deleteRequests_title), findsOneWidget);
    expect(find.text(l.manageAssociates_title), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('Manage Firm opens its screen', (tester) async {
    await pumpFirm(tester, seed: (db) => seedFirmMember(db));

    await tester.tap(find.text(l.manageAssociates_title));
    await tester.pumpAndSettle();

    expect(find.text(manageFirmMarker), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('the queue carries its waiting count and opens its screen', (
    tester,
  ) async {
    await pumpFirm(
      tester,
      seed: (db) async {
        await seedFirmMember(db);
        // A colleague's pending request is what waits on this owner.
        await DeleteRequestsDao(db).insert(
          DeleteRequestsCompanion(
            id: const Value('req-1'),
            firmId: const Value('firm-1'),
            entityType: const Value('note'),
            entityId: const Value('note-1'),
            entitySnapshot: const Value('{}'),
            targetBaseVersion: const Value(2),
            requestedBy: const Value('user-2'),
            status: const Value('pending'),
            createdAt: const Value(1000),
            updatedAt: const Value(2000),
            version: const Value(4),
            lastModifiedBy: const Value('user-2'),
            isDeleted: const Value(false),
          ),
        );
      },
    );
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text(l.deleteRequests_title));
    await tester.pumpAndSettle();
    expect(find.text(deleteRequestsMarker), findsOneWidget);

    await unmountApp(tester);
  });
}
