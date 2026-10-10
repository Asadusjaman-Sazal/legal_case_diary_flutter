/// Bounded widget-to-image rendering of a [PrintDocument] (Task 14 Phase 2).
///
/// The native `pdf` layout cannot shape Bengali, so a Bengali document is
/// printed as **bounded page images** of the print-only widget instead. The
/// bound is the whole point: one page is laid out at a time, captured, encoded
/// and released before the next page is touched, so the peak allocation is one
/// page's RGBA buffer rather than a whole scroll view's bitmap, and the pixel
/// ratio is derived from an explicit budget instead of the device's.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'print_document.dart';
import 'print_widgets.dart';

/// The memory envelope a captured page must fit in.
///
/// A page is A4 and the capture pixel ratio is capped so a single RGBA page
/// buffer stays inside [maxRgbaBytes]: a 3x phone would otherwise allocate
/// roughly 15 MB for one page of a cause list.
class PrintPageBudget {
  /// Creates a budget, defaulting to A4 at 2x.
  const PrintPageBudget({
    this.pageWidth = a4Width,
    this.pageHeight = a4Height,
    this.margin = 32,
    this.maxPixelRatio = 2,
    this.maxRgbaBytes = 8 * 1024 * 1024,
  });

  /// A4 width in points.
  static const double a4Width = 595.28;

  /// A4 height in points.
  static const double a4Height = 841.89;

  /// Space reserved for the page's own footer line and page counter (the top
  /// padding and the text line). Sized to the footer's own type: 12 pt at a
  /// 1.4 line height plus the 4 pt gap is 20.8 pt.
  static const double footerHeight = 24;

  /// Page width in points.
  final double pageWidth;

  /// Page height in points.
  final double pageHeight;

  /// Printable margin in points, on every side.
  final double margin;

  /// Hard cap on the capture pixel ratio.
  final double maxPixelRatio;

  /// Hard cap on one page's decoded RGBA bytes.
  final int maxRgbaBytes;

  /// Width of the area the print blocks are drawn in, in points.
  double get contentWidth => pageWidth - margin * 2;

  /// Height of the area the print blocks are drawn in, in points.
  double get contentHeight => pageHeight - margin * 2;

  /// Height the measured blocks may use on one page.
  double get blockAreaHeight => contentHeight - footerHeight;

  /// The largest ratio that keeps one page inside [maxRgbaBytes].
  ///
  /// Pixel dimensions round up, and rounding only ever adds area, so the solved
  /// ratio is trimmed until the rounded buffer verifiably fits — the budget is
  /// then enforced by construction rather than by hope.
  double get budgetPixelRatio {
    var ratio = math.min(
      math.sqrt(maxRgbaBytes / (contentWidth * contentHeight * 4)),
      maxPixelRatio,
    );
    while (ratio > 0 && rgbaBytesAt(ratio) > maxRgbaBytes) {
      ratio -= 0.01;
    }
    return ratio < 0 ? 0 : ratio;
  }

  /// The ratio to capture at: [requested] capped by both limits.
  double pixelRatioFor(double requested) =>
      math.min(requested, budgetPixelRatio);

  /// Decoded RGBA bytes one page occupies at [pixelRatio].
  int rgbaBytesAt(double pixelRatio) =>
      (contentWidth * pixelRatio).ceil() *
      (contentHeight * pixelRatio).ceil() *
      4;

  /// Whether [pixelRatio] keeps a page inside [maxRgbaBytes].
  bool withinBudget(double pixelRatio) =>
      rgbaBytesAt(pixelRatio) <= maxRgbaBytes;
}

/// Splits measured [blockHeights] into pages of at most [pageHeight] points.
///
/// This is the "measured rendered height, never a fixed row count" rule: the
/// caller measures the very blocks it is about to draw, a block that no longer
/// fits starts the next page, and a block taller than a page gets a page of its
/// own (the print blocks are fine-grained so this stays rare).
List<List<int>> paginateBlockHeights(
  List<double> blockHeights,
  double pageHeight,
) {
  final pages = <List<int>>[];
  var current = <int>[];
  var used = 0.0;

  for (var index = 0; index < blockHeights.length; index++) {
    final height = blockHeights[index];
    if (current.isNotEmpty && used + height > pageHeight) {
      pages.add(current);
      current = <int>[];
      used = 0.0;
    }
    current.add(index);
    used += height;
  }

  if (current.isNotEmpty) pages.add(current);
  return pages.isEmpty ? [<int>[]] : pages;
}

/// Memory accounting for one capture run, for the tests and the phase report.
class PrintCaptureStats {
  /// Creates a stats snapshot.
  const PrintCaptureStats({
    required this.pages,
    required this.pageRgbaBytes,
    required this.peakRgbaBytes,
  });

  /// Pages captured.
  final int pages;

  /// Decoded RGBA bytes one page occupies.
  final int pageRgbaBytes;

  /// Highest number of decoded RGBA bytes alive at any moment.
  final int peakRgbaBytes;
}

