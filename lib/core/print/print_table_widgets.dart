/// The ruled-table renderer: the bordered grid the case-list printouts use.
///
/// A [PrintDocument] whose [PrintDocument.columns] is non-null prints as this
/// table instead of the heading-and-fields body of `print_widgets.dart`. The
/// layout is fixed by the sample the user supplied: eight columns of fixed
/// width in centimetres, a fixed minimum row height that grows when a cell
/// wraps, a court-group row that spans the table, and a thin spacer row between
/// court groups.
///
/// Two things make it different from the free-flowing body it replaces:
///
/// * **Rows are the blocks.** Each row is one block, so pagination (which
///   measures blocks) can only ever break *between* rows — a row is never split
///   across a page.
/// * **The header band repeats.** [buildTablePageHeader] — logo, app title,
///   screen title, the Daily Cause List's date line and the bordered column
///   headings — is page furniture drawn on every page by the capture, not a
///   block drawn once. The capture measures it and subtracts its height.
library;

import 'package:flutter/widgets.dart';

import 'print_document.dart';
import 'print_widgets.dart';

/// Converts a length in centimetres to points (72 pt to the inch).
double printCm(double cm) => cm * 72 / 2.54;

/// Resolution a ruled table is captured at, in dots per inch.
///
/// 300 dpi is the print standard and 600 is where text stops improving on
/// paper; the user asked for 300 at least and 600 if possible, and accepted the
/// larger file. 600 dpi on A4 is ~139 MB of decoded RGBA **per page** while the
/// page is being captured (one page at a time, then encoded and released), which
/// is the ceiling this buys into — drop to 300 (`300.0`) if a low-memory device
/// ever fails a print.
const double kPrintTargetDpi = 600;

/// Pixel ratio that renders one point at [kPrintTargetDpi].
final double kPrintTablePixelRatio = kPrintTargetDpi / 72;

/// Ceiling on one page's decoded RGBA bytes at [kPrintTablePixelRatio].
///
/// 600 dpi on A4 needs ~139 MB; the cap sits just above that so the target is
/// actually reached, while the budget solver still trims on a smaller page.
const int kPrintTableMaxRgbaBytes = 170 * 1024 * 1024;

/// Sizes and colours of the ruled table.
abstract final class PrintTableStyle {
  /// The minimum height of a data row (the sample's 0.90 cm).
  static final double rowMinHeight = printCm(0.90);

  /// The height of the thin spacer row between court groups (0.29 cm).
  static final double spacerHeight = printCm(0.29);

  /// Cell border: a hairline, black, drawn on the right and bottom of each cell
  /// (plus the left of the first column and the top of the header row) so every
  /// shared edge is a single line rather than two.
  static const double borderWidth = 0.5;
  static const Color borderColor = PrintStyle.ink;

  /// Space inside a cell, kept tight so the narrow columns hold their text.
  static const EdgeInsets cellPadding = EdgeInsets.symmetric(
    horizontal: 2,
    vertical: 1,
  );

  /// A data cell's text.
  static const TextStyle cell = TextStyle(
    inherit: false,
    fontFamily: 'Inter',
    fontFamilyFallback: ['TiroBangla'],
    fontSize: 9.2,
    height: 1.25,
    color: PrintStyle.ink,
  );

  /// A column heading (the sample draws it a little smaller and bold).
  static const TextStyle header = TextStyle(
    inherit: false,
    fontFamily: 'Inter',
    fontFamilyFallback: ['TiroBangla'],
    fontSize: 8.3,
    height: 1.2,
    color: PrintStyle.ink,
    fontWeight: FontWeight.w700,
  );

  /// A court-group heading.
  static const TextStyle court = cell;

  /// The app brand line beside the logo.
  static const TextStyle brand = cell;

  /// The screen title (the page's headline): bold and underlined, centred over
  /// the table.
  static const TextStyle screenTitle = TextStyle(
    inherit: false,
    fontFamily: 'Inter',
    fontFamilyFallback: ['TiroBangla'],
    fontSize: 13,
    height: 1.2,
    color: PrintStyle.ink,
    fontWeight: FontWeight.w700,
    decoration: TextDecoration.underline,
  );

  /// The Daily Cause List's Date/Day/Month/Year line.
  static const TextStyle dateLine = cell;

  /// Side of the logo in the header band (the sample's ~18 pt square).
  static const double logoSize = 18;

  /// Gap between the screen title and the column headings when the band carries
  /// **no** date line — a screen without a date gets a little more air so the
  /// titled band does not crowd the table.
  static const double titleToTableGap = 10;

  /// Gap between the date line and the column headings.
  static const double dateLineToTableGap = 3;
}

/// One side of the cell border, or null where the edge is shared with the
/// neighbouring cell and must not be drawn twice.
BorderSide _side(bool on) =>
    on ? const BorderSide(width: PrintTableStyle.borderWidth, color: PrintTableStyle.borderColor) : BorderSide.none;

