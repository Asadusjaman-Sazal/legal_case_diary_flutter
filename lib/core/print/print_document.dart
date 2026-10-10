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
    this.previousDate = '',
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

  /// The case's **previous hearing date** (the last Case History entry's
  /// `hearing_date`), already formatted `dd/MM/yy`; empty when the case has no
  /// history. This is the ruled table's `Prev. Date` cell.
  final String previousDate;
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
  const PrintEntry({required this.fields, this.heading = '', this.serial = ''});

  /// Localized serial, empty on the screens that show none.
  final String serial;

  /// Primary line of the entry (`First Appeal- 34/26`), empty on the entries
  /// whose section heading has already said what they are (Case Detail).
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

/// One Case History row as it is printed.
class PrintHistoryEntry {
  /// Creates a printable history row.
  const PrintHistoryEntry({
    required this.date,
    this.step = '',
    this.result = '',
    this.note = '',
  });

  /// The hearing date, already formatted by the caller.
  final String date;

  /// Localized step label.
  final String step;

  /// Free-text result (higher courts have no step dropdown).
  final String result;

  /// Note or result text.
  final String note;
}

/// A case reduced to what the Case Detail sheet prints.
class PrintCaseDetail {
  /// Creates a printable case detail; every optional field is left off the page
  /// when empty, so a sheet never shows a label with nothing after it.
  const PrintCaseDetail({
    required this.caseNumber,
    this.caseType = '',
    this.court = '',
    this.judges = '',
    this.nextDate = '',
    this.step = '',
    this.result = '',
    this.petitioner = '',
    this.respondent = '',
    this.petitionerCounsel = '',
    this.respondentCounsel = '',
    this.onBehalf = '',
    this.phone = '',
    this.titleAndSection = '',
    this.remarks = '',
    this.tenderNumber = '',
    this.previousCourtCase = '',
    this.districtOfOrigin = '',
    this.history = const [],
  });

  /// Case number as the user typed it.
  final String caseNumber;

  /// Localized case type.
  final String caseType;

  /// Localized court name.
  final String court;

  /// Judges, shown for the higher courts.
  final String judges;

  /// Formatted next date.
  final String nextDate;

  /// Localized current step.
  final String step;

  /// Free-text result.
  final String result;

  /// Petitioner party label.
  final String petitioner;

  /// Respondent party label.
  final String respondent;

  /// Petitioner's lead counsel.
  final String petitionerCounsel;

  /// Respondent's lead counsel.
  final String respondentCounsel;

  /// Localized represented role from `on_behalf_id`.
  final String onBehalf;

  /// The represented party's phone number.
  final String phone;

  /// Sections or free-text case title.
  final String titleAndSection;

  /// Remarks or case summary.
  final String remarks;

  /// Tender number (tender cases only).
  final String tenderNumber;

  /// Previous court case reference.
  final String previousCourtCase;

  /// District of origin (lower courts).
  final String districtOfOrigin;

  /// The case's history, newest first as the screen shows it.
  final List<PrintHistoryEntry> history;
}

/// Number of history rows the Case Detail screen shows while collapsed.
const int collapsedHistoryRows = 3;

/// Case type and case number in the order every printout writes them:
/// `First Appeal- 34/26` — the type first, then the number, one space between
/// them — and just the number when the case has no type yet.
///
/// Nothing is inserted between the two: the seeded case-type labels already
/// carry their own trailing dash (`First Appeal-`), so joining with a space is
/// what produces `First Appeal- 34/26`, and a user-added type simply reads
/// `Misc 34/26` until it is named with a dash of its own.
String caseTypeAndCaseNumber(String caseType, String caseNumber) {
  final type = caseType.trim();
  final number = caseNumber.trim();
  if (type.isEmpty) return number;
  return number.isEmpty ? type : '$type $number';
}

