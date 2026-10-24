/// The automated client notification: decide, ask, compose and open.
///
/// Called by the two save windows after a hearing date has actually changed.
/// Nothing is sent silently — WhatsApp has no send API and a silent SMS needs a
/// permission Google Play restricts — so the chosen app is opened with the
/// finished text and the lawyer taps Send.
///
/// The flow never throws: the case is already saved by the time it runs, and a
/// missing court row, an unreadable setting or an app that will not open must
/// never turn a successful save into an error.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_translations.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/contact_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/services/client_notification_message.dart';
import '../../../core/services/contact_launcher.dart';
import '../../../core/utils/date_utils.dart';
import '../../../database/app_database.dart';
import '../../accounts_and_profile/data/profile_name_store.dart';
import '../../settings/data/client_notification_settings.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/presentation/settings_viewmodel.dart';

/// Offers or performs the client message for a changed hearing date.
///
/// [previousNextDateMs] is the date the case held before the save. The message
/// only runs when the civil day changed (re-picking the same day sends nothing),
/// the case has a client phone, and the account turned automated notifications
/// on. Ask/remembered answers decide whether the confirmation appears.
Future<void> maybeSendAutomatedClientNotification(
  BuildContext context, {
  required WidgetRef ref,
  required Case updatedCase,
  required int? previousNextDateMs,
}) async {
  try {
    final nextDate = updatedCase.nextDate;
    if (nextDate == null) return;
    final dateChanged =
        previousNextDateMs == null ||
        !AppDateUtils.isSameBangladeshCivilDate(previousNextDateMs, nextDate);
    final number = normalizeLaunchNumber(updatedCase.partyPhone);
    if (!dateChanged || number == null) return;

    final settings = await ref.read(settingsViewModelProvider.future);
    final decision = resolveClientNotificationDecision(
      settings: settings,
      dateChanged: dateChanged,
      hasRecipient: true,
    );
    if (decision == ClientNotificationDecision.none) return;
    if (!context.mounted) return;

    var send = decision == ClientNotificationDecision.send;
    if (decision == ClientNotificationDecision.ask) {
      final answer = await showDialog<_PromptAnswer>(
        context: context,
        useRootNavigator: true,
        builder: (_) => const AutomatedMessagePromptDialog(),
      );
      // A dismissed prompt is a No for this save; only an explicit answer can be
      // remembered.
      if (answer == null || !answer.send) {
        if (answer != null && answer.remember) {
          await _rememberAnswer(ref, send: false);
        }
        return;
      }
      send = true;
      if (answer.remember) await _rememberAnswer(ref, send: true);
    }
    if (!send || !context.mounted) return;

    final translations = context.l10n;
    final l = translations.raw;
    Court? court;
    OnBehalf? onBehalf;
    try {
      court = await (await ref.read(
        courtsRepositoryProvider.future,
      )).getById(updatedCase.courtId);
    } catch (_) {
      // The seed data still names a seeder court; a custom court is shown by its
      // stored id rather than failing the message.
    }
    try {
      onBehalf = await (await ref.read(
        onBehalfsRepositoryProvider.future,
      )).getById(updatedCase.onBehalfId);
    } catch (_) {
      // The represented party then falls back to the petitioner.
    }

    final profile = ref.read(profileFieldsProvider);
    final contact = settings.notificationContactNumber.trim().isNotEmpty
        ? settings.notificationContactNumber.trim()
        : profile.mobile.trim().isEmpty
        ? null
        : profile.mobile.trim();
    final facts = buildClientMessageFacts(
      translations: translations,
      currentCase: updatedCase,
      court: court,
      onBehalf: onBehalf,
      nextDateMs: nextDate,
      lawyerName: profile.fullName,
      contactNumber: contact,
    );
    final whatsApp =
        settings.automatedNotificationChannel ==
        clientNotificationChannelWhatsApp;
    final long = whatsApp
        ? settings.automatedNotificationWhatsAppTemplate ==
              clientNotificationTemplateLong
        : settings.automatedNotificationSmsTemplate ==
              clientNotificationTemplateLong;
    final message = buildClientNotificationMessage(
      translations: translations,
      facts: facts,
      long: long,
    );
    final uri = whatsApp
        ? whatsAppUri(whatsAppNumber(number)!, message)
        : smsUri(number, message);
    final opened = await ref.read(contactLauncherProvider).open(uri);
    if (!opened && context.mounted) {
      _rootMessengerOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            whatsApp
                ? l.casesContact_unableToOpenWhatsApp
                : l.casesContact_unableToMessage,
          ),
        ),
      );
    }
  } catch (_) {
    // The save is already committed; a notification failure is not a save error.
  }
}

