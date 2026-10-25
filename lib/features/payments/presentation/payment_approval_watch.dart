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
///
/// **It stops as soon as the subscription itself moves.** The governing expiry
/// (the profile's for an individual, the firm's for a chamber account) is
/// captured at the start and compared after every successful refresh. Every
/// approval changes it — a renewal extends it, an upgrade or a queued downgrade
/// writes the new period — so a payment applied to an account that was already
/// premium ends the watch as quickly as a free → premium one does. A refresh
/// that fails compares nothing, and the tick limit remains the backstop.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../shared/providers/database_provider.dart';
import '../../accounts_and_profile/data/account_mode.dart';
import '../../auth/presentation/auth_viewmodel.dart';
import '../../settings/data/premium_access.dart';

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

/// Reads the expiry that governs this account's entitlement from the cache.
///
/// The profile's expiry for an individual and the firm's for a chamber
/// account — the same value `resolveSubscriptionExpiry` gives the entitlement,
/// so a comparison cannot use a different date from the one the app acts on.
/// A function rather than a cached future: every beat needs the value the last
/// refresh just wrote, not what the provider first saw.
final paymentApprovalExpiryProvider = Provider<Future<int?> Function()>((ref) {
  return () async {
    final userId = ref.read(authIdentityProvider)?.userId;
    if (userId == null) return null;
    final db = await ref.read(databaseProvider.future);
    return resolveSubscriptionExpiry(db, userId);
  };
});

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

  /// The governing expiry when the watch started, and whether it could be read.
  ///
  /// A captured start is the primary stop signal; when the read fails, the
  /// free → premium check below is the fallback.
  int? _startExpiry;
  bool _startExpiryCaptured = false;

  /// Whether the account was already premium when the watch started, used only
  /// when the start expiry could not be read.
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
    _timer?.cancel();
    _timer = null;
    _ticksLeft = paymentApprovalWatchTicks;
    _wasPremium = ref.read(premiumAccessProvider).value == true;
    _startExpiry = null;
    _startExpiryCaptured = false;
    // Guard the asynchronous read against a newer start or a stop arriving
    // while it is in flight.
    unawaited(_captureStart(ref.read(paymentApprovalWatchProvider)));
  }

  Future<void> _captureStart(int epoch) async {
    int? expiry;
    var captured = false;
    try {
      expiry = await ref.read(paymentApprovalExpiryProvider)();
      captured = true;
    } on Object {
      // No cached expiry to compare against; the premium fallback still applies.
    }
    if (!mounted || ref.read(paymentApprovalWatchProvider) != epoch) return;
    _startExpiry = expiry;
    _startExpiryCaptured = captured;
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
      if (ref.read(authIdentityProvider) == null) {
        _finish();
        return;
      }
      final refreshed = await ref.read(accountRefreshProvider)();
      // An open Subscription History re-reads its two ledgers on the same beat,
      // so the pending card becomes Approved (or Rejected) with the plan.
      ref.invalidate(myPaymentSubmissionsProvider);
      ref.invalidate(mySubscriptionCancellationsProvider);
      if (!refreshed) {
        // Nothing was written, so there is nothing to compare this beat.
        if (_ticksLeft <= 0) _finish();
        return;
      }
      if (_startExpiryCaptured) {
        // Any approval moves the governing expiry: a renewal extends it, an
        // upgrade or a queued downgrade writes the new period. Equal means the
        // decision has not landed yet (or this beat's read failed).
        final expiry = await ref.read(paymentApprovalExpiryProvider)();
        if (expiry != _startExpiry) {
          _finish();
          return;
        }
      } else {
        // The start could not be read; a free → premium rise is the only
        // signal left, and it still ends the watch for the reported case.
        final premium = await ref.read(premiumAccessProvider.future);
        if (!_wasPremium && premium) {
          _finish();
          return;
        }
      }
      if (_ticksLeft <= 0) _finish();
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
