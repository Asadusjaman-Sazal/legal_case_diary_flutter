/// Active cases screen: filters to non-disposed cases only.
///
/// Task 08 Phase 2. Card layout and contacts mirror the All Cases screen, but
/// the KPI summary and Court Name / Chronology / search filters are omitted per
/// the task spec.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/pre_seeded_data.dart';
import '../../../../core/l10n/app_translations.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../database/app_database.dart';
import '../../../../features/settings/data/local/courts_dao.dart';
import '../../../../features/settings/data/local/on_behalfs_dao.dart';
import '../../../../shared/providers/database_provider.dart';
import '../../../../shared/widgets/add_edit_case_sheet.dart';
import '../../../../shared/widgets/case_card.dart';
import '../../../../shared/widgets/case_table_row.dart';
import '../case_list_view_mode.dart';
import '../case_search.dart';
import '../case_table_view.dart';
import '../cases_screen_modal.dart';

enum _ContactActionTarget { whatsApp, phone, message }

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
  Object? _error;
  bool _loading = true;

  // Scoped search state (plan §12.1): the query filters this screen's own
  // non-disposed dataset only.
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

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
      if (!_isSearching) _searchController.clear();
    });
  }

  /// The loaded cases the query still matches.
  List<Case> get _visibleCases => _cases
      .where(
        (c) => matchesCaseQuery(
          c,
          _searchController.text,
          onBehalfName: _onBehalfsById[c.onBehalfId]?.name,
        ),
      )
      .toList();

  Future<void> _loadCases() async {
    try {
      final repository = await ref.read(caseRepositoryProvider.future);
      final db = await ref.read(databaseProvider.future);
      final cases = await repository.listActive();
      final courts = await CourtsDao(db).getAll();
      final onBehalfs = await OnBehalfsDao(db).getAll();
      if (!mounted) return;
      setState(() {
        _cases = cases;
        _courtsById = {for (final court in courts) court.id: court};
        _onBehalfsById = {for (final item in onBehalfs) item.id: item};
        _error = null;
        _loading = false;
      });
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

  Future<void> _launchPartyAction(
    Case currentCase, {
    required bool message,
  }) async {
    final l = AppLocalizations.of(context);
    final phone = currentCase.partyPhone?.trim();
    if (phone == null || phone.isEmpty) return;

    final target = await _showContactTargetChooser(message: message);
    if (!mounted || target == null) return;

    if (target == _ContactActionTarget.whatsApp) {
      final normalized = phone.replaceAll(RegExp(r'\D'), '');
      if (normalized.isEmpty) return;
      await _launchExternal(
        Uri.https('wa.me', normalized),
        failureMessage: l.casesContact_unableToOpenWhatsApp,
      );
    } else {
      await _launchExternal(
        Uri(
          scheme: target == _ContactActionTarget.phone ? 'tel' : 'sms',
          path: phone,
        ),
        failureMessage: target == _ContactActionTarget.phone
            ? l.casesContact_unableToCall
            : l.casesContact_unableToMessage,
      );
    }
  }

  Future<_ContactActionTarget?> _showContactTargetChooser({
    required bool message,
  }) => showDialog<_ContactActionTarget>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(AppLocalizations.of(context).casesContact_openWith),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: ValueKey('case-card-${message ? 'message' : 'call'}-whatsapp'),
            leading: const Icon(Icons.chat_outlined),
            title: Text(AppLocalizations.of(context).casesContact_whatsapp),
            onTap: () =>
                Navigator.of(context).pop(_ContactActionTarget.whatsApp),
          ),
          ListTile(
            key: ValueKey('case-card-${message ? 'message' : 'call'}-native'),
            leading: Icon(message ? Icons.sms_outlined : Icons.call_outlined),
            title: Text(
              message
                  ? AppLocalizations.of(context).casesContact_message
                  : AppLocalizations.of(context).casesContact_phone,
            ),
            onTap: () => Navigator.of(context).pop(
              message
                  ? _ContactActionTarget.message
                  : _ContactActionTarget.phone,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: ValueKey('case-card-${message ? 'message' : 'call'}-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).sharedActions_cancel),
        ),
      ],
    ),
  );

  Future<void> _launchExternal(
    Uri uri, {
    required String failureMessage,
  }) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failureMessage)));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }

  Future<void> _openQuickUpdate(Case currentCase) async {
    await QuickUpdateCaseDialog.show(context, currentCase);
    if (mounted) await _loadCases();
  }

  Future<void> _openCaseDetail(Case currentCase) async {
    await context.push(AppRoutes.caseDetailPath(currentCase.id));
    if (mounted) await _loadCases();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // The compact ↔ extended choice is stored per screen, so this list can be
    // a table while another case list stays a card list.
    final extended = watchCaseListExtendedView(ref, CaseListScreenId.active);
    return CasesScreenModal(
      title: l.activeCasesScreen_title,
      onAddCase: _openAddCase,
      onSearch: _toggleSearch,
      isSearching: _isSearching,
      searchController: _searchController,
      onSearchChanged: (_) => setState(() {}),
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
        placeholder: l.activeCasesScreen_title,
        isSearching: _isSearching,
        hasAnyCase: _cases.isNotEmpty,
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
      onPhone: () => _launchPartyAction(currentCase, message: false),
      onMessage: () => _launchPartyAction(currentCase, message: true),
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
      note: currentCase.notesResults,
      onUpdate: () => _openQuickUpdate(currentCase),
      onTap: () => _openCaseDetail(currentCase),
    );
  }
}
