/// Upcoming cases screen: future-dated cases grouped by next hearing date.
///
/// Task 08 Phase 3. Shows cases whose `next_date` falls within tomorrow through
/// tomorrow + `upcoming_cases_period` days (UserSettings, default 7). Cases are
/// grouped under localized date headers, newest group first.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/pre_seeded_data.dart';
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

const _millisecondsPerDay = 86400000;

enum _ContactActionTarget { whatsApp, phone, message }

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
      final settingsRepo = await ref.read(settingsRepositoryProvider.future);
      final settings = await settingsRepo.getSettings();
      final period = settings.upcomingCasesPeriod;

      final todayStart = AppDateUtils.bangladeshTodayStartOfDay();
      final rangeStart = todayStart + _millisecondsPerDay; // tomorrow
      final rangeEnd = todayStart + _millisecondsPerDay * (period + 1) - 1;

      final cases = await repository.listByNextDateRange(rangeStart, rangeEnd);
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

  /// Groups cases by their normalized Bangladesh civil date, newest first.
  List<_DateGroup> _dateGroups(AppLocalizations l) {
    final byDate = <int, List<Case>>{};
    for (final c in _cases) {
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
          dateLabel: key == tomorrowStart
              ? l.general_tomorrow
              : AppDateUtils.formatFullDate(key, locale: l.localeName),
          cases: byDate[key]!,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return CasesScreenModal(
      title: l.upcomingCasesScreen_title,
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

    final groups = _dateGroups(l);

    if (groups.isEmpty) {
      return Center(
        child: Text(
          l.upcomingCasesScreen_title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCases,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: groups.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, groupIndex) {
          final group = groups[groupIndex];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm,
                  horizontal: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.dateLabel.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Theme.of(context).dividerColor,
                        endIndent: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final currentCase in group.cases) ...[
                _buildCard(currentCase, l),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildCard(Case currentCase, AppLocalizations l) {
    final court = _courtsById[currentCase.courtId];
    final isHigherCourt =
        court?.courtCategoryId == appellateDivisionId ||
        court?.courtCategoryId == highCourtDivisionId;
    return CaseCard(
      key: ValueKey('case-card-${currentCase.id}'),
      variant: CaseCardVariant.list,
      caseNumber: '${currentCase.caseType} ${currentCase.caseNumber}',
      title: '${currentCase.petitioner} Vs ${currentCase.respondent}',
      subtitle: currentCase.caseTitleAndSection,
      courtName: court?.courtName,
      judgesName: isHigherCourt ? currentCase.honorableJudges : null,
      statusLabel: _onBehalfsById[currentCase.onBehalfId]?.name,
      alignStatusLabelRight: true,
      nextDate: currentCase.nextDate == null
          ? null
          : DateFormat(
              'dd/MM/yy, EEE',
              l.localeName,
            ).format(AppDateUtils.bangladeshDateTime(currentCase.nextDate!)),
      step: currentCase.lastStep,
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
}

class _DateGroup {
  final String dateLabel;
  final List<Case> cases;

  const _DateGroup({required this.dateLabel, required this.cases});
}
