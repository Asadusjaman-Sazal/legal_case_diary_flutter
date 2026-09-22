/// Tests for the app-wide font size step (Settings > View Settings > Font).
///
/// Covers the additive scaler itself, the scope that applies it, and the one
/// piece of wiring no widget test can reach: the app root hands the saved step
/// to [FontSizeScope], so the setting is inside the app shell rather than
/// buried in a screen.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/constants/app_typography.dart';
import 'package:legal_case_diary/core/theme/font_size_scope.dart';
import 'package:legal_case_diary/features/settings/data/settings_repository.dart';

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

    test('wraps the inherited scaler instead of replacing it', () {
      // The device asks for 1.5x; the step still adds its own pixels on top, so
      // the platform accessibility setting is never overridden.
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

    testWidgets('at the default step the tree is untouched', (tester) async {
      await tester.pumpWidget(app(step: 0));

      final scaler = MediaQuery.textScalerOf(tester.element(find.byType(Text)));
      expect(scaler, isNot(isA<SteppedTextScaler>()));
      expect(scaler.scale(16), 16);
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

    testWidgets('the inherited scale is kept', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: FontSizeScope(
              step: 2,
              child: Text(_sample, style: const TextStyle(fontSize: 16)),
            ),
          ),
        ),
      );

      final scaler = MediaQuery.textScalerOf(tester.element(find.byType(Text)));
      expect(scaler.scale(16), 34);
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
