/// Case detail screen: KanBan cards for Parties, Case Description, and Case
/// History, plus the mockup Next Date highlight card.
///
/// Task 10 Phase 1. Opened from any case card via `/case-detail/:caseId`.
/// Loads the case, its court and on-behalf role, and its history through the
/// local repositories/DAOs and reloads after every returning dialog.
///
/// A hearing notification opens this screen too, but as the stack's **only**
/// route (the router's initial location on a cold launch, a `go` on a warm
/// tap). Closing it there has nothing to pop back to, so the close actions
/// fall back to the configured landing page — see [_CaseDetailScreenState._close].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/pre_seeded_data.dart';
import '../../../../core/l10n/app_translations.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/print/print_document.dart';
import '../../../../core/print/print_flow.dart';
import '../../../../core/providers/contact_providers.dart';
import '../../../../core/providers/print_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/app_router.dart';
import '../case_search.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/on_behalf_side.dart';
import '../../../../database/app_database.dart';
import '../../../../features/cases/data/local/case_history_dao.dart';
import '../../../../features/settings/data/local/courts_dao.dart';
import '../../../../features/settings/data/local/on_behalfs_dao.dart';
import '../../../../features/settings/presentation/delete_request_flow.dart';
import '../../../../features/settings/presentation/settings_viewmodel.dart';
import '../../../../shared/providers/database_provider.dart';
import '../../../../shared/widgets/add_edit_case_sheet.dart';
import '../../../../shared/widgets/attribution_line.dart';
import '../../../payments/presentation/lapse_allowance_ui.dart';
import '../../../../features/accounts_and_profile/data/account_mode.dart';
import '../../../../features/accounts_and_profile/data/profile_name_store.dart';
import '../case_contact_actions.dart';
import 'history_entry_edit_dialog.dart';

/// The Next Date highlight card's fill and border — the blue this card used
/// before the active-black unification turned every highlight black (the value
/// [AppColors.secondaryContainer] held until then).
///
/// The border is the same blue, not `AppColors.secondary`: a black border that
/// was invisible on the old black fill would ring a blue card in a dark rim.
///
/// Deliberately local to this screen, and therefore the one surface that stays
/// blue: `AppColors` keeps its unified black and the Case Detail screen is the
/// only place that varies from it.
///
/// `ponytail:` the ceiling is that this file is the single home of that blue;
/// if a second screen ever wants it, move it into `AppColors` as a named token
/// instead of copying the hex. `test/core/active_black_test.dart` names this
/// file as its one allowed exception.
const Color _nextDateCardBlue = Color(0xFF316BF3);

/// Long-press action chosen from a history item's option sheet.
enum _HistoryEntryAction { edit, delete }

/// Case detail host: shows a single case with full party/description/history.
class CaseDetailScreen extends ConsumerStatefulWidget {
  /// Creates the detail screen for the case identified by [caseId].
  const CaseDetailScreen({required this.caseId, super.key});

  /// Route case id (UUID).
  final String caseId;

