/// Turns a case-list screen's own rows into a **ruled-table** printout.
///
/// One table layout serves every case screen: the screen hands over exactly
/// what it is showing — its dataset, its court filter, its search query and its
/// ordering — plus the labels it already resolved for its cards and table rows,
/// so the printout cannot disagree with the screen.
///
/// The layout is fixed by the sample the user supplied: eight columns of fixed
/// width (in centimetres), a fixed minimum row height, a court-group heading row
/// that spans the table, and a thin spacer row between court groups. Every page
/// repeats the header band (logo, app title, screen title, and — on the Daily
/// Cause List — the date line) and the column headings.
library;

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/app_translations.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/print/print_document.dart';
import '../../../core/utils/date_utils.dart';
import '../../../database/app_database.dart';

/// The app's brand line drawn beside the logo in the repeated page header.
const String printBrandLogoAsset = 'assets/icons/app_logo.png';

/// The localized court heading a grouped screen shows above its rows.
///
/// A pre-seeded court stores its English name, so the printed heading follows
/// the active language exactly as the on-screen heading does.
String printCourtHeading(AppTranslations translations, Court? court) =>
    court == null
    ? ''
    : translations.seedLabel(court.id, fallbackEn: court.courtName);

/// The standard list-row date: `dd/MM/yy, EEE`, the same text every card and
/// table row shows.
String printListDate(AppLocalizations l, int? epochMs) => epochMs == null
    ? ''
    : DateFormat(
        'dd/MM/yy',
        l.localeName,
      ).format(AppDateUtils.bangladeshDateTime(epochMs));

/// The Daily Cause List / Upcoming rule: today and tomorrow are spelled out.
String printDisplayDate(AppLocalizations l, int? epochMs) => epochMs == null
    ? ''
    : AppDateUtils.formatDisplayDate(
        epochMs,
        todayLabel: l.caseCard_nextDate,
        tomorrowLabel: l.caseCard_nextDate,
        locale: l.localeName,
      );

/// The Daily Cause List printout's date line:
/// `Date: 10/10/26   Day: Saturday   Month: October   Year: 2026`.
///
/// Every part follows the active language — the date in that language's digits,
/// the weekday and month by their localized names — so a Bengali printout reads
/// wholly in Bengali.
String printDateLine(AppLocalizations l, int selectedDateEpochMs) {
  final at = AppDateUtils.bangladeshDateTime(selectedDateEpochMs);
  final date = DateFormat('dd/MM/yy', l.localeName).format(at);
  final day = DateFormat('EEEE', l.localeName).format(at);
  final month = DateFormat('MMMM', l.localeName).format(at);
  final year = DateFormat('yyyy', l.localeName).format(at);
  return l.print_dateLine(
    l.print_dateLabel,
    date,
    l.print_dayLabel,
    day,
    l.print_monthLabel,
    month,
    l.print_yearLabel,
    year,
  );
}

/// Re-orders [cases] so every court's cases are contiguous, with the localized
/// court name per case id.
///
/// A **flat** list has no court heading of its own, so its printout has no
/// court name at all (user report). This gives one: the cases are grouped by
/// court so the builder's own change-of-heading rule prints one centred court
/// row above each court's cases. The screen's order is kept **inside** a court,
/// and the courts keep the order they first appear in — so a list sorted by
/// `created_at` still reads newest-first within each court.
({List<Case> cases, Map<String, String> headings}) groupCasesByCourt(
  AppTranslations translations,
  List<Case> cases,
  Map<String, Court> courtsById,
) {
  final order = <String>[];
  final byCourt = <String, List<Case>>{};
  for (final currentCase in cases) {
    if (byCourt.putIfAbsent(currentCase.courtId, () => <Case>[]).isEmpty) {
      order.add(currentCase.courtId);
    }
    byCourt[currentCase.courtId]!.add(currentCase);
  }
  final ordered = <Case>[];
  final headings = <String, String>{};
  for (final courtId in order) {
    final heading = printCourtHeading(translations, courtsById[courtId]);
    for (final currentCase in byCourt[courtId]!) {
      ordered.add(currentCase);
      headings[currentCase.id] = heading;
    }
  }
  return (cases: ordered, headings: headings);
}

/// What a case-list screen prints.
class CaseListPrintRequest {
  /// Creates a print request from a screen's current state.
  const CaseListPrintRequest({
    required this.title,
    required this.cases,
    this.courtsById = const {},
    this.onBehalfsById = const {},
    this.previousDatesByCaseId = const {},
    this.previousDateOf,
    this.groupHeading,
    this.nextDateOf,
    this.showNextDate = true,
    this.subtitle = '',
    this.dateLine = '',
    this.meta = const [],
  });

  /// Localized screen title, e.g. `Active Cases`.
  final String title;

  /// The rows the screen is showing, in the order it shows them.
  final List<Case> cases;

  /// Courts by id, for the localized court name (as the cards resolve it).
  final Map<String, Court> courtsById;

