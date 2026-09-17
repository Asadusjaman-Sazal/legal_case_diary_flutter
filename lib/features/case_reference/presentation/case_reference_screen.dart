/// Case reference screen: precedents and citations library with navigation
/// panel, search, add/edit, pinning, and delete.
///
/// Task 11 Phase 2. Card layout mirrors the mandatory mockup
/// `mockup_html_screens/caseReference/code.html`. Uses [CasesScreenModal] for the
/// shared header (nav panel + search) and bottom nav, and a slide-up sheet for
/// add/edit (Google Keep style). Tapping a card opens the sheet to edit.
library;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../database/app_database.dart';
import '../../cases/presentation/cases_screen_modal.dart';
import '../../../shared/widgets/confirm_dialogs.dart';
import 'reference_viewmodel.dart';

/// Case reference library screen.
class CaseReferenceScreen extends ConsumerStatefulWidget {
  const CaseReferenceScreen({super.key});

  @override
  ConsumerState<CaseReferenceScreen> createState() => _CaseReferenceScreenState();
}

class _CaseReferenceScreenState extends ConsumerState<CaseReferenceScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) _searchController.clear();
    });
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
    final confirmed = await confirmDeleteDialog(context);
    if (!confirmed || !mounted) return;
    await ref.read(referenceViewModelProvider.notifier).deleteReference(reference);
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
    ref
        .read(referenceViewModelProvider.notifier)
        .setPinned(reference.id, !reference.isPinned);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final referencesAsync = ref.watch(referenceViewModelProvider);

    final references = referencesAsync.value?.items ?? const <CaseReference>[];
    final query = _searchController.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? references
        : references.where((r) {
            final hay = '${r.referenceAndPageNo} ${r.statute ?? ''} '
                '${r.sectionOrArticle ?? ''} ${r.titleAndDescription ?? ''} '
                '${r.commentsNotes ?? ''}'.toLowerCase();
            return hay.contains(query);
          }).toList();

    return CasesScreenModal(
      title: l.caseReferenceScreen_title,
      onSearch: _toggleSearch,
      onAddCase: () => _openSheet(),
      body: _ReferenceList(
        isSearching: _isSearching,
        searchController: _searchController,
        onSearchChanged: (_) => setState(() {}),
        onCloseSearch: _toggleSearch,
        references: visible,
        totalCount: references.length,
        onEdit: (reference) => _openSheet(reference: reference),
        onDelete: _confirmDelete,
        onTogglePin: _togglePin,
      ),
    );
  }
}

/// Scrollable reference list with optional inline search field.
class _ReferenceList extends StatelessWidget {
  const _ReferenceList({
    required this.isSearching,
    required this.searchController,
    required this.onSearchChanged,
    required this.onCloseSearch,
    required this.references,
    required this.totalCount,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePin,
  });

  final bool isSearching;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCloseSearch;
  final List<CaseReference> references;
  final int totalCount;
  final ValueChanged<CaseReference> onEdit;
  final ValueChanged<CaseReference> onDelete;
  final ValueChanged<CaseReference> onTogglePin;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final children = <Widget>[];

    if (isSearching) {
      children.add(
        ScopedSearchBar(
          controller: searchController,
          onChanged: onSearchChanged,
          onClose: onCloseSearch,
        ),
      );
    }

    if (references.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Center(
            child: Text(
              isSearching && totalCount > 0
                  ? l.sharedDialogs_noResults
                  : l.caseReferenceScreen_empty,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    for (var i = 0; i < references.length; i++) {
      if (i > 0) children.add(const SizedBox(height: AppSpacing.md));
      final reference = references[i];
      children.add(
        _ReferenceCard(
          reference: reference,
          onEdit: () => onEdit(reference),
          onDelete: () => onDelete(reference),
          onTogglePin: () => onTogglePin(reference),
        ),
      );
    }
    children.add(const SizedBox(height: AppSpacing.lg));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: children,
    );
  }
}

/// A single reference card matching the mandatory mockup layout.
class _ReferenceCard extends StatefulWidget {
  const _ReferenceCard({
    required this.reference,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePin,
  });

  final CaseReference reference;
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
    final borderColor =
        _hovered ? AppColors.secondary : AppColors.outlineVariant;

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
                                    ? AppLocalizations.of(context)
                                        .caseReferenceScreen_unpin
                                    : AppLocalizations.of(context)
                                        .caseReferenceScreen_pin,
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
                                AppLocalizations.of(context).sharedActions_delete,
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
                        left: BorderSide(
                          color: AppColors.secondary,
                          width: 4,
                        ),
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
          style: AppTypography.labelMd.copyWith(
            color: AppColors.primary,
          ),
        ),
      );
}

/// Slide-up sheet for adding or editing a case reference.
class _ReferenceEditSheet extends ConsumerStatefulWidget {
  const _ReferenceEditSheet({this.reference});

  final CaseReference? reference;

  @override
  ConsumerState<_ReferenceEditSheet> createState() => _ReferenceEditSheetState();
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
    _titleController = TextEditingController(text: r?.titleAndDescription ?? '');
    _commentsController = TextEditingController(text: r?.commentsNotes ?? '');
    _isPinned = r?.isPinned ?? false;
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
      await notifier.deleteReference(widget.reference!);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.caseReferenceScreen_deleted)));
        Navigator.of(context).pop(widget.reference);
      }
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
        _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.caseReferenceScreen_saved)));
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
                border: Border(
                  bottom: BorderSide(color: AppColors.outlineVariant),
                ),
              ),
              child: TextField(
                controller: controller,
                maxLines: maxLines,
                textAlign: TextAlign.start,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: placeholder,
                  hintStyle:
                      TextStyle(color: AppColors.outline.withValues(alpha: 0.5)),
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
