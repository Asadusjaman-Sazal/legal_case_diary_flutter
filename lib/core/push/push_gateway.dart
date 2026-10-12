/// The Firebase Cloud Messaging boundary.
///
/// The **only** file in the app that imports `firebase_core` or
/// `firebase_messaging` — the single-boundary rule `android_notification_gateway.dart`
/// follows for the notification and alarm packages, and for the same reasons:
/// call sites depend on [PushGateway] and never on the SDK, and a platform with
/// no FCM replaces one file instead of every caller.
///
/// What arrives here is the admin payment-alert sender's **data-only** message.
/// This file hands the payload to [applyPaymentAlert] — in the foreground
/// through the listener [FcmPushGateway.initialize] registers, and while the app
/// is backgrounded or closed through [pushGatewayBackgroundHandler]. The message
/// carries the two numbers and nothing else: the words, the language's own
/// digits and the notification itself are local work, on a purely local path.
///
/// **Nothing here asks for a permission.** The OS notification permission belongs
/// to Settings → Notifications, where the user switches these alerts on and where
/// the test alert already asks for it; a prompt at sign-in would be a dialog
/// nobody connected to anything.
library;

import 'dart:async';
import 'dart:developer' as dev;
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'payment_alert_message.dart';

/// Entry point FCM runs in its own isolate for a message that arrives while the
/// app is backgrounded or closed.
///
/// Top-level and `@pragma('vm:entry-point')` on purpose, like the daily hearing
/// job: the AOT compiler must keep it, and FCM resolves it by callback handle.
/// It posts one local notification and returns — no network call, no database,
/// no Supabase — which is the plan §12.3 shape and what keeps a push handler
/// from costing battery.
@pragma('vm:entry-point')
Future<void> pushGatewayBackgroundHandler(RemoteMessage message) async {
  // A second isolate, so the plugins registered on this engine have to be wired
  // to its channel handlers before the notification plugin can post anything.
  DartPluginRegistrant.ensureInitialized();
  try {
    await applyPaymentAlert(message.data);
  } catch (error, stackTrace) {
    // A failed handler must never crash the FCM isolate: the next message (or
    // the next launch) carries the same count again.
    dev.log(
      'Payment alert message failed',
      name: 'push',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// The push contract the app depends on.
///
/// Small on purpose: the app needs to wire the handlers once, learn this
/// device's registration token, and be told when it changes.
abstract class PushGateway {
  /// Wires the foreground and background message handlers.
  ///
  /// Idempotent and safe to call on a build with no Firebase configuration: it
  /// reports a failure and leaves [token] answering null.
  Future<void> initialize();

  /// This device's FCM registration token, or null when push is unavailable.
  Future<String?> token();

  /// Tokens the device has been given since [initialize], in order.
  ///
  /// Empty while [initialize] has not succeeded — a reinstall, a restore or a
  /// long-idle refresh gives the device a new token, and the server's row has to
  /// follow it or the alerts stop silently.
  Stream<String> tokenRefreshes();
}

/// The real gateway, over `firebase_core` and `firebase_messaging`.
class FcmPushGateway implements PushGateway {
  /// Whether this isolate already wired the handlers.
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      // The default app from `android/app/google-services.json` (Phase 1). A
      // build without that file has no FCM at all, and this is where it says so
      // rather than at the first token request.
      await Firebase.initializeApp();
      // Registered before any token is read: FCM resolves this handler by
      // callback handle the moment a message arrives, and one can arrive while
      // the app is cold.
      FirebaseMessaging.onBackgroundMessage(pushGatewayBackgroundHandler);
      // The foreground half. The same notification the background isolate posts,
      // so the count reads identically whether the app is open, backgrounded or
      // closed — the one design the user chose over a silent foreground. The
      // subscription is deliberately not kept: this gateway lives as long as the
      // process does, and FCM's stream is `static`.
      FirebaseMessaging.onMessage.listen(
        (message) => unawaited(applyPaymentAlert(message.data)),
        onError: (Object error, StackTrace stackTrace) =>
            _logFailure('payment alert message failed', error, stackTrace),
      );
      _initialized = true;
    } catch (error, stackTrace) {
      _logFailure('push initialization failed', error, stackTrace);
    }
  }

  @override
  Future<String?> token() async {
    // Only a gateway that wired its handlers may hand out a token: registering
    // one from a half-initialized SDK would put a device in the server's fan-set
    // that could never show what it was sent.
    if (!_initialized) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (error, stackTrace) {
      _logFailure('push token unavailable', error, stackTrace);
      return null;
    }
  }

  @override
  Stream<String> tokenRefreshes() => _initialized
      ? FirebaseMessaging.instance.onTokenRefresh
      : const Stream<String>.empty();
}

/// The push gateway, one per app process.
final pushGatewayProvider = Provider<PushGateway>((ref) => FcmPushGateway());

/// Logs and swallows a failure on the push path.
///
/// Push is an enhancement an administrator may never notice the loss of, and it
/// runs unattended on a platform that may have no plugin at all (the test host,
/// the Windows port), so nothing here may surface as an unhandled error.
void _logFailure(String what, Object error, StackTrace stackTrace) {
  dev.log(what, name: 'push', error: error, stackTrace: stackTrace);
}
