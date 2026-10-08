/// Tests for the app-wide font size step (Settings > View Settings > Font).
///
/// Covers the additive scaler itself, the scope that applies it, the shipped
/// default that sits under the user's own step, the bottom bar's opt-out from
/// that default, and the one piece of wiring no widget test can reach: the app
/// root hands the saved step to [FontSizeScope], so the setting is inside the
/// app shell rather than buried in a screen.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/constants/app_typography.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/core/theme/font_size_scope.dart';
import 'package:legal_case_diary/features/settings/data/settings_repository.dart';
import 'package:legal_case_diary/shared/widgets/bottom_nav_bar.dart';

/// The text every layout check measures.
const String _sample = 'Hearing on 12 August';

void main() {
  group('SteppedTextScaler', () {
    test('adds the step to every size, whatever the size', () {
      const scaler = SteppedTextScaler(TextScaler.noScaling, 2);

      expect(scaler.scale(12), 14);
      expect(scaler.scale(16), 18);
      expect(scaler.scale(30), 32);
      // A negative step shrinks the same way.
      expect(const SteppedTextScaler(TextScaler.noScaling, -2).scale(16), 14);
    });

    test('adds the step to the base scaler it is given', () {
      // The class is a plain wrapper; the app hands it no-scaling as the base,
      // but the maths works over any base scaler.
      const scaler = SteppedTextScaler(TextScaler.linear(1.5), 1);

      expect(scaler.scale(16), 25);
    });

    test('compares by inner scaler and step', () {
      expect(
        const SteppedTextScaler(TextScaler.noScaling, 1),
        const SteppedTextScaler(TextScaler.noScaling, 1),
      );
      expect(
        const SteppedTextScaler(TextScaler.noScaling, 1),
        isNot(const SteppedTextScaler(TextScaler.noScaling, 2)),
      );
      expect(
        const SteppedTextScaler(TextScaler.noScaling, 1).hashCode,
        const SteppedTextScaler(TextScaler.noScaling, 1).hashCode,
      );
    });

    test('reports the deprecated ratio against the app body size', () {
      // ignore: deprecated_member_use_from_same_package
      expect(
        const SteppedTextScaler(TextScaler.noScaling, 4).textScaleFactor,
        (AppTypography.bodyLg.fontSize! + 4) / AppTypography.bodyLg.fontSize!,
      );
    });
  });

  group('FontSizeScope', () {
    // Centred so the text reports its own size rather than the full width.
    Widget app({required int step}) => MaterialApp(
      home: Center(
        child: FontSizeScope(
          step: step,
          child: Text(_sample, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );

    testWidgets('at the default step the app paints the shipped size', (
      tester,
    ) async {
      // The default moved one pixel above the design size (defaultFontSizeStep),
      // so `Default` in the stepper is what `+1` used to render.
      await tester.pumpWidget(app(step: 0));

      final scaler = MediaQuery.textScalerOf(tester.element(find.byType(Text)));
      expect(scaler.scale(16), 16 + defaultFontSizeStep);
    });

    testWidgets('the default and the user step are one additive pair', (
      tester,
    ) async {
      Future<void> scaleOf(int step) async {
        await tester.pumpWidget(app(step: step));
        final scaler = MediaQuery.textScalerOf(
          tester.element(find.byType(Text)),
        );
        expect(scaler.scale(16), 16 + defaultFontSizeStep + step);
      }

      await scaleOf(-2);
      await scaleOf(0);
      await scaleOf(6);
    });

    testWidgets('a step scales the text that is actually painted', (
      tester,
    ) async {
      await tester.pumpWidget(app(step: 0));
      final atDefault = tester.getSize(find.text(_sample));

      await tester.pumpWidget(app(step: 3));
      final stepped = tester.getSize(find.text(_sample));
      expect(stepped.width, greaterThan(atDefault.width));
      expect(stepped.height, greaterThan(atDefault.height));

      await tester.pumpWidget(app(step: -2));
      final reduced = tester.getSize(find.text(_sample));
      expect(reduced.width, lessThan(atDefault.width));
    });

    testWidgets('the device\'s own scale is dropped', (tester) async {
      // The phone asks for 2x; the app ignores it entirely. A zero step gives
      // the shipped default, and a step adds to that — never the doubled
      // platform value.
      Future<void> pump(int step) => tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: FontSizeScope(
              step: step,
              child: Text(_sample, style: const TextStyle(fontSize: 16)),
            ),
          ),
        ),
      );

      await pump(0);
      var scaler = MediaQuery.textScalerOf(tester.element(find.byType(Text)));
      expect(scaler.scale(16), 16 + defaultFontSizeStep);

      await pump(2);
      scaler = MediaQuery.textScalerOf(tester.element(find.byType(Text)));
      expect(scaler.scale(16), 16 + defaultFontSizeStep + 2);
    });
  });

  group('the bottom bar opts out of the default', () {
    // The bar sits under the same scope as everything else; what is measured is
    // the scale its labels are painted with, read off the widget itself.
    Widget app({required int step}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: FontSizeScope(
        step: step,
        child: Scaffold(
          bottomNavigationBar: BottomNavBar(
            currentRoute: AppRoutes.notes,
            tabKeys: const <String>['overdue', 'active'],
            onTabSelected: (_) {},
          ),
          body: const Text(_sample, style: TextStyle(fontSize: 12)),
        ),
      ),
    );

    double scaleAt(WidgetTester tester, String text) => MediaQuery.textScalerOf(
      tester.element(find.text(text)),
    ).scale(12);

    testWidgets('at the default the bar is where it always was', (
      tester,
    ) async {
      await tester.pumpWidget(app(step: 0));

      // The screen grew by the shipped default…
      expect(
        scaleAt(tester, _sample),
        12 + defaultFontSizeStep,
        reason: 'every other surface follows the new default',
      );
      // …and the bar did not: its pixel was taken straight back out.
      expect(scaleAt(tester, 'Overdue Dates'), 12);
    });

    testWidgets('the user step still reaches the bar', (tester) async {
      await tester.pumpWidget(app(step: 3));

      expect(scaleAt(tester, _sample), 12 + defaultFontSizeStep + 3);
      // One pixel below the rest, at every step — not one pixel below the
      // design size wherever the default happens to sit.
      expect(scaleAt(tester, 'Overdue Dates'), 12 + 3);
    });
  });

  group('the app ships the step app-wide', () {
    test('the root wraps the app in FontSizeScope with the saved step', () {
      final source = File('lib/app.dart').readAsStringSync();

      expect(source, contains('FontSizeScope('));
      expect(source, contains('step: fontSizeStep'));
      expect(source, contains('fontSizeStep'));
    });

    test('the stored step is clamped on read', () {
      expect(clampFontSizeStep(fontSizeStepMax + 40), fontSizeStepMax);
      expect(clampFontSizeStep(fontSizeStepMin - 40), fontSizeStepMin);
      expect(clampFontSizeStep(2), 2);
      expect(const UserSettings().fontSizeStep, 0);
    });
  });
}
