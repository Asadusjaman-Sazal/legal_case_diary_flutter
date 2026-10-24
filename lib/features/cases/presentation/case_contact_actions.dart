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
/// * the **message** sheet's routes carry the ARB `messageTemplate_*` text with
///   the case number, next date, court and lawyer name substituted. The **call**
///   sheet's WhatsApp route deliberately carries none: it opens the bare chat,
///   which is where the user reaches the client to call them;
/// * no undocumented URL scheme is used. WhatsApp publishes no call scheme, so
///   the sheet offers WhatsApp **chat** — where a call can be started — and the
///   standard dialer as the explicit fallback.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_translations.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/services/contact_launcher.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/on_behalf_side.dart';
import '../../../database/app_database.dart';

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

/// The pre-filled message: the ARB template with this case's own facts.
///
/// [clientName] is the **represented** client (resolved through `on_behalf_id`),
/// not simply the petitioner, so a firm acting for the respondent sends the
/// respondent's name. The court falls back to the case's stored court text when
/// the id is not pre-seeded, and the lawyer's name comes from the Profile
/// screen — the same two values the printed sheet uses.
///
/// [whatsApp] picks the channel's own template. The two read the same today,
/// but each channel keeps its text so one can be reworded on its own.
String buildContactMessage({
  required AppLocalizations l,
  required Case currentCase,
  required String clientName,
  required String courtLabel,
  required String lawyerName,
  required bool whatsApp,
}) {
  final nextDate = currentCase.nextDate == null
      ? ''
      : AppDateUtils.formatDateDDMMYYYY(
          currentCase.nextDate!,
          locale: l.localeName,
        );
  final client = clientName.trim();
  final court = courtLabel.trim();
  final lawyer = lawyerName.trim();

  return whatsApp
      ? l.messageTemplate_clientWhatsApp(
          client,
          currentCase.caseNumber,
          nextDate,
          court,
          lawyer,
        )
      : l.messageTemplate_clientSms(
          client,
          currentCase.caseNumber,
          nextDate,
          court,
          lawyer,
        );
}

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
  // The court row is normally loaded with the case; when its lookup failed the
  // id still resolves through the seed data, so the message keeps the court.
  final courtLabel = court == null
      ? translations.seedLabel(currentCase.courtId)
      : translations.seedLabel(court.id, fallbackEn: court.courtName);

  final route = await showDialog<_ContactRoute>(
    context: context,
    builder: (context) => _ContactDialog(targets: targets, message: message),
  );
  if (route == null || !context.mounted) return;

  final number = targets.number!;

  /// The pre-filled text for one channel, built only where a route carries it.
  String messageFor({required bool whatsApp}) => buildContactMessage(
    l: l,
    currentCase: currentCase,
    clientName: targets.clientName,
    courtLabel: courtLabel,
    lawyerName: lawyerName,
    whatsApp: whatsApp,
  );

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
