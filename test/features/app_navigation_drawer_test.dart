/// Guards the side-menu polish.
///
/// The selected item is filled black, and the profile header renders three
/// centre-aligned lines whose order flips between English ("Legal Case Diary /
/// of / name") and Bengali ("name / এর / লিগ্যাল কেস ডায়েরি").
///
/// It also guards the **current plan** row: it names the running plan, expands
/// into Subscription Details and Subscription Plans rather than navigating, and
/// each of those two rows opens the screen it names.
///
/// And it guards the **profile icon**: it carries a small chevron badge that
/// marks it as a menu, and tapping it opens the account popover — anchored to
/// the icon, lined up with the drawer's own left edge, outlined in the drawer's
/// divider grey and naming the signed-in e-mail plus the three account actions,
/// Profile, Manage Account and Logout, each of which does what it says.
///
/// The panel itself is a **rounded window with transparent option rows** (user
/// request): the app's 8 px window corner, the address line marked by its `@`
/// icon alone, and its three options reading at the side menu's own text size.
library;

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:image/image.dart' as img;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/constants/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:legal_case_diary/core/constants/app_version.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/firm_logo_store.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_name_store.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_picture_store.dart';
import 'package:legal_case_diary/features/admin/presentation/admin_viewmodel.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/data/logout_flow.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_viewmodel.dart';
import 'package:legal_case_diary/features/payments/data/payment_plans.dart';
import 'package:legal_case_diary/features/payments/presentation/current_plan.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/features/settings/data/update_metadata_store.dart';
import 'package:legal_case_diary/features/settings/data/update_release.dart';
import 'package:legal_case_diary/features/settings/data/update_repository.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_controls.dart';
import 'package:legal_case_diary/shared/widgets/app_navigation_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A free account's plan, as the drawer's own derivation reports it.
const CurrentPlan freePlan = (known: true, premium: false, planKey: null);

/// A paid account's plan, named by its approved submission.
const CurrentPlan quarterlyPlan = (
  known: true,
  premium: true,
  planKey: paymentPlanProQuarterly,
);

/// Markers rendered by the stand-in screens the two plan rows open.
const String subscriptionDetailsMarker = 'Subscription Details Screen';
const String subscriptionPlansMarker = 'Subscription Plans Screen';

/// Markers rendered by the stand-in screens the account popover opens.
const String profileMarker = 'Profile Screen';
const String manageAccountMarker = 'Manage Account Screen';
const String loginMarker = 'Login Screen';

/// The address the drawer's account sheet is expected to print.
const String signedInEmail = 'rahim@example.com';

/// A firm associate's cached profile, for the chamber header.
Profile firmProfile({String role = 'associate'}) => Profile(
  id: 'drawer-test-user',
  fullName: 'Zaid',
  avatarVersion: 0,
  role: role,
  firmId: 'firm-1',
  subscriptionStatus: 'premium',
  subscriptionExpiry: DateTime.now()
      .add(const Duration(days: 30))
      .millisecondsSinceEpoch,
  tier: 'pro',
  createdAt: 0,
);

/// The chamber row beside it.
Firm firmRow({String name = 'Rahman & Associates'}) => Firm(
  id: 'firm-1',
  name: name,
  ownerId: 'owner-1',
  subscriptionStatus: 'premium',
  subscriptionExpiry: DateTime.now()
      .add(const Duration(days: 30))
      .millisecondsSinceEpoch,
  tier: 'firm',
  logoVersion: 0,
  createdAt: 0,
);

/// An update repository that answers from memory, recording its calls.
class _FakeUpdateRepository extends UpdateRepository {
  _FakeUpdateRepository({this.outcome});

  final UpdateCheckOutcome? outcome;

  /// How many times a check was asked for.
  int checks = 0;

