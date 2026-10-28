/// Case reference screen: precedents and citations library with navigation
/// panel, search, add/edit, pinning, and delete.
///
/// Task 11 Phase 2. Card layout mirrors the mandatory mockup
/// `mockup_html_screens/caseReference/code.html`. Uses [CasesScreenModal] for the
/// shared header (nav panel + search) and bottom nav, and a slide-up sheet for
/// add/edit (Google Keep style). Tapping a card opens the sheet to edit.
library;

import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/utils/scoped_search.dart';
import '../../../database/app_database.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../shared/widgets/pull_to_sync.dart';
import '../../../shared/widgets/read_only_lock.dart';
import '../../../sync/sync_service.dart';
import '../../accounts_and_profile/data/account_mode.dart';
import '../../cases/presentation/cases_screen_modal.dart';
import '../../payments/presentation/lapse_allowance_ui.dart';
import '../../settings/data/premium_access.dart';
import '../../settings/data/write_allowance.dart';
import '../../settings/presentation/delete_request_flow.dart';
import 'reference_viewmodel.dart';

/// Case reference library screen.
class CaseReferenceScreen extends ConsumerStatefulWidget {
  const CaseReferenceScreen({super.key});

  @override
  ConsumerState<CaseReferenceScreen> createState() =>
      _CaseReferenceScreenState();
}

class _CaseReferenceScreenState extends ConsumerState<CaseReferenceScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  /// The screen's live scoped search (Task 14 Phase 5, plan §12.1): the query
  /// runs as a Drift `LIKE` query across the reference's five text fields rather
  /// than filtering the rows this screen happened to have loaded.
  late final ScopedSearch<CaseReference> _search = ScopedSearch(
    fetch: _searchReferences,
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        unawaited(_search.run(''));
      }
    });
  }

  /// Runs one query through `CaseReferencesDao.search` (all five text fields).
  Future<List<CaseReference>> _searchReferences(String query) async {
    final repository = await ref.read(referenceRepositoryProvider.future);
    return repository.search(query);
  }

  /// Types into the bar: the query goes to SQL, then the library rebuilds.
  Future<void> _onSearchChanged(String query) async {
    await _search.run(query);
    if (mounted) setState(() {});
  }

  /// Opens the add/edit screen. [reference] is null when creating new.
  /// If the screen pops with a deleted [CaseReference], shows the undo snackbar.
  Future<void> _openSheet({CaseReference? reference}) async {
    final result = await Navigator.of(context).push<CaseReference?>(
      MaterialPageRoute(
        builder: (_) => _ReferenceEditSheet(reference: reference),
      ),
    );
    if (result is CaseReference && mounted) _showUndoSnackBar(result);
  }

  Future<void> _confirmDelete(CaseReference reference) async {
    // A member without delete permission raises a request instead of deleting
    // (plan §1, Associate Deletion Policy).
    final outcome = await deleteThroughFirmRules(
      context,
      ref,
      entityType: 'reference',
      entityId: reference.id,
      entitySnapshot: deleteRequestSnapshot(reference.toJson()),
      targetBaseVersion: deletionBaseVersion(reference.version),
      deleteDirectly: () async => await ref
          .read(referenceViewModelProvider.notifier)
          .deleteReference(reference),
    );
    if (!mounted || outcome != DeleteOutcome.deleted) return;
    _showUndoSnackBar(reference);
  }

  /// Shows a Google Keep–style undo snackbar after a reference is deleted.
  void _showUndoSnackBar(CaseReference reference) {
    final l = AppLocalizations.of(context);
    final controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.caseReferenceScreen_referenceDeleted),
        behavior: SnackBarBehavior.floating,
        width: 400,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: l.caseReferenceScreen_undo,
          onPressed: () => ref
              .read(referenceViewModelProvider.notifier)
              .restoreReference(reference),
        ),
      ),
    );
    // Enforce the 3s window even when the action button holds pointer focus
    // (desktop hover pauses the SnackBar's built-in auto-dismiss timer).
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) controller.close();
    });
  }

  void _togglePin(CaseReference reference) {
    // Pinning writes `updated_at`, which would pull a read-only reference back
    // into the allowance, so it meets the same boundary as an edit.
    if (!ensureReferenceWritable(context, ref, reference.id)) return;
    ref
        .read(referenceViewModelProvider.notifier)
        .setPinned(reference.id, !reference.isPinned);
  }

  /// Phase 10: a read-only reference explains itself instead of opening the
  /// editor.
  void _editIfWritable(CaseReference reference) {
    if (!ensureReferenceWritable(context, ref, reference.id)) return;
    _openSheet(reference: reference);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final referencesAsync = ref.watch(referenceViewModelProvider);

    final references = referencesAsync.value?.items ?? const <CaseReference>[];
    // The query's own rows while one is in force, otherwise the library.
    final visible = _search.rows ?? references;
    final allowance = ref.watch(writeAllowanceProvider).value;

    return CasesScreenModal(
      title: l.caseReferenceScreen_title,
      lapseKind: LapseRowKind.references,
      onSync: _onRefresh,
      onSearch: _toggleSearch,
      // The bar is mounted by the shared modal, exactly as on the case-list
      // screens: it sits under the header, above the scrolling list, and stays
      // there while the library is empty.
      isSearching: _isSearching,
      searchController: _searchController,
      onSearchChanged: _onSearchChanged,
      onAddCase: () => _openSheet(),
      // A short library must still be pullable, and the pull must not drag the
      // cards under the finger while the indicator spins.
      body: ScrollConfiguration(
        behavior: pullScrollBehavior(context),
        child: _ReferenceList(
          isSearching: _isSearching,
          references: visible,
          totalCount: references.length,
          writableReferenceIds: allowance?.writableReferenceIds,
          onEdit: _editIfWritable,
          onDelete: _confirmDelete,
          onTogglePin: _togglePin,
          onRefresh: _onRefresh,
        ),
      ),
    );
  }

  /// Pull-down-to-sync: the same forced drain the header button runs, then a
  /// reload so anything that arrived appears.
  ///
  /// Without the reload an empty Case Reference screen would spin and change
  /// nothing the user can see, which is the one case where pulling matters most.
  Future<void> _onRefresh() async {
    await ref.read(syncServiceProvider).retryNow();
    ref.invalidate(referenceViewModelProvider);
  }
}

