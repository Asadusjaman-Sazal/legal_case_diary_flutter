/// Disposed cases screen: cases closed by a seeded Step or AD/HCD Result.
///
/// Task 08 Phase 5. No FAB (cases cannot be re-opened here). Cards use the
/// disposed variant, showing the disposal date, parties, final note, and the
/// last two case-history entries.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/pre_seeded_data.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../database/app_database.dart';
import '../../../../features/cases/data/local/case_history_dao.dart';
import '../../../../features/settings/data/local/courts_dao.dart';
import '../../../../shared/providers/database_provider.dart';
import '../../../../shared/widgets/case_card.dart';
import '../cases_screen_modal.dart';

enum _ContactActionTarget { whatsApp, phone, message }

/// Disposed cases host: closed cases with the disposed card layout.
class DisposedCasesScreen extends ConsumerStatefulWidget {
  /// Creates the Disposed Cases host.
  const DisposedCasesScreen({super.key});

  @override
  ConsumerState<DisposedCasesScreen> createState() =>
      _DisposedCasesScreenState();
}

class _DisposedCasesScreenState extends ConsumerState<DisposedCasesScreen> {
  List<Case> _cases = const [];
  Map<String, Court> _courtsById = const {};
  Map<String, List<CaseHistoryRow>> _historyById = const {};
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
      final cases = await repository.listDisposed();
      final courts = await CourtsDao(db).getAll();

      final historyDao = CaseHistoryDao(db);
      final historyById = <String, List<CaseHistoryRow>>{};
      for (final c in cases) {
        final entries = await historyDao.getByCaseId(c.id, limit: 2);
        historyById[c.id] = entries;
      }

      if (!mounted) return;
      setState(() {
        _cases = cases;
        _courtsById = {for (final court in courts) court.id: court};
        _historyById = historyById;
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

  Future<void> _launchPartyAction(
    Case currentCase, {
    required bool message,
  }) async {
    final phone = currentCase.partyPhone?.trim();
    if (phone == null || phone.isEmpty) return;

    final target = await _showContactTargetChooser(message: message);
    if (!mounted || target == null) return;

    if (target == _ContactActionTarget.whatsApp) {
      final normalized = phone.replaceAll(RegExp(r'\D'), '');
      if (normalized.isEmpty) return;
      await _launchExternal(
        Uri.https('wa.me', normalized),
        failureMessage: 'Unable to open WhatsApp.',
      );
    } else {
      await _launchExternal(
        Uri(
          scheme: target == _ContactActionTarget.phone ? 'tel' : 'sms',
          path: phone,
        ),
        failureMessage: target == _ContactActionTarget.phone
            ? 'Unable to place a call.'
            : 'Unable to open messages.',
      );
    }
  }

  Future<_ContactActionTarget?> _showContactTargetChooser({
    required bool message,
  }) => showDialog<_ContactActionTarget>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Open with'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: ValueKey('case-card-${message ? 'message' : 'call'}-whatsapp'),
            leading: const Icon(Icons.chat_outlined),
            title: const Text('WhatsApp'),
            onTap: () =>
                Navigator.of(context).pop(_ContactActionTarget.whatsApp),
          ),
          ListTile(
            key: ValueKey('case-card-${message ? 'message' : 'call'}-native'),
            leading: Icon(message ? Icons.sms_outlined : Icons.call_outlined),
            title: Text(message ? 'Message' : 'Phone'),
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return CasesScreenModal(
      title: l.disposedCasesScreen_title,
      showFab: false,
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
          child: Text('Unable to load cases: $_error'),
        ),
      );
    }

    return _cases.isEmpty
        ? Center(
            child: Text(
              l.disposedCasesScreen_title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadCases,
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: _cases.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final currentCase = _cases[index];
                final court = _courtsById[currentCase.courtId];
                final isHigherCourt = court?.courtCategoryId == appellateDivisionId ||
                    court?.courtCategoryId == highCourtDivisionId;
                final history = _historyById[currentCase.id] ?? const [];
                final lastTwo = history.take(2).toList();
                return CaseCard(
                  key: ValueKey('case-card-${currentCase.id}'),
                  variant: CaseCardVariant.disposed,
                  caseNumber:
                      '${currentCase.caseType} ${currentCase.caseNumber}',
                  title:
                      '${currentCase.petitioner} Vs ${currentCase.respondent}',
                  subtitle: currentCase.caseTitleAndSection,
                  courtName: court?.courtName,
                  judgesName: isHigherCourt ? currentCase.honorableJudges : null,
                  statusLabel: currentCase.lastStep,
                  alignStatusLabelRight: true,
                  disposedDate: currentCase.nextDate == null
                      ? null
                      : AppDateUtils.formatDisplayDate(
                          currentCase.nextDate!,
                          todayLabel: l.caseCard_disposed,
                          tomorrowLabel: l.caseCard_disposed,
                          locale: l.localeName,
                        ),
                  step: currentCase.lastStep,
                  result: currentCase.result,
                  note: currentCase.notesResults,
                  showPhoneButton: true,
                  showMessageButton: true,
                  onPhone: () => _launchPartyAction(currentCase, message: false),
                  onMessage: () => _launchPartyAction(currentCase, message: true),
                  historyEntries: lastTwo.map((entry) {
                    final date = AppDateUtils.formatDisplayDate(
                      entry.hearingDate,
                      todayLabel: l.caseCard_disposed,
                      tomorrowLabel: l.caseCard_disposed,
                      locale: l.localeName,
                    );
                    final text = entry.noteResult?.trim().isNotEmpty == true
                        ? entry.noteResult!
                        : (entry.lastStep?.trim().isNotEmpty == true
                            ? entry.lastStep!
                            : l.caseCard_lastStep);
                    return CaseCardHistoryEntry(date: date, text: text);
                  }).toList(),
                );
              },
            ),
          );
  }
}
