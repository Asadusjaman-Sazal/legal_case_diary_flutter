/// The Print action's whole path: render the document, then present it.
///
/// The renderer is chosen by the document's own script rule (Phase 1): Bengali
/// content goes through the bounded raster capture behind a progress dialog,
/// Latin-only content straight through the native text layout, which finishes
/// in milliseconds and needs no dialog. Everything ends in an outcome the
/// screen can word, so a failed print never crashes a screen.
library;

import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'print_document.dart';
import 'print_document_renderer.dart';
import 'print_service.dart';

/// What a Print action did.
enum PrintOutcome {
  /// The OS took the job (it may still be cancelled inside the system dialog).
  presented,

  /// The user cancelled, before or inside the system dialog.
  cancelled,

  /// Rendering or presenting failed; the caller shows a recoverable message.
  failed,

  /// There was nothing to print (no rows for the current filters).
  nothingToPrint,
}

/// Renders [document] the way its script requires and presents it.
Future<PrintOutcome> printDocument({
  required BuildContext context,
  required PrintDocument document,
  required PrintService service,
  required PrintDocumentRenderer renderer,
}) async {
  if (document.isEmpty) return PrintOutcome.nothingToPrint;

  try {
    final Uint8List? bytes = await renderer.render(context, document);
    if (bytes == null) return PrintOutcome.cancelled;

    final presented = await service.present(
      bytes: bytes,
      jobName: document.title,
    );
    return presented ? PrintOutcome.presented : PrintOutcome.cancelled;
  } catch (_) {
    // A print job is never worth taking a screen down for.
    return PrintOutcome.failed;
  }
}
