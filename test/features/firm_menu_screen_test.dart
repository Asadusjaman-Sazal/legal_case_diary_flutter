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
import 'package:legal_case_diary/features/accounts_and_profile/data/firm_repository.dart';
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

  /// A firm-less individual profile: the account `join_firm` may accept.
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

  testWidgets('the owner sees Manage Firm, then Delete Requests', (
    tester,
  ) async {
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

  // -------------------------------------------------------------------------
  // Join a Firm (0.0.664, user request): the entry moved here from the create
  // page, and it is offered to the one account `join_firm` accepts — an
  // individual whose own diary is still empty.
  // -------------------------------------------------------------------------

  testWidgets(
    'an empty individual diary is offered Join a Firm, and it redeems',
    (tester) async {
      await pumpFirm(tester, seed: (db) => seedIndividual(db, premium: false));

      // The entry wears the Create a Firm card's own shape, so the page reads as
      // one list (user request).
      expect(find.text(l.manageAssociates_createFirmTitle), findsOneWidget);
      final join = find.byKey(const ValueKey('firm-join'));
      expect(join, findsOneWidget);
      expect(
        tester.widget<SettingsMenuCard>(join).subtitle,
        l.settingsFirm_joinFirmSubtitle,
      );

      await tester.tap(join);
      await tester.pumpAndSettle();

      // The window, its one sentence, and the two actions.
      expect(find.byType(Dialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text(l.manageAssociates_joinFirmTitle),
        ),
        findsOneWidget,
      );
      expect(find.text(l.manageAssociates_joinFirmIntro), findsOneWidget);
      expect(find.text(l.sharedActions_cancel), findsOneWidget);
      // An empty code cannot be sent: the server would only refuse it.
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('join-firm-send')))
            .onPressed,
        isNull,
      );

      await tester.enterText(
        find.byKey(const ValueKey('join-firm-code')),
        'k3m9p2',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('join-firm-send')));
      await tester.pumpAndSettle();

      expect(harness.firm.redeemedCodes, ['k3m9p2']);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text(l.auth_joinedFirm), findsOneWidget);

      await unmountApp(tester);
    },
  );

  testWidgets('a diary with a case is not offered the join', (tester) async {
    // `join_firm` refuses an account that already holds its own rows, and the
    // seat has to be empty — so a non-zero diary offers nothing.
    await pumpFirm(
      tester,
      seed: (db) async {
        await seedIndividual(db, premium: false);
        // The case's court is a real row: the local schema enforces the
        // reference chain, and the count is what the test is really about.
        await db
            .into(db.courtCategories)
            .insert(
              CourtCategoriesCompanion.insert(
                id: 'join-category',
                nameKey: 'join_category',
                courtLevel: 'lower_courts',
                orderIndex: 0,
                updatedAt: 1,
              ),
            );
        await db
            .into(db.courts)
            .insert(
              const CourtsCompanion(
                id: Value('court-1'),
                courtName: Value('Join Court'),
                higherLowerCourts: Value('lower_courts'),
                courtCategoryId: Value('join-category'),
                updatedAt: Value(1),
              ),
            );
        await db
            .into(db.onBehalfs)
            .insert(
              const OnBehalfsCompanion(
                id: Value('on-behalf-1'),
                courtCategoryId: Value('join-category'),
                name: Value('Petitioner'),
                orderIndex: Value(0),
                updatedAt: Value(1),
              ),
            );
        await db
            .into(db.cases)
            .insert(
              CasesCompanion.insert(
                id: 'case-1',
                userId: 'user-1',
                courtId: 'court-1',
                caseType: 'Civil',
                caseNumber: 'JOIN/2026',
                petitioner: 'Alice',
                respondent: 'Bob',
                onBehalfId: 'on-behalf-1',
                createdAt: 1,
                updatedAt: 1,
              ),
            );
      },
    );

    expect(find.byKey(const ValueKey('firm-join')), findsNothing);
    expect(find.text(l.manageAssociates_joinFirm), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('a paying individual is warned about their plan before joining', (
    tester,
  ) async {
    await pumpFirm(tester, seed: (db) => seedIndividual(db, premium: true));

    final join = find.byKey(const ValueKey('firm-join'));
    await tester.tap(join);
    await tester.pumpAndSettle();

    // Joining neither pauses nor cancels the plan, and the window says so before
    // the code is asked for.
    expect(find.text(l.manageAssociates_joinFirmPlanTitle), findsOneWidget);
    expect(find.text(l.manageAssociates_joinFirmPlanBody), findsOneWidget);

    // Declining opens no code window and redeems nothing.
    await tester.tap(find.text(l.sharedActions_cancel));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('join-firm-code')), findsNothing);
    expect(harness.firm.redeemedCodes, isEmpty);

    // Continuing reaches it.
    await tester.tap(join);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.manageAssociates_joinFirmContinue));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('join-firm-code')), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('a refusal in the join window is shown in the window', (
    tester,
  ) async {
    harness.firm.redeemError = const FirmFailure(
      FirmFailureKind.invalidInviteCode,
    );

    await pumpFirm(tester, seed: (db) => seedIndividual(db, premium: false));

    await tester.tap(find.byKey(const ValueKey('firm-join')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('join-firm-code')),
      'WRONGCODE1',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('join-firm-send')));
    await tester.pumpAndSettle();

    // The window stays open with the sentence, so the code can be corrected.
    expect(find.byKey(const ValueKey('join-firm-code')), findsOneWidget);
    expect(
      find.text(l.auth_errorInvalidCode),
      findsOneWidget,
      reason: 'worded in the window, not behind it',
    );

    await unmountApp(tester);
  });
}
