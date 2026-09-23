import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/shared/widgets/month_year_picker.dart';

void main() {
  /// Opens the shared Month | Year selector on its own, focused on August 2026 —
  /// the month the date-picker tests use.
  Future<void> openColumns(
    WidgetTester tester, {
    void Function(int month, int year)? onPicked,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MonthYearPickerColumns(
            firstYear: 1900,
            lastYear: 2100,
            month: 8,
            year: 2026,
            onPicked: onPicked ?? (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The scroll view behind one column.
  ListWheelScrollView columnOf(WidgetTester tester, Key key) =>
      tester.widget<ListWheelScrollView>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(ListWheelScrollView),
        ),
      );

  testWidgets('the rows are a straight list: one row extent apart, unbent', (
    WidgetTester tester,
  ) async {
    await openColumns(tester);

    // On the iOS wheel these were, the rows either side of the middle were
    // squeezed to about 39 px and tilted by some 19 degrees. A straight list
    // spaces them at exactly the row extent and leaves them upright.
    final middle = tester.getCenter(find.text('2026')).dy;
    final above = tester.getCenter(find.text('2025')).dy;
    final aboveTwo = tester.getCenter(find.text('2024')).dy;
    expect(middle - above, closeTo(monthYearPickerRowExtent, 0.5));
    expect(above - aboveTwo, closeTo(monthYearPickerRowExtent, 0.5));

    // Nothing is rotated about the middle either: a row's painted box is its own
    // box, not the wider box a tilted (or magnified) row would paint.
    final painted = tester.getRect(find.text('2024'));
    final laidOut = tester.getSize(find.text('2024'));
    expect(painted.height, closeTo(laidOut.height, 1.0));
    expect(painted.width, closeTo(laidOut.width, 1.0));
  });

  testWidgets('no row is magnified, dimmed or bent, and the list still snaps', (
    WidgetTester tester,
  ) async {
    await openColumns(tester);

    final columns = tester
        .widgetList<ListWheelScrollView>(find.byType(ListWheelScrollView))
        .toList();
    expect(columns, hasLength(2));
    for (final column in columns) {
      expect(column.itemExtent, monthYearPickerRowExtent);
      expect(column.useMagnifier, isFalse);
      expect(column.magnification, 1);
      expect(column.overAndUnderCenterOpacity, 1);
      expect(column.squeeze, 1);
      // A cylinder far wider than the column: what is left of the wheel is the
      // one-row-at-a-time snapping.
      expect(column.diameterRatio, greaterThanOrEqualTo(50));
      expect(column.physics, isA<FixedExtentScrollPhysics>());
    }
  });

  testWidgets('the current row is bigger and bold; every row is app text black', (
    WidgetTester tester,
  ) async {
    await openColumns(tester);

    Text row(String label) => tester.widget<Text>(
      find.descendant(
        of: find.byType(ListWheelScrollView),
        matching: find.text(label),
      ),
    );

    // The current value is told apart by size and weight: one type step up from
    // the rows around it, and bold.
    expect(row('August').style?.fontWeight, FontWeight.bold);
    expect(row('September').style?.fontWeight, FontWeight.normal);
    expect(
      row('August').style?.fontSize,
      greaterThan(row('September').style!.fontSize!),
    );
    expect(
      row('September').style?.fontSize,
      row('July').style?.fontSize,
    );

    // Row colours are the app's own text black, at full strength — the fade that
    // made the iOS wheel's neighbours look grey is gone.
    for (final label in ['July', 'August', 'September', '2026']) {
      expect(row(label).style?.color, AppColors.onSurface, reason: label);
    }
  });

  testWidgets('Month centres in its half; Year sits a seam gap past the seam', (
    WidgetTester tester,
  ) async {
    await openColumns(tester);

    // The picker's own middle is the seam the two columns meet on. The Month
    // column centres its labels in its half, so no month name can change where
    // the pair sits, and the Year column starts one seam gap into the other.
    final picker = tester.getRect(find.byType(MonthYearPickerColumns));
    expect(
      tester.getRect(find.text('August')).center.dx,
      closeTo(picker.left + picker.width / 4, 1),
    );
    expect(
      tester.getRect(find.text('2026')).left - picker.center.dx,
      closeTo(monthYearPickerSeamGap, 1),
    );
  });

  testWidgets('a light platform click plays as each row passes the middle', (
    WidgetTester tester,
  ) async {
    final sounds = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemSound.play') {
            sounds.add(call.arguments as String);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await openColumns(tester);
    expect(sounds, isEmpty, reason: 'opening the picker makes no sound');

    // One row past the middle, one click — the platform sound, so the phone's
    // own touch-sound setting decides whether it is heard.
    final yearController =
        columnOf(tester, monthYearPickerYearColumnKey).controller
            as FixedExtentScrollController;
    yearController.jumpToItem(2027 - 1900);
    await tester.pumpAndSettle();

    expect(sounds, [SystemSoundType.click.toString()]);
  });

  testWidgets('tapping a row confirms both columns as they stand', (
    WidgetTester tester,
  ) async {
    int? pickedMonth;
    int? pickedYear;
    await openColumns(
      tester,
      onPicked: (month, year) {
        pickedMonth = month;
        pickedYear = year;
      },
    );

    // Spin the year column to 2100 without touching the month column, then tap a
    // month: the calendar must receive the month tapped and the year the column
    // is holding.
    final yearController =
        columnOf(tester, monthYearPickerYearColumnKey).controller
            as FixedExtentScrollController;
    yearController.jumpToItem(2100 - 1900);
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(monthYearPickerMonthColumnKey),
        matching: find.text('September'),
      ),
    );
    await tester.pumpAndSettle();

    expect(pickedMonth, 9);
    expect(pickedYear, 2100);
  });
}
