/// Platform boundary for the dialer, the SMS app and WhatsApp (Task 14 Phase 4).
///
/// The screens never import `url_launcher`; they build a URI with the helpers
/// here and hand it to a [ContactLauncher]. The same seam lets the tests assert
/// exactly which URI a tap would open, which is the part worth pinning: the
/// Addendum forbids undocumented URL schemes, so the routes taken are a rule.
///
/// The Support screen (Settings > About > Support) reuses the same helpers for
/// its WhatsApp chat and `mailto:` channels.
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

/// `mailto:<address>?subject=<subject>&body=<message>` — the mail app's route.
///
/// Used by the Support screen, whose pre-filled message is written once and
/// handed to both channels.
///
/// The query is encoded pair by pair with [Uri.encodeComponent] instead of
/// `queryParameters`: `Uri`'s own query encoder writes a space as `+` (it is
/// built for HTML form bodies, where `+` means space), but a mail client reads
/// the `body` literally, so every space in the message arrived as a plus sign.
/// `%20` is the encoding every mail app decodes as a space.
Uri mailtoUri(String address, String subject, String body) => Uri(
  scheme: 'mailto',
  path: address,
  query: '${_mailtoField('subject', subject)}&${_mailtoField('body', body)}',
);

/// One `mailto:` query field, percent-encoded so a space stays a space.
String _mailtoField(String name, String value) =>
    '${Uri.encodeComponent(name)}=${Uri.encodeComponent(value)}';

/// The bare `mailto:` route, whose whole job is to raise the mail app chooser.
///
/// With no recipient the URI names no account, so Android offers every app that
/// handles mail — Gmail, Proton Mail, the vendor client — and the user picks the
/// one their confirmation mail arrived in. That is the point: the Check Your
/// Email screen's **Open Mail** has to land the user in their own mailbox, not
/// in a compose window addressed to the app's support address.
Uri mailAppUri() => Uri(scheme: 'mailto');

/// `https://wa.me/<number>` — WhatsApp's documented chat route, with no text.
///
/// The case contact chooser opens this from both its call and message sheets:
/// it lands the user in the client's chat, which is where a call is started and
/// where they can write whatever they actually want to say. Nothing is
/// pre-written into the composer for them.
Uri whatsAppChatUri(String number) => Uri.https('wa.me', '/$number');

/// `https://wa.me/<number>?text=<message>` — the chat route with the text.
///
/// This is the fallback the Addendum asks for: WhatsApp publishes no call URL
/// scheme, so the app opens the chat and never invents a call scheme.
///
/// This one keeps `queryParameters` (the form-style `+`-for-space encoding)
/// on purpose: WhatsApp's handler decodes `+` as a space, so the message the
/// user sees is unaffected - unlike `mailto:` above, which is read literally.
Uri whatsAppUri(String number, String message) =>
    Uri.https('wa.me', '/$number', {'text': message});
