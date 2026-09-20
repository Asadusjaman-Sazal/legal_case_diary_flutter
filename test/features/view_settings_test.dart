/// Tests for the View Settings screen (Task 12 Phase 4).
///
/// The screen has no mockup: it implements plan §10.1 and writes each choice to
/// the per-user `user_preferences` row. These tests cover the five settings,
/// the titled dropdowns they are rendered as, the drag & drop order of the
/// bottom bar and the rule that at least one tab always remains.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/constants/app_spacing.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/features/settings/data/settings_repository.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_controls.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_view/view_settings_screen.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:legal_case_diary/shared/widgets/app_navigation_drawer.dart';
import 'package:legal_case_diary/shared/widgets/bottom_nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_test_support.dart';

/// The canonical screen order both list dropdowns offer: the drawer sections
/// that can be hidden, in the order the drawer and the dropdowns list them.
const List<String> canonicalScreens = <String>[
  'All Cases',
  'Active Cases',
  'Daily Cause List',
  'Overdue Dates',
  'Upcoming Cases',
  'Disposed Cases',
  'Case Reference',
  'Notes',
];

/// Labels of the picker rows currently on screen, in render order.
List<String> dropdownLabels(WidgetTester tester) => tester
    .widgetList<SettingsOptionRow>(find.byType(SettingsOptionRow))
    .map((row) => row.label)
    .toList();

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
    // Card labels, Title Case via the shared section label.
    expect(find.text('Display'), findsOneWidget);
    expect(find.text('Navigation'), findsOneWidget);
    // Every dropdown is titled above the control, in Title Case.
    expect(find.text('Upcoming Cases Period'), findsWidgets);
    expect(find.text('Case List Display'), findsWidgets);
    expect(find.text('Bottom Navigation'), findsWidgets);
    expect(find.text('Side Navigation Options'), findsWidgets);
    // Collapsed values: plan §10.1 defaults, all Title Case.
    expect(find.text('7 Days'), findsOneWidget);
    expect(find.text('Compact'), findsOneWidget);
    expect(find.text('4 Screens Selected'), findsOneWidget);
    expect(find.text('8 of 8 Sections Shown'), findsOneWidget);
    // The list settings are no longer rendered inline on the page.
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    // Default Landing Page sits in a card of its own, below Navigation.
    await scrollTo(tester, find.text('Default Landing Page'));
    expect(find.text('Default Landing Page'), findsWidgets);
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

    // Every screen is listed in the canonical serial whatever is chosen, each
    // a check-mark row with no per-screen icon of its own.
    expect(
      find.byType(SettingsOptionRow),
      findsNWidgets(canonicalScreens.length),
    );
    expect(dropdownLabels(tester), canonicalScreens);
    expect(find.byIcon(Icons.error_outline), findsNothing);
    // The four defaults are ticked, the four extras are not.
    expect(find.byIcon(Icons.check_circle), findsNWidgets(4));
  });

  testWidgets(
    'side-navigation options list the canonical screens, not Settings',
    (tester) async {
      await pumpScreen(tester);
      await openDropdown(tester, '8 of 8 Sections Shown');

      expect(
        find.byType(SettingsOptionRow),
        findsNWidgets(canonicalScreens.length),
      );
      expect(dropdownLabels(tester), canonicalScreens);
      expect(find.text('Settings'), findsNothing);
      // Every section is visible, so every row is ticked.
      expect(
        find.byIcon(Icons.check_circle),
        findsNWidgets(canonicalScreens.length),
      );
    },
  );

  testWidgets('every dropdown title stays on a single line', (tester) async {
    // A narrow phone: the widest title (Side Navigation Options) has the least
    // room here, so a wrapping title would show up first in this case.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpScreen(tester);
    // `titleLg` is 20/28, so one line is exactly 28 px high.
    const oneLine = 28.0;

    for (final rowText in <String>[
      '7 Days',
      'Compact',
      '4 Screens Selected',
      '8 of 8 Sections Shown',
    ]) {
      await tester.tap(find.widgetWithText(SettingsPickerRow, rowText));
      await tester.pumpAndSettle();

      final title = tester
          .widget<Text>(
            find.descendant(
              of: find.byType(SettingsPickerDialogHeader),
              matching: find.byType(Text),
            ),
          )
          .data!;
      // The painted rect, so a title scaled down to fit is measured as drawn.
      // Scoped to the header: the section label behind it now shares the words.
      final titleRect = tester.getRect(
        find.descendant(
          of: find.byType(SettingsPickerDialogHeader),
          matching: find.text(title),
        ),
      );
      final content = tester
          .getRect(find.byType(SettingsPickerDialogHeader))
          .deflate(AppSpacing.md);

      expect(
        titleRect.height,
        lessThanOrEqualTo(oneLine + 0.5),
        reason: '"$title" wrapped onto a second line',
      );
      // It must also draw fully inside the bar, centred rather than clipped.
      expect(
        titleRect.left,
        greaterThanOrEqualTo(content.left - 0.5),
        reason: '"$title" overflows the header',
      );
      expect(
        titleRect.right,
        lessThanOrEqualTo(content.right + 0.5),
        reason: '"$title" overflows the header',
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    }
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

    // The rows hold the canonical serial — All Cases, Active Cases, Daily Cause
    // List — so drag Daily Cause List (row 2) above Active Cases (row 1).
    // `timedDrag` pumps frames between moves, which the reorder needs to track
    // the proxy.
    await tester.timedDrag(
      find.byIcon(Icons.drag_indicator).at(2),
      const Offset(0, -60),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();

    expect(repo.settings.bottomNavTabs, <String>[
      'daily_cause_list',
      'active',
      'overdue',
      'upcoming',
    ]);
  });

  testWidgets('a dragged order is still the order next time it opens', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openDropdown(tester, '4 Screens Selected');

    // Drag Daily Cause List (row 2) above Active Cases (row 1), as above.
    await tester.timedDrag(
      find.byIcon(Icons.drag_indicator).at(2),
      const Offset(0, -60),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();

    const dragged = <String>[
      'All Cases',
      'Daily Cause List',
      'Active Cases',
      'Overdue Dates',
      'Upcoming Cases',
      'Disposed Cases',
      'Case Reference',
      'Notes',
    ];
    expect(dropdownLabels(tester), dragged);
    // The whole serial is saved, ticked rows and unticked ones alike.
    expect(repo.settings.bottomNavOrder, <String>[
      'all_cases',
      'daily_cause_list',
      'active',
      'overdue',
      'upcoming',
      'disposed',
      'case_reference',
      'notes',
    ]);

    // Reopening shows that serial — the old build re-seeded the canonical one.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await openDropdown(tester, '4 Screens Selected');
    expect(dropdownLabels(tester), dragged);
  });

  testWidgets('a screen added by a later release is still listed', (
    tester,
  ) async {
    // A serial saved before "Notes" existed: the unknown-to-it screen must
    // still be offered, in its canonical place at the end.
    repo = FakeSettingsRepository(
      const UserSettings(
        bottomNavOrder: <String>[
          'active',
          'all_cases',
          'upcoming',
          'overdue',
          'disposed',
          'daily_cause_list',
          'case_reference',
        ],
      ),
    );
    await pumpScreen(tester);
    await openDropdown(tester, '4 Screens Selected');

    expect(dropdownLabels(tester), <String>[
      'Active Cases',
      'All Cases',
      'Upcoming Cases',
      'Overdue Dates',
      'Disposed Cases',
      'Daily Cause List',
      'Case Reference',
      'Notes',
    ]);
  });

  testWidgets('choosing a screen never moves it in the list', (tester) async {
    await pumpScreen(tester);
    await openDropdown(tester, '4 Screens Selected');
    expect(dropdownLabels(tester), canonicalScreens);

    // Tick an extra screen and untick a chosen one: the serial holds, so the
    // user's own drag is the only thing that can rearrange the rows.
    await tester.tap(find.widgetWithText(SettingsOptionRow, 'All Cases'));
    await tester.pumpAndSettle();
    expect(dropdownLabels(tester), canonicalScreens);
    await tester.tap(find.widgetWithText(SettingsOptionRow, 'Overdue Dates'));
    await tester.pumpAndSettle();
    expect(dropdownLabels(tester), canonicalScreens);

    // …and it still holds the next time the dropdown is opened.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await openDropdown(tester, '4 Screens Selected');
    expect(dropdownLabels(tester), canonicalScreens);
  });

  testWidgets('hiding a section never moves it in the list', (tester) async {
    await pumpScreen(tester);
    await openDropdown(tester, '8 of 8 Sections Shown');
    expect(dropdownLabels(tester), canonicalScreens);

    await tester.tap(find.widgetWithText(SettingsOptionRow, 'Case Reference'));
    await tester.pumpAndSettle();
    expect(dropdownLabels(tester), canonicalScreens);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await openDropdown(tester, '7 of 8 Sections Shown');
    expect(dropdownLabels(tester), canonicalScreens);
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
    await openDropdown(tester, '8 of 8 Sections Shown');

    await tester.tap(find.widgetWithText(SettingsOptionRow, 'Disposed Cases'));
    await tester.pumpAndSettle();

    expect(repo.settings.sideNavOptions[AppRoutes.disposedCases], isFalse);
    // The whole map is written, so the untouched sections stay explicitly on.
    expect(repo.settings.sideNavOptions[AppRoutes.notes], isTrue);
    expect(repo.settings.sideNavOptions[AppRoutes.activeCases], isTrue);
    // Settings is not removable, so the map must not carry its key at all —
    // a stale `false` from an older build would hide the way back here.
    expect(
      repo.settings.sideNavOptions.containsKey(AppRoutes.settings),
      isFalse,
    );
    expect(repo.settings.sideNavOptions, hasLength(canonicalScreens.length));
    expect(find.text('7 of 8 Sections Shown'), findsOneWidget);
  });

  testWidgets('the saved options drive the drawer, which keeps Settings', (
    tester,
  ) async {
    repo = FakeSettingsRepository(
      const UserSettings(
        sideNavOptions: <String, dynamic>{
          AppRoutes.disposedCases: false,
          AppRoutes.settings: false, // Stale key from an older build.
        },
      ),
    );
    // The drawer header reads the saved profile picture and name.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    await pumpSettingsScreen(
      tester,
      Scaffold(
        drawer: AppNavigationDrawer(
          currentRoute: AppRoutes.allCases,
          sideNavOptions: repo.settings.sideNavOptions,
        ),
        body: const SizedBox.shrink(),
      ),
      repo: repo,
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await tester.pumpAndSettle();

    final drawer = find.byType(Drawer);
    for (final label in <String>[
      'All Cases',
      'Active Cases',
      'Daily Cause List',
      'Overdue Dates',
      'Upcoming Cases',
      'Case Reference',
      'Notes',
      'Settings',
    ]) {
      expect(
        find.descendant(of: drawer, matching: find.text(label)),
        findsOneWidget,
        reason: '$label missing from the drawer',
      );
    }
    expect(
      find.descendant(of: drawer, matching: find.text('Disposed Cases')),
      findsNothing,
    );
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

    // A larger selection renders every tab and scrolls instead of squeezing —
    // including Case Reference and Notes, which the dropdown now offers too.
    await pumpBar(const <String>[
      'overdue',
      'daily_cause_list',
      'active',
      'upcoming',
      'all_cases',
      'disposed',
      'case_reference',
      'notes',
    ]);
    expect(find.byType(InkWell), findsNWidgets(8));
    expect(find.text('All Cases'), findsOneWidget);
    expect(find.text('Disposed Cases'), findsOneWidget);
    expect(find.text('Case Reference'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
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
