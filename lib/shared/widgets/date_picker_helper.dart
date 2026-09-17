/// Plain date-picker helpers for forms (Add/Edit case window).
///
/// Uses a custom grid that matches the Daily Cause List badge calendar's layout
/// (month/year chevron selectors, weekday 7-column body, window dimensions) but
/// keeps its own header (selected-date title), Material today ring, and the
/// Cancel/OK action buttons. No hearing counts (unlike the badge calendar).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/utils/date_utils.dart' show AppDateUtils;

const _englishPickerMonths = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _bengaliPickerMonths = <String>[
  'জানুঃ',
  'ফেব্রুঃ',
  'মার্চ',
  'এপ্রিল',
  'মে',
  'জুন',
  'জুলাই',
  'আগস্ট',
  'সেপ্টঃ',
  'অক্টোঃ',
  'নভেঃ',
  'ডিসেঃ',
];

const _englishPickerWeekdays = <String>[
  'Sun',
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
];

const _bengaliPickerWeekdays = <String>[
  'রবি',
  'সোম',
  'মঙ্গল',
  'বুধ',
  'বৃহঃ',
  'শুক্র',
  'শনি',
];

/// Formats the 1st-line header: "Month day, Weekday" (e.g. "Aug 5, Wed").
String _formatPickerHeaderDate(DateTime date, Locale locale) {
  final isBengali = locale.languageCode == 'bn';
  final monthLabels = isBengali ? _bengaliPickerMonths : _englishPickerMonths;
  final weekdayLabels = isBengali ? _bengaliPickerWeekdays : _englishPickerWeekdays;
  final day = AppDateUtils.formatDigits(
    date.day,
    locale.languageCode,
    grouping: false,
  );
  return '${monthLabels[date.month - 1]} $day, '
      '${weekdayLabels[date.weekday % DateTime.daysPerWeek]}';
}

enum _PickerMode { day, month, year }

class _PlainDatePickerDialog extends StatefulWidget {
  const _PlainDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.styleActions,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool styleActions;

  @override
  State<_PlainDatePickerDialog> createState() => _PlainDatePickerDialogState();
}

class _PlainDatePickerDialogState extends State<_PlainDatePickerDialog> {
  late DateTime _selectedDate = widget.initialDate;

  /// Focused month (day pinned to 1) for the day-grid header navigation.
  late DateTime _focusedMonth = DateTime(
    widget.initialDate.year,
    widget.initialDate.month,
    1,
  );

  _PickerMode _mode = _PickerMode.day;

  int get _selectedEpoch =>
      AppDateUtils.normalizeToBangladeshStartOfDay(_selectedDate.millisecondsSinceEpoch);

  void _changeMonth(int delta) {
    final next = DateTime(_focusedMonth.year, _focusedMonth.month + delta, 1);
    final minMonth = DateTime(widget.firstDate.year, widget.firstDate.month, 1);
    final maxMonth = DateTime(widget.lastDate.year, widget.lastDate.month, 1);
    if (next.isBefore(minMonth) || next.isAfter(maxMonth)) return;
    setState(() => _focusedMonth = next);
  }

  void _pickYear(int year) => setState(() {
        _focusedMonth = DateTime(year, _focusedMonth.month, 1);
        _mode = _PickerMode.day;
      });

  void _pickMonth(int month) => setState(() {
        _focusedMonth = DateTime(_focusedMonth.year, month, 1);
        _mode = _PickerMode.day;
      });

  bool _isEnabledDay(int epoch) {
    final date = AppDateUtils.bangladeshDateTime(epoch);
    return !date.isBefore(
          DateTime(widget.firstDate.year, widget.firstDate.month, widget.firstDate.day),
        ) &&
        !date.isAfter(
          DateTime(widget.lastDate.year, widget.lastDate.month, widget.lastDate.day),
        );
  }

