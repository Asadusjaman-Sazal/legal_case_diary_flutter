/// Overdue dates screen: cases whose next hearing date is in the past.
///
/// Task 08 Phase 4. Each card carries a red left strip (CaseCardVariant.overdue).
/// Cards are grouped by court name, maintaining the pre-seeded court hierarchy.
/// A "Last Updated" status line shows when the listed cases were last modified.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/pre_seeded_data.dart';
import '../../../../core/l10n/app_translations.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/providers/contact_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/print/print_document.dart';
import '../../../../core/utils/date_utils.dart';
import '../../data/case_search_scope.dart';
import '../case_contact_actions.dart';
import '../case_list_print.dart';
import '../../../../database/app_database.dart';
import '../../data/local/case_history_dao.dart';
import '../../../../features/settings/data/local/courts_dao.dart';
import '../../../../features/settings/data/local/court_categories_dao.dart';
import '../../../../features/settings/data/local/on_behalfs_dao.dart';
import '../../../../features/accounts_and_profile/data/profile_name_store.dart';
import '../../../../shared/providers/database_provider.dart';
import '../../../../shared/widgets/add_edit_case_sheet.dart';
import '../../../../shared/widgets/case_card.dart';
import '../../../../shared/widgets/case_table_row.dart';
import '../../../payments/presentation/lapse_allowance_ui.dart';
import '../case_list_view_mode.dart';
import '../case_search.dart';
import '../case_table_view.dart';
import '../cases_screen_modal.dart';

/// Overdue dates host: court-grouped overdue cases.
class OverdueDatesScreen extends ConsumerStatefulWidget {
  /// Creates the Overdue Dates host.
  const OverdueDatesScreen({super.key});

  @override
  ConsumerState<OverdueDatesScreen> createState() => _OverdueDatesScreenState();
}

class _OverdueDatesScreenState extends ConsumerState<OverdueDatesScreen> {
  List<Case> _cases = const [];
  Map<String, Court> _courtsById = const {};
  Map<String, CourtCategory> _categoriesById = const {};
  Map<String, OnBehalf> _onBehalfsById = const {};

  /// Each case's previous hearing date (epoch ms), for the printed `Prev. Date`.
  Map<String, int> _previousDatesByCaseId = const {};
  Object? _error;
  bool _loading = true;

