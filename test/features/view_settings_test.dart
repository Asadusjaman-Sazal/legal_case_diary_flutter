/// Tests for the View Settings screen (Task 12 Phase 4).
///
/// The screen has no mockup: it implements plan §10.1 and writes each choice to
/// the per-user `user_preferences` row. These tests cover the five settings and
/// the rule that at least one bottom-bar tab always remains.
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

  testWidgets('shows the five settings with their current values', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('View Settings'), findsOneWidget);
    expect(find.text('DISPLAY'), findsOneWidget);
    expect(find.text('NAVIGATION'), findsOneWidget);
    // Plan §10.1 defaults.
    expect(find.text('7 days'), findsOneWidget);
    expect(find.text('Compact'), findsOneWidget);
    expect(find.text('Daily Cause List'), findsWidgets);
    expect(find.byType(Checkbox), findsNWidgets(6));
    expect(find.byType(SwitchListTile), findsNWidgets(7));
  });

  testWidgets('the upcoming-cases period is stored', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(SettingsPickerRow, '7 days'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SettingsOptionRow, '14 days'));
    await tester.pumpAndSettle();

    expect(repo.settings.upcomingCasesPeriod, 14);
    expect(find.text('14 days'), findsOneWidget);
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

  testWidgets('a bottom-bar tab can be added and removed', (tester) async {
    await pumpScreen(tester);
    // The plan's four defaults.
    expect(repo.settings.bottomNavTabs, hasLength(4));

    // Add "All Cases": its checkbox is the 5th of the six candidates.
    final allCases = find.byType(Checkbox).at(4);
    await tester.ensureVisible(allCases);
    await tester.pumpAndSettle();
    await tester.tap(allCases);
    await tester.pumpAndSettle();
    expect(repo.settings.bottomNavTabs, contains('all_cases'));
    expect(repo.settings.bottomNavTabs, hasLength(5));

    await tester.ensureVisible(allCases);
    await tester.pumpAndSettle();
    await tester.tap(allCases);
    await tester.pumpAndSettle();
    expect(repo.settings.bottomNavTabs, isNot(contains('all_cases')));
    expect(repo.settings.bottomNavTabs, hasLength(4));
  });

  testWidgets('the last remaining tab cannot be removed', (tester) async {
    repo = FakeSettingsRepository(
      const UserSettings(bottomNavTabs: <String>['active']),
    );
    await pumpScreen(tester);

    await tester.ensureVisible(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(repo.settings.bottomNavTabs, <String>['active']);
    expect(
      find.text('Keep at least one screen in the bottom bar.'),
      findsOneWidget,
    );
  });

  testWidgets('side-navigation sections can be hidden', (tester) async {
    await pumpScreen(tester);

    // Fourth switch is "Disposed Cases" in drawer order.
    final disposed = find.byType(SwitchListTile).at(3);
    await tester.ensureVisible(disposed);
    await tester.pumpAndSettle();
    await tester.tap(disposed);
    await tester.pumpAndSettle();

    expect(repo.settings.sideNavOptions[AppRoutes.disposedCases], isFalse);
    expect(repo.settings.sideNavOptions[AppRoutes.notes], isNull);
  });

  testWidgets('the default landing page is stored', (tester) async {
    // Seeded explicitly: `UserSettings` currently defaults to `all_cases` for
    // on-device testing (see docs/currentlyWorking.md), while plan §10.1 calls
    // for Daily Cause List. The screen must simply show and save what is stored.
    repo = FakeSettingsRepository(
      const UserSettings(defaultLandingPage: 'daily_cause_list'),
    );
    await pumpScreen(tester);

    // The landing page is the last control on a long page, so it starts below
    // the viewport and is not built until scrolled into range.
    final landingRow = find.widgetWithText(
      SettingsPickerRow,
      'Daily Cause List',
    );
    await tester.scrollUntilVisible(
      landingRow,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
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
