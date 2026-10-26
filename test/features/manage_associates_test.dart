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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/constants/app_spacing.dart';
import 'package:legal_case_diary/core/constants/app_typography.dart';
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
import 'package:legal_case_diary/features/settings/presentation/settings_menu_card.dart'
    show settingsPrimaryButtonHeight;
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
    // Tall enough by default for the owner's roster; a test that reads the
    // whole create-firm page at once (the overview above the form) passes a
    // taller surface rather than scrolling, because it compares positions.
    Size surfaceSize = const Size(420, 1000),
  }) async {
    await tester.binding.setSurfaceSize(surfaceSize);
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
          builder: (_, state) => Scaffold(
            body: Column(
              children: [
                const Text(manageAssociatesPaywallMarker),
                // The tab the paywall was asked to open on, so the overview's
                // link can be proved to land on the chamber cards.
                Text(
                  '${AppRoutes.paywallAudienceParam}='
                  '${state.uri.queryParameters[AppRoutes.paywallAudienceParam]}',
                  key: const ValueKey('paywall-audience-query'),
                ),
              ],
            ),
          ),
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
    String firmName = 'Rahman & Associates',
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
        name: Value(firmName),
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
    // The page title itself says *Create a Firm* while there is none (0.0.654),
    // so the form is what is looked for rather than those words.
    expect(
      find.byKey(const ValueKey('manage-associates-firm-name')),
      findsNothing,
    );

    await unmountApp(tester);
  });

  testWidgets('a free account is sent to the Paywall and creates nothing', (
    tester,
  ) async {
    await pumpManageAssociates(
      tester,
      seed: (db) => seedIndividual(db, premium: false),
    );

    // The overview pushes the form below the fold on a 1000pt surface.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('manage-associates-firm-name')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

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

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('manage-associates-firm-name')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

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

  testWidgets('an individual reads what a firm is, above the create-firm form', (
    tester,
  ) async {
    await pumpManageAssociates(
      tester,
      seed: (db) => seedIndividual(db, premium: true),
      // The whole page at once: the assertion is about order.
      surfaceSize: const Size(420, 1700),
    );

    expect(find.text(l.manageAssociates_firmOverviewTitle), findsOneWidget);
    // Each point is a bold label running into its sentence, so it is looked for
    // as a run of the paragraph rather than as a Text of its own.
    for (final title in [
      l.manageAssociates_firmOverviewCollaborateTitle,
      l.manageAssociates_firmOverviewDevicesTitle,
      l.manageAssociates_firmOverviewBackupTitle,
    ]) {
      expect(find.textContaining(title), findsOneWidget);
    }
    expect(
      find.textContaining(l.manageAssociates_firmOverviewReadyTitle),
      findsOneWidget,
    );
    expect(
      find.textContaining(l.manageAssociates_firmOverviewReadySuffix),
      findsOneWidget,
    );
    // The link is what the request asked for rather than one flat paragraph:
    // bold and underlined, at the sentence's own size.
    final link = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('manage-associates-plans-link')),
        matching: find.byType(Text),
      ),
    );
    expect(link.style?.fontWeight, FontWeight.w700);
    expect(link.style?.decoration, TextDecoration.underline);
    expect(link.style!.fontSize, AppTypography.bodyMd.fontSize);

    // The form still follows the explainer: the overview is above the name
    // field, not instead of it.
    expect(
      tester.getTopLeft(find.text(l.manageAssociates_firmOverviewTitle)).dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('manage-associates-firm-name')),
            )
            .dy,
      ),
    );
    // The section's own title sits between the explainer and the name box, in
    // place of the sentence it replaced. It shares its words with the page
    // title now (0.0.654), so it is found by key.
    final formTitle = find.byKey(const ValueKey('firm-form-title'));
    expect(formTitle, findsOneWidget);
    expect(
      tester.getTopLeft(formTitle).dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('manage-associates-firm-name')),
            )
            .dy,
      ),
    );
    expect(find.text(l.manageAssociates_createFirm), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('the overview\'s plans link opens Subscription Plans on Firm', (
    tester,
  ) async {
    await pumpManageAssociates(
      tester,
      seed: (db) => seedIndividual(db, premium: true),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('manage-associates-plans-link')),
    );
    await tester.tap(
      find.byKey(const ValueKey('manage-associates-plans-link')),
    );
    await tester.pumpAndSettle();

    expect(find.text(manageAssociatesPaywallMarker), findsOneWidget);
    // It lands on the chamber cards, because a firm is created by a firm plan.
    expect(find.text('audience=firm'), findsOneWidget);

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

  testWidgets('a capacity-signed-out member is labelled and can be admitted', (
    tester,
  ) async {
    harness.firm.members = [
      const FirmMemberSummary(
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
        capacitySignedOutAt: DateTime.utc(2026, 10, 26, 12),
      ),
    ];

    await pumpManageAssociates(tester, seed: seedOwner);

    expect(find.text(l.manageAssociates_statusNotSignedIn), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('manage-associates-member-user-2')),
    );
    await tester.pumpAndSettle();

    expect(find.text(l.manageAssociates_signedOutNote), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('member-admit')));
    await tester.pumpAndSettle();

    expect(harness.firm.admittedMemberIds, ['user-2']);
    expect(find.text(l.manageAssociates_capacityAdmitted), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('the owner sees the chamber logo actions', (tester) async {
    await pumpManageAssociates(tester, seed: seedOwner);

    // The frame, with the pencil under it; the wording lives on the tooltip now,
    // because the buttons carry no visible text (user request 0.0.653).
    expect(find.byKey(const ValueKey('firm-logo-frame')), findsOneWidget);
    expect(find.byKey(const ValueKey('firm-logo-change')), findsOneWidget);
    expect(find.byTooltip(l.manageAssociates_addLogo), findsOneWidget);
    expect(find.text(l.manageAssociates_addLogo), findsNothing);
    // Nothing to remove until a logo exists.
    expect(find.byKey(const ValueKey('firm-logo-remove')), findsNothing);
    // The firm's name is bold and centred, with no "Firm" caption above it.
    final name = tester.widget<Text>(find.text('Rahman & Associates'));
    expect(name.textAlign, TextAlign.center);
    expect(name.style?.fontWeight, FontWeight.w700);
    expect(find.text(l.settingsManageAccount_firm), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('the name pencil sits beside a short firm name', (tester) async {
    // A short name on purpose: the test font is the fixed-width Ahem face, so
    // "Rahman & Associates" is already too wide to share a line with the pen.
    await pumpManageAssociates(
      tester,
      seed: (db) => seedOwner(db, firmName: 'Rahman'),
    );

    final pencil = find.byKey(const ValueKey('firm-name-change'));
    expect(pencil, findsOneWidget);
    // The same round pencil the logo carries, with no visible label.
    expect(
      find.descendant(of: pencil, matching: find.byIcon(Icons.edit)),
      findsOneWidget,
    );
    expect(find.text(l.manageAssociates_changeName), findsNothing);
    // Beside, not below: the two share a line.
    final name = find.text('Rahman');
    expect(
      (tester.getCenter(pencil).dy - tester.getCenter(name).dy).abs(),
      lessThan(16),
    );

    await unmountApp(tester);
  });

  testWidgets('a long firm name moves the name pencil below it', (
    tester,
  ) async {
    const longName = 'Rahman, Chowdhury & Associates International Law Chamber';
    await pumpManageAssociates(
      tester,
      seed: (db) => seedOwner(db, firmName: longName),
    );

    final pencil = tester.getRect(
      find.byKey(const ValueKey('firm-name-change')),
    );
    final name = tester.getRect(find.text(longName));
    expect(pencil.top, greaterThanOrEqualTo(name.bottom));

    await unmountApp(tester);
  });

  testWidgets(
    'a saved chamber logo shows Change and Remove, and Remove clears it',
    (tester) async {
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

      expect(find.byTooltip(l.manageAssociates_changeLogo), findsOneWidget);
      // The frame paints the saved logo as its background.
      final frame = tester.widget<Container>(
        find.byKey(const ValueKey('firm-logo-frame')),
      );
      final decoration = frame.decoration! as BoxDecoration;
      expect((decoration.image!.image as FileImage).file.path, logo.path);

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
      expect(find.byTooltip(l.manageAssociates_addLogo), findsOneWidget);

      await unmountApp(tester);
    },
  );

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

  testWidgets('the owner invites without creating a second firm', (
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

  testWidgets('the invite code is a centred pop-over with Exit App buttons', (
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
    ];

    // A phone-width surface: the window has to be roomy enough that Copy and
    // Share share a row at this width (user request 0.0.652).
    await pumpManageAssociates(
      tester,
      seed: seedOwner,
      surfaceSize: const Size(412, 800),
    );

    await tester.tap(find.text(l.manageAssociates_addAssociate));
    await tester.pumpAndSettle();

    // A window, not the bottom sheet it used to be.
    expect(find.byType(Dialog), findsOneWidget);
    expect(
      tester.widget<Text>(find.text(l.manageAssociates_inviteTitle)).textAlign,
      TextAlign.center,
    );

    /// The Exit App action size: 112 x 48 at 16 pt, as a minimum so a longer
    /// Bengali label grows instead of clipping.
    void expectExitAppSize(Key key) {
      final button = tester.widget<ButtonStyleButton>(find.byKey(key));
      expect(
        button.style?.minimumSize?.resolve(<WidgetState>{}),
        const Size(112, 48),
      );
      expect(button.style?.textStyle?.resolve(<WidgetState>{})?.fontSize, 16);
    }

    expectExitAppSize(const ValueKey('invite-code-copy'));
    expectExitAppSize(const ValueKey('invite-code-share'));
    expectExitAppSize(const ValueKey('invite-code-close'));

    // Copy and Share sit side by side, with Close beneath them: at the window's
    // old margins these two could not share a row on any phone.
    final copyY = tester
        .getTopLeft(find.byKey(const ValueKey('invite-code-copy')))
        .dy;
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('invite-code-share'))).dy,
      copyY,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('invite-code-close'))).dy,
      greaterThan(copyY),
    );

    // The second row of buttons is spaced exactly as the code box and the first
    // row are (0.0.654, user request), so the window reads as one column.
    final wrap = tester.widget<Wrap>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('invite-code-copy')),
            matching: find.byType(Wrap),
          )
          .first,
    );
    expect(wrap.runSpacing, AppSpacing.lg);

    // Copying confirms itself inside the window, where the user can see it.
    // The clipboard channel is answered so the copy settles like it does on a
    // device.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    expect(find.byKey(const ValueKey('invite-code-note')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('invite-code-copy')));
    await tester.pumpAndSettle();
    expect(find.text(l.manageAssociates_codeCopied), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('the owner\'s page is Manage Firm, and the name can be changed', (
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
    ];

    await pumpManageAssociates(tester, seed: seedOwner);

    // A firm exists, so the page and its menu row offer to manage it rather than
    // to create one (0.0.654, user request).
    expect(find.text(l.manageAssociates_title), findsOneWidget);
    expect(find.text(l.manageAssociates_createFirmTitle), findsNothing);
    expect(find.text('Rahman & Associates'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('firm-name-change')));
    await tester.pumpAndSettle();

    // The window opens on the current name, so a correction is an edit rather
    // than a retype.
    expect(find.byType(Dialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text(l.manageAssociates_changeNameTitle),
      ),
      findsOneWidget,
    );
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('firm-name-input')),
    );
    expect(field.controller?.text, 'Rahman & Associates');

    await tester.enterText(
      find.byKey(const ValueKey('firm-name-input')),
      'Rahman & Partners',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('firm-name-save')));
    await tester.pumpAndSettle();

    expect(harness.firm.renamedFirmNames, ['Rahman & Partners']);
    expect(find.text(l.manageAssociates_nameUpdated), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('a failed rename is reported, never applied', (tester) async {
    harness.firm.renameError = const FirmFailure(FirmFailureKind.network);

    await pumpManageAssociates(tester, seed: seedOwner);

    await tester.tap(find.byKey(const ValueKey('firm-name-change')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('firm-name-input')),
      'Rahman & Partners',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('firm-name-save')));
    await tester.pumpAndSettle();

    // The failure is the screen's own banner, worded by the shared map.
    expect(find.text(l.auth_errorNetwork), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('an empty individual diary is offered the join, and it redeems', (
    tester,
  ) async {
    await pumpManageAssociates(
      tester,
      seed: (db) => seedIndividual(db, premium: false),
      surfaceSize: const Size(420, 1400),
    );

    final join = find.byKey(const ValueKey('manage-associates-join-firm'));
    await tester.scrollUntilVisible(
      join,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(join);
    await tester.pumpAndSettle();

    // The window, its one sentence, and the two actions the request named.
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
  });

  testWidgets('a diary with a case is not offered the join', (tester) async {
    // `join_firm` refuses an account that already holds its own rows, and the
    // seat has to be empty — so a non-zero diary offers nothing.
    await pumpManageAssociates(
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
      surfaceSize: const Size(420, 1400),
    );

    expect(
      find.byKey(const ValueKey('manage-associates-join-firm')),
      findsNothing,
    );

    await unmountApp(tester);
  });

  testWidgets('a paying individual is warned about their plan before joining', (
    tester,
  ) async {
    await pumpManageAssociates(
      tester,
      seed: (db) => seedIndividual(db, premium: true),
      surfaceSize: const Size(420, 1400),
    );

    final join = find.byKey(const ValueKey('manage-associates-join-firm'));
    await tester.scrollUntilVisible(
      join,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(join);
    await tester.pumpAndSettle();

    // Joining neither pauses nor cancels the plan, and the window says so before
    // the code is asked for (user request).
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

    await pumpManageAssociates(
      tester,
      seed: (db) => seedIndividual(db, premium: false),
      surfaceSize: const Size(420, 1400),
    );

    final join = find.byKey(const ValueKey('manage-associates-join-firm'));
    await tester.scrollUntilVisible(
      join,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(join);
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

  testWidgets('a roster read that fails is reported, never swallowed', (
    tester,
  ) async {
    harness.firm.membersError = const FirmFailure(
      FirmFailureKind.firmAdminOffline,
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
    expect(find.text(l.manageAssociates_createFirmTitle), findsNothing);
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

    // Neither label: an associate has no firm of their own to create and no
    // right to manage the one they are in (0.0.654, user ruling).
    expect(find.text(l.manageAssociates_title), findsNothing);
    expect(find.text(l.manageAssociates_createFirmTitle), findsNothing);

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

    await tester.tap(
      find.byKey(const ValueKey('manage-associates-revoke-invite-9')),
    );
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

  testWidgets('an outstanding invite shows its code and copies it on tap', (
    tester,
  ) async {
    harness.firm.invites = [
      const FirmInviteSummary(id: 'invite-9', createdAt: 5000),
      const FirmInviteSummary(id: 'invite-8', createdAt: 4000),
    ];

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpManageAssociates(
      tester,
      seed: seedOwner,
      // The code this device generated for invite-9, as the store remembers it.
      preferences: <String, Object>{'firm_invite_code_invite-9': 'K7MQ2X'},
    );

    expect(find.text('K7MQ2X'), findsOneWidget);
    // invite-8 was made elsewhere (or before this device kept codes), so the row
    // says the code is not here rather than inventing one.
    expect(find.text(l.manageAssociates_inviteCodeUnavailable), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('manage-associates-invite-code-invite-9')),
    );
    await tester.pumpAndSettle();
    expect(find.text(l.manageAssociates_codeCopied), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('Revoke is black-filled and Dissolve is tall and red', (
    tester,
  ) async {
    harness.firm.invites = [
      const FirmInviteSummary(id: 'invite-9', createdAt: 5000),
    ];

    await pumpManageAssociates(tester, seed: seedOwner);

    final revoke = tester.widget<FilledButton>(
      find.byKey(const ValueKey('manage-associates-revoke-invite-9')),
    );
    expect(
      revoke.style?.backgroundColor?.resolve(<WidgetState>{}),
      AppColors.primary,
    );
    expect(
      revoke.style?.foregroundColor?.resolve(<WidgetState>{}),
      AppColors.onPrimary,
    );

    // Dissolve is a full-height red button, not an outlined one.
    final dissolve = tester.widget<FilledButton>(
      find
          .descendant(
            of: find.byType(ManageAssociatesScreen),
            matching: find.widgetWithText(
              FilledButton,
              l.manageAssociates_dissolveFirm,
            ),
          )
          .first,
    );
    expect(
      dissolve.style?.backgroundColor?.resolve(<WidgetState>{}),
      AppColors.error,
    );
    expect(
      dissolve.style?.minimumSize?.resolve(<WidgetState>{}),
      const Size.fromHeight(settingsPrimaryButtonHeight),
    );

    await unmountApp(tester);
  });

  testWidgets('the revoke window takes the Invite Code window\'s shape', (
    tester,
  ) async {
    harness.firm.invites = [
      const FirmInviteSummary(id: 'invite-9', createdAt: 5000),
    ];

    await pumpManageAssociates(tester, seed: seedOwner);

    await tester.tap(
      find.byKey(const ValueKey('manage-associates-revoke-invite-9')),
    );
    await tester.pumpAndSettle();

    expect(find.text(l.manageAssociates_revokeInviteTitle), findsOneWidget);
    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(
      (dialog.shape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(AppSpacing.cardRadius * 2),
    );

    // Both actions are the Invite Code window's 112 x 48 at 16 pt, centred.
    // Scoped to the window: Revoke's label also exists on the row behind it.
    for (final (label, type) in <(String, Type)>[
      (l.sharedActions_cancel, TextButton),
      (l.manageAssociates_revokeInvite, FilledButton),
    ]) {
      final button = tester.widget<ButtonStyleButton>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.ancestor(
            of: find.text(label),
            matching: find.byType(type),
          ),
        ),
      );
      expect(
        button.style?.minimumSize?.resolve(<WidgetState>{}),
        const Size(112, 48),
      );
      expect(button.style?.textStyle?.resolve(<WidgetState>{})?.fontSize, 16);
    }

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
    expect(_lines(harness.log), <String>[
      'firm.action FirmFailure(firmAdminOffline)',
    ]);

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

  testWidgets('the Accounts & Profile menu offers the Create a Firm teaser to a '
      'premium individual', (tester) async {
    // Adding the first associate is what creates the firm, so an individual must
    // be able to open the screen — and with no firm yet the row offers to create
    // one rather than to manage one (0.0.654, user request).
    await pumpMenu(tester);
    await seedIndividual(harness.db, premium: true);
    await tester.pumpAndSettle();

    expect(find.text(l.manageAssociates_createFirmTitle), findsOneWidget);
    expect(
      find.text(l.settingsAccountProfile_createFirmSubtitle),
      findsOneWidget,
    );
    expect(find.text(l.manageAssociates_title), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('the Accounts & Profile menu offers Create a Firm to a free '
      'individual', (tester) async {
    // The teaser is open to every individual (0.0.654, user request): the screen
    // it opens explains what a firm is and links to the firm plans, while the
    // create action itself sends a free account to the Paywall.
    await pumpMenu(tester);
    await seedIndividual(harness.db, premium: false);
    await tester.pumpAndSettle();

    expect(find.text(l.manageAssociates_createFirmTitle), findsOneWidget);
    expect(find.text(l.settingsAccountProfile_sectionFirm), findsOneWidget);

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
    expect(
      find.text(l.manageAssociates_dissolveBlockedMembers(1)),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, l.manageAssociates_dissolveFirm),
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
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(
          FilledButton,
          l.manageAssociates_dissolveFirm,
        ),
      ),
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
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(
          FilledButton,
          l.manageAssociates_dissolveFirm,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(l.manageAssociates_dissolveBlockedMembers(2)),
      findsOneWidget,
    );
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
        await db
            .into(db.syncQueue)
            .insert(
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

    expect(
      find.text(l.manageAssociates_dissolveBlockedPending),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, l.manageAssociates_dissolveFirm),
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
