/// Battery Optimization & Auto-Start setup guide (Task 13 Phase 3).
///
/// The plan's localized, step-by-step screen that keeps hearing alerts alive on
/// the aggressive OEM firmware dominating the target market: allow auto-start,
/// take the app off battery optimization, and (Android 12+) allow exact alarms.
/// Each step has a "Take Me There" button that jumps to the phone's own settings
/// page, with the app's details page as the fallback when the OEM page is gone.
///
/// **No mockup exists for this screen**, so it is built from the Settings
/// chrome and the shared controls the Notifications mockup already established
/// (`SettingsSubPageModal` + `settings_controls.dart`), as approved with the
/// user. Finishing or skipping the guide records the choice in the per-user
/// `user_preferences` row, which is what hides the reminder banner.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/notifications/oem_setup_guide.dart';
import '../../../../core/providers/notification_providers.dart';
import '../settings_controls.dart';
import '../settings_menu_card.dart';
import '../settings_sub_page_modal.dart';
import '../settings_viewmodel.dart';

/// The guide screen.
class BatterySetupGuideScreen extends ConsumerStatefulWidget {
  /// Creates the guide screen.
  const BatterySetupGuideScreen({super.key});

  @override
  ConsumerState<BatterySetupGuideScreen> createState() =>
      _BatterySetupGuideScreenState();
}

class _BatterySetupGuideScreenState
    extends ConsumerState<BatterySetupGuideScreen> {
  /// Steps for this device; null until the manufacturer has been read.
  OemGuidePlan? _plan;

  /// Whether exact alarms are already permitted, so the step can say so.
  bool _exactAlarmsAllowed = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceSetup();
  }

  Future<void> _loadDeviceSetup() async {
    final scheduler = ref.read(notificationSchedulerProvider);
    final identity = await scheduler.deviceIdentity();
    final exactAllowed = await scheduler.canScheduleExactAlarms();
    if (!mounted) return;
    setState(() {
      _plan = oemGuidePlanFor(identity);
      _exactAlarmsAllowed = exactAllowed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final plan = _plan;

    return SettingsSubPageModal(
      title: l.settingsNotifications_setupGuide,
      subtitle: l.settingsNotifications_setupGuideSubtitle,
      child: plan == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.edgeMargin,
                AppSpacing.md,
                AppSpacing.edgeMargin,
                AppSpacing.xl,
              ),
              children: [
                Container(
                  decoration: settingsCardDecoration(),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    l.settingsBatteryGuide_intro,
                    style: AppTypography.bodyMd,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final (index, step) in plan.steps.indexed) ...[
                  if (index > 0) const SizedBox(height: AppSpacing.md),
                  _GuideStepCard(
                    number: index + 1,
                    step: step,
                    showAllowedState:
                        step == OemGuideStepId.exactAlarms &&
                        _exactAlarmsAllowed,
                    onTakeMeThere: () => _takeMeThere(step),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  height: settingsPrimaryButtonHeight,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _finish(completed: true),
                    child: Text(l.settingsBatteryGuide_done),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => _finish(completed: false),
                  child: Text(l.settingsBatteryGuide_skip),
                ),
                Text(
                  l.settingsBatteryGuide_skipNote,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySm,
                ),
              ],
            ),
    );
  }

  /// Opens the first settings page this phone actually has for [step].
  Future<void> _takeMeThere(OemGuideStepId step) async {
    final scheduler = ref.read(notificationSchedulerProvider);
    for (final target in settingsTargetsFor(step)) {
      if (await scheduler.openSettingsTarget(target)) return;
    }
    // Every target, including the app's own page, refused: let the user set it
    // by hand instead of leaving the tap looking broken.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).settingsBatteryGuide_openFailed,
        ),
      ),
    );
  }

  /// Records the outcome and re-arms the alarm.
  ///
  /// Re-arming matters here: the user may have just granted exact alarms, and
  /// the armed alarm's precision was decided before that.
  Future<void> _finish({required bool completed}) async {
    await ref
        .read(settingsViewModelProvider.notifier)
        .updateSettings(
          (settings) => settings.copyWith(
            notificationSetupDone: completed,
            notificationGuideShown: true,
          ),
        );
    await ref.read(notificationSchedulerProvider).syncSchedule();
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }
}

/// One numbered step: what to do, why, and a button that opens the page.
class _GuideStepCard extends StatelessWidget {
  /// Step number shown in the badge (1-based).
  final int number;

  /// Which step this is.
  final OemGuideStepId step;

  /// Whether to state that this step is already done (exact alarms only).
  final bool showAllowedState;

  /// Opens the phone's settings page for this step.
  final VoidCallback onTakeMeThere;

  const _GuideStepCard({
    required this.number,
    required this.step,
    required this.showAllowedState,
    required this.onTakeMeThere,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (title, body) = switch (step) {
      OemGuideStepId.autoStart => (
        l.settingsBatteryGuide_autoStartTitle,
        l.settingsBatteryGuide_autoStartBody,
      ),
      OemGuideStepId.batteryUnrestricted => (
        l.settingsBatteryGuide_batteryTitle,
        l.settingsBatteryGuide_batteryBody,
      ),
      OemGuideStepId.exactAlarms => (
        l.settingsBatteryGuide_exactTitle,
        l.settingsBatteryGuide_exactBody,
      ),
    };

    return Container(
      decoration: settingsCardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepBadge(number: number),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.bodyLg),
                    const SizedBox(height: AppSpacing.xs),
                    Text(body, style: AppTypography.bodySm),
                  ],
                ),
              ),
            ],
          ),
          if (showAllowedState) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 18,
                  color: AppColors.success,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l.settingsBatteryGuide_exactAllowed,
                    style: AppTypography.bodySm,
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: settingsMenuCardRowHeight,
              child: OutlinedButton(
                onPressed: onTakeMeThere,
                child: Text(l.settingsBatteryGuide_takeMeThere),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Circular step number.
class _StepBadge extends StatelessWidget {
  /// Number to show.
  final int number;

  const _StepBadge({required this.number});

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: AppColors.primaryContainer,
      shape: BoxShape.circle,
    ),
    child: Text(
      '$number',
      style: AppTypography.labelLg.copyWith(color: AppColors.onPrimary),
    ),
  );
}
