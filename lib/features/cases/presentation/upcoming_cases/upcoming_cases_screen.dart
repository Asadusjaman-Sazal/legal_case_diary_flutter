/// Upcoming cases screen: future-dated cases grouped by next hearing date.
///
/// Task 08 Phase 3. Shows cases whose `next_date` falls within tomorrow through
/// tomorrow + `upcoming_cases_period` days (UserSettings, default 7). Cases are
/// grouped under localized date headers, newest group first.
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
import '../../../../features/settings/data/local/court_categories_dao.dart';
import '../../../../features/settings/data/local/courts_dao.dart';
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

const _millisecondsPerDay = 86400000;

/// Upcoming cases host: date-grouped future cases.
class UpcomingCasesScreen extends ConsumerStatefulWidget {
  /// Creates the Upcoming Cases host.
  const UpcomingCasesScreen({super.key});

  @override
  ConsumerState<UpcomingCasesScreen> createState() =>
      _UpcomingCasesScreenState();
}

class _UpcomingCasesScreenState extends ConsumerState<UpcomingCasesScreen> {
  List<Case> _cases = const [];
  Map<String, Court> _courtsById = const {};
  Map<String, CourtCategory> _categoriesById = const {};
  Map<String, OnBehalf> _onBehalfsById = const {};

  /// Each case's previous hearing date (epoch ms), for the printed `Prev. Date`.
  Map<String, int> _previousDatesByCaseId = const {};
  Object? _error;
  bool _loading = true;

  // Scoped search state (plan §12.1): the query filters this screen's own
  // upcoming window only.
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  /// The user's upcoming window, kept for the search so a query is scoped to
  /// the same dates the list shows.
  int _period = 7;

  /// The screen's live scoped search (plan §12.1), restricted to this screen's
  /// upcoming window.
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

