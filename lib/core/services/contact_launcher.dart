/// Platform boundary for the dialer, the SMS app and WhatsApp (Task 14 Phase 4).
///
/// The screens never import `url_launcher`; they build a URI with the helpers
/// here and hand it to a [ContactLauncher]. The same seam lets the tests assert
/// exactly which URI a tap would open, which is the part worth pinning: the
/// Addendum forbids undocumented URL schemes, so the routes taken are a rule.
library;

import 'package:url_launcher/url_launcher.dart';

/// Opens an external app for [uri].
abstract interface class ContactLauncher {
  /// Returns `false` when no app could handle [uri] (the caller says so).
  Future<bool> open(Uri uri);
}

/// The Android implementation, backed by `url_launcher`.
class UrlContactLauncher implements ContactLauncher {
  /// Creates the launcher.
  const UrlContactLauncher();

  @override
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

/// Normalizes a stored number for launching.
///
/// Spaces, dashes and brackets are stripped and a single leading `+` is kept;
/// anything without at least six digits is refused rather than dialled, so a
/// half-typed number can never be launched by accident.
String? normalizeLaunchNumber(String? raw) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty) return null;

  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 6) return null;

  return trimmed.startsWith('+') ? '+$digits' : digits;
}

/// The digits-only form WhatsApp's `wa.me` path expects (`+8801…` → `8801…`).
String? whatsAppNumber(String? raw) {
  final normalized = normalizeLaunchNumber(raw);
  return normalized?.replaceAll(RegExp(r'[^0-9]'), '');
}

/// `tel:` URI for a standard phone call.
Uri telUri(String number) => Uri(scheme: 'tel', path: number);

/// `sms:` URI with the pre-filled message body (plan §9's template).
Uri smsUri(String number, String body) =>
    Uri(scheme: 'sms', path: number, queryParameters: {'body': body});

/// `https://wa.me/<number>?text=<message>` — WhatsApp's documented chat route.
///
/// This is the fallback the Addendum asks for: WhatsApp publishes no call URL
/// scheme, so the app opens the chat and never invents a call scheme.
Uri whatsAppUri(String number, String message) =>
    Uri.https('wa.me', '/$number', {'text': message});