/// Builds the Case Detail sheet.
///
/// Plan §8 lists a Case History timeline export; the user asked for the whole
/// detail sheet instead, printed "the way the user has the screen" — so the
/// history honours the screen's own expansion state: [showAllHistory] false
/// prints the same [collapsedHistoryRows] rows the screen is showing.
///
/// Two things this sheet deliberately does not do: it repeats no case number,
/// case type or court under a section heading (the header line above already
/// carries all three), and it draws no rules — like every other printed page,
/// which draws text and nothing else.
PrintDocument buildCaseDetailDocument({
  required AppTranslations translations,
  required PrintCaseDetail detail,
  required bool showAllHistory,
}) {
  final l = translations.raw;
  final history = showAllHistory
      ? detail.history
      : detail.history.take(collapsedHistoryRows).toList();

  PrintGroup section(String heading, List<PrintField> fields) => PrintGroup(
    heading: heading,
    entries: [
      // No entry heading: the case number used to be repeated here, once per
      // section, and the sheet's own first line already carries it.
      PrintEntry(
        fields: fields.where((field) => field.value.trim().isNotEmpty).toList(),
      ),
    ],
  );

  final groups = <PrintGroup>[
    // The first section starts at the judges. The header line above already
    // says `First Appeal- 34/26 · Dhaka Judge Court`, so Case Number, Case Type
    // and Name of Court rows would only repeat it.
    section(l.caseDetailsScreen_title, [
      PrintField(l.addEditCaseSheet_honorableJudges, detail.judges),
      PrintField(l.addEditCaseSheet_nextDate, detail.nextDate),
      PrintField(l.caseCard_lastStep, detail.step),
      PrintField(l.addEditCaseSheet_result, detail.result),
    ]),
    section(l.addEditCaseSheet_sectionParties, [
      PrintField(l.caseDetailsScreen_onBehalfOf, detail.onBehalf),
      PrintField(l.caseDetailsScreen_petitioner, detail.petitioner),
      PrintField(
        l.addEditCaseSheet_petitionerLeadCounsel,
        detail.petitionerCounsel,
      ),
      PrintField(l.caseDetailsScreen_respondent, detail.respondent),
      PrintField(
        l.addEditCaseSheet_respondentLeadCounsel,
        detail.respondentCounsel,
      ),
      PrintField(l.addEditCaseSheet_partyPhone, detail.phone),
    ]),
    section(l.caseDetailsScreen_caseTitleAndRemark, [
      PrintField(l.caseDetailsScreen_sectionsOrCaseTitle, detail.titleAndSection),
      PrintField(l.caseDetailsScreen_remarksOrCaseSummary, detail.remarks),
    ]),
    section(l.caseDetailsScreen_otherInformation, [
      PrintField(l.caseDetailsScreen_tenderNumber, detail.tenderNumber),
      PrintField(l.caseDetailsScreen_previousCourtCase, detail.previousCourtCase),
      PrintField(l.caseDetailsScreen_districtOfOrigin, detail.districtOfOrigin),
    ]),
    if (history.isNotEmpty)
      PrintGroup(
        heading: l.caseDetailsScreen_caseHistory,
        entries: [
          for (final entry in history)
            PrintEntry(
              heading: entry.date,
              fields: [
                PrintField(l.caseCard_lastStep, entry.step),
                PrintField(l.addEditCaseSheet_result, entry.result),
                PrintField(l.addEditCaseSheet_note, entry.note),
              ].where((field) => field.value.trim().isNotEmpty).toList(),
            ),
        ],
      ),
  ];

  return PrintDocument(
    title: [
      caseTypeAndCaseNumber(detail.caseType, detail.caseNumber),
      if (detail.court.trim().isNotEmpty) detail.court.trim(),
    ].join(' · '),
    subtitle: detail.history.isEmpty
        ? ''
        : l.caseDetailsScreen_entriesTotal(detail.history.length),
    meta: [
      if (detail.petitioner.trim().isNotEmpty || detail.respondent.trim().isNotEmpty)
        PrintField(
          l.addEditCaseSheet_sectionParties,
          [detail.petitioner, detail.respondent]
              .where((party) => party.trim().isNotEmpty)
              .join(' · '),
        ),
    ],
    // Sections with nothing in them are dropped, not printed empty.
    groups: groups
        .where((group) => group.entries.any((entry) => entry.fields.isNotEmpty))
        .toList(),
    // No `Printed on…` footer (user request): the page carries only the
    // `Page X of Y` counter the renderer draws.
    footer: '',
    pageLabel: l.print_pageOf,
  );
}

/// Horizontal alignment of a ruled-table column's cells.
enum PrintColumnAlign {
  /// Left-aligned (the default), as free text columns are.
  start,

  /// Centred — the narrow `SL` and date columns read better centred.
  center,
}

/// One column of a ruled-table printout: its localized heading and its
/// **fixed** width in centimetres.
///
/// The width is fixed rather than fitted to the content: every row must line
/// up, and a value that does not fit wraps to another line inside its own cell
/// instead of widening the column (the rule the sample layout fixes).
class PrintTableColumn {
  /// Creates a table column.
  const PrintTableColumn({
    required this.label,
    required this.widthCm,
    this.align = PrintColumnAlign.start,
  });

  /// Localized column heading, e.g. `Prev. Date`.
  final String label;

  /// Column width in centimetres — the same for every row.
  final double widthCm;

  /// Cell alignment.
  final PrintColumnAlign align;
}

/// What a ruled-table row draws as.
enum PrintTableRowKind {
  /// A court group heading: one centred strip across the whole table width.
  court,

