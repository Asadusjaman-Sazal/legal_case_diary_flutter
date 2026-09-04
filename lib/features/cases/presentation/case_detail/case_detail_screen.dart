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
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.sharedDialogs_confirmDeleteTitle),
        content: Text(l.sharedDialogs_confirmDeleteMessage),
        actions: [
          TextButton(
            key: const ValueKey('case-detail-delete-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.sharedDialogs_cancel),
          ),
          FilledButton(
            key: const ValueKey('case-detail-delete-confirm'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.sharedActions_delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final repository = await ref.read(caseRepositoryProvider.future);
      await repository.deleteCase(current);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete the case: $error')),
      );
    }
  }

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
              onTap: () => Navigator.of(sheetContext).pop(
                _HistoryEntryAction.edit,
              ),
            ),
            ListTile(
              key: const ValueKey('history-action-delete'),
              leading: Icon(Icons.delete_outline, color: AppColors.error),
              title: Text(
                l.sharedActions_delete,
                style: AppTypography.titleMd.copyWith(color: AppColors.error),
              ),
              onTap: () => Navigator.of(sheetContext).pop(
                _HistoryEntryAction.delete,
              ),
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
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.sharedDialogs_confirmDeleteTitle),
        content: Text(l.sharedDialogs_confirmDeleteMessage),
        actions: [
          TextButton(
            key: const ValueKey('history-delete-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.sharedDialogs_cancel),
          ),
          FilledButton(
            key: const ValueKey('history-delete-confirm'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.sharedActions_delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final repository = await ref.read(caseHistoryRepositoryProvider.future);
      await repository.deleteHistory(entry);
      if (mounted) await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete the history entry: $error')),
      );
    }
  }

  Future<void> _launchPartyContact(String? phone, {required bool message}) async {
    final value = phone?.trim();
    if (value == null || value.isEmpty) return;
    final l = AppLocalizations.of(context);

    final target = await showDialog<_ContactActionTarget>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open with'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: ValueKey('case-detail-${message ? 'message' : 'call'}-whatsapp'),
              leading: const Icon(Icons.chat_outlined),
              title: const Text('WhatsApp'),
              onTap: () =>
                  Navigator.of(context).pop(_ContactActionTarget.whatsApp),
            ),
            ListTile(
              key: ValueKey('case-detail-${message ? 'message' : 'call'}-native'),
              leading: Icon(message ? Icons.sms_outlined : Icons.call_outlined),
              title: Text(message ? l.caseDetailsScreen_message : l.caseDetailsScreen_phone),
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

    String failureMessage = 'Unable to open the app.';
    try {
      if (target == _ContactActionTarget.whatsApp) {
        final normalized = value.replaceAll(RegExp(r'\D'), '');
        if (normalized.isEmpty) return;
        failureMessage = 'Unable to open WhatsApp.';
        final launched = await launchUrl(
          Uri.https('wa.me', normalized),
          mode: LaunchMode.externalApplication,
        );
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failureMessage)),
          );
        }
      } else {
        failureMessage = target == _ContactActionTarget.phone
            ? 'Unable to place a call.'
            : 'Unable to open messages.';
        final launched = await launchUrl(
          Uri(
            scheme: target == _ContactActionTarget.phone ? 'tel' : 'sms',
            path: value,
          ),
          mode: LaunchMode.externalApplication,
        );
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failureMessage)),
          );
        }
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage)),
      );
    }
  }

  // -------------------------------------------------------------------------
  // Build helpers
  // -------------------------------------------------------------------------

  String _courtLabel(BuildContext context, Court court) =>
      context.l10n.seedLabel(court.id, fallbackEn: court.courtName);

  String _roleLabel(BuildContext context, OnBehalf role) =>
      context.l10n.seedLabel(role.id, fallbackEn: role.name);

  String _formatHistoryDate(AppLocalizations l, int epochMs) =>
      DateFormat('d MMM y', l.localeName)
          .format(AppDateUtils.bangladeshDateTime(epochMs));

  String _formatHighlightDate(AppLocalizations l, int epochMs) =>
      DateFormat('d MMM y, EEEE', l.localeName)
          .format(AppDateUtils.bangladeshDateTime(epochMs));

  /// Whole civil days between the Bangladesh start of today and [nextDateMs].
  int _daysUntil(int nextDateMs) {
    final target = AppDateUtils.normalizeToBangladeshStartOfDay(nextDateMs);
    final days = (target - AppDateUtils.bangladeshTodayStartOfDay()) ~/
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
          child: Text('Unable to load the case: $_loadError'),
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
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.xxxl,
        ),
        children: [
          _buildHeader(context, l, current),
          const SizedBox(height: AppSpacing.lg),
          _buildPartiesCard(context, l, current),
          const SizedBox(height: AppSpacing.lg),
          _buildDescriptionCard(context, l, current),
          const SizedBox(height: AppSpacing.lg),
          _buildHistoryCard(context, l, current),
          if (current.nextDate != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _buildNextDateCard(context, l, current),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l, Case current) {
    final court = _court;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // L1: case type and case number in big font.
        Text(
          '${current.caseType} ${current.caseNumber}',
          key: const ValueKey('case-detail-case-number'),
          style: AppTypography.headlineMd,
        ),
        const SizedBox(height: AppSpacing.xs),
        // L2: location icon + court name.
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
  Widget _buildPartiesCard(BuildContext context, AppLocalizations l, Case current) {
    final clientSide = _onBehalf == null ? null : _representedSideOf(_onBehalf!);
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
                  style: AppTypography.titleMd.copyWith(color: AppColors.onSurface),
                ),
                Flexible(
                  child: Text(
                    _roleLabel(context, _onBehalf!),
                    key: const ValueKey('case-detail-on-behalf-role'),
                    style: AppTypography.titleMd.copyWith(color: AppColors.onSurface),
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
    final titleColor =
        side == _PartySide.petitioner ? AppColors.secondary : AppColors.error;
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
                style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w700),
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
              ? Text('—', style: AppTypography.bodyMd.copyWith(color: AppColors.outline))
              : Text(trimmed, style: AppTypography.bodyMd),
        ),
      ],
    );
  }

  /// L6 — Case History KanBan card.
  Widget _buildHistoryCard(
    BuildContext context,
    AppLocalizations l,
    Case current,
  ) {
    final history = _history;
    final visible = _showAllHistory || history.length <= 3
        ? history
        : history.sublist(0, 3);
    return _kanbanCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
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
                  l.caseDetailsScreen_entriesTotal(history.length),
                  key: const ValueKey('case-detail-history-total'),
                  style: AppTypography.labelMd,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.cardBorder),
          if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                l.caseDetailsScreen_noHistoryEntries,
                style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
              ),
            )
          else ...[
            for (final entry in visible)
              _historyEntry(context, l, entry),
            if (!_showAllHistory && history.length > 3) ...[
              const Divider(height: 1, color: AppColors.cardBorder),
              _viewAllButton(context, l, history.length),
            ],
          ],
        ],
      ),
    );
  }

  Widget _historyEntry(BuildContext context, AppLocalizations l, CaseHistoryRow entry) {
    final trimmedStep = entry.lastStep?.trim();
    final trimmedNote = entry.noteResult?.trim();
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
              child: Text(
                _formatHistoryDate(l, entry.hearingDate),
                style: AppTypography.caseNumber,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (trimmedStep != null && trimmedStep.isNotEmpty)
                  Text(
                    trimmedStep,
                    style: AppTypography.titleMd,
                    textAlign: TextAlign.right,
                  ),
                if ((trimmedStep == null || trimmedStep.isEmpty) &&
                    (trimmedNote == null || trimmedNote.isEmpty))
                  Text(
                    '—',
                    style: AppTypography.bodySm.copyWith(color: AppColors.outline),
                  ),
                if (trimmedNote != null && trimmedNote.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    trimmedNote,
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
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

  Widget _viewAllButton(BuildContext context, AppLocalizations l, int total) {
    return InkWell(
      key: const ValueKey('case-detail-history-view-all'),
      onTap: () => setState(() => _showAllHistory = true),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        color: AppColors.surfaceContainerLow,
        alignment: Alignment.center,
        child: Text(
          l.caseDetailsScreen_viewAllHistory(total),
          style: AppTypography.labelLg.copyWith(color: AppColors.secondary),
        ),
      ),
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
        ? current.lastStep!
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
              Icon(Icons.calendar_today, size: 16, color: white.withValues(alpha: 0.8)),
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