  void _selectDay(int epoch) {
    if (!_isEnabledDay(epoch)) return;
    setState(() => _selectedDate = AppDateUtils.bangladeshDateTime(epoch));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final datePickerTheme = DatePickerTheme.of(context);
    final defaults = DatePickerTheme.defaults(context);
    final headerForegroundColor =
        datePickerTheme.headerForegroundColor ??
        defaults.headerForegroundColor ??
        theme.colorScheme.onPrimary;
    final headerStyle =
        (datePickerTheme.headerHeadlineStyle ??
                defaults.headerHeadlineStyle ??
                theme.textTheme.headlineSmall)
            ?.copyWith(color: headerForegroundColor);
    final actionButtonStyle = widget.styleActions
        ? TextButton.styleFrom(
            alignment: Alignment.center,
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            fixedSize: const Size(132, 52),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          )
        : TextButton.styleFrom(
            alignment: Alignment.center,
            minimumSize: const Size(88, 52),
          );

    return Dialog(
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
        child: SizedBox(
          key: const ValueKey('plain-date-picker-surface'),
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1st-line header (selected date title) — lowered and centered.
              Container(
                width: double.infinity,
                alignment: Alignment.center,
                color: datePickerTheme.headerBackgroundColor ??
                    defaults.headerBackgroundColor,
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 20),
                child: Text(
                  _formatPickerHeaderDate(
                    _selectedDate,
                    Localizations.localeOf(context),
                  ),
                  style: headerStyle,
                ),
              ),
              // Calendar body: day grid (with month/year selectors), or the
              // month/year list selectors.
              Expanded(
                child: _mode == _PickerMode.month
                    ? _MonthSelector(
                        selectedMonth: _focusedMonth.month,
                        onSelect: _pickMonth,
                      )
                    : _mode == _PickerMode.year
                        ? _YearSelector(
                            firstYear: widget.firstDate.year,
                            lastYear: widget.lastDate.year,
                            selectedYear: _focusedMonth.year,
                            onSelect: _pickYear,
                          )
                        : _DayView(
                            focusedMonth: _focusedMonth,
                            selectedEpoch: _selectedEpoch,
                            onPrevMonth: () => _changeMonth(-1),
                            onNextMonth: () => _changeMonth(1),
                            onSelectMonth: () => setState(() =>
                                _mode = _mode == _PickerMode.month
                                    ? _PickerMode.day
                                    : _PickerMode.month),
                            onSelectYear: () => setState(() =>
                                _mode = _mode == _PickerMode.year
                                    ? _PickerMode.day
                                    : _PickerMode.year),
                            isToday: (epoch) =>
                                epoch == AppDateUtils.bangladeshTodayStartOfDay(),
                            isEnabled: _isEnabledDay,
                            onPick: _selectDay,
                          ),
              ),
              // Cancel / OK action buttons — unchanged.
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: widget.styleActions ? 132 : null,
                      height: 52,
                      child: TextButton(
                        style: actionButtonStyle,
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          MaterialLocalizations.of(context).cancelButtonLabel,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: widget.styleActions ? 132 : null,
                      height: 52,
                      child: TextButton(
                        style: actionButtonStyle,
                        onPressed: () => Navigator.of(context).pop(_selectedDate),
                        child: Text(
                          MaterialLocalizations.of(context).okButtonLabel,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Day-view: month/year `<>` selector header + the 7-column weekday grid.
class _DayView extends StatelessWidget {
  final DateTime focusedMonth;
  final int selectedEpoch;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onSelectMonth;
  final VoidCallback onSelectYear;
  final bool Function(int epoch) isToday;
  final bool Function(int epoch) isEnabled;
  final ValueChanged<int> onPick;

  const _DayView({
    required this.focusedMonth,
    required this.selectedEpoch,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onSelectMonth,
    required this.onSelectYear,
    required this.isToday,
    required this.isEnabled,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context).localeName;
    final year = focusedMonth.year;
    final month = focusedMonth.month;
    final firstWeekday = DateTime(year, month, 1).weekday; // Mon=1 .. Sun=7
    final leadingBlanks = firstWeekday % 7; // Sunday-first offset.
    final daysInMonth = DateTime(year, month + 1, 0).day;

    return Column(
      children: [
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
                onPressed: onPrevMonth,
              ),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: onSelectMonth,
                          borderRadius: BorderRadius.circular(AppSpacing.sm),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  intl.DateFormat('MMMM', locale)
                                      .format(focusedMonth),
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
                          onTap: onSelectYear,
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
                                    year,
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
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: onNextMonth,
              ),
            ],
          ),
        ),
        Expanded(
          child: GestureDetector(
            // Swipe left/right to change month, like Google Calendar.
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity == null) return;
              if (details.primaryVelocity! < 0) {
                onNextMonth();
              } else if (details.primaryVelocity! > 0) {
                onPrevMonth();
              }
            },
            child: _DayGrid(
              year: year,
              month: month,
              leadingBlanks: leadingBlanks,
              daysInMonth: daysInMonth,
              selectedEpoch: selectedEpoch,
              isToday: isToday,
              isEnabled: isEnabled,
              onPick: onPick,
            ),
          ),
        ),
      ],
    );
  }
}

/// Weekday headers + a 6-row (always) 7-column grid of day cells.
class _DayGrid extends StatelessWidget {
  final int year;
  final int month;
  final int leadingBlanks;
  final int daysInMonth;
  final int selectedEpoch;
  final bool Function(int epoch) isToday;
  final bool Function(int epoch) isEnabled;
  final ValueChanged<int> onPick;

