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
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/utils/date_utils.dart';
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
  /// Whether the timing section is open; it starts collapsed, so the screen
  /// opens as a plain column of buttons.
  bool _timingExpanded = false;

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
        // Turn Off first: the way back to an unlocked app, above the actions
        // that configure one.
        SettingsSubMenuRow(
          key: const ValueKey('app-lock-turn-off'),
          icon: Icons.lock_open_outlined,
          title: l.settingsAppLock_turnOff,
          onTap: _confirmTurnOff,
        ),
        const SizedBox(height: AppSpacing.sm),
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
        const SizedBox(height: AppSpacing.sm),
        // The timing control: a button like the two above, closed by default,
        // opening onto its two choices as two more buttons of the same design.
        _TimingHeader(
          key: const ValueKey('app-lock-timing'),
          expanded: _timingExpanded,
          onTap: () => setState(() => _timingExpanded = !_timingExpanded),
        ),
        if (_timingExpanded) ...[
          const SizedBox(height: AppSpacing.sm),
          _TimingOption(
            key: const ValueKey('app-lock-timing-app-starts'),
            label: l.settingsAppLock_whenAppStarts,
            selected: state.timing == AppLockTiming.appOpen,
            onTap: () => _chooseTiming(AppLockTiming.appOpen),
          ),
          const SizedBox(height: AppSpacing.sm),
          _TimingOption(
            key: const ValueKey('app-lock-timing-every-open'),
            label: l.settingsAppLock_whenAppOpensAndReturns,
            selected: state.timing == AppLockTiming.appOpenAndReturn,
            onTap: () => _chooseTiming(AppLockTiming.appOpenAndReturn),
          ),
        ],
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
  // Turn off
  // -------------------------------------------------------------------------

  /// Confirms, then turns App Lock off and returns the screen to Setup.
  ///
  /// The confirmation copies the app's own destructive-warning shape: Cancel
  /// and the acting button, centred, with the action named for what it does
  /// rather than a bare "OK". No PIN is asked for here — the request did not
  /// ask for one, and this is the action a user takes while already inside the
  /// unlocked app.
  Future<void> _confirmTurnOff() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.settingsAppLock_turnOffTitle),
        content: Text(l.settingsAppLock_turnOffBody),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(112, 48),
              textStyle: const TextStyle(fontSize: 16),
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.sharedActions_cancel),
          ),
          TextButton(
            key: const ValueKey('app-lock-turn-off-confirm'),
            style: TextButton.styleFrom(
              minimumSize: const Size(112, 48),
              textStyle: const TextStyle(
                fontSize: 16,
                color: AppColors.error,
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.settingsAppLock_turnOffConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(appLockStateProvider.notifier).turnOff();
    if (!mounted) return;
    // Collapse the timing section with it: the next setup should open on the
    // same plain column of buttons this screen shipped with.
    setState(() => _timingExpanded = false);
    _snack(l.settingsAppLock_turnedOff);
  }

  // -------------------------------------------------------------------------
  // Timing
  // -------------------------------------------------------------------------

  /// Writes the chosen timing and closes the section again.
  ///
  /// Collapsing on choose is the point of a section that opens from a button:
  /// the choice is made and the screen returns to its resting shape.
  Future<void> _chooseTiming(AppLockTiming timing) async {
    await ref.read(appLockStateProvider.notifier).setTiming(timing);
    if (!mounted) return;
    setState(() => _timingExpanded = false);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text)));
  }
}

/// The timing section's header: a row like the buttons above it, with a chevron
/// that turns as the section opens and closes.
class _TimingHeader extends StatelessWidget {
  const _TimingHeader({required this.expanded, required this.onTap, super.key});

  /// Whether the section below is open.
  final bool expanded;

  /// Opens or closes the section.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Material(
      color: AppColors.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.md),
        side: BorderSide(color: AppColors.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: settingsMenuCardRowHeight,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceContainer,
                  ),
                  child: const Center(
                    child: Icon(Icons.schedule, color: AppColors.primary),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    l.settingsAppLock_whenToAsk,
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
                // The same chevron, turned to point down when open.
                AnimatedRotation(
                  turns: expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    Icons.chevron_right,
                    color: AppColors.outlineVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the timing section's two choices: the same row design, ticked when it
/// is the active one.
class _TimingOption extends StatelessWidget {
  const _TimingOption({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  /// The choice's wording.
  final String label;

  /// Whether this is the timing in effect.
  final bool selected;

  /// Chooses this timing.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? AppColors.secondary.withValues(alpha: 0.08)
        : AppColors.surfaceContainerLowest,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.md),
      side: BorderSide(color: AppColors.outlineVariant),
    ),
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: settingsMenuCardRowHeight,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.titleMd.copyWith(
                    color: selected ? AppColors.secondary : AppColors.onSurface,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: AppColors.secondary),
            ],
          ),
        ),
      ),
    ),
  );
}
