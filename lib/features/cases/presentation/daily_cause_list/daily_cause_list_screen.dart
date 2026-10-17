/// Daily cause list screen: hearings for a chosen date, grouped by court.
///
/// Task 09 Phase 1-2. Loads cases scheduled for the selected Bangladesh civil
/// date (default today) and groups them by court name in the pre-seeded court
/// hierarchy order. Each court header carries a hearing-count KPI. A sticky date
/// switcher offers Today / Tomorrow quick filters and a calendar control that
/// opens the badge calendar picker (Phase 3). Cases render with the
/// daily-cause-list card layout (no Next Date field).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
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
import '../../../../features/cases/data/local/cases_dao.dart';
import '../../../../features/settings/data/local/courts_dao.dart';
import '../../../../features/settings/data/local/court_categories_dao.dart';
import '../../../../features/settings/data/local/on_behalfs_dao.dart';
import '../../../../features/accounts_and_profile/data/profile_name_store.dart';
import '../../../../shared/providers/database_provider.dart';
import '../../../../shared/providers/daily_cause_list_provider.dart';
import '../../../../shared/widgets/add_edit_case_sheet.dart';
import '../../../../shared/widgets/calendar_picker_dialog.dart';
import '../../../../shared/widgets/case_card.dart';
import '../../../../shared/widgets/case_table_row.dart';
import '../../../payments/presentation/lapse_allowance_ui.dart';
import '../case_list_view_mode.dart';
import '../case_search.dart';
import '../case_table_view.dart';
import '../cases_screen_modal.dart';

/// Daily cause list host: court-grouped hearings for the selected civil date.
class DailyCauseListScreen extends ConsumerStatefulWidget {
  /// Creates the Daily Cause List host.
  const DailyCauseListScreen({super.key});

  @override
  ConsumerState<DailyCauseListScreen> createState() =>
      _DailyCauseListScreenState();
}

class _DailyCauseListScreenState extends ConsumerState<DailyCauseListScreen> {
  List<Case> _cases = const [];
  Map<String, Court> _courtsById = const {};
  Map<String, CourtCategory> _categoriesById = const {};
  Map<String, OnBehalf> _onBehalfsById = const {};

  /// Each case's previous hearing date (epoch ms), for the printed `Prev. Date`.
  Map<String, int> _previousDatesByCaseId = const {};
  Object? _error;
  bool _loading = true;

  /// Currently selected Bangladesh civil date (epoch ms at start of day).
  /// Mirrors [dailyCauseListSelectedDateProvider] so the choice survives screen
  /// navigation until the app is closed or the user picks another date.
  late int _selectedDate;

  // Scoped search state (plan §12.1): the query filters the selected date's
  // hearings only.
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  /// The screen's live scoped search (plan §12.1), restricted to the selected
  /// date's hearings.
  late final ScopedCaseSearch _search = ScopedCaseSearch(fetch: _searchCases);

