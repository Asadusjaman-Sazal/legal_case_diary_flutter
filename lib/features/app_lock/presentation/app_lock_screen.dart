/// App Lock screen: the one place the PIN is set, changed, and paired with a
/// fingerprint — a Settings sub-page behind Manage Account.
///
/// Its rows follow the state exactly, as the request defines them:
/// **Setup App Lock** is offered only while no PIN exists and vanishes the
/// moment one is stored; **Change App Lock PIN**, the **Fingerprint** row and
/// the **When to Ask for PIN** picker appear only afterwards. Nothing here
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
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_dialog_actions.dart';
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
        // The timing section, shaped like Backup & Restore's Encryption card:
        // **one** card holds the header and, when open, its two choices, so the
        // choices read as part of the section rather than as separate buttons.
        _TimingSection(
          expanded: _timingExpanded,
          timing: state.timing,
          onToggle: () => setState(() => _timingExpanded = !_timingExpanded),
          onChooseAppStart: () => _chooseTiming(AppLockTiming.appOpen),
          onChooseEveryOpen: () =>
              _chooseTiming(AppLockTiming.appOpenAndReturn),
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
    final proven = await fingerprint.verify(
      l.settingsAppLock_verifyForFingerprint,
    );
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

  /// Warns, then proves it is the owner, then turns App Lock off.
  ///
  /// Three steps, and each earns its place: the **warning** copies the app's
  /// own destructive shape (Cancel and the acting button, named for what it
  /// does); the **proof** is the current PIN or the fingerprint, the same pair
  /// the change-PIN flow accepts, so a phone someone else is holding cannot
  /// switch the lock off; and only then is anything cleared.
  Future<void> _confirmTurnOff() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showAppDialog<bool>(
      context,
      title: Text(l.settingsAppLock_turnOffTitle),
      content: Text(l.settingsAppLock_turnOffBody),
      actions: (dialogContext) => [
        AppDialogAction(
          label: l.sharedActions_cancel,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        AppDialogAction(
          key: const ValueKey('app-lock-turn-off-confirm'),
          label: l.settingsAppLock_turnOffConfirm,
          foreground: AppColors.error,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    if (!await _proveIdentity(l)) return;
    if (!mounted) return;

    await ref.read(appLockStateProvider.notifier).turnOff();
    if (!mounted) return;
    // Collapse the timing section with it: the next setup should open on the
    // same plain column of buttons this screen shipped with.
    setState(() => _timingExpanded = false);
    _snack(l.settingsAppLock_turnedOff);
  }

  /// Asks for the current PIN, or a fingerprint where one is enabled and the
  /// device can answer it; true only when the owner proved themselves.
  ///
  /// Runs *after* the warning and *before* anything is cleared, so a cancelled
  /// or failed proof leaves the lock exactly as it was.
  Future<bool> _proveIdentity(AppLocalizations l) async {
    final notifier = ref.read(appLockStateProvider.notifier);
    final fingerprint = ref.read(biometricsProvider);
    final usable =
        ref.read(appLockStateProvider).value?.fingerprintEnabled == true &&
        await fingerprint.isUsable;
    if (!mounted) return false;

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
      ],
      cancelLabel: l.sharedActions_cancel,
    );
    // One capture means the PIN stage passed; a fingerprint completion carries
    // no pin, so an empty non-null result is a proven fingerprint, not a
    // refusal. A null result is a cancel.
    return captured != null;
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

/// The timing section: one card holding the header and, when open, its two
/// choices — the shape Backup & Restore's Encryption section uses, so the
/// choices read as one control rather than two separate buttons.
class _TimingSection extends StatelessWidget {
  const _TimingSection({
    required this.expanded,
    required this.timing,
    required this.onToggle,
    required this.onChooseAppStart,
    required this.onChooseEveryOpen,
  });

  /// Whether the choices are showing.
  final bool expanded;

  /// The timing in effect, so the matching choice can be filled.
  final AppLockTiming timing;

  /// Opens or closes the section.
  final VoidCallback onToggle;

  /// Chooses "when the app starts".
  final VoidCallback onChooseAppStart;

  /// Chooses "every time the app opens".
  final VoidCallback onChooseEveryOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Material(
      // The section's own surface, one shade lighter than the rows above, so
      // the whole block reads as a single grouped card.
      color: AppColors.surfaceBright,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        side: BorderSide(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The header row, tappable to open and close.
          InkWell(
            key: const ValueKey('app-lock-timing'),
            onTap: onToggle,
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.settingsAppLock_whenToAsk,
                            style: AppTypography.titleMd.copyWith(
                              color: AppColors.onSurface,
                            ),
                          ),
                          SizedBox(height: AppSpacing.xs),
                          // The choice in effect, so the section reads its
                          // current value without being opened.
                          Text(
                            timing == AppLockTiming.appOpen
                                ? l.settingsAppLock_whenAppStarts
                                : l.settingsAppLock_whenAppOpensAndReturns,
                            key: const ValueKey('app-lock-timing-current'),
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
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
          if (expanded) ...[
            // A hairline separates the header from its choices, and a second
            // separates the two choices — the same divider language the
            // neighbouring Settings cards use.
            const Divider(height: 1, color: AppColors.outlineVariant),
            Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              // Full width, one per line: the two wordy choices need the whole
              // row to read, and stacked they sit under one another as a list
              // rather than competing side by side.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TimingChoice(
                    key: const ValueKey('app-lock-timing-app-starts'),
                    label: l.settingsAppLock_whenAppStarts,
                    selected: timing == AppLockTiming.appOpen,
                    onPressed: onChooseAppStart,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _TimingChoice(
                    key: const ValueKey('app-lock-timing-every-open'),
                    label: l.settingsAppLock_whenAppOpensAndReturns,
                    selected: timing == AppLockTiming.appOpenAndReturn,
                    onPressed: onChooseEveryOpen,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One of the timing section's two choices: filled in the app's primary style
/// when it is the active one, outlined otherwise — the same pair the Backup &
/// Restore Encryption section draws, at the shared primary-button height.
class _TimingChoice extends StatelessWidget {
  const _TimingChoice({
    required this.label,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  /// The choice's wording.
  final String label;

  /// Whether this timing is the one in effect.
  final bool selected;

  /// Chooses this timing.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
    );
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size.fromHeight(settingsPrimaryButtonHeight),
      ),
      shape: WidgetStatePropertyAll(shape),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),
      textStyle: const WidgetStatePropertyAll(AppTypography.bodyMd),
    );
    return selected
        ? FilledButton(
            onPressed: onPressed,
            style: style.copyWith(
              backgroundColor: const WidgetStatePropertyAll(AppColors.primary),
              foregroundColor: const WidgetStatePropertyAll(
                AppColors.onPrimary,
              ),
            ),
            child: Text(label, textAlign: TextAlign.center),
          )
        : OutlinedButton(
            onPressed: onPressed,
            // Spelled out because this app's theme paints OutlinedButton black:
            // here it is the secondary choice on the section's own surface.
            style: style.copyWith(
              backgroundColor: const WidgetStatePropertyAll(
                AppColors.surfaceContainerLowest,
              ),
              foregroundColor: const WidgetStatePropertyAll(AppColors.primary),
              side: const WidgetStatePropertyAll(
                BorderSide(color: AppColors.outlineVariant),
              ),
            ),
            child: Text(label, textAlign: TextAlign.center),
          );
  }
}
