/// Tests for the Guidelines screen (Task 12 Phase 4).
///
/// The screen is a four-card accordion mirroring
/// `mockup_html_screens/guidelines/code.html`: all topics start collapsed,
/// opening one closes the other, and tapping the open one collapses it. The
/// copy lives in the ARB files, so one test pins the Bengali rendering.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_about/guidelines_screen.dart';

import 'settings_test_support.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) => pumpSettingsScreen(
    tester,
    const GuidelinesScreen(),
    repo: FakeSettingsRepository(),
    locale: locale,
  );

  testWidgets('shows the intro and four collapsed topics', (tester) async {
    await pump(tester);

    expect(find.text('Guidelines'), findsOneWidget);
    expect(
      find.text(
        'Tap on any topic below to expand and view detailed administrative '
        'procedures.',
      ),
      findsOneWidget,
    );
    expect(find.text('Daily Cause List Management'), findsOneWidget);
    expect(find.text('Managing Case References'), findsOneWidget);
    expect(find.text('Offline Backup & Restore'), findsOneWidget);
    expect(find.text('Security & Encryption'), findsOneWidget);

    // Every topic starts collapsed, so no body copy and no rotated chevron.
    expect(find.textContaining("court's official cause list"), findsNothing);
    expect(find.textContaining('AES-256'), findsNothing);
    expect(_openChevrons(), findsNothing);
  });

  testWidgets('opens one topic at a time and collapses on a second tap', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('Daily Cause List Management'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sync icon in the top right corner'), findsOne);
    expect(find.textContaining('marked for active monitoring'), findsOneWidget);
    expect(_openChevrons(), findsOneWidget);

    // Opening a second topic closes the first (mockup behaviour).
    await tester.tap(find.text('Security & Encryption'));
    await tester.pumpAndSettle();
    expect(find.textContaining('AES-256'), findsOneWidget);
    expect(find.textContaining('marked for active monitoring'), findsNothing);
    expect(_openChevrons(), findsOneWidget);

    // Tapping the open topic collapses it again.
    await tester.tap(find.text('Security & Encryption'));
    await tester.pumpAndSettle();
    expect(find.textContaining('AES-256'), findsNothing);
    expect(_openChevrons(), findsNothing);
  });

  testWidgets('renders the Bengali copy under Locale(bn)', (tester) async {
    await pump(tester, locale: const Locale('bn'));
    final l = await AppLocalizations.delegate.load(const Locale('bn'));

    expect(find.text(l.settingsGuidelines_title), findsOneWidget);
    expect(find.text(l.settingsGuidelines_intro), findsOneWidget);
    expect(find.text(l.settingsGuidelines_dailyCauseListTitle), findsOneWidget);

    await tester.tap(find.text(l.settingsGuidelines_dailyCauseListTitle));
    await tester.pumpAndSettle();
    expect(find.text(l.settingsGuidelines_dailyCauseListBody1), findsOneWidget);
    expect(find.text(l.settingsGuidelines_dailyCauseListBody2), findsOneWidget);
  });
}

/// The chevron of the currently open topic, which is rotated half a turn.
Finder _openChevrons() => find.byWidgetPredicate(
  (widget) => widget is AnimatedRotation && widget.turns == 0.5,
);
