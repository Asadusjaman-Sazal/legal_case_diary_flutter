/// A small Markdown reader for the app's own legal documents.
///
/// The Privacy Policy and the Terms of Service are authored as Markdown in
/// `docs/legal/` and bundled as assets, so the same text serves the repository
/// and the app. Rendering them needs only the subset those documents use —
/// headings, paragraphs, emphasis, inline code, bullet lists, block quotes,
/// tables and horizontal rules — which is why this is a purpose-built reader
/// rather than a Markdown dependency: the two documents are static, the subset
/// is fixed, and every block is styled with the app's own typography tokens.
///
/// Parsing is pure Dart with no Flutter import, so it is unit-testable on its
/// own; `MarkdownDocumentView` is the widget that draws the result.
///
/// Deliberately unsupported: ordered lists, links, images, nested lists and
/// HTML. The bundled documents contain none of these, and a document that
/// starts to use one should be changed or this reader extended — silently
/// rendering them as plain text would be worse.
library;

/// A run of text within a line, carrying the emphasis it was written with.
class MarkdownSpan {
  /// The literal text, with Markdown markers removed.
  final String text;

  /// Written between `**…**`.
  final bool bold;

  /// Written between `*…*`.
  final bool italic;

  /// Written between `` `…` ``.
  final bool code;

  const MarkdownSpan(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.code = false,
  });

  @override
  String toString() {
    final marks = [
      if (bold) 'b',
      if (italic) 'i',
      if (code) 'c',
    ].join();
    return marks.isEmpty ? text : '$text[$marks]';
  }

  @override
  bool operator ==(Object other) =>
      other is MarkdownSpan &&
      other.text == text &&
      other.bold == bold &&
      other.italic == italic &&
      other.code == code;

  @override
  int get hashCode => Object.hash(text, bold, italic, code);
}

/// One block-level element of a document.
sealed class MarkdownBlock {
  const MarkdownBlock();
}

/// `# …`, `## …`, `### …` — [level] is 1, 2 or 3.
class MarkdownHeading extends MarkdownBlock {
  final int level;
  final List<MarkdownSpan> spans;

  const MarkdownHeading(this.level, this.spans);
}

/// Consecutive non-blank lines joined into one paragraph, as Markdown intends.
class MarkdownParagraph extends MarkdownBlock {
  final List<MarkdownSpan> spans;

  const MarkdownParagraph(this.spans);
}

/// `- …` items, with wrapped continuation lines joined back into their item.
class MarkdownBullets extends MarkdownBlock {
  final List<List<MarkdownSpan>> items;

  const MarkdownBullets(this.items);
}

/// A `> …` block; each blank quote line starts a new paragraph within it.
class MarkdownQuote extends MarkdownBlock {
  final List<List<MarkdownSpan>> paragraphs;

  const MarkdownQuote(this.paragraphs);
}

/// `---`.
class MarkdownRule extends MarkdownBlock {
  const MarkdownRule();
}

/// A `| … |` table. [header] is empty when the document has no header row.
class MarkdownTable extends MarkdownBlock {
  final List<List<MarkdownSpan>> header;
  final List<List<List<MarkdownSpan>>> rows;

  const MarkdownTable({required this.header, required this.rows});
}

