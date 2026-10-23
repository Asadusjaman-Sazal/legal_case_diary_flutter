import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:intl/intl.dart' as intl;
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/utils/date_utils.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_sub_page_modal.dart';
import 'package:legal_case_diary/shared/widgets/calendar_picker_dialog.dart';
import 'package:legal_case_diary/shared/widgets/month_year_picker.dart';

void main() {
  group('SettingsSubPageModal', () {
    testWidgets('renders title, body, actions, and invokes back callback', (
      WidgetTester tester,
    ) async {
      var backPressed = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [premiumAccessProvider.overrideWith((ref) async => false)],
          child: MaterialApp(
            home: SettingsSubPageModal(
              title: 'View Settings',
              onBack: () => backPressed = true,
              actions: const [Icon(Icons.more_vert)],
              child: const Text('Settings content'),
            ),
          ),
        ),
      );

      expect(find.text('View Settings'), findsOneWidget);
      expect(find.text('Settings content'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      expect(backPressed, isTrue);
    });

    testWidgets('default back action pops the current route', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [premiumAccessProvider.overrideWith((ref) async => false)],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsSubPageModal(
                        title: 'Profile',
                        child: Text('Profile content'),
                      ),
                    ),
                  );
                },
                child: const Text('Open settings'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(find.text('Profile content'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Open settings'), findsOneWidget);
      expect(find.text('Profile content'), findsNothing);
    });

    testWidgets('premium sub-pages get the pull-to-sync gesture', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [premiumAccessProvider.overrideWith((ref) async => true)],
          child: MaterialApp(
            home: SettingsSubPageModal(
              title: 'View Settings',
              child: ListView(children: const [Text('Settings content')]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });
  });

  group('CalendarPickerDialog', () {
    /// The scroll view behind one month/year column, so a test can spin it.
    FixedExtentScrollController columnOf(WidgetTester tester, Key key) =>
        tester
                .widget<ListWheelScrollView>(
                  find.descendant(
                    of: find.byKey(key),
                    matching: find.byType(ListWheelScrollView),
                  ),
                )
                .controller!
            as FixedExtentScrollController;

    testWidgets('renders a dialog with a close button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CalendarPickerDialog(
              initialDate: AppDateUtils.bangladeshTodayStartOfDay(),
              hearingCounts: const {},
              onDateSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(Dialog), findsOneWidget);
      final l = AppLocalizations.of(tester.element(find.byType(Dialog).first));
      expect(find.text(l.sharedActions_close), findsOneWidget);
    });

    testWidgets('Total Hearings counts the visible month only, not all dates', (
      WidgetTester tester,
    ) async {
      // Two hearings this month, three hearings in a far-future month.
      final thisMonth = AppDateUtils.bangladeshTodayStartOfDay();
      final nextYear = AppDateUtils.normalizeToBangladeshStartOfDay(
        DateTime(DateTime.now().year + 1, 6, 15).millisecondsSinceEpoch,
      );
      final counts = <int, int>{thisMonth: 2, nextYear: 3};

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CalendarPickerDialog(
              initialDate: thisMonth,
              hearingCounts: counts,
              onDateSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Total must reflect only this month's 2, not 2 + 3 = 5 across all dates.
      expect(find.text('Total Hearings: 2'), findsOneWidget);
    });

    testWidgets('the header follows the month/year wheel before a tap', (
      WidgetTester tester,
    ) async {
      // Two hearings today, seven on a March a year out. Spinning the columns to
      // that month must move the header straight away — nothing is tapped.
      final today = AppDateUtils.bangladeshTodayStartOfDay();
      final todayCivil = AppDateUtils.bangladeshDateTime(today);
      final nextYear = todayCivil.year + 1;
      final marchEpoch = AppDateUtils.bangladeshCivilDateEpoch(nextYear, 3, 15);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CalendarPickerDialog(
              initialDate: today,
              hearingCounts: <int, int>{today: 2, marchEpoch: 7},
              onDateSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Total Hearings: 2'), findsOneWidget);

      // The header month opens both columns; spin the year and then the month.
      await tester.tap(
        find.text(
          intl.DateFormat(
            'MMMM',
          ).format(DateTime(todayCivil.year, todayCivil.month, 1)),
        ),
      );
      await tester.pumpAndSettle();
      columnOf(
        tester,
        monthYearPickerYearColumnKey,
      ).jumpToItem(nextYear - 1900);
      await tester.pumpAndSettle();
      columnOf(tester, monthYearPickerMonthColumnKey).jumpToItem(2);
      await tester.pumpAndSettle();

      expect(find.text('Total Hearings: 7'), findsOneWidget);

      // The title moved with the total: the header's own column now reads March
      // of the spun year, while the day grid has not moved off today's month.
      final header = find
          .ancestor(
            of: find.text('Total Hearings: 7'),
            matching: find.byType(Column),
          )
          .first;
      expect(
        find.descendant(of: header, matching: find.text('March')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: header,
          matching: find.text(
            AppDateUtils.formatDigits(nextYear, 'en', grouping: false),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('dates, years and hearing counts use Bengali digits', (
      WidgetTester tester,
    ) async {
      final today = AppDateUtils.bangladeshTodayStartOfDay();
      final todayCivil = AppDateUtils.bangladeshDateTime(today);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('bn'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CalendarPickerDialog(
              initialDate: today,
              hearingCounts: <int, int>{today: 3},
              onDateSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(tester.element(find.byType(Dialog).first));

      // Header year, today's cell, its badge and the month's hearing total are
      // all plain numbers, so none of them may render as ASCII.
      expect(
        find.text(
          AppDateUtils.formatDigits(todayCivil.year, 'bn', grouping: false),
        ),
        findsOneWidget,
      );
      expect(find.text('${todayCivil.year}'), findsNothing);
      expect(
        find.text(
          AppDateUtils.formatDigits(todayCivil.day, 'bn', grouping: false),
        ),
        findsOneWidget,
      );
      expect(find.text('${todayCivil.day}'), findsNothing);
      expect(
        find.text(
          '${l.dailyCauseListScreen_totalHearings} '
          '${AppDateUtils.formatDigits(3, 'bn')}',
        ),
        findsOneWidget,
      );
      expect(
        find.text('${l.dailyCauseListScreen_totalHearings} 3'),
        findsNothing,
      );
    });

    testWidgets('the year list uses Bengali digits', (
      WidgetTester tester,
    ) async {
      final today = AppDateUtils.bangladeshTodayStartOfDay();
      final year = AppDateUtils.bangladeshDateTime(today).year;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('bn'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CalendarPickerDialog(
              initialDate: today,
              hearingCounts: const {},
              onDateSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tapping the header year opens the month/year columns; every year the
      // year column renders must use Bengali digits (and no separator).
      await tester.tap(
        find.text(AppDateUtils.formatDigits(year, 'bn', grouping: false)),
      );
      await tester.pumpAndSettle();
      final cells = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(monthYearPickerYearColumnKey),
              matching: find.byType(Text),
            ),
          )
          .toList();
      expect(cells, isNotEmpty);
      for (final cell in cells) {
        expect(cell.data, matches(RegExp(r'^[০-৯]+$')), reason: cell.data);
      }
    });

    testWidgets(
      'month and year are straight columns, 1900-2100, confirmed by a tap',
      (WidgetTester tester) async {
        final today = AppDateUtils.bangladeshTodayStartOfDay();
        final todayCivil = AppDateUtils.bangladeshDateTime(today);
        final monthLabel = intl.DateFormat(
          'MMMM',
        ).format(DateTime(todayCivil.year, todayCivil.month, 1));

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: CalendarPickerDialog(
                initialDate: today,
                hearingCounts: const {},
                onDateSelected: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The header's month opens both columns at once; the year column spans
        // 1900-2100 and opens on the focused year rather than at 1900.
        await tester.tap(find.text(monthLabel));
        await tester.pumpAndSettle();
        expect(
          columnOf(tester, monthYearPickerMonthColumnKey).selectedItem,
          todayCivil.month - 1,
        );
        expect(
          columnOf(tester, monthYearPickerYearColumnKey).selectedItem,
          todayCivil.year - 1900,
        );
        expect(
          tester
              .widget<ListWheelScrollView>(
                find.descendant(
                  of: find.byKey(monthYearPickerYearColumnKey),
                  matching: find.byType(ListWheelScrollView),
                ),
              )
              .childDelegate
              .estimatedChildCount,
          201,
        );

        // Spinning the year column moves only that column; tapping the centred
        // month row then confirms both columns and returns to the day grid.
        columnOf(tester, monthYearPickerYearColumnKey).jumpToItem(2100 - 1900);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byKey(monthYearPickerMonthColumnKey),
            matching: find.text(monthLabel),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ListWheelScrollView), findsNothing);
        expect(find.text('2100'), findsOneWidget);
      },
    );
  });
}