  @override
  Future<UpdateCheckOutcome> checkForLatestRelease() async {
    checks++;
    return outcome ?? const UpdateCheckOutcome(ReleaseCheckResult.upToDate);
  }
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  /// Mounts the drawer over a stored name and opens it.
  Future<void> pumpDrawer(
    WidgetTester tester, {
    required Locale locale,
    String route = AppRoutes.dailyCauseList,
    UpdateRepository? updateRepository,
    List<String> bottomNavTabs = const <String>[],
    List<String> bottomNavOrder = const <String>[],
  }) async {
    await ProfileStore(
      prefs,
    ).write(const ProfileFields(fullName: 'Rahim Uddin'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          // The drawer's Check for update row drives the updater, so the
          // network is stubbed like every other seam in this suite.
          if (updateRepository != null)
            updateRepositoryProvider.overrideWithValue(updateRepository),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: Scaffold(
            drawer: AppNavigationDrawer(
              currentRoute: route,
              bottomNavTabs: bottomNavTabs,
              bottomNavOrder: bottomNavOrder,
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await tester.pumpAndSettle();
  }

  Finder drawerText(String text) =>
      find.descendant(of: find.byType(Drawer), matching: find.text(text));

  /// Gives the drawer enough height to build its last rows.
  ///
  /// The drawer's body is a `ListView`, so a row below the fold is not built at
  /// all — and the Check for update row sits under Print and Share.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  /// The colour the update row paints [label] in.
  Color? updateRowInk(WidgetTester tester, String label) =>
      tester.widget<Text>(drawerText(label)).style?.color;

  Finder drawerKey(String key) => find.descendant(
    of: find.byType(Drawer),
    matching: find.byKey(ValueKey(key)),
  );

  /// Pumps through a logout that shows an indeterminate spinner.
  ///
  /// While the account panel's Logout row is busy it swaps its icon for a
  /// `CircularProgressIndicator`, which animates forever — so `pumpAndSettle`
  /// can never see a settled frame and would time out. The flow's real work
  /// (a wipe on the in-memory database, then the fake endSession) completes on
  /// the event loop between bounded pumps, so a fixed-window pump is the honest
  /// way to wait for it.
  Future<void> pumpLogoutToDone(WidgetTester tester) async {
    for (
      var i = 0;
      i < 40 && tester.any(find.byKey(const ValueKey('drawer-account-logout')));
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Top Y of every divider inside the drawer, so a test can tell which section
  /// a row sits in rather than only what order the labels come in.
  List<double> drawerDividerYs(WidgetTester tester) {
    final finder = find.descendant(
      of: find.byType(Drawer),
      matching: find.byType(Divider),
    );
    return [
      for (var i = 0; i < finder.evaluate().length; i++)
        tester.getTopLeft(finder.at(i)).dy,
    ];
  }

  /// Pumps the drawer on a router, sitting on [route], with the account's plan
  /// stubbed to [plan].
  ///
  /// The plan row prints [currentPlanProvider], so stubbing that provider is
  /// what proves the row reads it — a row that invented its own plan would
  /// ignore the stub and print something else. The two routes are stand-ins
  /// with distinct text, so a test can tell where a tap landed.
  Future<GoRouter> pumpDrawerOnRouter(
    WidgetTester tester, {
    CurrentPlan plan = freePlan,
    Locale locale = const Locale('en'),
    String route = AppRoutes.dailyCauseList,
    String email = signedInEmail,
    LogoutFlow? logoutFlow,
    int? adminBadgeCount,
    bool firmMember = false,
    SubscriptionTier? tier,
    Profile? profile,
    Firm? firm,
  }) async {
    // Tall, so the plan row (below the eight nav items) is on screen to tap.
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: route,
      routes: [
        GoRoute(
          path: route,
          builder: (_, _) => Scaffold(
            drawer: AppNavigationDrawer(currentRoute: route),
            body: const SizedBox.shrink(),
          ),
        ),
        // A route the drawer already sits on is not declared twice.
        if (route != AppRoutes.settingsSubscriptionDetails)
          GoRoute(
            path: AppRoutes.settingsSubscriptionDetails,
            builder: (_, _) =>
                const Scaffold(body: Text(subscriptionDetailsMarker)),
          ),
        if (route != AppRoutes.paywall)
          GoRoute(
            path: AppRoutes.paywall,
            builder: (_, _) =>
                const Scaffold(body: Text(subscriptionPlansMarker)),
          ),
        // The three screens the account sheet opens.
        if (route != AppRoutes.settingsProfile)
          GoRoute(
            path: AppRoutes.settingsProfile,
            builder: (_, _) => const Scaffold(body: Text(profileMarker)),
          ),
        if (route != AppRoutes.settingsManageAccount)
          GoRoute(
            path: AppRoutes.settingsManageAccount,
            builder: (_, _) => const Scaffold(body: Text(manageAccountMarker)),
          ),
        if (route != AppRoutes.login)
          GoRoute(
            path: AppRoutes.login,
            builder: (_, _) => const Scaffold(body: Text(loginMarker)),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentPlanProvider.overrideWithValue(plan),
          // The member rule behind the plans child: a member has nothing to buy,
          // while the owner (the default here) keeps the renewal entry.
          firmMemberProvider.overrideWithValue(firmMember),
          // The tier behind the plan label's Limited Access tag: stubbed only
          // where a test needs the ended state, so no other case changes.
          if (tier != null) allowanceTierProvider.overrideWithValue(tier),
          // The account and chamber the header names, when a test is about the
          // firm header rather than the plan.
          if (profile != null)
            accountProfileProvider.overrideWith(
              (ref) => Stream<Profile?>.value(profile),
            ),
          if (firm != null)
            accountFirmProvider.overrideWith(
              (ref) => Stream<Firm?>.value(firm),
            ),
          // The address the sheet names. Stubbed, so a sheet that invented its
          // own address (or printed nothing) would fail the assertion below.
          authIdentityProvider.overrideWithValue(
            AuthIdentity(userId: 'drawer-test-user', email: email),
          ),
          if (logoutFlow != null)
            logoutFlowProvider.overrideWith((_) async => logoutFlow),
          // The Admin row exists only for an admin, and its badge reads a count
          // derived from the payment and unconfirmed-account lists; both are
          // stubbed so the row can be exercised without a server.
          if (adminBadgeCount != null) ...[
            adminStatusProvider.overrideWith((_) async => true),
            adminPendingCountProvider.overrideWithValue(adminBadgeCount),
          ],
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('the selected item is filled black', (tester) async {
    await pumpDrawer(tester, locale: const Locale('en'));

    final blackTiles = find.descendant(
      of: find.byType(Drawer),
      matching: find.byWidgetPredicate(
        (widget) => widget is Material && widget.color == Colors.black,
      ),
    );
    expect(blackTiles, findsOneWidget);
  });

  testWidgets('English header reads app, "of", name down the page', (
    tester,
  ) async {
    await pumpDrawer(tester, locale: const Locale('en'));

    expect(drawerText('Legal Case Diary'), findsOneWidget);
    expect(drawerText('of'), findsOneWidget);
    expect(drawerText('Rahim Uddin'), findsOneWidget);

    expect(
      tester.getTopLeft(drawerText('Legal Case Diary')).dy,
      lessThan(tester.getTopLeft(drawerText('of')).dy),
    );
    expect(
      tester.getTopLeft(drawerText('of')).dy,
      lessThan(tester.getTopLeft(drawerText('Rahim Uddin')).dy),
    );
    expect(tester.widget<Text>(drawerText('of')).textAlign, TextAlign.center);
  });

  testWidgets('the version is the last line, below Print and Share', (
    tester,
  ) async {
    // A tall surface so the whole menu builds and the ordering can be read.
    await tester.binding.setSurfaceSize(const Size(500, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpDrawer(tester, locale: const Locale('en'));

    final version = drawerText('V$appVersion');
    expect(version, findsOneWidget);
    expect(
      tester.getTopLeft(version).dy,
      greaterThan(tester.getTopLeft(drawerText('Share')).dy),
    );
    // It is left aligned, not centred like the profile header lines.
    expect(tester.widget<Text>(version).textAlign, TextAlign.left);
    // Even with a tall surface it sits at the bottom of the drawer, with only
    // the trailing padding beneath it.
    final drawerBottom = tester.getBottomLeft(find.byType(Drawer)).dy;
    expect(drawerBottom - tester.getBottomLeft(version).dy, lessThan(16));
  });

  testWidgets('Bengali header reads name, "এর", app down the page', (
    tester,
  ) async {
    await pumpDrawer(tester, locale: const Locale('bn'));

    expect(drawerText('Rahim Uddin'), findsOneWidget);
    expect(drawerText('এর'), findsOneWidget);
    expect(drawerText('লিগ্যাল কেস ডায়েরি'), findsOneWidget);

    expect(
      tester.getTopLeft(drawerText('Rahim Uddin')).dy,
      lessThan(tester.getTopLeft(drawerText('এর')).dy),
    );
    expect(
      tester.getTopLeft(drawerText('এর')).dy,
      lessThan(tester.getTopLeft(drawerText('লিগ্যাল কেস ডায়েরি')).dy),
    );
    expect(tester.widget<Text>(drawerText('এর')).textAlign, TextAlign.center);
  });

  testWidgets('a chamber header names the chamber, then the member and role', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    await ProfileStore(prefs).write(const ProfileFields(fullName: 'Zaid'));
    await pumpDrawerOnRouter(tester, profile: firmProfile(), firm: firmRow());

    expect(drawerText('Legal Case Diary'), findsOneWidget);
    expect(drawerText('of'), findsOneWidget);
    expect(drawerText('Rahman & Associates'), findsOneWidget);
    expect(
      drawerText('Zaid · ${l.settingsManageAccount_roleAssociate}'),
      findsOneWidget,
    );

    // The possessive names the chamber; the signed-in member follows it.
    final appY = tester.getTopLeft(drawerText('Legal Case Diary')).dy;
    final ofY = tester.getTopLeft(drawerText('of')).dy;
    final firmY = tester.getTopLeft(drawerText('Rahman & Associates')).dy;
    final memberY = tester
        .getTopLeft(
          drawerText('Zaid · ${l.settingsManageAccount_roleAssociate}'),
        )
        .dy;
    expect(appY, lessThan(ofY));
    expect(ofY, lessThan(firmY));
    expect(firmY, lessThan(memberY));
  });

  testWidgets('a chamber owner is named with Owner', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    await ProfileStore(prefs).write(const ProfileFields(fullName: 'Asad'));
    await pumpDrawerOnRouter(
      tester,
      profile: firmProfile(role: 'owner'),
      firm: firmRow(),
    );

    expect(
      drawerText('Asad · ${l.settingsManageAccount_roleOwner}'),
      findsOneWidget,
    );
  });

  testWidgets('a chamber row with no name keeps the member header', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    await ProfileStore(prefs).write(const ProfileFields(fullName: 'Zaid'));
    await pumpDrawerOnRouter(
      tester,
      profile: firmProfile(),
      firm: firmRow(name: ''),
    );

    expect(drawerText('Zaid'), findsOneWidget);
    expect(drawerText(l.settingsManageAccount_roleAssociate), findsNothing);
  });

  testWidgets('the chamber logo fills the circle', (tester) async {
    // Synchronous IO: a widget test runs on a fake clock, so a real async file
    // call inside the body would never complete.
    final dir = Directory.systemTemp.createTempSync('drawer-logo');
    addTearDown(() => dir.delete(recursive: true));
    final logo = File('${dir.path}/firm_firm-1.jpg');
    logo.writeAsBytesSync(img.encodePng(img.Image(width: 4, height: 4)));
    await prefs.setString(firmLogoPathKey, logo.path);
    await prefs.setString('firm_logo_firm_id', 'firm-1');

    await pumpDrawerOnRouter(tester, profile: firmProfile(), firm: firmRow());

    final avatar = tester.widget<CircleAvatar>(
      find
          .descendant(
            of: find.byType(Drawer),
            matching: find.byType(CircleAvatar),
          )
          .first,
    );
    expect(avatar.backgroundImage, isA<FileImage>());
    expect((avatar.backgroundImage! as FileImage).file.path, logo.path);
  });

  testWidgets('without a chamber logo the member picture is the fallback', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('drawer-member-picture');
    addTearDown(() => dir.delete(recursive: true));
    final member = File('${dir.path}/member.jpg');
    member.writeAsBytesSync(img.encodePng(img.Image(width: 4, height: 4)));
    await prefs.setString(profilePicturePathKey, member.path);

    await pumpDrawerOnRouter(tester, profile: firmProfile(), firm: firmRow());

    final avatar = tester.widget<CircleAvatar>(
      find
          .descendant(
            of: find.byType(Drawer),
            matching: find.byType(CircleAvatar),
          )
          .first,
    );
    expect((avatar.backgroundImage! as FileImage).file.path, member.path);
  });

  testWidgets('the Bengali chamber header keeps the member line last', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('bn'));
    await ProfileStore(prefs).write(const ProfileFields(fullName: 'Zaid'));
    await pumpDrawerOnRouter(
      tester,
      locale: const Locale('bn'),
      profile: firmProfile(),
      firm: firmRow(),
    );

    final firmLine = drawerText('Rahman & Associates');
    final memberLine = drawerText(
      'Zaid · ${l.settingsManageAccount_roleAssociate}',
    );
    expect(firmLine, findsOneWidget);
    expect(memberLine, findsOneWidget);
    expect(
      tester.getTopLeft(firmLine).dy,
      lessThan(tester.getTopLeft(drawerText('এর')).dy),
    );
    expect(
      tester.getTopLeft(drawerText('লিগ্যাল কেস ডায়েরি')).dy,
      lessThan(tester.getTopLeft(memberLine).dy),
    );
  });

  testWidgets('the plan row names the running plan, then expands to two pages', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    // A paid plan, so the row is pinned to name the plan itself
    // ("Pro · 3 Months") rather than falling back to the word Premium.
    final router = await pumpDrawerOnRouter(tester, plan: quarterlyPlan);

    expect(drawerText(l.paywall_planProQuarterly), findsOneWidget);
    // The caption says which fact that word is: a bare "Pro · 3 Months" beside
    // a chevron would read as the name of a screen.
    expect(drawerText(l.settingsSubscription_currentPlan), findsOneWidget);
    expect(
      tester.getTopLeft(drawerText(l.paywall_planProQuarterly)).dy,
      lessThan(
        tester.getTopLeft(drawerText(l.settingsSubscription_currentPlan)).dy,
      ),
    );

    // Settings now leads this group (user request): it sits directly above the
    // plan row with no divider between them, and the section divider that used
    // to separate the two now sits above Settings.
    final captionY = tester
        .getTopLeft(drawerText(l.settingsSubscription_currentPlan))
        .dy;
    final settingsY = tester.getTopLeft(drawerText(l.nav_settings)).dy;
    expect(settingsY, lessThan(captionY));
    expect(
      drawerDividerYs(tester).where((y) => y > settingsY && y < captionY),
      isEmpty,
    );
    expect(drawerDividerYs(tester).where((y) => y < settingsY), isNotEmpty);
    expect(captionY, lessThan(tester.getTopLeft(drawerText(l.nav_print)).dy));

    // Collapsed, neither destination is offered yet.
    expect(
      drawerText(l.settingsSubscription_managePlanTitle),
      findsNothing,
    );
    expect(drawerText(l.paywall_title), findsNothing);

    await tester.tap(drawerText(l.paywall_planProQuarterly));
    await tester.pumpAndSettle();

    // Expanding is not navigating: the app is still on the screen the drawer
    // was opened from.
    expect(router.state.matchedLocation, AppRoutes.dailyCauseList);
    expect(
      drawerText(l.settingsSubscription_managePlanTitle),
      findsOneWidget,
    );
    expect(drawerText(l.paywall_title), findsOneWidget);
  });

  testWidgets('an ended plan carries its tag two spaces off the name', (
    tester,
  ) async {
    // A paid tier with no entitlement is on Limited Access, which the row marks
    // with its own red tag. The user asked for a little more air before it here
    // than the details card gives: two spaces, so the tag reads as a note
    // beside the name rather than a suffix.
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpDrawerOnRouter(
      tester,
      plan: (known: true, premium: false, planKey: null),
      tier: SubscriptionTier.pro,
    );

    final label = find.descendant(
      of: find.byType(Drawer),
      matching: find.byType(CurrentPlanLabel),
    );
    expect(label, findsOneWidget);
    final rich = tester.widget<RichText>(
      find.descendant(of: label, matching: find.byType(RichText)),
    );
    // `Text` wraps the span it is given in one carrying the style, so the two
    // printed runs are found by walking the tree rather than by index.
    final spans = <TextSpan>[];
    (rich.text as TextSpan).visitChildren((span) {
      if (span is TextSpan && span.text != null) spans.add(span);
      return true;
    });
    expect(spans.map((span) => span.text), <String>[
      l.paywall_tierPro,
      '  ${l.settingsManageAccount_planLimitedAccessTag}',
    ]);
    expect(spans[1].style?.color, AppColors.error);
  });

  testWidgets('a chamber member expands to both subscription pages', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    // A member reads the chamber's plan and expiry on Details, and the plans
    // themselves on Subscription Plans (read-only, 0.0.626), so both children
    // are offered.
    await pumpDrawerOnRouter(tester, firmMember: true);

    await tester.tap(drawerText(l.settingsSubscription_currentPlan));
    await tester.pumpAndSettle();

    expect(
      drawerText(l.settingsSubscription_managePlanTitle),
      findsOneWidget,
    );
    expect(drawerText(l.paywall_title), findsOneWidget);
  });

  testWidgets('Subscription Details opens the details sub-page', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    final router = await pumpDrawerOnRouter(tester);

    await tester.tap(drawerText(l.settingsManageAccount_planFree));
    await tester.pumpAndSettle();
    await tester.tap(drawerText(l.settingsSubscription_managePlanTitle));
    await tester.pumpAndSettle();

    expect(find.text(subscriptionDetailsMarker), findsOneWidget);
    expect(router.state.matchedLocation, AppRoutes.settingsSubscriptionDetails);
  });

  testWidgets('Subscription Plans opens the paywall', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    final router = await pumpDrawerOnRouter(tester);

    await tester.tap(drawerText(l.settingsManageAccount_planFree));
    await tester.pumpAndSettle();
    // The second row carries the paywall's own title, which is the screen the
    // user asked for by that name.
    await tester.tap(drawerText(l.paywall_title));
    await tester.pumpAndSettle();

    expect(find.text(subscriptionPlansMarker), findsOneWidget);
    expect(router.state.matchedLocation, AppRoutes.paywall);
  });

  testWidgets('the row is already open on a screen it leads to', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    // Opened from the details sub-page itself: its row must be visible and
    // filled, not hidden inside a collapsed header.
    await pumpDrawerOnRouter(
      tester,
      route: AppRoutes.settingsSubscriptionDetails,
    );

    expect(
      drawerText(l.settingsSubscription_managePlanTitle),
      findsOneWidget,
    );
    final blackTiles = find.descendant(
      of: find.byType(Drawer),
      matching: find.byWidgetPredicate(
        (widget) => widget is Material && widget.color == Colors.black,
      ),
    );
    expect(blackTiles, findsOneWidget);
  });

