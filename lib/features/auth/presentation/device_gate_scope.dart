/// The device gate: what the app does when this device does not hold a slot.
///
/// Two states, both decided by the server (`register_device`):
///
/// * **The plan is full** — nothing was evicted, because every other device was
///   used in the last seven days. The screen names them, frees one on request,
///   and offers to try again. The lawyer's own work is untouched: this device
///   simply may not sync until it holds a slot.
/// * **This device was revoked** — another device took the slot, or the lawyer
///   removed it. The device **hands over its unsent work first**, records that
///   it did, and only then erases itself and signs out (user ruling, 2026-10-21).
///   If it cannot reach the account, it says so and erases nothing: a limit must
///   never destroy a note that was not yet saved. The escape hatch is an
///   explicit *Sign out and discard*, because a device that can never connect
///   must still be usable by the next person.
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
import '../../../core/router/app_router.dart';
import '../../../sync/sync_service.dart';
import '../data/device_registration.dart';
import '../data/logout_flow.dart';

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
  bool _saveFailed = false;
  bool _erased = false;

  /// Set once the eviction notice has been shown.
  String? _announcedEviction;

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(deviceGateProvider);
    final state = gate.value;

    // Loading or a failed read is not a reason to lock the diary: the sync gate
    // already refuses to push without a confirmed slot, which is the part that
    // protects the plan. Only a confirmed answer blocks the screen.
    if (state == null) return widget.child;

    if (state.status == DeviceGateStatus.limitReached) {
      return _PlanFullScreen(
        state: state,
        onRemove: (id) => ref.read(deviceGateProvider.notifier).remove(id),
        onRetry: () =>
            ref.read(deviceGateProvider.notifier).refresh(claim: true),
        onSignOut: _signOut,
      );
    }

    if (state.status == DeviceGateStatus.revoked) {
      if (!_started) {
        _started = true;
        unawaited(Future<void>.microtask(_saveThenErase));
      }
      return _RevokedScreen(
        state: state,
        saving: _saving,
        failed: _saveFailed,
        erased: _erased,
        onRetry: _saveThenErase,
        onDiscard: _discardAndSignOut,
      );
    }

    // Active again: say so when this registration evicted another device, so the
    // lawyer knows why their spare stopped working.
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
  }

  /// Saves the queued work, records the flush, then wipes and signs out.
  ///
  /// The order is the whole point: nothing is erased until the account has the
  /// work. A push that cannot reach the server leaves the device intact.
  Future<void> _saveThenErase() async {
    if (_saving || _erased) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    var saved = false;
    try {
      saved = await ref.read(syncServiceProvider).pushBeforeErase();
    } on Object {
      saved = false;
    }
    if (!mounted) return;

    if (!saved) {
      setState(() {
        _saving = false;
        _saveFailed = true;
      });
      return;
    }

    try {
      await ref.read(deviceGateProvider.notifier).acknowledgeWipe();
      await (await ref.read(logoutFlowProvider.future)).wipeAndComplete();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _erased = true;
      });
      widget.router.go(AppRoutes.login);
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveFailed = true;
      });
    }
  }

  /// The explicit escape: sign out without erasing, discarding the queue.
  Future<void> _discardAndSignOut() async {
    try {
      await (await ref.read(logoutFlowProvider.future)).wipeAndComplete();
    } on Object {
      // A wipe that fails leaves the device as it was; the screen stays up and
      // the action can be tried again.
      return;
    }
    if (!mounted) return;
    setState(() => _erased = true);
    widget.router.go(AppRoutes.login);
  }

  /// Ends the session from the plan-full screen, keeping local data.
  Future<void> _signOut() async {
    try {
      await (await ref.read(logoutFlowProvider.future)).syncThenComplete();
    } on Object {
      return;
    }
    if (!mounted) return;
    widget.router.go(AppRoutes.login);
  }
}

/// The plan-full screen: what holds the slots, and how to free one.
class _PlanFullScreen extends StatelessWidget {
  const _PlanFullScreen({
    required this.state,
    required this.onRemove,
    required this.onRetry,
    required this.onSignOut,
  });

  final DeviceGateState state;
  final Future<bool> Function(String id) onRemove;
  final VoidCallback onRetry;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const SizedBox(height: AppSpacing.xl),
              const Icon(
                Icons.devices_other_outlined,
                size: 48,
                color: AppColors.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l.devices_planFullTitle,
                textAlign: TextAlign.center,
                style: AppTypography.titleLg,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l.devices_planFullBody('${state.cap}'),
                textAlign: TextAlign.center,
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final device in state.devices) ...[
                _DeviceLine(
                  device: device,
                  onRemove: device.isCurrent ? null : () => onRemove(device.id),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.md),
              FilledButton(onPressed: onRetry, child: Text(l.devices_tryAgain)),
              TextButton(onPressed: onSignOut, child: Text(l.devices_signOut)),
            ],
          ),
        ),
      ),
    );
  }
}

/// One device on the plan-full screen.
class _DeviceLine extends StatelessWidget {
  const _DeviceLine({required this.device, required this.onRemove});

  final RegisteredDevice device;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              device.label,
              style: AppTypography.labelLg.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onRemove != null)
            TextButton(onPressed: onRemove, child: Text(l.devices_remove)),
        ],
      ),
    );
  }
}

/// The revoked screen: saving, then erased.
class _RevokedScreen extends StatelessWidget {
  const _RevokedScreen({
    required this.state,
    required this.saving,
    required this.failed,
    required this.erased,
    required this.onRetry,
    required this.onDiscard,
  });

  final DeviceGateState state;
  final bool saving;
  final bool failed;
  final bool erased;
  final Future<void> Function() onRetry;
  final Future<void> Function() onDiscard;

  /// Why this device lost its slot, in the lawyer's words.
  ///
  /// The reason comes from the server, which also wrote it into the row: a
  /// fallen ceiling reads as a plan change, a removal as the lawyer's own
  /// action, a second sign-in as that sign-in ending. Everything else — a new
  /// device taking the slot — keeps the shared sentence.
  String _body(AppLocalizations l) => switch (state.revokedReason) {
    'lapse' => l.devices_revokedLapseBody('${state.cap}'),
    'user' => l.devices_revokedRemovedBody,
    'replaced' => l.devices_revokedReplacedBody,
    _ => l.devices_revokedBody('${state.cap}'),
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
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
                    l.devices_revokedTitle,
                    textAlign: TextAlign.center,
                    style: AppTypography.titleLg,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Why it happened, kept on screen while the save runs: the
                  // reason and the save's outcome are two different facts, and
                  // replacing one with the other lost the explanation.
                  Text(
                    _body(l),
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
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
                          l.devices_revokedSaving,
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    )
                  else if (failed) ...[
                    Text(
                      l.devices_revokedSaveFailed,
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
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: onDiscard,
                      child: Text(l.devices_discard),
                    ),
                  ] else if (erased)
                    Text(
                      l.devices_revokedSaved,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
