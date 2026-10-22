/// Where sync is asked to run, and where the Realtime channel is opened.
///
/// The plan names four moments, and Task 18 owns all four: **launch**, **resume**,
/// **reconnect**, and every **local write** (coalesced by the service's 2–3 s
/// window). The first three ask for the delta pull as well (`pull: true`) — those
/// are the moments the plan says to pull on — while a local write only pushes,
/// so a burst of edits never becomes thirteen requests.
///
/// Task 19 adds the Realtime channel to the same lifecycle observer: opened on
/// resume (and as soon as a signed-in profile arrives) and closed **immediately**
/// when the app leaves the foreground or the screen locks, so an idle app costs
/// zero radio. A ping does not pull anything by itself — the listener hands it to
/// the service, which runs a micro delta pull through the same merge path as the
/// full pull.
///
/// It renders its child untouched and never awaits a call, so a cold start on a
/// dead connection opens the diary exactly as fast as Part A did.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/device_providers.dart';
import '../features/accounts_and_profile/data/account_mode.dart';
import '../features/payments/data/subscription_activation.dart';
import 'connectivity_monitor.dart';
import 'recovery_flow.dart';
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
    // the queue first and then pulls every table's delta, and opens the Realtime
    // channel for as long as this app instance is in the foreground.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncServiceProvider).requestSync(pull: true);
      unawaited(_openChannelIfEntitled());
    });
  }

  /// Runs the extended-offline check for this device.
  ///
  /// Individual mode is exempt inside the flow itself: with a single author
  /// there is no other writer whose deletions could be resurrected.
  Future<void> _checkRecovery() async {
    if (!mounted) return;
    // Reading the server is sync; with sync off this waits too, and the enable
    // path runs it below.
    if (!ref.read(syncEnabledProvider)) return;
    try {
      final flow = await ref.read(recoveryFlowProvider.future);
      if (!mounted) return;
      await flow.checkOnReconnect();
    } on Object {
      // A check that cannot run must not break the launch path; the next
      // reconnect or profile refresh tries again.
    }
  }

  /// Opens the Realtime channel when this account is allowed to sync.
  ///
  /// A free account never syncs (plan §6), so it never holds a socket either:
  /// the channel is entitlement-gated exactly like the drain, and the entitlement
  /// itself is the one derivation every other gate reads.
  Future<void> _openChannelIfEntitled() async {
    if (!mounted) return;
    // The user's switch: a paused app holds no socket, exactly as it holds none
    // while signed out or on the free plan.
    if (!ref.read(syncEnabledProvider)) return;
    if (ref.read(premiumAccessProvider).value != true) return;
    await ref.read(realtimeListenerProvider).start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final listener = ref.read(realtimeListenerProvider);
    final health = ref.read(syncHealthControllerProvider);
    switch (state) {
      case AppLifecycleState.resumed:
        // Foregrounded: the reconnect ladder starts again, the channel is
        // rejoined — which bumps the generation if it had been closed — and the
        // resume entry point pulls unless continuity plus the 60 s window allow
        // skipping it.
        health.setForeground(true);
        unawaited(ref.read(deviceGateProvider.notifier).touch());
        ref.read(syncServiceProvider).requestResumeSync();
      case AppLifecycleState.inactive:
        // Transiently not accepting input: a call arriving, the app switcher, a
        // system dialog. The app is **not** backgrounded yet, so the channel
        // stays open — that is what lets a quick switch prove continuity and
        // skip a redundant pull.
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Backgrounded, the screen locked, or being torn down: close the channel
        // immediately so an idle app holds no socket and burns no radio.
        health.setForeground(false);
        unawaited(listener.stop());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reconnect: the plan's third moment, and the same entry point. The ladder
    // is reset and the channel rejoined, then anything missed while offline is
    // repaired by a push followed by a forced per-table pull — the pull is never
    // skippable here, because the connection generation may have changed while
    // the app was unable to hear about it.
    ref.listen(isOnlineProvider, (previous, next) {
      final health = ref.read(syncHealthControllerProvider);
      final online = next.value;
      if (previous?.value == false && online == true) {
        health.setOnline(true);
        // Reconnecting is when the per-device offline gap is measured: the
        // extended-offline lock engages here, before any push can send stale
        // work (Task 19 Phase 5). A locked device never reaches the sync below,
        // because the service refuses to run while the lock is set.
        unawaited(_checkRecovery());
        ref.read(syncServiceProvider).requestSync(pull: true);
      } else if (online == false) {
        // No link: stop the ladder instead of retrying into a dead socket.
        health.setOnline(false);
      }
    });

    // A signed-in account is what the topic is built from, so the channel opens
    // as soon as the cached profile arrives — a cold start reaches `resumed`
    // before the pull that carries it — and closes when the profile goes away.
    ref.listen(accountProfileProvider, (previous, next) {
      final listener = ref.read(realtimeListenerProvider);
      if (next.value != null) {
        // The cached profile is what says whether this is a firm account, so the
        // recovery check cannot run before it lands — and a cold start after a
        // long absence must still be checked, not only a reconnect.
        unawaited(_checkRecovery());
        unawaited(_openChannelIfEntitled());
      } else {
        unawaited(listener.stop());
      }
    });

    // Entitlement is derived, so it can change under a running app (a payment
    // lands, or a firm's subscription lapses). The channel follows it: an
    // account that may not sync holds no socket, and one that just may opens it.
    ref.listen(premiumAccessProvider, (previous, next) {
      final listener = ref.read(realtimeListenerProvider);
      if (next.value == true) {
        unawaited(listener.start());
      } else {
        unawaited(listener.stop());
      }
      // Entitlement turning true is the moment to ask for the pull the engine
      // has already dropped. The launch request runs before this account's
      // `profiles` row has been pulled, so `_isEntitled()` answers false and
      // `syncNow` returns silently — no backoff, no retry, nothing remembered.
      // Without this, the first sync of a session waits for a resume, a
      // reconnect or a local write, which is how "Last Sync" stays *Never* long
      // after the account is plainly premium. A renewal landing mid-session is
      // the same transition and wants the same pull.
      if (previous?.value != true && next.value == true) {
        ref.read(syncServiceProvider).requestSync(pull: true);
      }
      // Activation detection (Task 21 Phase 4): when entitlement rises from a
      // stored false to true — including across a restart, which is how an
      // approval lands — run the free → premium backlog pass exactly once.
      final premium = next.value;
      if (premium != null) {
        unawaited(
          ref.read(subscriptionActivationProvider).observe(premium),
        );
      }
    });

    // The user's own switch on the Online Sync screen (user request). Off is
    // immediate — the channel closes, so nothing arrives and nothing is sent,
    // and no trigger in this scope can reopen it or run a drain. On is a fresh
    // start: the channel is rejoined and a delta pull catches up on everything
    // that happened while sync was off, including the queue's own backlog.
    ref.listen(syncEnabledProvider, (previous, next) {
      if (!next) {
        unawaited(ref.read(realtimeListenerProvider).stop());
        return;
      }
      unawaited(_openChannelIfEntitled());
      unawaited(_checkRecovery());
      ref.read(syncServiceProvider).requestSync(pull: true);
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
