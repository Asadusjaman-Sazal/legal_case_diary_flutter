/// App Lock screen: the one place the PIN is set, changed, and paired with a
/// fingerprint — a Settings sub-page behind Manage Account.
///
/// Its rows follow the state exactly, as the request defines them:
/// **Setup App Lock** is offered only while no PIN exists and vanishes the
/// moment one is stored; **Change App Lock Pin**, the **Fingerprint** row and
/// the **When To Ask For The Pin** picker appear only afterwards. Nothing here
/// enforces the lock — that is `AppLockScope` at the app root; this screen
/// only writes the PIN and the two preferences it obeys.
///
/// There is no mockup for this screen (rule 9: the shipped body is the
/// source), so it wears the shared Settings sub-page chrome and the same
/// sub-menu rows and picker controls as its neighbours.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/utils/date_utils.dart';
import '../../settings/presentation/settings_controls.dart';
import '../../settings/presentation/settings_menu_card.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';
import '../data/app_lock_store.dart';
import '../data/biometrics.dart';
import 'pin_pad.dart';

/// The App Lock sub-page.
class AppLockScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(appLockStateProvider);

    return SettingsSubPageModal(
      title: l.settingsAppLock_title,
      // Loading *and* error show a spinner rather than a fallback: offering
      // Setup over a PIN that exists would overwrite it without asking for the
      // old one, so an unreadable store shows nothing to tap rather than
      // something unsafe.
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: CircularProgressIndicator()),
        data: (value) => _body(l, value),
      ),
    );
  }

  Widget _body(AppLocalizations l, AppLockState state) => ListView(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.edgeMargin,
      AppSpacing.md,
      AppSpacing.edgeMargin,
      AppSpacing.xl,
    ),
    children: [
      if (!state.isSetup) ...[
        // The only row while the app is unlocked for the first time.
        SettingsSubMenuRow(
          key: const ValueKey('app-lock-setup'),
          icon: Icons.key_outlined,
          title: l.settingsAppLock_setup,
          onTap: _setup,
        ),
      ] else ...[
        SettingsSubMenuRow(
          key: const ValueKey('app-lock-change'),
          icon: Icons.password,
          title: l.settingsAppLock_changePin,
          onTap: _changePin,
        ),
        const SizedBox(height: AppSpacing.sm),
        SettingsSubMenuRow(
          key: const ValueKey('app-lock-fingerprint'),
          icon: Icons.fingerprint,
          title: state.fingerprintEnabled
              ? l.settingsAppLock_disableFingerprint
              : l.settingsAppLock_enableFingerprint,
          onTap: () => _toggleFingerprint(l, state.fingerprintEnabled),
        ),
        const SizedBox(height: AppSpacing.lg),
        SettingsSectionLabel(l.settingsAppLock_whenToAsk),
        const SizedBox(height: AppSpacing.sm),
        SettingsPickerRow(
          key: const ValueKey('app-lock-timing'),
          text: state.timing == AppLockTiming.appOpenAndReturn
              ? l.settingsAppLock_whenAppOpensAndReturns
              : l.settingsAppLock_whenAppOpens,
          icon: Icons.expand_more,
          onTap: () => _pickTiming(l, state.timing),
        ),
      ],
    ],
  );

  // -------------------------------------------------------------------------
  // Setup
  // -------------------------------------------------------------------------

  /// First-run flow: choose a pin, then confirm it.
  Future<void> _setup() async {
    final l = AppLocalizations.of(context);
    final length = AppDateUtils.formatDigits(
      appLockPinLength,
      l.localeName,
      grouping: false,
    );
    final captured = await showPinFlowDialog(
      context,
      stages: [
        PinPadStage(title: l.settingsAppLock_choosePin(length)),
        PinPadStage(
          title: l.settingsAppLock_confirmPin,
          // The first stage's capture is the pin being confirmed; anything
          // else restarts with the mismatch line rather than storing it.
          verify: (pin, prior) async => prior.isNotEmpty && pin == prior.first,
          error: l.settingsAppLock_pinMismatch,
          // A mismatch means neither entry may be trusted: start over at
          // choosing, which is what "Start Again." promises.
          restartAt: 0,
        ),
      ],
      cancelLabel: l.sharedActions_cancel,
    );
    if (captured == null || !mounted || captured.isEmpty) return;
    try {
      await ref.read(appLockStateProvider.notifier).setupPin(captured.first);
    } on Object {
      if (!mounted) return;
      _snack(l.settingsAppLock_setupFailed);
      return;
    }
    if (!mounted) return;
    _snack(l.settingsAppLock_setupDone);
  }

  // -------------------------------------------------------------------------
  // Change
  // -------------------------------------------------------------------------

  /// Prove the old pin (or the fingerprint), then choose and confirm a new one.
  Future<void> _changePin() async {
    final l = AppLocalizations.of(context);
    final notifier = ref.read(appLockStateProvider.notifier);
    // The glyph appears only when the fingerprint is switched on *and* this
    // device can actually answer it.
    final fingerprint = ref.read(biometricsProvider);
    final usable =
        ref.read(appLockStateProvider).value?.fingerprintEnabled == true &&
        await fingerprint.isUsable;
    if (!mounted) return;

    final captured = await showPinFlowDialog(
      context,
      stages: [
        PinPadStage(
          title: l.settingsAppLock_enterCurrentPin,
          verify: (pin, _) => notifier.verifyPin(pin),
          error: l.settingsAppLock_currentPinWrong,
          biometrics: usable
              ? () => fingerprint.verify(l.settingsAppLock_verifyForFingerprint)
              : null,
        ),
        PinPadStage(title: l.settingsAppLock_newPin),
        PinPadStage(
          title: l.settingsAppLock_confirmPin,
          verify: (pin, prior) async => prior.isNotEmpty && pin == prior.first,
          error: l.settingsAppLock_pinMismatch,
          // Back to choosing the new pin, not back to proving the old one:
          // the typo is in what was just typed, not in the credential.
          restartAt: 1,
        ),
      ],
      cancelLabel: l.sharedActions_cancel,
    );
    if (captured == null || !mounted || captured.isEmpty) return;
    try {
      await notifier.changePin(captured.first);
    } on Object {
      if (!mounted) return;
      _snack(l.settingsAppLock_setupFailed);
      return;
    }
    if (!mounted) return;
    _snack(l.settingsAppLock_pinChanged);
  }

  // -------------------------------------------------------------------------
  // Fingerprint
  // -------------------------------------------------------------------------

  /// Enables or disables fingerprint unlock, each gated by a real fingerprint.
  ///
  /// Switching *on* has to prove a fingerprint exists on this device before it
  /// is ever offered at the lock screen; switching *off* demands the same
  /// proof, so the screen a stranger picked up cannot quietly switch it off.
  Future<void> _toggleFingerprint(
    AppLocalizations l,
    bool currentlyEnabled,
  ) async {
    final fingerprint = ref.read(biometricsProvider);
    if (!await fingerprint.isUsable) {
      if (!mounted) return;
      _snack(l.settingsAppLock_fingerprintUnavailable);
      return;
    }
    if (!mounted) return;
    final proven = await fingerprint.verify(l.settingsAppLock_verifyForFingerprint);
    if (!proven || !mounted) return;

    await ref
        .read(appLockStateProvider.notifier)
        .setFingerprintEnabled(!currentlyEnabled);
    if (!mounted) return;
    _snack(
      currentlyEnabled
          ? l.settingsAppLock_fingerprintDisabled
          : l.settingsAppLock_fingerprintEnabled,
    );
  }

  // -------------------------------------------------------------------------
  // Timing
  // -------------------------------------------------------------------------

  /// The two-choice picker for when the pin is asked, in the shared dialog.
  Future<void> _pickTiming(AppLocalizations l, AppLockTiming current) async {
    final chosen = await showDialog<AppLockTiming>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SettingsPickerDialogHeader(title: l.settingsAppLock_whenToAsk),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  SettingsOptionRow(
                    label: l.settingsAppLock_whenAppOpens,
                    selected: current == AppLockTiming.appOpen,
                    onTap: () =>
                        Navigator.of(context).pop(AppLockTiming.appOpen),
                  ),
                  const Divider(height: 1, color: AppColors.outlineVariant),
                  SettingsOptionRow(
                    label: l.settingsAppLock_whenAppOpensAndReturns,
                    selected: current == AppLockTiming.appOpenAndReturn,
                    onTap: () => Navigator.of(
                      context,
                    ).pop(AppLockTiming.appOpenAndReturn),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    await ref.read(appLockStateProvider.notifier).setTiming(chosen);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text)));
  }
}
