/// Battery Optimization & Auto-Start setup guide (Task 13 Phase 3).
///
/// The plan's localized, step-by-step screen that keeps hearing alerts alive on
/// the aggressive OEM firmware dominating the target market: allow auto-start,
/// take the app off battery optimization, and (Android 12+) allow exact alarms.
/// Each step has a "Take Me There" button that jumps to the phone's own settings
/// page, with the app's details page as the fallback when the OEM page is gone.
///
/// **A step the phone can answer is ticked in green from the phone's own state**
/// (battery optimization, exact alarms) and re-read whenever the app comes back
/// from a settings page. Auto-start is the exception: Android exposes no API for
/// an OEM-only setting, so that step is the user's own tick — the same
/// arrangement as pressing "Done" at the bottom.
///
/// **No mockup exists for this screen**, so it is built from the Settings
/// chrome and the shared controls the Notifications mockup already established
/// (`SettingsSubPageModal` + `settings_controls.dart`), as approved with the
/// user. Finishing or skipping the guide records the choice in the per-user
/// `user_preferences` row, which is what hides the reminder banner.
library;

import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/notifications/oem_setup_guide.dart';
import '../../../../core/providers/notification_providers.dart';
import '../../data/settings_repository.dart';
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
    extends ConsumerState<BatterySetupGuideScreen>
    with WidgetsBindingObserver {
  /// Steps for this device; null until the manufacturer has been read.
  OemGuidePlan? _plan;

  /// What the phone reported, kept for the brand-specific instructions.
  DeviceIdentity? _identity;

  /// Whether exact alarms are already permitted: the phone's own answer.
  bool _exactAlarmsAllowed = false;

  /// Whether the phone already has the app off battery optimization.
  bool _batteryUnrestricted = false;

  /// Whether the user ticked the auto-start step; the phone cannot say, so their
  /// word is kept in the per-user settings.
  bool _autoStartDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDeviceSetup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // "Take Me There" hands the user to the phone's own settings, so the only
    // moment either answer can have changed is on the way back.
    if (state == AppLifecycleState.resumed) _refreshDeviceChecks();
  }

  /// Reads the phone's state and the user's own tick, then shows the plan.
  Future<void> _loadDeviceSetup() async {
    final scheduler = ref.read(notificationSchedulerProvider);
    final identity = await scheduler.deviceIdentity();
    // The guide is an enhancement and this is the app's first screen on a fresh
    // install, so a failed settings read leaves the steps usable with auto-start
    // simply un-ticked, rather than hanging the screen on its spinner.
    UserSettings settings;
    try {
      settings = await ref.read(settingsViewModelProvider.future);
    } catch (error, stackTrace) {
      dev.log(
        'Setup guide could not read the saved auto-start tick',
        name: 'notifications',
        error: error,
        stackTrace: stackTrace,
      );
      settings = const UserSettings();
    }
    final exactAllowed = await scheduler.canScheduleExactAlarms();
    final batteryUnrestricted = await scheduler.batteryOptimizationIgnored();
    if (!mounted) return;
    setState(() {
      _identity = identity;
      _plan = oemGuidePlanFor(identity);
      _exactAlarmsAllowed = exactAllowed;
      _batteryUnrestricted = batteryUnrestricted;
      _autoStartDone = settings.notificationAutoStartDone;
    });
  }

  /// Re-reads the two checks the high-level OS can answer.
  ///
  /// Runs on every resume, so a permission granted on a settings page shows up
  /// as soon as the user returns instead of at the next screen open.
  Future<void> _refreshDeviceChecks() async {
    final scheduler = ref.read(notificationSchedulerProvider);
    final exactAllowed = await scheduler.canScheduleExactAlarms();
    final batteryUnrestricted = await scheduler.batteryOptimizationIgnored();
    if (!mounted) return;
    setState(() {
      _exactAlarmsAllowed = exactAllowed;
      _batteryUnrestricted = batteryUnrestricted;
    });
  }

  /// Whether [step] is done: the phone's answer, except auto-start.
  bool _isDone(OemGuideStepId step) => switch (step) {
    OemGuideStepId.autoStart => _autoStartDone,
    OemGuideStepId.batteryUnrestricted => _batteryUnrestricted,
    OemGuideStepId.exactAlarms => _exactAlarmsAllowed,
  };

  /// Records (or clears) the user's own auto-start confirmation.
  Future<void> _setAutoStartDone(bool done) async {
    setState(() => _autoStartDone = done);
    await ref
        .read(settingsViewModelProvider.notifier)
        .updateSettings(
          (settings) => settings.copyWith(notificationAutoStartDone: done),
        );
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
                    brand: _guideBrand(_identity),
                    done: _isDone(step),
                    // Auto-start is the one step Android cannot read, so it is
                    // the one the user ticks (and un-ticks) themselves.
                    onToggleDone: step == OemGuideStepId.autoStart
                        ? () => _setAutoStartDone(!_autoStartDone)
                        : null,
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

/// Which brand's settings path the guide should spell out.
enum _GuideBrand { xiaomi, realme, vivo, other }

/// The brand whose instructions this phone should read.
///
/// Only the three brands the owner could verify get their own path; every other
/// phone keeps the generic wording. Realme is checked by its own name because
/// the OEM family groups it with Oppo/OnePlus, whose menus differ (0.0.703).
_GuideBrand _guideBrand(DeviceIdentity? identity) {
  if (identity == null) return _GuideBrand.other;
  final haystack = '${identity.manufacturer ?? ''} ${identity.brand ?? ''}'
      .toLowerCase();
  if (haystack.contains('realme')) return _GuideBrand.realme;
  return switch (oemFamilyFor(identity)) {
    OemFamily.xiaomi => _GuideBrand.xiaomi,
    OemFamily.vivo => _GuideBrand.vivo,
    _ => _GuideBrand.other,
  };
}

/// The auto-start path for [brand].
String _autoStartBody(AppLocalizations l, _GuideBrand brand) => switch (brand) {
  _GuideBrand.xiaomi => l.settingsBatteryGuide_autoStartXiaomi,
  _GuideBrand.realme => l.settingsBatteryGuide_autoStartRealme,
  _GuideBrand.vivo => l.settingsBatteryGuide_autoStartVivo,
  _GuideBrand.other => l.settingsBatteryGuide_autoStartBody,
};

/// The battery path for [brand].
String _batteryBody(AppLocalizations l, _GuideBrand brand) => switch (brand) {
  _GuideBrand.xiaomi => l.settingsBatteryGuide_batteryXiaomi,
  _GuideBrand.realme => l.settingsBatteryGuide_batteryRealme,
  _GuideBrand.vivo => l.settingsBatteryGuide_batteryVivo,
  _GuideBrand.other => l.settingsBatteryGuide_batteryBody,
};

/// One numbered step: what to do, why, and a button that opens the page.
///
/// A done step is drawn in green — badge, title and the line that replaces the
/// button — so the whole guide reads at a glance.
class _GuideStepCard extends StatelessWidget {
  /// Step number shown in the badge (1-based).
  final int number;

  /// Which step this is.
  final OemGuideStepId step;

  /// The phone's brand, for the two steps whose path differs per OEM.
  final _GuideBrand brand;

  /// Whether the step is done, and so drawn in green.
  final bool done;

  /// Ticks or un-ticks a step the user confirms themselves; null for the steps
  /// the phone answers on its own.
  final VoidCallback? onToggleDone;

  /// Opens the phone's settings page for this step.
  final VoidCallback onTakeMeThere;

  const _GuideStepCard({
    required this.number,
    required this.step,
    required this.brand,
    required this.done,
    required this.onToggleDone,
    required this.onTakeMeThere,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (title, body) = switch (step) {
      OemGuideStepId.autoStart => (
        l.settingsBatteryGuide_autoStartTitle,
        _autoStartBody(l, brand),
      ),
      OemGuideStepId.batteryUnrestricted => (
        l.settingsBatteryGuide_batteryTitle,
        _batteryBody(l, brand),
      ),
      OemGuideStepId.exactAlarms => (
        l.settingsBatteryGuide_exactTitle,
        l.settingsBatteryGuide_exactBody,
      ),
    };
    // One line per step, each naming how *that* step's completion is known.
    final doneLabel = switch (step) {
      OemGuideStepId.autoStart => l.settingsBatteryGuide_autoStartDone,
      OemGuideStepId.batteryUnrestricted =>
        l.settingsBatteryGuide_batteryAllowed,
      OemGuideStepId.exactAlarms => l.settingsBatteryGuide_exactAllowed,
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
              _StepBadge(number: number, done: done),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: done
                          ? AppTypography.bodyLg.copyWith(
                              color: AppColors.success,
                            )
                          : AppTypography.bodyLg,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // The instructions stay neutral in both states: they are
                    // still worth reading while the step is checked.
                    Text(body, style: AppTypography.bodySm),
                  ],
                ),
              ),
            ],
          ),
          if (done) ...[
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
                    doneLabel,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.success,
                    ),
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
          if (onToggleDone != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: onToggleDone,
              child: Text(
                done
                    ? l.settingsBatteryGuide_markNotDone
                    : l.settingsBatteryGuide_markDone,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Circular step number, which becomes a green tick once the step is done.
class _StepBadge extends StatelessWidget {
  /// Number to show while the step is outstanding.
  final int number;

  /// Whether the step is done.
  final bool done;

  const _StepBadge({required this.number, required this.done});

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: done ? AppColors.success : AppColors.primaryContainer,
      shape: BoxShape.circle,
    ),
    child: done
        ? const Icon(Icons.check, size: 18, color: AppColors.onPrimary)
        : Text(
            '$number',
            style: AppTypography.labelLg.copyWith(color: AppColors.onPrimary),
          ),
  );
}
