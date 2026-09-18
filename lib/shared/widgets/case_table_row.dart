/// The extended ("table") case view: an Excel-like grid of one row per case.
///
/// The compact card shows a case as a stack of labelled lines. The table shows
/// the same data as columns — one field per column, one line per cell — with a
/// single header row above the rows and no per-cell labels. Column widths are
/// owned by [CaseTableView] (feature layer), dragged from the header's rules
/// and stored per user, so this file only renders what it is handed.
library;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/utils/date_utils.dart';

/// The columns of the extended view, in the order they render.
///
/// The name of each value is its stable id in the stored width map, so
/// reordering this enum is a data migration: keep the names.
enum CaseTableColumn {
  /// Running position of the row in the list the screen is showing.
  serial,

  /// Hosts the Update (quick-update) action.
  update,

  /// The screen's own date — Next Date, Previous Date or Disposed.
  date,

  /// Name of the court, with the judges' name appended for higher courts.
  court,

  /// Localized case type, e.g. "Civil Suit".
  caseType,

  /// Case number as typed.
  caseNumber,

  /// Petitioner.
  petitioner,

  /// Respondent.
  respondent,

  /// On-behalf role of the user.
  onBehalf,

  /// Last step (or AD/HCD result).
  step,

  /// Notes / results free text.
  note,
}

/// Every column, in render order.
const List<CaseTableColumn> caseTableColumnOrder = CaseTableColumn.values;

/// The columns a screen renders, in render order, minus any it excludes.
///
/// A screen that shows the court as a group heading passes
/// `{CaseTableColumn.court}` so the name is not repeated in every row, and
/// Overdue Dates — which folds the step into its date cell — also excludes
/// `CaseTableColumn.step` so the table keeps exactly the columns it shows.
List<CaseTableColumn> caseTableColumns({
  Set<CaseTableColumn> exclude = const {},
}) => <CaseTableColumn>[
  for (final column in caseTableColumnOrder)
    if (!exclude.contains(column)) column,
];

/// Built-in column widths, used until the user drags a rule.
const Map<CaseTableColumn, double> _defaultWidths = <CaseTableColumn, double>{
  CaseTableColumn.serial: 64,
  CaseTableColumn.update: 84,
  CaseTableColumn.court: 220,
  CaseTableColumn.caseType: 150,
  CaseTableColumn.caseNumber: 160,
  CaseTableColumn.petitioner: 180,
  CaseTableColumn.respondent: 180,
  CaseTableColumn.onBehalf: 130,
  CaseTableColumn.step: 170,
  CaseTableColumn.note: 220,
  CaseTableColumn.date: 130,
};

/// Narrowest a column may be dragged, per column.
const Map<CaseTableColumn, double> _minWidths = <CaseTableColumn, double>{
  CaseTableColumn.serial: 48,
  CaseTableColumn.update: 64,
  CaseTableColumn.court: 96,
  CaseTableColumn.caseType: 80,
  CaseTableColumn.caseNumber: 96,
  CaseTableColumn.petitioner: 96,
  CaseTableColumn.respondent: 96,
  CaseTableColumn.onBehalf: 80,
  CaseTableColumn.step: 96,
  CaseTableColumn.note: 96,
  CaseTableColumn.date: 88,
};

/// Widest a column may be dragged.
const double caseTableMaxColumnWidth = 640.0;

/// Width of one inter-column rule, including its grab area either side.
const double caseTableDividerWidth = 17.0;

/// The 4 px lane every row and the header reserve on the left.
///
/// Rows paint it red when they are overdue; every other row leaves it empty.
/// Reserving it unconditionally is what keeps the header's cells and the data
/// cells in the same place.
const double caseTableStripWidth = 4.0;

/// Narrowest allowed width of [column].
double caseTableMinColumnWidth(CaseTableColumn column) => _minWidths[column]!;

/// The user's stored widths, falling back to the defaults.
///
/// Unknown keys are ignored (a column removed in a later release leaves nothing
/// behind) and every value is clamped to its column's range, so a corrupt row
/// cannot make a column unusable.
Map<CaseTableColumn, double> resolveCaseTableWidths(
  Map<String, dynamic> stored,
) {
  final widths = Map<CaseTableColumn, double>.from(_defaultWidths);
  for (final column in caseTableColumnOrder) {
    final value = stored[column.name];
    if (value is! num) continue;
    widths[column] = value.toDouble().clamp(
      caseTableMinColumnWidth(column),
      caseTableMaxColumnWidth,
    );
  }
  return widths;
}

/// The stored (JSON) form of [widths], keyed by the columns' stable names.
Map<String, double> caseTableStoredWidths(
  Map<CaseTableColumn, double> widths,
) => {for (final entry in widths.entries) entry.key.name: entry.value};

