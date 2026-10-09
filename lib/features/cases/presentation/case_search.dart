/// Scoped case search shared by the case-list screens.
///
/// Plan §12.1: every case listing searches only its own dataset, so the text
/// query is applied *after* each screen's own filter (date range, disposed
/// set, court, …). The search itself is a Drift query — `CasesDao.searchScoped`
/// owns the field set and the dataset predicate — and the screens each hold one
/// [ScopedCaseSearch], which hands them the rows the query returned.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/utils/scoped_search.dart';
import '../../../database/app_database.dart';
import '../../../sync/sync_service.dart';

/// Pull-down-to-sync for a case-list screen's [CaseListEmptyState].
///
/// It runs the same forced drain the header sync button runs
/// (`retryNow`, which clears the backoff and pulls the delta), then reloads the
/// screen's own rows so anything that arrived appears. The reload is what makes
/// an *empty* screen useful to pull on: a sync alone would change nothing the
/// user can see, because the list they are pulling has nothing in it yet.
Future<void> pullCaseListToSync(
  WidgetRef ref,
  Future<void> Function() reload,
) async {
  await ref.read(syncServiceProvider).retryNow();
  await reload();
}

/// The runner a case-list screen's search bar uses: one [ScopedSearch] over
/// [Case] rows, filled by `CaseRepository.searchScoped`.
typedef ScopedCaseSearch = ScopedSearch<Case>;

/// Centred empty state for a case list.
///
/// A scoped search that hides every row says so instead of looking like an
/// empty diary; when no query is hiding anything the screen shows its own
/// empty message ([placeholder] — the screen's `*_empty` string, e.g. *No case
/// added yet. Tap + to add one.*, not the screen title).
class CaseListEmptyState extends StatelessWidget {
  /// The screen's own empty message — what is missing, not what the screen is
  /// called. Shown when nothing has been filtered out by the search.
  final String placeholder;

  /// Whether the scoped search bar is open.
  final bool isSearching;

  /// Whether the screen had any case before the query was applied.
  final bool hasAnyCase;

  /// Refresh handler, so an empty list can still be pulled to sync.
  ///
  /// Nullable because not every caller has one; when it is null the empty state
  /// is not scrollable and pull-to-refresh simply does not exist there.
  final Future<void> Function()? onRefresh;

  /// Creates the shared case-list empty state.
  const CaseListEmptyState({
    required this.placeholder,
    required this.isSearching,
    required this.hasAnyCase,
    this.onRefresh,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Text(
      isSearching && hasAnyCase ? l.sharedDialogs_noResults : placeholder,
      style: Theme.of(context).textTheme.titleMedium,
    );

    // A `RefreshIndicator` only responds to a drag on a scrollable, and a bare
    // `Center` is not one — so an empty screen had nothing to pull. The message
    // now sits in a scrollable that always overscrolls, which is what makes
    // pull-to-sync available whether or not there is anything to show.
    final scrollable = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: Center(child: text),
        ),
      ],
    );

    final refresh = onRefresh;
    return refresh == null
        ? Center(child: text)
        : RefreshIndicator(onRefresh: refresh, child: scrollable);
  }
}
