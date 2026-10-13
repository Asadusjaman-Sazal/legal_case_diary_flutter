/// The pre-fill messages the Reject the Payment window offers, and the two pure
/// operations the note box uses to take them.
///
/// **Why this is a file of its own.** The window appends and removes canned
/// sentences in a text box the admin then edits freely, and that is fiddly
/// string work with rules of its own ("the one picked first stays first", "one
/// space joins them", "taking one back leaves no double space"). Keeping it out
/// of the widget makes it testable without pumping a dialog, and keeps the
/// screen about the screen.
///
/// The app's own messages are localized like every other user-facing string
/// (rule 11): sentence case, because they are prose the payer reads. The admin's
/// own saved messages live in the per-user settings row
/// (`UserSettings.adminRejectMessages`) and are appended to this list by the
/// picker, so the app's wording and the admin's are one list on screen.
library;

import '../../../core/l10n/generated/app_localizations.dart';

/// The app's own pre-fill messages, in the order the picker lists them.
List<String> adminRejectTemplates(AppLocalizations l) => <String>[
  l.adminPanel_rejectTemplateMismatch,
  l.adminPanel_rejectTemplateMobileNumber,
  l.adminPanel_rejectTemplateTransactionId,
  l.adminPanel_rejectTemplateCorrectInfo,
  l.adminPanel_rejectTemplateTwoTries,
  l.adminPanel_rejectTemplateOneTry,
  l.adminPanel_rejectTemplateBeCareful,
];

/// Whether [note] already carries [message] — which is also what ticks the
/// message's row.
///
/// **Containment, not a split.** Messages are sentences full of spaces, so the
/// note cannot be cut into segments; the question the picker asks is only
/// whether the sentence is in there. The cost of that: a message that is a
/// substring of another one (a shorter custom message inside a longer one)
/// reads as ticked while the longer one is present.
/// `ponytail: fine while the messages are whole sentences; a picker that has to
/// tell near-identical entries apart needs the ticks kept as their own list.`
bool adminRejectNoteHas(String note, String message) => note.contains(message);

/// [note] with [message] appended after one space.
///
/// The note the admin already wrote stays first, which is the order they asked
/// for: a message picked after typing is added at the end. A message already in
/// the note is left exactly as it is, so picking the same one twice cannot
/// duplicate it, and the note is trimmed first so appending never leaves a
/// stray double space.
String adminRejectNoteAdd(String note, String message) {
  if (message.isEmpty || adminRejectNoteHas(note, message)) return note;
  final trimmed = note.trim();
  return trimmed.isEmpty ? message : '$trimmed $message';
}

/// [note] with [message] and one adjoining space taken back out.
///
/// Only [message] itself goes, with the single space that joined it to the rest,
/// so "A B" minus "B" is "A" rather than "A ". Anything the admin typed by hand
/// in between is untouched — the note, not a hidden list, is the record of what
/// the payer will read.
String adminRejectNoteRemove(String note, String message) {
  if (message.isEmpty) return note;
  final at = note.indexOf(message);
  if (at < 0) return note;
  var start = at;
  var end = at + message.length;
  if (end < note.length && note[end] == ' ') {
    end++;
  } else if (start > 0 && note[start - 1] == ' ') {
    start--;
  }
  return note.replaceRange(start, end, '');
}
