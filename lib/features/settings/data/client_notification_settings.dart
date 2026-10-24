/// The client-notification decision: whether a changed hearing date should ask,
/// send, or do nothing.
///
/// Kept pure and separate from the widgets so the whole matrix — master toggle,
/// remembered answer, Ask setting, recipient and date change — is testable
/// without a database, a launcher or a dialog.
library;

import 'settings_repository.dart';

/// What the save flow should do for this date change.
enum ClientNotificationDecision {
  /// Nothing to do: the feature is off, the date did not change, or the case
  /// has no client number.
  none,

  /// Open the chosen messaging app with the message, without asking.
  send,

  /// Show the confirmation dialog first.
  ask,
}

/// Decides the action for a changed date from the stored settings.
///
/// The two switches are the whole rule: off does nothing; on with Ask asks; on
/// without Ask sends. Remembering an answer writes those switches (Yes turns Ask
/// off, No turns both off), so a later manual change is what brings the prompt
/// back.
ClientNotificationDecision resolveClientNotificationDecision({
  required UserSettings settings,
  required bool dateChanged,
  required bool hasRecipient,
}) {
  if (!settings.automatedNotificationEnabled ||
      !dateChanged ||
      !hasRecipient) {
    return ClientNotificationDecision.none;
  }
  return settings.automatedNotificationAskBeforeSending
      ? ClientNotificationDecision.ask
      : ClientNotificationDecision.send;
}
