/// Badge calendar picker for the Daily Cause List screen.
///
/// Shows a month grid of the selected civil month. Each day cell displays a
/// hearing-count badge: a gray badge when the date has hearings, no badge when
/// it does not. "Today" is highlighted with a black cell and a white badge
/// (white badge only when it has hearings). The month title is paired with a
/// "Total Hearings:" count spanning ALL scheduled dates (not just the visible
/// month). Used only on the Daily Cause List screen (per the design plan).
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

enum _PickerMode { day, month, year }

class _BadgeCalendarGridState extends State<_BadgeCalendarGrid> {
  /// The focused month (Bangladesh civil date, day pinned to 1).
  late DateTime _focusedMonth;

  /// Currently selected civil date (epoch ms at start of day).
  late int _selected;

  /// Which selection view is showing: the day grid, the month list, or the year list.
  _PickerMode _mode = _PickerMode.day;

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

  /// Sets the focused year (keeps month/day) and returns to the day grid.
  void _pickYear(int year) => setState(() {
        _focusedMonth = DateTime(year, _focusedMonth.month, 1);
        _mode = _PickerMode.day;
      });

  /// Sets the focused month (keeps year/day) and returns to the day grid.
  void _pickMonth(int month) => setState(() {
        _focusedMonth = DateTime(_focusedMonth.year, month, 1);
        _mode = _PickerMode.day;
      });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = l.localeName;
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final firstWeekday = DateTime(year, month, 1).weekday; // Mon=1 .. Sun=7
    final leadingBlanks = firstWeekday % 7; // Sunday-first offset.
    final daysInMonth = DateTime(year, month + 1, 0).day;

    // Total Hearings reflects ALL scheduled cases across every date (the map is
    // keyed by civil-day epoch for the full range), not just the visible month.
    final totalHearings =
        widget.hearingCounts.values.fold(0, (sum, c) => sum + c);

    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header: navigation + tappable title.
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
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: () => setState(() => _mode =
                              _mode == _PickerMode.month
                                  ? _PickerMode.day
                                  : _PickerMode.month),
                          borderRadius: BorderRadius.circular(AppSpacing.sm),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  DateFormat('MMMM', locale)
                                      .format(_focusedMonth),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 20,
                                  color: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.color,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => setState(() => _mode =
                              _mode == _PickerMode.year
                                  ? _PickerMode.day
                                  : _PickerMode.year),
                          borderRadius: BorderRadius.circular(AppSpacing.sm),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '${_focusedMonth.year}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 20,
                                  color: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.color,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '${l.dailyCauseListScreen_totalHearings} $totalHearings',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: AppColors.onSurface),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
        ),
        // Body switches between day grid, month list, and year list.
        Expanded(
          child: _mode == _PickerMode.month
              ? _MonthSelector(
                  selectedMonth: month,
                  onSelect: _pickMonth,
                )
              : _mode == _PickerMode.year
                  ? _YearSelector(
                      selectedYear: year,
                      onSelect: _pickYear,
                    )
                  : _DayGridView(
                      year: year,
                      month: month,
                      leadingBlanks: leadingBlanks,
                      daysInMonth: daysInMonth,
                      hearingCounts: widget.hearingCounts,
                      isToday: (epoch) =>
                          epoch == AppDateUtils.bangladeshTodayStartOfDay(),
                      isSelected: (epoch) => epoch == _selected,
                      onPick: widget.onDateSelected,
                      onPrevMonth: () => _changeMonth(-1),
                      onNextMonth: () => _changeMonth(1),
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

/// The day grid: weekday headers plus a 6-row (always) grid of [_DayCell]s.
class _DayGridView extends StatelessWidget {
  final int year;
  final int month;
  final int leadingBlanks;
  final int daysInMonth;
  final Map<int, int> hearingCounts;
  final bool Function(int epoch) isToday;
  final bool Function(int epoch) isSelected;
  final ValueChanged<int> onPick;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;

  const _DayGridView({
    required this.year,
    required this.month,
    required this.leadingBlanks,
    required this.daysInMonth,
    required this.hearingCounts,
    required this.isToday,
    required this.isSelected,
    required this.onPick,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context).localeName;
    return Column(
      children: [
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
        // Day cells — expanded to fill the space so no empty area remains, and
        // always rendering 6 date rows (the 7th row stays empty when unused).
        // Swipe left/right to change month (Google Calendar style).
        Expanded(
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity == null) return;
              if (details.primaryVelocity! < 0) {
                onNextMonth();
              } else if (details.primaryVelocity! > 0) {
                onPrevMonth();
              }
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                const dateRows = 6;
                final cellHeight =
                    (constraints.maxHeight - AppSpacing.sm * (dateRows - 1)) /
                        dateRows;
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
                            final epoch =
                                AppDateUtils.bangladeshCivilDateEpoch(
                              year,
                              month,
                              day,
                            );
                            return _DayCell(
                              day: day,
                              count: hearingCounts[epoch] ?? 0,
                              isToday: isToday(epoch),
                              isSelected: isSelected(epoch),
                              onTap: () => onPick(epoch),
                            );
                          },
                        ),
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
        ),
      ],
    );
  }
}

