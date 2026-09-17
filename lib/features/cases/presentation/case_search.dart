/// Scoped case search shared by the case-list screens.
///
/// Plan §12.1: every case listing searches only its own dataset, so the text
/// query is applied *after* each screen's own filter (date range, disposed
/// set, court, …). The matcher here is therefore pure and the screen owns the
/// wiring; the searched fields mirror `CasesDao.search` (case number, parties,
/// both lead counsels, party phone, case title/section, remarks) plus the
/// represented client name resolved through the case's on-behalf row.
library;

import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../database/app_database.dart';

/// Whether [currentCase] matches [query] on any of its searchable text fields.
///
/// Matching is case-insensitive and substring-based, and an empty query
/// matches everything, so a screen can call this unconditionally.
bool matchesCaseQuery(
  Case currentCase,
  String query, {
  String? onBehalfName,
}) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  final haystack = <String?>[
    currentCase.caseNumber,
    currentCase.petitioner,
    currentCase.respondent,
    currentCase.petitionerLeadCounsel,
    currentCase.respondentLeadCounsel,
    currentCase.partyPhone,
    currentCase.caseTitleAndSection,
    currentCase.caseRemarks,
    onBehalfName,
  ];
  return haystack.any(
    (value) => value != null && value.toLowerCase().contains(needle),
  );
}

/// Centred empty state for a case list.
///
/// A scoped search that hides every row says so instead of looking like an
/// empty diary; when no query is hiding anything the screen shows its own
/// placeholder ([placeholder] — usually the screen title).
class CaseListEmptyState extends StatelessWidget {
  /// Text shown when nothing has been filtered out by the search.
  final String placeholder;

  /// Whether the scoped search bar is open.
  final bool isSearching;

  /// Whether the screen had any case before the query was applied.
  final bool hasAnyCase;

  /// Creates the shared case-list empty state.
  const CaseListEmptyState({
    required this.placeholder,
    required this.isSearching,
    required this.hasAnyCase,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Text(
        isSearching && hasAnyCase
            ? l.sharedDialogs_noResults
            : placeholder,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
