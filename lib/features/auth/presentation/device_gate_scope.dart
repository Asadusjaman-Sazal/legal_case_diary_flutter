/// The device gate: what the app does when this device does not hold a slot.
///
/// Two states, both decided by the server (`register_device`):
///
/// * **The plan is full** — nothing was evicted, because every other device was
///   used in the last seven days. A pop-over names them and signs one out on
///   request. Signing one out revokes it, then **re-checks this device's own
///   slot**; it enters only when the server confirms a slot is free.
/// * **This device was revoked** — another device took the slot, or the lawyer
///   removed it. `signed_out` (the third-device window) discards and wipes at
///   once; the other reasons keep the older save-then-erase path until the
///   discard-everywhere change lands.
///
/// A **fresh login** waits for the server's answer and fails closed if it cannot
/// be read; a cold start with an existing session may use its local copy while
/// offline, which is the accepted “next online” rule.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/device_providers.dart';
import '../../../core/providers/notification_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/date_utils.dart';
import '../data/device_registration.dart';
import '../data/logout_flow.dart';
import 'auth_viewmodel.dart';

/// Replaces the app with the gate's screen while this device holds no slot.
class DeviceGateScope extends ConsumerStatefulWidget {
  /// Creates the scope around [child].
  const DeviceGateScope({required this.router, required this.child, super.key});

  /// Router used to reach the Login screen once the session has ended.
  final GoRouter router;

  /// The app below the gate.
  final Widget child;

  @override
  ConsumerState<DeviceGateScope> createState() => _DeviceGateScopeState();
}

class _DeviceGateScopeState extends ConsumerState<DeviceGateScope> {
  /// The revocation work runs once per screen.
  bool _started = false;
  bool _saving = false;
  bool _erased = false;

  /// The signed-out discard failed and may be retried.
  bool _discardFailed = false;

  /// The device whose row is currently being signed out, if any.
  String? _signingOutId;

  /// Set once the eviction notice has been shown.
  String? _announcedEviction;

  /// The last answer the server gave. A later `null` (a refresh in flight) is
  /// read against it: from the full-plan/revoked screens this is a check, while
  /// from the active app it is a background read.
  DeviceGateStatus? _lastStatus;

  /// The plan-limit revocation being explained after its discard and sign-out.
  ///
  /// Signing out turns the gate's provider `unmanaged`, but this screen must
  /// survive so its explanation can be read; Back to Login clears it.
  DeviceGateState? _stayedPlanState;

  /// Prevents more than one post-frame reset of the fresh-login flag.
  bool _freshClearScheduled = false;

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(deviceGateProvider);
    final state = gate.value;
    final fresh = ref.watch(freshDeviceCheckProvider);

    final stayed = _stayedPlanState;
    if (stayed != null) return _planLimitGate(context, stayed);

    // A rebuild in flight is not an answer yet: the fresh-login check must not
    // read the previous `unmanaged` value as permission to open the diary.
    if (state != null && !gate.isLoading) {
      _lastStatus = state.status;
      if (fresh) _clearFreshAfterFrame();
    }

    if (state == null || (fresh && gate.isLoading)) {
      // A fresh login must not open the cached diary while the slot check is in
      // flight. A cold start with an existing session keeps the offline rule.
      if (_blocksWithoutAnswer(fresh)) {
        return _checkGate(context, failed: gate.hasError);
      }
      return widget.child;
    }

