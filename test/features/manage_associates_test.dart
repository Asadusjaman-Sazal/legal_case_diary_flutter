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
///
/// The entry itself has its own rule (0.0.384): a **free individual** is not
/// offered it at all — `ensure_firm` would refuse them, so the row could only
/// advertise the Paywall — while a **lapsed owner** keeps it, because the server
/// still lets an owner manage the firm they already have.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/errors/error_log.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/firm_logo_store.dart';
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

/// Minimal valid 1x1 PNG, so a `FileImage` decodes without errors.
final List<int> _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFAAH/'
  'q842iQAAAABJRU5ErkJggg==',
);

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
    Map<String, Object> preferences = const <String, Object>{},
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final providerOverrides = await harness.setUp(
      extra: [
        isOnlineProvider.overrideWith((_) => Stream<bool>.value(online)),
        ...overrides,
      ],
    );
    // Values the picture provider reads at its first build (a saved logo, for
    // one). They are written after the harness has reset its preferences and
    // before the screen is pumped.
    for (final entry in preferences.entries) {
      if (entry.value is String) {
        await harness.prefs.setString(entry.key, entry.value as String);
      } else if (entry.value is bool) {
        await harness.prefs.setBool(entry.key, entry.value as bool);
      } else if (entry.value is int) {
        await harness.prefs.setInt(entry.key, entry.value as int);
      }
    }

    await pumpSettingsRouter(
      tester,
      location: AppRoutes.settingsManageAssociates,
      overrides: providerOverrides,
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

  /// Pumps the Accounts & Profile menu on its own route.
  ///
  /// The menu asks two cache questions — may this account manage associates at
  /// all, and is the entry worth offering — so each test seeds the profile that
  /// answers them.
  Future<void> pumpMenu(WidgetTester tester) async {
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
  ///
  /// [premium] false writes a **lapsed** owner: the firm and its roster are
  /// still theirs (plan §6), only the plan has run out.
  Future<void> seedOwner(
    AppDatabase db, {
    String role = AccountRole.owner,
    bool premium = true,
  }) async {
    // A member's entitlement is the chamber's expiry, so a lapsed owner needs a
    // lapsed **firm** row as well — otherwise every firm account still reads
    // premium and the lapse cannot be exercised.
    final expiry = premium
        ? _premiumExpiryMs
        : DateTime.now()
              .toUtc()
              .subtract(const Duration(days: 3))
              .millisecondsSinceEpoch;
    await ProfilesDao(db).upsert(
      ProfilesCompanion(
        id: const Value('user-1'),
        fullName: const Value('Adv. Rahim Uddin'),
        role: Value(role),
        firmId: const Value('firm-1'),
        subscriptionStatus: Value(premium ? 'active' : 'free'),
        subscriptionExpiry: Value(expiry),
        createdAt: const Value(1),
      ),
    );
    await FirmsDao(db).upsert(
      FirmsCompanion(
        id: const Value('firm-1'),
        name: const Value('Rahman & Associates'),
        ownerId: const Value('user-1'),
        subscriptionStatus: Value(premium ? 'active' : 'free'),
        subscriptionExpiry: Value(expiry),
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

  testWidgets('the owner sees the chamber logo actions', (tester) async {
    await pumpManageAssociates(tester, seed: seedOwner);

    expect(find.byKey(const ValueKey('firm-logo-change')), findsOneWidget);
    expect(find.text(l.manageAssociates_addLogo), findsOneWidget);
    // Nothing to remove until a logo exists.
    expect(find.byKey(const ValueKey('firm-logo-remove')), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('a saved chamber logo shows Change and Remove, and Remove clears it', (
    tester,
  ) async {
    // Synchronous IO: a widget test runs on a fake clock, so a real async file
    // call inside the body would never complete.
    final dir = Directory.systemTemp.createTempSync('manage-logo');
    addTearDown(() => dir.delete(recursive: true));
    final logo = File('${dir.path}/firm_firm-1.png');
    logo.writeAsBytesSync(_pngBytes);

    await pumpManageAssociates(
      tester,
      preferences: <String, Object>{
        firmLogoPathKey: logo.path,
        'firm_logo_firm_id': 'firm-1',
      },
      seed: seedOwner,
    );

    expect(find.text(l.manageAssociates_changeLogo), findsOneWidget);
    final avatar = tester.widget<CircleAvatar>(
      find
          .descendant(
            of: find.byType(ManageAssociatesScreen),
            matching: find.byType(CircleAvatar),
          )
          .first,
    );
    expect((avatar.backgroundImage! as FileImage).file.path, logo.path);

    final remove = find.byKey(const ValueKey('firm-logo-remove'));
    await tester.ensureVisible(remove);
    await tester.pumpAndSettle();
    await tester.tap(remove);
    // The delete is real file IO; a widget test's fake clock needs a real
    // event-loop turn for it to finish before the assertion.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();

    expect(logo.existsSync(), isFalse);
    expect(find.byKey(const ValueKey('firm-logo-remove')), findsNothing);
    expect(find.text(l.manageAssociates_addLogo), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('a lapsed owner is told a live plan is needed for a logo', (
    tester,
  ) async {
    await pumpManageAssociates(
      tester,
      seed: (db) => seedOwner(db, premium: false),
    );

    final change = find.byKey(const ValueKey('firm-logo-change'));
    await tester.ensureVisible(change);
    await tester.pumpAndSettle();
    await tester.tap(change);
    await tester.pumpAndSettle();

    // No picker opens: the message is the whole answer.
    expect(find.text(l.manageAssociates_logoNeedsPlan), findsOneWidget);

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
    harness.firm.membersError = const FirmFailure(FirmFailureKind.firmAdminOffline);

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
    // The entry is the only intended way in, and an associate's taps would only
    // be refused server-side — the roster, the invites and the permission
    // toggles are owner-only there.
    await pumpMenu(tester);
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

  testWidgets('a failed permission write is reported and recorded', (
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
      ..permissionsError = const FirmFailure(FirmFailureKind.firmAdminOffline);

    await pumpManageAssociates(tester, seed: seedOwner);

    await tester.tap(
      find.byKey(const ValueKey('manage-associates-member-user-2')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.manageAssociates_savePermissions));
    await tester.pumpAndSettle();

    expect(find.text(l.auth_errorFirmAdminOffline), findsOneWidget);

    // The banner above is what the user reads; this is what they hand over. A
    // firm refusal recorded as anything but a firm refusal sends whoever reads
    // the report looking in the wrong domain.
    expect(_lines(harness.log), <String>['firm.action FirmFailure(firmAdminOffline)']);

    await unmountApp(tester);
  });

  testWidgets('a roster read that fails is recorded once, not per rebuild', (
    tester,
  ) async {
    harness.firm.membersError = const FirmFailure(FirmFailureKind.server);

    await pumpManageAssociates(tester, seed: seedOwner);
    await tester.pumpAndSettle();

    expect(find.text(l.firm_errorServer), findsOneWidget);
    expect(_lines(harness.log), <String>['firm.members FirmFailure(server)']);

    // Rebuilding the roster must not add a second copy: a screen that
    // re-recorded on every frame would fill the log with one fault and hide
    // the twenty that follow it.
    await tester.pumpAndSettle();
    expect(_lines(harness.log), hasLength(1));

    await unmountApp(tester);
  });

  testWidgets('the Accounts & Profile menu offers Manage Associates to a '
      'premium individual', (tester) async {
    // Adding the first associate is what creates the firm, so an individual must
    // be able to open the screen — while their plan is active.
    await pumpMenu(tester);
    await seedIndividual(harness.db, premium: true);
    await tester.pumpAndSettle();

    expect(find.text(l.manageAssociates_title), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('the Accounts & Profile menu hides Manage Associates from a '
      'free individual', (tester) async {
    // Regression: the entry was offered to every individual, so a free account
    // was shown a door that could only lead to the Paywall — `ensure_firm`
    // refuses a non-premium caller server-side.
    await pumpMenu(tester);
    await seedIndividual(harness.db, premium: false);
    await tester.pumpAndSettle();

    expect(find.text(l.manageAssociates_title), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('the Accounts & Profile menu keeps Manage Associates for a '
      'lapsed owner', (tester) async {
    // Plan §6: a lapsed owner keeps the firm they already have, and the server
    // still lets an owner manage its roster — only *creating* a firm is
    // premium-gated — so the entry must not disappear with the subscription.
    await pumpMenu(tester);
    await seedOwner(harness.db, premium: false);
    await tester.pumpAndSettle();

    expect(find.text(l.manageAssociates_title), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('the dissolve action is blocked while an associate remains', (
    tester,
  ) async {
    harness.firm.members = _roster(associates: 1);

    await pumpManageAssociates(tester, seed: seedOwner);

    // Disabled rather than hidden, with the count: the owner is told what
    // stands in the way, not left guessing why there is no action.
    expect(find.text(l.manageAssociates_dissolveBlockedMembers(1)), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, l.manageAssociates_dissolveFirm),
    );
    expect(button.onPressed, isNull);

    await unmountApp(tester);
  });

  testWidgets('an empty roster dissolves the firm after confirmation', (
    tester,
  ) async {
    harness.firm.members = _roster(associates: 0);

    await pumpManageAssociates(tester, seed: seedOwner);

    await tester.tap(find.text(l.manageAssociates_dissolveFirm));
    await tester.pumpAndSettle();
    expect(find.text(l.manageAssociates_dissolveConfirmTitle), findsOneWidget);
    expect(harness.firm.dissolveCalls, 0, reason: 'the dialog is the gate');

    await tester.tap(
      find.widgetWithText(FilledButton, l.manageAssociates_dissolveFirm),
    );
    await tester.pumpAndSettle();

    expect(harness.firm.dissolveCalls, 1);
    expect(find.text(l.manageAssociates_dissolveDone), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('a refusal from a newer roster shows the count and does not '
      'claim success', (tester) async {
    // A member joined after this screen read the roster, so the server is the
    // authority and its count is what the sentence quotes.
    harness.firm.members = _roster(associates: 0);
    harness.firm.dissolveError = const DissolveRefusal(2);

    await pumpManageAssociates(tester, seed: seedOwner);

    await tester.tap(find.text(l.manageAssociates_dissolveFirm));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, l.manageAssociates_dissolveFirm),
    );
    await tester.pumpAndSettle();

    expect(find.text(l.manageAssociates_dissolveBlockedMembers(2)), findsOneWidget);
    expect(find.text(l.manageAssociates_dissolveDone), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('a queued change blocks the dissolve until it is sent', (
    tester,
  ) async {
    // The push runs before the pull, so an unsynced edit still names the chamber
    // and would be refused the moment the chamber stopped existing.
    harness.firm.members = _roster(associates: 0);

    await pumpManageAssociates(
      tester,
      seed: (db) async {
        await seedOwner(db);
        await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            entityType: 'case',
            entityId: 'case-1',
            operation: 'update',
            mutationId: 'mutation-1',
            basePayload: '{}',
            changedFields: '[]',
            payload: '{}',
            preMutationPayload: '{}',
            createdAt: 1,
            state: 'pending',
          ),
        );
      },
    );
    await tester.pumpAndSettle();

    expect(find.text(l.manageAssociates_dissolveBlockedPending), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, l.manageAssociates_dissolveFirm),
    );
    expect(button.onPressed, isNull);

    await unmountApp(tester);
  });
}

/// A roster with the owner and [associates] associates, in the order the
/// server returns it.
List<FirmMemberSummary> _roster({required int associates}) => [
  const FirmMemberSummary(
    userId: 'user-1',
    role: AccountRole.owner,
    fullName: 'Adv. Rahim Uddin',
    canAdd: true,
    canEdit: true,
    canDelete: true,
  ),
  for (var i = 0; i < associates; i++)
    FirmMemberSummary(
      userId: 'user-${i + 2}',
      role: AccountRole.associate,
      fullName: 'Adv. $i',
      canAdd: true,
      canEdit: true,
      canDelete: false,
    ),
];

/// Each recorded failure as one `area label` line, so a failed expectation
/// shows the whole log instead of a "too many elements" that hides it.
List<String> _lines(ErrorLog log) =>
    log.entries.map((e) => '${e.area} ${e.label}').toList();
