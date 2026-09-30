/// Where sync is asked to run.
///
/// The plan names four moments, and Task 18 owns all four: **launch**, **resume**,
/// **reconnect**, and every **local write** (coalesced by the service's 2–3 s
/// window). The first three ask for the delta pull as well (`pull: true`) — those
/// are the moments the plan says to pull on — while a local write only pushes,
/// so a burst of edits never becomes thirteen requests. Realtime pings and the
/// Sync Status UI are Task 19's; they call the same `requestSync()` entry point.
///
/// It renders its child untouched and never awaits a call, so a cold start on a
/// dead connection opens the diary exactly as fast as Part A did.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_monitor.dart';
import 'sync_providers.dart';
import 'sync_service.dart';

/// Triggers sync on the app lifecycle and on connectivity changes.
class SyncTriggerScope extends ConsumerStatefulWidget {
  /// Creates the scope around [child].
  const SyncTriggerScope({required this.child, super.key});

  /// The app subtree; returned unchanged.
  final Widget child;

  @override
  ConsumerState<SyncTriggerScope> createState() => _SyncTriggerScopeState();
}

class _SyncTriggerScopeState extends ConsumerState<SyncTriggerScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // After the first frame, so the diary is already on screen. Launch pushes
    // the queue first and then pulls every table's delta.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(syncServiceProvider).requestSync(pull: true),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Foregrounded: push pending work, then pull every table's delta.
    if (state == AppLifecycleState.resumed) {
      ref.read(syncServiceProvider).requestSync(pull: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reconnect: the plan's third moment, and the same entry point. Anything
    // missed while offline is repaired by the pull, so it is always asked for.
    ref.listen(isOnlineProvider, (previous, next) {
      if (previous?.value == false && next.value == true) {
        ref.read(syncServiceProvider).requestSync(pull: true);
      }
    });

    // A new pending row means a local write landed; coalesce and push. Only a
    // rise in the pending count triggers, so the worker's own churn does not.
    ref.listen(syncQueuePendingCountProvider, (previous, next) {
      final was = previous?.value ?? 0;
      final now = next.value;
      if (now != null && now > was) {
        ref.read(syncServiceProvider).requestSync();
      }
    });

    return widget.child;
  }
}
