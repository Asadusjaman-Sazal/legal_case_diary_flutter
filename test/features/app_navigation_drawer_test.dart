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
/// request): corners far rounder than the card radius, the address line marked
/// by its `@` icon alone, and its three options reading at the side menu's own
/// text size.
library;

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
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_name_store.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/data/logout_flow.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_viewmodel.dart';
import 'package:legal_case_diary/features/payments/data/payment_plans.dart';
import 'package:legal_case_diary/features/payments/presentation/current_plan.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:legal_case_diary/shared/widgets/app_navigation_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A free account's plan, as the drawer's own derivation reports it.
const CurrentPlan freePlan = (known: true, premium: false, planKey: null);

/// A paid account's plan, named by its approved submission.
const CurrentPlan quarterlyPlan = (
  known: true,
  premium: true,
  planKey: paymentPlanQuarterly,
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
  }) async {
    await ProfileStore(
      prefs,
    ).write(const ProfileFields(fullName: 'Rahim Uddin'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: Scaffold(
            drawer: AppNavigationDrawer(currentRoute: route),
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
          // The address the sheet names. Stubbed, so a sheet that invented its
          // own address (or printed nothing) would fail the assertion below.
          authIdentityProvider.overrideWithValue(
            AuthIdentity(userId: 'drawer-test-user', email: email),
          ),
          if (logoutFlow != null)
            logoutFlowProvider.overrideWith((_) async => logoutFlow),
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

  testWidgets('the plan row names the running plan, then expands to two pages', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    // A paid plan, so the row is pinned to name the plan itself ("3 Months")
    // rather than falling back to the word Premium.
    final router = await pumpDrawerOnRouter(tester, plan: quarterlyPlan);

    expect(drawerText(l.paywall_planQuarterly), findsOneWidget);
    // The caption says which fact that word is: a bare "3 Months" beside a
    // chevron would read as the name of a screen.
    expect(drawerText(l.settingsSubscription_currentPlan), findsOneWidget);
    expect(
      tester.getTopLeft(drawerText(l.paywall_planQuarterly)).dy,
      lessThan(
        tester.getTopLeft(drawerText(l.settingsSubscription_currentPlan)).dy,
      ),
    );

    // It sits in the Print/Share group, not under Settings (user request): a
    // section divider now separates it from Settings, and Print — the row it
    // was asked to sit above — follows it.
    final captionY = tester
        .getTopLeft(drawerText(l.settingsSubscription_currentPlan))
        .dy;
    final settingsY = tester.getTopLeft(drawerText(l.nav_settings)).dy;
    expect(
      drawerDividerYs(tester).where((y) => y > settingsY && y < captionY),
      isNotEmpty,
    );
    expect(captionY, lessThan(tester.getTopLeft(drawerText(l.nav_print)).dy));

    // Collapsed, neither destination is offered yet.
    expect(
      drawerText(l.settingsManageAccount_subscriptionDetails),
      findsNothing,
    );
    expect(drawerText(l.paywall_title), findsNothing);

    await tester.tap(drawerText(l.paywall_planQuarterly));
    await tester.pumpAndSettle();

    // Expanding is not navigating: the app is still on the screen the drawer
    // was opened from.
    expect(router.state.matchedLocation, AppRoutes.dailyCauseList);
    expect(
      drawerText(l.settingsManageAccount_subscriptionDetails),
      findsOneWidget,
    );
    expect(drawerText(l.paywall_title), findsOneWidget);
  });

  testWidgets('Subscription Details opens the details sub-page', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    final router = await pumpDrawerOnRouter(tester);

    await tester.tap(drawerText(l.settingsManageAccount_planFree));
    await tester.pumpAndSettle();
    await tester.tap(drawerText(l.settingsManageAccount_subscriptionDetails));
    await tester.pumpAndSettle();

    expect(find.text(subscriptionDetailsMarker), findsOneWidget);
    expect(
      router.state.matchedLocation,
      AppRoutes.settingsSubscriptionDetails,
    );
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

  testWidgets('the row is already open on a screen it leads to', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    // Opened from the details sub-page itself: its row must be visible and
    // filled, not hidden inside a collapsed header.
    await pumpDrawerOnRouter(
      tester,
      route: AppRoutes.settingsSubscriptionDetails,
    );

    expect(
      drawerText(l.settingsManageAccount_subscriptionDetails),
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
    expect(find.byKey(const ValueKey('drawer-account-profile')), findsOneWidget);
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

    // Far rounder than the 4 px card radius: the reference panel's own shape.
    final shape =
        tester
                .widget<Material>(
                  find.byKey(const ValueKey('drawer-account-popover')),
                )
                .shape
            as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(16));
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
            find.descendant(of: find.byKey(option.$1), matching: find.text(option.$2)),
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

  testWidgets('the account popover carries a thin grey outline', (tester) async {
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
}
