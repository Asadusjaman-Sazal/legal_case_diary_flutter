/// Tests for the bounded raster path (Task 14 Phase 2).
///
/// Three things must hold before a Bengali printout may be rendered as page
/// images: the pixel ratio and page buffer must stay inside an explicit budget,
/// pagination must follow measured block heights rather than a row count, and a
/// capture must never keep more than one page's decoded buffer alive. The last
/// two are driven here through an injected encoder and assembler, so the tests
/// assert the pipeline itself instead of the engine's PNG encoder.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/print/print_document.dart';
import 'package:legal_case_diary/core/print/print_page_capture.dart';
import 'package:legal_case_diary/core/print/print_widgets.dart';

/// A real PNG, read from disk: the pdf package decodes it itself.
final Uint8List _logoPng = File('assets/icons/app_logo.png').readAsBytesSync();

/// A document with [entries] entries and a handful of fields each, so it can
/// only fit on several pages.
PrintDocument _document({int entries = 60}) => PrintDocument(
  title: 'Daily Cause List',
  subtitle: '19/09/2026',
  footer: 'Printed on 19/09/2026',
  pageLabel: (page, total) => 'Page $page of $total',
  groups: [
    PrintGroup(
      heading: 'Dhaka Judge Court',
      entries: [
        for (var i = 0; i < entries; i++)
          PrintEntry(
            serial: '${i + 1}',
            heading: '${100 + i}/2021 · Civil Suit',
            fields: const [
              PrintField('Petitioner', 'Karim Rahman'),
              PrintField('Respondent', 'State'),
              PrintField('Lead Counsel', 'Adv. A. Hossain'),
              PrintField('Step', 'Evidence'),
              PrintField('Note', 'Adjourned for cross-examination'),
            ],
          ),
      ],
    ),
  ],
);

/// The number of pages the captured PDF declares.
int _pageCountOf(Uint8List pdf) {
  final match = RegExp(r'/Count (\d+)').firstMatch(latin1.decode(pdf));
  return match == null ? 0 : int.parse(match.group(1)!);
}

/// Pumps frames until [done] reports true, so the capture can advance its
/// frame-by-frame page loop.
Future<void> _drive(WidgetTester tester, bool Function() done, {int maxFrames = 600}) async {
  for (var frame = 0; frame < maxFrames && !done(); frame++) {
    await tester.pump();
  }
}

/// A one-entry document, with or without the hairline rules.
PrintDocument _ruled({required bool showRules}) => PrintDocument(
  title: 'Case Details',
  footer: 'Printed on 19/09/2026',
  pageLabel: (page, total) => 'Page $page of $total',
  showRules: showRules,
  groups: [
    PrintGroup(
      heading: 'Case Details',
      entries: const [
        PrintEntry(fields: [PrintField('Petitioner', 'Karim Rahman')]),
      ],
    ),
  ],
);

