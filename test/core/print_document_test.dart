/// Tests for the pure print-document model (Task 14 Phase 1).
///
/// The model is where a printed page's wording, field order and layout
/// decisions live, so it is tested without a plugin, a widget tree or a
/// database. The one rule that matters most here is the script decision:
/// `pdf` 3.13.0 cannot shape Bengali, so a document containing Bengali must be
/// flagged for the raster path rather than silently going native.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:legal_case_diary/core/l10n/app_translations.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/print/print_document.dart';
import 'package:legal_case_diary/core/utils/date_utils.dart';

AppTranslations _t(String language) =>
    AppTranslations(lookupAppLocalizations(Locale(language)));

PrintCaseRow _row({
  String caseNumber = '110/2021',
  // Dash-terminated, as the pre-seeded case-type labels are.
  String caseType = 'Civil Suit-',
  String petitioner = 'Karim Rahman',
  String respondent = 'State',
  String court = 'Dhaka Judge Court',
  String petitionerCounsel = 'Adv. A. Hossain',
  String respondentCounsel = 'Adv. B. Islam',
  String onBehalf = 'Petitioner',
  String step = 'Evidence',
  String note = 'Adjourned for cross-examination',
  String date = '19/09/2026',
}) => PrintCaseRow(
  caseNumber: caseNumber,
  caseType: caseType,
  petitioner: petitioner,
  respondent: respondent,
  court: court,
  petitionerCounsel: petitionerCounsel,
  respondentCounsel: respondentCounsel,
  onBehalf: onBehalf,
  step: step,
  note: note,
  date: date,
);

