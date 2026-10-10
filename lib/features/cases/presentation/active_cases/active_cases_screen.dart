/// Active cases screen: filters to non-disposed cases only.
///
/// Task 08 Phase 2. Card layout and contacts mirror the All Cases screen, but
/// the KPI summary and Court Name / Chronology / search filters are omitted per
/// the task spec.
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

/// Active cases host: non-disposed cases with the standard case card.
class ActiveCasesScreen extends ConsumerStatefulWidget {
  /// Creates the Active Cases host.
  const ActiveCasesScreen({super.key});

  @override
  ConsumerState<ActiveCasesScreen> createState() => _ActiveCasesScreenState();
}

class _ActiveCasesScreenState extends ConsumerState<ActiveCasesScreen> {
  List<Case> _cases = const [];
  Map<String, Court> _courtsById = const {};
  Map<String, OnBehalf> _onBehalfsById = const {};

  /// Each case's previous hearing date (epoch ms), for the printed `Prev. Date`.
  Map<String, int> _previousDatesByCaseId = const {};
  Object? _error;
  bool _loading = true;

  // Scoped search state (plan §12.1): the query filters this screen's own
  // non-disposed dataset only.
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  /// The screen's live scoped search (plan §12.1), restricted to the
  /// non-disposed dataset this screen lists.
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

  /// Runs one query through the Drift LIKE path, scoped to the active dataset.
  Future<List<Case>> _searchCases(String query) async {
    final repository = await ref.read(caseRepositoryProvider.future);
    return repository.searchScoped(
      query,
      scope: const CaseSearchScope(
        disposal: CaseSearchDisposal.activeOnly,
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
  List<Case> get _visibleCases => _search.rows ?? _cases;

  Future<void> _loadCases() async {
    try {
      final repository = await ref.read(caseRepositoryProvider.future);
      final db = await ref.read(databaseProvider.future);
      final cases = await repository.listActive();
      final courts = await CourtsDao(db).getAll();
      final onBehalfs = await OnBehalfsDao(db).getAll();
      final previousDates = await CaseHistoryDao(
        db,
      ).latestHearingDateByCaseIds(cases.map((currentCase) => currentCase.id));
      if (!mounted) return;
      setState(() {
        _cases = cases;
        _courtsById = {for (final court in courts) court.id: court};
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

  /// The document this screen prints: its own non-disposed dataset, filtered
  /// and searched exactly as the list is (plan §8 and §12.1).
  ///
  /// Grouped by court, so the printout carries each case's court name as a
  /// centred heading (user request).
  PrintDocument _printDocument(BuildContext context) {
    final l = AppLocalizations.of(context);
    final grouped = groupCasesByCourt(context.l10n, _visibleCases, _courtsById);
    return buildCaseListPrintDocument(
      context,
      CaseListPrintRequest(
        title: l.activeCasesScreen_title,
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // The compact ↔ extended choice is stored per screen, so this list can be
    // a table while another case list stays a card list.
    final extended = watchCaseListExtendedView(ref, CaseListScreenId.active);
    return CasesScreenModal(
      title: l.activeCasesScreen_title,
      documentBuilder: () => _printDocument(context),
      onAddCase: _openAddCase,
      onSearch: _toggleSearch,
      isSearching: _isSearching,
      searchController: _searchController,
      onSearchChanged: _onSearchChanged,
      onViewToggle: (compact) => setCaseListViewMode(
        ref,
        screenId: CaseListScreenId.active,
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

    final visible = _visibleCases;

    if (visible.isEmpty) {
      return CaseListEmptyState(
        placeholder: l.activeCasesScreen_empty,
        isSearching: _isSearching,
        hasAnyCase: _cases.isNotEmpty,
        onRefresh: () => pullCaseListToSync(ref, _loadCases),
      );
    }

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
          // Serial numbers are this screen's own running order: searching
          // renumbers the visible list from 1.
          return widths == null
              ? _buildCaseCard(currentCase, court, l)
              : _buildCaseRow(currentCase, court, index + 1, l, widths);
        },
      ),
    );

    return extended
        ? CaseTableView(
            dateLabel: l.caseCard_nextDate,
            builder: (_, widths) => buildList(widths),
          )
        : buildList(null);
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
      // A pre-seeded court stores its English name, so the card resolves it to
      // follow the active language.
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
}
