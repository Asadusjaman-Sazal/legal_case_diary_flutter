/// Pure print-document model for Task 14's Print (PDF export).
///
/// Nothing here touches a plugin, a platform channel or the Drift database: the
/// model answers *what a printed page says*, so the renderers can be swapped
/// without touching the screens. Two renderers consume it — the native `pdf`
/// layout (`pdf_native_renderer.dart`) and, for Bengali content, the bounded
/// page-image renderer added in Phase 2.
///
/// Why the decision is here and not in a renderer: `pdf` 3.13.0 ships no Indic
/// shaper (its only shaping table is `arabic.dart`), so Bengali conjuncts, reph
/// and pre-base vowel signs come out visually wrong on the native text path
/// while still extracting as text — a failure no text test can catch. A
/// document that contains Bengali therefore must not be laid out natively, and
/// [PrintDocument.needsRaster] is that rule.
library;

import '../l10n/app_translations.dart';
import '../utils/date_utils.dart';

/// Whether [text] contains Bengali script (U+0980–U+09FF).
///
/// The app ships Bengali and English only, so this single block decides the
/// raster fallback; a future complex script needs its own block added here.
bool hasBengaliText(String text) =>
    text.codeUnits.any((unit) => unit >= 0x0980 && unit <= 0x09FF);

/// A labelled value in a printed entry, e.g. `Petitioner: Karim Rahman`.
class PrintField {
  /// Creates a labelled printed value.
  const PrintField(this.label, this.value);

  /// Localized label shown before the value.
  final String label;

  /// The value itself, already localized/formatted by the caller.
  final String value;
}

/// One case entry as a screen hands it to the printer.
///
/// Mirrors the `HearingCandidate` pattern used by the notification planner: the
/// print layer never sees a Drift row, so its tests need no database.
class PrintCaseRow {
  /// Creates a printable case row; every text field is optional but the case
  /// number, because an empty value is simply left off the page.
  const PrintCaseRow({
    required this.caseNumber,
    this.caseType = '',
    this.petitioner = '',
    this.respondent = '',
    this.court = '',
    this.petitionerCounsel = '',
    this.respondentCounsel = '',
    this.onBehalf = '',
    this.step = '',
    this.note = '',
    this.date = '',
  });

  /// Case number as the user typed it, e.g. `110/2021`.
  final String caseNumber;

  /// Case type plus any free-text title/section the screen shows with it.
  final String caseType;

  /// Petitioner party label.
  final String petitioner;

  /// Respondent party label.
  final String respondent;

  /// Localized court label (used only when the row is not already grouped
  /// under a court heading).
  final String court;

  /// Petitioner's lead counsel.
  final String petitionerCounsel;

  /// Respondent's lead counsel.
  final String respondentCounsel;

  /// Localized represented role resolved through `on_behalf_id`.
  final String onBehalf;

  /// Localized step label.
  final String step;

  /// Free-text note/remarks.
  final String note;

  /// The screen's own date, already formatted (next, previous or disposed).
  final String date;
}

/// A screen's own grouping of rows — a court, a date, or the whole list.
class PrintCaseGroup {
  /// Creates a group with an optional localized heading.
  const PrintCaseGroup({required this.rows, this.heading});

  /// Localized group heading (court name, date, …), omitted for flat lists.
  final String? heading;

  /// The group's rows, in the order the screen shows them.
  final List<PrintCaseRow> rows;
}

/// One composed entry: an optional serial and a heading line plus its labelled
/// fields, already in print order.
class PrintEntry {
  /// Creates a composed printed entry.
  const PrintEntry({required this.heading, required this.fields, this.serial = ''});

  /// Localized serial, empty on the screens that show none.
  final String serial;

  /// Primary line of the entry (`110/2021 · Civil Suit`).
  final String heading;

  /// Labelled values printed under [heading], in canonical order.
  final List<PrintField> fields;
}

/// A composed group of entries under an optional heading.
class PrintGroup {
  /// Creates a composed printed group.
  const PrintGroup({required this.entries, this.heading});

  /// Localized heading (`Dhaka Judge Court`), omitted for flat lists.
  final String? heading;

  /// The group's entries.
  final List<PrintEntry> entries;
}

/// Builds the plain `Page X of Y` line before a localized one is supplied.
String _defaultPageLabel(int page, int total) => 'Page $page of $total';