/// Encodes one laid-out page as PNG bytes.
///
/// Injectable so the tests can drive pagination, budgets and cancellation
/// without the engine's encoder; [encodePagePng] is the production one.
typedef PageEncoder =
    Future<Uint8List> Function(RenderRepaintBoundary boundary, double pixelRatio);

/// Assembles captured pages into a PDF; injectable so a test can skip the
/// isolate, [assembleInIsolate] being the production one.
typedef PdfAssembler = Future<Uint8List> Function(RasterPdfRequest request);

/// Runs [assembleRasterPdf] on a worker isolate, keeping the main thread free
/// while a long cause list is assembled.
Future<Uint8List> assembleInIsolate(RasterPdfRequest request) =>
    compute(assembleRasterPdf, request);

/// Captures one painted page as PNG bytes, releasing the image straight away.
Future<Uint8List> encodePagePng(
  RenderRepaintBoundary boundary,
  double pixelRatio,
) async {
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    // The RGBA buffer is the largest allocation in this feature; it must not
    // outlive the page it belongs to.
    image.dispose();
  }
}

/// The sendable request for [assembleRasterPdf].
class RasterPdfRequest {
  /// Creates the request.
  const RasterPdfRequest({
    required this.pages,
    required this.title,
    required this.pageWidth,
    required this.pageHeight,
    required this.margin,
  });

  /// One PNG per page, in order.
  final List<Uint8List> pages;

  /// Document title, used as the PDF title.
  final String title;

  /// Page width in points.
  final double pageWidth;

  /// Page height in points.
  final double pageHeight;

  /// Printable margin in points.
  final double margin;
}

/// Assembles captured pages into a PDF — a top-level function so it can run in
/// an isolate, which keeps the layout work off the main thread.
Future<Uint8List> assembleRasterPdf(RasterPdfRequest request) async {
  final pdf = pw.Document(title: request.title);
  final format = PdfPageFormat(request.pageWidth, request.pageHeight);

  for (final page in request.pages) {
    final image = pw.MemoryImage(page);
    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.all(request.margin),
        build: (context) => pw.Center(
          child: pw.Image(image, fit: pw.BoxFit.contain),
        ),
      ),
    );
  }

  return pdf.save();
}

/// Captures a [PrintDocument] page by page and builds the print-ready PDF.
///
/// It draws nothing visible: the print-only widget lives off the top-left
/// corner of a non-clipping stack, still laid out and painted (a capture needs
/// a painted layer, so `Offstage` and zero opacity would not work).
class PrintPageCapture extends StatefulWidget {
  /// Creates the capture widget for [document].
  const PrintPageCapture({
    super.key,
    required this.document,
    this.budget = const PrintPageBudget(),
    required this.onCompleted,
    required this.onCancelled,
    required this.onFailed,
    this.onProgress,
    this.onStats,
    this.isCancelled,
    this.pageEncoder = encodePagePng,
    this.assembler = assembleInIsolate,
  });

  /// The document to render.
  final PrintDocument document;

  /// The page geometry and memory envelope.
  final PrintPageBudget budget;

  /// Called with the finished PDF bytes.
  final void Function(Uint8List bytes) onCompleted;

  /// Called when [isCancelled] asked the run to stop.
  final VoidCallback onCancelled;

  /// Called with a recoverable failure (nothing is thrown at the caller).
  final void Function(Object error) onFailed;

  /// Called after each captured page.
  final void Function(int page, int total)? onProgress;

  /// Called once with the run's memory accounting.
  final void Function(PrintCaptureStats stats)? onStats;

  /// Polled between pages.
  final bool Function()? isCancelled;

  /// The page encoder; replaced by the tests.
  final PageEncoder pageEncoder;

  /// The PDF assembler; replaced by the tests.
  final PdfAssembler assembler;

  @override
  State<PrintPageCapture> createState() => _PrintPageCaptureState();
}

class _PrintPageCaptureState extends State<PrintPageCapture> {
  final GlobalKey _measureKey = GlobalKey();
  final GlobalKey _pageKey = GlobalKey();

  late final List<Widget> _blocks;
  List<List<int>> _pages = const [];
  int _capturingPage = 0;
  int _peakRgbaBytes = 0;
  bool _measuring = true;

  /// The budget actually in force: the document's own margin when it sets one
  /// (the ruled table asks for a narrow margin), the caller's budget otherwise.
  PrintPageBudget get _budget {
    final margin = widget.document.margin;
    if (margin == null) return widget.budget;
    return PrintPageBudget(
      pageWidth: widget.budget.pageWidth,
      pageHeight: widget.budget.pageHeight,
      margin: margin,
      maxPixelRatio: widget.budget.maxPixelRatio,
      maxRgbaBytes: widget.budget.maxRgbaBytes,
    );
  }

  @override
  void initState() {
    super.initState();
    _blocks = buildPrintBlocks(widget.document);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
  }

