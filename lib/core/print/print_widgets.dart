/// Print-only Flutter widgets: the raster renderer of a [PrintDocument].
///
/// This is the second renderer of the same model and the one Bengali content
/// needs, because `pdf` 3.13.0 has no Indic shaper while Flutter's own text
/// stack shapes Bengali correctly (HarfBuzz). The blocks are deliberately
/// fine-grained — a heading, one field row, a rule — because [PrintPageCapture]
/// paginates by measuring these very blocks, and a block taller than a page
/// could not be split across pages.
///
/// The type is fixed rather than themed: a printout is paper, so a dark theme
/// must not tint it. Latin runs use the project's English families, and every
/// style falls back to Tiro Bangla so Bengali is drawn with the font the plan
/// requires whichever language the UI is in.
///
/// Every style is `inherit: false`, and that is load-bearing rather than
/// cosmetic. The capture is drawn outside any `Material` — it is a sibling of
/// the progress dialog, not a child of it — so the ambient [DefaultTextStyle]
/// is `MaterialApp`'s fallback "put this text in a Material" style, whose
/// decoration is a **double underline in `#FFFF00`**. A `TextStyle` that leaves
/// `decoration` unset is *merged* with that ambient style and keeps its
/// decoration, so every printed line came out double-underlined in yellow on
/// the page image, and nothing in a theme could take it off. A non-inheriting
/// style ignores the ambient style entirely, so what is printed is exactly what
/// is declared here.
library;

import 'package:flutter/widgets.dart';

import 'print_document.dart';
import 'print_page_capture.dart';
import 'print_table_widgets.dart';

/// Sizes, families and colours of a printed page (points, one logical pixel to
/// one point at the capture's pixel ratio).
abstract final class PrintStyle {
  /// Document title.
  static const TextStyle title = TextStyle(
    inherit: false,
    fontFamily: 'Manrope',
    fontFamilyFallback: _bengali,
    fontSize: 25,
    height: 1.3,
    color: ink,
    fontWeight: FontWeight.w600,
  );

  /// Dataset description under the title.
  static const TextStyle subtitle = TextStyle(
    inherit: false,
    fontFamily: 'Inter',
    fontFamilyFallback: _bengali,
    fontSize: 13,
    height: 1.4,
    color: muted,
  );

  /// A group heading (court or date).
  static const TextStyle groupHeading = TextStyle(
    inherit: false,
    fontFamily: 'Manrope',
    fontFamilyFallback: _bengali,
    fontSize: 18,
    height: 1.3,
    color: ink,
    fontWeight: FontWeight.w600,
  );

  /// An entry's primary line (case number and case type).
  static const TextStyle entryHeading = TextStyle(
    inherit: false,
    fontFamily: 'IBMPlexSans',
    fontFamilyFallback: _bengali,
    fontSize: 16,
    height: 1.35,
    color: ink,
    fontWeight: FontWeight.w600,
  );

  /// A field's value.
  static const TextStyle value = TextStyle(
    inherit: false,
    fontFamily: 'Inter',
    fontFamilyFallback: _bengali,
    fontSize: 14,
    height: 1.4,
    color: ink,
  );

  /// A field's label.
  static const TextStyle label = TextStyle(
    inherit: false,
    fontFamily: 'IBMPlexSans',
    fontFamilyFallback: _bengali,
    fontSize: 12,
    height: 1.4,
    color: muted,
  );

  /// A header fact (`Date range: …`).
  static const TextStyle meta = TextStyle(
    inherit: false,
    fontFamily: 'Inter',
    fontFamilyFallback: _bengali,
    fontSize: 13,
    height: 1.4,
    color: muted,
  );

  /// The page footer and page counter.
  static const TextStyle footer = TextStyle(
    inherit: false,
    fontFamily: 'Inter',
    fontFamilyFallback: _bengali,
    fontSize: 12,
    height: 1.4,
    color: muted,
  );

  /// Primary ink.
  static const Color ink = Color(0xFF0F172A);

  /// Secondary ink.
  static const Color muted = Color(0xFF475569);