/// One bordered cell of fixed width.
///
/// Every cell draws its own **top** border, so no row can end up with an open
/// top edge — a data row at the top of a page, a court row after a spacer, or
/// the first column on any page. Adjacent rows' edges meet on the same line, so
/// the grid still reads as single hairlines.
Widget buildTableCell({
  required String text,
  required PrintTableColumn column,
  required bool isFirst,
  required bool isHeader,
  bool isLast = false,
}) {
  // Headings are centred whatever the column's own alignment (user request);
  // data cells follow the column.
  final alignment = isHeader
      ? TextAlign.center
      : switch (column.align) {
          PrintColumnAlign.center => TextAlign.center,
          PrintColumnAlign.start => TextAlign.start,
        };
  return SizedBox(
    width: printCm(column.widthCm),
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: _side(true),
          left: _side(isFirst),
          right: _side(true),
          bottom: _side(true),
        ),
      ),
      child: Padding(
        padding: PrintTableStyle.cellPadding,
        child: Text(
          text,
          style: isHeader ? PrintTableStyle.header : PrintTableStyle.cell,
          textAlign: alignment,
          softWrap: true,
        ),
      ),
    ),
  );
}

/// The bordered column-heading row.
Widget buildTableHeaderRow(List<PrintTableColumn> columns) => IntrinsicHeight(
  child: ConstrainedBox(
    constraints: BoxConstraints(minHeight: PrintTableStyle.rowMinHeight),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < columns.length; i++)
          buildTableCell(
            text: columns[i].label,
            column: columns[i],
            isFirst: i == 0,
            isHeader: true,
          ),
      ],
    ),
  ),
);

/// One data row: a bordered cell per column, all as tall as the tallest.
Widget buildTableDataRow(
  PrintTableRow row,
  List<PrintTableColumn> columns,
) => IntrinsicHeight(
  child: ConstrainedBox(
    constraints: BoxConstraints(minHeight: PrintTableStyle.rowMinHeight),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < columns.length; i++)
          buildTableCell(
            text: i < row.cells.length ? row.cells[i] : '',
            column: columns[i],
            isFirst: i == 0,
            isHeader: false,
          ),
      ],
    ),
  ),
);

/// A court-group row: one centred strip across the whole table width.
Widget buildTableCourtRow(String heading, double tableWidth) =>
    ConstrainedBox(
      constraints: BoxConstraints(minHeight: PrintTableStyle.rowMinHeight),
      child: SizedBox(
        width: tableWidth,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(
                width: PrintTableStyle.borderWidth,
                color: PrintTableStyle.borderColor,
              ),
              left: BorderSide(
                width: PrintTableStyle.borderWidth,
                color: PrintTableStyle.borderColor,
              ),
              right: BorderSide(
                width: PrintTableStyle.borderWidth,
                color: PrintTableStyle.borderColor,
              ),
              bottom: BorderSide(
                width: PrintTableStyle.borderWidth,
                color: PrintTableStyle.borderColor,
              ),
            ),
          ),
          child: Padding(
            padding: PrintTableStyle.cellPadding,
            child: Center(
              child: Text(heading, style: PrintTableStyle.court, textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );

/// The table's full width in points (the sum of its fixed columns).
double tableWidthOf(List<PrintTableColumn> columns) =>
    columns.fold(0, (total, column) => total + printCm(column.widthCm));

/// One row of the table as a page block.
///
/// Court headings and data rows are bordered; a spacer is a bare gap. The
/// heading needs the table width, which is why it is passed in.
Widget buildTableRowBlock(
  PrintTableRow row,
  List<PrintTableColumn> columns,
) => switch (row.kind) {
  PrintTableRowKind.court => buildTableCourtRow(
    row.cells.isEmpty ? '' : row.cells.first,
    tableWidthOf(columns),
  ),
  PrintTableRowKind.data => buildTableDataRow(row, columns),
  PrintTableRowKind.spacer => SizedBox(height: PrintTableStyle.spacerHeight),
};

/// The header band drawn on **every** page of a table printout.
///
/// The logo, the app brand line and the screen title on one row (the title
/// centred over the table), the optional date line beneath, then the bordered
/// column headings.
Widget buildTablePageHeader(
  PrintDocument document,
  List<PrintTableColumn> columns,
) {
  final hasDateLine = document.dateLine.trim().isNotEmpty;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // The title is centred **over the whole table** (user request), with the
      // logo and brand line sitting at the left rather than pushing it right.
      Stack(
        alignment: Alignment.center,
        children: [
          Text(
            document.title,
            style: PrintTableStyle.screenTitle,
            textAlign: TextAlign.center,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (document.logoAsset != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Image.asset(
                      document.logoAsset!,
                      width: PrintTableStyle.logoSize,
                      height: PrintTableStyle.logoSize,
                      fit: BoxFit.contain,
                      // A missing asset must not take the whole printout down;
                      // the band simply carries no logo.
                      errorBuilder: (context, error, stack) => const SizedBox(
                        width: PrintTableStyle.logoSize,
                        height: PrintTableStyle.logoSize,
                      ),
                    ),
                  ),
                if (document.brandTitle.trim().isNotEmpty)
                  Text(document.brandTitle, style: PrintTableStyle.brand),
              ],
            ),
          ),
        ],
      ),
      if (hasDateLine) ...[
        const SizedBox(height: 2),
        Center(
          child: Text(
            document.dateLine,
            style: PrintTableStyle.dateLine,
            textAlign: TextAlign.center,
          ),
        ),
      ],
      // A screen without a date line gets a little more air before the table.
      SizedBox(
        height: hasDateLine
            ? PrintTableStyle.dateLineToTableGap
            : PrintTableStyle.titleToTableGap,
      ),
      buildTableHeaderRow(columns),
    ],
  );
}
