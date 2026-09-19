/// Native PDF path tests for Task 14 Phase 1.
///
/// Two things have to hold before the native layout may be considered
/// release-ready for text: the bundled fonts must actually load into the `pdf`
/// package, and the characters drawn must round-trip out of the finished file
/// (the file's own `ToUnicode` map is what a reader copies/search uses).
///
/// What these tests deliberately do *not* claim is correct Bengali shaping —
/// `pdf` 3.13.0 ships no Indic shaper (its only shaping table is
/// `arabic.dart`), so Bengali is routed to the raster path instead. The
/// round-trip check is what makes that failure visible: the text is present and
/// extractable, yet the glyph run would be wrong, which is exactly why
/// [PrintDocument.needsRaster] must gate this path.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';

import 'package:legal_case_diary/core/l10n/app_translations.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/print/pdf_native_renderer.dart';
import 'package:legal_case_diary/core/print/print_document.dart';

/// Reads the bundled font files straight from disk: the test host has the
/// repository, and `rootBundle` is not guaranteed to answer under `flutter test`.
Future<ByteData> _diskFontLoader(String assetPath) async =>
    ByteData.sublistView(File(assetPath).readAsBytesSync());

AppTranslations _t(String language) =>
    AppTranslations(lookupAppLocalizations(Locale(language)));

/// Bengali fixtures covering vowels, diacritics, a conjunct, a reph and digits.
const List<String> _bengaliFixtures = [
  'আবেদনকারী মোঃ করিম',
  'ক্ষমা প্রার্থনা',
  'ধারা ৩০২ দণ্ডবিধি',
];

/// A mixed Bengali/English line, the case the theme's font fallback exists for.
const String _mixedFixture = 'Civil Suit 110/2021 · ধারা ৩০২';

/// Every `<code> <rune>` pair of every `ToUnicode` CMap in [bytes], in file
/// order: the pdf package writes one `beginbfchar` block per embedded font.
List<List<({int code, int rune})>> _cmapBlocks(Uint8List bytes) {
  final text = latin1.decode(bytes);
  final blocks = <List<({int code, int rune})>>[];
  final blockPattern = RegExp(r'beginbfchar\r?\n(.*?)endbfchar', dotAll: true);
  final pairPattern = RegExp(r'<([0-9A-F]{4})> <([0-9A-F]{4})>');
  for (final block in blockPattern.allMatches(text)) {
    blocks.add([
      for (final pair in pairPattern.allMatches(block.group(1)!))
        (
          code: int.parse(pair.group(1)!, radix: 16),
          rune: int.parse(pair.group(2)!, radix: 16),
        ),
    ]);
  }
  return blocks;
}

bool _isBengali(int rune) => rune >= 0x0980 && rune <= 0x09FF;

/// First-use order of the code points, so a repeated rune is not counted twice
/// (the CMap only records the first glyph a rune is drawn as).
List<int> _firstUses(Iterable<String> texts) {
  final seen = <int>{};
  final ordered = <int>[];
  for (final text in texts) {
    for (final rune in text.runes) {
      if (seen.add(rune)) ordered.add(rune);
    }
  }
  return ordered;
}

