/// Pull-down-to-sync for a routed page, for premium accounts only.
///
/// The gesture runs the same forced sync as the header Sync button
/// (`SyncService.retryNow`) and then the page's own reload, when it has one.
/// A free account gets its child untouched: nothing suggests a cloud sync it
/// is not allowed to perform.
///
/// A short page (a settings menu, a device list with one row) can still be
/// pulled because the physics is always scrollable, but it is bound to the
/// platform's own physics and the overscroll effect is off: the pull moves the
/// refresh spinner, never the page under the finger.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/accounts_and_profile/data/account_mode.dart';
import '../../sync/sync_service.dart';

/// The scroll behaviour a pull-to-sync page needs.
///
/// [AlwaysScrollableScrollPhysics] on its own has no bounds, so a short page
/// would follow the finger and stay where it was dropped; binding it to the
/// platform physics keeps the content clamped. The overscroll effect is off
/// because on Android 12+ it stretches the page itself.
ScrollBehavior pullScrollBehavior(BuildContext context) {
  final base = ScrollConfiguration.of(context);
  return base.copyWith(
    physics: AlwaysScrollableScrollPhysics(
      parent: base.getScrollPhysics(context),
    ),
    overscroll: false,
  );
}

/// Wraps a routed page's scrollable in a premium pull-to-sync gesture.
class PullToSync extends StatelessWidget {
  /// Creates the gesture around [child].
  const PullToSync({required this.child, this.onReload, super.key});

  /// The page body. It must contain a vertical scrollable.
  final Widget child;

  /// Runs after the sync, so the page can re-read its own rows.
  final Future<void> Function()? onReload;

  @override
  Widget build(BuildContext context) {
    // The app always mounts a ProviderScope. A widget test that renders the
    // shell on its own may not; such a page still renders, just without the
    // gesture, instead of failing on a missing scope.
    try {
      ProviderScope.containerOf(context, listen: false);
    } on StateError {
      return child;
    }

    return Consumer(
      builder: (context, ref, _) {
        // Unknown or free entitlement: leave the page exactly as it was.
        if (ref.watch(premiumAccessProvider).value != true) return child;

        return RefreshIndicator(
          onRefresh: () async {
            await ref.read(syncServiceProvider).retryNow();
            if (onReload != null) await onReload!();
          },
          child: ScrollConfiguration(
            behavior: pullScrollBehavior(context),
            child: child,
          ),
        );
      },
    );
  }
}
