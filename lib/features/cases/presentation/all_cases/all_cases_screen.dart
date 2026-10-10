/// All cases screen: primary data source for every case in the app.
///
/// Task 08 Phase 1 adds the KPI summary, Court Name + Chronology filters,
/// first-come-first-served serial ordering, and a scoped search box.
///
/// Each count box in the KPI summary is tappable and opens the list it counts
/// (Active Cases / Disposed Cases), and the filter dropdowns' text carries the
/// count boxes' title font size so the two rows read as one block.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/pre_seeded_data.dart';
import '../../../../core/l10n/app_translations.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/providers/contact_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/print/print_document.dart';
import '../../../../core/utils/date_utils.dart';
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
import '../case_list_view_mode.dart';
import '../case_search.dart';
import '../case_table_view.dart';
import '../cases_screen_modal.dart';

/// All Cases host: repository-backed list with KPI summary and filters.
class AllCasesScreen extends ConsumerStatefulWidget {
  /// Creates the All Cases host.
  const AllCasesScreen({super.key});

  @override
  ConsumerState<AllCasesScreen> createState() => _AllCasesScreenState();
}

class _AllCasesScreenState extends ConsumerState<AllCasesScreen> {
  List<Case> _cases = const [];
  Map<String, Court> _courtsById = const {};
  Map<String, CourtCategory> _categoriesById = const {};
  Map<String, OnBehalf> _onBehalfsById = const {};

  /// Each case's previous hearing date (epoch ms), for the printed `Prev. Date`.
  Map<String, int> _previousDatesByCaseId = const {};
  Object? _error;
  bool _loading = true;

  int _activeCount = 0;
  int _disposedCount = 0;

  // Filter + search state.
  String? _courtCategoryId; // null = All Courts.
  bool _newestFirst = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  /// The screen's live scoped search (plan §12.1): the query runs as a Drift
  /// query over the All Cases dataset, rather than filtering the loaded rows.
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