/// Parses [source] into blocks. Never throws: anything unrecognised becomes a
/// paragraph, so a malformed document still renders rather than blanking out.
List<MarkdownBlock> parseMarkdown(String source) {
  final lines = source
      .replaceAll('\r\n', '\n')
      .split('\n')
      .map((line) => line.trimRight())
      .toList();

  final blocks = <MarkdownBlock>[];
  var index = 0;

  while (index < lines.length) {
    final line = lines[index];

    if (line.trim().isEmpty) {
      index++;
      continue;
    }

    if (line.trim() == '---') {
      blocks.add(const MarkdownRule());
      index++;
      continue;
    }

    final heading = _heading(line);
    if (heading != null) {
      blocks.add(heading);
      index++;
      continue;
    }

    if (_isQuote(line)) {
      final quote = <List<MarkdownSpan>>[];
      var current = <String>[];
      while (index < lines.length && _isQuote(lines[index])) {
        final body = _quoteBody(lines[index]);
        if (body.isEmpty) {
          if (current.isNotEmpty) {
            quote.add(parseInline(current.join(' ')));
            current = <String>[];
          }
        } else {
          current.add(body);
        }
        index++;
      }
      if (current.isNotEmpty) quote.add(parseInline(current.join(' ')));
      if (quote.isNotEmpty) blocks.add(MarkdownQuote(quote));
      continue;
    }

    if (_isTableRow(line)) {
      final tableLines = <String>[];
      while (index < lines.length && _isTableRow(lines[index])) {
        tableLines.add(lines[index]);
        index++;
      }
      blocks.add(_table(tableLines));
      continue;
    }

    if (_isBullet(line)) {
      final items = <List<MarkdownSpan>>[];
      var current = <String>[];
      while (index < lines.length) {
        final candidate = lines[index];
        if (_isBullet(candidate)) {
          if (current.isNotEmpty) items.add(parseInline(current.join(' ')));
          current = <String>[_bulletBody(candidate)];
        } else if (candidate.trim().isNotEmpty &&
            candidate.startsWith('  ') &&
            !_isQuote(candidate) &&
            !_isTableRow(candidate) &&
            _heading(candidate) == null &&
            candidate.trim() != '---') {
          // A wrapped continuation of the bullet above it.
          current.add(candidate.trim());
        } else {
          break;
        }
        index++;
      }
      if (current.isNotEmpty) items.add(parseInline(current.join(' ')));
      if (items.isNotEmpty) blocks.add(MarkdownBullets(items));
      continue;
    }

    // Anything else: a paragraph, gathered while lines keep coming and the
    // line does not begin another block.
    final paragraph = <String>[];
    while (index < lines.length) {
      final candidate = lines[index];
      final ends = candidate.trim().isEmpty ||
          candidate.trim() == '---' ||
          _heading(candidate) != null ||
          _isQuote(candidate) ||
          _isTableRow(candidate) ||
          _isBullet(candidate);
      if (ends) break;
      paragraph.add(candidate.trim());
      index++;
    }
    if (paragraph.isNotEmpty) {
      blocks.add(MarkdownParagraph(parseInline(paragraph.join(' '))));
    }
  }

  return blocks;
}

/// Splits one line into spans, resolving `**bold**`, `*italic*` and `` `code` ``.
List<MarkdownSpan> parseInline(String text) {
  final spans = <MarkdownSpan>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|`(.+?)`');
  var cursor = 0;

  for (final match in pattern.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(MarkdownSpan(text.substring(cursor, match.start)));
    }
    if (match.group(1) != null) {
      spans.add(MarkdownSpan(match.group(1)!, bold: true));
    } else if (match.group(2) != null) {
      spans.add(MarkdownSpan(match.group(2)!, italic: true));
    } else {
      spans.add(MarkdownSpan(match.group(3)!, code: true));
    }
    cursor = match.end;
  }
  if (cursor < text.length) spans.add(MarkdownSpan(text.substring(cursor)));
  return spans;
}

MarkdownHeading? _heading(String line) {
  final match = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(line);
  if (match == null) return null;
  return MarkdownHeading(match.group(1)!.length, parseInline(match.group(2)!));
}

bool _isQuote(String line) => line.startsWith('>');

String _quoteBody(String line) {
  final body = line.replaceFirst(RegExp(r'^>\s?'), '');
  return body.trim() == '' ? '' : body.trim();
}

bool _isTableRow(String line) {
  final trimmed = line.trim();
  return trimmed.startsWith('|') && trimmed.endsWith('|') && trimmed.length > 2;
}

bool _isSeparatorRow(String line) =>
    RegExp(r'^\|[\s:|-]+\|$').hasMatch(line.trim());

bool _isBullet(String line) => line.startsWith('- ') || line.startsWith('* ');

String _bulletBody(String line) => line.substring(2).trim();

/// One span list per cell of a table row.
List<List<MarkdownSpan>> _cells(String line) {
  final trimmed = line.trim();
  final inner = trimmed.substring(1, trimmed.length - 1);
  return inner.split('|').map((cell) {
    final text = cell.trim();
    return text.isEmpty ? <MarkdownSpan>[] : parseInline(text);
  }).toList();
}

MarkdownTable _table(List<String> lines) {
  final separator = lines.length > 1 && _isSeparatorRow(lines[1]);
  final header = separator ? _cells(lines.first) : const <List<MarkdownSpan>>[];
  final bodyLines = separator ? lines.skip(2) : lines;
  return MarkdownTable(
    header: header,
    rows: bodyLines.map(_cells).toList(),
  );
}
