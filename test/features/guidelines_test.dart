/// Tests for the Guidelines & FAQs screen.
///
/// Two sections of accordion cards mirroring
/// `mockup_html_screens/guidelines/code.html`: every card starts collapsed,
/// opening one closes the other, and tapping the open card collapses it. The
/// copy lives in the ARB files, so one test pins the Bengali rendering and one
/// guards the copy against the placeholder claims the screen used to carry.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_about/guidelines_screen.dart';

import 'settings_test_support.dart';

void main() {
  /// The screen is a long scroll, so the surface is made tall enough for every
  /// card to build — otherwise the lazy list never creates the lower cards and
  /// the assertions below would pass for the wrong reason.
  Future<void> pump(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(1000, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpSettingsScreen(
      tester,
      const GuidelinesScreen(),
      repo: FakeSettingsRepository(),
      locale: locale,
    );
  }

  testWidgets('shows both sections with every card collapsed', (tester) async {
    await pump(tester);

    expect(find.text('Guidelines & FAQs'), findsOneWidget);
    expect(find.text('GUIDELINES'), findsOneWidget);
    expect(find.text('FAQS'), findsOneWidget);

    // The four guideline topics.
    expect(find.text('Daily Cause List'), findsOneWidget);
    expect(find.text('Case References & Notes'), findsOneWidget);
    expect(find.text('Offline Backup & Restore'), findsOneWidget);
    expect(find.text('Security & Encryption'), findsOneWidget);

    // The FAQ groups.
    expect(find.text('Getting started'), findsOneWidget);
    expect(find.text('Finding and viewing cases'), findsOneWidget);
    expect(find.text('Notes, references and printing'), findsOneWidget);
    expect(find.text('Backup and restore'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Language and display'), findsOneWidget);
    expect(find.text('Free plan and premium'), findsOneWidget);
    expect(find.text('Courts and customisation'), findsOneWidget);
    expect(find.text('Data, privacy and support'), findsOneWidget);

    // Nothing is open, so no body copy and no rotated chevron.
    expect(find.textContaining('grouped by court'), findsNothing);
    expect(find.textContaining('AES-256-GCM'), findsNothing);
    expect(find.textContaining('passphrase is never stored'), findsNothing);
    expect(_openChevrons(), findsNothing);
  });

  testWidgets('opens one guideline topic at a time', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Daily Cause List'));
    await tester.pumpAndSettle();
    expect(find.textContaining('grouped by court in your court hierarchy'), findsOne);
    expect(find.textContaining('Overdue Dates'), findsOneWidget);
    expect(_openChevrons(), findsOneWidget);

    // Opening a second topic closes the first.
    await tester.tap(find.text('Security & Encryption'));
    await tester.pumpAndSettle();
    expect(find.textContaining('AES-256-GCM'), findsOneWidget);
    expect(find.textContaining('grouped by court in your court hierarchy'), findsNothing);

    // Tapping the open topic collapses it again.
    await tester.tap(find.text('Security & Encryption'));
    await tester.pumpAndSettle();
    expect(find.textContaining('AES-256-GCM'), findsNothing);
    expect(_openChevrons(), findsNothing);
  });

  testWidgets('opens an FAQ group and lists its questions with answers', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('Backup and restore'));
    await tester.pumpAndSettle();

    expect(
      find.text('I forgot my passphrase. Can you recover it?'),
      findsOneWidget,
    );
    expect(
      find.textContaining('The passphrase is never stored'),
      findsOneWidget,
    );
    expect(find.text('How do I move my diary to a new phone?'), findsOneWidget);

    // The two sections share one open card, so a guideline closes the FAQ.
    await tester.tap(find.text('Offline Backup & Restore'));
    await tester.pumpAndSettle();
    expect(
      find.text('I forgot my passphrase. Can you recover it?'),
      findsNothing,
    );
    expect(find.textContaining('make a fresh backup before restoring'), findsOne);
  });

  testWidgets('renders the Bengali copy under Locale(bn)', (tester) async {
    await pump(tester, locale: const Locale('bn'));
    final l = await AppLocalizations.delegate.load(const Locale('bn'));

    expect(find.text(l.settingsGuidelines_title), findsOneWidget);
    expect(find.text(l.settingsGuidelines_intro), findsOneWidget);
    expect(find.text(l.settingsGuidelines_dailyCauseListTitle), findsOneWidget);
    expect(
      find.text(l.settingsGuidelines_faqCatBackupAndRestore),
      findsOneWidget,
    );

    await tester.tap(find.text(l.settingsGuidelines_dailyCauseListTitle));
    await tester.pumpAndSettle();
    expect(find.text(l.settingsGuidelines_dailyCauseListBody1), findsOneWidget);
    expect(find.text(l.settingsGuidelines_dailyCauseListBody2), findsOneWidget);
  });

  group('the copy describes only shipped behaviour', () {
    final forbiddenEn = <String>[
      'Justice Ledger',
      'every 24 hours',
      'biometric',
      'sync icon',
      'Backup Options',
      'end-to-end',
    ];
    final forbiddenBn = <String>[
      'জাস্টিস লেজার',
      '২৪ ঘণ্টায়',
      'বায়োমেট্রিক',
      'সিঙ্ক আইকনে',
      'ব্যাকআপ অপশনে',
      'এন্ড-টু-এন্ড',
    ];

    for (final path in const [
      'lib/core/l10n/app_en.arb',
      'lib/core/l10n/app_bn.arb',
    ]) {
      test('$path carries no placeholder feature claims', () {
        final arb =
            json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;
        final guidelines = arb.entries.where(
          (entry) => entry.key.startsWith('settingsGuidelines'),
        );
        expect(guidelines, isNotEmpty);
        for (final entry in guidelines) {
          final value = entry.value as String;
          for (final phrase in [...forbiddenEn, ...forbiddenBn]) {
            expect(
              value.toLowerCase().contains(phrase.toLowerCase()),
              isFalse,
              reason: '${entry.key} mentions "$phrase"',
            );
          }
        }
      });
    }
  });
}

/// The chevron of the currently open card, which is rotated half a turn.
Finder _openChevrons() => find.byWidgetPredicate(
  (widget) => widget is AnimatedRotation && widget.turns == 0.5,
);
