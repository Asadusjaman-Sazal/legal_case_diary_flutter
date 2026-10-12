/// The admin payment-alert message: what a push says, and what it does.
///
/// The sender (`supabase/functions/send-admin-payment-alerts`) posts a
/// **data-only** message — `{pending, alert}` — because the words live in this
/// app's ARB files: the count is written in the device's own language and digits
/// here, not on the server. One message therefore reads correctly in English and
/// in বাংলা.
///
/// This file is the one path both isolates share. The foreground handler and the
/// background isolate (`push_gateway.dart`) both call [applyPaymentAlert], and
/// neither reaches the network, the database or the sync engine: the payload
/// carries the numbers, and the only other read is the language the app already
/// stored. That is the plan §12.3 shape applied to push — the handler posts one
/// local notification and nothing else — and `push_local_only_test.dart` guards
/// it at source level.
///
/// The count is never guessed and never accumulated: every message carries the
/// server's current pending total, so a re-post replaces the line that is already
/// there, and a total of zero **cancels** it instead of announcing it.
library;

import 'dart:ui' show Locale;

import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/generated/app_localizations.dart';
import '../notifications/android_notification_gateway.dart';
import '../utils/date_utils.dart';

/// Preference key the active language code is persisted under.
///
/// Read rather than borrowed from `localeProvider`: the background isolate has no
/// Riverpod scope, and both halves must build the same words from the same value.
const String _localeKey = 'app_locale';

/// Language used when the device has stored none — the app's own default.
const String _fallbackLanguage = 'en';

/// Payload carried by the payment-alert notification.
///
/// The app's own token for "this is the admin payment alert", never a case id, so
/// a tap on it opens the page the alert is about rather than a case detail that
/// does not exist (`notificationPayloadRoute`, its one reader). Spelled with a
/// hyphen and not as a UUID, which is what a case id always is.
const String paymentAlertPayload = 'admin-payment-requests';

/// One parsed payment-alert payload.
class PaymentAlert {
  /// How many payment submissions the server holds as pending right now.
  final int pending;

  /// Whether this is the arrival (nothing pending → something pending) rather
  /// than a later correction.
  ///
  /// The sender sets it, and only it earns a sound and a high-priority wake; a
  /// correction is the same line, quietly rewritten.
  final bool alert;

  /// Creates a parsed alert.
  const PaymentAlert({required this.pending, required this.alert});

  /// Reads the sender's data payload, or null when it is not one.
  ///
  /// A message whose `pending` is missing or unreadable is ignored rather than
  /// treated as zero: a payload this app does not understand must never clear a
  /// line that is still true.
  static PaymentAlert? fromData(Map<String, dynamic> data) {
    final pending = int.tryParse('${data['pending'] ?? ''}');
    if (pending == null) return null;
    return PaymentAlert(
      pending: pending,
      alert: '${data['alert'] ?? ''}'.toLowerCase() == 'true',
    );
  }
}

/// The words one payment alert shows.
class PaymentAlertNotice {
  /// Notification title.
  final String title;

  /// Notification body: the count, already written in the language's own digits.
  final String body;

  /// Whether this is the arrival (nothing pending → something pending) rather
  /// than a correction. It is what earns sound and vibration.
  final bool alert;

  /// Creates a notice.
  const PaymentAlertNotice({
    required this.title,
    required this.body,
    required this.alert,
  });
}

/// Builds the notice for [alert] in [language].
///
/// Pure on purpose: no plugin, no store, no clock, so the one part of this path
/// a test host cannot exercise for real — what the line actually says — is
/// checked directly. The count goes through the same `intl` formatter the
/// panel's badge uses, so বাংলা reads ৫ where English reads 5.
PaymentAlertNotice buildPaymentAlertNotice(PaymentAlert alert, String language) {
  final l = lookupAppLocalizations(Locale(language));
  return PaymentAlertNotice(
    alert: alert.alert,
    title: l.adminPush_title,
    body: alert.pending == 1
        ? l.adminPush_bodyOne
        : l.adminPush_bodyMany(AppDateUtils.formatDigits(alert.pending, language)),
  );
}

/// Applies one data message: posts the count, replaces it, or cancels it.
///
/// Called from the foreground listener and from the FCM background isolate, so it
/// must stay cheap and local. It never throws: a plugin that is not there (the
/// test host, a build with no Firebase configuration) must not fail the isolate
/// that called it.
Future<void> applyPaymentAlert(Map<String, dynamic> data) async {
  final alert = PaymentAlert.fromData(data);
  if (alert == null) return;

  if (alert.pending <= 0) {
    // Nothing is waiting: the honest answer is an empty notification tray, not a
    // line claiming zero requests. (The sender still sends the zero, which is how
    // the last request being resolved clears the line on the device.)
    await AndroidNotificationGateway.cancelPaymentAlert();
    return;
  }

  final language = await storedLanguage();
  final notice = buildPaymentAlertNotice(alert, language);
  final l = lookupAppLocalizations(Locale(language));
  await AndroidNotificationGateway.presentPaymentAlert(
    alert: notice.alert,
    title: notice.title,
    body: notice.body,
    channelName: l.adminPush_channelName,
    channelDescription: l.adminPush_channelDescription,
    // What a tap on the line does: the payment requests page, which is where the
    // count the notification is about can actually be acted on.
    payload: paymentAlertPayload,
  );
}

/// The language the device last stored, or the app's default.
///
/// SharedPreferences rather than the database, for the same reason the daily
/// hearing job reads the language it does: a background isolate must be able to
/// answer without opening the encrypted diary.
Future<String> storedLanguage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_localeKey);
    return (stored == null || stored.isEmpty) ? _fallbackLanguage : stored;
  } catch (_) {
    // An unreadable store is not a reason to drop the alert: English is the
    // app's default language, and the count is what the notification is for.
    return _fallbackLanguage;
  }
}
