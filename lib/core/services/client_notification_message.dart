/// The automated client message sent when a hearing date changes.
///
/// Two templates are offered per account — a long letter and a short note — and
/// either can be used for WhatsApp or SMS. This file only turns one case's facts
/// into text: who the client is (the represented party), the localized case type
/// and number, the next date, the localized steps joined by `/`, the court, the
/// lawyer and the call-back number. It launches nothing and reads no settings,
/// so every wording rule is testable on its own.
library;

import '../../database/app_database.dart';
import '../l10n/app_translations.dart';
import '../print/print_document.dart';
import '../utils/date_utils.dart';
import '../utils/on_behalf_side.dart';

/// The values one message substitutes, already resolved and localized.
class ClientMessageFacts {
  /// Creates the facts for one message.
  const ClientMessageFacts({
    required this.clientName,
    required this.caseLine,
    required this.nextDateMs,
    required this.steps,
    required this.court,
    required this.lawyerName,
    this.contactNumber,
  });

  /// The represented client's name.
  final String clientName;

  /// Localized case type and the case number, e.g. `দেওয়ানি-১২৩/২৬`.
  final String caseLine;

  /// The next hearing date, epoch milliseconds.
  final int nextDateMs;

  /// Localized step names; empty for a higher-court case, which has no steps.
  final List<String> steps;

  /// The court, localized where the case uses a seeded court.
  final String court;

  /// The lawyer's own name.
  final String lawyerName;

  /// The call-back number for the long message, or null when there is none.
  final String? contactNumber;
}

/// Resolves [currentCase] into the values both templates substitute.
///
/// The client is the **represented** party, resolved through `on_behalf_id`
/// (`on_behalf_side.dart`), never guessed from the field order. The court falls
/// back to the case's stored court id when the row lookup failed, and the case
/// number is printed exactly as stored — it is the identifier the client quotes
/// — while the date and the seeded labels follow the active language.
ClientMessageFacts buildClientMessageFacts({
  required AppTranslations translations,
  required Case currentCase,
  required Court? court,
  required OnBehalf? onBehalf,
  required int nextDateMs,
  required String lawyerName,
  String? contactNumber,
}) {
  final category = court?.courtCategoryId;
  final caseType = translations.caseTypeLabel(
    currentCase.caseType,
    courtCategoryId: category,
  );
  final caseLine = caseTypeAndCaseNumber(caseType, currentCase.caseNumber);
  final steps = (translations.stepNames(
            currentCase.lastStep,
            courtCategoryId: category,
          ) ??
          '')
      .split(',')
      .map((step) => step.trim())
      .where((step) => step.isNotEmpty)
      .toList(growable: false);
  final seededCourt = court == null
      ? translations.seedLabel(currentCase.courtId)
      : translations.seedLabel(court.id, fallbackEn: court.courtName);
  final resolvedCourt = seededCourt.trim().isEmpty
      ? currentCase.courtId
      : seededCourt;
  final contact = contactNumber?.trim();

  return ClientMessageFacts(
    clientName: representedClientName(currentCase, onBehalf).trim(),
    caseLine: caseLine,
    nextDateMs: nextDateMs,
    steps: steps,
    court: resolvedCourt,
    lawyerName: lawyerName.trim(),
    contactNumber: contact == null || contact.isEmpty ? null : contact,
  );
}

/// Builds the finished message with the selected template.
///
/// [long] picks the letter rather than the note. The steps clause and the
/// call-back line are separate localized fragments, so a case with no steps (the
/// higher-court divisions) drops the clause cleanly instead of leaving a bare
/// "for" or an empty pair of brackets; the note never carries a call-back line.
String buildClientNotificationMessage({
  required AppTranslations translations,
  required ClientMessageFacts facts,
  required bool long,
}) {
  final l = translations.raw;
  final stepsText = facts.steps.join('/');
  final stepsClause = facts.steps.isEmpty
      ? ''
      : long
      ? l.clientNotification_longStepsClause(stepsText)
      : l.clientNotification_shortStepsClause(stepsText);
  final nextDate = AppDateUtils.formatDateDDMMYYYY(
    facts.nextDateMs,
    locale: l.localeName,
  );
  final contact = facts.contactNumber;
  final contactLine = long && contact != null
      ? l.clientNotification_contactLine(contact)
      : '';

  return long
      ? l.clientNotification_long(
          facts.clientName,
          facts.caseLine,
          nextDate,
          stepsClause,
          facts.court,
          facts.lawyerName,
          contactLine,
        )
      : l.clientNotification_short(
          facts.caseLine,
          nextDate,
          stepsClause,
          facts.court,
        );
}
