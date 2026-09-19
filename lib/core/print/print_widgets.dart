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
library;

import 'package:flutter/widgets.dart';

import 'print_document.dart';
import 'print_page_capture.dart';

/// Sizes, families and colours of a printed page (points, one logical pixel to
/// one point at the capture's pixel ratio).
abstract final class PrintStyle {
  /// Document title.
  static const TextStyle title = TextStyle(
    fontFamily: 'Manrope',
    fontFamilyFallback: _bengali,
    fontSize: 15,
    height: 1.3,
    color: ink,
    fontWeight: FontWeight.w600,
  );

  /// Dataset description under the title.
  static const TextStyle subtitle = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _bengali,
    fontSize: 8,
    height: 1.4,
    color: muted,
  );

  /// A group heading (court or date).
  static const TextStyle groupHeading = TextStyle(
    fontFamily: 'Manrope',
    fontFamilyFallback: _bengali,
    fontSize: 11,
    height: 1.3,
    color: ink,
    fontWeight: FontWeight.w600,
  );

  /// An entry's primary line (case number and case type).
  static const TextStyle entryHeading = TextStyle(
    fontFamily: 'IBMPlexSans',
    fontFamilyFallback: _bengali,
    fontSize: 9.5,
    height: 1.35,
    color: ink,
    fontWeight: FontWeight.w600,
  );

  /// A field's value.
  static const TextStyle value = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _bengali,
    fontSize: 8.5,
    height: 1.4,
    color: ink,
  );

  /// A field's label.
  static const TextStyle label = TextStyle(
    fontFamily: 'IBMPlexSans',
    fontFamilyFallback: _bengali,
    fontSize: 7,
    height: 1.4,
    color: muted,
  );

  /// A header fact (`Date range: …`).
  static const TextStyle meta = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _bengali,
    fontSize: 8,
    height: 1.4,
    color: muted,
  );

  /// The page footer and page counter.
  static const TextStyle footer = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _bengali,
    fontSize: 7,
    height: 1.4,
    color: muted,
  );

  /// Primary ink.
  static const Color ink = Color(0xFF0F172A);

  /// Secondary ink.
  static const Color muted = Color(0xFF475569);

  /// Hairline rules.
  static const Color rule = Color(0xFFCBD5E1);

  /// Width of a field's label column.
  static const double labelColumnWidth = 92;

  static const List<String> _bengali = ['TiroBangla'];
}

/// The document's blocks in reading order.
///
/// The page's own footer and page counter are **not** blocks: they are page
/// furniture, drawn per page by [buildPrintPage].
List<Widget> buildPrintBlocks(PrintDocument document) => [
  ..._headerBlocks(document),
  for (final field in document.meta) _metaBlock(field),
  for (final group in document.groups) ...[
    if (group.heading != null) _groupHeadingBlock(group.heading!),
    for (final entry in group.entries) ..._entryBlocks(entry),
  ],
];

/// One captured page: its blocks, plus the footer line and the page counter.
Widget buildPrintPage({
  required PrintDocument document,
  required List<Widget> blocks,
  required int pageIndex,
  required int pageCount,
  required PrintPageBudget budget,
}) => SizedBox(
  width: budget.contentWidth,
  height: budget.contentHeight,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: blocks,
        ),
      ),
      const SizedBox(height: 1, child: ColoredBox(color: PrintStyle.rule)),
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
            Text(document.pageLabel(pageIndex + 1, pageCount),
                style: PrintStyle.footer),
          ],
        ),
      ),
    ],
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
  const Padding(
    padding: EdgeInsets.only(top: 6),
    child: SizedBox(height: 0.5, child: ColoredBox(color: PrintStyle.rule)),
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

List<Widget> _entryBlocks(PrintEntry entry) => [
  Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Text(
      [entry.serial, entry.heading]
          .where((part) => part.trim().isNotEmpty)
          .join('. '),
      style: PrintStyle.entryHeading,
    ),
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
  const Padding(
    padding: EdgeInsets.only(top: 6),
    child: SizedBox(height: 0.5, child: ColoredBox(color: PrintStyle.rule)),
  ),
];

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
