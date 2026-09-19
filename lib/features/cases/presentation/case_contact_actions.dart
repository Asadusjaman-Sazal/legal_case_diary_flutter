/// The Phone and Message actions shared by every case surface (Task 14 Phase 4).
///
/// Before this, seven screens each carried their own copy of "show a chooser,
/// then launch WhatsApp or the dialer". One implementation now owns the rules,
/// so they cannot drift:
///
/// * the party to contact is the **represented** party, resolved through
///   `on_behalf_id` — never guessed from the field order;
/// * a case stores a single `party_phone`, which is the represented client's
///   number, so the other side is shown **disabled with a reason** instead of
///   silently reusing the client's number (plan §9 and the Addendum);
/// * the pre-filled text is the ARB `messageTemplate_*` template with the case
///   number, next date, court and lawyer name substituted;
/// * no undocumented URL scheme is used. WhatsApp publishes no call scheme, so
///   the sheet offers WhatsApp **chat** — where a call can be started — and the
///   standard dialer as the explicit fallbacks.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_translations.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/services/contact_launcher.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/on_behalf_side.dart';
import '../../../database/app_database.dart';

/// The party-side rule lives in `core/utils/on_behalf_side.dart`, so the Case
/// Detail party card, this chooser and the scoped case search cannot disagree
/// about who the client is.

/// Who the Phone/Message buttons reach on one case, and why not.
class ContactTargets {
  /// Creates resolved targets.
  const ContactTargets({
    required this.partyLabel,
    required this.clientName,
    required this.otherPartyLabel,
    required this.otherName,
    required this.number,
  });

  /// Localized label of the represented side (`Petitioner`/`Respondent`).
  final String partyLabel;

  /// The represented client's name.
  final String clientName;

  /// Localized label of the other side.
  final String otherPartyLabel;

  /// The other side's name.
  final String otherName;

  /// The launchable number, or `null` when the case has none.
  final String? number;

  /// Whether an action can actually be launched.
  bool get hasNumber => number != null;
}

/// Resolves the represented party and the number its contact actions use.
///
/// `cases.party_phone` holds the represented client's number, which is why only
/// that side is actionable; an unresolved or custom role falls back to the
/// petitioner, exactly as the case detail screen labels its parties.
ContactTargets resolveContactTargets({
  required Case currentCase,
  required OnBehalf? onBehalf,
  required AppTranslations translations,
}) {
  final l = translations.raw;
  // An unresolved (custom or missing) role falls back to the petitioner, which
  // is the side the app labels first everywhere else.
  final side = representedSideOf(onBehalf) ?? PartySide.petitioner;
  final isPetitioner = side == PartySide.petitioner;
  final client = representedClientName(currentCase, onBehalf);

  return ContactTargets(
    partyLabel: isPetitioner
        ? l.caseDetailsScreen_petitioner
        : l.caseDetailsScreen_respondent,
    clientName: client,
    otherPartyLabel: isPetitioner
        ? l.caseDetailsScreen_respondent
        : l.caseDetailsScreen_petitioner,
    otherName: isPetitioner ? currentCase.respondent : currentCase.petitioner,
    number: normalizeLaunchNumber(currentCase.partyPhone),
  );
}

/// The pre-filled message: the ARB template with this case's own facts.
///
/// [clientName] is the **represented** client (resolved through `on_behalf_id`),
/// not simply the petitioner, so a firm acting for the respondent sends the
/// respondent's name. The court falls back to the case's stored court text when
/// the id is not pre-seeded, and the lawyer's name comes from the Profile
/// screen — the same two values the printed sheet uses.
String buildContactMessage({
  required AppLocalizations l,
  required Case currentCase,
  required String clientName,
  required String courtLabel,
  required String lawyerName,
  required bool message,
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

  return message
      ? l.messageTemplate_clientSms(
          client,
          currentCase.caseNumber,
          nextDate,
          court,
          lawyer,
        )
      : l.messageTemplate_clientWhatsApp(
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
    translations: translations,
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
  final body = buildContactMessage(
    l: l,
    currentCase: currentCase,
    clientName: targets.clientName,
    courtLabel: courtLabel,
    lawyerName: lawyerName,
    message: message,
  );
  final uri = switch (route) {
    _ContactRoute.standard => message ? smsUri(number, body) : telUri(number),
    _ContactRoute.whatsApp => whatsAppUri(whatsAppNumber(number)!, body),
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

/// The chooser: both parties first (the represented one actionable), then the
/// two documented routes.
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
      title: Text(
        l.casesContact_openWith,
        key: ValueKey('$prefix-title'),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PartyRow(
            key: ValueKey('$prefix-party-represented'),
            label: targets.partyLabel,
            name: targets.clientName,
            enabled: targets.hasNumber,
            note: targets.hasNumber
                ? targets.number!
                : l.casesContact_noNumber(targets.partyLabel),
          ),
          // The other side is shown but disabled, with the reason, so the user
          // can see the app is not offering the client's number twice.
          _PartyRow(
            key: ValueKey('$prefix-party-other'),
            label: targets.otherPartyLabel,
            name: targets.otherName,
            enabled: false,
            note: l.casesContact_noNumber(targets.otherPartyLabel),
          ),
          const Divider(height: 24),
          ListTile(
            key: ValueKey('$prefix-whatsapp'),
            leading: const Icon(Icons.chat_outlined),
            title: Text(l.casesContact_whatsapp),
            subtitle: message ? null : Text(l.casesContact_whatsappNote),
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

/// One party row in the chooser: label, name, and its number or the reason it
/// cannot be reached.
class _PartyRow extends StatelessWidget {
  const _PartyRow({
    super.key,
    required this.label,
    required this.name,
    required this.enabled,
    required this.note,
  });

  final String label;
  final String name;
  final bool enabled;
  final String note;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      enabled: enabled,
      leading: Icon(
        enabled ? Icons.person_outline : Icons.person_off_outlined,
        color: enabled ? AppColors.secondary : AppColors.outline,
      ),
      title: Text('$label · $name'),
      subtitle: Text(note),
    );
  }
}
