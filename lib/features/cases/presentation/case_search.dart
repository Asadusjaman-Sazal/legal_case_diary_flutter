/// Scoped case search shared by the case-list screens.
///
/// Plan §12.1: every case listing searches only its own dataset, so the text
/// query is applied *after* each screen's own filter (date range, disposed
/// set, court, …). The search itself is a Drift query — `CasesDao.searchScoped`
/// owns the field set and the dataset predicate — and the screens each hold one
/// [ScopedCaseSearch], which hands them the rows the query returned.
library;

import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/utils/scoped_search.dart';
import '../../../database/app_database.dart';

/// The runner a case-list screen's search bar uses: one [ScopedSearch] over
/// [Case] rows, filled by `CaseRepository.searchScoped`.
typedef ScopedCaseSearch = ScopedSearch<Case>;

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
