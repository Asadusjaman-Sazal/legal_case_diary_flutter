/// Platform boundary for Task 14's Print action.
///
/// The screen side talks to [PrintService], never to the `printing` plugin, so
/// the tests drive a fake and the Windows port has one seam to swap (the same
/// discipline the notification gateway follows). This file is the only place in
/// the app that may import `package:printing`.
library;

import 'dart:typed_data';

import 'package:printing/printing.dart';

/// Presents finished PDF bytes to the platform.
abstract interface class PrintService {
  /// Opens the OS print dialog (which on Android also offers "Save as PDF").
  ///
  /// Returns `true` when the platform took the job, and `false` when the user
  /// cancelled — the caller decides whether that deserves a message.
  Future<bool> present({required Uint8List bytes, required String jobName});
}

/// The Android implementation, backed by the `printing` plugin.
class PlatformPrintService implements PrintService {
  /// Creates the platform print service.
  const PlatformPrintService();

  @override
  Future<bool> present({
    required Uint8List bytes,
    required String jobName,
  }) {
    // The document is already laid out, so the callback hands back the same
    // bytes for every page the plugin asks about.
    return Printing.layoutPdf(
      name: jobName,
      onLayout: (format) => bytes,
    );
  }
}
