/// Notification settings screen: upcoming-case alert preferences.
///
/// Body mirrors `mockup_html_screens/settings_notifications/code.html` — one
/// white card with the notification status, the day offset and the delivery
/// time — plus the OEM battery-setup reminder banner and guide entry that the
/// plan (§10, Task 13) requires on this screen.
///
/// Every value is a durable per-user preference in the local `user_preferences`
/// row (never firm-shared); premium self-scoped sync arrives in Part B. The
/// alarm/scheduling side is Task 13, so the guide entry only says so for now.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/app_router.dart';
// The mockup's default alert time lives with the scheduler so the screen and
// the daily job cannot drift apart.
import '../../../../core/notifications/notification_plan.dart';
import '../../../../core/providers/notification_providers.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/utils/date_utils.dart';
import '../../data/notification_day_offsets.dart';
import '../../data/settings_repository.dart';
import '../settings_controls.dart';
import '../settings_menu_card.dart';
import '../settings_sub_page_modal.dart';
import '../settings_viewmodel.dart';

/// Notification settings screen.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings =
        ref.watch(settingsViewModelProvider).value ?? const UserSettings();
    final timeMinutes = settings.notificationTime ?? defaultNotificationMinutes;

    return SettingsSubPageModal(
      title: l.settingsNotifications_title,
      child: ListView(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Default notification status — the mockup's ON/OFF pair.
                SettingsSectionLabel(l.settingsNotifications_statusLabel),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    SettingsChoiceButton(
                      label: l.settingsNotifications_on,
                      icon: Icons.notifications_outlined,
                      selected: settings.notificationEnabled,
                      onTap: () => _setEnabled(ref, true),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SettingsChoiceButton(
                      label: l.settingsNotifications_off,
                      icon: Icons.notifications_off_outlined,
                      selected: !settings.notificationEnabled,
                      onTap: () => _setEnabled(ref, false),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                // Notification day offset.
                SettingsSectionLabel(l.settingsNotifications_dayOffsetLabel),
                const SizedBox(height: AppSpacing.md),
                SettingsPickerRow(
                  text: _dayOffsetLabel(l, settings.notificationDayOffset),
                  icon: Icons.expand_more,
                  onTap: () => _pickDayOffset(context, ref),
                ),
                const SizedBox(height: AppSpacing.xl),
                // Notification time.
                SettingsSectionLabel(l.settingsNotifications_timeLabel),
                const SizedBox(height: AppSpacing.md),
                SettingsPickerRow(
                  text: AppDateUtils.formatClockTime(
                    timeMinutes,
                    locale: Localizations.localeOf(context).languageCode,
                  ),
                  icon: Icons.schedule,
                  onTap: () => _pickTime(context, ref, timeMinutes),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // OEM battery-killer reminder: the plan keeps this on the screen until
          // the user finishes the setup guide, and tapping it opens the guide.
          if (!settings.notificationSetupDone) ...[
            _SetupReminderBanner(
              message: l.settingsNotifications_reminderBanner,
              onTap: () => context.push(AppRoutes.settingsBatterySetupGuide),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          SettingsMenuCard(
            icon: Icons.battery_charging_full,
            title: l.settingsNotifications_setupGuide,
            subtitle: l.settingsNotifications_setupGuideSubtitle,
            onTap: () => context.push(AppRoutes.settingsBatterySetupGuide),
          ),
          const SizedBox(height: AppSpacing.md),
          // The mockup's Test Notification section: a real alert through the
          // real channel, so the user can check delivery without waiting for
          // the daily alarm.
          SettingsMenuCard(
            icon: Icons.notifications_active_outlined,
            title: l.settingsNotifications_sendTest,
            subtitle: l.settingsNotifications_sendTestSubtitle,
            onTap: () => _sendTestNotification(context, ref),
          ),
        ],
      ),
    );
  }

  /// Posts a test notification, asking for the OS permission first.
  ///
  /// Without the permission the alert would be silently dropped by Android, so
  /// a refusal is reported instead of being papered over with a success message.
  Future<void> _sendTestNotification(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final scheduler = ref.read(notificationSchedulerProvider);
    if (!await scheduler.notificationsAllowed()) {
      await scheduler.requestNotificationsPermission();
    }
    final allowed = await scheduler.notificationsAllowed();
    if (allowed) await scheduler.showTestNotification();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          allowed
              ? l.settingsNotifications_testSent
              : l.settingsNotifications_testFailed,
        ),
      ),
    );
  }

  /// Persists the notification master toggle and re-arms the daily alarm.
  Future<void> _setEnabled(WidgetRef ref, bool enabled) async {
    await ref
        .read(settingsViewModelProvider.notifier)
        .updateSettings(
          (current) => current.copyWith(notificationEnabled: enabled),
        );
    await _resyncSchedule(ref);
  }

  /// Keeps the armed alarm in step with what was just saved.
  ///
  /// The scheduler reads the stored settings on every call, so one call covers
  /// both a changed time and switching alerts off (which cancels the alarm).
  Future<void> _resyncSchedule(WidgetRef ref) =>
      ref.read(notificationSchedulerProvider).syncSchedule();

  /// Opens the day-offset modal and stores the choice.
  Future<void> _pickDayOffset(BuildContext context, WidgetRef ref) async {
    final current = ref
        .read(settingsViewModelProvider)
        .value
        ?.notificationDayOffset;
    final selected = await showDialog<int>(
      context: context,
      builder: (_) =>
          _DayOffsetDialog(selected: current ?? defaultNotificationDayOffset),
    );
    if (selected == null || selected == current) return;
    await ref
        .read(settingsViewModelProvider.notifier)
        .updateSettings(
          (settings) => settings.copyWith(
            notificationDayOffset: selected,
            // The single choice is mirrored into the offsets list so the daily
            // job (Task 13) can read either field.
            notificationDefaultOffsets: <int>[selected],
          ),
        );
    await _resyncSchedule(ref);
  }

  /// Opens the platform time picker and stores the choice in minutes.
  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    int currentMinutes,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: currentMinutes ~/ 60,
        minute: currentMinutes % 60,
      ),
    );
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    await ref
        .read(settingsViewModelProvider.notifier)
        .updateSettings(
          (settings) => settings.copyWith(notificationTime: minutes),
        );
    await _resyncSchedule(ref);
  }

}

