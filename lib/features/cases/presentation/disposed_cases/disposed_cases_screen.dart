/// Disposed cases screen: cases closed by a seeded Step or AD/HCD Result.
///
/// Task 08 Phase 5. No Add-Case FAB (cases cannot be re-opened here), but a
/// Help FAB opens the "How to set a case as disposed?" window. Cards use the
/// disposed variant, showing the disposal date, parties, final note, and the
/// last two case-history entries.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/pre_seeded_data.dart';
import '../../../../core/l10n/app_translations.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../database/app_database.dart';
import '../../../../features/settings/data/local/courts_dao.dart';
import '../../../../shared/providers/database_provider.dart';
import '../../../../shared/widgets/add_edit_case_sheet.dart';
import '../../../../shared/widgets/case_table_row.dart';
import '../case_list_view_mode.dart';
import '../case_search.dart';
import '../case_table_view.dart';
import '../cases_screen_modal.dart';
import 'disposed_help_dialog.dart';

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
  Object? _error;
  bool _loading = true;

  // Scoped search state (plan §12.1): the query filters this screen's own
  // disposed dataset only.
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

  /// The loaded disposed cases the query still matches.
  List<Case> get _visibleCases =>
      _cases.where((c) => matchesCaseQuery(c, _searchController.text)).toList();

  Future<void> _loadCases() async {
    try {
      final repository = await ref.read(caseRepositoryProvider.future);
      final db = await ref.read(databaseProvider.future);
      final cases = await repository.listDisposed();
      final courts = await CourtsDao(db).getAll();

      if (!mounted) return;
      setState(() {
        _cases = cases;
        _courtsById = {for (final court in courts) court.id: court};
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
    final extended = watchCaseListExtendedView(ref, CaseListScreenId.disposed);
    return CasesScreenModal(
      title: l.disposedCasesScreen_title,
      showFab: false,
      showHelpFab: true,
      onHelp: () => showDisposedHelpDialog(context),
      onSearch: _toggleSearch,
      isSearching: _isSearching,
      searchController: _searchController,
      onSearchChanged: (_) => setState(() {}),
      onViewToggle: (compact) => setCaseListViewMode(
        ref,
        screenId: CaseListScreenId.disposed,
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
        placeholder: l.disposedCasesScreen_title,
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
              ? _buildCaseCard(context, l, currentCase, court)
              : _buildCaseRow(
                  context,
                  l,
                  currentCase,
                  court,
                  index + 1,
                  widths,
                );
        },
      ),
    );

    return extended
        ? CaseTableView(
            dateLabel: l.caseTable_disposed,
            builder: (_, widths) => buildList(widths),
          )
        : buildList(null);
  }

  /// The compact disposed card for [currentCase].
  Widget _buildCaseCard(
    BuildContext context,
    AppLocalizations l,
    Case currentCase,
    Court? court,
  ) {
    final isHigherCourt =
        court?.courtCategoryId == appellateDivisionId ||
        court?.courtCategoryId == highCourtDivisionId;
    // Steps are stored by name, so they need the language lookup;
    // an AD/HCD case's free-text Result is shown as typed.
    final stepOrResult = currentCase.lastStep?.trim().isNotEmpty == true
        ? context.l10n.stepNames(
            currentCase.lastStep,
            courtCategoryId: court?.courtCategoryId,
          )
        : (currentCase.result?.trim().isNotEmpty == true
              ? currentCase.result!
              : null);
    final disposedDate = currentCase.nextDate == null
        ? null
        : AppDateUtils.formatDateDDMMYYYY(
            currentCase.nextDate!,
            locale: l.localeName,
          );
    return _DisposedCaseCard(
      key: ValueKey('case-card-${currentCase.id}'),
      stepOrResult: stepOrResult,
      caseNumber:
          '${context.l10n.caseTypeLabel(currentCase.caseType, courtCategoryId: court?.courtCategoryId)} ${currentCase.caseNumber}',
      parties: '${currentCase.petitioner} Vs ${currentCase.respondent}',
      title: currentCase.caseTitleAndSection,
      // A pre-seeded court stores its English name, so the card resolves it to
      // follow the active language.
      courtName: court == null
          ? null
          : context.l10n.seedLabel(court.id, fallbackEn: court.courtName),
      judgesName: isHigherCourt ? currentCase.honorableJudges : null,
      disposedDate: disposedDate,
      note: currentCase.notesResults,
      onPhone: () => _launchPartyAction(currentCase, message: false),
      onMessage: () => _launchPartyAction(currentCase, message: true),
      onUpdate: () => _openQuickUpdate(currentCase),
      onTap: () => _openCaseDetail(currentCase),
    );
  }

  /// The extended-view row for [currentCase]; [serial] is its 1-based position
  /// and [widths] the table's current column widths. One column per field, so
  /// the row carries every value the disposed card shows.
  Widget _buildCaseRow(
    BuildContext context,
    AppLocalizations l,
    Case currentCase,
    Court? court,
    int serial,
    Map<CaseTableColumn, double> widths,
  ) {
    final isHigherCourt =
        court?.courtCategoryId == appellateDivisionId ||
        court?.courtCategoryId == highCourtDivisionId;
    // The disposal is whichever of the two the card would have shown (a seeded
    // Step vs an AD/HCD free-text Result).
    final hasStep = currentCase.lastStep?.trim().isNotEmpty == true;
    final stepOrResult = hasStep
        ? context.l10n.stepNames(
            currentCase.lastStep,
            courtCategoryId: court?.courtCategoryId,
          )
        : (currentCase.result?.trim().isNotEmpty == true
              ? currentCase.result!
              : null);
    final disposedDate = currentCase.nextDate == null
        ? null
        : AppDateUtils.formatDateDDMMYYYY(
            currentCase.nextDate!,
            locale: l.localeName,
          );
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
      date: disposedDate,
      step: stepOrResult,
      note: currentCase.notesResults,
      onUpdate: () => _openQuickUpdate(currentCase),
      onTap: () => _openCaseDetail(currentCase),
    );
  }
}

