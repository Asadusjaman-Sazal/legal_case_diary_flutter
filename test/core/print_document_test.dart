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

/// A fixed print day, so the footer never depends on the wall clock.
final int _printedAt = AppDateUtils.bangladeshCivilDateEpoch(2026, 9, 19);

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
  bool showSerial = false,
  List<PrintField> meta = const [],
}) => buildCaseListDocument(
  translations: translations,
  title: translations.raw.nav_allCases,
  dateColumnLabel: translations.raw.caseCard_nextDate,
  groups: [PrintCaseGroup(rows: rows ?? [_row()])],
  showSerial: showSerial,
  meta: meta,
  printedAtEpochMs: _printedAt,
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  group('canonical case-list layout', () {
    test('composes the case number, parties, counsel, step and date', () {
      final document = _flatDocument(_t('en'));
      final entry = document.groups.single.entries.single;

      expect(entry.heading, 'Civil Suit- 110/2021');
      expect(
        entry.fields.map((field) => field.label),
        [
          'Name of Court',
          'Petitioner',
          'Respondent',
          'Lead Counsel',
          'On Behalf',
          'Step',
          'Next Date',
          'Note',
        ],
      );
      expect(entry.fields[0].value, 'Dhaka Judge Court');
      expect(entry.fields[3].value, 'Adv. A. Hossain · Adv. B. Islam');
      expect(entry.fields[6].value, '19/09/2026');
    });

    test('leads with the case type, then the number, with nothing between', () {
      // The type's own trailing dash is the only dash on the line.
      expect(_flatDocument(_t('en')).groups.single.entries.single.heading,
          'Civil Suit- 110/2021');
      // A user-added type without a dash is joined by one space, not given one.
      expect(
        _flatDocument(_t('en'), rows: [_row(caseType: 'Misc')])
            .groups
            .single
            .entries
            .single
            .heading,
        'Misc 110/2021',
      );
      // A case with no type yet prints its number alone, never a bare dash.
      expect(
        _flatDocument(_t('en'), rows: [_row(caseType: '')])
            .groups
            .single
            .entries
            .single
            .heading,
        '110/2021',
      );
    });

    test('leaves blank values off the page instead of printing labels alone', () {
      final document = _flatDocument(
        _t('en'),
        rows: [
          _row(
            respondent: '',
            court: '',
            petitionerCounsel: '',
            respondentCounsel: '',
            onBehalf: '',
            step: '',
            note: '',
          ),
        ],
      );
      final entry = document.groups.single.entries.single;

      expect(
        entry.fields.map((field) => field.label),
        ['Petitioner', 'Next Date'],
      );
      expect(entry.fields.first.value, 'Karim Rahman');
    });

    test('a grouped screen names the court in its heading, not every row', () {
      final document = buildCaseListDocument(
        translations: _t('en'),
        title: _t('en').raw.nav_dailyCauseList,
        dateColumnLabel: _t('en').raw.caseCard_nextDate,
        groups: [
          PrintCaseGroup(
            heading: 'Dhaka Judge Court',
            rows: [_row(), _row(caseNumber: '111/2021')],
          ),
        ],
        printedAtEpochMs: _printedAt,
      );

      expect(document.groups.single.heading, 'Dhaka Judge Court');
      expect(document.entryCount, 2);
      for (final entry in document.groups.single.entries) {
        expect(
          entry.fields.map((field) => field.label),
          isNot(contains('Name of Court')),
        );
      }
    });

    test('prints the serial only for the screens that show one', () {
      final plain = _flatDocument(_t('en'));
      expect(plain.groups.single.entries.single.serial, '');

      final numbered = _flatDocument(
        _t('en'),
        rows: [_row(), _row(caseNumber: '111/2021')],
        showSerial: true,
      );
      expect(
        numbered.groups.single.entries.map((entry) => entry.serial),
        ['1', '2'],
      );

      final bengali = _flatDocument(
        _t('bn'),
        rows: [_row(), _row(caseNumber: '111/2021')],
        showSerial: true,
      );
      expect(
        bengali.groups.single.entries.map((entry) => entry.serial),
        ['১', '২'],
      );
    });
  });

  group('case detail sheet', () {
    PrintDocument detailDocument({
      String caseType = 'First Appeal-',
      String court = 'Dhaka Judge Court',
    }) => buildCaseDetailDocument(
      translations: _t('en'),
      showAllHistory: true,
      printedAtEpochMs: _printedAt,
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
    test('labels, footer and page counter follow the active language', () {
      final bengali = _flatDocument(_t('bn'));
      final entry = bengali.groups.single.entries.single;

      expect(entry.fields.first.label, 'আদালতের নাম');
      expect(entry.fields[1].label, 'বাদী');
      expect(bengali.footer, 'প্রিন্টের তারিখ ১৯/০৯/২০২৬');
      expect(bengali.pageLabel(2, 3), 'পৃষ্ঠা ২ / ৩');

      final english = _flatDocument(_t('en'));
      expect(english.footer, 'Printed on 19/09/2026');
      expect(english.pageLabel(2, 3), 'Page 2 of 3');
      // The default, translation-free page line, used before a locale is known.
      const plain = PrintDocument(title: 't', groups: [], footer: 'f');
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

    test('an empty dataset still builds a printable document', () {
      final document = buildCaseListDocument(
        translations: _t('en'),
        title: _t('en').raw.nav_overdueDates,
        dateColumnLabel: _t('en').raw.caseCard_previousDate,
        groups: const [PrintCaseGroup(rows: [])],
        printedAtEpochMs: _printedAt,
      );

      expect(document.isEmpty, isTrue);
      expect(document.entryCount, 0);
      expect(document.footer, 'Printed on 19/09/2026');
    });
  });

  group('script-aware renderer decision', () {
    test('an English document keeps the native text path', () {
      expect(_flatDocument(_t('en')).needsRaster, isFalse);
      expect(hasBengaliText('Case 110/2021 · Civil Suit'), isFalse);
    });

    test('a Bengali label alone puts the document on the raster path', () {
      final bengali = _flatDocument(_t('bn'));
      expect(bengali.needsRaster, isTrue);
    });

    test('Bengali case data in an English document also flips the decision', () {
      final document = _flatDocument(
        _t('en'),
        rows: [_row(petitioner: 'করিম রহমান', caseNumber: '১১০/২০২১')],
      );

      expect(document.needsRaster, isTrue);
      expect(hasBengaliText('দ্ধ'), isTrue);
      expect(hasBengaliText('ক্ষ'), isTrue);
    });
  });
}