/// Writes the answer into the two switches the section shows.
///
/// Remembered Yes keeps the feature on and stops asking; remembered No turns the
/// feature and Ask off, so nothing is sent or asked again. A later manual change
/// to the master and Ask switches is therefore what brings the prompt back.
/// A failure here must not lose this save's answer: the caller already decided to
/// send, and only the next prompt reappears.
Future<void> _rememberAnswer(WidgetRef ref, {required bool send}) async {
  try {
    await ref
        .read(settingsViewModelProvider.notifier)
        .updateSettings(
          (current) => current.copyWith(
            automatedNotificationEnabled: send,
            automatedNotificationAskBeforeSending: false,
          ),
        );
  } catch (_) {
    // Remembering is an optimisation, not a condition of sending.
  }
}

/// The app's root messenger, which outlives the Update window and Edit sheet.
ScaffoldMessengerState? _rootMessengerOf(BuildContext context) {
  try {
    return ScaffoldMessenger.maybeOf(
      Navigator.of(context, rootNavigator: true).context,
    );
  } catch (_) {
    return null;
  }
}

/// What the confirmation returned.
class _PromptAnswer {
  const _PromptAnswer({required this.send, required this.remember});

  /// Whether the message should be opened.
  final bool send;

  /// Whether the answer should replace the next prompt.
  final bool remember;
}

/// The confirmation shown before the messaging app opens.
class AutomatedMessagePromptDialog extends StatefulWidget {
  /// Creates the prompt.
  const AutomatedMessagePromptDialog({super.key});

  @override
  State<AutomatedMessagePromptDialog> createState() =>
      _AutomatedMessagePromptDialogState();
}

class _AutomatedMessagePromptDialogState
    extends State<AutomatedMessagePromptDialog> {
  bool _remember = false;

  void _close({required bool send}) =>
      Navigator.of(context).pop(_PromptAnswer(send: send, remember: _remember));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      key: const ValueKey('client-notification-prompt'),
      // The Update window's 8 px corner (user request, 0.0.616).
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius * 2),
      ),
      title: Text(
        l.clientNotification_promptTitle,
        textAlign: TextAlign.center,
      ),
      content: Text(
        l.clientNotification_promptBody,
        textAlign: TextAlign.justify,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        // The buttons first, then the remember choice under them (user
        // request, 0.0.618). 16 px is double the actions' default 8 px gap.
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // The Exit App window's action size; No is the red half.
                FilledButton(
                  key: const ValueKey('client-notification-no'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(112, 48),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  onPressed: () => _close(send: false),
                  child: Text(l.sharedActions_no),
                ),
                const SizedBox(width: AppSpacing.md),
                FilledButton(
                  key: const ValueKey('client-notification-yes'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(112, 48),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  onPressed: () => _close(send: true),
                  child: Text(l.sharedActions_yes),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              key: const ValueKey('client-notification-remember'),
              onTap: () => setState(() => _remember = !_remember),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _remember,
                    onChanged: (value) =>
                        setState(() => _remember = value ?? false),
                  ),
                  Text(l.clientNotification_rememberChoice),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
