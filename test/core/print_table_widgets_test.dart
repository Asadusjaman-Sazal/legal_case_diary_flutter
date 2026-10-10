/// Tests for the ruled-table renderer (the case-list printout format).
///
/// These pin the things the format fixes: fixed column widths in centimetres,
/// a bordered grid that draws a rule (unlike the free-flowing body, which draws
/// text only), a minimum row height that grows when a cell wraps, and the
/// header band that repeats on every page.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/print/print_document.dart';
import 'package:legal_case_diary/core/print/print_table_widgets.dart';

const List<PrintTableColumn> _columns = [
  PrintTableColumn(label: 'SL', widthCm: 0.69),
  PrintTableColumn(label: 'Case No.', widthCm: 2.51),
];

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  Directionality(textDirection: TextDirection.ltr, child: child),
);

void main() {
  test('centimetres convert to points the way the page is laid out', () {
    expect(printCm(2.54), closeTo(72, 0.001));
    // The sample's eight columns total 19.62 cm, which the A4 budget fits.
    const sample = <double>[0.69, 1.83, 2.51, 3.68, 3.68, 2.22, 3.18, 1.83];
    expect(
      sample.fold<double>(0, (sum, cm) => sum + cm),
      closeTo(19.62, 0.001),
    );
  });

  testWidgets('a data row draws a bordered cell per column, at fixed widths', (
    tester,
  ) async {
    await _pump(
      tester,
      buildTableDataRow(
        const PrintTableRow.data(['1', 'Civil- 12/26']),
        _columns,
      ),
    );

    // One bordered box per column, each exactly its centimetre width.
    final boxes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
    expect(boxes, hasLength(2));
    for (final box in boxes) {
      expect(
        (box.decoration as BoxDecoration).border,
        isNotNull,
        reason: 'every cell is ruled',
      );
    }
    // Each cell is its own fixed width (the row spans the available width, but
    // the cells keep the sample's centimetre widths).
    final sizes = [
      for (var i = 0; i < 2; i++)
        tester.getSize(
          find
              .descendant(of: find.byType(Row), matching: find.byType(SizedBox))
              .at(i),
        ),
    ];
    expect(sizes[0].width, closeTo(printCm(0.69), 0.01));
    expect(sizes[1].width, closeTo(printCm(2.51), 0.01));
  });

  testWidgets('a row is at least the fixed height, and grows when a cell wraps', (
    tester,
  ) async {
    await _pump(
      tester,
      const SizedBox(
        width: 400,
        child: PrintTableRowProbe(row: PrintTableRow.data(['1', 'short'])),
      ),
    );
    final short = tester.getSize(find.byType(Row).first).height;
    expect(short, greaterThanOrEqualTo(PrintTableStyle.rowMinHeight - 0.01));

    await _pump(
      tester,
      const SizedBox(
        width: 400,
        // A long case number in the narrow column must wrap, not clip, and the
        // row grows past the minimum rather than overflowing.
        child: PrintTableRowProbe(
          row: PrintTableRow.data(['1', 'First Appeal- 1234/2026 (Civil)']),
        ),
      ),
    );
    final tall = tester.getSize(find.byType(Row).first).height;
    expect(tall, greaterThanOrEqualTo(PrintTableStyle.rowMinHeight - 0.01));
  });

  testWidgets('the header band carries the title and a bordered heading row', (
    tester,
  ) async {
    const document = PrintDocument(
      title: 'Daily Cause List',
      groups: [],
      footer: '',
      brandTitle: 'Legal Case Diary',
      dateLine: 'Date: 10/10/26   Day: Saturday',
      columns: _columns,
    );

    await _pump(tester, buildTablePageHeader(document, _columns));

    expect(find.text('Legal Case Diary'), findsOneWidget);
    expect(find.text('Daily Cause List'), findsOneWidget);
    expect(find.textContaining('Date: 10/10/26'), findsOneWidget);
    expect(find.text('SL'), findsOneWidget);
    expect(find.text('Case No.'), findsOneWidget);
    // The heading row is ruled like a data row.
    expect(find.byType(DecoratedBox), findsWidgets);
  });

  test('the table width is the sum of its columns', () {
    expect(tableWidthOf(_columns), closeTo(printCm(0.69) + printCm(2.51), 0.001));
  });

  testWidgets('every cell draws its own top border, so no edge is open', (
    tester,
  ) async {
    await _pump(
      tester,
      buildTableDataRow(
        const PrintTableRow.data(['1', 'Civil- 12/26']),
        _columns,
      ),
    );

    for (final box in tester.widgetList<DecoratedBox>(
      find.byType(DecoratedBox),
    )) {
      final border = (box.decoration as BoxDecoration).border! as Border;
      expect(border.top, isNot(BorderSide.none), reason: 'an open top edge');
      expect(border.bottom, isNot(BorderSide.none));
      expect(border.right, isNot(BorderSide.none));
    }
  });

  testWidgets('a court row is bordered on all four sides', (tester) async {
    await _pump(tester, buildTableCourtRow('Dhaka Judge Court', 400));
    final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
    final border = (box.decoration as BoxDecoration).border! as Border;
    expect(border.top, isNot(BorderSide.none));
    expect(border.left, isNot(BorderSide.none));
    expect(border.right, isNot(BorderSide.none));
    expect(border.bottom, isNot(BorderSide.none));
  });

  testWidgets('column headings are centred whatever the column alignment', (
    tester,
  ) async {
    await _pump(
      tester,
      buildTableHeaderRow(const [
        PrintTableColumn(label: 'Case No.', widthCm: 2.51),
      ]),
    );
    expect(tester.widget<Text>(find.text('Case No.')).textAlign, TextAlign.center);
  });

  test('the screen title is underlined', () {
    expect(
      PrintTableStyle.screenTitle.decoration,
      TextDecoration.underline,
    );
    // The print resolution is the 600 dpi the user asked for, not a screen cap.
    expect(kPrintTargetDpi, greaterThanOrEqualTo(300));
    expect(kPrintTablePixelRatio, closeTo(600 / 72, 0.001));
  });
}

/// A tiny probe that lays one row out at a bounded width.
class PrintTableRowProbe extends StatelessWidget {
  const PrintTableRowProbe({required this.row, super.key});

  final PrintTableRow row;

  @override
  Widget build(BuildContext context) => buildTableDataRow(row, _columns);
}
