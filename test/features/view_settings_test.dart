/// Tests for the View Settings screen (Task 12 Phase 4).
///
/// The screen has no mockup: it implements plan §10.1 and writes each choice to
/// the per-user `user_preferences` row. These tests cover the five settings,
/// the titled dropdowns they are rendered as, the drag & drop order of the
/// bottom bar and the rule that at least one tab always remains.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/features/settings/data/settings_repository.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_controls.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_view/view_settings_screen.dart';
import 'package:legal_case_diary/shared/widgets/bottom_nav_bar.dart';

import 'settings_test_support.dart';

void main() {
  late FakeSettingsRepository repo;

  setUp(() {
    repo = FakeSettingsRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) =>
      pumpSettingsScreen(tester, const ViewSettingsScreen(), repo: repo);

  /// Opens one of the two list dropdowns from its collapsed row.
  Future<void> openDropdown(WidgetTester tester, String rowText) async {
    await tester.tap(find.widgetWithText(SettingsPickerRow, rowText));
    await tester.pumpAndSettle();
  }

  /// Scrolls [finder] into view; the page is taller than the test viewport, so
  /// its last card is not built until the list is scrolled.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the five settings, each with its own title', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('View Settings'), findsOneWidget);
    // Card labels, upper-cased by the shared section label.
    expect(find.text('DISPLAY'), findsOneWidget);
    expect(find.text('NAVIGATION'), findsOneWidget);
    // Every dropdown is titled above the control, in Title Case.
    expect(find.text('UPCOMING CASES PERIOD'), findsOneWidget);
    expect(find.text('CASE LIST DISPLAY'), findsOneWidget);
    expect(find.text('BOTTOM NAVIGATION'), findsOneWidget);
    expect(find.text('SIDE NAVIGATION OPTIONS'), findsOneWidget);
    // Collapsed values: plan §10.1 defaults, all Title Case.
    expect(find.text('7 Days'), findsOneWidget);
    expect(find.text('Compact'), findsOneWidget);
    expect(find.text('4 Screens Selected'), findsOneWidget);
    expect(find.text('7 of 7 Sections Shown'), findsOneWidget);
    // The list settings are no longer rendered inline on the page.
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    // Default Landing Page sits in a card of its own, below Navigation.
    await scrollTo(tester, find.text('DEFAULT LANDING PAGE'));
    expect(find.text('DEFAULT LANDING PAGE'), findsOneWidget);
    expect(find.widgetWithText(SettingsPickerRow, 'All Cases'), findsOneWidget);
  });

  testWidgets('the upcoming-cases period is stored', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(SettingsPickerRow, '7 Days'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SettingsOptionRow, '14 Days'));
    await tester.pumpAndSettle();

    expect(repo.settings.upcomingCasesPeriod, 14);
    expect(find.text('14 Days'), findsOneWidget);
  });

  testWidgets('the case-list display mode is stored', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(SettingsPickerRow, 'Compact'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SettingsOptionRow, 'Expanded'));
    await tester.pumpAndSettle();

    expect(repo.settings.caseListDisplayMode, 'expanded');
    expect(find.text('Expanded'), findsOneWidget);
  });

  testWidgets('the bottom-navigation dropdown lists every candidate screen', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openDropdown(tester, '4 Screens Selected');

    // Six candidates, one check-mark row each, and no per-screen icon.
    expect(find.byType(SettingsOptionRow), findsNWidgets(6));
    for (final label in <String>[
      'Overdue Dates',
      'Daily Cause List',
      'Active Cases',
      'Upcoming Cases',
      'All Cases',
      'Disposed Cases',
    ]) {
      expect(find.widgetWithText(SettingsOptionRow, label), findsOneWidget);
    }
    expect(find.byIcon(Icons.error_outline), findsNothing);
    // The four defaults are ticked, the two extras are not.
    expect(find.byIcon(Icons.check_circle), findsNWidgets(4));
  });

  testWidgets('a bottom-bar tab can be added and removed', (tester) async {
    await pumpScreen(tester);
    // The plan's four defaults.
    expect(repo.settings.bottomNavTabs, hasLength(4));

    await openDropdown(tester, '4 Screens Selected');

    // Add "All Cases"; the dropdown stays open, so the row behind already
    // reports the new count.
    await tester.tap(find.widgetWithText(SettingsOptionRow, 'All Cases'));
    await tester.pumpAndSettle();
    expect(repo.settings.bottomNavTabs, contains('all_cases'));
    expect(repo.settings.bottomNavTabs, hasLength(5));
    expect(find.text('5 Screens Selected'), findsOneWidget);

    await tester.tap(find.widgetWithText(SettingsOptionRow, 'All Cases'));
    await tester.pumpAndSettle();
    expect(repo.settings.bottomNavTabs, isNot(contains('all_cases')));
    expect(repo.settings.bottomNavTabs, hasLength(4));
  });

  testWidgets('bottom-bar tabs can be reordered by drag & drop', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openDropdown(tester, '4 Screens Selected');
    expect(repo.settings.bottomNavTabs, <String>[
      'overdue',
      'daily_cause_list',
      'active',
      'upcoming',
    ]);

    // Drag the first row (Overdue Dates) past the second one. `timedDrag`
    // pumps frames between moves, which the reorder needs to track the proxy.
    await tester.timedDrag(
      find.byIcon(Icons.drag_indicator).first,
      const Offset(0, 60),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();

    expect(repo.settings.bottomNavTabs, <String>[
      'daily_cause_list',
      'overdue',
      'active',
      'upcoming',
    ]);
  });

  testWidgets('the last remaining tab cannot be removed', (tester) async {
    repo = FakeSettingsRepository(
      const UserSettings(bottomNavTabs: <String>['active']),
    );
    await pumpScreen(tester);
    await openDropdown(tester, '1 Screens Selected');

    await tester.tap(find.widgetWithText(SettingsOptionRow, 'Active Cases'));
    await tester.pumpAndSettle();

    expect(repo.settings.bottomNavTabs, <String>['active']);
    expect(
      find.text('Keep at Least One Screen in the Bottom Bar.'),
      findsOneWidget,
    );
  });

  testWidgets('side-navigation sections can be hidden', (tester) async {
    await pumpScreen(tester);
    await openDropdown(tester, '7 of 7 Sections Shown');
    expect(find.byType(SettingsOptionRow), findsNWidgets(7));

    await tester.tap(find.widgetWithText(SettingsOptionRow, 'Disposed Cases'));
    await tester.pumpAndSettle();

    expect(repo.settings.sideNavOptions[AppRoutes.disposedCases], isFalse);
    // The whole map is written, so the untouched sections stay explicitly on.
    expect(repo.settings.sideNavOptions[AppRoutes.notes], isTrue);
    expect(find.text('6 of 7 Sections Shown'), findsOneWidget);
  });

  testWidgets('the default landing page is stored', (tester) async {
    // Seeded explicitly: `UserSettings` currently defaults to `all_cases` for
    // on-device testing (see docs/currentlyWorking.md), while plan §10.1 calls
    // for Daily Cause List. The screen must simply show and save what is stored.
    repo = FakeSettingsRepository(
      const UserSettings(defaultLandingPage: 'daily_cause_list'),
    );
    await pumpScreen(tester);

    // The landing page card is the last one and can start below the viewport,
    // so the row is scrolled into range before it is tapped.
    final landingRow = find.widgetWithText(
      SettingsPickerRow,
      'Daily Cause List',
    );
    await scrollTo(tester, landingRow);
    await tester.tap(landingRow);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SettingsOptionRow, 'Active Cases'));
    await tester.pumpAndSettle();

    expect(repo.settings.defaultLandingPage, 'active');
    expect(
      find.widgetWithText(SettingsPickerRow, 'Active Cases'),
      findsOneWidget,
    );
  });

  testWidgets('the stored tabs are what the bottom bar renders', (
    tester,
  ) async {
    String? tapped;

    // Wrapped in a Scaffold: the bar is a Scaffold's `bottomNavigationBar` in
    // the app, and its ink splashes need that Material ancestor.
    Future<void> pumpBar(List<String> keys) => pumpSettingsScreen(
      tester,
      Scaffold(
        body: BottomNavBar(
          currentRoute: AppRoutes.notes,
          tabKeys: keys,
          onTabSelected: (route) => tapped = route,
        ),
      ),
      repo: repo,
    );

    // Four tabs (the plan's default selection) lay out evenly.
    await pumpBar(const <String>[
      'overdue',
      'daily_cause_list',
      'active',
      'upcoming',
    ]);
    expect(find.byType(InkWell), findsNWidgets(4));
    expect(find.byType(Expanded), findsNWidgets(4));
    expect(find.text('Overdue Dates'), findsOneWidget);
    expect(find.text('Upcoming Cases'), findsOneWidget);

    // A larger selection renders every tab and scrolls instead of squeezing.
    await pumpBar(const <String>[
      'overdue',
      'daily_cause_list',
      'active',
      'upcoming',
      'all_cases',
      'disposed',
    ]);
    expect(find.byType(InkWell), findsNWidgets(6));
    expect(find.text('All Cases'), findsOneWidget);
    expect(find.text('Disposed Cases'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    // Tapping a tab reports the route the bar would navigate to.
    await tester.tap(find.text('Upcoming Cases'));
    await tester.pumpAndSettle();
    expect(tapped, AppRoutes.upcomingCases);
  });

  test('every offered landing page resolves to its own route', () {
    const keys = <String>[
      'daily_cause_list',
      'overdue',
      'active',
      'upcoming',
      'all_cases',
      'disposed',
    ];
    final routes = keys.map(AppRoutes.landingPageRoute).toList();

    expect(routes.toSet(), hasLength(keys.length));
    for (final route in routes) {
      expect(route, startsWith('/'));
    }
    expect(AppRoutes.landingPageRoute('active'), AppRoutes.activeCases);
    expect(AppRoutes.landingPageRoute('disposed'), AppRoutes.disposedCases);
  });
}
