/// The Phone and Message actions shared by every case surface (Task 14 Phase 4).
///
/// Before this, seven screens each carried their own copy of "show a chooser,
/// then launch WhatsApp or the dialer". One implementation now owns the rules,
/// so they cannot drift:
///
/// * the client to contact is the **represented** party, resolved through
///   `on_behalf_id` — never guessed from the field order;
/// * a case stores a single `party_phone`, which is the represented client's
///   number, and that number is the only one any route may use;
/// * the window offers the two routes and nothing else: it names no party and
///   prints no number, because the case behind it already does;
/// * the **message** sheet's routes carry the template chosen in
///   Settings → Notifications → Client Notification: WhatsApp uses its own
///   Long/Short choice, the native message its own, and both substitute the
///   represented client, the case, the next date, the steps, the court, the
///   lawyer and the call-back number. The **call** sheet's WhatsApp route
///   deliberately carries none: it opens the bare chat, which is where the user
///   reaches the client to call them;
/// * no undocumented URL scheme is used. WhatsApp publishes no call scheme, so
///   the sheet offers WhatsApp **chat** — where a call can be started — and the
///   standard dialer as the explicit fallback.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_translations.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/services/client_notification_message.dart';
import '../../../core/services/contact_launcher.dart';
import '../../../core/utils/on_behalf_side.dart';
import '../../../database/app_database.dart';
import '../../accounts_and_profile/data/profile_name_store.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/presentation/settings_viewmodel.dart';

/// The party-side rule lives in `core/utils/on_behalf_side.dart`, so the Case
/// Detail party card, this chooser and the scoped case search cannot disagree
/// about who the client is.

/// Who the Phone/Message buttons reach on one case.
class ContactTargets {
  /// Creates resolved targets.
  const ContactTargets({required this.clientName, required this.number});

  /// The represented client's name, substituted into the message text.
  final String clientName;

  /// The launchable number, or `null` when the case has none.
  final String? number;

  /// Whether an action can actually be launched.
  bool get hasNumber => number != null;
}

/// Resolves the represented client and the number its contact actions use.
///
/// `cases.party_phone` holds the represented client's number, which is why that
/// single number is the only one the routes may launch; an unresolved or custom
/// role falls back to the petitioner, exactly as the case detail screen labels
/// its parties (the rule itself lives in `on_behalf_side.dart`).
ContactTargets resolveContactTargets({
  required Case currentCase,
  required OnBehalf? onBehalf,
}) => ContactTargets(
  clientName: representedClientName(currentCase, onBehalf),
  number: normalizeLaunchNumber(currentCase.partyPhone),
);

