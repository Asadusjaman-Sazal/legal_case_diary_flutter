/// Turning a [PrintDocument] into PDF bytes, the way its script requires.
///
/// The script rule lives in the document (Phase 1): Bengali content must not go
/// down the native text path because `pdf` 3.13.0 ships no Indic shaper, so it
/// is rendered as bounded page images behind a progress dialog instead, while a
/// Latin-only document keeps the searchable native layout and needs no dialog.
///
/// The choice sits behind this interface so a screen test can replace the whole
/// rendering step with a recorder and assert *what* would have been printed —
/// no platform channel, no engine encoder, no isolate.
library;

import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'pdf_native_renderer.dart';
import 'print_document.dart';
import 'print_page_capture.dart';
import 'print_progress_dialog.dart';

/// Renders a print document to PDF bytes.
abstract interface class PrintDocumentRenderer {
  /// Renders [document], or returns `null` when the user cancelled a capture.
  Future<Uint8List?> render(BuildContext context, PrintDocument document);
}

/// The production renderer: native text when the document has no Bengali,
/// bounded raster pages when it has.
class ScriptAwarePrintRenderer implements PrintDocumentRenderer {
  /// Creates the renderer; the knobs exist for the tests.
  const ScriptAwarePrintRenderer({
    this.nativeRenderer,
    this.pageEncoder = encodePagePng,
    this.assembler = assembleInIsolate,
    this.onStats,
  });

  /// Native layout renderer; created on demand when not supplied.
  final PdfNativeRenderer? nativeRenderer;

  /// Page encoder used by the raster path.
  final PageEncoder pageEncoder;

  /// PDF assembler used by the raster path.
  final PdfAssembler assembler;

  /// Capture accounting, reported by the tests.
  final void Function(PrintCaptureStats stats)? onStats;

  @override
  Future<Uint8List?> render(BuildContext context, PrintDocument document) =>
      document.needsRaster
      ? captureDocumentInDialog(
          context,
          document,
          pageEncoder: pageEncoder,
          assembler: assembler,
          onStats: onStats,
        )
      : (nativeRenderer ?? PdfNativeRenderer()).render(document);
}