    switch (state.status) {
      case DeviceGateStatus.limitReached:
        return _limitGate(context, state);

      case DeviceGateStatus.revoked:
        if (state.revokedReason == 'replaced') {
          if (!_started) {
            _started = true;
            unawaited(Future<void>.microtask(_endReplacedSession));
          }
          return _replacedGate(context);
        }
        // The two plan-limit reasons keep the screen after the discard so the
        // lawyer can read what happened and leave through Back to Login.
        final planLimit =
            state.revokedReason == 'cap' || state.revokedReason == 'lapse';
        if (!_started) {
          _started = true;
          unawaited(
            Future<void>.microtask(() => _discardAndSignOut(stay: planLimit)),
          );
        }
        if (planLimit) {
          // Kept for the rebuild that follows the sign-out, when the provider
          // itself turns `unmanaged`.
          _stayedPlanState = state;
          return _planLimitGate(context, state);
        }
        return _RevokedScreen(
          state: state,
          saving: _saving,
          failed: _discardFailed,
          onRetry: _discardAndSignOut,
        );

      case DeviceGateStatus.unregistered:
      case DeviceGateStatus.unknown:
        return _checkGate(context, failed: true);

      case DeviceGateStatus.sessionInUse:
        if (!_started) {
          _started = true;
          unawaited(Future<void>.microtask(_discardAndSignOut));
        }
        return _RevokedScreen(
          title: AppLocalizations.of(context).devices_sessionInUseTitle,
          state: state,
          saving: _saving,
          failed: _discardFailed,
          onRetry: _discardAndSignOut,
        );

      case DeviceGateStatus.active:
        // A new session on this screen: the next revocation must do its work
        // again, and a fresh eviction notice must be allowed to appear.
        if (_started || _erased || _discardFailed) _resetRevocationState();
        final evicted = state.evictedLabel;
        if (evicted != null && evicted != _announcedEviction) {
          _announcedEviction = evicted;
          final l = AppLocalizations.of(context);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l.devices_evicted(evicted))));
          });
        }
        return widget.child;

      case DeviceGateStatus.unmanaged:
        if (_started || _erased || _discardFailed) _resetRevocationState();
        return widget.child;
    }
  }

  /// Clears the one-revocation flags so a later sign-in is gated from scratch.
  void _resetRevocationState() {
    _started = false;
    _saving = false;
    _erased = false;
    _discardFailed = false;
    _announcedEviction = null;
  }

  bool _blocksWithoutAnswer(bool fresh) =>
      fresh ||
      _lastStatus == DeviceGateStatus.limitReached ||
      _lastStatus == DeviceGateStatus.revoked ||
      _lastStatus == DeviceGateStatus.unregistered ||
      _lastStatus == DeviceGateStatus.unknown;

  void _clearFreshAfterFrame() {
    if (_freshClearScheduled) return;
    _freshClearScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _freshClearScheduled = false;
      if (!mounted) return;
      ref.read(freshDeviceCheckProvider.notifier).clear();
    });
  }

  // ---------------------------------------------------------------------------
  // The full-plan window
  // ---------------------------------------------------------------------------

  Widget _limitGate(BuildContext context, DeviceGateState state) {
    final l = AppLocalizations.of(context);
    final busy = _signingOutId != null;
    return _popOver(
      context,
      title: l.devices_planFullTitle,
      lightHeader: true,
      children: [
        Text(
          l.devices_planFullBody(_digits(context, state.cap)),
          style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
        ),
        const SizedBox(height: AppSpacing.md),
        // Deliberately its own block: the label, then the warning beneath it.
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.devices_planFullWarningLabel,
              style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              l.devices_planFullWarning,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final device in state.devices) ...[
          _deviceRow(
            device: device,
            busy: busy,
            signingOut: _signingOutId == device.id,
            onSignOut: () => _signOutDevice(device.id),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          style: _tallerTextButton,
          onPressed: busy ? null : _retry,
          child: Text(l.devices_tryAgain),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          style: _tallerTextButton,
          onPressed: busy ? null : _signOutThisDevice,
          child: Text(l.devices_signOutThisDevice),
        ),
      ],
    );
  }

  /// One device on the full-plan window.
  Widget _deviceRow({
    required RegisteredDevice device,
    required bool busy,
    required bool signingOut,
    required VoidCallback onSignOut,
  }) {
    final l = AppLocalizations.of(context);
    final seen = device.lastSeenAt;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius * 2),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.label,
                  style: AppTypography.labelLg.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (seen != null)
                  Text(
                    l.devices_lastUsed(
                      MaterialLocalizations.of(context).formatShortDate(seen),
                    ),
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton(
            key: ValueKey<String>('device-sign-out-${device.id}'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
              disabledBackgroundColor: AppColors.surfaceContainer,
              disabledForegroundColor: AppColors.onSurfaceVariant,
              minimumSize: const Size(112, 48),
              textStyle: const TextStyle(fontSize: 16),
            ),
            onPressed: busy ? null : onSignOut,
            child: signingOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onError,
                    ),
                  )
                : Text(l.devices_signOut),
          ),
        ],
      ),
    );
  }

  /// Signs out one of the other devices, then re-checks this device's slot.
  Future<void> _signOutDevice(String deviceId) async {
    if (_signingOutId != null) return;
    setState(() => _signingOutId = deviceId);
    var signedOut = false;
    try {
      signedOut = await ref.read(deviceGateProvider.notifier).signOut(deviceId);
    } on Object {
      signedOut = false;
    }
    if (!mounted) return;
    setState(() => _signingOutId = null);
    if (!signedOut) {
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.devices_signOutFailed)));
    }
  }

  /// Re-asks the server without claiming anything new.
  void _retry() {
    unawaited(ref.read(deviceGateProvider.notifier).refresh(claim: true));
  }

  // ---------------------------------------------------------------------------
  // Checking / failure window
  // ---------------------------------------------------------------------------

  Widget _checkGate(BuildContext context, {required bool failed}) {
    final l = AppLocalizations.of(context);
    return _popOver(
      context,
      title: failed ? l.devices_checkFailedTitle : l.devices_checkingTitle,
      children: [
        Text(
          failed ? l.devices_checkFailedBody : l.devices_checkingBody,
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        if (!failed) ...[
          const SizedBox(height: AppSpacing.xl),
          const Center(child: CircularProgressIndicator()),
        ] else ...[
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: _retry, child: Text(l.devices_tryAgain)),
          TextButton(
            onPressed: _signOutThisDevice,
            child: Text(l.devices_signOutThisDevice),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Same-install re-login: end the old sign-in, keep the data
  // ---------------------------------------------------------------------------

  Widget _replacedGate(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _popOver(
      context,
      title: l.devices_replacedTitle,
      children: [
        Text(
          l.devices_replacedBody,
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Text(
            l.devices_signingOut,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // The plan's device limit: the slots were full, so this device was signed out
  // ---------------------------------------------------------------------------

  Widget _planLimitGate(BuildContext context, DeviceGateState state) {
    final l = AppLocalizations.of(context);
    // Two concurrent devices exists only on Pro; every other tier allows one,
    // so a cap of two can state the plan by name and the rest stay generic.
    final lead = state.cap == 2
        ? l.devices_limitRevokedLeadPro
        : l.devices_limitRevokedLead;
    final bodyStyle = AppTypography.bodyMd.copyWith(
      color: AppColors.onSurfaceVariant,
    );
    return _RevokedScreen(
      title: l.devices_planFullTitle,
      state: state,
      saving: _saving,
      failed: _discardFailed,
      onRetry: () => _discardAndSignOut(stay: true),
      onBackToLogin: _erased
          ? () {
              widget.router.go(AppRoutes.login);
              setState(() {
                _stayedPlanState = null;
                _resetRevocationState();
              });
            }
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              style: bodyStyle,
              children: [
                TextSpan(text: '$lead '),
                TextSpan(
                  text: l.devices_limitRevokedLimit(state.cap),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: l.devices_limitRevokedTally(state.cap)),
              ],
            ),
            textAlign: TextAlign.justify,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l.devices_limitRevokedDiscarded,
            textAlign: TextAlign.justify,
            style: bodyStyle.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l.devices_limitRevokedRelogin,
            textAlign: TextAlign.justify,
            style: bodyStyle,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Work
  // ---------------------------------------------------------------------------

  /// Ends the old sign-in without touching the local database.
  ///
  /// `replaced` means the same install signed in again; the local data belongs
  /// to the new session and must survive.
  Future<void> _endReplacedSession() async {
    try {
      await ref.read(authViewModelProvider.notifier).signOut();
    } on Object {
      // Even a failed SDK sign-out must not trap this screen.
    }
    if (!mounted) return;
    widget.router.go(AppRoutes.login);
  }

  /// Discards the queue and local database, cancels alarms, then signs out.
  ///
  /// There is deliberately no push here: every non-`replaced` revocation means
  /// the work is lost, which the window warned about before the button was
  /// pressed. `stay` keeps the plan-limit screen visible after the discard so
  /// its explanation can be read; that screen carries Back to Login.
  Future<void> _discardAndSignOut({bool stay = false}) async {
    if (_saving || _erased) return;
    setState(() {
      _saving = true;
      _discardFailed = false;
    });
    try {
      try {
        await ref.read(notificationSchedulerProvider).cancelAll();
      } on Object {
        // A scheduler that cannot cancel must not block the wipe.
      }
      try {
        await ref.read(deviceGateProvider.notifier).acknowledgeWipe();
      } on Object {
        // Offline acknowledgement is best-effort; the wipe still proceeds.
      }
      await (await ref.read(logoutFlowProvider.future)).wipeAndComplete();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _erased = true;
      });
      if (!stay) widget.router.go(AppRoutes.login);
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _discardFailed = true;
      });
    }
  }

  /// The explicit escape: sign out of this device without using a slot.
  ///
  /// The local queue is discarded because this device cannot push without one;
  /// the window's Sign Out This Device is the lawyer's deliberate choice.
  Future<void> _signOutThisDevice() async {
    try {
      await (await ref.read(logoutFlowProvider.future)).wipeAndComplete();
    } on Object {
      return;
    }
    if (!mounted) return;
    widget.router.go(AppRoutes.login);
  }

  // ---------------------------------------------------------------------------
  // The window shape
  // ---------------------------------------------------------------------------

  /// The two secondary actions under the device list, a touch taller than the
  /// default text button.
  static final ButtonStyle _tallerTextButton = TextButton.styleFrom(
    minimumSize: const Size(0, 48),
  );

  Widget _popOver(
    BuildContext context, {
    required String title,
    required List<Widget> children,
    bool lightHeader = false,
  }) {
    final content = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 420,
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 60,
            width: double.infinity,
            color: lightHeader
                ? AppColors.surfaceContainerLowest
                : AppColors.secondary,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleLg.copyWith(
                color: lightHeader ? AppColors.onSurface : AppColors.onPrimary,
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );

    return PopScope(
      canPop: false,
      child: Scaffold(
        // The plan-full window is a white page; the other gate windows keep the
        // dimmed overlay that marks them as interruptions.
        backgroundColor: lightHeader
            ? AppColors.surfaceContainerLowest
            : Colors.black54,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              // The white page needs no card behind it, so the old shadowed
              // panel is kept only for the windows that sit over the app.
              child: lightHeader
                  ? content
                  : Material(
                      color: AppColors.surfaceContainerLowest,
                      elevation: 8,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.cardRadius * 2,
                        ),
                      ),
                      child: content,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  String _digits(BuildContext context, int value) => AppDateUtils.formatDigits(
    value,
    Localizations.localeOf(context).toLanguageTag(),
    grouping: false,
  );
}

/// The revoked screen for every reason except a same-install re-login.
///
/// The device is discarding its local copy, not saving it; the screen says so
/// and offers a retry when the wipe cannot run.
class _RevokedScreen extends StatelessWidget {
  final String? title;
  final DeviceGateState state;
  final bool saving;
  final bool failed;
  final Future<void> Function() onRetry;

  /// A richer body than the reason's default sentence, when the screen needs one.
  final Widget? body;

  /// The way out once the discard has completed; null while it is running or
  /// after it fails, because leaving with the local copy still on the device is
  /// exactly what this screen exists to prevent.
  final VoidCallback? onBackToLogin;

  const _RevokedScreen({
    this.title,
    required this.state,
    required this.saving,
    required this.failed,
    required this.onRetry,
    this.body,
    this.onBackToLogin,
  });

  String _body(AppLocalizations l) => switch (state.revokedReason) {
    'user' => l.devices_revokedRemovedBody,
    'signed_out' => l.devices_signedOutBody,
    'session_in_use' => l.devices_sessionInUseBody,
    'capacity' => l.devices_capacityRevokedBody,
    'removed' => l.devices_removedRevokedBody,
    _ => l.devices_revokedBody('${state.cap}'),
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          // The plan-limit copy is long enough to overflow a short phone, so
          // the column centres when it fits and scrolls when it does not.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.phonelink_erase_outlined,
                        size: 48,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        title ?? l.devices_revokedTitle,
                        textAlign: TextAlign.center,
                        style: AppTypography.titleLg,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child:
                            body ??
                            Text(
                              _body(l),
                              textAlign: TextAlign.center,
                              style: AppTypography.bodyMd.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (saving)
                        Column(
                          children: [
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              l.devices_signingOut,
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        )
                      else if (failed) ...[
                        Text(
                          l.devices_signedOutFailed,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        FilledButton(
                          onPressed: onRetry,
                          child: Text(l.devices_tryAgain),
                        ),
                      ],
                      if (onBackToLogin != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Center(
                          child: FilledButton(
                            onPressed: onBackToLogin,
                            child: Text(l.devices_backToLogin),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