/// Shows the Phone or Message chooser and launches the chosen route.
///
/// [message] false offers the call routes and true offers the message routes;
/// [launcher] is the platform seam, so the tests assert the URI a tap produces
/// instead of needing a device with WhatsApp installed.
///
/// Only the message routes pre-fill anything: the call sheet's WhatsApp option
/// opens the chat bare, and `tel:` has nowhere to put text anyway.
Future<void> showCaseContactActions(
  BuildContext context, {
  required WidgetRef ref,
  required Case currentCase,
  required Court? court,
  required OnBehalf? onBehalf,
  required String lawyerName,
  required bool message,
  ContactLauncher launcher = const UrlContactLauncher(),
}) async {
  final translations = context.l10n;
  final l = translations.raw;
  final targets = resolveContactTargets(
    currentCase: currentCase,
    onBehalf: onBehalf,
  );
  // The message follows the account's Client Notification settings, so the
  // Message button and the automated update cannot disagree about the wording.
  final settings = await _clientNotificationSettings(ref);
  if (!context.mounted) return;
  final profileMobile = ref.read(profileFieldsProvider).mobile;

  final route = await showDialog<_ContactRoute>(
    context: context,
    builder: (context) => _ContactDialog(targets: targets, message: message),
  );
  if (route == null || !context.mounted) return;

  final number = targets.number!;

  final contact = settings.notificationContactNumber.trim().isNotEmpty
      ? settings.notificationContactNumber.trim()
      : profileMobile.trim().isEmpty
      ? null
      : profileMobile.trim();

  /// The pre-filled text for one channel, built only where a route carries it.
  String messageFor({required bool whatsApp}) {
    final facts = buildClientMessageFacts(
      translations: translations,
      currentCase: currentCase,
      court: court,
      onBehalf: onBehalf,
      nextDateMs: currentCase.nextDate,
      lawyerName: lawyerName,
      contactNumber: contact,
    );
    final long = whatsApp
        ? settings.automatedNotificationWhatsAppTemplate ==
              clientNotificationTemplateLong
        : settings.automatedNotificationSmsTemplate ==
              clientNotificationTemplateLong;
    return buildClientNotificationMessage(
      translations: translations,
      facts: facts,
      long: long,
    );
  }

  final uri = switch (route) {
    // The call sheet reaches the client by opening their chat with nothing
    // written for them: the user is there to start a call, not to send the
    // office's message template.
    _ContactRoute.whatsApp when !message => whatsAppChatUri(
      whatsAppNumber(number)!,
    ),
    _ContactRoute.whatsApp => whatsAppUri(
      whatsAppNumber(number)!,
      messageFor(whatsApp: true),
    ),
    _ContactRoute.standard => message
        ? smsUri(number, messageFor(whatsApp: false))
        : telUri(number),
  };

  final opened = await launcher.open(uri);
  if (opened || !context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        switch (route) {
          _ContactRoute.whatsApp => l.casesContact_unableToOpenWhatsApp,
          _ContactRoute.standard =>
            message
                ? l.casesContact_unableToMessage
                : l.casesContact_unableToCall,
        },
      ),
    ),
  );
}

/// Which launch route the user picked.
enum _ContactRoute { standard, whatsApp }

/// The account's Client Notification settings; defaults apply if unreadable.
Future<UserSettings> _clientNotificationSettings(WidgetRef ref) async {
  try {
    return await ref.read(settingsViewModelProvider.future);
  } catch (_) {
    return const UserSettings();
  }
}

/// The chooser: the two documented routes, and nothing else.
///
/// No party and no number is printed here. The client's number is the case's
/// own `party_phone`, and which party that is already sits on the card or header
/// the user tapped, so repeating either in a chooser only shows the client's
/// number in a second place.
class _ContactDialog extends StatelessWidget {
  const _ContactDialog({required this.targets, required this.message});

  final ContactTargets targets;
  final bool message;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final prefix = 'case-contact-${message ? 'message' : 'call'}';

    return AlertDialog(
      key: const ValueKey('case-contact-dialog'),
      // The Update window's 8 px corner (user request, 0.0.616).
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius * 2),
      ),
      title: Text(
        l.casesContact_openWith,
        key: ValueKey('$prefix-title'),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            key: ValueKey('$prefix-whatsapp'),
            leading: const Icon(Icons.chat_outlined),
            title: Text(l.casesContact_whatsapp),
            enabled: targets.hasNumber,
            onTap: targets.hasNumber
                ? () => Navigator.of(context).pop(_ContactRoute.whatsApp)
                : null,
          ),
          ListTile(
            key: ValueKey('$prefix-native'),
            leading: Icon(message ? Icons.sms_outlined : Icons.call_outlined),
            title: Text(
              message ? l.casesContact_message : l.casesContact_phone,
            ),
            enabled: targets.hasNumber,
            onTap: targets.hasNumber
                ? () => Navigator.of(context).pop(_ContactRoute.standard)
                : null,
          ),
        ],
      ),
      actions: [
        TextButton(
          key: ValueKey('case-card-${message ? 'message' : 'call'}-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.sharedDialogs_cancel),
        ),
      ],
    );
  }
}
