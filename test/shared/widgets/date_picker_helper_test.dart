import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/shared/widgets/date_picker_helper.dart';

void main() {
  final selectedDate = DateTime(2026, 8, 5);

  Future<void> openPicker(WidgetTester tester, Locale locale) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showPlainDatePicker(
                context,
                initialDate: selectedDate,
                styleActions: true,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('uses the exact abbreviated English header labels', (
    WidgetTester tester,
  ) async {
    await openPicker(tester, const Locale('en'));

    expect(find.text('Aug 5, Wed'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('plain-date-picker-surface')))
          .width,
      460,
    );
    expect(
      tester.getSize(find.widgetWithText(TextButton, 'Cancel')).width,
      132,
    );
    expect(tester.getSize(find.widgetWithText(TextButton, 'OK')).width, 132);
    final dialog = tester.getRect(
      find.byKey(const ValueKey('plain-date-picker-surface')),
    );
    final cancel = tester.getRect(find.widgetWithText(TextButton, 'Cancel'));
    final ok = tester.getRect(find.widgetWithText(TextButton, 'OK'));
    expect((cancel.center.dx + ok.center.dx) / 2, closeTo(dialog.center.dx, 1));
    expect(dialog.bottom - ok.bottom, greaterThanOrEqualTo(16));
  });

  testWidgets('uses the exact abbreviated Bengali header labels', (
    WidgetTester tester,
  ) async {
    await openPicker(tester, const Locale('bn'));

    expect(find.text('আগস্ট ৫, বুধ'), findsOneWidget);

    final dialog = tester.getRect(
      find.byKey(const ValueKey('plain-date-picker-surface')),
    );
    final button = tester.getRect(find.byType(TextButton).first);
    expect(dialog.bottom - button.bottom, greaterThanOrEqualTo(16));
  });

  testWidgets('matches DCL calendar layout: month/year selectors + 7-col weekday body',
      (WidgetTester tester) async {
    await openPicker(tester, const Locale('en'));

    // Month/year header with chevron navigation (matches Daily Cause List).
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.text('August'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);

    // Cancel/OK buttons preserved.
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'OK'), findsOneWidget);
  });

  testWidgets('tapping a day cell selects it and returns the date on OK',
      (WidgetTester tester) async {
    final picked = Completer<DateTime?>();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async =>
                  picked.complete(await showPlainDatePicker(
                context,
                initialDate: selectedDate,
                styleActions: true,
              )),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Tap day 10 (enabled in 2026-08), then confirm via OK.
    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'OK'));

    final result = await picked.future;
    expect(result, isNotNull);
    expect(result!.year, 2026);
    expect(result.month, 8);
    expect(result.day, 10);
  });

  testWidgets('Cancel returns null', (WidgetTester tester) async {
    await openPicker(tester, const Locale('en'));
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Aug 5, Wed'), findsNothing);
  });
}
