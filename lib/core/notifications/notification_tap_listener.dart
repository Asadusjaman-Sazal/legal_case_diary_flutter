/// Bridges notification taps to the router.
///
/// Mounted around the app's navigator, it registers the tap handler and
/// initializes the scheduler once per app process (Task 13 Phase 1, item 5:
/// a tap opens that case's detail view). A tap that *launches* the app is
/// handled by [appRouterProvider] through the scheduler's launch payload, so
/// both cold and warm taps land on the same screen.
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
    scheduler.onCaseSelected(_openCase);
    // Initialization arms the daily alarm; it must not delay the first frame,
    // so it runs unawaited and reports nothing the UI needs.
    unawaited(scheduler.initialize());
  }

  void _openCase(String caseId) {
    if (!mounted) return;
    widget.router.go(AppRoutes.caseDetailPath(caseId));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
