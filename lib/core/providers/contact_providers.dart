/// Provider for the external-app launcher (Task 14 Phase 4).
///
/// The screens never import `url_launcher`: they build a URI with the helpers in
/// `core/services/contact_launcher.dart` and hand it to this seam, so a widget
/// test can assert exactly which URI a tap would open.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/contact_launcher.dart';

/// Opens the dialer, the SMS app and WhatsApp.
final contactLauncherProvider = Provider<ContactLauncher>(
  (ref) => const UrlContactLauncher(),
);
