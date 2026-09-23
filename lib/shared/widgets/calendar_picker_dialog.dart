/// Badge calendar picker for the Daily Cause List screen.
///
/// Shows a month grid of the selected civil month. Each day cell displays a
/// hearing-count badge: a gray badge when the date has hearings, no badge when
/// it does not. "Today" is highlighted with a black cell and a white badge
/// (white badge only when it has hearings). The month title is paired with a
/// "Total Hearings:" count for the visible month only (summed from the per-date
/// hearing counts). Used only on the Daily Cause List screen (per the design
/// plan).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/utils/date_utils.dart';

/// Year span the year list offers and the picker's month navigation stays
/// inside, so a month step can never leave what the year list can select.
const int _calendarMinYear = 1900;
const int _calendarMaxYear = 2100;

/// Height of one month/year option row, including its 2 px outer gap.
///
/// Fixed so the list opens scrolled to the selected row without measuring
/// anything, however many years there are.
const double _pickerOptionRowExtent = 52;

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

  void _changeMonth(int delta) {
    final next = DateTime(_focusedMonth.year, _focusedMonth.month + delta, 1);
    if (next.year < _calendarMinYear || next.year > _calendarMaxYear) return;
    setState(() => _focusedMonth = next);
  }

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

    // Total Hearings reflects the visible month only: sum the hearing counts
    // across that month's civil-day epochs in the all-dates map.
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
                                  AppDateUtils.formatDigits(
                                    _focusedMonth.year,
                                    locale,
                                    grouping: false,
                                  ),
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
                      '${l.dailyCauseListScreen_totalHearings} '
                      '${AppDateUtils.formatDigits(totalHearings, locale)}',
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
    final locale = AppLocalizations.of(context).localeName;
    final hasHearings = count > 0;
    // Selected (today or not): black fill + white text. A today cell that is NOT
    // the current selection shows a black ring on white with black text, so the
    // selected date stays distinct. When today is selected (the default on open),
    // both flags are true and it correctly renders as the selected (filled) cell.
    final selected = isSelected;
    final todayUnselected = isToday && !isSelected;
    final backgroundColor = selected ? AppColors.primary : null;
    final foreground = selected
        ? AppColors.onPrimary
        : todayUnselected
            ? AppColors.primary
            : AppColors.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
          border: todayUnselected
              ? Border.all(color: AppColors.primary, width: 2)
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              AppDateUtils.formatDigits(day, locale, grouping: false),
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
                    color: selected
                        ? AppColors.onPrimary
                        : AppColors.surfaceDim,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    AppDateUtils.formatDigits(count, locale),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: selected
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

/// A tappable single-column list of all 12 months for the focused year.
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
    return _PickerOptionList(
      labels: months,
      selectedIndex: selectedMonth - 1,
      onSelect: (index) => onSelect(index + 1),
    );
  }
}

/// A scrollable single-column list of the selectable years (1900–2100).
class _YearSelector extends StatelessWidget {
  final int selectedYear;
  final ValueChanged<int> onSelect;

  const _YearSelector({
    required this.selectedYear,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context).localeName;
    return _PickerOptionList(
      labels: [
        for (var y = _calendarMinYear; y <= _calendarMaxYear; y++)
          AppDateUtils.formatDigits(y, locale, grouping: false),
      ],
      selectedIndex: (selectedYear - _calendarMinYear)
          .clamp(0, _calendarMaxYear - _calendarMinYear),
      onSelect: (index) => onSelect(_calendarMinYear + index),
    );
  }
}

/// A vertical single-column option list for the month and year selectors.
///
/// One label per line, top to bottom, opened with the selected row in view.
/// (Both selectors used to be multi-column grids, which made the current
/// month/year hard to find.)
class _PickerOptionList extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _PickerOptionList({
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      // The scroll view clamps this to its own extent, so the last year's row
      // is never left unreachable.
      controller: ScrollController(
        initialScrollOffset: selectedIndex * _pickerOptionRowExtent,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      itemExtent: _pickerOptionRowExtent,
      itemCount: labels.length,
      itemBuilder: (context, index) => _PickerOptionRow(
        label: labels[index],
        selected: index == selectedIndex,
        onTap: () => onSelect(index),
      ),
    );
  }
}

/// One month/year row: the selected one is drawn a little larger and bold on
/// the primary fill, so the current choice is identifiable at a glance.
class _PickerOptionRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PickerOptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.labelLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: Container(
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : null,
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            border: selected ? null : Border.all(color: AppColors.surfaceDim),
          ),
          child: Center(
            child: Text(
              label,
              style: base?.copyWith(
                color: selected ? AppColors.onPrimary : AppColors.onSurface,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: selected ? (base.fontSize ?? 14) + 4 : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