PrintDocument _flatDocument(
  AppTranslations translations, {
  List<PrintCaseRow>? rows,
  List<PrintField> meta = const [],
}) {
  final l = translations.raw;
  var serial = 0;
  return buildRuledTableDocument(
    translations: translations,
    title: l.nav_allCases,
    brandTitle: l.appTitle,
    columns: [
      const PrintTableColumn(label: 'SL', widthCm: 0.69),
      const PrintTableColumn(label: 'Prev. Date', widthCm: 1.83),
      const PrintTableColumn(label: 'Case No.', widthCm: 2.51),
      const PrintTableColumn(label: 'Petitioner', widthCm: 3.68),
      const PrintTableColumn(label: 'Respondent', widthCm: 3.68),
      const PrintTableColumn(label: 'On Behalf', widthCm: 2.22),
      const PrintTableColumn(label: 'Step', widthCm: 3.18),
      const PrintTableColumn(label: 'Next Date', widthCm: 1.83),
    ],
    rows: [
      for (final row in rows ?? [_row()])
        PrintTableRow.data(<String>[
          AppDateUtils.formatDigits(
            ++serial,
            l.localeName,
            grouping: false,
          ),
          row.previousDate,
          caseTypeAndCaseNumber(row.caseType, row.caseNumber),
          row.petitioner,
          row.respondent,
          row.onBehalf,
          row.step,
          row.date,
        ]),
    ],
    meta: meta,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  group('canonical case-list table', () {
    test('prints the eight fixed columns in the sample order', () {
      final document = _flatDocument(_t('en'));
      expect(document.isTable, isTrue);
      expect(
        document.columns!.map((column) => column.label),
        [
          'SL',
          'Prev. Date',
          'Case No.',
          'Petitioner',
          'Respondent',
          'On Behalf',
          'Step',
          'Next Date',
        ],
      );
      // The sample's fixed widths, in centimetres.
      expect(
        document.columns!.map((column) => column.widthCm),
        [0.69, 1.83, 2.51, 3.68, 3.68, 2.22, 3.18, 1.83],
      );
    });

    test('a data row carries every column, in order', () {
      final row = _flatDocument(_t('en')).tableRows.single;
      expect(row.kind, PrintTableRowKind.data);
      expect(row.cells, [
        '1',
        '', // Prev. Date — this fixture has no history
        'Civil Suit- 110/2021',
        'Karim Rahman',
        'State',
        'Petitioner',
        'Evidence',
        '19/09/2026',
      ]);
    });

    test('leads with the case type, then the number, with nothing between', () {
      // The type's own trailing dash is the only dash on the cell.
      expect(
        _flatDocument(_t('en')).tableRows.single.cells[2],
        'Civil Suit- 110/2021',
      );
      expect(
        _flatDocument(
          _t('en'),
          rows: [_row(caseType: 'Misc')],
        ).tableRows.single.cells[2],
        'Misc 110/2021',
      );
      // A case with no type yet prints its number alone, never a bare dash.
      expect(
        _flatDocument(
          _t('en'),
          rows: [_row(caseType: '')],
        ).tableRows.single.cells[2],
        '110/2021',
      );
    });

    test('a court heading is a spanning row above its cases', () {
      final translations = _t('en');
      final document = buildRuledTableDocument(
        translations: translations,
        title: translations.raw.nav_dailyCauseList,
        brandTitle: translations.raw.appTitle,
        columns: const [
          PrintTableColumn(label: 'SL', widthCm: 0.69),
        ],
        rows: const [
          PrintTableRow.court(['Dhaka Judge Court']),
          PrintTableRow.data(['1']),
          PrintTableRow.data(['2']),
        ],
      );

      expect(document.tableRows.first.kind, PrintTableRowKind.court);
      expect(document.tableRows.first.cells, ['Dhaka Judge Court']);
      expect(document.entryCount, 2, reason: 'only data rows count');
    });

    test('the serial follows the active language', () {
      expect(_flatDocument(_t('en')).tableRows.first.cells.first, '1');
      expect(_flatDocument(_t('bn')).tableRows.first.cells.first, '১');
    });

    test('prints no "Printed on" footer, keeping only the page counter', () {
      final document = _flatDocument(_t('en'));
      expect(document.footer, isEmpty);
      expect(document.pageLabel(1, 2), isNotEmpty);
    });
  });

  group('case detail sheet', () {
    PrintDocument detailDocument({
      String caseType = 'First Appeal-',
      String court = 'Dhaka Judge Court',
    }) => buildCaseDetailDocument(
      translations: _t('en'),
      showAllHistory: true,
      detail: PrintCaseDetail(
        caseNumber: '34/26',
        caseType: caseType,
        court: court,
        judges: 'Md. Justice A. Rahman',
        nextDate: '19/10/2026',
        step: 'Evidence',
        result: 'Adjourned',
        petitioner: 'Karim Rahman',
        history: const [
          PrintHistoryEntry(date: '19/09/2026', step: 'Evidence'),
        ],
      ),
    );

    test('leads with the case type, then the number, then the court', () {
      // The type carries its own dash; the print adds none.
      expect(
        detailDocument(caseType: 'First Appeal-').title,
        'First Appeal- 34/26 · Dhaka Judge Court',
      );
      expect(
        detailDocument(caseType: 'First Appeal').title,
        'First Appeal 34/26 · Dhaka Judge Court',
      );
      expect(detailDocument(caseType: '').title, '34/26 · Dhaka Judge Court');
    });

    test('no section repeats the case number under its heading', () {
      final l = _t('en').raw;
      final document = detailDocument();
      final sections = document.groups.where(
        (group) => group.heading != l.caseDetailsScreen_caseHistory,
      );

      expect(sections, isNotEmpty);
      for (final entry in sections.expand((group) => group.entries)) {
        expect(entry.heading, '');
        expect(entry.heading, isNot(document.title));
      }
      // Nor as labelled rows: only the header line names the type, the number
      // and the court, so the section starts at the judges.
      final labels = sections
          .expand((group) => group.entries)
          .expand((entry) => entry.fields)
          .map((field) => field.label)
          .toList();
      expect(labels, isNot(contains(l.addEditCaseSheet_caseNumber)));
      expect(labels, isNot(contains(l.allCasesScreen_caseType)));
      expect(labels, isNot(contains(l.addEditCaseSheet_nameOfCourt)));
      expect(labels.first, l.addEditCaseSheet_honorableJudges);
      // History rows keep their date — that heading says something.
      final history = document.groups.firstWhere(
        (group) => group.heading == l.caseDetailsScreen_caseHistory,
      );
      expect(history.entries.single.heading, '19/09/2026');
    });

  });

  group('localized document furniture', () {
    test('the page counter follows the active language', () {
      expect(_flatDocument(_t('bn')).pageLabel(2, 3), 'পৃষ্ঠা ২ / ৩');
      expect(_flatDocument(_t('en')).pageLabel(2, 3), 'Page 2 of 3');
      // The default, translation-free page line, used before a locale is known.
      const plain = PrintDocument(title: 't', groups: [], footer: '');
      expect(plain.pageLabel(1, 4), 'Page 1 of 4');
    });

    test('carries the screen own dataset description and header facts', () {
      final document = _flatDocument(
        _t('en'),
        meta: const [
          PrintField('Court', 'Dhaka Judge Court'),
          PrintField('Search', 'karim'),
        ],
      );

      expect(document.entryCount, 1);
      expect(document.isEmpty, isFalse);
      expect(document.meta.map((field) => field.value), ['Dhaka Judge Court', 'karim']);
      expect(document.allText, contains('karim'));
    });

    test('an empty dataset still builds a printable table document', () {
      final document = buildRuledTableDocument(
        translations: _t('en'),
        title: _t('en').raw.nav_overdueDates,
        columns: const [PrintTableColumn(label: 'SL', widthCm: 0.69)],
        rows: const [],
      );

      expect(document.isEmpty, isTrue);
      expect(document.entryCount, 0);
      expect(document.footer, isEmpty);
    });
  });

  group('script-aware renderer decision', () {
    test('a ruled table always rasterises, whatever the language', () {
      // Fixed columns, fixed row heights and cell borders must look identical
      // in both languages, so the table never takes the native text path.
      expect(_flatDocument(_t('en')).needsRaster, isTrue);
      expect(_flatDocument(_t('bn')).needsRaster, isTrue);
    });

    test('a non-table document keeps the script-aware rule', () {
      // An English, table-free document still prints as searchable text.
      final english = buildCaseDetailDocument(
        translations: _t('en'),
        detail: const PrintCaseDetail(caseNumber: '34/26'),
        showAllHistory: false,
      );
      expect(english.needsRaster, isFalse);
      expect(hasBengaliText('Case 110/2021 · Civil Suit'), isFalse);

      final bengali = buildCaseDetailDocument(
        translations: _t('bn'),
        detail: const PrintCaseDetail(caseNumber: '৩৪/২৬'),
        showAllHistory: false,
      );
      expect(bengali.needsRaster, isTrue);
      expect(hasBengaliText('দ্ধ'), isTrue);
      expect(hasBengaliText('ক্ষ'), isTrue);
    });
  });
}