/// Scrollable reference list; the search bar lives in the modal above it.
class _ReferenceList extends StatelessWidget {
  const _ReferenceList({
    required this.isSearching,
    required this.references,
    required this.totalCount,
    this.writableReferenceIds,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePin,
    required this.onRefresh,
  });

  final bool isSearching;
  final List<CaseReference> references;
  final int totalCount;

  /// References the allowance keeps editable, or null when every one is.
  final Set<String>? writableReferenceIds;

  final ValueChanged<CaseReference> onEdit;
  final ValueChanged<CaseReference> onDelete;
  final ValueChanged<CaseReference> onTogglePin;

  /// Pull-down-to-sync, so an empty list is still syncable.
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final children = <Widget>[];

    if (references.isEmpty) {
      // Nothing to list: one semibold message centred in the screen, exactly
      // like the case-list empty state on Active Cases. It sits in a scrollable
      // that always overscrolls, so an empty screen can still be pulled to
      // sync — a bare `Center` has nothing to drag.
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.6,
              child: Center(
                child: Text(
                  isSearching && totalCount > 0
                      ? l.sharedDialogs_noResults
                      : l.caseReferenceScreen_empty,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ],
        ),
      );
    }

    for (var i = 0; i < references.length; i++) {
      if (i > 0) children.add(const SizedBox(height: AppSpacing.md));
      final reference = references[i];
      children.add(
        _ReferenceCard(
          reference: reference,
          isReadOnly:
              writableReferenceIds != null &&
              !writableReferenceIds!.contains(reference.id),
          onEdit: () => onEdit(reference),
          onDelete: () => onDelete(reference),
          onTogglePin: () => onTogglePin(reference),
        ),
      );
    }
    children.add(const SizedBox(height: AppSpacing.lg));

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: children,
      ),
    );
  }
}

/// A single reference card matching the mandatory mockup layout.
class _ReferenceCard extends StatefulWidget {
  const _ReferenceCard({
    required this.reference,
    required this.isReadOnly,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePin,
  });

  final CaseReference reference;
  final bool isReadOnly;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;

  @override
  State<_ReferenceCard> createState() => _ReferenceCardState();
}