  @override
  Widget build(BuildContext context) {
    // The parent must not decide this layout. A dialog positions its capture
    // child with *loose* constraints (no `top`/`bottom` on the `Positioned`),
    // and a `Stack` sized to those asserts `size.isFinite` and aborts the whole
    // capture — which is how a Bengali print used to fail while an English one
    // worked, Bengali being the only path that draws this widget. `LimitedBox`
    // supplies a bound exactly where the parent left one out and passes a
    // bounded parent through untouched.
    //
    // Inside, one block column is laid out at page width with unbounded height,
    // so every block keeps the natural height the paginator measures, and it is
    // drawn off the visible area rather than hidden: a capture needs a painted
    // layer, so `Offstage` and zero opacity would not do.
    final budget = _budget;
    return LimitedBox(
      maxWidth: budget.contentWidth,
      maxHeight: budget.contentHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -budget.pageWidth,
            top: 0,
            child: SizedBox(
              width: budget.contentWidth,
              child: _measuring ? _measurementBody() : _pageBody(),
            ),
          ),
        ],
      ),
    );
  }

  /// The repeated header band, or null for a document without one.
  Widget? get _header => buildRepeatedPageHeader(widget.document);

  /// Every block, laid out once at page width so its height can be measured.
  ///
  /// The repeated header band, when there is one, is measured first here so the
  /// paginator can subtract its height before splitting the blocks.
  Widget _measurementBody() => Column(
    key: _measureKey,
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ?_header,
      ..._blocks,
    ],
  );

  /// The page currently being captured.
  Widget _pageBody() {
    final pageBlocks = _pages[_capturingPage]
        .map((index) => _blocks[index])
        .toList();
    return RepaintBoundary(
      key: _pageKey,
      child: buildPrintPage(
        document: widget.document,
        blocks: pageBlocks,
        pageIndex: _capturingPage,
        pageCount: _pages.length,
        budget: _budget,
      ),
    );
  }

  /// Measures the blocks, paginates them and captures one page at a time.
  Future<void> _run() async {
    try {
      final heights = _measureBlocks();
      // The header band (when present) is the first measured child; the blocks
      // get whatever room is left after it and the 4 pt gap drawn under it.
      final headerHeight = _header == null ? 0.0 : heights.removeAt(0);
      _pages = paginateBlockHeights(
        heights,
        _budget.blockAreaHeight - (headerHeight == 0 ? 0 : headerHeight + 4),
      );

      final budget = _budget;
      final pixelRatio = budget.pixelRatioFor(
        View.of(context).devicePixelRatio,
      );
      final pageRgbaBytes = budget.rgbaBytesAt(pixelRatio);
      final captured = <Uint8List>[];

      for (var page = 0; page < _pages.length; page++) {
        if (widget.isCancelled?.call() ?? false) {
          widget.onCancelled();
          return;
        }
        setState(() {
          _measuring = false;
          _capturingPage = page;
        });
        await _nextFrame();

        final boundary =
            _pageKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        // One page's decoded buffer is alive here, and only here.
        _peakRgbaBytes = math.max(_peakRgbaBytes, pageRgbaBytes);
        captured.add(await widget.pageEncoder(boundary, pixelRatio));
        widget.onProgress?.call(page + 1, _pages.length);
      }

      // The pages are assembled off the main thread; only compressed PNG bytes
      // are held while that happens.
      final bytes = await widget.assembler(
        RasterPdfRequest(
          pages: captured,
          title: widget.document.title,
          pageWidth: budget.pageWidth,
          pageHeight: budget.pageHeight,
          margin: budget.margin,
        ),
      );

      if (!mounted) return;
      widget.onStats?.call(
        PrintCaptureStats(
          pages: _pages.length,
          pageRgbaBytes: pageRgbaBytes,
          peakRgbaBytes: _peakRgbaBytes,
        ),
      );
      widget.onCompleted(bytes);
    } catch (error, stack) {
      // A capture failure is recoverable: the caller shows a message and the
      // user keeps working. The cause still goes to the log, because a silent
      // "could not print" is unfixable in the field.
      debugPrint('Print capture failed: $error');
      debugPrintStack(stackTrace: stack, maxFrames: 12);
      if (mounted) {
        widget.onStats?.call(
          PrintCaptureStats(
            pages: _pages.length,
            pageRgbaBytes: 0,
            peakRgbaBytes: _peakRgbaBytes,
          ),
        );
      }
      widget.onFailed(error);
    }
  }

  /// Reads the laid-out height of every block, straight from the flex.
  ///
  /// Both guards exist because the failure they describe is the one that is
  /// hardest to see from a report like "could not print": a capture widget that
  /// was never laid out. The message says so instead of leaving an assertion
  /// about an anonymous render box in the log.
  List<double> _measureBlocks() {
    final object = _measureKey.currentContext?.findRenderObject();
    if (object is! RenderFlex) {
      throw StateError('The print blocks were never laid out; cannot measure.');
    }

    final heights = <double>[];
    RenderBox? child = object.firstChild;
    while (child != null) {
      if (!child.hasSize) {
        throw StateError('A print block was left unlaid out; cannot measure.');
      }
      heights.add(child.size.height);
      child = (child.parentData! as FlexParentData).nextSibling;
    }
    return heights;
  }

  /// Resolves after the next painted frame, which is what the capture reads.
  Future<void> _nextFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) completer.complete();
    });
    WidgetsBinding.instance.scheduleFrame();
    return completer.future;
  }
}
