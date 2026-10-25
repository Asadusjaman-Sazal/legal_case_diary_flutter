/// Watches for the admin's decision right after a payment is submitted.
///
/// A free account holds no Realtime socket (sync is entitlement-gated) and no
/// approval push exists, so the payer's app would otherwise learn about an
/// approval only on launch, resume, reconnect or sign-in. After a confirmed
/// submission the checkout starts this watch: the account is re-read every
/// [paymentApprovalWatchInterval] for [paymentApprovalWatchWindow], which is
/// enough for the plan label, the gates and the ledger to update without a
/// sign-out. It is deliberately bounded — a payment left undecided longer than
/// the window falls back to the ordinary launch/resume refresh.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../../accounts_and_profile/data/account_mode.dart';

/// How long a freshly submitted payment is watched for a decision.
const Duration paymentApprovalWatchWindow = Duration(minutes: 10);

/// How often the account is re-read while that watch is running.
const Duration paymentApprovalWatchInterval = Duration(seconds: 30);

/// How many refreshes one watch runs: the window divided by the interval.
final int paymentApprovalWatchTicks =
    paymentApprovalWatchWindow.inSeconds ~/
    paymentApprovalWatchInterval.inSeconds;

/// A counter that starts a watch; zero means nothing is being watched.
///
/// An int rather than a bool so a second submission inside the window restarts
/// the ten minutes instead of being swallowed by the first watch.
class PaymentApprovalWatch extends Notifier<int> {
  @override
  int build() => 0;

  /// Starts (or restarts) the watch.
  void start() => state++;

  /// Ends the watch.
  void stop() => state = 0;
}

/// The watch's start signal.
final paymentApprovalWatchProvider =
    NotifierProvider<PaymentApprovalWatch, int>(PaymentApprovalWatch.new);

/// Runs the bounded refresh while a submitted payment waits for a decision.
class PaymentApprovalWatchScope extends ConsumerStatefulWidget {
  /// Creates the scope around [child].
  const PaymentApprovalWatchScope({required this.child, super.key});

  /// The app below the scope.
  final Widget child;

  @override
  ConsumerState<PaymentApprovalWatchScope> createState() =>
      _PaymentApprovalWatchScopeState();
}

class _PaymentApprovalWatchScopeState
    extends ConsumerState<PaymentApprovalWatchScope>
    with WidgetsBindingObserver {
  Timer? _timer;

  /// Refreshes left in the current watch.
  int _ticksLeft = 0;

  /// Whether the account was already premium when the watch started, so a
  /// free → premium approval can end it early while a renewal cannot.
  bool _wasPremium = false;

  /// One refresh at a time: a slow pull must not stack up ticks.
  bool _working = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // The account refresh on resume is AccountRefreshScope's job; the watch
      // only carries on with its remaining ticks while the app is in front.
      if (ref.read(paymentApprovalWatchProvider) > 0) _startTimer();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Starts a fresh window.
  void _start() {
    _ticksLeft = paymentApprovalWatchTicks;
    _wasPremium = ref.read(premiumAccessProvider).value == true;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_ticksLeft <= 0) {
      _finish();
      return;
    }
    _timer = Timer.periodic(paymentApprovalWatchInterval, (_) => _tick());
  }

  Future<void> _tick() async {
    if (!mounted) return;
    if (_ticksLeft <= 0) {
      _finish();
      return;
    }
    _ticksLeft--;
    if (_working) return;
    _working = true;
    try {
      await ref.read(accountRefreshProvider)();
      // An open Subscription History re-reads its two ledgers on the same beat,
      // so the pending card becomes Approved (or Rejected) with the plan.
      ref.invalidate(myPaymentSubmissionsProvider);
      ref.invalidate(mySubscriptionCancellationsProvider);
      final premium = await ref.read(premiumAccessProvider.future);
      if (!_wasPremium && premium) {
        // The approval landed: the cache now says premium, so watching is done.
        _finish();
      } else if (_ticksLeft <= 0) {
        _finish();
      }
    } on Object {
      // A refresh that cannot run leaves the cache untouched; the next tick, a
      // resume or the next launch tries again.
    } finally {
      _working = false;
    }
  }

  void _finish() {
    _timer?.cancel();
    _timer = null;
    if (mounted) ref.read(paymentApprovalWatchProvider.notifier).stop();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(paymentApprovalWatchProvider, (previous, next) {
      if (next > 0) {
        _start();
      } else {
        _timer?.cancel();
        _timer = null;
      }
    });
    return widget.child;
  }
}
