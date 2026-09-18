/// Hosts the extended ("table") case view: the header row, the horizontal
/// scroll that keeps the header aligned with the rows, and the column widths.
///
/// Widths are the one piece of table state the user owns: they are read from
/// the stored per-user settings when the screen opens, updated live while a
/// header rule is dragged, and written back when the drag ends. A screen only
/// supplies the rows, so no screen has to know how a column is sized.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../shared/widgets/case_table_row.dart';
import 'case_list_view_mode.dart';

/// The extended case view: one header row over the screen's own rows.
class CaseTableView extends ConsumerStatefulWidget {
  /// The columns this screen shows, in render order. Defaults to every column;
  /// a screen that shows the court as a group heading passes a list without
  /// [CaseTableColumn.court], and Overdue Dates also drops the Step column
  /// because it folds the step into its date cell.
  final List<CaseTableColumn> columns;

  /// Label of the date column, named by the host screen ("Next Date", "Previous
  /// Date", "Previous Date & Step" or "Disposed").
  final String dateLabel;

  /// Builds the vertically scrolling body — court groups, date headers and rows
  /// — at the table's exact width. The rows must be built with the widths it is
  /// handed so their columns line up with the header.
  final Widget Function(
    BuildContext context,
    Map<CaseTableColumn, double> widths,
  )
  builder;

  /// Creates the extended-view host.
  const CaseTableView({
    this.columns = caseTableColumnOrder,
    required this.dateLabel,
    required this.builder,
    super.key,
  });

  @override
  ConsumerState<CaseTableView> createState() => _CaseTableViewState();
}

class _CaseTableViewState extends ConsumerState<CaseTableView> {
  /// The widths in use. Seeded with the defaults so the first frame is already
  /// a table; replaced by the stored widths as soon as they load.
  Map<CaseTableColumn, double> _widths = resolveCaseTableWidths(const {});

  /// Set once the user drags a rule. From then on the live widths win, so a
  /// slow settings read can never fight the drag in progress.
  bool _resized = false;

  @override
  void initState() {
    super.initState();
    _loadStoredWidths();
  }

  /// Opens the table at the sizes the user last left it in; an install that has
  /// never dragged a rule keeps the built-in defaults.
  Future<void> _loadStoredWidths() async {
    try {
      final repo = await ref.read(settingsRepositoryProvider.future);
      final stored = (await repo.getSettings()).caseTableColumnWidths;
      if (!mounted || _resized) return;
      setState(() => _widths = resolveCaseTableWidths(stored));
    } catch (_) {
      // A failed read leaves the defaults in place rather than breaking the
      // list: the column sizes are a convenience, not data.
    }
  }

  /// Applies one resize delta to [column], clamped to the column's range.
  void _resize(CaseTableColumn column, double delta) {
    if (delta == 0) return;
    final current = _widths[column]!;
    final next = (current + delta).clamp(
      caseTableMinColumnWidth(column),
      caseTableMaxColumnWidth,
    );
    if (next == current) return;
    setState(() {
      _resized = true;
      _widths = {..._widths, column: next};
    });
  }

  /// Stores the widths the drag settled on.
  Future<void> _persist() =>
      setCaseTableColumnWidths(ref, caseTableStoredWidths(_widths));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minimum = caseTableMinimumWidth(widget.columns, _widths);
        final width = minimum > constraints.maxWidth
            ? minimum
            : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    0,
                  ),
                  child: CaseTableHeader(
                    widths: _widths,
                    columns: widget.columns,
                    dateLabel: widget.dateLabel,
                    onResizeDelta: _resize,
                    onResizeEnd: _persist,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(child: widget.builder(context, _widths)),
              ],
            ),
          ),
        );
      },
    );
  }
}
