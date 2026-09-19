/// Turns a case-list screen's own rows into a printable document (Phase 3).
///
/// One canonical layout serves every case screen, as chosen (no layout
/// chooser). The screen hands over **exactly what it is showing** — its dataset,
/// its court filter, its search query and its ordering — plus the labels it
/// already resolved for its cards and table rows, so the printout cannot
/// disagree with the screen (plan §8 and §12.1).
library;

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/app_translations.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/print/print_document.dart';
import '../../../core/utils/date_utils.dart';
import '../../../database/app_database.dart';

/// The localized court heading a grouped screen shows above its rows.
///
/// A pre-seeded court stores its English name, so the printed heading follows
/// the active language exactly as the on-screen heading does.
String printCourtHeading(AppTranslations translations, Court? court) => court == null
    ? ''
    : translations.seedLabel(court.id, fallbackEn: court.courtName);

/// The standard list-row date: `dd/MM/yy, EEE`, the same text every card and
/// table row shows.
String printListDate(AppLocalizations l, int? epochMs) => epochMs == null
    ? ''
    : DateFormat(
        'dd/MM/yy, EEE',
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

/// What a case-list screen prints.
class CaseListPrintRequest {
  /// Creates a print request from a screen's current state.
  const CaseListPrintRequest({
    required this.title,
    required this.cases,
    required this.dateColumnLabel,
    this.courtsById = const {},
    this.onBehalfsById = const {},
    this.showSerial = false,
    this.groupHeading,
    this.dateOf,
    this.subtitle = '',
    this.meta = const [],
  });

  /// Localized screen title, e.g. `Active Cases`.
  final String title;

  /// The rows the screen is showing, in the order it shows them.
  final List<Case> cases;

  /// The screen's own name for its date column.
  final String dateColumnLabel;

  /// Courts by id, for the localized court name (as the cards resolve it).
  final Map<String, Court> courtsById;

  /// On-behalf rows by id, for the represented role.
  final Map<String, OnBehalf> onBehalfsById;

  /// Whether the screen numbers its rows (the flat lists do).
  final bool showSerial;

  /// Heading for a case's group — a court or a date — or `null` for a flat list.
  final String? Function(Case currentCase)? groupHeading;

  /// The screen's own date rule; defaults to the case's next date.
  final String Function(Case currentCase, Court? court)? dateOf;

  /// Optional line under the title describing the dataset.
  final String subtitle;

  /// Optional header facts, e.g. the search query in force.
  final List<PrintField> meta;
}

/// Builds the printable document for [request].
PrintDocument buildCaseListPrintDocument(
  BuildContext context,
  CaseListPrintRequest request,
) {
  final translations = context.l10n;
  final l = translations.raw;

  /// The rows, grouped by consecutive heading so the printed order is the
  /// screen's order.
  final groups = <PrintCaseGroup>[];
  for (final currentCase in request.cases) {
    final heading = request.groupHeading?.call(currentCase);
    final court = request.courtsById[currentCase.courtId];

    if (groups.isEmpty || groups.last.heading != heading) {
      groups.add(PrintCaseGroup(heading: heading, rows: <PrintCaseRow>[]));
    }

    groups.last.rows.add(
      PrintCaseRow(
        caseNumber: currentCase.caseNumber,
        caseType: translations.caseTypeLabel(
          currentCase.caseType,
          courtCategoryId: court?.courtCategoryId,
        ),
        petitioner: currentCase.petitioner,
        respondent: currentCase.respondent,
        court: printCourtHeading(translations, court),
        petitionerCounsel: currentCase.petitionerLeadCounsel ?? '',
        respondentCounsel: currentCase.respondentLeadCounsel ?? '',
        onBehalf:
            translations.onBehalfLabel(
              currentCase.onBehalfId,
              request.onBehalfsById[currentCase.onBehalfId]?.name,
            ) ??
            '',
        step:
            translations.stepNames(
              currentCase.lastStep,
              courtCategoryId: court?.courtCategoryId,
            ) ??
            '',
        note: currentCase.notesResults ?? '',
        date:
            request.dateOf?.call(currentCase, court) ??
            printListDate(l, currentCase.nextDate),
      ),
    );
  }

  return buildCaseListDocument(
    translations: translations,
    title: request.title,
    subtitle: request.subtitle,
    dateColumnLabel: request.dateColumnLabel,
    groups: groups,
    showSerial: request.showSerial,
    meta: request.meta,
  );
}
