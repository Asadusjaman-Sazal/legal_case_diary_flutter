/// The to-do checklist of a note: one [NoteItem] per row, plus the JSON codec
/// that stores and reads them.
///
/// A to-do note keeps its rows in `notes.items` as a JSON array in display
/// order. `null` there means a plain text note, so the kind of a note is the
/// presence of this list and never a separate flag to keep in step. The same
/// rows are mirrored into `notes.body`, one text per line, so the existing
/// title+body search finds a to-do by what is on its list.
library;

import 'dart:convert';

/// One row of a to-do note.
class NoteItem {
  /// Creates a row; [done] is false until the user ticks it.
  const NoteItem({required this.text, this.done = false});

  /// The item's text, as the user typed it.
  final String text;

  /// Whether the item is ticked off.
  final bool done;

  /// Returns a copy with [text] and/or [done] replaced.
  NoteItem copyWith({String? text, bool? done}) =>
      NoteItem(text: text ?? this.text, done: done ?? this.done);

  /// JSON shape stored in `notes.items`.
  Map<String, dynamic> toJson() => <String, dynamic>{'text': text, 'done': done};

  /// Reads one stored row, tolerating a missing or mistyped field so a
  /// hand-edited or older row degrades to an empty, unticked item.
  factory NoteItem.fromJson(Map<String, dynamic> json) => NoteItem(
    text: json['text'] is String ? json['text'] as String : '',
    done: json['done'] == true,
  );

  @override
  bool operator ==(Object other) =>
      other is NoteItem && other.text == text && other.done == done;

  @override
  int get hashCode => Object.hash(text, done);

  @override
  String toString() => 'NoteItem($text, done: $done)';
}

/// Decodes the stored `notes.items`.
///
/// Returns `null` for a plain text note, and also for unreadable data — a
/// corrupt row reads as a text note rather than breaking the editor. An empty
/// array decodes to an empty list, which is how an empty to-do stays a to-do.
List<NoteItem>? decodeNoteItems(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return null;
    return <NoteItem>[
      for (final entry in decoded)
        if (entry is Map<String, dynamic>) NoteItem.fromJson(entry),
    ];
  } on FormatException {
    return null;
  }
}

/// Encodes [items] for `notes.items`; an empty list is stored as `[]`.
String encodeNoteItems(List<NoteItem> items) =>
    jsonEncode(<Map<String, dynamic>>[for (final item in items) item.toJson()]);

/// The `notes.body` mirror of [items]: one item text per line.
///
/// This is what makes a to-do findable by the existing title+body search
/// without teaching the query about JSON.
String noteItemsAsBody(List<NoteItem> items) =>
    items.map((item) => item.text).join('\n');