  // Scoped search state (plan §12.1): the query filters this screen's own
  // overdue dataset only, so the Last Updated line stays the dataset's.
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  /// The screen's live scoped search (plan §12.1), restricted to the same
  /// past-dated, non-disposed dataset this screen lists.
  late final ScopedCaseSearch _search = ScopedCaseSearch(fetch: _searchCases);

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Opens/closes the scoped search bar; closing clears the query so the list
  /// comes back whole.
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        unawaited(_search.run(''));
      }
    });
  }

  /// Runs one query through the Drift LIKE path, scoped to the overdue window
  /// (everything before today's Bangladesh civil date).
  Future<List<Case>> _searchCases(String query) async {
    final repository = await ref.read(caseRepositoryProvider.future);
    final todayStart = AppDateUtils.bangladeshTodayStartOfDay();
    return repository.searchScoped(
      query,
      scope: CaseSearchScope(
        disposal: CaseSearchDisposal.activeOnly,
        nextDateStart: 0,
        nextDateEnd: todayStart - 1,
      ),
    );
  }

  /// Types into the bar: the query goes to SQL, then the list rebuilds.
  Future<void> _onSearchChanged(String query) async {
    await _search.run(query);
    if (mounted) setState(() {});
  }

  /// The rows the list shows: the query's own result while one is in force,
  /// otherwise the screen's loaded dataset.
  List<Case> get _visibleRows => _search.rows ?? _cases;

  Future<void> _loadCases() async {
    try {
      final repository = await ref.read(caseRepositoryProvider.future);
      final db = await ref.read(databaseProvider.future);

      final todayStart = AppDateUtils.bangladeshTodayStartOfDay();
      final cases = await repository.listByNextDateRange(0, todayStart - 1);
      final courts = await CourtsDao(db).getAll();
      final categories = await CourtCategoriesDao(db).getAll();
      final onBehalfs = await OnBehalfsDao(db).getAll();
      final previousDates = await CaseHistoryDao(
        db,
      ).latestHearingDateByCaseIds(cases.map((currentCase) => currentCase.id));
      if (!mounted) return;
      setState(() {
        _cases = cases;
        _courtsById = {for (final court in courts) court.id: court};
        _categoriesById = {
          for (final category in categories) category.id: category,
        };
        _onBehalfsById = {for (final item in onBehalfs) item.id: item};
        _previousDatesByCaseId = previousDates;
        _error = null;
        _loading = false;
      });
      // A reload can change the dataset under an open search, so the query is
      // re-run rather than answered from stale rows.
      if (_search.isActive) await _onSearchChanged(_searchController.text);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _openAddCase() async {
    await AddEditCaseSheet.show<void>(context);
    if (mounted) await _loadCases();
  }

  /// When the cases on this screen were last modified.
  ///
  /// The newest `updated_at` among the overdue cases currently listed — the
  /// same field the Notes screen prints on a card — so a date, step or note
  /// change made anywhere in the app (including from a card's Update window)
  /// moves this line forward. `null` when the screen has nothing to show.
  int? get _lastUpdatedAt {
    int? newest;
    for (final currentCase in _cases) {
      if (newest == null || currentCase.updatedAt > newest) {
        newest = currentCase.updatedAt;
      }
    }
    return newest;
  }

  /// Formats the status line the way the mockup does — `Thursday, 04/06/26,
  /// 10:45 AM` — in the active language (Bengali weekday and digits under
  /// বাংলা).
  String _formatLastUpdated(AppLocalizations l, int epochMs) => DateFormat(
    'EEEE, dd/MM/yy, hh:mm a',
    l.localeName,
  ).format(AppDateUtils.bangladeshDateTime(epochMs));

  /// Opens the shared Phone/Message chooser for the represented party
  /// (Task 14 Phase 4): the party comes from `on_behalf_id`, the number from
  /// the case's single `party_phone`, and the message from the ARB template.
  Future<void> _contactParty(Case currentCase, {required bool message}) async {
    await showCaseContactActions(
      context,
      currentCase: currentCase,
      court: _courtsById[currentCase.courtId],
      onBehalf: _onBehalfsById[currentCase.onBehalfId],
      lawyerName: ref.read(profileNameProvider),
      message: message,
      launcher: ref.read(contactLauncherProvider),
    );
  }

  Future<void> _openQuickUpdate(Case currentCase) async {
    await QuickUpdateCaseDialog.show(context, currentCase);
    if (mounted) await _loadCases();
  }

  Future<void> _openCaseDetail(Case currentCase) async {
    await context.push(AppRoutes.caseDetailPath(currentCase.id));
    if (mounted) await _loadCases();
  }

  /// The document this screen prints: the overdue rows in this screen's own
  /// court order, with its `Previous Date` column wording (plan §8, §12.1).
  ///
  /// On this screen the case's own date **is** the previous date — an overdue
  /// case's `next_date` is in the past — so `Prev. Date` prints that (the same
  /// value the screen shows) and the `Next Date` column is left empty
  /// (user request), exactly as Daily Cause List leaves it.
  PrintDocument _printDocument(BuildContext context) {
    final l = AppLocalizations.of(context);
    final headings = <String, String>{};
    final rows = <Case>[];
    for (final group in _courtGroups(l)) {
      for (final currentCase in group.cases) {
        rows.add(currentCase);
        headings[currentCase.id] = printCourtHeading(context.l10n, group.court);
      }
    }
    return buildCaseListPrintDocument(
      context,
      CaseListPrintRequest(
        title: l.overdueDatesScreen_title,
        cases: rows,
        courtsById: _courtsById,
        onBehalfsById: _onBehalfsById,
        previousDatesByCaseId: _previousDatesByCaseId,
        groupHeading: (currentCase) => headings[currentCase.id],
        previousDateOf: (currentCase, court) =>
            printDisplayDate(l, currentCase.nextDate),
        showNextDate: false,
        meta: [
          if (_searchController.text.trim().isNotEmpty)
            PrintField(l.sharedActions_search, _searchController.text.trim()),
        ],
      ),
    );
  }

  /// Groups overdue cases by court, ordered by the pre-seeded court hierarchy.
  List<_CourtGroup> _courtGroups(AppLocalizations l) {
    final orderedCourts = _courtsById.values.toList()
      ..sort((a, b) {
        final ca = _categoriesById[a.courtCategoryId]?.orderIndex ?? 0;
        final cb = _categoriesById[b.courtCategoryId]?.orderIndex ?? 0;
        if (ca != cb) return ca.compareTo(cb);
        return a.orderIndex.compareTo(b.orderIndex);
      });

    final byCourt = <String, List<Case>>{};
    for (final c in _visibleRows) {
      byCourt.putIfAbsent(c.courtId, () => []).add(c);
    }

    final groups = <_CourtGroup>[];
    for (final court in orderedCourts) {
      final groupCases = byCourt[court.id];
      if (groupCases == null || groupCases.isEmpty) continue;
      groupCases.sort((a, b) => (a.nextDate ?? 0).compareTo(b.nextDate ?? 0));
      groups.add(_CourtGroup(court: court, cases: groupCases));
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // The compact ↔ extended choice is stored per screen, so this list can be
    // a table while another case list stays a card list.
    final extended = watchCaseListExtendedView(ref, CaseListScreenId.overdue);
    return CasesScreenModal(
      title: l.overdueDatesScreen_title,
      onSync: () => pullCaseListToSync(ref, _loadCases),
      documentBuilder: () => _printDocument(context),
      onAddCase: _openAddCase,
      onSearch: _toggleSearch,
      isSearching: _isSearching,
      searchController: _searchController,
      onSearchChanged: _onSearchChanged,
      onViewToggle: (compact) => setCaseListViewMode(
        ref,
        screenId: CaseListScreenId.overdue,
        compact: compact,
      ),
      isCompactView: !extended,
      body: _buildBody(context, l, extended: extended),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l, {
    required bool extended,
  }) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            AppLocalizations.of(context).casesScreen_loadError('$_error'),
          ),
        ),
      );
    }

    final groups = _courtGroups(l);

    final lastUpdatedAt = _lastUpdatedAt;

    // 1-based position of every case in the order this screen shows them, so
    // the table's serial column numbers the grouped rows the same way the flat
    // lists number theirs.
    final serials = <String, int>{};
    var nextSerial = 1;
    for (final group in groups) {
      for (final currentCase in group.cases) {
        serials[currentCase.id] = nextSerial++;
      }
    }

    // Courts the user folded away on this screen, read from the app settings so
    // the fold choice survives leaving and re-opening the screen for the rest
    // of the day. Both views read the same entry, so a court folded in one is
    // folded in the other, and a new day opens every court again.
    final collapsedCourts = watchCaseTableCollapsedCourts(
      ref,
      CaseListScreenId.overdue,
    );

    /// Folds or re-opens one court here, whichever view asked for it.
    Future<void> toggleCourt(String courtId, bool collapsed) =>
        setCaseTableCourtCollapsed(
          ref,
          screenId: CaseListScreenId.overdue,
          courtId: courtId,
          collapsed: collapsed,
        );

    // The compact list: the court heading pins to the top of the list for as
    // long as that court's own cards are on screen, and tapping it folds that
    // court's cases away — the same heading the extended view draws, only over
    // cards instead of rows.
    Widget buildList() => RefreshIndicator(
      onRefresh: () => pullCaseListToSync(ref, _loadCases),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
          for (final group in groups)
            CaseTableGroup(
              key: ValueKey('court-header-${group.court.id}'),
              heading: _courtHeading(group, l),
              headingHeight: caseTableGroupHeaderHeight(context),
              initiallyCollapsed: collapsedCourts.contains(group.court.id),
              onToggle: (collapsed) => toggleCourt(group.court.id, collapsed),
              rows: [
                for (final currentCase in group.cases)
                  _buildCard(currentCase, l),
              ],
            ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
        ],
      ),
    );

    // The extended view pins the same court headings over its rows: a heading
    // holds the top of the list until the next court's heading reaches it, so
    // the court a row belongs to stays on screen for as long as its cases do.
    Widget buildTableList(Map<CaseTableColumn, double> widths) =>
        RefreshIndicator(
          onRefresh: () => pullCaseListToSync(ref, _loadCases),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
              for (final group in groups)
                CaseTableGroup(
                  key: ValueKey('court-header-${group.court.id}'),
                  heading: _courtHeading(group, l),
                  headingHeight: caseTableGroupHeaderHeight(context),
                  initiallyCollapsed: collapsedCourts.contains(group.court.id),
                  onToggle: (collapsed) =>
                      toggleCourt(group.court.id, collapsed),
                  rows: [
                    for (final currentCase in group.cases)
                      _buildRow(
                        currentCase,
                        l,
                        serials[currentCase.id]!,
                        widths,
                      ),
                  ],
                ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
            ],
          ),
        );

    return Column(
      children: [
        if (lastUpdatedAt != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                const Icon(Icons.history, size: 14),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '${l.overdueDatesScreen_lastUpdated}: '
                    '${_formatLastUpdated(l, lastUpdatedAt)}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: groups.isEmpty
              ? CaseListEmptyState(
                  placeholder: l.overdueDatesScreen_empty,
                  isSearching: _isSearching,
                  hasAnyCase: _cases.isNotEmpty,
                  onRefresh: () => pullCaseListToSync(ref, _loadCases),
                )
              : (extended
                    ? CaseTableView(
                        // The court is the group heading above each row, so the
                        // Name of Court column is dropped. Every other column
                        // stays, the combined Step/Result one included.
                        columns: caseTableColumns(
                          exclude: const {CaseTableColumn.court},
                        ),
                        dateLabel: l.caseCard_previousDate,
                        builder: (_, widths) => buildTableList(widths),
                      )
                    : buildList()),
        ),
      ],
    );
  }

  /// The court heading above a group of cases: the court icon, its name and the
  /// hearing count, in the pre-seeded hierarchy's order.
  ///
  /// Compact draws it above its cards and extended draws it pinned, so the two
  /// views share one heading.
  Widget _courtHeading(_CourtGroup group, AppLocalizations l) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Row(
      children: [
        const Icon(Icons.account_balance, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            // Pre-seeded courts store their English name, so the heading is
            // resolved through the seed lookup to follow the language.
            context.l10n.seedLabel(
              group.court.id,
              fallbackEn: group.court.courtName,
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Text(
          // The hearing count alone, in the active language's digits, exactly
          // like the Daily Cause List and Upcoming Cases court titles (বাংলা
          // reads ২, not 2 Cases).
          AppDateUtils.formatDigits(group.cases.length, l.localeName),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    ),
  );

  /// Phase 10: a read-only case explains itself instead of opening the form.
  void _updateIfWritable(Case currentCase) {
    if (!ensureCaseWritable(context, ref, currentCase.id)) return;
    _openQuickUpdate(currentCase);
  }

  Widget _buildCard(Case currentCase, AppLocalizations l) {
    final court = _courtsById[currentCase.courtId];
    final isHigherCourt =
        court?.courtCategoryId == appellateDivisionId ||
        court?.courtCategoryId == highCourtDivisionId;
    return CaseCard(
      key: ValueKey('case-card-${currentCase.id}'),
      variant: CaseCardVariant.overdue,
      caseNumber:
          '${context.l10n.caseTypeLabel(currentCase.caseType, courtCategoryId: court?.courtCategoryId)} ${currentCase.caseNumber}',
      title: '${currentCase.petitioner} Vs ${currentCase.respondent}',
      subtitle: currentCase.caseTitleAndSection,
      courtName:
          null, // Court name is shown in the group header above the card.
      judgesName: isHigherCourt ? currentCase.honorableJudges : null,
      statusLabel: context.l10n.onBehalfLabel(
        currentCase.onBehalfId,
        _onBehalfsById[currentCase.onBehalfId]?.name,
      ),
      alignStatusLabelRight: true,
      isOverdue: true, // Always overdue; black case number, red stripe + date.
      nextDate: currentCase.nextDate == null
          ? null
          : AppDateUtils.formatDisplayDate(
              currentCase.nextDate!,
              todayLabel: l.caseCard_previousDate,
              tomorrowLabel: l.caseCard_previousDate,
              locale: l.localeName,
            ),
      step: context.l10n.stepNames(
        currentCase.lastStep,
        courtCategoryId: court?.courtCategoryId,
      ),
      result: currentCase.result,
      note: currentCase.notesResults,
      showPhoneButton: true,
      showMessageButton: true,
      onPhone: () => _contactParty(currentCase, message: false),
      onMessage: () => _contactParty(currentCase, message: true),
      isReadOnly: isCaseReadOnly(ref, currentCase.id),
      onUpdate: () => _updateIfWritable(currentCase),
      onTap: () => _openCaseDetail(currentCase),
    );
  }

  /// The extended-view row for [currentCase]: one column per field, carrying
  /// the same values as [_buildCard], including the red overdue strip.
  Widget _buildRow(
    Case currentCase,
    AppLocalizations l,
    int serial,
    Map<CaseTableColumn, double> widths,
  ) {
    final court = _courtsById[currentCase.courtId];
    final isHigherCourt =
        court?.courtCategoryId == appellateDivisionId ||
        court?.courtCategoryId == highCourtDivisionId;
    return CaseTableRow(
      key: ValueKey('case-row-${currentCase.id}'),
      widths: widths,
      columns: caseTableColumns(exclude: const {CaseTableColumn.court}),
      serial: serial,
      courtName: court == null
          ? null
          : context.l10n.seedLabel(court.id, fallbackEn: court.courtName),
      judgesName: isHigherCourt ? currentCase.honorableJudges : null,
      caseType: context.l10n.caseTypeLabel(
        currentCase.caseType,
        courtCategoryId: court?.courtCategoryId,
      ),
      caseNumber: currentCase.caseNumber,
      petitioner: currentCase.petitioner,
      respondent: currentCase.respondent,
      onBehalf: context.l10n.onBehalfLabel(
        currentCase.onBehalfId,
        _onBehalfsById[currentCase.onBehalfId]?.name,
      ),
      isOverdue: true, // Always overdue; red stripe + red date.
      date: currentCase.nextDate == null
          ? null
          : AppDateUtils.formatDisplayDate(
              currentCase.nextDate!,
              todayLabel: l.caseCard_previousDate,
              tomorrowLabel: l.caseCard_previousDate,
              locale: l.localeName,
            ),
      step: context.l10n.stepNames(
        currentCase.lastStep,
        courtCategoryId: court?.courtCategoryId,
      ),
      result: currentCase.result,
      note: currentCase.notesResults,
      isReadOnly: isCaseReadOnly(ref, currentCase.id),
      onUpdate: () => _updateIfWritable(currentCase),
      onTap: () => _openCaseDetail(currentCase),
    );
  }
}

class _CourtGroup {
  final Court court;
  final List<Case> cases;

  const _CourtGroup({required this.court, required this.cases});
}