  /// Opens/closes the scoped search bar; closing clears the query so the
  /// list comes back whole.
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        unawaited(_search.run(''));
      }
    });
  }

  /// Runs one query through the Drift LIKE path for this screen's dataset.
  Future<List<Case>> _searchCases(String query) async {
    final repository = await ref.read(caseRepositoryProvider.future);
    return repository.searchScoped(query);
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
      final cases = await repository.listAll();
      final courts = await CourtsDao(db).getAll();
      final categories = await CourtCategoriesDao(db).getAll();
      final onBehalfs = await OnBehalfsDao(db).getAll();
      final previousDates = await CaseHistoryDao(
        db,
      ).latestHearingDateByCaseIds(cases.map((currentCase) => currentCase.id));
      final active = await repository.activeCount();
      if (!mounted) return;
      setState(() {
        _cases = cases;
        _courtsById = {for (final court in courts) court.id: court};
        _categoriesById = {
          for (final category in categories) category.id: category,
        };
        _onBehalfsById = {for (final item in onBehalfs) item.id: item};
        _previousDatesByCaseId = previousDates;
        _activeCount = active;
        _disposedCount = cases.length - active;
        _error = null;
        _loading = false;
      });
      // A reload can change the dataset under an open search, so the query is
      // re-run against the fresh data instead of answering from stale rows.
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

  Future<void> _openQuickUpdate(Case currentCase) async {
    await QuickUpdateCaseDialog.show(context, currentCase);
    if (mounted) await _loadCases();
  }

  Future<void> _openCaseDetail(Case currentCase) async {
    await context.push(AppRoutes.caseDetailPath(currentCase.id));
    if (mounted) await _loadCases();
  }

  /// The document this screen prints: the rows it is showing, with the court
  /// filter, the search query and the chronology choice already applied, so the
  /// printout cannot disagree with the list (plan §8 and §12.1).
  ///
  /// The rows are grouped by court so the printout carries each case's court
  /// name as a centred heading (user request) — this screen has no court column
  /// of its own.
  PrintDocument _printDocument(BuildContext context) {
    final l = AppLocalizations.of(context);
    final grouped = groupCasesByCourt(context.l10n, _visibleCases(), _courtsById);
    return buildCaseListPrintDocument(
      context,
      CaseListPrintRequest(
        title: l.allCasesScreen_title,
        cases: grouped.cases,
        courtsById: _courtsById,
        onBehalfsById: _onBehalfsById,
        previousDatesByCaseId: _previousDatesByCaseId,
        groupHeading: (currentCase) => grouped.headings[currentCase.id],
        meta: [
          if (_searchController.text.trim().isNotEmpty)
            PrintField(l.sharedActions_search, _searchController.text.trim()),
        ],
      ),
    );
  }

  /// Applies the Court Name filter on top of the scoped search result (plan
  /// §12.1 — the screen's own dataset is filtered before the text query, and
  /// the text query itself already ran in SQL), then the Chronology ordering.
  List<Case> _visibleCases() {
    final filtered = _visibleRows
        .where(
          (c) =>
              _courtCategoryId == null ||
              _courtsById[c.courtId]?.courtCategoryId == _courtCategoryId,
        )
        .toList();

    filtered.sort((a, b) {
      final cmp = a.createdAt.compareTo(b.createdAt);
      return _newestFirst ? -cmp : cmp;
    });
    return filtered;
  }

  String _categoryLabel(BuildContext context, CourtCategory category) {
    final l = AppLocalizations.of(context);
    return switch (category.nameKey) {
      'courtCategory_appellateDivision' => l.courtCategory_appellateDivision,
      'courtCategory_highCourtDivision' => l.courtCategory_highCourtDivision,
      'lowerCourtCategory_districtSessionsCriminal' =>
        l.lowerCourtCategory_districtSessionsCriminal,
      'lowerCourtCategory_districtCourtsCivil' =>
        l.lowerCourtCategory_districtCourtsCivil,
      'lowerCourtCategory_metropolitanSessionsJudgeCriminal' =>
        l.lowerCourtCategory_metropolitanSessionsJudgeCriminal,
      'lowerCourtCategory_chiefJudicialMagistrate' =>
        l.lowerCourtCategory_chiefJudicialMagistrate,
      'lowerCourtCategory_chiefMetropolitanMagistrate' =>
        l.lowerCourtCategory_chiefMetropolitanMagistrate,
      'lowerCourtCategory_executiveMagistrate' =>
        l.lowerCourtCategory_executiveMagistrate,
      'lowerCourtCategory_tribunals' => l.lowerCourtCategory_tribunals,
      _ => category.nameKey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // The compact ↔ extended choice is stored per screen, so this list can be
    // a table while another case list stays a card list.
    final extended = watchCaseListExtendedView(ref, CaseListScreenId.allCases);
    return CasesScreenModal(
      title: l.allCasesScreen_title,
      documentBuilder: () => _printDocument(context),
      onAddCase: _openAddCase,
      onSearch: _toggleSearch,
      isSearching: _isSearching,
      searchController: _searchController,
      onSearchChanged: _onSearchChanged,
      onViewToggle: (compact) => setCaseListViewMode(
        ref,
        screenId: CaseListScreenId.allCases,
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

    final categories = _categoriesById.values.toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final visible = _visibleCases();

    // [widths] is set only in the extended view, where the table's columns
    // decide each cell's width; the compact list keeps the cards.
    Widget buildList(Map<CaseTableColumn, double>? widths) => RefreshIndicator(
      onRefresh: _loadCases,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: visible.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final currentCase = visible[index];
          final court = _courtsById[currentCase.courtId];
          // Serial numbers are this screen's own running order: filtering,
          // sorting or searching renumbers the visible list from 1.
          return widths == null
              ? _buildCaseCard(currentCase, court, l)
              : _buildCaseRow(currentCase, court, index + 1, l, widths);
        },
      ),
    );

    final body = Column(
      children: [
        _buildKpiSummary(l),
        _buildFilters(context, l, categories),
        Expanded(
          child: visible.isEmpty
              ? CaseListEmptyState(
                  placeholder: l.allCasesScreen_empty,
                  isSearching: _isSearching,
                  hasAnyCase: _cases.isNotEmpty,
                  onRefresh: () => pullCaseListToSync(ref, _loadCases),
                )
              : (extended
                    ? CaseTableView(
                        dateLabel: l.caseCard_nextDate,
                        builder: (_, widths) => buildList(widths),
                      )
                    : buildList(null)),
        ),
      ],
    );
    return body;
  }

  /// The compact card for [currentCase].
  Widget _buildCaseCard(Case currentCase, Court? court, AppLocalizations l) {
    final isHigherCourt =
        court?.courtCategoryId == appellateDivisionId ||
        court?.courtCategoryId == highCourtDivisionId;
    final isOverdue =
        currentCase.nextDate != null &&
        currentCase.nextDate! < AppDateUtils.bangladeshTodayStartOfDay();
    return CaseCard(
      key: ValueKey('case-card-${currentCase.id}'),
      variant: CaseCardVariant.list,
      caseNumber:
          '${context.l10n.caseTypeLabel(currentCase.caseType, courtCategoryId: court?.courtCategoryId)} ${currentCase.caseNumber}',
      title: '${currentCase.petitioner} Vs ${currentCase.respondent}',
      subtitle: currentCase.caseTitleAndSection,
      // A pre-seeded court stores its English name, so the
      // card resolves it to follow the active language.
      courtName: court == null
          ? null
          : context.l10n.seedLabel(court.id, fallbackEn: court.courtName),
      judgesName: isHigherCourt ? currentCase.honorableJudges : null,
      statusLabel: context.l10n.onBehalfLabel(
        currentCase.onBehalfId,
        _onBehalfsById[currentCase.onBehalfId]?.name,
      ),
      alignStatusLabelRight: true,
      isOverdue: isOverdue,
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
      onUpdate: () => _openQuickUpdate(currentCase),
      onTap: () => _openCaseDetail(currentCase),
    );
  }

  /// The extended-view row for [currentCase]; [serial] is its 1-based position
  /// and [widths] the table's current column widths. One column per field, so
  /// the row carries every value [_buildCaseCard] shows.
  Widget _buildCaseRow(
    Case currentCase,
    Court? court,
    int serial,
    AppLocalizations l,
    Map<CaseTableColumn, double> widths,
  ) {
    final isHigherCourt =
        court?.courtCategoryId == appellateDivisionId ||
        court?.courtCategoryId == highCourtDivisionId;
    final isOverdue =
        currentCase.nextDate != null &&
        currentCase.nextDate! < AppDateUtils.bangladeshTodayStartOfDay();
    return CaseTableRow(
      key: ValueKey('case-row-${currentCase.id}'),
      widths: widths,
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
      isOverdue: isOverdue,
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
      onUpdate: () => _openQuickUpdate(currentCase),
      onTap: () => _openCaseDetail(currentCase),
    );
  }

  Widget _buildKpiSummary(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: _KpiTile(
              key: const ValueKey('all-cases-kpi-active'),
              label: l.allCasesScreen_activeCases,
              value: _activeCount.toString(),
              valueColor: AppColors.success,
              // Each count box opens the list that count belongs to.
              onTap: () => context.push(AppRoutes.activeCases),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _KpiTile(
              key: const ValueKey('all-cases-kpi-disposed'),
              label: l.allCasesScreen_disposedCases,
              value: _disposedCount.toString(),
              valueColor: AppColors.secondary,
              onTap: () => context.push(AppRoutes.disposedCases),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(
    BuildContext context,
    AppLocalizations l,
    List<CourtCategory> categories,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: _courtCategoryId,
              isExpanded: true,
              // The dropdown's own text carries the count boxes' title font
              // size, so the summary row and the filter row read as one block.
              style: AppTypography.titleMd.copyWith(fontSize: 14 * 0.6),
              decoration: InputDecoration(
                labelText: l.allCasesScreen_filterByCourt,
                labelStyle: AppTypography.labelLg.copyWith(
                  fontSize: 14 * 0.6,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(l.allCasesScreen_filterByCourt),
                ),
                for (final category in categories)
                  DropdownMenuItem<String?>(
                    value: category.id,
                    child: Text(_categoryLabel(context, category)),
                  ),
              ],
              onChanged: (value) => setState(() => _courtCategoryId = value),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: DropdownButtonFormField<bool>(
              initialValue: _newestFirst,
              isExpanded: true,
              style: AppTypography.titleMd.copyWith(fontSize: 14 * 0.6),
              decoration: InputDecoration(
                labelText: l.allCasesScreen_newestFirst,
                labelStyle: AppTypography.labelLg.copyWith(
                  fontSize: 14 * 0.6,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(l.allCasesScreen_newestFirst),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(l.allCasesScreen_oldestFirst),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _newestFirst = value ?? true),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact KPI tile used in the All Cases summary row.
///
/// Tappable: the Active tile opens Active Cases and the Disposed tile opens
/// Disposed Cases, so the count a user is reading is one tap from its list.
class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final VoidCallback onTap;

  const _KpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Sized ~40% smaller than the default tile (padding, radius, fonts, gap).
    final radius = BorderRadius.circular(AppSpacing.cardRadius * 0.6);
    return Material(
      // The Material carries the fill so InkWell can paint its ripple.
      color: AppColors.surfaceContainerLowest,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md * 0.6),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.outlineVariant),
            borderRadius: radius,
          ),
          child: Column(
            children: [
              Text(
                // Title Case from the ARB, exactly as the mockup draws it.
                label,
                style: AppTypography.labelMd.copyWith(
                  fontSize: 14 * 0.6,
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs * 0.6),
              Text(
                value,
                style: AppTypography.titleLg.copyWith(
                  fontSize: 20 * 0.6,
                  color: valueColor,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
