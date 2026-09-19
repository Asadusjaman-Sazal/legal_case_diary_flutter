/// Progress and cancellation for a raster capture (Task 14 Phase 2, item 6).
///
/// A long cause list takes a moment to render page by page, so the user gets a
/// progress count and a way out. A failure is reported back to the caller
/// instead of thrown, so the screen can show a recoverable message.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../l10n/generated/app_localizations.dart';
import 'print_document.dart';
import 'print_page_capture.dart';

/// Captures [document] behind a progress dialog.
///
/// Returns the PDF bytes, or `null` when the user cancelled or the capture
/// failed. Nothing is thrown here.
Future<Uint8List?> captureDocumentInDialog(
  BuildContext context,
  PrintDocument document, {
  void Function(PrintCaptureStats stats)? onStats,
  PageEncoder pageEncoder = encodePagePng,
  PdfAssembler assembler = assembleInIsolate,
}) => showDialog<Uint8List>(
  context: context,
  barrierDismissible: false,
  builder: (context) => _CaptureDialog(
    document: document,
    onStats: onStats,
    pageEncoder: pageEncoder,
    assembler: assembler,
  ),
);

/// The dialog card, with the invisible capture beside it in the same stack.
class _CaptureDialog extends StatefulWidget {
  const _CaptureDialog({
    required this.document,
    this.onStats,
    required this.pageEncoder,
    required this.assembler,
  });

  final PrintDocument document;
  final void Function(PrintCaptureStats stats)? onStats;
  final PageEncoder pageEncoder;
  final PdfAssembler assembler;

  @override
  State<_CaptureDialog> createState() => _CaptureDialogState();
}

class _CaptureDialogState extends State<_CaptureDialog> {
  bool _cancelled = false;
  bool _failed = false;
  int _page = 0;
  int _total = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final total = _total == 0 ? 1 : _total;

    return PopScope(
      canPop: false,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Off the visible area, but still laid out and painted: a capture
          // needs a painted layer, so `Offstage` would not do.
          Positioned(
            left: -2000,
            top: 0,
            child: PrintPageCapture(
              document: widget.document,
              isCancelled: () => _cancelled,
              pageEncoder: widget.pageEncoder,
              assembler: widget.assembler,
              onStats: widget.onStats,
              onProgress: (page, total) {
                if (!mounted) return;
                setState(() {
                  _page = page;
                  _total = total;
                });
              },
              onCompleted: (bytes) {
                if (mounted) Navigator.of(context).pop(bytes);
              },
              onCancelled: () {
                if (mounted) Navigator.of(context).pop();
              },
              onFailed: (error) {
                if (!mounted) return;
                setState(() {
                  _failed = true;
                  _page = 0;
                  _total = 0;
                });
              },
            ),
          ),
          AlertDialog(
            title: Text(l.print_preparing),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(value: _total == 0 ? null : _page / _total),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _failed
                      ? l.print_failed
                      : l.print_pageOf(_page, total),
                  key: const ValueKey('print-progress-label'),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.document.title,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              TextButton(
                key: const ValueKey('print-cancel'),
                onPressed: _failed
                    ? () => Navigator.of(context).pop()
                    : () => setState(() => _cancelled = true),
                child: Text(l.sharedActions_cancel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
