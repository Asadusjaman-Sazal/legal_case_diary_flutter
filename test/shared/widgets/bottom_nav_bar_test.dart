/// The app's bottom bar clears the phone's navigation panel itself.
///
/// Android 15 onward draws the app behind the system bars, so the bar takes the
/// bottom inset into its own surface. Phones that still inset the app window
/// report 0 and keep the bar at its design height.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/shared/widgets/bottom_nav_bar.dart';

void main() {
  setUp(resetBottomNavScrollOffset);

  Widget app({required double viewPaddingBottom, double paddingBottom = 0}) =>
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              viewPadding: EdgeInsets.only(bottom: viewPaddingBottom),
              padding: EdgeInsets.only(bottom: paddingBottom),
            ),
            child: Scaffold(
              body: const SizedBox.shrink(),
              bottomNavigationBar: BottomNavBar(
                currentRoute: AppRoutes.notes,
                tabKeys: const <String>['overdue', 'active'],
                onTabSelected: (_) {},
              ),
            ),
          ),
        ),
      );

  testWidgets('adds the system navigation inset below its own row', (
    tester,
  ) async {
    await tester.pumpWidget(app(viewPaddingBottom: 48, paddingBottom: 48));

    // The bar's surface grows by the panel's height; its row keeps its 64 px.
    expect(tester.getSize(find.byType(BottomNavBar)).height, 64 + 48);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('keeps the design height where the window is already inset', (
    tester,
  ) async {
    await tester.pumpWidget(app(viewPaddingBottom: 0));

    expect(tester.getSize(find.byType(BottomNavBar)).height, 64);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('holds the inset while the temporary padding is zero', (
    tester,
  ) async {
    // A keyboard zeros `padding` while its own inset is applied; the panel's
    // strip must not collapse with it.
    await tester.pumpWidget(app(viewPaddingBottom: 48));

    expect(tester.getSize(find.byType(BottomNavBar)).height, 64 + 48);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('keeps its scroll position when the next screen mounts a bar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Widget phoneApp() => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: const SizedBox.shrink(),
        bottomNavigationBar: BottomNavBar(
          currentRoute: AppRoutes.notes,
          tabKeys: const <String>[
            'all_cases',
            'active',
            'daily_cause_list',
            'overdue',
            'upcoming',
            'disposed',
          ],
          onTabSelected: (_) {},
        ),
      ),
    );

    await tester.pumpWidget(phoneApp());
    final bar = find.byType(SingleChildScrollView);
    // More tabs than the phone shows: the bar scrolls horizontally.
    await tester.drag(bar, const Offset(-160, 0));
    await tester.pump();
    final left = tester.widget<SingleChildScrollView>(bar).controller!.offset;
    expect(left, greaterThan(0));

    // A tab tap mounts the next screen's own bar — a new widget and state.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(phoneApp());
    await tester.pump();

    expect(
      tester
          .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .controller!
          .offset,
      left,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