  @override
  ConsumerState<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends ConsumerState<CaseDetailScreen> {
  Case? _current;
  Court? _court;
  OnBehalf? _onBehalf;
  List<CaseHistoryRow> _history = const [];
  Object? _loadError;
  bool _loading = true;
  bool _canEdit = false;
  bool _showAllHistory = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repository = await ref.read(caseRepositoryProvider.future);
      final db = await ref.read(databaseProvider.future);
      final permissions = await ref.read(caseWritePermissionsProvider.future);
      final caseData = await repository.getById(widget.caseId);
      if (!mounted) return;
      if (caseData == null) {
        setState(() {
          _current = null;
          _court = null;
          _onBehalf = null;
          _history = const [];
          _loading = false;
          _canEdit = permissions.canEdit;
          _loadError = null;
        });
        return;
      }
      final court = await CourtsDao(db).getById(caseData.courtId);
      final onBehalf = await OnBehalfsDao(db).getById(caseData.onBehalfId);
      final history = await CaseHistoryDao(db).getByCaseId(widget.caseId);
      // Case History rows show each entry's own date (`hearing_date`) on the
      // left, so the section sorts newest-first by that date instead of the
      // DAO's `next_date` key, which can diverge from the visible timeline
      // when entries were added or edited out of date order. Secondary keys
      // keep the ordering deterministic for equal hearing dates.
      history.sort((a, b) {
        final byDate = b.hearingDate.compareTo(a.hearingDate);
        if (byDate != 0) return byDate;
        final byNext = (b.nextDate ?? 0).compareTo(a.nextDate ?? 0);
        if (byNext != 0) return byNext;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      if (!mounted) return;
      setState(() {
        _current = caseData;
        _court = court;
        _onBehalf = onBehalf;
        _history = history;
        _loading = false;
        _canEdit = permissions.canEdit;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error;
      });
    }
  }

  Future<void> _openEditCase() async {
    final current = _current;
    if (current == null) return;
    // Phase 10: beyond the lapse allowance the case explains itself rather
    // than opening a form that would be refused on save.
    if (!ensureCaseWritable(context, ref, current.id)) return;
    await AddEditCaseSheet.show<void>(context, initialCase: current);
    if (mounted) await _load();
  }

  Future<void> _openReminderUpdate() async {
    final current = _current;
    if (current == null) return;
    if (!ensureCaseWritable(context, ref, current.id)) return;
    await QuickUpdateCaseDialog.show(context, current, canEdit: _canEdit);
    if (mounted) await _load();
  }

  Future<void> _confirmDeleteCase() async {
    final current = _current;
    if (current == null || !_canEdit) return;
    try {
      // The decision — delete now, or ask somebody who can — lives in one place
      // (plan §1, Associate Deletion Policy), and so does the permission refresh
      // and the confirmation that precedes it.
      final outcome = await deleteThroughFirmRules(
        context,
        ref,
        entityType: 'case',
        entityId: current.id,
        entitySnapshot: deleteRequestSnapshot(current.toJson()),
        targetBaseVersion: deletionBaseVersion(current.version),
        deleteDirectly: () async {
          final repository = await ref.read(caseRepositoryProvider.future);
          await repository.deleteCase(current);
        },
      );
      if (!mounted || outcome != DeleteOutcome.deleted) return;
      _close();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).caseDetailsScreen_deleteCaseError('$error'),
          ),
        ),
      );
    }
  }

  /// True when the loaded court belongs to the Appellate or High Court
  /// Division. Only such cases carry the AD/HCD-specific fields shown on this
  /// screen (judges line and the Other Information card).
  bool get _isHigherCourt =>
      _court?.courtCategoryId == appellateDivisionId ||
      _court?.courtCategoryId == highCourtDivisionId;

  /// Resolves the single stored party phone for a contact action. In the
  /// current schema the phone belongs to the represented client, whose side is
  /// derived from `on_behalf_id`; no second phone is ever inferred.
  /// Long-press options for one history item; edit/delete are write actions
  /// and therefore gated like the header buttons by [_canEdit].
  Future<void> _showHistoryActions(CaseHistoryRow entry) async {
    final l = AppLocalizations.of(context);
    final action = await showModalBottomSheet<_HistoryEntryAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('history-action-edit'),
              leading: const Icon(Icons.edit_outlined),
              title: Text(l.sharedActions_edit),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_HistoryEntryAction.edit),
            ),
            ListTile(
              key: const ValueKey('history-action-delete'),
              leading: Icon(Icons.delete_outline, color: AppColors.error),
              title: Text(
                l.sharedActions_delete,
                style: AppTypography.titleMd.copyWith(color: AppColors.error),
              ),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_HistoryEntryAction.delete),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _HistoryEntryAction.edit:
        await _openHistoryEdit(entry);
        break;
      case _HistoryEntryAction.delete:
        await _confirmDeleteHistory(entry);
        break;
    }
  }

  Future<void> _openHistoryEdit(CaseHistoryRow entry) async {
    final current = _current;
    if (current == null) return;
    // A history edit writes the case like any other edit, so it meets the same
    // allowance boundary.
    if (!ensureCaseWritable(context, ref, current.id)) return;
    await HistoryEntryEditDialog.show(context, entry: entry, caseData: current);
    if (mounted) await _load();
  }

  Future<void> _confirmDeleteHistory(CaseHistoryRow entry) async {
    try {
      final outcome = await deleteThroughFirmRules(
        context,
        ref,
        entityType: 'case_history',
        entityId: entry.id,
        entitySnapshot: deleteRequestSnapshot(entry.toJson()),
        targetBaseVersion: deletionBaseVersion(entry.version),
        deleteDirectly: () async {
          final repository = await ref.read(
            caseHistoryRepositoryProvider.future,
          );
          await repository.deleteHistory(entry);
        },
      );
      if (mounted && outcome == DeleteOutcome.deleted) await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).caseDetailsScreen_deleteHistoryError('$error'),
          ),
        ),
      );
    }
  }

  /// Leaves the detail view, landing on the user's chosen landing page when
  /// there is nothing to pop back to.
  ///
  /// A notification tap opens this screen as the only route on the stack, so
  /// `pop` would empty the navigator and strand the app on a black screen. The
  /// navigator is asked first: with history the screen pops as usual (the case
  /// cards push it on top of their list), and at the root it goes through the
  /// router to the stored default landing page instead. Used by both Close
  /// controls, the delete flow and the system back gesture, so every way out
  /// behaves the same.
  void _close() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    // `maybeOf`, not `of`: a test harness can mount this screen under a plain
    // Navigator with no GoRouter above it, and there is nothing to navigate to
    // there either way.
    final landingKey = ref
        .read(settingsViewModelProvider)
        .value
        ?.defaultLandingPage;
    GoRouter.maybeOf(context)?.go(
      landingKey == null
          ? AppRoutes.allCases
          : AppRoutes.landingPageRoute(landingKey),
    );
  }

  /// Opens the shared Phone/Message chooser for the represented party.
  Future<void> _contact({required bool message}) async {
    final current = _current;
    if (current == null) return;
    await showCaseContactActions(
      context,
      ref: ref,
      currentCase: current,
      court: _court,
      onBehalf: _onBehalf,
      lawyerName: ref.read(profileNameProvider),
      message: message,
      launcher: ref.read(contactLauncherProvider),
    );
  }

  // -------------------------------------------------------------------------
  // Build helpers
  // -------------------------------------------------------------------------

  /// Prints this case's detail sheet exactly as the screen is showing it —
  /// including whether the history is expanded — and hands it to the OS dialog
  /// (the user's chosen entry point for the Case History export).
  Future<void> _print(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final current = _current;
    if (current == null) return;

    final outcome = await printDocument(
      context: context,
      document: _printDocument(context, current),
      service: ref.read(printServiceProvider),
      renderer: ref.read(printDocumentRendererProvider),
    );
    if (!context.mounted) return;

    switch (outcome) {
      case PrintOutcome.nothingToPrint:
        _say(context, l.print_nothingToPrint);
      case PrintOutcome.failed:
        _say(context, l.print_failed);
      case PrintOutcome.presented:
      case PrintOutcome.cancelled:
        break;
    }
  }

  /// The printable detail sheet: the same sections, the same localized labels
  /// and the same history rows the screen shows while it is expanded or
  /// collapsed (3 rows).
  PrintDocument _printDocument(BuildContext context, Case current) {
    final l = AppLocalizations.of(context);
    final step = context.l10n.stepNames(
      current.lastStep,
      courtCategoryId: _court?.courtCategoryId,
    );
    final onBehalf = _onBehalf;

    return buildCaseDetailDocument(
      translations: context.l10n,
      showAllHistory: _showAllHistory,
      detail: PrintCaseDetail(
        caseNumber: current.caseNumber,
        caseType: context.l10n.caseTypeLabel(
          current.caseType,
          courtCategoryId: _court?.courtCategoryId,
        ),
        court: _court == null ? '' : _courtLabel(context, _court!),
        judges: current.honorableJudges ?? '',
        nextDate: current.nextDate == null
            ? ''
            : _formatHistoryDate(l, current.nextDate!),
        step: step ?? '',
        result: current.result ?? '',
        petitioner: current.petitioner,
        respondent: current.respondent,
        petitionerCounsel: current.petitionerLeadCounsel ?? '',
        respondentCounsel: current.respondentLeadCounsel ?? '',
        onBehalf: onBehalf == null ? '' : _roleLabel(context, onBehalf),
        phone: current.partyPhone ?? '',
        titleAndSection: current.caseTitleAndSection ?? '',
        remarks: current.notesResults ?? '',
        tenderNumber: current.tenderNumber ?? '',
        previousCourtCase: current.previousCourtCase ?? '',
        districtOfOrigin: current.districtOfOrigin ?? '',
        history: [
          for (final entry in _history)
            PrintHistoryEntry(
              date: _formatHistoryDate(l, entry.hearingDate),
              step:
                  context.l10n.stepNames(
                    entry.lastStep,
                    courtCategoryId: _court?.courtCategoryId,
                  ) ??
                  '',
              result: entry.result ?? '',
              note: entry.noteResult ?? '',
            ),
        ],
      ),
    );
  }

  void _say(BuildContext context, String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  String _courtLabel(BuildContext context, Court court) =>
      context.l10n.seedLabel(court.id, fallbackEn: court.courtName);

  String _roleLabel(BuildContext context, OnBehalf role) =>
      context.l10n.seedLabel(role.id, fallbackEn: role.name);

  /// Case History row date, rendered as `DD/MM/YYYY` (Bangladesh civil date).
  String _formatHistoryDate(AppLocalizations l, int epochMs) => DateFormat(
    'dd/MM/yyyy',
    l.localeName,
  ).format(AppDateUtils.bangladeshDateTime(epochMs));

  /// Case History row weekday shown under the date (e.g. English "THU").
  String _formatHistoryWeekday(AppLocalizations l, int epochMs) => DateFormat(
    'EEE',
    l.localeName,
  ).format(AppDateUtils.bangladeshDateTime(epochMs)).toUpperCase();

  String _formatHighlightDate(AppLocalizations l, int epochMs) => DateFormat(
    'd MMM y, EEEE',
    l.localeName,
  ).format(AppDateUtils.bangladeshDateTime(epochMs));

  /// Whole civil days between the Bangladesh start of today and [nextDateMs].
  ///
  /// Negative when the date has passed; the card reads the sign to choose its
  /// Previous Date title and its "days ago" count.
  int _daysUntil(int nextDateMs) {
    final target = AppDateUtils.normalizeToBangladeshStartOfDay(nextDateMs);
    return (target - AppDateUtils.bangladeshTodayStartOfDay()) ~/
        Duration.millisecondsPerDay;
  }

  /// Shared KanBan card shell: white surface, outline border, rounded top.
  Widget _kanbanCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
      ),
      child: child,
    );
  }

  Widget _headerButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Color backgroundColor = Colors.black,
    Color foregroundColor = Colors.white,
    bool iconOnly = false,
  }) {
    final style = FilledButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      minimumSize: const Size(0, 40),
      padding: iconOnly
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
      ),
      textStyle: AppTypography.labelLg.copyWith(color: foregroundColor),
    );

    if (!iconOnly) {
      return FilledButton.icon(
        key: key,
        onPressed: onPressed,
        style: style,
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
    }

    // No visible text, so the label moves to the tooltip and the semantics
    // label: the button keeps a name for the screen reader and on long press.
    return Tooltip(
      message: label,
      child: FilledButton(
        key: key,
        onPressed: onPressed,
        style: style,
        child: Icon(icon, size: 18),
      ),
    );
  }

  /// One icon-only action in the header's evenly spaced row.
  ///
  /// [Expanded] holds the slot — four equal slots plus equal gaps are what keep
  /// the icons at an even distance — and [FractionallySizedBox] makes the button
  /// take 70% of its slot, i.e. 30% narrower than it, so an icon reads as a
  /// button rather than as a full-width bar.
  Widget _headerAction({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Color backgroundColor = Colors.black,
  }) => Expanded(
    child: FractionallySizedBox(
      widthFactor: 0.7,
      child: _headerButton(
        key: key,
        icon: icon,
        label: label,
        onPressed: onPressed,
        backgroundColor: backgroundColor,
        iconOnly: true,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Intercepting the pop gives the system back gesture the same care as the
    // Close button: a notification-opened detail must fall back to the landing
    // page rather than empty the navigator. The same pattern as the shell's
    // exit confirmation (AppShellRoot).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _close();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(child: _buildBody(context, l)),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            AppLocalizations.of(
              context,
            ).caseDetailsScreen_loadError('$_loadError'),
          ),
        ),
      );
    }
    final current = _current;
    if (current == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.caseDetailsScreen_caseNotFound),
            const SizedBox(height: AppSpacing.md),
            _headerButton(
              key: const ValueKey('case-detail-close'),
              icon: Icons.close,
              label: l.caseDetailsScreen_close,
              onPressed: _close,
            ),
          ],
        ),
      );
    }
    // Horizontal margins stay a static Padding (the ListView's horizontal
    // padding was static too); the top/bottom insets are sliver spacers so
    // they scroll away exactly like the previous ListView padding did.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: RefreshIndicator(
        onRefresh: () => pullCaseListToSync(ref, _load),
        // CustomScrollView (sliver twin of the previous ListView) so the
        // expanded Case History title can pin to the top via
        // [PinnedHeaderSliver].
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            SliverToBoxAdapter(child: _buildHeader(context, l, current)),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            SliverToBoxAdapter(child: _buildPartiesCard(context, l, current)),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            SliverToBoxAdapter(
              child: _buildDescriptionCard(context, l, current),
            ),
            if (_isHigherCourt) ...[
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
              SliverToBoxAdapter(
                child: _buildOtherInformationCard(context, l, current),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            // The history title pins to the top only while every entry is
            // expanded; collapsed stays a plain card (see [_buildHistoryBody]).
            if (_showAllHistory && _history.length > 3)
              PinnedHeaderSliver(
                child: _historyCardTitle(context, l, _history.length),
              ),
            _buildHistoryBody(context, l, current),
            if (current.nextDate != null) ...[
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
              SliverToBoxAdapter(
                child: _buildNextDateCard(context, l, current),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxxl)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l, Case current) {
    final court = _court;
    final trimmedJudges = current.honorableJudges?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // L1: case type and case number in big font.
        Text(
          '${context.l10n.caseTypeLabel(current.caseType, courtCategoryId: court?.courtCategoryId)} ${current.caseNumber}',
          key: const ValueKey('case-detail-case-number'),
          style: AppTypography.headlineMd,
        ),
        const SizedBox(height: AppSpacing.xs),
        // L2: court icon + court name; AD/HCD only: judges names line.
        if (court != null) ...[
          Row(
            children: [
              // The courthouse glyph the Overdue Dates court title uses (user
              // request, 0.0.723).
              const Icon(Icons.account_balance, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  _courtLabel(context, court),
                  style: AppTypography.bodyLg.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (_isHigherCourt &&
              trimmedJudges != null &&
              trimmedJudges.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              trimmedJudges,
              key: const ValueKey('case-detail-judges'),
              style: AppTypography.bodyLg.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
        ],
        // L3: Delete / Edit / Print / Close — icon-only, one evenly spaced row.
        // The labels used to make this a `Wrap` that broke onto two lines; they
        // now live on as each button's tooltip and semantics label. The four
        // equal slots keep the icons on one line at an even distance, each button
        // takes 70% of its slot (so the icons are not full-width bars), and the
        // slot gap is 48% of `AppSpacing.sm` — the original 8 pt cut 40% and then
        // 20% again, from 4.8 to 3.84 pt.
        Row(
          children: [
            _headerAction(
              key: const ValueKey('case-detail-delete'),
              icon: Icons.delete_outline,
              label: l.caseDetailsScreen_delete,
              backgroundColor: AppColors.error,
              onPressed: _canEdit ? _confirmDeleteCase : null,
            ),
            const SizedBox(width: AppSpacing.sm * 0.48),
            _headerAction(
              key: const ValueKey('case-detail-edit'),
              icon: Icons.edit_outlined,
              label: l.sharedActions_edit,
              onPressed: _openEditCase,
            ),
            const SizedBox(width: AppSpacing.sm * 0.48),
            _headerAction(
              key: const ValueKey('case-detail-print'),
              icon: Icons.print_outlined,
              label: l.nav_print,
              onPressed: () => _print(context),
            ),
            const SizedBox(width: AppSpacing.sm * 0.48),
            _headerAction(
              key: const ValueKey('case-detail-close'),
              icon: Icons.close,
              label: l.caseDetailsScreen_close,
              onPressed: _close,
            ),
          ],
        ),
      ],
    );
  }

  /// L4 — Parties KanBan card.
  Widget _buildPartiesCard(
    BuildContext context,
    AppLocalizations l,
    Case current,
  ) {
    final clientSide = _onBehalf == null ? null : representedSideOf(_onBehalf);
    final clientPhone = current.partyPhone?.trim();
    return _kanbanCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_onBehalf != null) ...[
            Row(
              children: [
                Text(
                  '${l.caseDetailsScreen_onBehalfOf}: ',
                  style: AppTypography.titleMd.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                Flexible(
                  child: Text(
                    _roleLabel(context, _onBehalf!),
                    key: const ValueKey('case-detail-on-behalf-role'),
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _partyBox(
            context,
            l: l,
            side: PartySide.petitioner,
            isClient: clientSide == PartySide.petitioner,
            partyKey: const ValueKey('case-detail-party-petitioner'),
            title: l.caseDetailsScreen_petitioner,
            name: current.petitioner,
            counsel: current.petitionerLeadCounsel,
            phone: clientSide == PartySide.petitioner ? clientPhone : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          _partyBox(
            context,
            l: l,
            side: PartySide.respondent,
            isClient: clientSide == PartySide.respondent,
            partyKey: const ValueKey('case-detail-party-respondent'),
            title: l.caseDetailsScreen_respondent,
            name: current.respondent,
            counsel: current.respondentLeadCounsel,
            phone: clientSide == PartySide.respondent ? clientPhone : null,
          ),
        ],
      ),
    );
  }

  Widget _partyBox(
    BuildContext context, {
    required AppLocalizations l,
    required PartySide side,
    required bool isClient,
    required Key partyKey,
    required String title,
    required String name,
    required String? counsel,
    required String? phone,
  }) {
    final titleColor = side == PartySide.petitioner
        ? AppColors.secondary
        : AppColors.error;
    final trimmedCounsel = counsel?.trim();
    final trimmedPhone = isClient ? phone?.trim() : null;
    return Column(
      key: partyKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.person, size: 20),
            const SizedBox(width: AppSpacing.xs),
            Text(
              title,
              style: AppTypography.titleMd.copyWith(color: titleColor),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                name,
                style: AppTypography.bodyLg.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (trimmedCounsel != null && trimmedCounsel.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${l.caseDetailsScreen_leadCounsel}: $trimmedCounsel',
                  style: AppTypography.bodySm,
                ),
              ],
              if (trimmedPhone != null && trimmedPhone.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Divider(
                    height: 1,
                    color: AppColors.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    _contactIcon(
                      context,
                      key: const ValueKey('case-detail-party-phone'),
                      icon: Icons.call_outlined,
                      tooltip: l.caseDetailsScreen_phone,
                      onTap: () => _contact(message: false),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _contactIcon(
                      context,
                      key: const ValueKey('case-detail-party-message'),
                      icon: Icons.chat_outlined,
                      tooltip: l.caseDetailsScreen_message,
                      onTap: () => _contact(message: true),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        trimmedPhone,
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _contactIcon(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        key: key,
        radius: 18,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 18, color: AppColors.onSurfaceVariant),
        ),
      ),
    );
  }

  /// AD/HCD-only card between Case Title & Remark and Case History: shows
  /// Tender Number, Previous Court Case, and District of Origin.
  Widget _buildOtherInformationCard(
    BuildContext context,
    AppLocalizations l,
    Case current,
  ) {
    return _kanbanCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l.caseDetailsScreen_otherInformation,
                  key: const ValueKey('case-detail-other-information'),
                  style: AppTypography.titleMd,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _descriptionBox(
            key: const ValueKey('case-detail-tender-number-box'),
            label: l.caseDetailsScreen_tenderNumber,
            value: current.tenderNumber,
          ),
          const SizedBox(height: AppSpacing.md),
          _descriptionBox(
            key: const ValueKey('case-detail-previous-court-case-box'),
            label: l.caseDetailsScreen_previousCourtCase,
            value: current.previousCourtCase,
          ),
          const SizedBox(height: AppSpacing.md),
          _descriptionBox(
            key: const ValueKey('case-detail-district-of-origin-box'),
            label: l.caseDetailsScreen_districtOfOrigin,
            value: current.districtOfOrigin,
          ),
        ],
      ),
    );
  }

  /// L5 — Case Title & Remark KanBan card.
  Widget _buildDescriptionCard(
    BuildContext context,
    AppLocalizations l,
    Case current,
  ) {
    return _kanbanCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.sticky_note_2, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l.caseDetailsScreen_caseTitleAndRemark,
                  style: AppTypography.titleMd,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _descriptionBox(
            key: const ValueKey('case-detail-case-title-box'),
            label: l.caseDetailsScreen_sectionsOrCaseTitle,
            value: current.caseTitleAndSection,
          ),
          const SizedBox(height: AppSpacing.md),
          _descriptionBox(
            key: const ValueKey('case-detail-case-remarks-box'),
            label: l.caseDetailsScreen_remarksOrCaseSummary,
            value: current.caseRemarks,
          ),
        ],
      ),
    );
  }

  Widget _descriptionBox({
    required Key key,
    required String label,
    required String? value,
  }) {
    final trimmed = value?.trim();
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppTypography.labelLg),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          ),
          child: (trimmed == null || trimmed.isEmpty)
              ? Text(
                  '—',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.outline,
                  ),
                )
              : Text(trimmed, style: AppTypography.bodyMd),
        ),
      ],
    );
  }

  /// L6 — Case History KanBan card.
  ///
  /// Collapsed (default): one bordered card with the title row on top. When
  /// every entry is expanded, the title row is instead pinned above this body
  /// by `_buildBody` (PinnedHeaderSliver) and only the entries live here, so
  /// the title stays visible while the user scrolls the long list.
  Widget _buildHistoryBody(
    BuildContext context,
    AppLocalizations l,
    Case current,
  ) {
    final history = _history;
    final expanded = _showAllHistory && history.length > 3;
    final visible = expanded || history.length <= 3
        ? history
        : history.sublist(0, 3);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              l.caseDetailsScreen_noHistoryEntries,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          )
        else ...[
          for (final entry in visible) _historyEntry(context, l, entry),
        ],
      ],
    );
    if (expanded) {
      // Expanded: the pinned title supplies the top edge; only the bottom
      // corners belong to this body.
      return SliverToBoxAdapter(
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            border: Border(
              left: BorderSide(color: AppColors.cardBorder),
              right: BorderSide(color: AppColors.cardBorder),
              bottom: BorderSide(color: AppColors.cardBorder),
            ),
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(AppSpacing.sheetRadius),
            ),
          ),
          child: body,
        ),
      );
    }
    // Collapsed: the original single KanBan card with the title row on top.
    return SliverToBoxAdapter(
      child: _kanbanCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _historyCardTitle(context, l, history.length),
            const Divider(height: 1, color: AppColors.cardBorder),
            body,
          ],
        ),
      ),
    );
  }

  /// Case History title row: icon + label, entry count, and the Show/Hide
  /// toggle (only when there are more than the 3 collapsed entries).
  Widget _historyCardTitle(
    BuildContext context,
    AppLocalizations l,
    int total,
  ) {
    final canToggle = total > 3;
    return Container(
      color: AppColors.surfaceContainerLowest,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          const Icon(Icons.history, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l.caseDetailsScreen_caseHistory,
              style: AppTypography.titleMd,
            ),
          ),
          Text(
            l.caseDetailsScreen_entriesTotal(total),
            key: const ValueKey('case-detail-history-total'),
            style: AppTypography.labelMd,
          ),
          if (canToggle) ...[
            const SizedBox(width: AppSpacing.sm),
            InkWell(
              key: const ValueKey('case-detail-history-show-hide'),
              onTap: () => setState(() => _showAllHistory = !_showAllHistory),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                ),
                child: Text(
                  _showAllHistory
                      ? l.caseDetailsScreen_hideHistory
                      : l.caseDetailsScreen_showHistory,
                  key: ValueKey(
                    'case-detail-history-${_showAllHistory ? 'hide' : 'show'}-label',
                  ),
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _historyEntry(
    BuildContext context,
    AppLocalizations l,
    CaseHistoryRow entry,
  ) {
    final trimmedStep = entry.lastStep?.trim();
    final trimmedNote = entry.noteResult?.trim();
    // AD/HCD cases have no Steps; their per-hearing outcome is the Result
    // snapshot, shown in the same slot where lower-court rows show Step.
    final trimmedResult = entry.result?.trim();
    // Who added this entry, and only inside a chamber (firm-mode §9.9): the
    // author is read from the row's own `created_by`, which the server writes as
    // the authenticated account, and the name from this device's own cache.
    final chamber = ref.watch(firmModeProvider);
    final authorName = chamber
        ? ref.watch(accountDisplayNameProvider(entry.createdBy)).value
        : null;
    // Steps are stored by name, so they need the language lookup; an AD/HCD
    // case's free-text Result is shown as it was typed.
    final mainContent = _isHigherCourt
        ? trimmedResult
        : context.l10n.stepNames(
            trimmedStep,
            courtCategoryId: _court?.courtCategoryId,
          );
    final content = Container(
      key: ValueKey('case-detail-history-entry-${entry.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      // The height must be known before the divider can stretch to it; the
      // history card sits in a scrolling column, whose height is unbounded.
      child: IntrinsicHeight(
        child: Row(
          // Stretch gives the divider the row's full height, so its own
          // centring puts it halfway down the card (user request, 0.0.725).
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              // The date block is as wide as its own date text, so the bar can
              // sit halfway between it and the step; IntrinsicWidth gives the
              // inner stretch a bounded width to centre the weekday in.
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatHistoryDate(l, entry.hearingDate),
                      style: AppTypography.caseNumber,
                    ),
                    const SizedBox(height: 2),
                    // Weekday sits centered under the date within the date
                    // column.
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        _formatHistoryWeekday(l, entry.hearingDate),
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // The bar sits halfway between the date and the step, in a gap the
            // width of the old visible spacing, and centres itself vertically
            // (user request, 0.0.725).
            const SizedBox(
              width: AppSpacing.xl,
              child: Center(
                child: Text(
                  '|',
                  style: TextStyle(fontSize: 14, color: AppColors.outline),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (mainContent != null && mainContent.isNotEmpty)
                    // Step/Result and its note read as one line while both fit;
                    // the note moves under the step as a whole when they do not
                    // (user request, 0.0.725). The step stays bold and the note
                    // stays muted, as the note line always read.
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.xs,
                      runSpacing: 2,
                      children: [
                        Text(
                          mainContent,
                          style: AppTypography.bodyMd.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.left,
                        ),
                        if (trimmedNote != null && trimmedNote.isNotEmpty)
                          Text(
                            '($trimmedNote)',
                            style: AppTypography.bodyMd.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.left,
                          ),
                      ],
                    )
                  else if (trimmedNote != null && trimmedNote.isNotEmpty)
                    Text(
                      trimmedNote,
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.left,
                    )
                  else
                    Text(
                      '—',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.outline,
                      ),
                    ),
                  // Drawn **only inside a chamber**, where several people write
                  // one case's history and its entries would otherwise be
                  // indistinguishable from each other. On an individual device
                  // every entry is this account's own, so the line would repeat
                  // one name down the whole list — the same reason the roster and
                  // the delete-request requester are chamber-only surfaces.
                  if (chamber) ...[
                    const SizedBox(height: AppSpacing.xs),
                    AttributionLine(
                      // The name alone, without an "Added By" prefix (user
                      // request, 0.0.724). `profiles` caches this account's own
                      // row alone (rule 4), so a colleague's name is not here and
                      // the neutral label stands in for it rather than a wrong
                      // name or a raw id.
                      label: authorName ?? l.sharedLabels_chamberMember,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
    // Long-press opens the Edit/Delete option sheet; write actions require
    // edit permission so the gesture is inert for read-only members.
    return GestureDetector(
      onLongPress: _canEdit ? () => _showHistoryActions(entry) : null,
      child: content,
    );
  }

  /// Mockup Next Date highlight card (mobile extra).
  Widget _buildNextDateCard(
    BuildContext context,
    AppLocalizations l,
    Case current,
  ) {
    final nextDate = current.nextDate;
    if (nextDate == null) return const SizedBox.shrink();
    final daysUntil = _daysUntil(nextDate);
    // A date already behind today is the case's previous hearing, not its next
    // one (user request, 0.0.722).
    final isPast = daysUntil < 0;
    final stepOrResult = current.lastStep?.trim().isNotEmpty == true
        ? context.l10n.stepNames(
            current.lastStep,
            courtCategoryId: _court?.courtCategoryId,
          )
        : (current.result?.trim().isNotEmpty == true ? current.result! : null);
    final note = current.notesResults?.trim();
    // The note rides the step in parentheses, the way the case cards read it
    // (user request, 0.0.724).
    final stepLine = stepOrResult == null || note == null || note.isEmpty
        ? stepOrResult
        : '$stepOrResult ($note)';
    final white = AppColors.onSecondaryContainer;
    return Container(
      key: const ValueKey('case-detail-next-date-card'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: _nextDateCardBlue,
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        // Same blue as the fill, so it reads as a seamless edge rather than the
        // dark rim the shared active black would draw on it.
        border: Border.all(color: _nextDateCardBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                // The card's own calendar glyph; the court's courthouse icon
                // belongs to the header line above (user request, 0.0.723).
                Icons.calendar_today,
                size: 16,
                color: white.withValues(alpha: 0.8),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                // Title Case from the ARB; a date behind today reads as the
                // previous one.
                isPast ? l.caseCard_previousDate : l.caseCard_nextDate,
                style: AppTypography.labelLg.copyWith(
                  color: white.withValues(alpha: 0.8),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _formatHighlightDate(l, nextDate),
            key: const ValueKey('case-detail-next-date-value'),
            style: AppTypography.headlineLg.copyWith(
              color: white,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (stepLine != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              stepLine,
              style: AppTypography.titleMd.copyWith(
                color: white.withValues(alpha: 0.9),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Divider(height: 1, color: white.withValues(alpha: 0.2)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  isPast
                      ? l.caseDetailsScreen_daysAgo(-daysUntil)
                      : l.caseDetailsScreen_daysRemaining(daysUntil),
                  key: const ValueKey('case-detail-days-remaining'),
                  style: AppTypography.labelMd.copyWith(color: white),
                ),
              ),
              FilledButton(
                key: const ValueKey('case-detail-set-reminder'),
                style: FilledButton.styleFrom(
                  backgroundColor: white,
                  foregroundColor: AppColors.secondaryContainer,
                  visualDensity: VisualDensity.compact,
                  shape: const StadiumBorder(),
                  textStyle: AppTypography.labelMd.copyWith(
                    color: AppColors.secondaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: _openReminderUpdate,
                // The same window either way; only the word changes, because a
                // passed hearing is updated rather than reminded (user request,
                // 0.0.723).
                child: Text(
                  isPast
                      ? l.sharedActions_update
                      : l.caseDetailsScreen_setReminder,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
