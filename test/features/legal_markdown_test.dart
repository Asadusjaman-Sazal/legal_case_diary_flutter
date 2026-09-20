/// Tests for the Markdown reader that renders the bundled legal documents.
///
/// The parser is pure Dart, so these run without a widget tree. They pin the
/// subset the two documents actually use — and, importantly, that the reader
/// never throws on input it does not recognise, because a legal document that
/// fails to render is worse than one that renders plainly.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/features/settings/presentation/legal/markdown_document.dart';

List<MarkdownBlock> parse(String source) => parseMarkdown(source);

void main() {
  group('headings', () {
    test('reads levels one to three and keeps the text', () {
      final blocks = parse('# One\n\n## Two\n\n### Three');

      expect(blocks, hasLength(3));
      expect((blocks[0] as MarkdownHeading).level, 1);
      expect((blocks[0] as MarkdownHeading).spans.single.text, 'One');
      expect((blocks[1] as MarkdownHeading).level, 2);
      expect((blocks[2] as MarkdownHeading).level, 3);
    });

    test('keeps emphasis inside a heading', () {
      final heading = parse('## সেবার শর্তাবলি — **গুরুত্বপূর্ণ**').single;
      final spans = (heading as MarkdownHeading).spans;

      expect(spans.map((s) => s.text).join(), 'সেবার শর্তাবলি — গুরুত্বপূর্ণ');
      expect(spans.where((s) => s.bold).single.text, 'গুরুত্বপূর্ণ');
    });
  });

  group('paragraphs', () {
    test('joins wrapped lines into one paragraph', () {
      final blocks = parse(
        'The app is developed by **Asadusjaman Sazal**, an individual\n'
        'developer based in Narayanganj, Bangladesh.',
      );

      expect(blocks, hasLength(1));
      final spans = (blocks.single as MarkdownParagraph).spans;
      expect(
        spans.map((s) => s.text).join(),
        'The app is developed by Asadusjaman Sazal, an individual developer '
        'based in Narayanganj, Bangladesh.',
      );
    });

    test('a blank line starts a new paragraph', () {
      final blocks = parse('First.\n\nSecond.');

      expect(blocks, hasLength(2));
      expect((blocks[0] as MarkdownParagraph).spans.single.text, 'First.');
      expect((blocks[1] as MarkdownParagraph).spans.single.text, 'Second.');
    });
  });

  group('inline spans', () {
    test('separates bold, italic and code', () {
      final spans = parseInline(
        'Write to **adv.asadusjaman@gmail.com** using *your* own `TrxID`.',
      );

      expect(spans.first.text, 'Write to ');
      expect(spans[1], const MarkdownSpan('adv.asadusjaman@gmail.com', bold: true));
      expect(spans[2].text, ' using ');
      expect(spans[3], const MarkdownSpan('your', italic: true));
      expect(spans[4].text, ' own ');
      expect(spans[5], const MarkdownSpan('TrxID', code: true));
      expect(spans[6].text, '.');
    });

    test('plain text comes back as a single span', () {
      expect(parseInline('No markup here'), const [
        MarkdownSpan('No markup here'),
      ]);
    });
  });

  group('bullet lists', () {
    test('one item per bullet, with wrapped continuation lines joined in', () {
      final blocks = parse(
        '- **Backups.** A backup file is written where you choose, through the\n'
        '  system file picker. The file is encrypted with AES-256-GCM.\n'
        '- **Sharing and printing.** Content goes to the app you chose.',
      );

      final bullets = blocks.single as MarkdownBullets;
      expect(bullets.items, hasLength(2));
      expect(
        bullets.items.first.map((s) => s.text).join(),
        'Backups. A backup file is written where you choose, through the system '
        'file picker. The file is encrypted with AES-256-GCM.',
      );
      expect(bullets.items.first.first.bold, isTrue);
      expect(bullets.items[1].first.text, 'Sharing and printing.');
    });

    test('a blank line ends the list', () {
      final blocks = parse('- one\n\nAfter.');

      expect(blocks, hasLength(2));
      expect(blocks[1], isA<MarkdownParagraph>());
    });
  });

  group('block quotes', () {
    test('joins the quote lines and starts a new paragraph on a blank quote line', () {
      final blocks = parse(
        '> **Status:** draft for legal review.\n'
        '> It reflects the app as built.\n'
        '>\n'
        '> Second paragraph.',
      );

      final quote = blocks.single as MarkdownQuote;
      expect(quote.paragraphs, hasLength(2));
      expect(
        quote.paragraphs.first.map((s) => s.text).join(),
        'Status: draft for legal review. It reflects the app as built.',
      );
      expect(quote.paragraphs[1].single.text, 'Second paragraph.');
    });
  });

  group('tables', () {
    test('reads a header row, its separator and the body rows', () {
      final blocks = parse(
        '| | Offline version | Online version |\n'
        '|---|---|---|\n'
        '| Where your diary is stored | Only on your device | In the cloud |\n'
        '| Account required? | **No** | Yes |',
      );

      final table = blocks.single as MarkdownTable;
      expect(table.header.map((cell) => _text(cell)), [
        '',
        'Offline version',
        'Online version',
      ]);
      expect(table.rows, hasLength(2));
      expect(_text(table.rows[0][0]), 'Where your diary is stored');
      expect(_text(table.rows[0][2]), 'In the cloud');
      expect(table.rows[1][1].single.bold, isTrue);
      expect(_text(table.rows[1][1]), 'No');
    });

    test('a table without a separator row has no header', () {
      final table = parse('| a | b |\n| c | d |').single as MarkdownTable;

      expect(table.header, isEmpty);
      expect(table.rows, hasLength(2));
    });
  });

  test('a horizontal rule is its own block', () {
    expect(parse('Above.\n\n---\n\nBelow.'), [
      isA<MarkdownParagraph>(),
      isA<MarkdownRule>(),
      isA<MarkdownParagraph>(),
    ]);
  });

  test('unrecognised syntax renders as a paragraph rather than throwing', () {
    // Ordered lists and links are deliberately unsupported: they must not
    // vanish, and they must not crash the screen that shows a legal document.
    final blocks = parse('1. First step\n2. Second step\n\n[Terms](https://example.com)');

    expect(blocks, hasLength(2));
    expect(blocks.every((b) => b is MarkdownParagraph), isTrue);
    expect(
      _text((blocks[0] as MarkdownParagraph).spans),
      '1. First step 2. Second step',
    );
  });

  test('an empty document parses to no blocks', () {
    expect(parse(''), isEmpty);
    expect(parse('\n\n  \n'), isEmpty);
  });
}

String _text(List<MarkdownSpan> spans) => spans.map((s) => s.text).join();
