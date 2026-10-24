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
/// A remembered answer wins: yes sends, no does nothing, whatever the Ask
/// setting says (changing Ask clears the remembered answer). With no memory,
/// Ask off means send, Ask on means ask.
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
  switch (settings.automatedNotificationRememberedAnswer) {
    case clientNotificationRememberedYes:
      return ClientNotificationDecision.send;
    case clientNotificationRememberedNo:
      return ClientNotificationDecision.none;
  }
  return settings.automatedNotificationAskBeforeSending
      ? ClientNotificationDecision.ask
      : ClientNotificationDecision.send;
}