void main() {
  group('print blocks', () {
    testWidgets('a document without rules draws no hairline anywhere',
        (tester) async {
      Future<int> ruleCount(PrintDocument document) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(children: buildPrintBlocks(document)),
              ),
            ),
          ),
        );
        return tester
            .widgetList(
              find.byWidgetPredicate(
                (widget) => widget is ColoredBox && widget.color == PrintStyle.rule,
              ),
            )
            .length;
      }

      expect(await ruleCount(_ruled(showRules: true)), greaterThan(0));
      expect(await ruleCount(_ruled(showRules: false)), 0);
    });

    testWidgets('a heading-less entry draws no empty heading line',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(children: buildPrintBlocks(_ruled(showRules: true))),
          ),
        ),
      );

      expect(find.text('Petitioner'), findsOneWidget);
      // Neither an empty heading line nor a stray `". "` joins one.
      expect(find.text(''), findsNothing);
    });
  });

  group('page budget', () {
    test('caps the pixel ratio so one page fits the byte budget', () {
      const budget = PrintPageBudget();

      // A 3x phone would allocate ~15 MB for one page; the cap is 2x.
      expect(budget.pixelRatioFor(3), 2);
      expect(budget.pixelRatioFor(1), 1);
      expect(budget.withinBudget(budget.pixelRatioFor(3)), isTrue);
      expect(budget.rgbaBytesAt(2), lessThanOrEqualTo(budget.maxRgbaBytes));
    });

    test('the byte budget wins over the ratio cap when the page is large', () {
      // One megabyte for a whole A4 page is far below 2x, so the ratio must
      // shrink: the budget is enforced by construction, not by hope.
      const tight = PrintPageBudget(maxRgbaBytes: 1024 * 1024);

      final ratio = tight.pixelRatioFor(2);
      expect(ratio, lessThan(2));
      expect(tight.withinBudget(ratio), isTrue);
      expect(tight.rgbaBytesAt(ratio), lessThanOrEqualTo(tight.maxRgbaBytes));
    });

    test('the block area is the content area minus the page furniture', () {
      const budget = PrintPageBudget();

      expect(budget.contentWidth, closeTo(595.28 - 64, 0.01));
      expect(budget.contentHeight, closeTo(841.89 - 64, 0.01));
      expect(
        budget.blockAreaHeight,
        closeTo(budget.contentHeight - PrintPageBudget.footerHeight, 0.01),
      );
    });
  });

  group('measured-height pagination', () {
    test('keeps blocks that fit on one page together', () {
      expect(paginateBlockHeights([10, 10, 10], 100), [
        [0, 1, 2],
      ]);
    });

    test('starts a new page when the next block does not fit', () {
      expect(paginateBlockHeights([10, 10, 10], 25), [
        [0, 1],
        [2],
      ]);
    });

    test('gives a block taller than the page a page of its own', () {
      expect(paginateBlockHeights([30, 5], 25), [
        [0],
        [1],
      ]);
    });

    test('an empty document still yields one capturable page', () {
      expect(paginateBlockHeights(const [], 100), [<int>[]]);
    });
  });

  group('PDF assembly', () {
    test('one PDF page per captured page, with a PDF header', () async {
      final bytes = await assembleRasterPdf(
        RasterPdfRequest(
          pages: [_logoPng, _logoPng, _logoPng],
          title: 'Active Cases',
          pageWidth: PrintPageBudget.a4Width,
          pageHeight: PrintPageBudget.a4Height,
          margin: 32,
        ),
      );

      expect(latin1.decode(bytes.sublist(0, 4)), '%PDF');
      expect(_pageCountOf(bytes), 3);
    });

    test('assembly runs on a worker isolate', () async {
      final bytes = await assembleInIsolate(
        RasterPdfRequest(
          pages: [_logoPng],
          title: 'Active Cases',
          pageWidth: PrintPageBudget.a4Width,
          pageHeight: PrintPageBudget.a4Height,
          margin: 32,
        ),
      );

      expect(_pageCountOf(bytes), 1);
    });
  });

  group('bounded capture', () {
    testWidgets('captures one page at a time and reports its budget use',
        (tester) async {
      final encodedPages = <int>[];
      final progress = <int>[];
      RasterPdfRequest? assembled;
      Uint8List? completed;
      PrintCaptureStats? stats;
      Object? failure;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrintPageCapture(
              document: _document(),
              pageEncoder: (boundary, pixelRatio) async {
                encodedPages.add(pixelRatio.round());
                return _logoPng;
              },
              assembler: (request) async {
                assembled = request;
                return Uint8List.fromList(utf8.encode('%PDF fake'));
              },
              onProgress: (page, total) => progress.add(page),
              onStats: (value) => stats = value,
              onCompleted: (bytes) => completed = bytes,
              onCancelled: () {},
              onFailed: (error) => failure = error,
            ),
          ),
        ),
      );

      await _drive(tester, () => completed != null || failure != null);

      expect(failure, isNull);
      expect(completed, isNotNull);
      expect(assembled, isNotNull);
      // Everything the encoder produced reached the assembler, in order.
      expect(assembled!.pages, hasLength(encodedPages.length));
      expect(encodedPages.length, greaterThan(1));
      expect(progress, [for (var i = 1; i <= encodedPages.length; i++) i]);

      // The memory rule: one page's decoded buffer at a time, inside budget.
      expect(stats, isNotNull);
      expect(stats!.pages, encodedPages.length);
      expect(stats!.peakRgbaBytes, stats!.pageRgbaBytes);
      expect(stats!.pageRgbaBytes, lessThanOrEqualTo(const PrintPageBudget().maxRgbaBytes));
      expect(encodedPages.toSet(), {2}); // capped at 2x, never the 3x device
    });

    testWidgets('a cancelled capture stops between pages and never completes',
        (tester) async {
      var encoded = 0;
      var cancelled = false;
      Uint8List? completed;
      Object? failure;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrintPageCapture(
              document: _document(),
              // Cancel once the second page has been encoded: the run must stop
              // there rather than render the remaining pages.
              isCancelled: () => encoded >= 2,
              pageEncoder: (boundary, pixelRatio) async {
                encoded++;
                return _logoPng;
              },
              assembler: (request) async => Uint8List.fromList([1, 2, 3]),
              onCompleted: (bytes) => completed = bytes,
              onCancelled: () => cancelled = true,
              onFailed: (error) => failure = error,
            ),
          ),
        ),
      );

      await _drive(tester, () => cancelled || completed != null || failure != null);

      expect(cancelled, isTrue);
      expect(completed, isNull);
      expect(failure, isNull);
      expect(encoded, 2);
    });

    testWidgets('an encoder failure is reported, not thrown', (tester) async {
      Object? failure;
      Uint8List? completed;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrintPageCapture(
              document: _document(entries: 2),
              pageEncoder: (boundary, pixelRatio) async =>
                  throw StateError('encoder exploded'),
              assembler: (request) async => Uint8List.fromList([1]),
              onCompleted: (bytes) => completed = bytes,
              onCancelled: () {},
              onFailed: (error) => failure = error,
            ),
          ),
        ),
      );

      await _drive(tester, () => failure != null || completed != null);

      expect(failure, isA<StateError>());
      expect(completed, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the real encoder paints the page and yields PNG bytes',
        (tester) async {
      Uint8List? completed;
      Object? failure;
      final captured = <Uint8List>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrintPageCapture(
              document: _document(entries: 3),
              pageEncoder: encodePagePng,
              assembler: (request) async {
                captured.addAll(request.pages);
                return Uint8List.fromList(utf8.encode('%PDF fake'));
              },
              onCompleted: (bytes) => completed = bytes,
              onCancelled: () {},
              onFailed: (error) => failure = error,
            ),
          ),
        ),
      );

      // The engine's encoder needs the real event loop, so the frame driving is
      // interleaved with a real one-tick drain.
      for (var i = 0; i < 60 && completed == null && failure == null; i++) {
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      }

      expect(failure, isNull, reason: 'capture threw: $failure');
      expect(captured, hasLength(1));
      expect(completed, isNotNull);
      // The engine's own encoder produced a real PNG of the painted page.
      expect(captured.single.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      expect(captured.single.length, greaterThan(1000));
    });
  });
}
