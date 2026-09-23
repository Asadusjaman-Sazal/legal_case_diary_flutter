/// The Month | Year selector the app's calendars share.
///
/// Add/Edit Case's date fields, the Quick Update window, the Edit History Entry
/// sheet and the Daily Cause List's badge calendar all open this same selector,
/// so it lives here rather than being copied into each dialog.
///
/// It reads as a **straight list**, not an iOS wheel. Flutter's own
/// [ListWheelScrollView] is still what drives it — that is the widget that snaps
/// one row at a time and keeps the row in the middle the current value — but its
/// cylinder is given a diameter so much larger than the column that the rows are
/// drawn flat: none is bent, magnified or faded, so every label paints at its own
/// size in the app's own text colour, and the current row differs from its
/// neighbours by weight alone. Tapping a row confirms the pair.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../core/constants/app_colors.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/utils/date_utils.dart' show AppDateUtils;

/// Height of the picker columns — the height of the iOS wheel they replace.
const double monthYearPickerHeight = 216;

/// One row of a column. 44 px keeps a label legible at the largest Font Size
/// step, where a larger label still fits without clipping.
const double monthYearPickerRowExtent = 44;

/// The Month column's key, so a test (or a finder) can address it.
const Key monthYearPickerMonthColumnKey = ValueKey('month-picker-column');

/// The Year column's key, so a test (or a finder) can address it.
const Key monthYearPickerYearColumnKey = ValueKey('year-picker-column');

/// The flattened cylinder's diameter, as a multiple of a column's height.
///
/// Flutter exposes no flat version of its snapping picker, so the curvature is
/// flattened instead: at 100 the outermost visible row tilts by about half a
/// degree — under a pixel across a label — and rows land exactly one row extent
/// apart, which is what makes the column read as a straight list.
const double _flatDiameterRatio = 100;

/// How many rows fit into the column's height.
///
/// A `squeeze` of 1 spaces the rows exactly one row extent apart, matching what
/// the rows are laid out at, so the list and its middle line up with the layout
/// rather than with a compressed wheel.
const double _flatSqueeze = 1;

/// The Month | Year pair: two straight lists side by side, whose current values
/// are confirmed together by a tap on either column.
class MonthYearPickerColumns extends StatefulWidget {
  /// First year the year column offers.
  final int firstYear;

  /// Last year the year column offers.
  final int lastYear;

  /// Month the columns open on (1-12).
  final int month;

  /// Year the columns open on.
  final int year;

  /// Called with the confirmed month and year when a row is tapped.
  final void Function(int month, int year) onPicked;

  const MonthYearPickerColumns({
    super.key,
    required this.firstYear,
    required this.lastYear,
    required this.month,
    required this.year,
    required this.onPicked,
  });

  @override
  State<MonthYearPickerColumns> createState() => _MonthYearPickerColumnsState();
}

class _MonthYearPickerColumnsState extends State<MonthYearPickerColumns> {
  /// Live positions — what the two columns point at right now. They reach the
  /// calendar only when a row is tapped.
  late int _month = widget.month;
  late int _year = widget.year;

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context).localeName;
    return Center(
      child: SizedBox(
        height: monthYearPickerHeight,
        child: Row(
          children: [
            Expanded(
              child: _PickerColumn(
                key: monthYearPickerMonthColumnKey,
                labels: [
                  for (var m = 1; m <= 12; m++)
                    intl.DateFormat(
                      'MMMM',
                      locale,
                    ).format(DateTime(2023, m, 1)),
                ],
                selectedIndex: _month - 1,
                onChanged: (index) => setState(() => _month = index + 1),
                onRowTapped: (index) => widget.onPicked(index + 1, _year),
              ),
            ),
            Expanded(
              child: _PickerColumn(
                key: monthYearPickerYearColumnKey,
                labels: [
                  for (var y = widget.firstYear; y <= widget.lastYear; y++)
                    AppDateUtils.formatDigits(y, locale, grouping: false),
                ],
                selectedIndex: (_year - widget.firstYear).clamp(
                  0,
                  widget.lastYear - widget.firstYear,
                ),
                onChanged: (index) =>
                    setState(() => _year = widget.firstYear + index),
                onRowTapped: (index) =>
                    widget.onPicked(_month, widget.firstYear + index),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One column of [MonthYearPickerColumns]: a straight, snapping list of labels
/// whose middle row is the current value.
class _PickerColumn extends StatefulWidget {
  /// Every label of the column, top to bottom.
  final List<String> labels;

  /// Index of the row that starts out in the middle.
  final int selectedIndex;

  /// Reports the row that has moved into the middle.
  final ValueChanged<int> onChanged;

  /// Confirms the pair, carrying the tapped row's index.
  final ValueChanged<int> onRowTapped;

  const _PickerColumn({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    required this.onRowTapped,
  });

  @override
  State<_PickerColumn> createState() => _PickerColumnState();
}

class _PickerColumnState extends State<_PickerColumn> {
  /// Opens on [widget.selectedIndex] and then belongs to the user: a live spin
  /// must survive the rebuilds its own onChanged triggers.
  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: widget.selectedIndex);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: _controller,
      physics: const FixedExtentScrollPhysics(),
      itemExtent: monthYearPickerRowExtent,
      // Flattened: an almost flat cylinder still snaps, which is the part of the
      // iOS wheel this list wants; the curvature is not.
      diameterRatio: _flatDiameterRatio,
      squeeze: _flatSqueeze,
      // A wheel magnifies the middle row and dims the rows around it; a straight
      // list draws every label at its own size and at full strength.
      useMagnifier: false,
      overAndUnderCenterOpacity: 1,
      onSelectedItemChanged: widget.onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: widget.labels.length,
        builder: (context, index) => GestureDetector(
          // A tap confirms here rather than spinning the list to the row, so one
          // tap always means one choice.
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onRowTapped(index),
          child: Center(
            // The app's own text colour, undimmed: the current row is told apart
            // by weight, not by size or opacity.
            child: Text(
              widget.labels[index],
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.onSurface,
                fontWeight: index == widget.selectedIndex
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