/// Localized label of one day-offset option.
String _dayOffsetLabel(AppLocalizations l, int offset) => switch (offset) {
  0 => l.settingsNotifications_offsetSameDay,
  1 => l.settingsNotifications_offsetDayBefore,
  _ => l.settingsNotifications_offsetBeforeDays(offset),
};

/// Single-select day-offset modal, matching the mockup's list (dark header,
/// divided rows, `check_circle` on the active one). Tapping a row selects it
/// and closes, because the mockup's modal has no confirm button. The options
/// are [notificationDayOffsetOptions], the same list the case form offers.
class _DayOffsetDialog extends StatelessWidget {
  /// Currently stored offset.
  final int selected;

  const _DayOffsetDialog({required this.selected});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SettingsPickerDialogHeader(
            title: l.settingsNotifications_selectDayOffsetTitle,
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final offset in notificationDayOffsetOptions) ...[
                  if (offset != notificationDayOffsetOptions.first)
                    const Divider(height: 1, color: AppColors.outlineVariant),
                  SettingsOptionRow(
                    label: _dayOffsetLabel(l, offset),
                    selected: offset == selected,
                    onTap: () => Navigator.of(context).pop(offset),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The plan's persistent, non-intrusive "notifications may not work" banner.
class _SetupReminderBanner extends StatelessWidget {
  /// Banner copy.
  final String message;

  /// Banner tap handler.
  final VoidCallback onTap;

  const _SetupReminderBanner({required this.message, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.errorContainer,
    borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
