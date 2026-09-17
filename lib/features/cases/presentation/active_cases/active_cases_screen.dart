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

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

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
    return CasesScreenModal(
      title: l.activeCasesScreen_title,
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

    return _cases.isEmpty
        ? Center(
            child: Text(
              l.activeCasesScreen_title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadCases,
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: _cases.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final currentCase = _cases[index];
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
                      '${context.l10n.caseTypeLabel(currentCase.caseType, courtCategoryId: court?.courtCategoryId)} ${currentCase.caseNumber}',
                  title:
                      '${currentCase.petitioner} Vs ${currentCase.respondent}',
                  subtitle: currentCase.caseTitleAndSection,
                  courtName: court?.courtName,
                  judgesName: isHigherCourt
                      ? currentCase.honorableJudges
                      : null,
                  statusLabel: _onBehalfsById[currentCase.onBehalfId]?.name,
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
          );
  }
}
