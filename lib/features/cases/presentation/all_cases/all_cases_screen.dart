/// All cases screen: the first production host for Task 07 case actions.
///
/// Task 08 owns the remaining list-screen refinements; this host intentionally
/// keeps filtering and presentation minimal while exposing the real CaseCard
/// Update callback required by the Add/Edit task.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../database/app_database.dart';
import '../../../../features/settings/data/local/courts_dao.dart';
import '../../../../features/settings/data/local/on_behalfs_dao.dart';
import '../../../../shared/providers/database_provider.dart';
import '../../../../shared/widgets/add_edit_case_sheet.dart';
import '../../../../shared/widgets/case_card.dart';
import '../cases_screen_modal.dart';

/// Minimal repository-backed All Cases host for Task 07 action integration.
class AllCasesScreen extends ConsumerStatefulWidget {
  /// Creates the All Cases host.
  const AllCasesScreen({super.key});

  @override
  ConsumerState<AllCasesScreen> createState() => _AllCasesScreenState();
}

class _AllCasesScreenState extends ConsumerState<AllCasesScreen> {
  List<Case> _cases = const [];
  Map<String, Court> _courtsById = const {};
  Map<String, OnBehalf> _onBehalfsById = const {};
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  Future<void> _loadCases() async {
    try {
      final repository = await ref.read(caseRepositoryProvider.future);
      final db = await ref.read(databaseProvider.future);
      final cases = await repository.listAll();
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

  Future<void> _openQuickUpdate(Case currentCase) async {
    await QuickUpdateCaseDialog.show(context, currentCase);
    if (mounted) await _loadCases();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return CasesScreenModal(
      title: l.allCasesScreen_title,
      onAddCase: _openAddCase,
      body: _buildBody(context, l),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text('Unable to load cases: $_error'),
        ),
      );
    }
    if (_cases.isEmpty) {
      return Center(
        child: Text(
          l.allCasesScreen_title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    final locale = Localizations.localeOf(context).languageCode;
    return RefreshIndicator(
      onRefresh: _loadCases,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _cases.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final currentCase = _cases[index];
          return CaseCard(
            key: ValueKey('case-card-${currentCase.id}'),
            caseNumber: '${currentCase.caseType} ${currentCase.caseNumber}',
            title: '${currentCase.petitioner} Vs ${currentCase.respondent}',
            subtitle: currentCase.caseTitleAndSection,
            courtName: _courtsById[currentCase.courtId]?.courtName,
            statusLabel: _onBehalfsById[currentCase.onBehalfId]?.name,
            nextDate: currentCase.nextDate == null
                ? null
                : AppDateUtils.formatDateDDMMYYYY(
                    currentCase.nextDate!,
                    locale: locale,
                  ),
            step: currentCase
                .lastStep, // Phone/message actions are reserved for Task 14 platform
            // Phone/message integrations belong to Task 14; do not render
            // inert controls before their platform callbacks exist.
            showPhoneButton: false,
            showMessageButton: false,
            onUpdate: () => _openQuickUpdate(currentCase),
          );
        },
      ),
    );
  }
}
