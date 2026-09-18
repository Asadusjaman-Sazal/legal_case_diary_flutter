/// Overdue dates screen: cases whose next hearing date is in the past.
///
/// Task 08 Phase 4. Each card carries a red left strip (CaseCardVariant.overdue).
/// Cards are grouped by court name, maintaining the pre-seeded court hierarchy.
/// A "Last Updated" status line shows when the listed cases were last modified.
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
import '../../../../features/settings/data/local/court_categories_dao.dart';
import '../../../../features/settings/data/local/on_behalfs_dao.dart';
import '../../../../shared/providers/database_provider.dart';
import '../../../../shared/widgets/add_edit_case_sheet.dart';
import '../../../../shared/widgets/case_card.dart';
import '../case_search.dart';
import '../cases_screen_modal.dart';

enum _ContactActionTarget { whatsApp, phone, message }

/// Overdue dates host: court-grouped overdue cases.
class OverdueDatesScreen extends ConsumerStatefulWidget {
  /// Creates the Overdue Dates host.
  const OverdueDatesScreen({super.key});

  @override
  ConsumerState<OverdueDatesScreen> createState() => _OverdueDatesScreenState();
}

class _OverdueDatesScreenState extends ConsumerState<OverdueDatesScreen> {
  List<Case> _cases = const [];
  Map<String, Court> _courtsById = const {};
  Map<String, CourtCategory> _categoriesById = const {};
  Map<String, OnBehalf> _onBehalfsById = const {};
  Object? _error;
  bool _loading = true;

  // Scoped search state (plan §12.1): the query filters this screen's own
  // overdue dataset only, so the Last Updated line stays the dataset's.
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

  Future<void> _loadCases() async {
    try {
      final repository = await ref.read(caseRepositoryProvider.future);
      final db = await ref.read(databaseProvider.future);

      final todayStart = AppDateUtils.bangladeshTodayStartOfDay();
      final cases = await repository.listByNextDateRange(0, todayStart - 1);
      final courts = await CourtsDao(db).getAll();
      final categories = await CourtCategoriesDao(db).getAll();
      final onBehalfs = await OnBehalfsDao(db).getAll();
      if (!mounted) return;
      setState(() {
        _cases = cases;
        _courtsById = {for (final court in courts) court.id: court};
        _categoriesById = {
          for (final category in categories) category.id: category,
        };
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

  /// When the cases on this screen were last modified.
  ///
  /// The newest `updated_at` among the overdue cases currently listed — the
  /// same field the Notes screen prints on a card — so a date, step or note
  /// change made anywhere in the app (including from a card's Update window)
  /// moves this line forward. `null` when the screen has nothing to show.
  int? get _lastUpdatedAt {
    int? newest;
    for (final currentCase in _cases) {
      if (newest == null || currentCase.updatedAt > newest) {
        newest = currentCase.updatedAt;
      }
    }
    return newest;
  }

  /// Formats the status line the way the mockup does — `Thursday, 04/06/26,
  /// 10:45 AM` — in the active language (Bengali weekday and digits under
  /// বাংলা).
  String _formatLastUpdated(AppLocalizations l, int epochMs) => DateFormat(
    'EEEE, dd/MM/yy, hh:mm a',
    l.localeName,
  ).format(AppDateUtils.bangladeshDateTime(epochMs));

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

  /// Groups overdue cases by court, ordered by the pre-seeded court hierarchy.
  List<_CourtGroup> _courtGroups(AppLocalizations l) {
    final orderedCourts = _courtsById.values.toList()
      ..sort((a, b) {
        final ca = _categoriesById[a.courtCategoryId]?.orderIndex ?? 0;
        final cb = _categoriesById[b.courtCategoryId]?.orderIndex ?? 0;
        if (ca != cb) return ca.compareTo(cb);
        return a.orderIndex.compareTo(b.orderIndex);
      });

    final query = _searchController.text;
    final byCourt = <String, List<Case>>{};
    for (final c in _cases) {
      if (!matchesCaseQuery(
        c,
        query,
        onBehalfName: _onBehalfsById[c.onBehalfId]?.name,
      )) {
        continue;
      }
      byCourt.putIfAbsent(c.courtId, () => []).add(c);
    }

    final groups = <_CourtGroup>[];
    for (final court in orderedCourts) {
      final groupCases = byCourt[court.id];
      if (groupCases == null || groupCases.isEmpty) continue;
      groupCases.sort((a, b) => (a.nextDate ?? 0).compareTo(b.nextDate ?? 0));
      groups.add(_CourtGroup(court: court, cases: groupCases));
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return CasesScreenModal(
      title: l.overdueDatesScreen_title,
      onAddCase: _openAddCase,
      onSearch: _toggleSearch,
      isSearching: _isSearching,
      searchController: _searchController,
      onSearchChanged: (_) => setState(() {}),
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

    final groups = _courtGroups(l);

    final lastUpdatedAt = _lastUpdatedAt;

    return Column(
      children: [
        if (lastUpdatedAt != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                const Icon(Icons.history, size: 14),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '${l.overdueDatesScreen_lastUpdated}: '
                    '${_formatLastUpdated(l, lastUpdatedAt)}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: groups.isEmpty
              ? CaseListEmptyState(
                  placeholder: l.overdueDatesScreen_title,
                  isSearching: _isSearching,
                  hasAnyCase: _cases.isNotEmpty,
                )
              : RefreshIndicator(
                  onRefresh: _loadCases,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: groups.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
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
                                    // Pre-seeded courts store their English
                                    // name, so the heading is resolved through
                                    // the seed lookup to follow the language.
                                    context.l10n.seedLabel(
                                      group.court.id,
                                      fallbackEn: group.court.courtName,
                                    ),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                Text(
                                  // The hearing count alone, in the active
                                  // language's digits, exactly like the Daily
                                  // Cause List and Upcoming Cases court titles
                                  // (বাংলা reads ২, not 2 Cases).
                                  AppDateUtils.formatDigits(
                                    group.cases.length,
                                    l.localeName,
                                  ),
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outline,
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
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCard(Case currentCase, AppLocalizations l) {
    final court = _courtsById[currentCase.courtId];
    final isHigherCourt =
        court?.courtCategoryId == appellateDivisionId ||
        court?.courtCategoryId == highCourtDivisionId;
    return CaseCard(
      key: ValueKey('case-card-${currentCase.id}'),
      variant: CaseCardVariant.overdue,
      caseNumber:
          '${context.l10n.caseTypeLabel(currentCase.caseType, courtCategoryId: court?.courtCategoryId)} ${currentCase.caseNumber}',
      title: '${currentCase.petitioner} Vs ${currentCase.respondent}',
      subtitle: currentCase.caseTitleAndSection,
      courtName:
          null, // Court name is shown in the group header above the card.
      judgesName: isHigherCourt ? currentCase.honorableJudges : null,
      statusLabel: context.l10n.onBehalfLabel(
        currentCase.onBehalfId,
        _onBehalfsById[currentCase.onBehalfId]?.name,
      ),
      alignStatusLabelRight: true,
      isOverdue: true, // Always overdue; black case number, red stripe + date.
      nextDate: currentCase.nextDate == null
          ? null
          : AppDateUtils.formatDisplayDate(
              currentCase.nextDate!,
              todayLabel: l.caseCard_previousDate,
              tomorrowLabel: l.caseCard_previousDate,
              locale: l.localeName,
            ),
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
}

class _CourtGroup {
  final Court court;
  final List<Case> cases;

  const _CourtGroup({required this.court, required this.cases});
}