class _ReferenceCardState extends State<_ReferenceCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final reference = widget.reference;
    final borderColor = _hovered
        ? AppColors.secondary
        : AppColors.outlineVariant;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Card(
        elevation: _hovered ? 2 : 0,
        color: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onEdit,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // L1: reference & page no + statute chips, 3-dot menu on the right.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          _Chip(label: reference.referenceAndPageNo),
                          if (reference.statute != null &&
                              reference.statute!.isNotEmpty)
                            _Chip(label: reference.statute!),
                        ],
                      ),
                    ),
                    if (widget.isReadOnly) ...[
                      const ReadOnlyLock(),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    PopupMenuButton<String>(
                      key: const ValueKey('reference-menu'),
                      icon: const Icon(Icons.more_vert),
                      color: AppColors.surfaceContainerLowest,
                      onSelected: (value) {
                        if (value == 'pin') {
                          widget.onTogglePin();
                        } else if (value == 'delete') {
                          widget.onDelete();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem<String>(
                          key: const ValueKey('reference-pin'),
                          value: 'pin',
                          child: Row(
                            children: [
                              Icon(
                                reference.isPinned
                                    ? Icons.push_pin
                                    : Icons.push_pin_outlined,
                                size: 18,
                                color: AppColors.onSurfaceVariant,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                reference.isPinned
                                    ? AppLocalizations.of(
                                        context,
                                      ).caseReferenceScreen_unpin
                                    : AppLocalizations.of(
                                        context,
                                      ).caseReferenceScreen_pin,
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem<String>(
                          key: const ValueKey('reference-delete'),
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                AppLocalizations.of(
                                  context,
                                ).sharedActions_delete,
                                style: TextStyle(color: AppColors.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                // L2: section / article.
                if (reference.sectionOrArticle != null &&
                    reference.sectionOrArticle!.isNotEmpty)
                  Text(
                    reference.sectionOrArticle!,
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                // L3: title & description.
                if (reference.titleAndDescription != null &&
                    reference.titleAndDescription!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    reference.titleAndDescription!,
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
                // L4: comments / notes.
                if (reference.commentsNotes != null &&
                    reference.commentsNotes!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(color: AppColors.secondary, width: 4),
                      ),
                    ),
                    child: Text(
                      reference.commentsNotes!,
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small rounded chip used for the reference & page no and statute labels.
class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: AppColors.secondaryFixed,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: AppTypography.labelMd.copyWith(color: AppColors.primary),
    ),
  );
}

/// Slide-up sheet for adding or editing a case reference.
class _ReferenceEditSheet extends ConsumerStatefulWidget {
  const _ReferenceEditSheet({this.reference});

  final CaseReference? reference;

  @override
  ConsumerState<_ReferenceEditSheet> createState() =>
      _ReferenceEditSheetState();
}

class _ReferenceEditSheetState extends ConsumerState<_ReferenceEditSheet> {
  late final TextEditingController _refNoController;
  late final TextEditingController _statuteController;
  late final TextEditingController _sectionController;
  late final TextEditingController _titleController;
  late final TextEditingController _commentsController;
  late bool _isPinned;

  @override
  void initState() {
    super.initState();
    final r = widget.reference;
    _refNoController = TextEditingController(text: r?.referenceAndPageNo ?? '');
    _statuteController = TextEditingController(text: r?.statute ?? '');
    _sectionController = TextEditingController(text: r?.sectionOrArticle ?? '');
    _titleController = TextEditingController(
      text: r?.titleAndDescription ?? '',
    );
    _commentsController = TextEditingController(text: r?.commentsNotes ?? '');
    _isPinned = r?.isPinned ?? false;
    // Warn before editing a reference someone else has asked to delete.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final existing = widget.reference;
      if (existing == null || !mounted) return;
      final proceed = await confirmEditOfRequestedRecord(
        context,
        ref,
        entityType: 'reference',
        entityId: existing.id,
      );
      if (!proceed && mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _refNoController.dispose();
    _statuteController.dispose();
    _sectionController.dispose();
    _titleController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  bool get _isNew => widget.reference == null;

  Future<void> _save({bool deleting = false}) async {
    final l = AppLocalizations.of(context);
    final notifier = ref.read(referenceViewModelProvider.notifier);

    if (deleting && !_isNew) {
      final reference = widget.reference!;
      // The same decision point the list uses, so the delete button inside the
      // editor raises a request exactly as the swipe action does.
      final outcome = await deleteThroughFirmRules(
        context,
        ref,
        entityType: 'reference',
        entityId: reference.id,
        entitySnapshot: deleteRequestSnapshot(reference.toJson()),
        targetBaseVersion: deletionBaseVersion(reference.version),
        deleteDirectly: () async => await notifier.deleteReference(reference),
      );
      if (mounted && outcome == DeleteOutcome.deleted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.caseReferenceScreen_deleted)));
        Navigator.of(context).pop(reference);
      }
      return;
    }

    // A lapsed account may add only up to its reference allowance, and may
    // edit only the references inside it; the rest stay readable.
    final db = await ref.read(databaseProvider.future);
    final allowance = await resolveWriteAllowance(
      db,
      tier: ref.read(allowanceTierProvider),
      premium: await resolvePremiumAccess(
        db,
        ref.read(accountCacheUserIdProvider),
      ),
    );
    if (_isNew && !allowance.canAddReference()) {
      if (mounted) showReadOnlyWriteMessage(context, l.lapse_referenceLimit);
      return;
    }
    if (!_isNew && !allowance.isReferenceWritable(widget.reference!.id)) {
      if (mounted) showReadOnlyWriteMessage(context, l.lapse_readOnlyReference);
      return;
    }

    final companion = CaseReferencesCompanion(
      referenceAndPageNo: Value(_refNoController.text.trim()),
      statute: Value(
        _statuteController.text.trim().isEmpty
            ? null
            : _statuteController.text.trim(),
      ),
      sectionOrArticle: Value(
        _sectionController.text.trim().isEmpty
            ? null
            : _sectionController.text.trim(),
      ),
      titleAndDescription: Value(
        _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
      ),
      commentsNotes: Value(
        _commentsController.text.trim().isEmpty
            ? null
            : _commentsController.text.trim(),
      ),
      isPinned: Value(_isPinned),
    );

    if (_isNew) {
      await notifier.addReference(companion);
    } else {
      await notifier.updateReference(
        companion.copyWith(id: Value(widget.reference!.id)),
        baseReference: widget.reference,
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.caseReferenceScreen_saved)));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // Sticky top bar: centered title, close button at the right.
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Text(
                    _isNew
                        ? l.caseReferenceScreen_addTitle
                        : l.caseReferenceScreen_editTitle,
                    textAlign: TextAlign.center,
                    style: AppTypography.titleLg.copyWith(
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: AppColors.onPrimary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // Scrollable form body.
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                _Field(
                  label: l.caseReferenceScreen_referenceAndPageNo,
                  controller: _refNoController,
                  placeholder: l.caseReferenceScreen_refPlaceholder,
                ),
                _Field(
                  label: l.caseReferenceScreen_statute,
                  controller: _statuteController,
                  placeholder: l.caseReferenceScreen_statutePlaceholder,
                ),
                _Field(
                  label: l.caseReferenceScreen_sectionOrArticle,
                  controller: _sectionController,
                  placeholder: l.caseReferenceScreen_sectionPlaceholder,
                ),
                _Field(
                  label: l.caseReferenceScreen_titleAndDescription,
                  controller: _titleController,
                  placeholder: l.caseReferenceScreen_titlePlaceholder,
                  maxLines: 4,
                ),
                _Field(
                  label: l.caseReferenceScreen_commentsNotes,
                  controller: _commentsController,
                  placeholder: l.caseReferenceScreen_commentsPlaceholder,
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.sm),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
          // Sticky Save button at the bottom.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: FilledButton(
              key: const ValueKey('reference-save'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size.fromHeight(56),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              ),
              onPressed: () => _save(),
              child: Text(
                l.sharedActions_save,
                style: AppTypography.titleMd.copyWith(
                  color: AppColors.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A labeled text field matching the mockup's bottom-border legal-input style.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.placeholder,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String placeholder;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
            0,
          ),
          child: Text(
            label,
            style: AppTypography.labelLg.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            textAlign: TextAlign.start,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: TextStyle(
                color: AppColors.outline.withValues(alpha: 0.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              isCollapsed: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
            ),
          ),
        ),
      ],
    ),
  );
}
