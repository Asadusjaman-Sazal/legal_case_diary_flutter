/// Native `pdf` layout for [PrintDocument] — the Latin-only text path.
///
/// Pagination is the layout engine's: a `pw.MultiPage` measures every block it
/// is given and breaks the page where it actually runs out of room, so nothing
/// here counts rows or guesses page height. Text drawn through this path stays
/// searchable and selectable, which is why a Latin-only document prefers it.
///
/// Bengali content must not come here — `pdf` 3.13.0 has no Indic shaper (see
/// `print_document.dart`); [PrintDocument.needsRaster] is the rule and the
/// bounded raster renderer (Phase 2) is the path.
library;

import 'dart:typed_data';

import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'print_document.dart';

/// Loads a bundled font asset.
///
/// Injectable because the asset bundle is not guaranteed to answer under
/// `flutter test`: the tests read the same files straight from disk instead.
typedef FontBytesLoader = Future<ByteData> Function(String assetPath);

/// The fonts the native print path draws with (plan: Tiro Bangla for Bengali,
/// Manrope for headlines, Inter for body text, IBM Plex Sans for labels/data).
class PrintFontSet {
  /// Creates a loaded font set.
  const PrintFontSet({
    required this.body,
    required this.headline,
    required this.data,
    required this.bengali,
  });

  /// Inter — body text and mixed-script lines.
  final pw.Font body;

  /// Manrope — document and group headlines.
  final pw.Font headline;

  /// IBM Plex Sans — case numbers and other data labels.
  final pw.Font data;

  /// Tiro Bangla — every Bengali run.
  final pw.Font bengali;
}

/// Loads and caches the printable font set.
abstract final class PrintFonts {
  /// Absolute asset paths of the bundle in `assets/fonts/`.
  static const String bodyAsset =
      'assets/fonts/Inter-VariableFont_slnt,wght.ttf';

  /// Manrope headline font asset.
  static const String headlineAsset =
      'assets/fonts/Manrope-VariableFont_wght.ttf';

  /// IBM Plex Sans data font asset.
  static const String dataAsset = 'assets/fonts/IBMPlexSans-Regular.ttf';

  /// Tiro Bangla asset.
  static const String bengaliAsset = 'assets/fonts/TiroBangla-Regular.ttf';

  /// The production loader: the app's asset bundle.
  static Future<ByteData> loadAsset(String assetPath) =>
      rootBundle.load(assetPath);

  static PrintFontSet? _cached;

  /// Loads the font set once per process.
  static Future<PrintFontSet> load({FontBytesLoader loader = loadAsset}) async {
    final cached = _cached;
    if (cached != null) return cached;

    Future<pw.Font> read(String assetPath) async =>
        pw.Font.ttf(await loader(assetPath));

    final fonts = PrintFontSet(
      body: await read(bodyAsset),
      headline: await read(headlineAsset),
      data: await read(dataAsset),
      bengali: await read(bengaliAsset),
    );
    _cached = fonts;
    return fonts;
  }
}

/// Lays a [PrintDocument] out as native PDF text.
class PdfNativeRenderer {
  /// Creates a renderer; [fonts] is loaded on first use.
  PdfNativeRenderer({this.fontLoader = PrintFonts.loadAsset, this.fonts});

  /// Loader used when [fonts] is not supplied.
  final FontBytesLoader fontLoader;

  /// Pre-loaded fonts, or `null` to load them lazily.
  final PrintFontSet? fonts;

  /// Renders [document] to PDF bytes.
  ///
  /// [compress] is exposed for the tests: the embedded `ToUnicode` CMap of an
  /// uncompressed document is plain text, so the tests can prove the Bengali
  /// fixtures survive the round trip out of the file.
  Future<Uint8List> render(
    PrintDocument document, {
    bool compress = true,
  }) async {
    final set = fonts ?? await PrintFonts.load(loader: fontLoader);

    final pdf = pw.Document(
      compress: compress,
      title: document.title,
      theme: pw.ThemeData.withFont(
        base: set.body,
        bold: set.headline,
        fontFallback: [set.bengali],
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 36),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : _header(document, set),
        footer: (context) => _footer(
          document,
          context.pageNumber,
          context.pagesCount,
        ),
        build: (context) => [
          _header(document, set),
          ...document.meta.map(
            (field) => _metaLine(field, set),
          ),
          pw.SizedBox(height: 12),
          for (final group in document.groups) ...[
            if (group.heading != null) _groupHeading(group.heading!, set),
            ...group.entries.map((entry) => _entry(entry, document, set)),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  /// Title band: the screen's own localized name and the dataset description.
  pw.Widget _header(PrintDocument document, PrintFontSet set) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          document.title,
          style: pw.TextStyle(font: set.headline, fontSize: 18),
        ),
        if (document.subtitle.trim().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(
              document.subtitle,
              style: pw.TextStyle(font: set.body, fontSize: 9, color: PdfColors.grey700),
            ),
          ),
        pw.SizedBox(height: 6),
        if (document.showRules)
          pw.Divider(height: 1, thickness: 0.6, color: PdfColors.grey400),
      ],
    );
  }

  /// One labelled header fact (`Date range: …`, `Search: …`).
  pw.Widget _metaLine(PrintField field, PrintFontSet set) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4),
      child: _labelledRow(field, set, labelWidth: 84),
    );
  }

  /// A court (or date) heading above its entries.
  pw.Widget _groupHeading(String heading, PrintFontSet set) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 12, bottom: 2),
      child: pw.Text(
        heading,
        style: pw.TextStyle(font: set.headline, fontSize: 12),
      ),
    );
  }

  /// One case entry: its heading line (when it has one), then its labelled
  /// fields, closed by the hairline rule unless the document turned rules off.
  pw.Widget _entry(PrintEntry entry, PrintDocument document, PrintFontSet set) {
    final heading = [entry.serial, entry.heading]
        .where((part) => part.trim().isNotEmpty)
        .join('. ');
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      decoration: document.showRules
          ? const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
            )
          : null,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (heading.isNotEmpty)
            pw.Text(
              heading,
              style: pw.TextStyle(font: set.data, fontSize: 10.5),
            ),
          for (final field in entry.fields)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: _labelledRow(field, set),
            ),
        ],
      ),
    );
  }

  /// `Label   value` on one line, wrapping the value as needed.
  pw.Widget _labelledRow(
    PrintField field,
    PrintFontSet set, {
    double labelWidth = 96,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: labelWidth,
          child: pw.Text(
            field.label,
            style: pw.TextStyle(
              font: set.data,
              fontSize: 8,
              color: PdfColors.grey700,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            field.value,
            style: pw.TextStyle(font: set.body, fontSize: 9.5),
          ),
        ),
      ],
    );
  }

  /// Printed-on line and the localized page counter.
  pw.Widget _footer(PrintDocument document, int page, int total) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            document.footer,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            document.pageLabel(page, total),
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }
}
