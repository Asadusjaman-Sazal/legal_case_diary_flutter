/// Case detail screen: KanBan cards for Parties, Case Description, and Case
/// History, plus the mockup Next Date highlight card.
///
/// Task 10 Phase 1. Opened from any case card via `/case-detail/:caseId`.
/// Loads the case, its court and on-behalf role, and its history through the
/// local repositories/DAOs and reloads after every returning dialog.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/pre_seeded_data.dart';
import '../../../../core/l10n/app_translations.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../database/app_database.dart';
import '../../../../features/cases/data/local/case_history_dao.dart';
import '../../../../features/settings/data/local/courts_dao.dart';
import '../../../../features/settings/data/local/on_behalfs_dao.dart';
import '../../../../shared/providers/database_provider.dart';
import '../../../../shared/widgets/add_edit_case_sheet.dart';
import '../../../../shared/widgets/confirm_dialogs.dart';
import 'history_entry_edit_dialog.dart';

/// Launch targets offered by the Phone/Message contact chooser.
enum _ContactActionTarget { whatsApp, phone, message }

/// Side of a case a party sits on; the single stored `party_phone` is the
/// represented client's phone and is shown only inside that party's block.
enum _PartySide { petitioner, respondent }

/// Long-press action chosen from a history item's option sheet.
enum _HistoryEntryAction { edit, delete }