  /// Runs one query through the Drift LIKE path, scoped to the same
  /// tomorrow-through-`period` window this screen lists.
  Future<List<Case>> _searchCases(String query) async {
    final repository = await ref.read(caseRepositoryProvider.future);
    final todayStart = AppDateUtils.bangladeshTodayStartOfDay();
    return repository.searchScoped(
      query,
      scope: CaseSearchScope(
        disposal: CaseSearchDisposal.activeOnly,
        nextDateStart: todayStart + _millisecondsPerDay, // tomorrow
        nextDateEnd: todayStart + _millisecondsPerDay * (_period + 1) - 1,
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
      final settingsRepo = await ref.read(settingsRepositoryProvider.future);
      final settings = await settingsRepo.getSettings();
      final period = settings.upcomingCasesPeriod;

      final todayStart = AppDateUtils.bangladeshTodayStartOfDay();
      final rangeStart = todayStart + _millisecondsPerDay; // tomorrow
      final rangeEnd = todayStart + _millisecondsPerDay * (period + 1) - 1;

      final cases = await repository.listByNextDateRange(rangeStart, rangeEnd);
      final courts = await CourtsDao(db).getAll();
      final categories = await CourtCategoriesDao(db).getAll();
      final onBehalfs = await OnBehalfsDao(db).getAll();
      final previousDates = await CaseHistoryDao(
        db,
      ).latestHearingDateByCaseIds(cases.map((currentCase) => currentCase.id));
      if (!mounted) return;
      setState(() {
        _cases = cases;
        _period = period;
        _courtsById = {for (final court in courts) court.id: court};
        _categoriesById = {for (final c in categories) c.id: c};
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

  /// Opens the shared Phone/Message chooser for the represented party
  /// (Task 14 Phase 4): the party comes from `on_behalf_id`, the number from
  /// the case's single `party_phone`, and the message from the ARB template.
  Future<void> _contactParty(Case currentCase, {required bool message}) async {
    await showCaseContactActions(
      context,
      ref: ref,
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

  /// The document this screen prints: the upcoming window it is showing, with
  /// its own date-then-court headings (plan §8 and §12.1).
  PrintDocument _printDocument(BuildContext context) {
    final l = AppLocalizations.of(context);
    final headings = <String, String>{};
    final rows = <Case>[];
    for (final dateGroup in _dateGroups(l)) {
      for (final courtGroup in dateGroup.courtGroups) {
        final court = printCourtHeading(context.l10n, courtGroup.court);
        for (final currentCase in courtGroup.cases) {
          rows.add(currentCase);
          // The court name alone: the printout already orders by date, and the
          // "Tomorrow/Day & Date" prefix ahead of the court name was removed
          // (user request).
          headings[currentCase.id] = court;
        }
      }
    }
    return buildCaseListPrintDocument(
      context,
      CaseListPrintRequest(
        title: l.upcomingCasesScreen_title,
        cases: rows,
        courtsById: _courtsById,
        onBehalfsById: _onBehalfsById,
        previousDatesByCaseId: _previousDatesByCaseId,
        groupHeading: (currentCase) => headings[currentCase.id],
        meta: [
          if (_searchController.text.trim().isNotEmpty)
            PrintField(l.sharedActions_search, _searchController.text.trim()),
        ],
      ),
    );
  }

  /// Groups cases by their normalized Bangladesh civil date, newest first,
  /// and then by court inside each date.
  List<_DateGroup> _dateGroups(AppLocalizations l) {
    final byDate = <int, List<Case>>{};
    for (final c in _visibleRows) {
      if (c.nextDate == null) continue;
      final dayStart = AppDateUtils.normalizeToBangladeshStartOfDay(
        c.nextDate!,
      );
      byDate.putIfAbsent(dayStart, () => []).add(c);
    }
    // Ascending: earliest hearing date first (01/09/2026 above 02/09/2026).
    final sortedKeys = byDate.keys.toList()..sort((a, b) => a.compareTo(b));
    final tomorrowStart =
        AppDateUtils.bangladeshTodayStartOfDay() + _millisecondsPerDay;
    return [
      for (final key in sortedKeys)
        _DateGroup(
          // The header renders this as-is (Title Case); the date, month and
          // weekday follow the active language, digits included.
          dateLabel: key == tomorrowStart
              ? l.general_tomorrow
              : _formatDateTitle(key, l.localeName),
          courtGroups: _courtGroupsFor(byDate[key]!),
        ),
    ];
  }

  /// The date-title text for one hearing day: English keeps the short
  /// `EEE, MMM dd, yyyy` — e.g. Sat, Sep 19, 2026 — while বাংলা spells the
  /// month out and keeps the language's day-first order:
  /// `EEE, dd MMMM, yyyy` → বৃহস্পতি, ২৪ সেপ্টেম্বর, ২০২৬.
  String _formatDateTitle(int dayStart, String locale) {
    final pattern = locale.startsWith('bn')
        ? 'EEE, dd MMMM, yyyy'
        : 'EEE, MMM dd, yyyy';
    return DateFormat(
      pattern,
      locale,
    ).format(AppDateUtils.bangladeshDateTime(dayStart));
  }

  /// Splits one date's cases by court, ordered by the pre-seeded court
  /// hierarchy exactly like the Daily Cause List groups its courts.
  List<_CourtGroup> _courtGroupsFor(List<Case> cases) {
    final orderedCourts = _courtsById.values.toList()
      ..sort((a, b) {
        final ca = _categoriesById[a.courtCategoryId]?.orderIndex ?? 0;
        final cb = _categoriesById[b.courtCategoryId]?.orderIndex ?? 0;
        if (ca != cb) return ca.compareTo(cb);
        return a.orderIndex.compareTo(b.orderIndex);
      });

    final byCourt = <String, List<Case>>{};
    for (final currentCase in cases) {
      byCourt.putIfAbsent(currentCase.courtId, () => []).add(currentCase);
    }

    final groups = <_CourtGroup>[];
    for (final court in orderedCourts) {
      final courtCases = byCourt[court.id];
      if (courtCases == null || courtCases.isEmpty) continue;
      groups.add(_CourtGroup(court: court, cases: courtCases));
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // The compact ↔ extended choice is stored per screen, so this list can be
    // a table while another case list stays a card list.
    final extended = watchCaseListExtendedView(ref, CaseListScreenId.upcoming);
    return CasesScreenModal(
      title: l.upcomingCasesScreen_title,
      onSync: () => pullCaseListToSync(ref, _loadCases),
      documentBuilder: () => _printDocument(context),
      onAddCase: _openAddCase,
      onSearch: _toggleSearch,
      isSearching: _isSearching,
      searchController: _searchController,
      onSearchChanged: _onSearchChanged,
      onViewToggle: (compact) => setCaseListViewMode(
        ref,
        screenId: CaseListScreenId.upcoming,
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

    final groups = _dateGroups(l);

    if (groups.isEmpty) {
      return CaseListEmptyState(
        placeholder: l.upcomingCasesScreen_empty,
        isSearching: _isSearching,
        hasAnyCase: _cases.isNotEmpty,
        onRefresh: () => pullCaseListToSync(ref, _loadCases),
      );
    }

    // 1-based position of every case in the order this screen shows them, so
    // the table's serial column numbers the grouped rows the same way the flat
    // lists number theirs.
    final serials = <String, int>{};
    var nextSerial = 1;
    for (final group in groups) {
      for (final courtGroup in group.courtGroups) {
        for (final currentCase in courtGroup.cases) {
          serials[currentCase.id] = nextSerial++;
        }
      }
    }

    // Courts the user folded away on this screen, read from the app settings so
    // the fold choice survives leaving and re-opening the screen for the rest
    // of the day, and a new day opens every court again. A court that heads
    // groups on more than one hearing day folds as one header, and both views
    // read the same entry, so a court folded in one is folded in the other.
    final collapsedCourts = watchCaseTableCollapsedCourts(
      ref,
      CaseListScreenId.upcoming,
    );

    /// Folds or re-opens one court here, whichever view asked for it.
    Future<void> toggleCourt(String courtId, bool collapsed) =>
        setCaseTableCourtCollapsed(
          ref,
          screenId: CaseListScreenId.upcoming,
          courtId: courtId,
          collapsed: collapsed,
        );

    // The date heading above one day's courts: an ordinary row that scrolls
    // away, so the pinned court titles have the list top to themselves.
    Widget dateHeadingSliver(_DateGroup group) => SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dateHeading(group),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );

    // The compact list: the court title pins to the top of the list for as long
    // as that court's own cards are on screen, and tapping it folds that
    // court's cases away — the same title the extended view draws, only over
    // cards instead of rows. The date heading stays an ordinary row.
    Widget buildList() => RefreshIndicator(
      onRefresh: () => pullCaseListToSync(ref, _loadCases),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
          for (var i = 0; i < groups.length; i++) ...[
            dateHeadingSliver(groups[i]),
            for (final courtGroup in groups[i].courtGroups)
              CaseTableGroup(
                // A court can head a group on more than one hearing day, so
                // the key carries the day too.
                key: ValueKey('court-header-$i-${courtGroup.court.id}'),
                heading: _buildCourtTitle(courtGroup, l),
                headingHeight: caseTableGroupHeaderHeight(context),
                initiallyCollapsed: collapsedCourts.contains(
                  courtGroup.court.id,
                ),
                onToggle: (collapsed) =>
                    toggleCourt(courtGroup.court.id, collapsed),
                rows: [
                  for (final currentCase in courtGroup.cases)
                    _buildCard(currentCase, l),
                ],
              ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
        ],
      ),
    );

    // The extended view pins the same court titles over its rows: a title holds
    // the top of the list until the next court's title reaches it, so the court
    // a row belongs to stays on screen for as long as its cases do.
    Widget buildTableList(Map<CaseTableColumn, double> widths) =>
        RefreshIndicator(
          onRefresh: () => pullCaseListToSync(ref, _loadCases),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
              for (var i = 0; i < groups.length; i++) ...[
                dateHeadingSliver(groups[i]),
                for (final courtGroup in groups[i].courtGroups)
                  CaseTableGroup(
                    // A court can head a group on more than one hearing day, so
                    // the key carries the day too.
                    key: ValueKey('court-header-$i-${courtGroup.court.id}'),
                    heading: _buildCourtTitle(courtGroup, l),
                    headingHeight: caseTableGroupHeaderHeight(context),
                    initiallyCollapsed: collapsedCourts.contains(
                      courtGroup.court.id,
                    ),
                    onToggle: (collapsed) =>
                        toggleCourt(courtGroup.court.id, collapsed),
                    rows: [
                      for (final currentCase in courtGroup.cases)
                        _buildRow(
                          currentCase,
                          l,
                          serials[currentCase.id]!,
                          widths,
                        ),
                    ],
                  ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
            ],
          ),
        );

    return extended
        ? CaseTableView(
            // The court is already the group heading here, so the table drops
            // the Name of Court column rather than repeating it in every row.
            columns: caseTableColumns(exclude: const {CaseTableColumn.court}),
            dateLabel: l.caseCard_nextDate,
            builder: (_, widths) => buildTableList(widths),
          )
        : buildList();
  }

  /// The date heading above one hearing day: the day in Title Case, then a rule
  /// filling the rest of the line.
  ///
  /// The date keeps its own width so it is drawn on a single line; the divider
  /// is what flexes, filling only the space left over once the date is laid out.
  /// (Two flexible children would split the row in half and wrap the date,
  /// which is the bug this replaces.)
  Widget _dateHeading(_DateGroup group) => Padding(
    padding: const EdgeInsets.symmetric(
      vertical: AppSpacing.sm,
      horizontal: AppSpacing.xs,
    ),
    child: Row(
      children: [
        Text(
          group.dateLabel,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Divider(color: Theme.of(context).dividerColor, endIndent: 0),
        ),
      ],
    ),
  );

  /// The court title above a group of cards, styled like the Daily Cause List
  /// court heading (court icon, court name, number of cases).
  Widget _buildCourtTitle(_CourtGroup group, AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.account_balance, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              // Pre-seeded courts store their English name, so the title is
              // resolved through the seed label lookup to follow the active
              // language; a court the user added keeps the name they typed.
              context.l10n.seedLabel(
                group.court.id,
                fallbackEn: group.court.courtName,
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Text(
            AppDateUtils.formatDigits(group.cases.length, l.localeName),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

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
      // Same card layout as the Daily Cause List screen.
      variant: CaseCardVariant.dailyCauseList,
      caseNumber:
          '${context.l10n.caseTypeLabel(currentCase.caseType, courtCategoryId: court?.courtCategoryId)} ${currentCase.caseNumber}',
      title: '${currentCase.petitioner} Vs ${currentCase.respondent}',
      subtitle: currentCase.caseTitleAndSection,
      courtName: null, // Shown in the court title above the card.
      judgesName: isHigherCourt ? currentCase.honorableJudges : null,
      statusLabel: context.l10n.onBehalfLabel(
        currentCase.onBehalfId,
        _onBehalfsById[currentCase.onBehalfId]?.name,
      ),
      alignStatusLabelRight: true,
      nextDate: currentCase.nextDate == null
          ? null
          : DateFormat(
              'dd/MM/yy, EEE',
              l.localeName,
            ).format(AppDateUtils.bangladeshDateTime(currentCase.nextDate!)),
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
  /// the same values as [_buildCard].
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
      date: currentCase.nextDate == null
          ? null
          : DateFormat(
              'dd/MM/yy, EEE',
              l.localeName,
            ).format(AppDateUtils.bangladeshDateTime(currentCase.nextDate!)),
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

class _DateGroup {
  final String dateLabel;
  final List<_CourtGroup> courtGroups;

  const _DateGroup({required this.dateLabel, required this.courtGroups});
}

class _CourtGroup {
  final Court court;
  final List<Case> cases;

  const _CourtGroup({required this.court, required this.cases});
}