  const _DayGrid({
    required this.year,
    required this.month,
    required this.leadingBlanks,
    required this.daysInMonth,
    required this.selectedEpoch,
    required this.isToday,
    required this.isEnabled,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context).localeName;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: List<Widget>.generate(7, (i) {
              final label = intl.DateFormat('E', locale)
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
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const dateRows = 6;
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
                          return _DayCell(
                            day: day,
                            isToday: isToday(epoch),
                            isSelected: epoch == selectedEpoch,
                            enabled: isEnabled(epoch),
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
      ],
    );
  }
}

/// A single day cell: today gets a Material circle outline, the selected
/// (non-today) date gets a filled circle, others are plain. No hearing badge.
class _DayCell extends StatelessWidget {
  final int day;
  final bool isToday;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = enabled
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: 0.38);
    // Selected (today or not): black fill + white text. A today cell that is NOT
    // the current selection shows a black ring on white with black text, so the
    // selected date stays distinct. When today is selected (the default on open),
    // both flags are true and it correctly renders as the selected (filled) cell.
    final selected = isSelected;
    final todayUnselected = isToday && !isSelected;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? colorScheme.primary : null,
          border: todayUnselected
              ? Border.all(color: colorScheme.primary, width: 2)
              : null,
        ),
        child: Center(
          child: Text(
            AppDateUtils.formatDigits(
              day,
              AppLocalizations.of(context).localeName,
              grouping: false,
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected
                      ? colorScheme.onPrimary
                      : todayUnselected
                          ? colorScheme.primary
                          : textColor,
                  fontWeight:
                      (isSelected || isToday) ? FontWeight.bold : FontWeight.normal,
                ),
          ),
        ),
      ),
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
      (i) => intl.DateFormat('MMMM', l.localeName)
          .format(DateTime(2023, i + 1, 1)),
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

/// A scrollable list of selectable years spanning the picker's date bounds.
class _YearSelector extends StatelessWidget {
  static const double _childAspectRatio = 2.2;

  final int firstYear;
  final int lastYear;
  final int selectedYear;
  final ValueChanged<int> onSelect;

  const _YearSelector({
    required this.firstYear,
    required this.lastYear,
    required this.selectedYear,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final years = [for (var y = firstYear; y <= lastYear; y++) y];
    final rowHeight =
        (MediaQuery.of(context).size.width - AppSpacing.md * 2) /
            4 /
            _childAspectRatio +
        AppSpacing.sm;
    final initialRow = (selectedYear - firstYear) ~/ 4;
    final controller = ScrollController(
      initialScrollOffset:
          (initialRow * rowHeight).clamp(0.0, (years.length / 4) * rowHeight),
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
                AppDateUtils.formatDigits(
                  y,
                  AppLocalizations.of(context).localeName,
                  grouping: false,
                ),
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

/// Returns the date-only value used as the default picker selection.
///
/// Keeping this calculation separate makes the today-default rule reusable and
/// straightforward to test without opening a platform dialog.
DateTime plainDatePickerInitialDate([DateTime? now]) {
  return DateUtils.dateOnly(now ?? DateTime.now());
}

/// Opens a plain date picker defaulting to today.
///
/// The calendar body matches the Daily Cause List badge calendar (month/year
/// `<>` selectors, weekday 7-column grid, window dimensions) but keeps its own
/// header and Cancel/OK buttons. [initialDate] may be supplied by an edit form;
/// when omitted the picker opens on today. Returns date-only, or `null` on cancel.
Future<DateTime?> showPlainDatePicker(
  BuildContext context, {
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  bool styleActions = false,
}) async {
  final today = plainDatePickerInitialDate();
  final effectiveFirstDate = DateUtils.dateOnly(
    firstDate ?? DateTime(today.year - 100),
  );
  final effectiveLastDate = DateUtils.dateOnly(
    lastDate ?? DateTime(today.year + 100),
  );
  if (effectiveFirstDate.isAfter(effectiveLastDate)) {
    throw ArgumentError.value(
      lastDate,
      'lastDate',
      'must be on or after firstDate',
    );
  }
  final requestedDate = DateUtils.dateOnly(initialDate ?? today);
  final effectiveInitialDate = requestedDate.isBefore(effectiveFirstDate)
      ? effectiveFirstDate
      : requestedDate.isAfter(effectiveLastDate)
          ? effectiveLastDate
          : requestedDate;

  return showDialog<DateTime>(
    context: context,
    builder: (context) => _PlainDatePickerDialog(
      initialDate: effectiveInitialDate,
      firstDate: effectiveFirstDate,
      lastDate: effectiveLastDate,
      styleActions: styleActions,
    ),
  );
}
