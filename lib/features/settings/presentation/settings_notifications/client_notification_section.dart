/// The Client Notification section of Settings → Notifications.
///
/// Every account sees it (unlike the admin-only payment alerts): it decides
/// whether a changed hearing date offers the client a prepared WhatsApp or SMS,
/// which app is used, which template each channel sends, whether the app asks
/// first, and the call-back number printed in the long message. The two
/// quotations show exactly what will be sent, using sample case facts so the
/// wording can be judged without a case.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/l10n/app_translations.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/services/client_notification_message.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_dialog_actions.dart';
import '../../../accounts_and_profile/data/profile_name_store.dart';
import '../../data/settings_repository.dart';
import '../settings_controls.dart';
import '../settings_menu_card.dart';
import '../settings_viewmodel.dart';

/// The whole section: master switch, channel, templates with previews, the Ask
/// setting and the call-back number.
class ClientNotificationSection extends ConsumerWidget {
  /// Creates the section.
  const ClientNotificationSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings =
        ref.watch(settingsViewModelProvider).value ?? const UserSettings();
    final profile = ref.watch(profileFieldsProvider);
    final whatsApp =
        settings.automatedNotificationChannel ==
        clientNotificationChannelWhatsApp;

    return Container(
      decoration: settingsCardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Automated Notification: the master switch, shaped like the admin
          // payment-alert pair above.
          SettingsSectionLabel(l.clientNotification_automatedLabel),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              SettingsChoiceButton(
                key: const ValueKey('client-notification-enabled-on'),
                label: l.settingsNotifications_on,
                icon: Icons.notifications_outlined,
                selected: settings.automatedNotificationEnabled,
                onTap: () => _change(
                  ref,
                  (current) =>
                      current.copyWith(automatedNotificationEnabled: true),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SettingsChoiceButton(
                key: const ValueKey('client-notification-enabled-off'),
                label: l.settingsNotifications_off,
                icon: Icons.notifications_off_outlined,
                selected: !settings.automatedNotificationEnabled,
                onTap: () => _change(
                  ref,
                  (current) =>
                      current.copyWith(automatedNotificationEnabled: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          // Ask first, or open the app straight away. Remembering an answer in
          // the prompt writes these two switches: Yes keeps the feature on and
          // turns Ask off; No turns both off.
          SettingsSectionLabel(l.clientNotification_askLabel),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              SettingsChoiceButton(
                key: const ValueKey('client-notification-ask-yes'),
                label: l.sharedActions_yes,
                selected: settings.automatedNotificationAskBeforeSending,
                onTap: () => _change(
                  ref,
                  (current) => current.copyWith(
                    automatedNotificationAskBeforeSending: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SettingsChoiceButton(
                key: const ValueKey('client-notification-ask-no'),
                label: l.sharedActions_no,
                selected: !settings.automatedNotificationAskBeforeSending,
                onTap: () => _change(
                  ref,
                  (current) => current.copyWith(
                    automatedNotificationAskBeforeSending: false,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const SizedBox(height: AppSpacing.xl),
          // Which app opens. One at a time, so the client never gets the same
          // update twice.
          SettingsSectionLabel(l.clientNotification_channelLabel),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              SettingsChoiceButton(
                key: const ValueKey('client-notification-channel-whatsapp'),
                label: l.casesContact_whatsapp,
                icon: Icons.chat_outlined,
                selected: whatsApp,
                onTap: () => _change(
                  ref,
                  (current) => current.copyWith(
                    automatedNotificationChannel:
                        clientNotificationChannelWhatsApp,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SettingsChoiceButton(
                key: const ValueKey('client-notification-channel-sms'),
                label: l.clientNotification_sms,
                icon: Icons.sms_outlined,
                selected: !whatsApp,
                onTap: () => _change(
                  ref,
                  (current) => current.copyWith(
                    automatedNotificationChannel: clientNotificationChannelSms,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          // The template each channel sends, with its live quotation below it.
          SettingsSectionLabel(l.clientNotification_templateLabel),
          const SizedBox(height: AppSpacing.md),
          _TemplateRow(
            title: l.casesContact_whatsapp,
            longSelected:
                settings.automatedNotificationWhatsAppTemplate ==
                clientNotificationTemplateLong,
            longKey: const ValueKey('client-notification-whatsapp-long'),
            shortKey: const ValueKey('client-notification-whatsapp-short'),
            onChanged: (long) => _change(
              ref,
              (current) => current.copyWith(
                automatedNotificationWhatsAppTemplate: long
                    ? clientNotificationTemplateLong
                    : clientNotificationTemplateShort,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Quotation(
            key: const ValueKey('client-notification-whatsapp-preview'),
            message: _previewMessage(
              context,
              settings: settings,
              profile: profile,
              long:
                  settings.automatedNotificationWhatsAppTemplate ==
                  clientNotificationTemplateLong,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _TemplateRow(
            title: l.clientNotification_sms,
            longSelected:
                settings.automatedNotificationSmsTemplate ==
                clientNotificationTemplateLong,
            longKey: const ValueKey('client-notification-sms-long'),
            shortKey: const ValueKey('client-notification-sms-short'),
            onChanged: (long) => _change(
              ref,
              (current) => current.copyWith(
                automatedNotificationSmsTemplate: long
                    ? clientNotificationTemplateLong
                    : clientNotificationTemplateShort,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Quotation(
            key: const ValueKey('client-notification-sms-preview'),
            message: _previewMessage(
              context,
              settings: settings,
              profile: profile,
              long:
                  settings.automatedNotificationSmsTemplate ==
                  clientNotificationTemplateLong,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // The call-back number printed in the long message.
          SettingsSectionLabel(l.clientNotification_contactLabel),
          const SizedBox(height: AppSpacing.md),
          Container(
            key: const ValueKey('client-notification-contact-row'),
            padding: const EdgeInsets.only(left: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    settings.notificationContactNumber.isEmpty
                        ? l.clientNotification_contactNotSet
                        : settings.notificationContactNumber,
                    style: AppTypography.bodyMd.copyWith(
                      color: settings.notificationContactNumber.isEmpty
                          ? AppColors.onSurfaceVariant
                          : AppColors.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('client-notification-contact-edit'),
                  tooltip: l.sharedActions_edit,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editContact(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Stores one change without rebuilding the rest of the settings value.
  Future<void> _change(
    WidgetRef ref,
    UserSettings Function(UserSettings) change,
  ) => ref.read(settingsViewModelProvider.notifier).updateSettings(change);

  /// Opens the small number editor and saves a cleared field as an empty box.
  Future<void> _editContact(BuildContext context, WidgetRef ref) async {
    final settings =
        ref.read(settingsViewModelProvider).value ?? const UserSettings();
    final value = await showDialog<String>(
      context: context,
      builder: (_) =>
          _ContactNumberDialog(initial: settings.notificationContactNumber),
    );
    if (value == null) return;
    await _change(
      ref,
      (current) => current.copyWith(notificationContactNumber: value),
    );
  }

  /// The sample message both quotations show.
  ///
  /// The lawyer's own name and resolved contact are real; the case facts are the
  /// approved sample, so the wording can be judged before a case is picked.
  String _previewMessage(
    BuildContext context, {
    required UserSettings settings,
    required ProfileFields profile,
    required bool long,
  }) {
    final l = AppLocalizations.of(context);
    final contact = settings.notificationContactNumber.isNotEmpty
        ? settings.notificationContactNumber
        : profile.mobile.trim().isEmpty
        ? null
        : profile.mobile.trim();
    final facts = ClientMessageFacts(
      clientName: l.clientNotification_previewClient,
      caseLine: l.clientNotification_previewCase,
      nextDateMs: AppDateUtils.bangladeshCivilDateEpoch(2026, 11, 17),
      steps: <String>[l.clientNotification_previewSteps],
      court: l.clientNotification_previewCourt,
      lawyerName: profile.fullName.trim().isEmpty
          ? l.clientNotification_previewLawyer
          : profile.fullName.trim(),
      contactNumber: contact,
    );
    return buildClientNotificationMessage(
      translations: context.l10n,
      facts: facts,
      long: long,
    );
  }
}

/// One channel's Long / Short pair.
class _TemplateRow extends StatelessWidget {
  const _TemplateRow({
    required this.title,
    required this.longSelected,
    required this.longKey,
    required this.shortKey,
    required this.onChanged,
  });

  final String title;
  final bool longSelected;
  final Key longKey;
  final Key shortKey;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.bodyLg),
        const SizedBox(height: AppSpacing.sm),
        // The pair shares the row's width, so a longer Bengali label has room
        // instead of overflowing a fixed compact control.
        Row(
          children: [
            SettingsChoiceButton(
              key: longKey,
              label: l.clientNotification_longLabel,
              selected: longSelected,
              onTap: () => onChanged(true),
            ),
            const SizedBox(width: AppSpacing.sm),
            SettingsChoiceButton(
              key: shortKey,
              label: l.clientNotification_shortLabel,
              selected: !longSelected,
              onTap: () => onChanged(false),
            ),
          ],
        ),
      ],
    );
  }
}

/// The example message: "Example:" over the justified text, in the low box.
class _Quotation extends StatelessWidget {
  const _Quotation({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(settingsMenuCardRadius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.clientNotification_exampleLabel,
                style: AppTypography.labelLg.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.justify,
                style: AppTypography.bodySm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small editor for the call-back number: digits only, empty clears it.
class _ContactNumberDialog extends StatefulWidget {
  const _ContactNumberDialog({required this.initial});

  final String initial;

  @override
  State<_ContactNumberDialog> createState() => _ContactNumberDialogState();
}

class _ContactNumberDialogState extends State<_ContactNumberDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AppDialogFrame(
      dialogKey: const ValueKey('client-notification-contact-dialog'),
      title: Text(
        l.clientNotification_contactLabel,
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.clientNotification_contactDialogHelper,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('client-notification-contact-input'),
            controller: _controller,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(15),
            ],
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: (dialogContext) => [
        AppDialogAction(
          key: const ValueKey('client-notification-contact-cancel'),
          label: l.sharedActions_cancel,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
        AppDialogAction(
          key: const ValueKey('client-notification-contact-save'),
          label: l.sharedActions_save,
          kind: AppDialogActionKind.primary,
          onPressed: () =>
              Navigator.of(dialogContext).pop(_controller.text.trim()),
        ),
      ],
    );
  }
}
