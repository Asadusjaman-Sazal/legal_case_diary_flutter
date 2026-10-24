/// Notification settings screen: upcoming-case alert preferences.
///
/// Body mirrors `mockup_html_screens/settings_notifications/code.html` — one
/// white card with the notification status, the day offsets and the delivery
/// time — plus the OEM battery-setup reminder banner and guide entry that the
/// plan (§10, Task 13) requires on this screen.
///
/// The card carries one more pair for a **confirmed administrator**: Payment
/// Request Alerts, the per-user switch the push sender reads for itself so a
/// silenced account is skipped server-side, while the app is closed.
///
/// The foot of the screen carries the **Client Notification** section for every
/// account: the automated WhatsApp/SMS message offered when a hearing date
/// changes (0.0.614).
///
/// The day offsets are a multi-select list, so one hearing can alert several
/// times (the same choice the case form offers per case), and the picker row
/// shows every ticked offset. The time window stays Flutter's, with the Bengali
/// bundle layered over it so বাংলা shows the English 12-hour window.
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
import '../../../admin/presentation/admin_viewmodel.dart';
import '../../data/notification_day_offsets.dart';
import 'client_notification_section.dart';
import 'notification_time_picker.dart';
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
    // Whether this screen may offer the payment-alert switch at all.
    final isAdmin = ref.watch(adminStatusProvider).value ?? false;
    final timeMinutes = settings.notificationTime ?? defaultNotificationMinutes;
    final dayOffsets = _tickedDayOffsets(settings);

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
                      key: const ValueKey('settings-notifications-status-on'),
                      label: l.settingsNotifications_on,
                      icon: Icons.notifications_outlined,
                      selected: settings.notificationEnabled,
                      onTap: () => _setEnabled(ref, true),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SettingsChoiceButton(
                      key: const ValueKey('settings-notifications-status-off'),
                      label: l.settingsNotifications_off,
                      icon: Icons.notifications_off_outlined,
                      selected: !settings.notificationEnabled,
                      onTap: () => _setEnabled(ref, false),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                // Notification day offsets — every ticked one alerts.
                SettingsSectionLabel(l.settingsNotifications_dayOffsetLabel),
                const SizedBox(height: AppSpacing.md),
                SettingsPickerRow(
                  text: _dayOffsetsLabel(l, dayOffsets),
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
                // Admin payment alerts, for a **confirmed administrator only**
                // — the same rule the panel itself follows, and the reason is the
                // same: a non-admin is shown nothing about a feature they cannot
                // have. False while the server's answer loads, so the row never
                // flashes in and out.
                if (isAdmin) ...[
                  const SizedBox(height: AppSpacing.xl),
                  // Not a hearing reminder: the count arrives from the server
                  // while the app is closed, and this switch is the per-user
                  // preference the sender reads for itself, so it silences the
                  // phone rather than only the app.
                  SettingsSectionLabel(
                    l.settingsNotifications_paymentAlertsLabel,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      SettingsChoiceButton(
                        key: const ValueKey(
                          'settings-notifications-payment-alerts-on',
                        ),
                        label: l.settingsNotifications_on,
                        icon: Icons.notifications_outlined,
                        selected: settings.paymentAlertsEnabled,
                        onTap: () => _setPaymentAlerts(ref, true),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      SettingsChoiceButton(
                        key: const ValueKey(
                          'settings-notifications-payment-alerts-off',
                        ),
                        label: l.settingsNotifications_off,
                        icon: Icons.notifications_off_outlined,
                        selected: !settings.paymentAlertsEnabled,
                        onTap: () => _setPaymentAlerts(ref, false),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // The client-facing automated message, for every account, sits above
          // the OEM/battery guidance (user request, 0.0.615).
          const ClientNotificationSection(),
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
  Future<void> _sendTestNotification(
    BuildContext context,
    WidgetRef ref,
  ) async {
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

  /// Persists the admin payment-alert toggle.
  ///
  /// Nothing local is scheduled for it — the count is pushed by the server — so
  /// there is no alarm to re-arm; the saved preference is what reaches the
  /// sender, and an account that is not an administrator never receives one.
  ///
  /// Switching it **on** asks for the OS notification permission if the app does
  /// not have it, the same question the test alert below asks: Android 13+ drops
  /// a notification an app may not post, so a preference switched on without it
  /// would be a switch that does nothing.
  Future<void> _setPaymentAlerts(WidgetRef ref, bool enabled) async {
    if (enabled) {
      final scheduler = ref.read(notificationSchedulerProvider);
      if (!await scheduler.notificationsAllowed()) {
        await scheduler.requestNotificationsPermission();
      }
    }
    await ref
        .read(settingsViewModelProvider.notifier)
        .updateSettings(
          (current) => current.copyWith(paymentAlertsEnabled: enabled),
        );
  }

  /// Keeps the armed alarm in step with what was just saved.
  ///
  /// The scheduler reads the stored settings on every call, so one call covers
  /// both a changed time and switching alerts off (which cancels the alarm).
  Future<void> _resyncSchedule(WidgetRef ref) =>
      ref.read(notificationSchedulerProvider).syncSchedule();

  /// Opens the day-offset picker and stores every tick.
  ///
  /// Ticking a row saves straight away — like the ON/OFF pair above it — so
  /// the dialog needs no confirm button and the header's close button simply
  /// dismisses it. One offset always stays ticked: an empty list would be
  /// indistinguishable from the master switch being off.
  Future<void> _pickDayOffset(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final settings =
        ref.read(settingsViewModelProvider).value ?? const UserSettings();
    await showDialog<void>(
      context: context,
      builder: (_) => SettingsMultiSelectDialog<int>(
        title: l.settingsNotifications_selectDayOffsetTitle,
        order: notificationDayOffsetOptions,
        selected: _tickedDayOffsets(settings).toSet(),
        labelOf: (offset) => _dayOffsetLabel(l, offset),
        // Same window and taller title bar as the View Settings dropdowns.
        popoverWindow: true,
        minSelected: 1,
        minSelectedMessage: l.settingsNotifications_keepOneOffset,
        onChanged: (_, chosen) => _storeDayOffsets(ref, chosen),
      ),
    );
  }

  /// Stores the ticked day offsets and re-arms the daily alarm.
  ///
  /// The single `notificationDayOffset` the case form starts from stays in
  /// step with the list: it is the earliest offset ticked, so a new case
  /// defaults to the nearest alert the user asked for.
  Future<void> _storeDayOffsets(WidgetRef ref, List<int> offsets) async {
    final chosen = <int>[
      for (final offset in notificationDayOffsetOptions)
        if (offsets.contains(offset)) offset,
    ];
    if (chosen.isEmpty) return;
    await ref
        .read(settingsViewModelProvider.notifier)
        .updateSettings(
          (settings) => settings.copyWith(
            notificationDayOffset: chosen.first,
            notificationDefaultOffsets: chosen,
          ),
        );
    await _resyncSchedule(ref);
  }

  /// Opens the shared notification-time window and stores the choice in
  /// minutes. The same window the case form's Notification Time field opens.
  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    int currentMinutes,
  ) async {
    final picked = await showNotificationTimePicker(
      context,
      initialMinutes: currentMinutes,
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

/// Day offsets to show as ticked, in the picker's order.
///
/// The stored list is the source of truth; it is always non-empty, and an
/// install that has never ticked anything carries the default.
List<int> _tickedDayOffsets(UserSettings settings) {
  final ticked = <int>[
    for (final offset in notificationDayOffsetOptions)
      if (settings.notificationDefaultOffsets.contains(offset)) offset,
  ];
  return ticked.isEmpty ? const <int>[defaultNotificationDayOffset] : ticked;
}

/// Localized label of one day-offset option.
String _dayOffsetLabel(AppLocalizations l, int offset) => switch (offset) {
  0 => l.settingsNotifications_offsetSameDay,
  1 => l.settingsNotifications_offsetDayBefore,
  _ => l.settingsNotifications_offsetBeforeDays(offset),
};

/// The picker row's value: every ticked offset, in the picker's order.
String _dayOffsetsLabel(AppLocalizations l, List<int> offsets) =>
    offsets.map((offset) => _dayOffsetLabel(l, offset)).join(', ');

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