  /// The page itself: opaque white, and the reason it is here rather than left
  /// transparent is that a captured page *is* paper. Capturing on nothing
  /// leaves the image ~99% transparent, and the PDF then carries an alpha mask
  /// whose misreading by a viewer or a print driver shows up on exactly the
  /// thin dark strokes of a page — a doubled, tinted line. An opaque page has
  /// no mask to misread.
  static const Color page = Color(0xFFFFFFFF);

  /// Width of a field's label column.
  ///
  /// Scaled with the label (92 pt at the old 7 pt label); at the current 12 pt
  /// it keeps the longest label (`Respondent's Lead Counsel`) on one line, so a
  /// bigger type does not turn every field row into two label lines.
  static const double labelColumnWidth = 158;

  static const List<String> _bengali = ['TiroBangla'];
}

/// The document's blocks in reading order.
///
/// The page's own footer and page counter are **not** blocks: they are page
/// furniture, drawn per page by [buildPrintPage]. A ruled-table document's
/// header band is furniture too — [buildTablePageHeader] — so the blocks here
/// are only its rows.
List<Widget> buildPrintBlocks(PrintDocument document) => document.isTable
    ? [
        for (final row in document.tableRows)
          buildTableRowBlock(row, document.columns!),
      ]
    : [
        ..._headerBlocks(document),
        for (final field in document.meta) _metaBlock(field),
        for (final group in document.groups) ...[
          if (group.heading != null) _groupHeadingBlock(group.heading!),
          for (final entry in group.entries) ..._entryBlocks(entry),
        ],
      ];

/// The repeated page header band for a table document, or null otherwise.
///
/// Drawn on **every** page by [buildPrintPage] (unlike the body header, which
/// is a block and so appears once). The capture measures this widget to work
/// out how much room the body has left per page.
Widget? buildRepeatedPageHeader(PrintDocument document) =>
    document.isTable ? buildTablePageHeader(document, document.columns!) : null;

/// One captured page: opaque paper, its repeated header, its blocks, its footer
/// and page counter.
Widget buildPrintPage({
  required PrintDocument document,
  required List<Widget> blocks,
  required int pageIndex,
  required int pageCount,
  required PrintPageBudget budget,
}) => ColoredBox(
  color: PrintStyle.page,
  child: SizedBox(
    width: budget.contentWidth,
    height: budget.contentHeight,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The repeated band is drawn flush against the body: for a ruled table
        // the column-heading row's bottom edge must touch the first data row,
        // or that row's top border is left open (the "missing top border" bug).
        ?buildRepeatedPageHeader(document),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: blocks,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  document.footer,
                  style: PrintStyle.footer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                document.pageLabel(pageIndex + 1, pageCount),
                style: PrintStyle.footer,
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);

List<Widget> _headerBlocks(PrintDocument document) => [
  Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(document.title, style: PrintStyle.title),
  ),
  if (document.subtitle.trim().isNotEmpty)
    Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(document.subtitle, style: PrintStyle.subtitle),
    ),
];

Widget _metaBlock(PrintField field) => Padding(
  padding: const EdgeInsets.only(bottom: 3),
  child: _labelledRow(field.label, field.value, PrintStyle.meta, PrintStyle.meta),
);

Widget _groupHeadingBlock(String heading) => Padding(
  padding: const EdgeInsets.only(top: 8, bottom: 3),
  child: Text(heading, style: PrintStyle.groupHeading),
);

/// An entry's blocks: its heading line (when it has one) and its field rows.
///
/// No rule closes the entry and no rule sits under a line anywhere: the printed
/// page draws text and nothing else.
List<Widget> _entryBlocks(PrintEntry entry) {
  final heading = [entry.serial, entry.heading]
      .where((part) => part.trim().isNotEmpty)
      .join('. ');
  return [
    if (heading.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(heading, style: PrintStyle.entryHeading),
      ),
    for (final field in entry.fields)
      Padding(
        padding: const EdgeInsets.only(top: 1.5),
        child: _labelledRow(
          field.label,
          field.value,
          PrintStyle.label,
          PrintStyle.value,
        ),
      ),
  ];
}

Widget _labelledRow(
  String label,
  String value,
  TextStyle labelStyle,
  TextStyle valueStyle,
) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    SizedBox(
      width: PrintStyle.labelColumnWidth,
      child: Text(label, style: labelStyle),
    ),
    Expanded(child: Text(value, style: valueStyle)),
  ],
);
