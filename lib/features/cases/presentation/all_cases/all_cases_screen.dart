/// All cases screen: the first production host for Task 07 case actions.
///
/// Task 08 owns the remaining list-screen refinements; this host intentionally
/// keeps filtering and presentation minimal while exposing the real CaseCard
/// Update callback required by the Add/Edit task.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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

enum _CallTarget { whatsApp, phone }

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

  Future<void> _launchPartyAction(
    Case currentCase, {
    required bool message,
  }) async {
    final phone = currentCase.partyPhone?.trim();
    if (phone == null || phone.isEmpty) return;

    if (!message) {
      final target = await _showCallTargetChooser();
      if (!mounted || target == null) return;
      if (target == _CallTarget.whatsApp) {
        // WhatsApp has no documented direct-call URI; open the contact/chat as
        // the safe fallback, where the user can start a WhatsApp call.
        final normalized = phone.replaceAll(RegExp(r'\D'), '');
        if (normalized.isEmpty) return;
        await _launchExternal(
          Uri.https('wa.me', normalized),
          failureMessage: 'Unable to open WhatsApp.',
        );
      } else {
        await _launchExternal(
          Uri(scheme: 'tel', path: phone),
          failureMessage: 'Unable to place a call.',
        );
      }
      return;
    }

    await _launchExternal(
      Uri(scheme: 'sms', path: phone),
      failureMessage: 'Unable to open messages.',
    );
  }

  Future<_CallTarget?> _showCallTargetChooser() => showDialog<_CallTarget>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Open with'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const ValueKey('case-card-call-whatsapp'),
            leading: const Icon(Icons.chat_outlined),
            title: const Text('WhatsApp'),
            onTap: () => Navigator.of(context).pop(_CallTarget.whatsApp),
          ),
          ListTile(
            key: const ValueKey('case-card-call-phone'),
            leading: const Icon(Icons.call_outlined),
            title: const Text('Phone'),
            onTap: () => Navigator.of(context).pop(_CallTarget.phone),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('case-card-call-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
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

    final locale = Localizations.localeOf(context).toLanguageTag();
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
            alignStatusLabelRight: true,
            nextDate: currentCase.nextDate == null
                ? null
                : DateFormat('dd/MM/yy, EEE', locale).format(
                    AppDateUtils.bangladeshDateTime(currentCase.nextDate!),
                  ),
            step: currentCase.lastStep,
            // Keep the card layout stable even when contact data is absent;
            // the callbacks remain no-ops for an empty phone value.
            showPhoneButton: true,
            showMessageButton: true,
            onPhone: () => _launchPartyAction(currentCase, message: false),
            onMessage: () => _launchPartyAction(currentCase, message: true),
            onUpdate: () => _openQuickUpdate(currentCase),
          );
        },
      ),
    );
  }
}
