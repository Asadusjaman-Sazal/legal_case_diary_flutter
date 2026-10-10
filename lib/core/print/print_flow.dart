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

import '../utils/date_utils.dart';
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

/// The name a print job is saved under: the document's own title plus the
/// print date — `All Cases 10-10-26`.
///
/// The OS pre-fills its "Save as PDF" file name with this job name, so adding
/// the date makes every saved file self-describing (and two prints of the same
/// screen on different days no longer collide). The date is the day it is
/// printed, in the app's Bangladesh civil time like every other date, and in
/// **Latin digits whatever the active language**: a file name is not prose, and
/// Bengali digits would be awkward to type or search on a desktop.
String printJobName(String title, {int? printedAtEpochMs}) {
  final at = AppDateUtils.bangladeshDateTime(
    printedAtEpochMs ?? DateTime.now().millisecondsSinceEpoch,
  );
  String two(int value) => value.toString().padLeft(2, '0');
  return '$title ${two(at.day)}-${two(at.month)}-${two(at.year % 100)}';
}

/// Renders [document] the way its script requires and presents it.
Future<PrintOutcome> printDocument({
  required BuildContext context,
  required PrintDocument document,
  required PrintService service,
  required PrintDocumentRenderer renderer,
  int? printedAtEpochMs,
}) async {
  if (document.isEmpty) return PrintOutcome.nothingToPrint;

  try {
    final Uint8List? bytes = await renderer.render(context, document);
    if (bytes == null) return PrintOutcome.cancelled;

    final presented = await service.present(
      bytes: bytes,
      jobName: printJobName(document.title, printedAtEpochMs: printedAtEpochMs),
    );
    return presented ? PrintOutcome.presented : PrintOutcome.cancelled;
  } catch (_) {
    // A print job is never worth taking a screen down for.
    return PrintOutcome.failed;
  }
}
