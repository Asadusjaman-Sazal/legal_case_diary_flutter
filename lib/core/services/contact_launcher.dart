/// Platform boundary for the dialer, the SMS app, WhatsApp and the mail app
/// (Task 14 Phase 4).
///
/// The screens never import `url_launcher` or `android_intent_plus`; they build a
/// URI with the helpers here — or ask for the mail app, which is an intent rather
/// than a route — and hand the request to a [ContactLauncher]. The same seam lets
/// the tests assert exactly which URI a tap would open, which is the part worth
/// pinning: the Addendum forbids undocumented URL schemes, so the routes taken
/// are a rule.
///
/// The Support screen (Settings > About > Support) reuses the same helpers for
/// its WhatsApp chat and `mailto:` channels.
library;

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens an external app for [uri], or the device's mail app.
abstract interface class ContactLauncher {
  /// Returns `false` when no app could handle [uri] (the caller says so).
  Future<bool> open(Uri uri);

  /// Opens the device's mail app on its **own** screen — not a new message.
  ///
  /// Returns `false` when no mail app could be opened (the caller says so).
  Future<bool> openMailApp();
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

  @override
  Future<bool> openMailApp() async {
    // Resolvability is asked first because `launch()` is a no-op off Android:
    // it returns without doing anything at all there, so a platform that cannot
    // answer has to take the fallback rather than report a success it did not
    // have.
    try {
      if (await androidMailAppIntent.canResolveActivity() ?? false) {
        await androidMailAppIntent.launch();
        return true;
      }
    } catch (_) {
      // An unresolvable intent is not a dead button; fall through.
    }
    return open(mailAppUri());
  }
}

/// Android's own "the email app" intent: `MAIN` plus the `APP_EMAIL` category.
///
/// A `mailto:` URI means "write a message" by definition (RFC 6068), so the
/// chooser it raises can only offer each mail app's **compose** activity — the
/// user picks Gmail and gets an empty draft, which is not what the Check Your
/// Email screen's Open Mail means. Android keeps a category for the app itself,
/// so this asks for *the email app*: it opens on its main screen (the inbox),
/// and where several apps qualify Android raises its own chooser of app entries —
/// the "pick your mail app" the button wanted, without the draft. A constant,
/// and public, so a test can state the action, category and flag it sends without
/// a phone. The manifest's `<queries>` declares this intent, which is what makes
/// it visible and launchable on Android 11 and later.
///
/// **`FLAG_ACTIVITY_NEW_TASK` is not decoration — its absence was a real defect.**
/// `android_intent_plus` starts the intent from *our* live activity with no flags
/// at all, so the mail app's activity was pushed onto **our** task: Back from the
/// mail app then closed the app and reopening it from the launcher brought the
/// mail screen back inside it, because the task the system resumed was ours with
/// the mail app on top. `NEW_TASK` opens the mail app in its own task, which is
/// what the launcher does when the user taps its icon and what `url_launcher`'s
/// external-application mode did for the `mailto:` route before this — so Back
/// returns to this app and this app's own task stays ours.
const AndroidIntent androidMailAppIntent = AndroidIntent(
  action: 'android.intent.action.MAIN',
  category: 'android.intent.category.APP_EMAIL',
  flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
);

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

/// The bare `mailto:` route, whose job is to raise the mail app chooser.
///
/// With no recipient the URI names no account, so Android offers every app that
/// handles mail — Gmail, Proton Mail, the vendor client — and the user picks the
/// one their confirmation mail arrived in. It is now the **fallback** behind
/// [ContactLauncher.openMailApp]: a `mailto:` chooser can only offer compose
/// activities, so it is used when the platform cannot answer the email-app
/// intent (a non-Android device, or one with no app registered as the mail app),
/// where reaching a mailbox at all still beats a dead button. The Support screen
/// keeps its own addressed [mailtoUri].
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