/// Maps a seeded on-behalf role id to the party side it represents.
///
/// Only roles with an unambiguous procedural side are mapped. Unknown or
/// ambiguous roles (e.g. custom rows) resolve to null so a stored phone is
/// never mislabelled as belonging to a party.
///
/// ponytail: extended when the Task 07 two-column `petitioner_phone` /
/// `respondent_phone` realignment lands, at which point per-party display no
/// longer needs a side guess.
_PartySide? _representedSideOf(OnBehalf role) {
  final id = role.id;
  final slug = id.substring(id.lastIndexOf('-') + 1);
  switch (slug) {
    case 'petitioner':
    case 'plaintiff':
    case 'appellant':
    case 'revisioner':
    case 'reviewer':
    case 'decree_holder':
      return _PartySide.petitioner;
    case 'respondent':
    case 'defendant':
    case 'accused':
    case 'judgement_debtor':
      return _PartySide.respondent;
    default:
      return null;
  }
}

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
    await AddEditCaseSheet.show<void>(context, initialCase: current);
    if (mounted) await _load();
  }

  Future<void> _openReminderUpdate() async {
    final current = _current;
    if (current == null) return;
    await QuickUpdateCaseDialog.show(context, current, canEdit: _canEdit);
    if (mounted) await _load();
  }

  Future<void> _confirmDeleteCase() async {
    final current = _current;
    if (current == null || !_canEdit) return;
    final confirmed = await confirmDeleteDialog(context);
    if (!confirmed || !mounted) return;
    try {
      final repository = await ref.read(caseRepositoryProvider.future);
      await repository.deleteCase(current);
      if (!mounted) return;
      Navigator.of(context).pop();
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
    await HistoryEntryEditDialog.show(context, entry: entry, caseData: current);
    if (mounted) await _load();
  }

  Future<void> _confirmDeleteHistory(CaseHistoryRow entry) async {
    final confirmed = await confirmDeleteDialog(context);
    if (!confirmed || !mounted) return;
    try {
      final repository = await ref.read(caseHistoryRepositoryProvider.future);
      await repository.deleteHistory(entry);
      if (mounted) await _load();
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

  Future<void> _launchPartyContact(
    String? phone, {
    required bool message,
  }) async {
    final value = phone?.trim();
    if (value == null || value.isEmpty) return;
    final l = AppLocalizations.of(context);

    final target = await showDialog<_ContactActionTarget>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.casesContact_openWith),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: ValueKey(
                'case-detail-${message ? 'message' : 'call'}-whatsapp',
              ),
              leading: const Icon(Icons.chat_outlined),
              title: Text(l.casesContact_whatsapp),
              onTap: () =>
                  Navigator.of(context).pop(_ContactActionTarget.whatsApp),
            ),
            ListTile(
              key: ValueKey(
                'case-detail-${message ? 'message' : 'call'}-native',
              ),
              leading: Icon(message ? Icons.sms_outlined : Icons.call_outlined),
              title: Text(
                message
                    ? l.caseDetailsScreen_message
                    : l.caseDetailsScreen_phone,
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
            key: ValueKey('case-detail-${message ? 'message' : 'call'}-cancel'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.sharedDialogs_cancel),
          ),
        ],
      ),
    );
    if (!mounted || target == null) return;

    String failureMessage = l.casesContact_unableToOpenApp;
    try {
      if (target == _ContactActionTarget.whatsApp) {
        final normalized = value.replaceAll(RegExp(r'\D'), '');
        if (normalized.isEmpty) return;
        failureMessage = l.casesContact_unableToOpenWhatsApp;
        final launched = await launchUrl(
          Uri.https('wa.me', normalized),
          mode: LaunchMode.externalApplication,
        );
        if (!launched && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failureMessage)));
        }
      } else {
        failureMessage = target == _ContactActionTarget.phone
            ? l.casesContact_unableToCall
            : l.casesContact_unableToMessage;
        final launched = await launchUrl(
          Uri(
            scheme: target == _ContactActionTarget.phone ? 'tel' : 'sms',
            path: value,
          ),
          mode: LaunchMode.externalApplication,
        );
        if (!launched && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failureMessage)));
        }
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }

  // -------------------------------------------------------------------------
  // Build helpers
  // -------------------------------------------------------------------------

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
  int _daysUntil(int nextDateMs) {
    final target = AppDateUtils.normalizeToBangladeshStartOfDay(nextDateMs);
    final days =
        (target - AppDateUtils.bangladeshTodayStartOfDay()) ~/
        Duration.millisecondsPerDay;
    return days < 0 ? 0 : days;
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
  }) {
    return FilledButton.icon(
      key: key,
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        ),
        textStyle: AppTypography.labelLg.copyWith(color: foregroundColor),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: _buildBody(context, l)),
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
              onPressed: () => Navigator.of(context).pop(),
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
        onRefresh: _load,
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
        // L2: location icon + court name; AD/HCD only: judges names line.
        if (court != null) ...[
          Row(
            children: [
              const Icon(Icons.location_on, size: 18),
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
        // L3: Delete / Edit Case / Close actions.
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _headerButton(
              key: const ValueKey('case-detail-delete'),
              icon: Icons.delete_outline,
              label: l.caseDetailsScreen_delete,
              backgroundColor: AppColors.error,
              onPressed: _canEdit ? _confirmDeleteCase : null,
            ),
            _headerButton(
              key: const ValueKey('case-detail-edit'),
              icon: Icons.edit_outlined,
              label: l.caseDetailsScreen_editCase,
              onPressed: _openEditCase,
            ),
            _headerButton(
              key: const ValueKey('case-detail-close'),
              icon: Icons.close,
              label: l.caseDetailsScreen_close,
              onPressed: () => Navigator.of(context).pop(),
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
    final clientSide = _onBehalf == null
        ? null
        : _representedSideOf(_onBehalf!);
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
            side: _PartySide.petitioner,
            isClient: clientSide == _PartySide.petitioner,
            partyKey: const ValueKey('case-detail-party-petitioner'),
            title: l.caseDetailsScreen_petitioner,
            name: current.petitioner,
            counsel: current.petitionerLeadCounsel,
            phone: clientSide == _PartySide.petitioner ? clientPhone : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          _partyBox(
            context,
            l: l,
            side: _PartySide.respondent,
            isClient: clientSide == _PartySide.respondent,
            partyKey: const ValueKey('case-detail-party-respondent'),
            title: l.caseDetailsScreen_respondent,
            name: current.respondent,
            counsel: current.respondentLeadCounsel,
            phone: clientSide == _PartySide.respondent ? clientPhone : null,
          ),
        ],
      ),
    );
  }

  Widget _partyBox(
    BuildContext context, {
    required AppLocalizations l,
    required _PartySide side,
    required bool isClient,
    required Key partyKey,
    required String title,
    required String name,
    required String? counsel,
    required String? phone,
  }) {
    final titleColor = side == _PartySide.petitioner
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
                      onTap: () =>
                          _launchPartyContact(trimmedPhone, message: false),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _contactIcon(
                      context,
                      key: const ValueKey('case-detail-party-message'),
                      icon: Icons.chat_outlined,
                      tooltip: l.caseDetailsScreen_message,
                      onTap: () =>
                          _launchPartyContact(trimmedPhone, message: true),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatHistoryDate(l, entry.hearingDate),
                    style: AppTypography.caseNumber,
                  ),
                  const SizedBox(height: 2),
                  // Weekday sits centered under the date within the date column.
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
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (mainContent != null && mainContent.isNotEmpty)
                  // Step/Result span the full content width and read left
                  // aligned (Google Keep style). Same size as the Note (14/20)
                  // but kept bold.
                  Text(
                    mainContent,
                    style: AppTypography.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.left,
                  ),
                if ((mainContent == null || mainContent.isEmpty) &&
                    (trimmedNote == null || trimmedNote.isEmpty))
                  Text(
                    '—',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.outline,
                    ),
                  ),
                if (trimmedNote != null && trimmedNote.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    trimmedNote,
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ],
              ],
            ),
          ),
        ],
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
    final stepOrResult = current.lastStep?.trim().isNotEmpty == true
        ? context.l10n.stepNames(
            current.lastStep,
            courtCategoryId: _court?.courtCategoryId,
          )
        : (current.result?.trim().isNotEmpty == true ? current.result! : null);
    final white = AppColors.onSecondaryContainer;
    return Container(
      key: const ValueKey('case-detail-next-date-card'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        border: Border.all(color: AppColors.secondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 16,
                color: white.withValues(alpha: 0.8),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l.caseCard_nextDate.toUpperCase(),
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
          if (stepOrResult != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              stepOrResult,
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
                  l.caseDetailsScreen_daysRemaining(_daysUntil(nextDate)),
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
                child: Text(l.caseDetailsScreen_setReminder),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
