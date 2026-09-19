/// Providers for the print and app-share platform services (Task 14 Phase 3).
///
/// Both services own a platform channel, so screens read them from here and the
/// tests override them with fakes instead of reaching for a device.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../print/print_document_renderer.dart';
import '../print/print_service.dart';
import '../services/app_share_service.dart';

/// Presents finished PDF bytes to the OS print dialog.
final printServiceProvider = Provider<PrintService>(
  (ref) => const PlatformPrintService(),
);

/// Renders a print document the way its script requires (native text or
/// bounded raster pages). Overridden in the tests with a recorder.
final printDocumentRendererProvider = Provider<PrintDocumentRenderer>(
  (ref) => const ScriptAwarePrintRenderer(),
);

/// Shares the app through the platform's sharing utility.
final appShareServiceProvider = Provider<AppShareService>(
  (ref) => const PlatformAppShareService(),
);
