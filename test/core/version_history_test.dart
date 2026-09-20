/// Guards the shape of `docs/version_history.md`.
///
/// Hand-editing the log produced the same two mistakes twice: the new entry was
/// inserted above the previous one under `## Current Version` instead of
/// *replacing* it, and a long entry was written after a blank line at the end of
/// `## Version History Log` instead of one short line appended to the last
/// entry. `tool/record_version.py` records an entry the right way; this test is
/// the check that fails the suite when the file was hand-edited instead, so the
/// rule no longer depends on anyone remembering it.
///
/// The length limit applies to the newest entry only: the file's earlier
/// entries were already written long before the rule existed, and rewriting
/// history is not this test's job.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The longest the newest entry may be ("short but precise").
const int maxEntryLength = 300;

/// `Version: X.Y.Z - summary`, the one format the protocol allows.
final RegExp _entryPattern = RegExp(r'^Version: (\d+)\.(\d+)\.(\d+) - (\S.*)$');

List<String> _lines() => File('docs/version_history.md').readAsLinesSync();

/// Index of the first line whose trimmed text is one of [names].
int _heading(List<String> lines, List<String> names) {
  final index = lines.indexWhere((line) => names.contains(line.trim()));
  if (index < 0) {
    fail('docs/version_history.md has no "${names.first}" heading');
  }
  return index;
}

/// Index of the `## Current Version` heading.
int _currentHeading(List<String> lines) =>
    _heading(lines, ['## Current Version:', '## Current Version']);

/// Index of the `## Version History Log` heading.
int _historyHeading(List<String> lines) => _heading(lines, [
  '## Version History Log:',
  '## Version History Log',
  '## Version History:',
]);

/// `(lineIndex, entry)` for every version entry in [lines] from [from] on.
List<(int, String)> _entries(List<String> lines, int from) => [
  for (var index = from; index < lines.length; index++)
    if (_entryPattern.hasMatch(lines[index])) (index, lines[index]),
];

/// `(major, minor, patch)` of an entry line.
List<int> _version(String entry) {
  final match = _entryPattern.firstMatch(entry);
  return [
    for (var group = 1; group <= 3; group++) int.parse(match!.group(group)!),
  ];
}

void main() {
  test(
    'Current Version holds exactly one entry, directly under the heading',
    () {
      final lines = _lines();
      final current = _currentHeading(lines);
      final history = _historyHeading(lines);

      final entries = _entries(lines, current + 1);
      final holder = [
        for (final (index, _) in entries)
          if (index < history) index,
      ];

      expect(
        holder,
        hasLength(1),
        reason:
            'The Current Version section must hold exactly one entry - the '
            'newest. A new entry replaces the previous one; it is never '
            'inserted above it.',
      );
      expect(
        holder.single,
        current + 1,
        reason: 'The entry belongs on the line directly under the heading.',
      );
    },
  );

  test('the current entry is the last line of the history log, verbatim', () {
    final lines = _lines();
    final history = _historyHeading(lines);
    final entries = _entries(lines, history + 1);
    final currentEntry = _entries(lines, _currentHeading(lines) + 1).first.$2;

    expect(entries, isNotEmpty, reason: 'The history log holds no entries.');
    expect(
      entries.last.$2,
      currentEntry,
      reason:
          'The same line must be appended to the end of the history log, '
          'character for character.',
    );
    expect(
      entries.last.$1,
      lines.length - 1,
      reason: 'The newest entry is the file\'s last line.',
    );
  });

  test('no stray or blank line sits between two entries', () {
    final lines = _lines();
    final entries = _entries(lines, _historyHeading(lines) + 1);

    for (var index = 1; index < entries.length; index++) {
      final previous = entries[index - 1].$1;
      final next = entries[index].$1;
      expect(
        next,
        previous + 1,
        reason:
            'A stray or blank line (${lines[previous + 1]}) sits between the '
            'entries on lines ${previous + 1} and ${next + 1}: the new entry '
            'is appended directly under the last one.',
      );
    }
  });

  test('the newest entry is one short, precise line', () {
    final lines = _lines();
    final entry = _entries(lines, _currentHeading(lines) + 1).first.$2;

    expect(entry, matches(_entryPattern));
    expect(
      entry.length,
      lessThanOrEqualTo(maxEntryLength),
      reason:
          'The newest entry is ${entry.length} characters. Keep it to one '
          'short, precise sentence ($maxEntryLength or fewer); the long '
          'account belongs in docs/currentlyWorking.md.',
    );
  });

  test('the newest version is greater than the entry above it', () {
    final lines = _lines();
    final entries = _entries(lines, _historyHeading(lines) + 1);
    expect(entries.length, greaterThan(1));

    final previous = _version(entries[entries.length - 2].$2);
    final newest = _version(entries.last.$2);

    expect(
      _compare(newest, previous),
      greaterThan(0),
      reason: 'The version bumps sequentially, never backwards.',
    );
  });
}

/// Compares two `[major, minor, patch]` versions.
int _compare(List<int> a, List<int> b) {
  for (var index = 0; index < 3; index++) {
    if (a[index] != b[index]) return a[index].compareTo(b[index]);
  }
  return 0;
}
