/// The reject note's string rules, without a window in the way.
///
/// The admin picks canned sentences into a note they then edit by hand, and the
/// rules that make that pleasant — the first one picked stays first, one space
/// joins them, taking one back leaves no stray space, a hand edit is never
/// rewritten — are all here. They are pinned as plain function tests so a change
/// to them fails with the rule it broke rather than with a tap that went
/// somewhere unexpected.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/features/admin/presentation/reject_message_templates.dart';

void main() {
  const String wrongNumber = 'Mobile number is wrong.';
  const String wrongTrx = 'Transaction ID is wrong.';

  group('adminRejectNoteHas', () {
    test('finds a message the note carries', () {
      expect(adminRejectNoteHas('Hello $wrongNumber', wrongNumber), isTrue);
      expect(adminRejectNoteHas('Hello', wrongNumber), isFalse);
      expect(adminRejectNoteHas('', wrongNumber), isFalse);
    });
  });

  group('adminRejectNoteAdd', () {
    test('a note that is empty becomes the message', () {
      expect(adminRejectNoteAdd('', wrongNumber), wrongNumber);
      expect(adminRejectNoteAdd('   ', wrongNumber), wrongNumber);
    });

    test('a typed note stays first, the message follows after one space', () {
      expect(
        adminRejectNoteAdd('Amount did not arrive', wrongNumber),
        'Amount did not arrive $wrongNumber',
      );
    });

    test('a note with a trailing space gains no second one', () {
      expect(adminRejectNoteAdd('Amount did not arrive ', wrongNumber),
          'Amount did not arrive $wrongNumber');
    });

    test('picking the same message twice does not duplicate it', () {
      final once = adminRejectNoteAdd('Amount did not arrive', wrongNumber);
      expect(adminRejectNoteAdd(once, wrongNumber), once);
    });

    test('the order picked is the order written', () {
      final first = adminRejectNoteAdd('', wrongTrx);
      expect(adminRejectNoteAdd(first, wrongNumber), '$wrongTrx $wrongNumber');
    });

    test('an empty message changes nothing', () {
      expect(adminRejectNoteAdd('Amount did not arrive', ''), 'Amount did not arrive');
    });
  });

  group('adminRejectNoteRemove', () {
    test('takes the last message and its joining space', () {
      expect(
        adminRejectNoteRemove('Amount did not arrive $wrongNumber', wrongNumber),
        'Amount did not arrive',
      );
    });

    test('takes a first message without leaving a leading space', () {
      expect(
        adminRejectNoteRemove('$wrongTrx $wrongNumber', wrongTrx),
        wrongNumber,
      );
    });

    test('takes a middle message without leaving a double space', () {
      expect(
        adminRejectNoteRemove('$wrongTrx $wrongNumber Please try again.', wrongNumber),
        '$wrongTrx Please try again.',
      );
    });

    test('a note holding only that message becomes empty', () {
      expect(adminRejectNoteRemove(wrongNumber, wrongNumber), '');
    });

    test('a message the note does not carry changes nothing', () {
      expect(adminRejectNoteRemove('Amount did not arrive', wrongNumber),
          'Amount did not arrive');
      expect(adminRejectNoteRemove('Amount did not arrive', ''), 'Amount did not arrive');
    });
  });
}
