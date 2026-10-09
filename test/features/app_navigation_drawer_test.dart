/// Guards the side-menu polish.
///
/// The selected item is filled black, and the profile header renders three
/// centre-aligned lines whose order flips between English ("Legal Case Diary /
/// of / name") and Bengali ("name / এর / লিগ্যাল কেস ডায়েরি").
///
/// It also guards the **current plan** row: it names the running plan, expands
/// into Subscription Details and Subscription Plans rather than navigating, and
/// each of those two rows opens the screen it names.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:legal_case_diary/core/constants/app_version.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_name_store.dart';
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
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentPlanProvider.overrideWithValue(plan),
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
}