  /// A data row: one cell per column.
  data,

  /// A blank spacer row drawn between court groups.
  spacer,
}

/// One row of a ruled-table printout.
class PrintTableRow {
  /// A court group heading row; [cells] holds the single heading text.
  const PrintTableRow.court(this.cells) : kind = PrintTableRowKind.court;

  /// A data row; [cells] holds one value per column, in column order.
  const PrintTableRow.data(this.cells) : kind = PrintTableRowKind.data;

  /// A blank spacer row.
  const PrintTableRow.spacer()
    : kind = PrintTableRowKind.spacer,
      cells = const <String>[];

  /// What the row draws as.
  final PrintTableRowKind kind;

  /// Cell texts (see the constructors for how many each kind carries).
  final List<String> cells;
}

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
    this.brandTitle = '',
    this.dateLine = '',
    this.logoAsset,
    this.columns,
    this.tableRows = const [],
    this.margin,
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

  /// App brand line drawn beside the logo in the repeated page header
  /// (`Legal Case Diary`); empty when the header carries no brand.
  final String brandTitle;

  /// Optional date line under the brand in the repeated page header, e.g. the
  /// Daily Cause List's `Date: … Day: … Month: … Year: …`. Empty for the
  /// screens that have no single date of their own.
  final String dateLine;

  /// Asset path of the logo drawn in the repeated page header, or null for a
  /// document whose header carries no logo.
  final String? logoAsset;

  /// Ruled-table columns. When non-null the document prints as a bordered
  /// table instead of the heading-and-fields [groups] body, and every page
  /// repeats the header band and these column headings.
  final List<PrintTableColumn>? columns;

  /// The table's rows, in print order (court headings, data rows, spacers).
  /// Ignored unless [columns] is non-null.
  final List<PrintTableRow> tableRows;

  /// Page margin in points, or null for the shared default. The table format
  /// asks for a narrow margin so its fixed columns hold as much as possible.
  final double? margin;

  /// Whether the document prints as a ruled table.
  bool get isTable => columns != null;

  /// Number of printed entries: data rows for a table, one heading-and-fields
  /// entry per group entry otherwise.
  int get entryCount => isTable
      ? tableRows.where((row) => row.kind == PrintTableRowKind.data).length
      : groups.fold(0, (total, group) => total + group.entries.length);

  /// Whether the document has nothing to print.
  bool get isEmpty => entryCount == 0;

  /// Every string the document will draw, in reading order.
  Iterable<String> get allText sync* {
    yield title;
    yield subtitle;
    yield brandTitle;
    yield dateLine;
    for (final field in meta) {
      yield field.label;
      yield field.value;
    }
    for (final column in columns ?? const <PrintTableColumn>[]) {
      yield column.label;
    }
    for (final row in tableRows) {
      yield* row.cells;
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
  /// A ruled table **always** rasterises: its fixed columns, fixed row heights
  /// and cell borders must look identical in both languages, and the native
  /// `pdf` layout engine would measure them its own way (the chosen trade-off
  /// is that a table's text is not selectable).
  bool get needsRaster =>
      isTable || allText.any(hasBengaliText);
}

/// The narrow page margin the ruled-table format uses, in points.
///
/// **0.69 cm** each side: the sample layout's eight fixed columns total
/// 19.62 cm, so on A4 (21 cm) a 0.69 cm margin on each side leaves them fitting
/// almost edge to edge — the "hold as much data as possible" the format asks
/// for.
const double kPrintTableMargin = 0.69 * 72 / 2.54;

/// Builds a ruled-table printout (the case-list format).
///
/// The screen supplies the fixed [columns] and the [rows] it is showing — court
/// headings, data rows and spacer rows, in print order — plus the header band's
/// brand line, optional date line and logo. The document then repeats that
/// band and the column headings on **every** page, and prints no `Printed on…`
/// footer (only the `Page X of Y` counter remains).
PrintDocument buildRuledTableDocument({
  required AppTranslations translations,
  required String title,
  required List<PrintTableColumn> columns,
  required List<PrintTableRow> rows,
  String brandTitle = '',
  String dateLine = '',
  String? logoAsset,
  String subtitle = '',
  List<PrintField> meta = const [],
  double margin = kPrintTableMargin,
}) => PrintDocument(
  title: title,
  subtitle: subtitle,
  meta: meta,
  groups: const <PrintGroup>[],
  // The table carries no footer line: `Printed on…` is deliberately gone, and
  // the page counter is drawn by the renderer.
  footer: '',
  pageLabel: translations.raw.print_pageOf,
  brandTitle: brandTitle,
  dateLine: dateLine,
  logoAsset: logoAsset,
  columns: columns,
  tableRows: rows,
  margin: margin,
);