  testWidgets('the profile icon opens the account popover with the e-mail', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpDrawerOnRouter(tester);

    // Nothing is offered until the icon is tapped.
    expect(find.text(signedInEmail), findsNothing);

    await tester.tap(find.byKey(const ValueKey('drawer-profile-icon')));
    await tester.pumpAndSettle();

    // The address the account signed in with, and only the address: the
    // "Email" caption is gone, the `@` icon saying what the line is (user
    // request).
    expect(find.text(signedInEmail), findsOneWidget);
    expect(find.text(l.auth_emailLabel), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('drawer-account-popover')),
        matching: find.byIcon(Icons.alternate_email),
      ),
      findsOneWidget,
      reason: 'the icon stays; only the caption went',
    );
    // The three options, in the app's own words for them.
    expect(
      find.byKey(const ValueKey('drawer-account-profile')),
      findsOneWidget,
    );
    expect(find.text(l.settingsScreen_profile), findsOneWidget);
    expect(find.byKey(const ValueKey('drawer-account-manage')), findsOneWidget);
    expect(find.text(l.settingsScreen_manageAccount), findsOneWidget);
    expect(find.byKey(const ValueKey('drawer-account-logout')), findsOneWidget);
    expect(find.text(l.settingsManageAccount_logout), findsOneWidget);
  });

  testWidgets('the account popover is a rounded window', (tester) async {
    await pumpDrawerOnRouter(tester);

    await tester.tap(find.byKey(const ValueKey('drawer-profile-icon')));
    await tester.pumpAndSettle();

    // The same 8 px window corner as the app's dropdown windows.
    final shape =
        tester
                .widget<Material>(
                  find.byKey(const ValueKey('drawer-account-popover')),
                )
                .shape
            as RoundedRectangleBorder;
    expect(
      shape.borderRadius,
      BorderRadius.circular(AppSpacing.cardRadius * 2),
    );
  });

  testWidgets('the popover options read at the side menu\'s text size', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpDrawerOnRouter(tester);

    await tester.tap(find.byKey(const ValueKey('drawer-profile-icon')));
    await tester.pumpAndSettle();

    // The side menu's own row, as the yardstick the options must match. A row
    // that is not the active one (the active row is white and bold), so the
    // comparison is against the resting side-menu metric.
    final menuStyle = tester.widget<Text>(drawerText(l.nav_settings)).style;
    for (final option in [
      (const ValueKey('drawer-account-profile'), l.settingsScreen_profile),
      (const ValueKey('drawer-account-manage'), l.settingsScreen_manageAccount),
      (const ValueKey('drawer-account-logout'), l.settingsManageAccount_logout),
    ]) {
      final style = tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(option.$1),
              matching: find.text(option.$2),
            ),
          )
          .style;
      expect(style?.fontSize, menuStyle?.fontSize);
      expect(style?.fontFamily, menuStyle?.fontFamily);
      expect(style?.fontWeight, menuStyle?.fontWeight);
    }
  });

  testWidgets('the account popover grows from the profile icon', (
    tester,
  ) async {
    await pumpDrawerOnRouter(tester);

    final icon = find.byKey(const ValueKey('drawer-profile-icon'));
    final iconRect = tester.getRect(icon);

    await tester.tap(icon);
    await tester.pumpAndSettle();

    final popover = tester.getRect(
      find.byKey(const ValueKey('drawer-account-popover')),
    );

    // Just under the icon: it hangs off the icon rather than rising from the
    // screen's foot, which is the difference between a popover and a sheet (a
    // sheet's top edge on this 1400 px surface would be near 1150).
    expect(popover.top - iconRect.bottom, moreOrLessEquals(8, epsilon: 0.01));
    expect(popover.top, lessThan(400));
  });

  testWidgets('the account popover is a hair narrower than the side menu', (
    tester,
  ) async {
    await pumpDrawerOnRouter(tester);

    final icon = find.byKey(const ValueKey('drawer-profile-icon'));
    final iconRect = tester.getRect(icon);
    final drawerRect = tester.getRect(find.byType(Drawer));

    await tester.tap(icon);
    await tester.pumpAndSettle();

    final popover = tester.getRect(
      find.byKey(const ValueKey('drawer-account-popover')),
    );

    // Narrower than the side menu on both sides, so a strip of the drawer shows
    // beside the panel — a window inside the menu, not a wall over it (0.0.443).
    expect(drawerRect.width, greaterThan(0));
    expect(popover.width, drawerRect.width - AppSpacing.sm * 2);
    expect(popover.left, drawerRect.left + AppSpacing.sm);
    expect(popover.right, drawerRect.right - AppSpacing.sm);
    // Still a move off the icon's own left edge (the panel is a menu window, not
    // an icon-sized bubble).
    expect(popover.left, lessThan(iconRect.left));
  });

  testWidgets('the account popover carries a thin grey outline', (
    tester,
  ) async {
    await pumpDrawerOnRouter(tester);

    await tester.tap(find.byKey(const ValueKey('drawer-profile-icon')));
    await tester.pumpAndSettle();

    // A white panel over the white drawer, so the edge is what tells the user a
    // menu is floating above the panel rather than being part of it.
    final shape =
        tester
                .widget<Material>(
                  find.byKey(const ValueKey('drawer-account-popover')),
                )
                .shape
            as RoundedRectangleBorder;
    expect(shape.side.color, AppColors.outlineVariant);
    expect(shape.side.width, 1.0, reason: 'thin: an edge, not a frame');
  });

  testWidgets('the profile icon carries a small chevron badge', (tester) async {
    await pumpDrawer(tester, locale: const Locale('en'));

    final iconRect = tester.getRect(
      find.byKey(const ValueKey('drawer-profile-icon')),
    );
    final badge = find.byKey(const ValueKey('drawer-profile-icon-indicator'));
    expect(badge, findsOneWidget, reason: 'the avatar says it can be tapped');

    final badgeRect = tester.getRect(badge);
    // Small, and inside the avatar's own box: an affordance, not a second avatar
    // — it leaves the picture alone and does not grow the tap target.
    expect(badgeRect.width, lessThanOrEqualTo(16));
    expect(iconRect.contains(badgeRect.center), isTrue);
    expect(badgeRect.width, lessThan(iconRect.width));

    // The chevron the drawer already uses for "a menu opens here".
    final chevron = find.descendant(
      of: badge,
      matching: find.byIcon(Icons.expand_more),
    );
    expect(chevron, findsOneWidget);
    expect(tester.widget<Icon>(chevron).color, AppColors.onSurfaceVariant);

    // Muted: the panel's own fill behind a hairline of the divider grey, so it
    // reads as a mark on the avatar rather than a coloured dot.
    final decoration =
        tester.widget<Container>(badge).decoration! as BoxDecoration;
    expect(decoration.color, AppColors.surfaceContainerLowest);
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.border!.top.color, AppColors.outlineVariant);
  });

  testWidgets('Profile in the popover opens the Profile page', (tester) async {
    final router = await pumpDrawerOnRouter(tester);

    await tester.tap(find.byKey(const ValueKey('drawer-profile-icon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('drawer-account-profile')));
    await tester.pumpAndSettle();

    expect(find.text(profileMarker), findsOneWidget);
    expect(router.state.matchedLocation, AppRoutes.settingsProfile);
  });

  testWidgets('Manage Account in the popover opens the Manage Account page', (
    tester,
  ) async {
    final router = await pumpDrawerOnRouter(tester);

    await tester.tap(find.byKey(const ValueKey('drawer-profile-icon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('drawer-account-manage')));
    await tester.pumpAndSettle();

    expect(find.text(manageAccountMarker), findsOneWidget);
    expect(router.state.matchedLocation, AppRoutes.settingsManageAccount);
  });

  testWidgets('Logout runs the branched logout and lands on Login', (
    tester,
  ) async {
    // A premium account with nothing queued and no link: the branch that ends
    // the session with no copy to offer and no window to answer, so this test
    // observes what the drawer's own tap set in motion rather than restating
    // the flow's own suite. It is also the case that pins the popover's live
    // `ref`: a panel that closed before the flow ran could not read its
    // providers at all.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    var sessionsEnded = 0;
    final flow = LogoutFlow(
      db: db,
      premium: true,
      online: false,
      runBacklogPush: () async => null,
      endSession: () async => sessionsEnded++,
    );

    final router = await pumpDrawerOnRouter(tester, logoutFlow: flow);

    await tester.tap(find.byKey(const ValueKey('drawer-profile-icon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('drawer-account-logout')));
    await tester.pumpAndSettle();

    expect(sessionsEnded, 1, reason: 'the logout ended the session');
    expect(find.text(loginMarker), findsOneWidget);
    expect(router.state.matchedLocation, AppRoutes.login);
  });

  testWidgets('Logout shows a spinner on the row while the flow is running', (
    tester,
  ) async {
    // A logout held open on purpose: while it awaits, the Logout row's icon
    // is a spinner, so the tap is visibly answered before the wipe finishes.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final gate = Completer<void>();
    var sessionsEnded = 0;
    final flow = LogoutFlow(
      db: db,
      premium: true,
      online: false,
      runBacklogPush: () async => null,
      // wipeToFreshInstall runs for real; endSession is what we hold, so the
      // whole flow stays in flight until the test releases it.
      endSession: () async {
        await gate.future;
        sessionsEnded++;
      },
    );

    await pumpDrawerOnRouter(tester, logoutFlow: flow);
    await tester.tap(find.byKey(const ValueKey('drawer-profile-icon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('drawer-account-logout')));
    await tester.pump();

    // The row's icon is a progress spinner while the flow runs.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('drawer-account-logout')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    // Releasing the flow clears the spinner and reaches Login.
    gate.complete();
    await tester.pumpAndSettle();

    expect(sessionsEnded, 1);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('drawer-account-logout')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
  });

  testWidgets('Logout survives the drawer being unmounted under the popover', (
    tester,
  ) async {
    // A shell-shaped router, like the real app's: the drawer's screen sits on
    // the shell's **nested** navigator, so the popover's close pops that screen
    // and the drawer is deactivated while the panel is still up. The popover's
    // page is then rebuilt — a logout window opens above it — and a panel whose
    // builder still read the drawer's `ref` threw
    // "Using \"ref\" when a widget is about to or has been unmounted". The
    // address, the navigator and the router are now read while the drawer is
    // certainly mounted, so the rebuild is harmless. This test fails on the
    // pre-fix code with that StateError.
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // A row only the user could have authored: the free branch then offers the
    // safety copy, which is the window that rebuilds the popover's page.
    await db
        .into(db.courtCategories)
        .insert(
          const CourtCategoriesCompanion(
            id: Value('drawer-category'),
            nameKey: Value('courtCategory_districtCourtsCivil'),
            courtLevel: Value('lower'),
            orderIndex: Value(1),
            updatedAt: Value(1),
          ),
        );
    await db
        .into(db.courts)
        .insert(
          const CourtsCompanion(
            id: Value('drawer-court'),
            courtName: Value('Drawer Court'),
            higherLowerCourts: Value('lower_courts'),
            courtCategoryId: Value('drawer-category'),
            isCustom: Value(true),
            orderIndex: Value(0),
            updatedAt: Value(1),
          ),
        );
    var sessionsEnded = 0;
    final flow = LogoutFlow(
      db: db,
      premium: false,
      online: false,
      runBacklogPush: () async => null,
      endSession: () async => sessionsEnded++,
    );

    final router = GoRouter(
      initialLocation: AppRoutes.dailyCauseList,
      routes: [
        ShellRoute(
          builder: (_, _, child) => Scaffold(body: child),
          routes: [
            GoRoute(
              path: AppRoutes.dailyCauseList,
              builder: (_, _) => Scaffold(
                drawer: AppNavigationDrawer(
                  currentRoute: AppRoutes.dailyCauseList,
                ),
                body: const SizedBox.shrink(),
              ),
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (_, _) => const Scaffold(body: Text(loginMarker)),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentPlanProvider.overrideWithValue(freePlan),
          authIdentityProvider.overrideWithValue(
            const AuthIdentity(
              userId: 'drawer-test-user',
              email: signedInEmail,
            ),
          ),
          logoutFlowProvider.overrideWith((_) async => flow),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The screen's own Scaffold, the one carrying the drawer.
    tester
        .state<ScaffoldState>(
          find
              .byWidgetPredicate((w) => w is Scaffold && w.drawer != null)
              .first,
        )
        .openDrawer();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('drawer-profile-icon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('drawer-account-logout')));
    // The spinner is up from this tap; a bounded pump lets the confirmation
    // window animate in over it (pumpAndSettle cannot settle an infinite
    // animation).
    await tester.pump(const Duration(milliseconds: 300));

    // The copy is offered before anything is deleted; No wipes without one.
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l.logout_backupPromptTitle), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(l.sharedActions_no),
      ),
    );
    await pumpLogoutToDone(tester);

    expect(sessionsEnded, 1, reason: 'the logout ended the session');
    expect(router.state.matchedLocation, AppRoutes.login);
  });

  testWidgets('Logout leaves the side menu open while its windows run', (
    tester,
  ) async {
    // A free account with authored data takes the backup-choice branch, so a
    // confirmation window opens above the still-open drawer. The drawer and its
    // account panel must stay up until the flow is done — a cancelled logout
    // leaves the user exactly where they were.
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.courtCategories)
        .insert(
          const CourtCategoriesCompanion(
            id: Value('drawer-category'),
            nameKey: Value('courtCategory_districtCourtsCivil'),
            courtLevel: Value('lower'),
            orderIndex: Value(1),
            updatedAt: Value(1),
          ),
        );
    await db
        .into(db.courts)
        .insert(
          const CourtsCompanion(
            id: Value('drawer-court'),
            courtName: Value('Drawer Court'),
            higherLowerCourts: Value('lower_courts'),
            courtCategoryId: Value('drawer-category'),
            isCustom: Value(true),
            orderIndex: Value(0),
            updatedAt: Value(1),
          ),
        );
    var sessionsEnded = 0;
    final flow = LogoutFlow(
      db: db,
      premium: false,
      online: false,
      runBacklogPush: () async => null,
      endSession: () async => sessionsEnded++,
    );

    final router = GoRouter(
      initialLocation: AppRoutes.dailyCauseList,
      routes: [
        ShellRoute(
          builder: (_, _, child) => Scaffold(body: child),
          routes: [
            GoRoute(
              path: AppRoutes.dailyCauseList,
              builder: (_, _) => Scaffold(
                drawer: AppNavigationDrawer(
                  currentRoute: AppRoutes.dailyCauseList,
                ),
                body: const SizedBox.shrink(),
              ),
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (_, _) => const Scaffold(body: Text(loginMarker)),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentPlanProvider.overrideWithValue(freePlan),
          authIdentityProvider.overrideWithValue(
            const AuthIdentity(
              userId: 'drawer-test-user',
              email: signedInEmail,
            ),
          ),
          logoutFlowProvider.overrideWith((_) async => flow),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester
        .state<ScaffoldState>(
          find
              .byWidgetPredicate((w) => w is Scaffold && w.drawer != null)
              .first,
        )
        .openDrawer();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('drawer-profile-icon')));
    await tester.pumpAndSettle();
    // The menu is open when the logout is started.
    expect(find.text('Daily Cause List'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('drawer-account-logout')));
    // The spinner is up from this tap, so a bounded pump (not pumpAndSettle)
    // lets the confirmation window animate in over it.
    await tester.pump(const Duration(milliseconds: 300));

    // The confirmation window is up, and the side menu has NOT been closed
    // underneath it — the drawer's own row is still on screen.
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l.logout_backupPromptTitle), findsOneWidget);
    expect(find.text('Daily Cause List'), findsOneWidget);

    // Declining the copy wipes without one — the same branch the sibling test
    // proves reaches Login — while the drawer has stayed open throughout.
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(l.sharedActions_no),
      ),
    );
    await pumpLogoutToDone(tester);

    expect(sessionsEnded, 1, reason: 'the logout ended the session');
    expect(router.state.matchedLocation, AppRoutes.login);
  });

  testWidgets('the Admin row badges the work waiting in the panel', (
    tester,
  ) async {
    await pumpDrawerOnRouter(tester, adminBadgeCount: 4);
    await tester.tap(find.byKey(const ValueKey('drawer-profile-icon')));
    await tester.pumpAndSettle();

    // The row exists (the account is an admin) and carries the count over its
    // icon, the way the Sync Status icon carries its own.
    expect(find.text('Admin Panel'), findsOneWidget);
    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isTrue);
    expect(
      find.descendant(of: find.byType(Badge), matching: find.text('4')),
      findsOneWidget,
    );
  });
  testWidgets("the Admin row's count uses the language's own digits", (
    tester,
  ) async {
    await pumpDrawerOnRouter(
      tester,
      adminBadgeCount: 4,
      locale: const Locale('bn'),
    );
    await tester.tap(find.byKey(const ValueKey('drawer-profile-icon')));
    await tester.pumpAndSettle();

    // A count is written in the active language's digits whichever icon carries
    // it: `Badge.count` paints Latin ones, and this row is not an exception.
    final badge = find.byType(Badge);
    expect(badge, findsOneWidget);
    expect(
      find.descendant(of: badge, matching: find.text('৪')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: badge, matching: find.text('4')),
      findsNothing,
      reason: 'the count was painted in Latin digits',
    );
  });

  testWidgets('the Admin row carries no badge when nothing is waiting', (
    tester,
  ) async {
    await pumpDrawerOnRouter(tester, adminBadgeCount: 0);
    await tester.tap(find.byKey(const ValueKey('drawer-profile-icon')));
    await tester.pumpAndSettle();

    // The row is there, with a plain icon and no count over it.
    expect(find.text('Admin Panel'), findsOneWidget);
    expect(find.byType(Badge), findsNothing);
  });

  testWidgets(
    'Check for update sits below Share, and opens the drawer no wider',
    (tester) async {
      useTallViewport(tester);
      await pumpDrawer(tester, locale: const Locale('en'));
      final l = await AppLocalizations.delegate.load(const Locale('en'));

      // Below Share, as asked.
      final share = tester.getRect(drawerText(l.nav_share)).top;
      final update = tester
          .getRect(drawerText(l.settingsUpdate_checkForUpdate))
          .top;
      expect(update, greaterThan(share));
    },
  );

  testWidgets('tapping it checks and cascades the result underneath', (
    tester,
  ) async {
    useTallViewport(tester);
    final repo = _FakeUpdateRepository(
      outcome: const UpdateCheckOutcome(
        ReleaseCheckResult.updateAvailable,
        release: AppRelease(
          version: '99.99.999',
          downloadUrl: 'https://example.test/app.apk',
        ),
      ),
    );
    await pumpDrawer(
      tester,
      locale: const Locale('en'),
      updateRepository: repo,
    );
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    // Nothing is said before the tap.
    expect(
      drawerText('There is a newer version available (V99.99.999).'),
      findsNothing,
    );

    await tester.tap(drawerKey('drawer-update'));
    await tester.pumpAndSettle();

    expect(repo.checks, 1);
    // The line cascades under the row, the same sentence the About card shows.
    expect(
      drawerText('There is a newer version available (V99.99.999).'),
      findsOneWidget,
    );
    // And the row itself turns into the install action.
    expect(drawerText(l.settingsUpdate_updateNow), findsOneWidget);
  });

  testWidgets('a clean check cascades the latest-version line', (tester) async {
    useTallViewport(tester);
    await pumpDrawer(
      tester,
      locale: const Locale('en'),
      updateRepository: _FakeUpdateRepository(),
    );

    await tester.tap(drawerKey('drawer-update'));
    await tester.pumpAndSettle();

    expect(
      drawerText('You are on the latest V$appVersion version.'),
      findsOneWidget,
    );
  });

  testWidgets('the row carries the dot only when an update is offered', (
    tester,
  ) async {
    useTallViewport(tester);
    // Seeded before the pump: the store reads preferences once when built.
    SharedPreferences.setMockInitialValues(<String, Object>{
      updateAvailableReleaseKey:
          '{"version":"99.99.999","url":"https://example.test/app.apk"}',
    });
    prefs = await SharedPreferences.getInstance();
    await pumpDrawer(tester, locale: const Locale('en'));

    // The same dot the About and Update rows show.
    final dot = find.descendant(
      of: drawerKey('drawer-update'),
      matching: find.byType(UpdateDot),
    );
    expect(dot, findsOneWidget);
  });

  testWidgets('no dot when nothing is waiting', (tester) async {
    useTallViewport(tester);
    await pumpDrawer(tester, locale: const Locale('en'));

    expect(
      find.descendant(
        of: drawerKey('drawer-update'),
        matching: find.byType(UpdateDot),
      ),
      findsNothing,
    );
  });

  testWidgets('a case screen in the bottom bar is hidden from the drawer', (
    tester,
  ) async {
    useTallViewport(tester);
    await pumpDrawer(
      tester,
      locale: const Locale('en'),
      // The bar carries these three; the drawer must not repeat them.
      bottomNavTabs: const <String>['active', 'overdue', 'notes'],
    );

    expect(drawerText('Active Cases'), findsNothing);
    expect(drawerText('Overdue Dates'), findsNothing);
    // Notes is a *tool* row, not a case screen, so it stays (user request).
    expect(drawerText('Notes'), findsOneWidget);
    // The case screens the bar does not carry stay put.
    expect(drawerText('All Cases'), findsOneWidget);
    expect(drawerText('Daily Cause List'), findsOneWidget);
    expect(drawerText('Upcoming Cases'), findsOneWidget);
    expect(drawerText('Disposed Cases'), findsOneWidget);
  });

  testWidgets('the arrow rides the last visible case row and expands the rest', (
    tester,
  ) async {
    useTallViewport(tester);
    await pumpDrawer(
      tester,
      locale: const Locale('en'),
      bottomNavTabs: const <String>['all_cases', 'active'],
    );

    // All Cases and Active are in the bar, so the group starts at Daily Cause
    // List — and the arrow rides the end of it.
    expect(drawerText('All Cases'), findsNothing);
    expect(drawerKey('drawer-case-expander'), findsOneWidget);

    await tester.tap(drawerKey('drawer-case-expander'));
    await tester.pumpAndSettle();

    // The full list: the bar's screens back in the drawer, in the serial order.
    expect(drawerText('All Cases'), findsOneWidget);
    expect(drawerText('Active Cases'), findsOneWidget);
    final all = tester.getRect(drawerText('All Cases')).top;
    final active = tester.getRect(drawerText('Active Cases')).top;
    final daily = tester.getRect(drawerText('Daily Cause List')).top;
    expect(all, lessThan(active));
    expect(active, lessThan(daily));
  });

  testWidgets(
    'the expanded list follows the saved serial, not the canonical one',
    (tester) async {
      useTallViewport(tester);
      await pumpDrawer(
        tester,
        locale: const Locale('en'),
        // The user dragged Disposed to the front in View Settings.
        bottomNavTabs: const <String>['all_cases'],
        bottomNavOrder: const <String>['disposed', 'notes', 'upcoming'],
      );

      await tester.tap(drawerKey('drawer-case-expander'));
      await tester.pumpAndSettle();

      // Disposed leads, because that is the serial the user set.
      final disposed = tester.getRect(drawerText('Disposed Cases')).top;
      final upcoming = tester.getRect(drawerText('Upcoming Cases')).top;
      final daily = tester.getRect(drawerText('Daily Cause List')).top;
      expect(disposed, lessThan(upcoming));
      expect(upcoming, lessThan(daily));
    },
  );

  testWidgets('no arrow when the bar carries no case screen', (tester) async {
    useTallViewport(tester);
    await pumpDrawer(
      tester,
      locale: const Locale('en'),
      // Only a tool row is in the bar, so nothing is hidden and there is
      // nothing to expand.
      bottomNavTabs: const <String>['notes'],
    );

    expect(drawerText('All Cases'), findsOneWidget);
    expect(drawerKey('drawer-case-expander'), findsNothing);
  });

  testWidgets('the group disappears when the bar carries every case screen', (
    tester,
  ) async {
    useTallViewport(tester);
    await pumpDrawer(
      tester,
      locale: const Locale('en'),
      bottomNavTabs: const <String>[
        'all_cases',
        'active',
        'daily_cause_list',
        'overdue',
        'upcoming',
        'disposed',
      ],
    );

    // Every case screen is in the bar, so the drawer lists none of them — and
    // there is no row left to hang an arrow on.
    for (final label in const <String>[
      'All Cases',
      'Active Cases',
      'Daily Cause List',
      'Overdue Dates',
      'Upcoming Cases',
      'Disposed Cases',
    ]) {
      expect(drawerText(label), findsNothing, reason: label);
    }
    expect(drawerKey('drawer-case-expander'), findsNothing);
    // The rest of the drawer is untouched.
    expect(drawerText('Notes'), findsOneWidget);
    expect(drawerText('Settings'), findsOneWidget);
  });

  testWidgets('the arrow is white when its row is the active one', (
    tester,
  ) async {
    useTallViewport(tester);
    // Disposed is the last case row once Active and Overdue are in the bar, so
    // the arrow rides it — and the drawer is opened *on* it, making it the
    // active row. The active row paints black, so a grey arrow would vanish.
    await pumpDrawer(
      tester,
      locale: const Locale('en'),
      route: AppRoutes.disposedCases,
      bottomNavTabs: const <String>['active', 'overdue'],
    );

    final arrow = find.descendant(
      of: drawerKey('drawer-case-expander'),
      matching: find.byType(Icon),
    );
    expect(tester.widget<Icon>(arrow).color, Colors.white);
  });

  testWidgets('the arrow keeps the muted ink on an ordinary row', (
    tester,
  ) async {
    useTallViewport(tester);
    // The same last row, but the drawer is open on a different screen, so the
    // row is not active and the arrow stays the usual grey.
    await pumpDrawer(
      tester,
      locale: const Locale('en'),
      route: AppRoutes.notes,
      bottomNavTabs: const <String>['active', 'overdue'],
    );

    final arrow = find.descendant(
      of: drawerKey('drawer-case-expander'),
      matching: find.byType(Icon),
    );
    expect(
      tester.widget<Icon>(arrow).color,
      isNot(Colors.white),
      reason: 'the grey arrow on a white row',
    );
  });

  testWidgets('Rate App sits between Share and Check for update', (
    tester,
  ) async {
    useTallViewport(tester);
    await pumpDrawer(tester, locale: const Locale('en'));
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    final share = tester.getRect(drawerText(l.nav_share)).top;
    final rate = tester.getRect(drawerText(l.drawer_rateApp)).top;
    final update = tester
        .getRect(drawerText(l.settingsUpdate_checkForUpdate))
        .top;
    expect(rate, greaterThan(share));
    expect(update, greaterThan(rate));
  });

  testWidgets('tapping Rate App says it is not open yet, and closes the menu', (
    tester,
  ) async {
    useTallViewport(tester);
    await pumpDrawer(tester, locale: const Locale('en'));
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(drawerText(l.drawer_rateApp));
    await tester.pumpAndSettle();

    // The listing does not exist yet, so the row says so rather than opening a
    // page that 404s.
    expect(find.text(l.drawer_rateAppPending), findsOneWidget);
    // It is an ordinary action row, so it closes the drawer like Print/Share.
    expect(find.byType(Drawer), findsNothing);
  });

  testWidgets('a stored offer turns the row into Update now', (tester) async {
    useTallViewport(tester);
    // Seeded before the pump: the store reads preferences once when built. This
    // is a release the *launch check* found — this row's own controller never
    // saw it — so the row has to read the store, not just its own phase.
    SharedPreferences.setMockInitialValues(<String, Object>{
      updateAvailableReleaseKey:
          '{"version":"99.99.999","url":"https://example.test/app.apk"}',
    });
    prefs = await SharedPreferences.getInstance();
    await pumpDrawer(tester, locale: const Locale('en'));
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    expect(drawerText(l.settingsUpdate_updateNow), findsOneWidget);
    expect(drawerText(l.settingsUpdate_checkForUpdate), findsNothing);
    // And in green, so the row that can change the app says so.
    expect(updateRowInk(tester, l.settingsUpdate_updateNow), AppColors.success);
  });

  testWidgets('a check that finds nothing keeps the row plain and grey', (
    tester,
  ) async {
    useTallViewport(tester);
    await pumpDrawer(
      tester,
      locale: const Locale('en'),
      updateRepository: _FakeUpdateRepository(),
    );
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    expect(drawerText(l.settingsUpdate_checkForUpdate), findsOneWidget);
    expect(drawerText(l.settingsUpdate_updateNow), findsNothing);
    expect(
      updateRowInk(tester, l.settingsUpdate_checkForUpdate),
      AppColors.onSurfaceVariant,
    );
  });

  testWidgets('a check that finds a release turns the row green', (
    tester,
  ) async {
    useTallViewport(tester);
    await pumpDrawer(
      tester,
      locale: const Locale('en'),
      updateRepository: _FakeUpdateRepository(
        outcome: const UpdateCheckOutcome(
          ReleaseCheckResult.updateAvailable,
          release: AppRelease(
            version: '99.99.999',
            downloadUrl: 'https://example.test/app.apk',
          ),
        ),
      ),
    );
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    // Grey before the tap...
    expect(
      updateRowInk(tester, l.settingsUpdate_checkForUpdate),
      AppColors.onSurfaceVariant,
    );

    await tester.tap(drawerKey('drawer-update'));
    await tester.pumpAndSettle();

    // ...green once it has something to install, by the manual route too.
    expect(drawerText(l.settingsUpdate_updateNow), findsOneWidget);
    expect(updateRowInk(tester, l.settingsUpdate_updateNow), AppColors.success);
  });

  testWidgets('a release found after the row was built turns it green', (
    tester,
  ) async {
    useTallViewport(tester);
    // The case the store read exists for: the row is already built and its
    // controller is idle, and *then* something finds a release — which is what
    // the launch check does, minutes after the drawer was laid out. The
    // controller would still be idle, so only the store can tell the row.
    await pumpDrawer(
      tester,
      locale: const Locale('en'),
      updateRepository: _FakeUpdateRepository(),
    );
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    expect(drawerText(l.settingsUpdate_checkForUpdate), findsOneWidget);
    expect(
      updateRowInk(tester, l.settingsUpdate_checkForUpdate),
      AppColors.onSurfaceVariant,
    );

    // A check elsewhere — exactly the launch check — stores what it found.
    ProviderScope.containerOf(tester.element(find.byType(Drawer)))
        .read(updateMetadataProvider.notifier)
        .recordCheck(
          atEpochMs: 0,
          offline: false,
          release: const AppRelease(
            version: '99.99.999',
            downloadUrl: 'https://example.test/app.apk',
          ),
        );
    await tester.pumpAndSettle();

    expect(drawerText(l.settingsUpdate_updateNow), findsOneWidget);
    expect(updateRowInk(tester, l.settingsUpdate_updateNow), AppColors.success);
  });
}