/// Disposed-case card: a 7-line layout tuned for closed cases.
///
/// L1 Step/Result (light-gray chip) left, "Disposed:" right.
/// L2 Case Type & Number left, last Next Date right (under "Disposed:").
/// L3 Petitioner Vs Respondent. L4 Case Title/Section. L5 Court (judges for
/// higher courts). L6 Note in a quotation box. L7 call/message/update actions.
class _DisposedCaseCard extends StatelessWidget {
  const _DisposedCaseCard({
    super.key,
    required this.stepOrResult,
    required this.caseNumber,
    required this.parties,
    required this.title,
    required this.courtName,
    required this.judgesName,
    required this.disposedDate,
    required this.note,
    required this.onPhone,
    required this.onMessage,
    required this.onUpdate,
    this.onTap,
  });

  final String? stepOrResult;
  final String caseNumber;
  final String parties;
  final String? title;
  final String? courtName;
  final String? judgesName;
  final String? disposedDate;
  final String? note;
  final VoidCallback onPhone;
  final VoidCallback onMessage;
  final VoidCallback onUpdate;

  /// Called when the whole card is tapped (opens the case detail screen).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final trimmedNote = note?.trim();
    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // L1: Step/Result (light-gray) left, "Disposed:" right.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  stepOrResult?.isNotEmpty == true ? stepOrResult! : '—',
                  style: AppTypography.labelMd,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(l.caseCard_disposed, style: AppTypography.labelMd),
                  if (disposedDate != null)
                    Text(
                      disposedDate!,
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // L2: Case Type & Number.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(caseNumber, style: AppTypography.caseNumber),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // L3: Petitioner Vs Respondent.
          Text(parties, style: AppTypography.titleMd),
          const SizedBox(height: AppSpacing.xs),
          // L4: Case Title or Section.
          if (title?.trim().isNotEmpty == true)
            Text(title!, style: AppTypography.bodyMd),
          // L5: Name of Court.
          if (courtName != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(courtName!, style: AppTypography.bodySm),
            if (judgesName != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(judgesName!, style: AppTypography.bodySm),
            ],
          ],
          // L6: Note in a quotation box.
          if (trimmedNote != null && trimmedNote.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                border: Border(
                  left: BorderSide(color: AppColors.secondary, width: 4),
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                '"$trimmedNote"',
                style: AppTypography.bodyMd.copyWith(
                  fontStyle: FontStyle.italic,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          // L7: call, message, update.
          Row(
            children: [
              IconButton(
                tooltip: l.allCasesScreen_phone,
                onPressed: onPhone,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                ),
                icon: const Icon(Icons.call_outlined),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                tooltip: l.allCasesScreen_message,
                onPressed: onMessage,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                ),
                icon: const Icon(Icons.chat_outlined),
              ),
              const Spacer(),
              SizedBox(
                height: 40,
                child: FilledButton.icon(
                  onPressed: onUpdate,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(l.allCasesScreen_update),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) {
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          border: Border.all(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: content,
      );
    }
    return Material(
      color: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
