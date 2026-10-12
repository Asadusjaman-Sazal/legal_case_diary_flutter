/// Bridges notification taps to the router.
///
/// Mounted around the app's navigator, it registers the tap handler and
/// initializes the scheduler once per app process (Task 13 Phase 1, item 5: a tap
/// opens the screen its notification is about — a hearing alert opens that case's
/// detail view, the admin payment alert opens the panel's Payment Requests page).
/// A tap that *launches* the app is handled by [appRouterProvider] through the
/// same resolver, so cold and warm taps land on the same screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/notification_providers.dart';
import '../router/app_router.dart';

/// Registers notification handling for the app's lifetime.
class NotificationTapListener extends ConsumerStatefulWidget {
  /// Router used to open the tapped case.
  final GoRouter router;

  /// The app content below this listener.
  final Widget child;

  /// Creates the listener.
  const NotificationTapListener({
    required this.router,
    required this.child,
    super.key,
  });

  @override
  ConsumerState<NotificationTapListener> createState() =>
      _NotificationTapListenerState();
}

class _NotificationTapListenerState
    extends ConsumerState<NotificationTapListener> {
  @override
  void initState() {
    super.initState();
    final scheduler = ref.read(notificationSchedulerProvider);
    // Register the handler before initializing, so a tap that arrives during
    // startup is not dropped.
    scheduler.onNotificationSelected(_openPayload);
    // Initialization arms the daily alarm; it must not delay the first frame,
    // so it runs unawaited and reports nothing the UI needs.
    unawaited(scheduler.initialize());
  }

  /// Opens the destination the tapped notification names.
  ///
  /// The payload is resolved through the router's own [notificationPayloadRoute],
  /// so a warm tap and a tap that launched the app cannot disagree about where
  /// the same notification goes.
  void _openPayload(String payload) {
    if (!mounted) return;
    widget.router.go(notificationPayloadRoute(payload));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
