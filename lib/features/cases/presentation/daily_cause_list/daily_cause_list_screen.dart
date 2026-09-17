/// Daily cause list screen: hearings for a chosen date, grouped by court.
///
/// Task 09 Phase 1-2. Loads cases scheduled for the selected Bangladesh civil
/// date (default today) and groups them by court name in the pre-seeded court
/// hierarchy order. Each court header carries a hearing-count KPI. A sticky date
/// switcher offers Today / Tomorrow quick filters and a calendar control that
/// opens the badge calendar picker (Phase 3). Cases render with the
/// daily-cause-list card layout (no Next Date field).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/pre_seeded_data.dart';
import '../../../../core/l10n/app_translations.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../database/app_database.dart';
import '../../../../features/cases/data/local/cases_dao.dart';
import '../../../../features/settings/data/local/courts_dao.dart';
import '../../../../features/settings/data/local/court_categories_dao.dart';
import '../../../../features/settings/data/local/on_behalfs_dao.dart';
import '../../../../shared/providers/database_provider.dart';
import '../../../../shared/providers/daily_cause_list_provider.dart';
import '../../../../shared/widgets/add_edit_case_sheet.dart';
import '../../../../shared/widgets/calendar_picker_dialog.dart';
import '../../../../shared/widgets/case_card.dart';
import '../cases_screen_modal.dart';

enum _ContactActionTarget { whatsApp, phone, message }

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
  Object? _error;
  bool _loading = true;

  /// Currently selected Bangladesh civil date (epoch ms at start of day).
  /// Mirrors [dailyCauseListSelectedDateProvider] so the choice survives screen
  /// navigation until the app is closed or the user picks another date.
  late int _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = ref.read(dailyCauseListSelectedDateProvider);
    _loadCases();
  }

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
      if (!mounted) return;
      setState(() {
        _cases = cases;
        _courtsById = {for (final court in courts) court.id: court};
        _categoriesById = {for (final c in categories) c.id: c};
        _onBehalfsById = {for (final item in onBehalfs) item.id: item};
        _loading = false;
        _error = null;
      });
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

  Future<void> _launchPartyAction(
    Case currentCase, {
    required _ContactActionTarget target,
  }) async {
    final phone = currentCase.partyPhone;
    if (phone == null || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n().dailyCauseListScreen_noPhone)),
      );
      return;
    }
    if (target == _ContactActionTarget.whatsApp) {
      await _launchExternal(
        Uri.parse('https://wa.me/$phone'),
        failureMessage: l10n().dailyCauseListScreen_whatsappError,
      );
    } else {
      await _launchExternal(
        Uri(
          scheme: target == _ContactActionTarget.phone ? 'tel' : 'sms',
          path: phone,
        ),
        failureMessage: target == _ContactActionTarget.phone
            ? l10n().dailyCauseListScreen_callError
            : l10n().dailyCauseListScreen_messageError,
      );
    }
  }

  Future<void> _launchExternal(
    Uri uri, {
    required String failureMessage,
  }) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
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
    for (final c in _cases) {
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
    return CasesScreenModal(
      title: l.dailyCauseListScreen_title,
      onAddCase: () {},
      onSearch: () {},
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
          Expanded(child: _buildBody(context, l)),
        ],
      ),
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
    final groups = _courtGroups();
    return groups.isEmpty
        ? Center(
            child: Text(
              l.dailyCauseListScreen_noHearings,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          )
        : ListView.separated(
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
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            group.court.courtName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          '${group.cases.length}',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                  ),
                  for (final currentCase in group.cases) ...[
                    _buildCard(currentCase, l),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
              );
            },
          );
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
          _launchPartyAction(currentCase, target: _ContactActionTarget.phone),
      onMessage: () =>
          _launchPartyAction(currentCase, target: _ContactActionTarget.message),
      onUpdate: () => _openQuickUpdate(currentCase),
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
        color: selected ? AppColors.primary : Colors.transparent,
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