  /// On-behalf rows by id, for the represented role.
  final Map<String, OnBehalf> onBehalfsById;

  /// Each case's previous hearing date (epoch ms), from the latest Case History
  /// entry. A case absent from the map prints a blank `Prev. Date`.
  final Map<String, int> previousDatesByCaseId;

  /// Overrides the `Prev. Date` cell for a screen whose own date column *is*
  /// the previous date — the Overdue Dates screen, which shows the case's
  /// current (overdue) next date there. When set it wins over
  /// [previousDatesByCaseId].
  final String Function(Case currentCase, Court? court)? previousDateOf;

  /// Heading for a case's group — a court or a date — or `null` for a flat list.
  final String? Function(Case currentCase)? groupHeading;

  /// The case's next-hearing date, formatted, or empty.
  final String Function(Case currentCase, Court? court)? nextDateOf;

  /// Whether the `Next Date` column is filled. The Daily Cause List leaves it
  /// blank (the list *is* that day); the other screens fill it.
  final bool showNextDate;

  /// Optional line under the title describing the dataset.
  final String subtitle;

  /// The Daily Cause List's Date/Day/Month/Year line; empty elsewhere.
  final String dateLine;

  /// Optional header facts, e.g. the search query in force.
  final List<PrintField> meta;
}

/// The eight fixed columns of the case-list table, in print order.
///
/// Widths are the sample layout's centimetres; the labels are the app's own
/// localized strings (so the printout reads like the screen and the Bengali
/// translations already exist), except the serial, whose `SL` short form is the
/// only label that fits the 0.69 cm column.
List<PrintTableColumn> caseListPrintColumns(AppLocalizations l) => [
  PrintTableColumn(
    label: l.print_serialShort,
    widthCm: 0.69,
    align: PrintColumnAlign.center,
  ),
  PrintTableColumn(
    label: l.caseCard_previousDate,
    widthCm: 1.83,
    align: PrintColumnAlign.center,
  ),
  PrintTableColumn(
    label: l.addEditCaseSheet_caseNumber,
    widthCm: 2.51,
    align: PrintColumnAlign.center,
  ),
  PrintTableColumn(label: l.addEditCaseSheet_petitioner, widthCm: 3.68),
  PrintTableColumn(label: l.addEditCaseSheet_respondent, widthCm: 3.68),
  PrintTableColumn(label: l.allCasesScreen_onBehalf, widthCm: 2.22),
  PrintTableColumn(label: l.caseCard_lastStep, widthCm: 3.18),
  PrintTableColumn(
    label: l.caseCard_nextDate,
    widthCm: 1.83,
    align: PrintColumnAlign.center,
  ),
];

/// Builds the printable ruled-table document for [request].
PrintDocument buildCaseListPrintDocument(
  BuildContext context,
  CaseListPrintRequest request,
) {
  final translations = context.l10n;
  final l = translations.raw;

  var serial = 0;
  final rows = <PrintTableRow>[];
  String? lastHeading;
  var hasGroup = false;

  void addGroupHeading(String heading) {
    // A thin spacer row above every group after the first, so consecutive
    // courts read as separate blocks (the sample's 0.29 cm spacer).
    if (hasGroup) rows.add(const PrintTableRow.spacer());
    rows.add(PrintTableRow.court(<String>[heading]));
    hasGroup = true;
  }

  for (final currentCase in request.cases) {
    final heading = request.groupHeading?.call(currentCase);
    final court = request.courtsById[currentCase.courtId];

    if (heading != null && heading != lastHeading) {
      addGroupHeading(heading);
      lastHeading = heading;
    }

    final prevOverride = request.previousDateOf?.call(currentCase, court);
    final prevDate = request.previousDatesByCaseId[currentCase.id];
    rows.add(
      PrintTableRow.data(<String>[
        AppDateUtils.formatDigits(++serial, l.localeName, grouping: false),
        prevOverride ?? (prevDate == null ? '' : printListDate(l, prevDate)),
        caseTypeAndCaseNumber(
          translations.caseTypeLabel(
            currentCase.caseType,
            courtCategoryId: court?.courtCategoryId,
          ),
          currentCase.caseNumber,
        ),
        currentCase.petitioner,
        currentCase.respondent,
        translations.onBehalfLabel(
              currentCase.onBehalfId,
              request.onBehalfsById[currentCase.onBehalfId]?.name,
            ) ??
            '',
        translations.stepNames(
              currentCase.lastStep,
              courtCategoryId: court?.courtCategoryId,
            ) ??
            '',
        request.showNextDate
            ? (request.nextDateOf?.call(currentCase, court) ??
                  printListDate(l, currentCase.nextDate))
            : '',
      ]),
    );
  }

  return buildRuledTableDocument(
    translations: translations,
    title: request.title,
    brandTitle: l.appTitle,
    dateLine: request.dateLine,
    logoAsset: printBrandLogoAsset,
    columns: caseListPrintColumns(l),
    rows: rows,
    subtitle: request.subtitle,
    meta: request.meta,
  );
}
