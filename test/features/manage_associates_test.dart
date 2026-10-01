/// Task 20 Phase 1 — the Manage Associates screen and the individual → firm
/// transition.
///
/// Five things the phase promises are pinned here: the offline body replaces the
/// controls (plan §1, Online-Only Firm Administration); a free entitlement is
/// sent to the Paywall and creates nothing (plan §6); a premium individual's
/// create-firm action is what calls `ensure_firm` and then invites the first
/// associate; the owner's roster is the live server read, rendered with names and
/// roles; and a firm member who is not the owner never sees a create-firm form —
/// not even through the deep link that the hidden menu entry would normally be
/// the only way into.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/firm_repository.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/firms_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/profiles_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_repository.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/accounts_profile_menu_screen.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/manage_associates_screen.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/sync/connectivity_monitor.dart';

import 'auth_test_support.dart';
import 'settings_test_support.dart';

/// Marker rendered by the stand-in Paywall route.
const String manageAssociatesPaywallMarker = 'Paywall Route';

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

  /// Pumps the Manage Associates route, then seeds [seed] once adoption has run.
  Future<void> pumpManageAssociates(
    WidgetTester tester, {
    Future<void> Function(AppDatabase db)? seed,
    bool online = true,
    List<Override> overrides = const <Override>[],
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpSettingsRouter(
      tester,
      location: AppRoutes.settingsManageAssociates,
      overrides: await harness.setUp(
        extra: [
          isOnlineProvider.overrideWith((_) => Stream<bool>.value(online)),
          ...overrides,
        ],
      ),
      routes: [
        GoRoute(
          path: AppRoutes.settingsManageAssociates,
          builder: (_, _) => const ManageAssociatesScreen(),
        ),
        GoRoute(
          path: AppRoutes.paywall,
          builder: (_, _) =>
              const Scaffold(body: Text(manageAssociatesPaywallMarker)),
        ),
      ],
    );
    l = await AppLocalizations.delegate.load(const Locale('en'));

    if (seed != null) {
      await seed(harness.db);
      await tester.pumpAndSettle();
    }
  }

  /// Writes an individual profile with the given entitlement.
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

  /// Writes an owner profile plus the firm it owns.
  Future<void> seedOwner(AppDatabase db, {String role = AccountRole.owner}) async {
    await ProfilesDao(db).upsert(
      ProfilesCompanion(
        id: const Value('user-1'),
        fullName: const Value('Adv. Rahim Uddin'),
        role: Value(role),
        firmId: const Value('firm-1'),
        subscriptionStatus: const Value('active'),
        subscriptionExpiry: Value(_premiumExpiryMs),
        createdAt: const Value(1),
      ),
    );
    await FirmsDao(db).upsert(
      FirmsCompanion(
        id: const Value('firm-1'),
        name: const Value('Rahman & Associates'),
        ownerId: const Value('user-1'),
        subscriptionStatus: const Value('active'),
        subscriptionExpiry: Value(_premiumExpiryMs),
        createdAt: const Value(1),
      ),
    );
  }

  testWidgets('offline says so instead of offering firm controls', (
    tester,
  ) async {
    await pumpManageAssociates(tester, online: false);

    expect(find.text(l.auth_errorFirmAdminOffline), findsOneWidget);
    expect(find.text(l.manageAssociates_addAssociate), findsNothing);
    expect(find.text(l.manageAssociates_createFirmIntro), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('a free account is sent to the Paywall and creates nothing', (
    tester,
  ) async {
    await pumpManageAssociates(
      tester,
      seed: (db) => seedIndividual(db, premium: false),
    );

    // The card says why, and the action offers the Paywall rather than a form
    // whose submit the server would refuse.
    expect(find.text(l.auth_errorPremiumRequired), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('manage-associates-firm-name')),
      'Rahman & Associates',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.manageAssociates_goPremium));
    await tester.pumpAndSettle();

    expect(find.text(manageAssociatesPaywallMarker), findsOneWidget);
    expect(
      harness.firm.ensuredFirmNames,
      isEmpty,
      reason: 'the gate is checked before the server is asked',
    );
    expect(harness.firm.createInviteCalls, 0);

    await unmountApp(tester);
  });

  testWidgets('a premium individual creates the firm, then the code is shown', (
    tester,
  ) async {
    await pumpManageAssociates(
      tester,
      seed: (db) => seedIndividual(db, premium: true),
    );

    await tester.enterText(
      find.byKey(const ValueKey('manage-associates-firm-name')),
      'Rahman & Associates',
    );
    await tester.pumpAndSettle();

    // An empty name leaves the action disabled: the server refuses a blank firm
    // name on purpose and the client does not send one to find that out.
    expect(find.text(l.manageAssociates_createFirm), findsOneWidget);

    await tester.tap(find.text(l.manageAssociates_createFirm));
    await tester.pumpAndSettle();

    expect(harness.firm.ensuredFirmNames, ['Rahman & Associates']);
    expect(
      harness.firm.createInviteCalls,
      1,
      reason: 'the first associate is invited in the same step',
    );
    expect(find.text(l.manageAssociates_inviteTitle), findsOneWidget);
    expect(
      find.text(harness.firm.invite.code),
      findsOneWidget,
      reason: 'the plaintext is shown once, here',
    );

    await unmountApp(tester);
  });

  testWidgets('the owner sees the roster with its names and roles', (
    tester,
  ) async {
    harness.firm.members = const [
      FirmMemberSummary(
        userId: 'user-1',
        role: AccountRole.owner,
        fullName: 'Adv. Rahim Uddin',
        canAdd: true,
        canEdit: true,
        canDelete: true,
      ),
      FirmMemberSummary(
        userId: 'user-2',
        role: AccountRole.associate,
        fullName: 'Adv. Karim',
        canAdd: true,
        canEdit: true,
        canDelete: false,
      ),
    ];

    await pumpManageAssociates(tester, seed: seedOwner);

    expect(find.text('Rahman & Associates'), findsOneWidget);
    expect(find.text(l.manageAssociates_sectionMembers), findsOneWidget);
    expect(find.text('Adv. Rahim Uddin'), findsOneWidget);
    expect(find.text('Adv. Karim'), findsOneWidget);
    expect(find.text(l.settingsManageAccount_roleOwner), findsOneWidget);
    expect(find.text(l.settingsManageAccount_roleAssociate), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('the owner invites without creating a second firm', (tester) async {
    harness.firm.members = const [
      FirmMemberSummary(
        userId: 'user-1',
        role: AccountRole.owner,
        fullName: 'Adv. Rahim Uddin',
        canAdd: true,
        canEdit: true,
        canDelete: true,
      ),
    ];

    await pumpManageAssociates(tester, seed: seedOwner);

    await tester.tap(find.text(l.manageAssociates_addAssociate));
    await tester.pumpAndSettle();

    expect(harness.firm.createInviteCalls, 1);
    expect(
      harness.firm.ensuredFirmNames,
      isEmpty,
      reason: 'the firm already exists; ensure_firm is for the first one only',
    );
    expect(find.text(l.manageAssociates_inviteTitle), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('a roster read that fails is reported, never swallowed', (
    tester,
  ) async {
    harness.firm.membersError = const AuthFailure(
      AuthFailureKind.firmAdminOffline,
    );

    await pumpManageAssociates(tester, seed: seedOwner);

    expect(find.text(l.auth_errorFirmAdminOffline), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('an associate is never offered a create-firm form', (
    tester,
  ) async {
    await pumpManageAssociates(
      tester,
      seed: (db) => seedOwner(db, role: AccountRole.associate),
    );

    expect(find.text(l.manageAssociates_ownerOnly), findsOneWidget);
    expect(find.text(l.manageAssociates_createFirmIntro), findsNothing);
    expect(find.text(l.manageAssociates_addAssociate), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('the Accounts & Profile menu hides Manage Associates from an '
      'associate', (tester) async {
    // The entry is the only intended way in: an individual needs it (adding the
    // first associate is what creates the firm), an owner has it, and an
    // associate's taps would only be refused server-side.
    await tester.binding.setSurfaceSize(const Size(420, 1000));
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
      ],
    );
    l = await AppLocalizations.delegate.load(const Locale('en'));
    await seedOwner(harness.db, role: AccountRole.associate);
    await tester.pumpAndSettle();

    expect(find.text(l.manageAssociates_title), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('the owner sees the outstanding invites and can revoke one', (
    tester,
  ) async {
    harness.firm
      ..members = const [
        FirmMemberSummary(
          userId: 'user-1',
          role: AccountRole.owner,
          fullName: 'Adv. Rahim Uddin',
          canAdd: true,
          canEdit: true,
          canDelete: true,
        ),
      ]
      // A code that has been sent but not yet used is the only thing the server
      // can say about it: the plaintext is gone, so the row is named by its date.
      ..invites = [
        FirmInviteSummary(
          id: 'invite-9',
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      ];

    await pumpManageAssociates(tester, seed: seedOwner);

    expect(find.text(l.manageAssociates_sectionInvites), findsOneWidget);
    expect(
      find.text(l.manageAssociates_noInvites),
      findsNothing,
      reason: 'there is one outstanding invite',
    );

    await tester.tap(find.byKey(const ValueKey('manage-associates-revoke-invite-9')));
    await tester.pumpAndSettle();

    // Revoking is confirmed first: the code stops working at once and cannot be
    // shown again, so it is not a one-tap accident.
    expect(find.text(l.manageAssociates_revokeInviteTitle), findsOneWidget);
    expect(harness.firm.revokedInviteIds, isEmpty);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(l.manageAssociates_revokeInvite),
      ),
    );
    await tester.pumpAndSettle();

    expect(harness.firm.revokedInviteIds, ['invite-9']);
    expect(find.text(l.manageAssociates_inviteRevoked), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('no outstanding invites says so', (tester) async {
    harness.firm.members = const [
      FirmMemberSummary(
        userId: 'user-1',
        role: AccountRole.owner,
        fullName: 'Adv. Rahim Uddin',
        canAdd: true,
        canEdit: true,
        canDelete: true,
      ),
    ];

    await pumpManageAssociates(tester, seed: seedOwner);

    expect(find.text(l.manageAssociates_noInvites), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('a member\'s sheet writes the role and the three flags', (
    tester,
  ) async {
    harness.firm.members = const [
      FirmMemberSummary(
        userId: 'user-1',
        role: AccountRole.owner,
        fullName: 'Adv. Rahim Uddin',
        canAdd: true,
        canEdit: true,
        canDelete: true,
      ),
      FirmMemberSummary(
        userId: 'user-2',
        role: AccountRole.associate,
        fullName: 'Adv. Karim',
        canAdd: true,
        canEdit: false,
        canDelete: false,
      ),
    ];

    await pumpManageAssociates(tester, seed: seedOwner);

    await tester.tap(
      find.byKey(const ValueKey('manage-associates-member-user-2')),
    );
    await tester.pumpAndSettle();

    // The sheet opens on the member's current values, so a save that changes
    // nothing writes nothing surprising.
    expect(find.text(l.manageAssociates_permissionsTitle), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('member-role-viewer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.manageAssociates_permissionDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.manageAssociates_savePermissions));
    await tester.pumpAndSettle();

    expect(harness.firm.permissionWrites, hasLength(1));
    final write = harness.firm.permissionWrites.single;
    expect(write.userId, 'user-2');
    expect(write.role, AccountRole.viewer);
    expect(write.canAdd, isTrue, reason: 'untouched flags keep their value');
    expect(write.canEdit, isFalse);
    expect(write.canDelete, isTrue);
    expect(find.text(l.manageAssociates_permissionsUpdated), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('removing an associate asks first and names what it costs', (
    tester,
  ) async {
    harness.firm.members = const [
      FirmMemberSummary(
        userId: 'user-2',
        role: AccountRole.associate,
        fullName: 'Adv. Karim',
        canAdd: true,
        canEdit: true,
        canDelete: false,
      ),
    ];

    await pumpManageAssociates(tester, seed: seedOwner);

    await tester.tap(
      find.byKey(const ValueKey('manage-associates-member-user-2')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('member-remove')));
    await tester.pumpAndSettle();

    expect(find.text(l.manageAssociates_removeAssociateTitle), findsOneWidget);
    expect(
      harness.firm.removedMemberIds,
      isEmpty,
      reason: 'the removal is the server\'s decision, and it is asked once',
    );

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(l.manageAssociates_removeAssociate),
      ),
    );
    await tester.pumpAndSettle();

    expect(harness.firm.removedMemberIds, ['user-2']);
    expect(find.text(l.manageAssociates_associateRemoved), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('declining the removal removes nobody', (tester) async {
    harness.firm.members = const [
      FirmMemberSummary(
        userId: 'user-2',
        role: AccountRole.associate,
        fullName: 'Adv. Karim',
        canAdd: true,
        canEdit: true,
        canDelete: false,
      ),
    ];

    await pumpManageAssociates(tester, seed: seedOwner);

    await tester.tap(
      find.byKey(const ValueKey('manage-associates-member-user-2')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('member-remove')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.sharedActions_cancel));
    await tester.pumpAndSettle();

    expect(harness.firm.removedMemberIds, isEmpty);

    await unmountApp(tester);
  });

  testWidgets('the owner\'s own row opens nothing', (tester) async {
    harness.firm.members = const [
      FirmMemberSummary(
        userId: 'user-1',
        role: AccountRole.owner,
        fullName: 'Adv. Rahim Uddin',
        canAdd: true,
        canEdit: true,
        canDelete: true,
      ),
    ];

    await pumpManageAssociates(tester, seed: seedOwner);

    // Ownership is `firms.owner_id`, not a row flag: editing the owner's own
    // `firm_members` row would change nothing, so the row offers nothing.
    expect(
      find.byKey(const ValueKey('manage-associates-member-user-1')),
      findsNothing,
    );
    expect(find.text(l.manageAssociates_permissionsTitle), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('a failed permission write is reported, not swallowed', (
    tester,
  ) async {
    harness.firm
      ..members = const [
        FirmMemberSummary(
          userId: 'user-2',
          role: AccountRole.associate,
          fullName: 'Adv. Karim',
          canAdd: true,
          canEdit: true,
          canDelete: false,
        ),
      ]
      ..permissionsError = const AuthFailure(AuthFailureKind.firmAdminOffline);

    await pumpManageAssociates(tester, seed: seedOwner);

    await tester.tap(
      find.byKey(const ValueKey('manage-associates-member-user-2')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.manageAssociates_savePermissions));
    await tester.pumpAndSettle();

    expect(find.text(l.auth_errorFirmAdminOffline), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('the Accounts & Profile menu offers Manage Associates to an '
      'individual', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
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
      ],
    );
    l = await AppLocalizations.delegate.load(const Locale('en'));
    await seedIndividual(harness.db, premium: true);
    await tester.pumpAndSettle();

    expect(find.text(l.manageAssociates_title), findsOneWidget);

    await unmountApp(tester);
  });
}
