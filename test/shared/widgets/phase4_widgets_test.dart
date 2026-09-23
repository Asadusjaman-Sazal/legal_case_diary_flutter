import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' as intl;
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/utils/date_utils.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_sub_page_modal.dart';
import 'package:legal_case_diary/shared/widgets/calendar_picker_dialog.dart';

void main() {
  group('SettingsSubPageModal', () {
    testWidgets('renders title, body, actions, and invokes back callback', (
      WidgetTester tester,
    ) async {
      var backPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsSubPageModal(
            title: 'View Settings',
            onBack: () => backPressed = true,
            actions: const [Icon(Icons.more_vert)],
            child: const Text('Settings content'),
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
        MaterialApp(
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
      );

      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(find.text('Profile content'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Open settings'), findsOneWidget);
      expect(find.text('Profile content'), findsNothing);
    });
  });

  group('CalendarPickerDialog', () {
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

      // Tapping the header year opens the scrollable year list; every row it
      // renders must use Bengali digits (and no thousands separator).
      await tester.tap(
        find.text(AppDateUtils.formatDigits(year, 'bn', grouping: false)),
      );
      await tester.pumpAndSettle();
      final cells = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(ListView),
              matching: find.byType(Text),
            ),
          )
          .toList();
      expect(cells, isNotEmpty);
      for (final cell in cells) {
        expect(cell.data, matches(RegExp(r'^[০-৯]+$')), reason: cell.data);
      }
    });

    testWidgets('month and year read as one option per line, 1900-2100 years',
        (WidgetTester tester) async {
      final today = AppDateUtils.bangladeshTodayStartOfDay();
      final todayCivil = AppDateUtils.bangladeshDateTime(today);
      final monthLabel =
          intl.DateFormat('MMMM').format(DateTime(todayCivil.year, todayCivil.month, 1));
      final nextMonthLabel = intl.DateFormat('MMMM')
          .format(DateTime(todayCivil.year, todayCivil.month + 1, 1));

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

      // Months: one column, one month per line (was a 3-column grid), opened
      // with the focused month in view and drawn larger than its neighbours.
      await tester.tap(find.text(monthLabel));
      await tester.pumpAndSettle();
      var list = tester.widget<ListView>(find.byType(ListView));
      expect(
        (list.childrenDelegate as SliverChildBuilderDelegate)
            .estimatedChildCount,
        12,
      );
      Text row(String label) => tester.widget<Text>(
            find.descendant(
              of: find.byType(ListView),
              matching: find.text(label),
            ),
          );
      final nextMonth = tester.getRect(find.text(nextMonthLabel));
      final monthRow = tester.getRect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text(monthLabel),
        ),
      );
      // Same horizontal centre (one column), one row apart. Centres are compared
      // because the enlarged selected label is taller than its neighbour.
      expect(nextMonth.center.dx, monthRow.center.dx);
      expect(nextMonth.center.dy - monthRow.center.dy, closeTo(list.itemExtent!, 0.5));
      expect(
        row(monthLabel).style!.fontSize!,
        greaterThan(row(nextMonthLabel).style!.fontSize!),
      );

      // Years: the same single column, spanning 1900-2100 and opened at the
      // focused year rather than at 1900.
      await tester.tap(find.text('${todayCivil.year}'));
      await tester.pumpAndSettle();
      list = tester.widget<ListView>(find.byType(ListView));
      expect(
        (list.childrenDelegate as SliverChildBuilderDelegate)
            .estimatedChildCount,
        201,
      );
      expect(
        list.controller!.offset,
        (todayCivil.year - 1900) * list.itemExtent!,
      );
      expect(find.text('1900'), findsNothing);
      expect(row('${todayCivil.year}').style!.fontSize!,
          greaterThan(row('${todayCivil.year + 1}').style!.fontSize!));
    });
  });
}
