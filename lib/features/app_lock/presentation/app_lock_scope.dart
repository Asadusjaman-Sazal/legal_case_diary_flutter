/// The gate in front of the whole app: when the PIN has to be entered.
///
/// Sits at the root (`app.dart`, just inside [FontSizeScope]), so the lock
/// covers every route, dialog and gate below it — recovery screens included,
/// because a phone someone just picked up should learn nothing before the PIN
/// is given.
///
/// The rules it keeps, exactly as the user set them:
///
/// * the **first read decides**: if a PIN exists, this run starts locked; the
///   decision is taken once, so setting a PIN does not immediately lock the
///   screen it was set from;
/// * **On App Open** (the default) never re-asks on a resume, while
///   **…Or Returns From The Background** locks again every time the app comes
///   back to the foreground;
/// * five wrong PINs stop the keypad for 30 seconds — the fingerprint stays
///   usable throughout, because the lockout is against guessing, not against
///   the owner;
/// * while the stored state is still being read, an opaque placeholder covers
///   the app rather than showing it unlocked for a frame.
///
/// The app keeps running underneath while it is covered (sync, notifications,
/// queues), so an errand that starts before the phone is put down still
/// finishes.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/errors/error_log.dart';
import '../../../core/errors/error_log_provider.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/utils/date_utils.dart';
import '../data/app_lock_store.dart';
import '../data/biometrics.dart';
import 'pin_pad.dart';

/// Wrong pins refused in a row before the keypad rests.
const int _lockoutAttempts = 5;

/// How long the keypad rests after them.
const Duration _lockoutDuration = Duration(seconds: 30);

/// Wraps the app with the lock screen whenever the PIN is owed.
class AppLockScope extends ConsumerStatefulWidget {
  /// Creates the scope around the app's content.
  const AppLockScope({required this.child, super.key});

  /// Everything below the lock.
  final Widget child;

  @override
  ConsumerState<AppLockScope> createState() => _AppLockScopeState();
}