/// A document whose Bengali content is exactly [bengaliValues], in draw order.
PrintDocument _document({
  required String title,
  required List<String> values,
}) => PrintDocument(
  title: title,
  footer: 'Printed on 19/09/2026',
  groups: [
    PrintGroup(
      heading: 'Dhaka Judge Court',
      entries: [
        PrintEntry(
          heading: values.first,
          fields: [
            for (final value in values.skip(1))
              PrintField('Petitioner', value),
          ],
        ),
      ],
    ),
  ],
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  test('every bundled print font loads into the pdf package', () async {
    final fonts = await PrintFonts.load(loader: _diskFontLoader);

    for (final font in [fonts.body, fonts.headline, fonts.data, fonts.bengali]) {
      expect(font, isNotNull);
    }
  });

  test('Tiro Bangla has a glyph for every character of the fixtures', () async {
    final bytes = await _diskFontLoader(PrintFonts.bengaliAsset);
    final ttf = TtfParser(bytes);

    for (final fixture in [..._bengaliFixtures, _mixedFixture]) {
      for (final rune in fixture.runes) {
        if (!_isBengali(rune)) continue;
        expect(
          ttf.charToGlyphIndexMap.containsKey(rune),
          isTrue,
          reason: 'U+${rune.toRadixString(16)} missing from Tiro Bangla',
        );
      }
    }
  });

  test('the printed Bengali characters round-trip out of the PDF', () async {
    final document = _document(
      title: 'Daily Cause List',
      values: [..._bengaliFixtures, _mixedFixture],
    );
    final bytes = await PdfNativeRenderer(
      fontLoader: _diskFontLoader,
    ).render(document, compress: false);

    final blocks = _cmapBlocks(bytes);
    final bengaliBlocks = blocks
        .where((block) => block.any((pair) => _isBengali(pair.rune)))
        .toList();

    // One embedded Bengali font, and the file maps its glyphs back to text.
    expect(bengaliBlocks, hasLength(1));
    final carried = bengaliBlocks.single
        .map((pair) => pair.rune)
        .where(_isBengali)
        .toList();
    // Spaces and Latin letters of a mixed line are drawn with Inter, so only
    // the Bengali code points belong to this font's map.
    expect(
      carried,
      _firstUses([..._bengaliFixtures, _mixedFixture]).where(_isBengali),
    );

    for (final rune in _bengaliRunes(_bengaliFixtures.join())) {
      expect(carried, contains(rune));
    }
  });

  test('the embedded Bengali font is Tiro Bangla, not a substitution', () async {
    final bytes = await PdfNativeRenderer(
      fontLoader: _diskFontLoader,
    ).render(_document(title: 'Daily Cause List', values: _bengaliFixtures));

    expect(latin1.decode(bytes), contains('TiroBangla-Regular'));
  });

  test('pages break on measured height, not on a fixed row count', () async {
    final renderer = PdfNativeRenderer(fontLoader: _diskFontLoader);

    Future<int> pageCount(int rows) async {
      final bytes = await renderer.render(
        buildCaseListDocument(
          translations: _t('en'),
          title: _t('en').raw.nav_allCases,
          dateColumnLabel: _t('en').raw.caseCard_nextDate,
          groups: [
            PrintCaseGroup(
              rows: [
                for (var i = 0; i < rows; i++)
                  PrintCaseRow(
                    caseNumber: '${100 + i}/2021',
                    caseType: 'Civil Suit',
                    petitioner: 'Karim Rahman',
                    respondent: 'State',
                    court: 'Dhaka Judge Court',
                    petitionerCounsel: 'Adv. A. Hossain',
                    step: 'Evidence',
                    note: 'Adjourned for cross-examination',
                    date: '19/09/2026',
                  ),
              ],
            ),
          ],
          printedAtEpochMs: 1_758_259_200_000,
        ),
        compress: false,
      );
      // The page tree states its own page count.
      final match = RegExp(r'/Count (\d+)').firstMatch(latin1.decode(bytes));
      expect(match, isNotNull, reason: 'no page tree in the output');
      return int.parse(match!.group(1)!);
    }

    expect(await pageCount(3), 1);
    expect(await pageCount(200), greaterThan(1));
  });

  test('the case detail sheet draws no rules; the list layout keeps them',
      () async {
    final renderer = PdfNativeRenderer(fontLoader: _diskFontLoader);

    /// The rule tints of the file, in uncompressed form: grey400 is the header
    /// divider and grey300 the hairline closing an entry. Nothing else this
    /// renderer draws uses either (text and the two other greys are grey600 and
    /// grey700), so their presence *is* the rules — stroked, hence `RG`.
    Future<Set<String>> ruleTints(PrintDocument document) async {
      final bytes = await renderer.render(document, compress: false);
      return RegExp(
        r'0\.74118 0\.74118 0\.74118 (?:rg|RG)'
        r'|0\.87843 0\.87843 0\.87843 (?:rg|RG)',
      ).allMatches(latin1.decode(bytes)).map((match) => match.group(0)!).toSet();
    }

    expect(
      await ruleTints(_document(title: 'Active Cases', values: ['Karim Rahman'])),
      isNotEmpty,
      reason: 'the case list separates its entries with a rule',
    );
    expect(
      await ruleTints(
        buildCaseDetailDocument(
          translations: _t('en'),
          showAllHistory: true,
          printedAtEpochMs: 1_758_259_200_000,
          detail: const PrintCaseDetail(
            caseNumber: '34/26',
            caseType: 'First Appeal',
            court: 'Dhaka Judge Court',
            petitioner: 'Karim Rahman',
            history: [
              PrintHistoryEntry(date: '19/09/2026', step: 'Evidence'),
            ],
          ),
        ),
      ),
      isEmpty,
      reason: 'the detail sheet must print no underline under any of its lines',
    );
  });

  test('a Bengali document is flagged away from this path', () {
    expect(
      _document(title: 'Daily Cause List', values: _bengaliFixtures).needsRaster,
      isTrue,
    );
    expect(
      _document(title: 'Active Cases', values: ['Karim Rahman']).needsRaster,
      isFalse,
    );
  });
}

/// The Bengali code points of [text], used to check the extracted set.
Iterable<int> _bengaliRunes(String text) => text.runes.where(_isBengali);