/// Minimum body width the table needs so no column is squeezed.
///
/// Adds, on top of the columns, the rules between them and the fixed chrome of
/// the header and the rows: the 2 px card border, the 4 px strip lane and the
/// 12 px gutter either side, plus the 16 px screen margin the body already
/// applies. The header and the rows are laid out to exactly this width, which
/// is what makes their columns line up.
double caseTableMinimumWidth(
  List<CaseTableColumn> columns,
  Map<CaseTableColumn, double> widths,
) {
  final cells = columns.fold<double>(0, (sum, column) => sum + widths[column]!);
  return AppSpacing.md * 2 +
      2 +
      caseTableStripWidth +
      AppSpacing.gutter * 2 +
      cells +
      caseTableDividerWidth * (columns.length - 1);
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

/// The single header row above the table's data rows.
///
/// Its labels name the columns once, so each data row shows values only. Every
/// rule between two labels doubles as the column's resize handle: drag it and
/// [onResizeDelta] reports the horizontal delta for that column, then
/// [onResizeEnd] fires once the drag finishes so the host can store the size.
class CaseTableHeader extends StatelessWidget {
  /// Current width of every column, in logical pixels.
  final Map<CaseTableColumn, double> widths;

  /// The columns this screen shows, in render order. A screen that keeps the
  /// court as a group heading omits [CaseTableColumn.court] here so no empty
  /// column is drawn under a header for it.
  final List<CaseTableColumn> columns;

  /// Label of the date column, which each screen names for itself ("Next
  /// Date", "Previous Date", "Previous Date & Step" or "Disposed").
  final String dateLabel;

  /// Called while a rule is dragged, with the column to its left.
  final void Function(CaseTableColumn column, double delta)? onResizeDelta;

  /// Called once a resize drag finishes.
  final VoidCallback? onResizeEnd;

  /// Creates the table header row.
  const CaseTableHeader({
    required this.widths,
    this.columns = caseTableColumnOrder,
    required this.dateLabel,
    this.onResizeDelta,
    this.onResizeEnd,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final labels = <CaseTableColumn, String>{
      CaseTableColumn.serial: l.caseTable_serial,
      CaseTableColumn.update: l.allCasesScreen_update,
      CaseTableColumn.court: l.addEditCaseSheet_nameOfCourt,
      CaseTableColumn.caseType: l.allCasesScreen_caseType,
      CaseTableColumn.caseNumber: l.addEditCaseSheet_caseNumber,
      CaseTableColumn.petitioner: l.addEditCaseSheet_petitioner,
      CaseTableColumn.respondent: l.addEditCaseSheet_respondent,
      CaseTableColumn.onBehalf: l.allCasesScreen_onBehalf,
      CaseTableColumn.step: l.caseCard_lastStep,
      CaseTableColumn.note: l.addEditCaseSheet_note,
      CaseTableColumn.date: dateLabel,
    };

    final children = <Widget>[];
    for (var i = 0; i < columns.length; i++) {
      final column = columns[i];
      children.add(
        SizedBox(
          width: widths[column],
          child: Text(
            labels[column]!,
            key: ValueKey('case-table-header-${column.name}'),
            style: AppTypography.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
      if (i != columns.length - 1) {
        children.add(
          _ColumnResizeHandle(
            column: column,
            onDelta: onResizeDelta,
            onDragEnd: onResizeEnd,
          ),
        );
      }
    }

    return _TableFrame(
      key: const ValueKey('case-table-header'),
      background: AppColors.surfaceContainerLow,
      roundedLeft: true,
      child: Row(children: children),
    );
  }
}

/// The rule between two header cells, draggable to resize the column on its
/// left.
class _ColumnResizeHandle extends StatelessWidget {
  final CaseTableColumn column;
  final void Function(CaseTableColumn column, double delta)? onDelta;
  final VoidCallback? onDragEnd;

  const _ColumnResizeHandle({
    required this.column,
    required this.onDelta,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final rule = Center(
      child: Container(width: 1, height: 20, color: AppColors.outlineVariant),
    );
    if (onDelta == null) {
      return SizedBox(width: caseTableDividerWidth, child: rule);
    }
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        key: ValueKey('case-table-resize-${column.name}'),
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => onDelta!(column, details.delta.dx),
        onHorizontalDragEnd: (_) => onDragEnd?.call(),
        child: SizedBox(width: caseTableDividerWidth, child: rule),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Row
// ---------------------------------------------------------------------------

/// One case laid out as a single line of the table.
///
/// Every cell is a fixed-width column of the shared width map, so a row lines
/// up with the header and with every other row. The card chrome is unchanged:
/// the white surface, the border, the rounded corners and — for an overdue
/// case — the red left strip.
class CaseTableRow extends StatelessWidget {
  /// Current width of every column, in logical pixels.
  final Map<CaseTableColumn, double> widths;

  /// The columns this screen shows, in render order, matching the header it is
  /// drawn under. A screen that keeps the court as a group heading omits
  /// [CaseTableColumn.court].
  final List<CaseTableColumn> columns;

  /// 1-based position of the case in the list the screen is showing, rendered
  /// in the active language's digits.
  final int serial;

  /// Name of the court, resolved to the active language by the caller.
  final String? courtName;

  /// Honorable judges' name, appended to the court cell for AD/HCD cases.
  final String? judgesName;

  /// Localized case type, e.g. "Civil Suit".
  final String caseType;

  /// Case number as typed.
  final String caseNumber;

  /// Petitioner.
  final String petitioner;

  /// Respondent.
  final String respondent;

  /// On-behalf role of the user, resolved to the active language.
  final String? onBehalf;

  /// Last step, or the AD/HCD result when the screen shows that instead.
  final String? step;

  /// Notes / results free text.
  final String? note;

  /// The screen's own date for this case — next hearing date, previous hearing
  /// date, or disposal date. `null` leaves the cell empty.
  final String? date;

  /// Whether this case is overdue: draws the red left strip and the red date.
  final bool isOverdue;

  /// Whether the date cell also shows [step] beneath the date.
  ///
  /// Overdue Dates has no Step column of its own, so it folds the step into
  /// its "Previous Date & Step" cell instead of dropping it.
  final bool dateShowsStep;

  /// Called by the Update action, when supplied.
  final VoidCallback? onUpdate;

  /// Called when the whole row is tapped (opens the case detail screen).
  final VoidCallback? onTap;

  /// Creates an extended-view case row.
  const CaseTableRow({
    required this.widths,
    this.columns = caseTableColumnOrder,
    required this.serial,
    required this.caseType,
    required this.caseNumber,
    required this.petitioner,
    required this.respondent,
    this.courtName,
    this.judgesName,
    this.onBehalf,
    this.step,
    this.note,
    this.date,
    this.isOverdue = false,
    this.dateShowsStep = false,
    this.onUpdate,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final court = _join([courtName, judgesName]);

    final children = <Widget>[];
    for (var i = 0; i < columns.length; i++) {
      final column = columns[i];
      children.add(
        SizedBox(
          width: widths[column],
          child: KeyedSubtree(
            key: ValueKey('case-table-cell-${column.name}'),
            child: _cell(context, l, column, court: court),
          ),
        ),
      );
      if (i != columns.length - 1) {
        children.add(const _RowDivider());
      }
    }

    return _TableFrame(
      background: AppColors.surfaceContainerLowest,
      roundedLeft: !isOverdue,
      showStrip: isOverdue,
      onTap: onTap,
      child: IntrinsicHeight(child: Row(children: children)),
    );
  }

  /// Builds one column's value.
  ///
  /// Every data cell uses the same [AppTypography.bodyMd] font and size as the
  /// Name of Court cell, so the row reads as one grid rather than a mix of
  /// roles; only the colour carries meaning (the muted serial, the red overdue
  /// date). The black case number is deliberate: in the compact card it is a
  /// link-blue accent, but in the table it is plain data like its neighbours.
  Widget _cell(
    BuildContext context,
    AppLocalizations l,
    CaseTableColumn column, {
    required String court,
  }) {
    switch (column) {
      case CaseTableColumn.serial:
        return _DataCell(
          text: AppDateUtils.formatDigits(serial, l.localeName),
          textKey: const ValueKey('case-row-serial'),
          style: AppTypography.bodyMd.copyWith(color: AppColors.outline),
          align: TextAlign.center,
        );
      case CaseTableColumn.update:
        return _UpdateCell(l: l, onUpdate: onUpdate);
      case CaseTableColumn.date:
        return _DataCell(
          text: date ?? '',
          subText: dateShowsStep ? step : null,
          style: AppTypography.bodyMd.copyWith(
            color: isOverdue ? AppColors.error : AppColors.onSurface,
          ),
          subStyle: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
        );
      case CaseTableColumn.court:
        return _DataCell(text: court, style: AppTypography.bodyMd);
      case CaseTableColumn.caseType:
        return _DataCell(text: caseType, style: AppTypography.bodyMd);
      case CaseTableColumn.caseNumber:
        return _DataCell(
          text: caseNumber,
          style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
        );
      case CaseTableColumn.petitioner:
        return _DataCell(text: petitioner, style: AppTypography.bodyMd);
      case CaseTableColumn.respondent:
        return _DataCell(text: respondent, style: AppTypography.bodyMd);
      case CaseTableColumn.onBehalf:
        return _DataCell(
          text: onBehalf ?? '',
          textKey: const ValueKey('case-row-status-label'),
          style: AppTypography.bodyMd,
        );
      case CaseTableColumn.step:
        return _DataCell(text: step ?? '', style: AppTypography.bodyMd);
      case CaseTableColumn.note:
        return _DataCell(
          text: note ?? '',
          textKey: const ValueKey('case-row-note'),
          style: AppTypography.bodyMd,
        );
    }
  }
}

/// Joins the parts that share one cell, skipping blanks.
String _join(List<String?> parts) => parts
    .map((part) => part?.trim() ?? '')
    .where((part) => part.isNotEmpty)
    .join(' · ');

// ---------------------------------------------------------------------------
// Cells and chrome
// ---------------------------------------------------------------------------

/// The fixed-width, single-line body of one column.
///
/// `maxLines: 1` with `softWrap: false` is the "each cell is one line" rule:
/// a value too long for its column ellipsises rather than wrapping, and the
/// user widens the column to read it.
class _DataCell extends StatelessWidget {
  final String text;

  /// Optional second line shown under [text] (the step, in Overdue Dates'
  /// combined "Previous Date & Step" cell). Blank means no second line.
  final String? subText;
  final TextStyle style;

  /// Style of the second line; falls back to [style].
  final TextStyle? subStyle;
  final TextAlign align;

  /// Key placed on the value itself, so a test can read the rendered text.
  final Key? textKey;

  const _DataCell({
    required this.text,
    this.subText,
    required this.style,
    this.subStyle,
    this.align = TextAlign.start,
    this.textKey,
  });

  @override
  Widget build(BuildContext context) {
    final alignment = align == TextAlign.center
        ? Alignment.center
        : Alignment.centerLeft;
    final sub = subText?.trim();
    final line = Text(
      text,
      key: textKey,
      style: style,
      textAlign: align,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );
    if (sub == null || sub.isEmpty) {
      return Align(alignment: alignment, child: line);
    }
    return Align(
      alignment: alignment,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: align == TextAlign.center
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          line,
          Text(
            sub,
            style: subStyle ?? style,
            textAlign: align,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// The Update action, sized to the Update column.
class _UpdateCell extends StatelessWidget {
  final AppLocalizations l;
  final VoidCallback? onUpdate;

  const _UpdateCell({required this.l, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: IconButton(
        key: const ValueKey('case-row-update'),
        tooltip: l.allCasesScreen_update,
        onPressed: onUpdate,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.edit_outlined, size: 20),
      ),
    );
  }
}

/// The vertical rule between two row cells.
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: caseTableDividerWidth,
    child: Center(
      child: VerticalDivider(width: 1, color: AppColors.outlineVariant),
    ),
  );
}

/// Shared chrome of a header row and a data row.
///
/// Both reserve the same 4 px strip lane on the left and the same gutter inside
/// the border, so their cells start at the same x. Only a data row paints the
/// lane (red, when overdue).
class _TableFrame extends StatelessWidget {
  final Widget child;
  final Color background;
  final bool roundedLeft;
  final bool showStrip;
  final VoidCallback? onTap;

  const _TableFrame({
    required this.child,
    required this.background,
    required this.roundedLeft,
    this.showStrip = false,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        if (showStrip)
          Container(
            key: const ValueKey('case-row-overdue-strip'),
            width: caseTableStripWidth,
            color: AppColors.error,
          )
        else
          const SizedBox(width: caseTableStripWidth),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: child,
          ),
        ),
      ],
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: _rowRadius(!roundedLeft),
      ),
      // The tap target sits inside the frame so the ink stays on top of the
      // row's own background, and the row's card chrome is drawn once here
      // rather than re-declared by the interactive and plain variants.
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(onTap: onTap, child: content),
            ),
    );
  }
}

/// The card corners: squared on the left when the red strip is drawn against
/// them, rounded otherwise, and always rounded on the right — the shape the
/// compact card uses.
BorderRadius _rowRadius(bool squaredLeft) => BorderRadius.only(
  topLeft: Radius.circular(squaredLeft ? 0 : AppSpacing.cardRadius),
  bottomLeft: Radius.circular(squaredLeft ? 0 : AppSpacing.cardRadius),
  topRight: const Radius.circular(AppSpacing.cardRadius),
  bottomRight: const Radius.circular(AppSpacing.cardRadius),
);