class _AppLockScopeState extends ConsumerState<AppLockScope>
    with WidgetsBindingObserver {
  /// Whether the first read has been turned into a lock decision yet.
  bool _decided = false;

  /// Whether the lock screen is showing.
  bool _locked = false;

  /// Wrong PINs in the current window.
  int _attempts = 0;

  /// Seconds left before the keypad may be used again; 0 means no refusal.
  ///
  /// A counted second rather than a wall-clock deadline: the countdown is the
  /// whole UI during a refusal, so it must tick with the frames the widget
  /// tests pump, not with real time the test cannot fast-forward.
  int _refusalLeft = 0;

  /// The countdown ticker, running only while refused.
  Timer? _ticker;

  /// Whether the fingerprint is both switched on and answerable right now.
  bool _fingerprintAvailable = false;

  /// Whether a verification is in flight, so a double-tap cannot race it.
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle != AppLifecycleState.resumed) return;
    if (!_decided || _locked) return;
    final state = ref.read(appLockStateProvider).value;
    if (state == null || !state.isSetup) return;
    // The default (On App Open) deliberately does not re-ask here; only the
    // background-return option does.
    if (state.timing == AppLockTiming.appOpenAndReturn) {
      _lock();
    }
  }

  /// Covers the app again and resets the attempt window.
  void _lock() {
    _ticker?.cancel();
    setState(() {
      _locked = true;
      _attempts = 0;
      _refusalLeft = 0;
      _checking = false;
    });
    _refreshFingerprint();
  }

  Future<void> _refreshFingerprint() async {
    final state = ref.read(appLockStateProvider).value;
    final available =
        state != null &&
        state.fingerprintEnabled &&
        await ref.read(biometricsProvider).isUsable;
    if (!mounted || !_locked) return;
    setState(() => _fingerprintAvailable = available);
  }

  Future<void> _onPin(String pin) async {
    if (_checking || _refusalActive) return;
    setState(() => _checking = true);
    final ok = await ref.read(appLockStateProvider.notifier).verifyPin(pin);
    if (!mounted) return;
    if (ok) {
      _unlock();
      return;
    }
    setState(() {
      _checking = false;
      _attempts++;
      if (_attempts >= _lockoutAttempts) {
        _attempts = 0;
        _refusalLeft = _lockoutDuration.inSeconds;
        _startTicker();
      }
    });
  }

  Future<void> _onBiometrics() async {
    if (_checking) return;
    setState(() => _checking = true);
    final l = AppLocalizations.of(context);
    final ok = await ref
        .read(biometricsProvider)
        .verify(l.settingsAppLock_verifyForFingerprint);
    if (!mounted) return;
    if (ok) {
      _unlock();
    } else {
      // The system prompt showed its own failure; the pad simply stands ready.
      setState(() => _checking = false);
    }
  }

  void _unlock() {
    _ticker?.cancel();
    setState(() {
      _locked = false;
      _attempts = 0;
      _refusalLeft = 0;
      _checking = false;
    });
  }

  bool get _refusalActive => _refusalLeft > 0;

  int get _refusalSeconds => _refusalLeft;

  void _startTicker() {
    _ticker?.cancel();
    // One rebuild a second for the countdown; stops itself when it reaches 0,
    // which is also the moment the keypad becomes usable again.
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_refusalLeft > 0) _refusalLeft--;
      });
      if (_refusalLeft <= 0) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appLockStateProvider);

    if (!_decided && !state.isLoading) {
      _decided = true;
      if (state.hasError) {
        // A store whose record cannot be read must not freeze the diary: an
        // unreadable PIN could mean anything — a broken Keystore, a plugin
        // that never answered — and locking the owner out with no way to ever
        // get in would be the worse failure. Record it and let the app
        // through; a device whose reads fail this way also cannot verify, so
        // a lock here could never be satisfied anyway.
        try {
          recordFailure(ref.read(errorLogProvider), 'appLock.read', state.error!);
        } on Object {
          // The log is injected by main.dart. A harness that pumps the app
          // without the override must not lose its whole tree over a failed
          // record — this line is diagnostics, the decision below is not.
        }
        _locked = false;
      } else {
        _locked = state.value!.isSetup;
        if (_locked) _refreshFingerprint();
      }
    }

    return Stack(
      children: [
        widget.child,
        if (!_decided || _locked)
          Positioned.fill(child: ColoredBox(color: AppColors.background)),
        if (_decided && _locked)
          Positioned.fill(child: _LockView(scope: this)),
      ],
    );
  }

  // The lock view reads through its enclosing scope, so it shares this state
  // rather than keeping a second copy of the attempts and refusal.
}

/// The full-screen lock: identity line, then the shared pin pad.
class _LockView extends StatelessWidget {
  const _LockView({required this.scope});

  final _AppLockScopeState scope;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final refused = scope._refusalActive;
    final message = refused
        ? l.settingsAppLock_tooManyAttempts(
            AppDateUtils.formatDigits(
              scope._refusalSeconds,
              l.localeName,
              grouping: false,
            ),
          )
        : scope._attempts > 0
        ? l.settingsAppLock_wrongPin
        : '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 44,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(l.settingsAppLock_title, style: AppTypography.titleLg),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l.settingsAppLock_unlockTitle,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                PinPad(
                  // Re-keyed per attempt: a fresh pad, a fresh shake.
                  key: ValueKey('lock-${scope._attempts}'),
                  message: message,
                  errorMessage: scope._attempts > 0 || refused,
                  // The digits rest during a refusal; the fingerprint never
                  // does — the lockout is against guessing, not the owner.
                  enabled: !refused && !scope._checking,
                  biometricsEnabled: !scope._checking,
                  showBiometrics: scope._fingerprintAvailable,
                  biometricsLabel: l.settingsAppLock_useFingerprint,
                  onCompleted: scope._onPin,
                  onBiometrics: scope._onBiometrics,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