/// A complete printable document, ready for either renderer.
class PrintDocument {
  /// Creates a printable document.
  const PrintDocument({
    required this.title,
    required this.groups,
    required this.footer,
    this.subtitle = '',
    this.meta = const [],
    this.pageLabel = _defaultPageLabel,
  });

  /// Document title — the screen's own localized name.
  final String title;

  /// Optional second line describing the dataset (date scope, active filter).
  final String subtitle;

  /// Labelled header facts, e.g. the date range or the search query in force.
  final List<PrintField> meta;

  /// The document body.
  final List<PrintGroup> groups;

  /// Footer line, e.g. `Printed on 19/09/2026`.
  final String footer;

  /// Localized `Page X of Y` line for renderers that paginate.
  final String Function(int page, int total) pageLabel;

  /// Number of printed entries.
  int get entryCount =>
      groups.fold(0, (total, group) => total + group.entries.length);

  /// Whether the document has nothing to print.
  bool get isEmpty => entryCount == 0;

  /// Every string the document will draw, in reading order.
  Iterable<String> get allText sync* {
    yield title;
    yield subtitle;
    for (final field in meta) {
      yield field.label;
      yield field.value;
    }
    for (final group in groups) {
      if (group.heading != null) yield group.heading!;
      for (final entry in group.entries) {
        yield entry.serial;
        yield entry.heading;
        for (final field in entry.fields) {
          yield field.label;
          yield field.value;
        }
      }
    }
    yield footer;
    yield pageLabel(1, 1);
  }

  /// Whether the native text path cannot be trusted for this document.
  ///
  /// Script-aware default (user-approved): Bengali content is rendered as
  /// bounded page images, Latin-only content keeps the searchable text path.
  bool get needsRaster => allText.any(hasBengaliText);
}

/// Builds the canonical case-list document (plan §8).
///
/// One list layout serves every case screen: the screen supplies its own
/// localized [title], its own date column label (`Next Date`, `Previous Date`,
/// `Disposed`) and its own grouping, and the rows it passes are exactly the
/// rows it is showing — so an active filter or search is printed too.
PrintDocument buildCaseListDocument({
  required AppTranslations translations,
  required String title,
  required String dateColumnLabel,
  required List<PrintCaseGroup> groups,
  String subtitle = '',
  List<PrintField> meta = const [],
  bool showSerial = false,
  int? printedAtEpochMs,
}) {
  final l = translations.raw;
  var serial = 0;

  final composed = <PrintGroup>[
    for (final group in groups)
      PrintGroup(
        heading: group.heading,
        entries: [
          for (final row in group.rows)
            PrintEntry(
              serial: showSerial
                  ? AppDateUtils.formatDigits(
                      ++serial,
                      l.localeName,
                      grouping: false,
                    )
                  : '',
              heading: _entryHeading(row),
              fields: [
                // The court is a field only on the flat lists; on a grouped
                // screen the group heading already names it once.
                if (group.heading == null)
                  PrintField(l.addEditCaseSheet_nameOfCourt, row.court),
                PrintField(
                  l.caseDetailsScreen_petitioner,
                  row.petitioner,
                ),
                PrintField(l.caseDetailsScreen_respondent, row.respondent),
                PrintField(l.caseDetailsScreen_leadCounsel, _counselLine(row)),
                PrintField(l.addEditCaseSheet_onBehalf, row.onBehalf),
                PrintField(l.caseCard_lastStep, row.step),
                PrintField(dateColumnLabel, row.date),
                PrintField(l.addEditCaseSheet_note, row.note),
              ].where((field) => field.value.trim().isNotEmpty).toList(),
            ),
        ],
      ),
  ];

  return PrintDocument(
    title: title,
    subtitle: subtitle,
    meta: meta,
    groups: composed,
    pageLabel: l.print_pageOf,
    footer: l.print_printedOn(
      AppDateUtils.formatDateDDMMYYYY(
        printedAtEpochMs ?? DateTime.now().millisecondsSinceEpoch,
        locale: l.localeName,
      ),
    ),
  );
}

/// Primary line of an entry: `110/2021 · Civil Suit`.
String _entryHeading(PrintCaseRow row) => [
  row.caseNumber.trim(),
  if (row.caseType.trim().isNotEmpty) row.caseType.trim(),
].join(' · ');

/// Both lead counsels on one line, whichever of them exist.
String _counselLine(PrintCaseRow row) => [
  row.petitionerCounsel.trim(),
  row.respondentCounsel.trim(),
].where((value) => value.isNotEmpty).join(' · ');