  @override
  void initState() {
    super.initState();
    _selectedDate = ref.read(dailyCauseListSelectedDateProvider);
    _loadCases();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Opens/closes the scoped search bar; closing clears the query so the day's
  /// hearings come back whole.
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        unawaited(_search.run(''));
      }
    });
  }

  /// Runs one query through the Drift LIKE path, scoped to the selected day.
  Future<List<Case>> _searchCases(String query) async {
    final repository = await ref.read(caseRepositoryProvider.future);
    return repository.searchScoped(
      query,
      scope: CaseSearchScope(
        disposal: CaseSearchDisposal.activeOnly,
        nextDateStart: _selectedDate,
        nextDateEnd:
            _selectedDate + const Duration(days: 1).inMilliseconds - 1,
      ),
    );
  }

  /// Types into the bar: the query goes to SQL, then the list rebuilds.
  Future<void> _onSearchChanged(String query) async {
    await _search.run(query);
    if (mounted) setState(() {});
  }

  /// The rows the list shows: the query's own result while one is in force,
  /// otherwise the selected day's hearings.
  List<Case> get _visibleRows => _search.rows ?? _cases;

  Future<void> _loadCases() async {
    try {
      final repository = await ref.read(caseRepositoryProvider.future);
      final db = await ref.read(databaseProvider.future);
      final start = _selectedDate;
      final end = start + const Duration(days: 1).inMilliseconds - 1;
      final cases = await repository.listByNextDateRange(start, end);
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
        _categoriesById = {for (final c in categories) c.id: c};
        _onBehalfsById = {for (final item in onBehalfs) item.id: item};
        _previousDatesByCaseId = previousDates;
        _loading = false;
        _error = null;
      });
      // A day change or a reload moves the dataset under an open search, so the
      // query is re-run rather than answered from the previous day's rows.
      if (_search.isActive) await _onSearchChanged(_searchController.text);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  void _selectDate(int date) {
    if (date == _selectedDate) return;
    setState(() => _selectedDate = date);
    ref.read(dailyCauseListSelectedDateProvider.notifier).select(date);
    _loadCases();
  }

  Future<void> _openCalendarPicker() async {
    final db = await ref.read(databaseProvider.future);
    // Counts span ALL dates (every case with a next date), so the badge calendar
    // shows hearing counts for past and future months, not just the focused one.
    final counts = await CasesDao(db).countAllByNextDate();
    if (!mounted) return;
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => CalendarPickerDialog(
        initialDate: _selectedDate,
        hearingCounts: counts,
        onDateSelected: (date) => Navigator.of(context).pop(date),
      ),
    );
    if (picked != null && mounted) _selectDate(picked);
  }

  /// Opens the shared Phone/Message chooser for the represented party
  /// (Task 14 Phase 4): the party comes from `on_behalf_id`, the number from
  /// the case's single `party_phone`, and the message from the ARB template.
  Future<void> _contactParty(
    Case currentCase, {
    required bool message,
  }) async {
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

  /// FAB action: open the Add Case form, then refresh the selected date so a
  /// case saved with a hearing today appears immediately.
  Future<void> _openAddCase() async {
    await AddEditCaseSheet.show<void>(context);
    if (mounted) await _loadCases();
  }

  Future<void> _openQuickUpdate(Case currentCase) async {
    await QuickUpdateCaseDialog.show(context, currentCase);
    if (mounted) await _loadCases();
  }

  Future<void> _openCaseDetail(Case currentCase) async {
    await context.push(AppRoutes.caseDetailPath(currentCase.id));
    if (mounted) await _loadCases();
  }

  /// The document this screen prints: the selected day's cause list, grouped by
  /// court exactly as the screen groups it (plan §8 and §12.1).
  PrintDocument _printDocument(BuildContext context) {
    final l = AppLocalizations.of(context);
    final headings = <String, String>{};
    final rows = <Case>[];
    for (final group in _courtGroups()) {
      for (final currentCase in group.cases) {
        rows.add(currentCase);
        headings[currentCase.id] = printCourtHeading(context.l10n, group.court);
      }
    }
    return buildCaseListPrintDocument(
      context,
      CaseListPrintRequest(
      title: l.dailyCauseListScreen_title,
        cases: rows,
        subtitle: AppDateUtils.formatDailyCauseCalendarDate(
          _selectedDate,
          locale: l.localeName,
        ),
        courtsById: _courtsById,
        onBehalfsById: _onBehalfsById,
        previousDatesByCaseId: _previousDatesByCaseId,
        groupHeading: (currentCase) => headings[currentCase.id],
        showNextDate: false,
        dateLine: printDateLine(l, _selectedDate),
        meta: [
          if (_searchController.text.trim().isNotEmpty)
            PrintField(l.sharedActions_search, _searchController.text.trim()),
        ],
      ),
    );
  }

  /// Groups selected-date cases by court, ordered by the pre-seeded hierarchy.
  List<_CourtGroup> _courtGroups() {
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
      groups.add(_CourtGroup(court: court, cases: groupCases));
    }
    return groups;
  }

  AppLocalizations l10n() => AppLocalizations.of(context);

  @override
  Widget build(BuildContext context) {
    final l = l10n();
    // The compact ↔ extended choice is stored per screen, so this list can be
    // a table while another case list stays a card list.
    final extended = watchCaseListExtendedView(
      ref,
      CaseListScreenId.dailyCauseList,
    );
    return CasesScreenModal(
      title: l.dailyCauseListScreen_title,
      onSync: () => pullCaseListToSync(ref, _loadCases),
      documentBuilder: () => _printDocument(context),
      onAddCase: _openAddCase,
      onSearch: _toggleSearch,
      isSearching: _isSearching,
      searchController: _searchController,
      onSearchChanged: _onSearchChanged,
      onViewToggle: (compact) => setCaseListViewMode(
        ref,
        screenId: CaseListScreenId.dailyCauseList,
        compact: compact,
      ),
      isCompactView: !extended,
      body: Column(
        children: [
          _DateSwitcher(
            selectedDate: _selectedDate,
            onToday: () =>
                _selectDate(AppDateUtils.bangladeshTodayStartOfDay()),
            onTomorrow: () => _selectDate(
              AppDateUtils.bangladeshTodayStartOfDay() +
                  const Duration(days: 1).inMilliseconds,
            ),
            onOpenCalendar: _openCalendarPicker,
          ),
          Expanded(child: _buildBody(context, l, extended: extended)),
        ],
      ),
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
          child: Text('Unable to load cases: $_error'),
        ),
      );
    }
    final groups = _courtGroups();
    if (groups.isEmpty) {
      return CaseListEmptyState(
        placeholder: l.dailyCauseListScreen_noHearings,
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
      CaseListScreenId.dailyCauseList,
    );

    /// Folds or re-opens one court here, whichever view asked for it.
    Future<void> toggleCourt(String courtId, bool collapsed) =>
        setCaseTableCourtCollapsed(
          ref,
          screenId: CaseListScreenId.dailyCauseList,
          courtId: courtId,
          collapsed: collapsed,
        );

    // The compact list: the court heading pins to the top of the list for as
    // long as that court's own cards are on screen, and tapping it folds that
    // court's cases away — the same heading the extended view draws, only over
    // cards instead of rows.
    Widget buildList() => CustomScrollView(
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
              for (final currentCase in group.cases) _buildCard(currentCase, l),
            ],
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
      ],
    );

    // The extended view pins the same court headings over its rows: a heading
    // holds the top of the list until the next court's heading reaches it, so
    // the court a row belongs to stays on screen for as long as its cases do.
    Widget buildTableList(Map<CaseTableColumn, double> widths) =>
        RefreshIndicator(
          onRefresh: _loadCases,
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
              for (final group in groups)
                CaseTableGroup(
                  key: ValueKey('court-header-${group.court.id}'),
                  heading: _courtHeading(group, l),
                  headingHeight: caseTableGroupHeaderHeight(context),
                  initiallyCollapsed: collapsedCourts.contains(group.court.id),
                  onToggle: (collapsed) => toggleCourt(
                    group.court.id,
                    collapsed,
                  ),
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

  /// The court heading above a group of hearings: the court icon, its name and
  /// the hearing count, in the pre-seeded hierarchy's order.
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
      variant: CaseCardVariant.dailyCauseList,
      caseNumber:
          '${context.l10n.caseTypeLabel(currentCase.caseType, courtCategoryId: court?.courtCategoryId)} ${currentCase.caseNumber}',
      title: '${currentCase.petitioner} Vs ${currentCase.respondent}',
      subtitle: currentCase.caseTitleAndSection,
      courtName: null, // Shown in the group header above the card.
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
      onPhone: () =>
          _contactParty(currentCase, message: false),
      onMessage: () =>
          _contactParty(currentCase, message: true),
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

/// Sticky date switcher: Today / Tomorrow quick filters + calendar control.
class _DateSwitcher extends StatelessWidget {
  final int selectedDate;
  final VoidCallback onToday;
  final VoidCallback onTomorrow;
  final VoidCallback onOpenCalendar;

  const _DateSwitcher({
    required this.selectedDate,
    required this.onToday,
    required this.onTomorrow,
    required this.onOpenCalendar,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final today = AppDateUtils.bangladeshTodayStartOfDay();
    final tomorrow = today + const Duration(days: 1).inMilliseconds;
    final isToday = selectedDate == today;
    final isTomorrow = selectedDate == tomorrow;
    final calendarLabel = AppDateUtils.formatDailyCauseCalendarDate(
      selectedDate,
      locale: l.localeName,
    );

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DatePill(
                  label: l.dailyCauseListScreen_today,
                  selected: isToday,
                  onTap: onToday,
                ),
                _DatePill(
                  label: l.dailyCauseListScreen_tomorrow,
                  selected: isTomorrow,
                  onTap: onTomorrow,
                ),
                Container(
                  width: 1,
                  height: 16,
                  color: AppColors.outlineVariant,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                ),
                InkWell(
                  onTap: onOpenCalendar,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: AppColors.onPrimary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          calendarLabel,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: AppColors.onPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A pill button inside the date switcher.
class _DatePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DatePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(999),
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: selected ? Colors.black : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: selected ? AppColors.onPrimary : AppColors.onSurface,
        ),
      ),
    ),
  );
}

class _CourtGroup {
  final Court court;
  final List<Case> cases;

  const _CourtGroup({required this.court, required this.cases});
}
