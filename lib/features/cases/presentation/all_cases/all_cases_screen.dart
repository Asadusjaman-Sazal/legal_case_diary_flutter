/// All cases screen: primary data source for every case in the app.
///
/// Task 08 Phase 1 adds the KPI summary, Court Name + Chronology filters,
/// first-come-first-served serial ordering, and a scoped search box.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/pre_seeded_data.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../database/app_database.dart';
import '../../../../features/settings/data/local/courts_dao.dart';
import '../../../../features/settings/data/local/court_categories_dao.dart';
import '../../../../features/settings/data/local/on_behalfs_dao.dart';
import '../../../../shared/providers/database_provider.dart';
import '../../../../shared/widgets/add_edit_case_sheet.dart';
import '../../../../shared/widgets/case_card.dart';
import '../cases_screen_modal.dart';

enum _ContactActionTarget { whatsApp, phone, message }

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
  Object? _error;
  bool _loading = true;

  int _activeCount = 0;
  int _disposedCount = 0;

  // Filter + search state.
  String? _courtCategoryId; // null = All Courts.
  bool _newestFirst = true;
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

  Future<void> _loadCases() async {
    try {
      final repository = await ref.read(caseRepositoryProvider.future);
      final db = await ref.read(databaseProvider.future);
      final cases = await repository.listAll();
      final courts = await CourtsDao(db).getAll();
      final categories = await CourtCategoriesDao(db).getAll();
      final onBehalfs = await OnBehalfsDao(db).getAll();
      final active = await repository.activeCount();
      if (!mounted) return;
      setState(() {
        _cases = cases;
        _courtsById = {for (final court in courts) court.id: court};
        _categoriesById = {
          for (final category in categories) category.id: category,
        };
        _onBehalfsById = {for (final item in onBehalfs) item.id: item};
        _activeCount = active;
        _disposedCount = cases.length - active;
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
      // WhatsApp has no documented direct-call URI; open the contact/chat as
      // the safe fallback, where the user can start a call or send a message.
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

  /// Applies the Court Name filter, scoped search, and Chronology ordering.
  List<Case> _visibleCases() {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _cases.where((c) {
      if (_courtCategoryId != null) {
        final categoryId = _courtsById[c.courtId]?.courtCategoryId;
        if (categoryId != _courtCategoryId) return false;
      }
      if (query.isEmpty) return true;
      return c.caseNumber.toLowerCase().contains(query) ||
          c.petitioner.toLowerCase().contains(query) ||
          c.respondent.toLowerCase().contains(query) ||
          c.caseTitleAndSection?.toLowerCase().contains(query) == true;
    }).toList();

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
    return CasesScreenModal(
      title: l.allCasesScreen_title,
      onAddCase: _openAddCase,
      onSearch: () {},
      body: _buildBody(context, l),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l) {
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

    return Column(
      children: [
        _buildKpiSummary(l),
        _buildFilters(context, l, categories),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    l.allCasesScreen_title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCases,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final currentCase = visible[index];
                      final court = _courtsById[currentCase.courtId];
                      final isHigherCourt =
                          court?.courtCategoryId == appellateDivisionId ||
                          court?.courtCategoryId == highCourtDivisionId;
                      final isOverdue =
                          currentCase.nextDate != null &&
                          currentCase.nextDate! <
                              AppDateUtils.bangladeshTodayStartOfDay();
                      return CaseCard(
                        key: ValueKey('case-card-${currentCase.id}'),
                        variant: CaseCardVariant.list,
                        caseNumber:
                            '${currentCase.caseType} ${currentCase.caseNumber}',
                        title:
                            '${currentCase.petitioner} Vs ${currentCase.respondent}',
                        subtitle: currentCase.caseTitleAndSection,
                        courtName: court?.courtName,
                        judgesName: isHigherCourt
                            ? currentCase.honorableJudges
                            : null,
                        statusLabel:
                            _onBehalfsById[currentCase.onBehalfId]?.name,
                        alignStatusLabelRight: true,
                        isOverdue: isOverdue,
                        nextDate: currentCase.nextDate == null
                            ? null
                            : DateFormat('dd/MM/yy, EEE', l.localeName).format(
                                AppDateUtils.bangladeshDateTime(
                                  currentCase.nextDate!,
                                ),
                              ),
                        step: currentCase.lastStep,
                        result: currentCase.result,
                        note: currentCase.notesResults,
                        showPhoneButton: true,
                        showMessageButton: true,
                        onPhone: () =>
                            _launchPartyAction(currentCase, message: false),
                        onMessage: () =>
                            _launchPartyAction(currentCase, message: true),
                        onUpdate: () => _openQuickUpdate(currentCase),
                        onTap: () => _openCaseDetail(currentCase),
                      );
                    },
                  ),
                ),
        ),
      ],
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
              label: l.allCasesScreen_activeCases,
              value: _activeCount.toString(),
              valueColor: AppColors.success,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _KpiTile(
              label: l.allCasesScreen_disposedCases,
              value: _disposedCount.toString(),
              valueColor: AppColors.secondary,
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
              decoration: InputDecoration(
                labelText: l.allCasesScreen_filterByCourt,
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
              decoration: InputDecoration(
                labelText: l.allCasesScreen_newestFirst,
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
class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _KpiTile({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    // Sized ~40% smaller than the default tile (padding, radius, fonts, gap).
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md * 0.6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius * 0.6),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
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
    );
  }
}
