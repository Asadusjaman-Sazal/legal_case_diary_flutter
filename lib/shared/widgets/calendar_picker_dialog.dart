/// Badge calendar picker for the Daily Cause List screen.
///
/// Shows a month grid of the selected civil month. Each day cell displays a
/// hearing-count badge: a gray badge when the date has hearings, no badge when
/// it does not. "Today" is highlighted with a black cell and a white badge
/// (white badge only when it has hearings). The month title is paired with a
/// "Total Hearings:" count for the visible month. Used only on the Daily Cause
/// List screen (per the design plan).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/utils/date_utils.dart';

/// A dialog shell hosting the Daily Cause List badge calendar.
///
/// [initialDate] is the currently selected Bangladesh civil date (epoch ms at
/// start of day). [hearingCounts] maps civil-day start-of-day epochs to the
/// number of hearings on that date. [onDateSelected] is invoked with the chosen
/// date when the user taps a day cell; the dialog then closes itself.
class CalendarPickerDialog extends StatelessWidget {
  /// Currently selected civil date (epoch ms at start of day).
  final int initialDate;

  /// Hearing counts keyed by civil-day start-of-day epoch.
  final Map<int, int> hearingCounts;

  /// Called with the picked civil date; the dialog pops itself afterwards.
  final ValueChanged<int> onDateSelected;

  /// Creates the Daily Cause List calendar picker dialog.
  const CalendarPickerDialog({
    required this.initialDate,
    required this.hearingCounts,
    required this.onDateSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.all(AppSpacing.sm),
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius * 2),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: 360,
            maxWidth: 460,
            minHeight: MediaQuery.of(context).size.height * 0.565,
            maxHeight: MediaQuery.of(context).size.height * 0.743,
          ),
          child: _BadgeCalendarGrid(
            initialDate: initialDate,
            hearingCounts: hearingCounts,
            onDateSelected: onDateSelected,
          ),
        ),
      );
}

/// Stateful month grid backing [CalendarPickerDialog].
class _BadgeCalendarGrid extends StatefulWidget {
  final int initialDate;
  final Map<int, int> hearingCounts;
  final ValueChanged<int> onDateSelected;

  const _BadgeCalendarGrid({
    required this.initialDate,
    required this.hearingCounts,
    required this.onDateSelected,
  });

  @override
  State<_BadgeCalendarGrid> createState() => _BadgeCalendarGridState();
}

class _BadgeCalendarGridState extends State<_BadgeCalendarGrid> {
  /// The focused month (Bangladesh civil date, day pinned to 1).
  late DateTime _focusedMonth;

  /// Currently selected civil date (epoch ms at start of day).
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
    final d = AppDateUtils.bangladeshDateTime(widget.initialDate);
    _focusedMonth = DateTime(d.year, d.month, 1);
  }

  void _changeMonth(int delta) =>
      setState(() => _focusedMonth = DateTime(
            _focusedMonth.year,
            _focusedMonth.month + delta,
            1,
          ));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = l.localeName;
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final firstWeekday = DateTime(year, month, 1).weekday; // Mon=1 .. Sun=7
    final leadingBlanks = firstWeekday % 7; // Sunday-first offset.
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final monthTitle = DateFormat('MMMM yyyy', locale).format(_focusedMonth);

    var totalHearings = 0;
    for (var day = 1; day <= daysInMonth; day++) {
      totalHearings +=
          widget.hearingCounts[AppDateUtils.bangladeshCivilDateEpoch(
        year,
        month,
        day,
      )] ??
              0;
    }

    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header: month navigation + title + total hearings.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeMonth(-1),
              ),
              Column(
                children: [
                  Text(
                    monthTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '${l.dailyCauseListScreen_totalHearings} $totalHearings',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.onSurface,
                        ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
        ),
        // Weekday headers (Sunday-first, localized).
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: List<Widget>.generate(7, (i) {
              final label = DateFormat('E', locale)
                  .format(DateTime(2023, 1, 1 + i)); // Jan 1 2023 is Sunday.
              return Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Day cells — expanded to fill the dialog so no empty space remains.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const dateRows = 6; // Always show 6 date rows like other pickers.
              final cellHeight =
                  (constraints.maxHeight - AppSpacing.sm * (dateRows - 1)) /
                      dateRows;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: GridView.custom(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: 0,
                    mainAxisExtent: cellHeight,
                  ),
                  childrenDelegate: SliverChildListDelegate([
                    for (var i = 0; i < leadingBlanks; i++)
                      const SizedBox.shrink(),
                    for (var day = 1; day <= daysInMonth; day++)
                      Builder(
                        builder: (context) {
                          final epoch = AppDateUtils.bangladeshCivilDateEpoch(
                            year,
                            month,
                            day,
                          );
                          final count = widget.hearingCounts[epoch] ?? 0;
                          final isToday =
                              epoch == AppDateUtils.bangladeshTodayStartOfDay();
                          final isSelected = epoch == _selected;
                          return _DayCell(
                            day: day,
                            count: count,
                            isToday: isToday,
                            isSelected: isSelected,
                            onTap: () => widget.onDateSelected(epoch),
                          );
                        },
                      ),
                    // Pad the 7th (and any unused) row with empty cells so the
                    // grid always shows 6 date rows consistently.
                    for (var i = 0;
                        i < (dateRows * 7 - leadingBlanks - daysInMonth);
                        i++)
                      const SizedBox.shrink(),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Close button (black background, white text — matches app theme).
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.sharedActions_close),
            ),
          ),
        ),
      ],
    );
  }
}

/// A single day cell in the badge calendar grid.
class _DayCell extends StatelessWidget {
  final int day;
  final int count;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.count,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasHearings = count > 0;
    // Today and the selected (non-today) date are highlighted with black; all
    // other dates are plain. The selected non-today date uses a black ring so it
    // matches the Today fill and stays visible against the light background.
    final isHighlighted = isToday || isSelected;
    final backgroundColor = isHighlighted ? AppColors.primary : null;
    final foreground = isHighlighted ? AppColors.onPrimary : AppColors.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          border: isSelected && !isToday
              ? Border.all(color: AppColors.primary, width: 2)
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '$day',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: foreground),
            ),
            if (hasHearings)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? AppColors.onPrimary
                        : AppColors.surfaceDim,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isHighlighted
                              ? AppColors.primary
                              : AppColors.onSurface,
                          fontSize: 9,
                        ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