/// A tappable grid of all 12 months for the focused year.
class _MonthSelector extends StatelessWidget {
  final int selectedMonth;
  final ValueChanged<int> onSelect;

  const _MonthSelector({
    required this.selectedMonth,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final months = List<String>.generate(
      12,
      (i) => DateFormat('MMMM', l.localeName).format(DateTime(2023, i + 1, 1)),
    );
    return GridView.count(
      crossAxisCount: 3,
      padding: const EdgeInsets.all(AppSpacing.md),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: List<Widget>.generate(12, (i) {
        final m = i + 1;
        final isSelected = m == selectedMonth;
        return InkWell(
          onTap: () => onSelect(m),
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : null,
              borderRadius: BorderRadius.circular(AppSpacing.sm),
              border: isSelected
                  ? null
                  : Border.all(color: AppColors.surfaceDim),
            ),
            child: Center(
              child: Text(
                months[i],
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: isSelected
                          ? AppColors.onPrimary
                          : AppColors.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// A scrollable list of selectable years spanning 1926–2126.
class _YearSelector extends StatelessWidget {
  static const int _minYear = 1926;
  static const int _maxYear = 2126;
  static const double _childAspectRatio = 2.2;

  final int selectedYear;
  final ValueChanged<int> onSelect;

  const _YearSelector({
    required this.selectedYear,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final years = [
      for (var y = _minYear; y <= _maxYear; y++) y,
    ];
    // Approximate row height so we can scroll the focused (current) year into
    // view on open — 4 columns, fixed aspect ratio against the available width.
    final rowHeight = (MediaQuery.of(context).size.width - AppSpacing.md * 2) /
            4 /
            _childAspectRatio +
        AppSpacing.sm;
    final initialRow = (selectedYear - _minYear) ~/ 4;
    final controller = ScrollController(
      initialScrollOffset: (initialRow * rowHeight).clamp(
        0.0,
        (years.length / 4) * rowHeight,
      ),
    );
    return GridView.builder(
      controller: controller,
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: _childAspectRatio,
      ),
      itemCount: years.length,
      itemBuilder: (context, index) {
        final y = years[index];
        final isSelected = y == selectedYear;
        return InkWell(
          onTap: () => onSelect(y),
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : null,
              borderRadius: BorderRadius.circular(AppSpacing.sm),
              border: isSelected
                  ? null
                  : Border.all(color: AppColors.surfaceDim),
            ),
            child: Center(
              child: Text(
                '$y',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: isSelected
                          ? AppColors.onPrimary
                          : AppColors.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
              ),
            ),
          ),
        );
      },
    );
  }
}
