/// Case reference screen: precedents and citations library with navigation
/// panel, search, add/edit, pinning, and delete.
///
/// Task 11 Phase 2. Card layout mirrors the mandatory mockup
/// `mockup_html_screens/caseReference/code.html`. Uses [CasesScreenModal] for the
/// shared header (nav panel + search) and bottom nav, and a slide-up sheet for
/// add/edit (Google Keep style). Tapping a card opens the sheet to edit.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_dialog_metrics.dart';
import '../../../core/utils/scoped_search.dart';
import '../../../database/app_database.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../shared/widgets/pull_to_sync.dart';
import '../../../sync/sync_service.dart';
import '../../accounts_and_profile/data/account_mode.dart';
import '../../cases/presentation/cases_screen_modal.dart';
import '../../payments/presentation/lapse_allowance_ui.dart';
import '../../settings/data/premium_access.dart';
import '../../settings/data/write_allowance.dart';
import '../../settings/presentation/delete_request_flow.dart';
import '../../settings/presentation/edit_court_steps/next_order_index.dart';
import '../data/local/shared_case_references_dao.dart';
import 'law_name_dialog.dart';
import 'reference_library.dart';
import 'law_picker.dart';
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

  /// The law whose references are open, or null while the law list shows.
  ///
  /// The key is the statute text the references carry (an empty string for a
  /// reference with no statute), not a law id: `statute` has always been text,
  /// so two references naming the same Act belong under one row even when no
  /// law row owns that name — which is how a citation written before this list
  /// existed still appears here as its own law.
  String? _openLaw;

  /// The screen's live scoped search (Task 14 Phase 5, plan §12.1): the query
  /// runs as a Drift `LIKE` query across the reference's five text fields rather
  /// than filtering the rows this screen happened to have loaded.
  ///
  /// The runner holds the screen's display rows rather than `CaseReference`,
  /// because a law's page lists the user's own citations and the official
  /// library's together.
  late final ScopedSearch<ReferenceRow> _search = ScopedSearch(
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

  /// Runs one query through `CaseReferencesDao.search` (all five text fields)
  /// and the official cache's own search, then keeps the open law's rows.
  ///
  /// The user's own rows keep the SQL query every library uses; the official
  /// cache is searched in memory by its own DAO, because it is a small
  /// pull-only set with no sync columns to query by.
  Future<List<ReferenceRow>> _searchReferences(String query) async {
    final ownRepository = await ref.read(referenceRepositoryProvider.future);
    final officialRepository = await ref.read(
      sharedReferenceRepositoryProvider.future,
    );
    final own = await ownRepository.search(query);
    final official = await officialRepository.search(query);
    final law = _openLaw;
    final rows = <ReferenceRow>[
      for (final reference in own) ReferenceRow.own(reference),
      for (final entry in official) ReferenceRow.official(entry),
    ];
    if (law == null) return rows;
    return rows
        .where((row) => referenceStatuteKey(row.statute) == law)
        .toList(growable: false);
  }

  /// Types into the bar.
  ///
  /// The two levels search different things: the law list narrows by **law
  /// name** (a law whose name matches but whose citations do not must still be
  /// offered), while a law's page runs the library's SQL query across its five
  /// fields and then keeps this law's rows.
  Future<void> _onSearchChanged(String query) async {
    if (_openLaw == null) {
      if (mounted) setState(() {});
      return;
    }
    await _search.run(query);
    if (mounted) setState(() {});
  }

  /// Opens one law's references; the search bar closes with the level change,
  /// because the two levels search different things.
  Future<void> _openLawReferences(String law) async {
    setState(() {
      _openLaw = law;
      _isSearching = false;
      _searchController.clear();
    });
    await _search.run('');
  }

  /// Returns to the law list, from the page's back arrow or the system gesture.
  Future<void> _closeLaw() async {
    setState(() {
      _openLaw = null;
      _isSearching = false;
      _searchController.clear();
    });
    await _search.run('');
  }

  /// Opens the add/edit screen. [reference] is null when creating new.
  /// If the screen pops with a deleted [CaseReference], shows the undo snackbar.
  ///
  /// [initialStatute] preselects the law when the sheet is opened from that
  /// law's own page, so a citation added there lands in the list being read.
  Future<void> _openSheet({
    CaseReference? reference,
    String? initialStatute,
  }) async {
    final result = await Navigator.of(context).push<CaseReference?>(
      MaterialPageRoute(
        builder: (_) => _ReferenceEditSheet(
          reference: reference,
          initialStatute: initialStatute,
        ),
      ),
    );
    if (result is CaseReference && mounted) _showUndoSnackBar(result);
  }

  Future<void> _confirmDelete(ReferenceRow row) async {
    // An official citation is the admins' to change; the phone has no grant on
    // that table, so there is nothing here to confirm.
    final reference = row.own;
    if (reference == null) return;
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

  /// Pins or unpins a row.
  ///
  /// An official citation's pin is this device's own arrangement, kept in the
  /// local-only pin table, so it needs no allowance: there is nothing to write
  /// to the server and nothing another phone would see.
  void _togglePin(ReferenceRow row) {
    final official = row.official;
    if (official != null) {
      unawaited(
        ref
            .read(sharedReferenceRepositoryProvider.future)
            .then(
              (repo) => repo.setPinned(official.row.id, !official.isPinned),
            ),
      );
      return;
    }
    final reference = row.own!;
    // Pinning writes `updated_at`, which would pull a read-only reference back
    // into the allowance, so it meets the same boundary as an edit.
    if (!ensureReferenceWritable(context, ref, reference.id)) return;
    ref
        .read(referenceViewModelProvider.notifier)
        .setPinned(reference.id, !reference.isPinned);
  }

  /// Phase 10: a read-only reference explains itself instead of opening the
  /// editor.
  ///
  /// An official citation has no editor on this device at all — it belongs to
  /// the admin-curated library — so tapping one opens nothing.
  void _editIfWritable(ReferenceRow row) {
    final reference = row.own;
    if (reference == null) return;
    if (!ensureReferenceWritable(context, ref, reference.id)) return;
    _openSheet(reference: reference);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final referencesAsync = ref.watch(referenceViewModelProvider);
    final references = referencesAsync.value?.items ?? const <CaseReference>[];
    final official =
        ref.watch(officialReferencesProvider).value ??
        const <OfficialReference>[];
    // The two libraries as the screen shows them: the user's own rows first, in
    // their own pinned-then-recent order, then the official ones.
    final rows = <ReferenceRow>[
      for (final reference in references) ReferenceRow.own(reference),
      for (final entry in official) ReferenceRow.official(entry),
    ];
    final allowance = ref.watch(writeAllowanceProvider).value;
    final law = _openLaw;

    // A short library must still be pullable, and the pull must not drag the
    // cards under the finger while the indicator spins.
    final behavior = ScrollConfiguration(
      behavior: pullScrollBehavior(context),
      child: law == null
          ? ReferenceLawList(
              sections: filterLawSections(
                lawSectionsFor(
                  ref.watch(lawListProvider).value ?? const <Law>[],
                  rows,
                ),
                _isSearching ? _searchController.text : '',
              ),
              // Which empty state, and whether the library has anything at all.
              isSearching: _isSearching,
              hasReferences: rows.isNotEmpty,
              onOpen: _openLawReferences,
              onRefresh: _onRefresh,
            )
          : Column(
              children: [
                ReferenceLawHeader(
                  label: law.isEmpty ? l.caseReferenceScreen_noStatute : law,
                  count: rows
                      .where((row) => referenceStatuteKey(row.statute) == law)
                      .length,
                  onBack: _closeLaw,
                ),
                Expanded(
                  child: ReferenceList(
                    isSearching: _isSearching,
                    references:
                        _search.rows ??
                        rows
                            .where(
                              (row) => referenceStatuteKey(row.statute) == law,
                            )
                            .toList(growable: false),
                    totalCount: rows.length,
                    emptyMessage: l.caseReferenceScreen_noLawReferences,
                    writableReferenceIds: allowance?.writableReferenceIds,
                    onEdit: _editIfWritable,
                    onDelete: _confirmDelete,
                    onTogglePin: _togglePin,
                    onRefresh: _onRefresh,
                  ),
                ),
              ],
            ),
    );

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
      // The hardware back on a law's page returns to the law list rather than
      // offering to close the app; on the law list it keeps the exit window.
      onBack: law == null ? null : _closeLaw,
      onAddCase: () => _openSheet(initialStatute: law),
      body: behavior,
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

/// Slide-up sheet for adding or editing a case reference.
class _ReferenceEditSheet extends ConsumerStatefulWidget {
  const _ReferenceEditSheet({this.reference, this.initialStatute});

  final CaseReference? reference;

  /// The law a new reference starts under, when the sheet is opened from that
  /// law's own list; null from the library, where the user chooses one.
  final String? initialStatute;

  @override
  ConsumerState<_ReferenceEditSheet> createState() =>
      _ReferenceEditSheetState();
}

class _ReferenceEditSheetState extends ConsumerState<_ReferenceEditSheet> {
  late final TextEditingController _refNoController;

  /// The cited law's name, chosen from the law list rather than typed.
  ///
  /// It stays a plain name rather than an id because `case_references.statute`
  /// has always held text: an existing reference keeps whatever it was saved
  /// with, including a name the list has never heard of, and the screen keeps
  /// showing it until the user picks a different one.
  String? _statute;
  late final TextEditingController _sectionController;
  late final TextEditingController _titleController;
  late final TextEditingController _commentsController;
  late bool _isPinned;

  @override
  void initState() {
    super.initState();
    final r = widget.reference;
    _refNoController = TextEditingController(text: r?.referenceAndPageNo ?? '');
    final initial = widget.initialStatute;
    _statute =
        r?.statute ?? (initial == null || initial.isEmpty ? null : initial);
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
    _sectionController.dispose();
    _titleController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  bool get _isNew => widget.reference == null;

  /// Opens the grouped law picker, and its **Add a Law Name…** row when the
  /// citation's law is not in the list yet.
  ///
  /// The picker reads the list fresh each time: another associate may have
  /// added a name since this sheet opened, and the dropdown should offer it.
  Future<void> _pickStatute() async {
    final repo = await ref.read(lawsRepositoryProvider.future);
    final laws = await repo.listAll();
    if (!mounted) return;

    Law? selected;
    for (final law in laws) {
      if (law.name == _statute) selected = law;
    }

    final pick = await showLawPicker(context, laws: laws, selected: selected);
    if (pick == null || !mounted) return;

    if (!pick.addNew) {
      final law = pick.law;
      if (law != null) setState(() => _statute = law.name);
      return;
    }

    // A new name lands in the category of the law currently cited when there
    // is one, so adding a neighbouring Act does not require re-choosing it.
    final draft = await showLawNameDialog(
      context,
      initialCategoryId: selected == null || selected.category.isEmpty
          ? null
          : selected.category,
    );
    if (draft == null || !mounted) return;

    await repo.insert(
      LawsCompanion(
        name: Value(draft.name),
        category: Value(draft.categoryId),
        orderIndex: Value(
          nextOrderIndex(
            laws
                .where((law) => law.category == draft.categoryId)
                .map((law) => law.orderIndex),
          ),
        ),
      ),
    );
    if (mounted) setState(() => _statute = draft.name);
  }

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
        _statute == null || _statute!.trim().isEmpty ? null : _statute!.trim(),
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
          // Sticky top bar: centered title, close button at the right. The band
          // is the app's black (#000000) — the same black the buttons, the side
          // menu and the Quick Update window wear — rather than the ink navy
          // the other headers use (user request).
          Container(
            key: const ValueKey('reference-title'),
            color: AppColors.secondary,
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
                  verticalPadding: _singleLineVerticalPadding,
                ),
                _DropdownField(
                  key: const ValueKey('reference-statute-field'),
                  label: l.caseReferenceScreen_statute,
                  value: _statute,
                  placeholder: l.caseReferenceScreen_statutePlaceholder,
                  verticalPadding: _singleLineVerticalPadding,
                  onTap: _pickStatute,
                ),
                _Field(
                  label: l.caseReferenceScreen_sectionOrArticle,
                  controller: _sectionController,
                  placeholder: l.caseReferenceScreen_sectionPlaceholder,
                  verticalPadding: _singleLineVerticalPadding,
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

/// The single-line fields' vertical padding.
///
/// Measured in a widget test, a single-line box with [AppSpacing.sm] padding is
/// 32 px tall, so the user's 25 % taller box is 40 px: padding grows to
/// [AppSpacing.gutter] (12 px) and the text line keeps its own size. The
/// multi-line fields keep the default padding, because their height comes from
/// their line count rather than from a fixed box.
const double _singleLineVerticalPadding = AppSpacing.gutter;

/// The colour of the fields' bottom rule.
///
/// [AppColors.outlineVariant] (#C6C6CD) sat only ~1.5:1 against the box's
/// [AppColors.surfaceContainerLow] (#F2F4F6) fill, so the rule all but vanished
/// on the near-white box (user report). Its own parent token
/// [AppColors.outline] (#76777D) is the same neutral grey one step darker and
/// reads clearly without turning into a heavy ink line — thematically the
/// app's field border, not a new colour (user request).
const Color _bottomRuleColor = AppColors.outline;

/// A labeled text field matching the mockup's bottom-border legal-input style.
///
/// The box wears the shared pop-over window's corner ([AppDialogMetrics.corner])
/// on all four sides, so a field and the window it may sit in read as one
/// family (user request).
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.placeholder,
    this.maxLines = 1,
    this.verticalPadding = AppSpacing.sm,
  });

  final String label;
  final TextEditingController controller;
  final String placeholder;
  final int maxLines;

  /// Padding above and below the text inside the box. Only the single-line
  /// fields raise it; see [_singleLineVerticalPadding].
  final double verticalPadding;

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
        _fieldBox(
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
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: verticalPadding,
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

/// The box every field on the form draws: the shared window's corner, the
/// aside fill, and the gray rule along the box's own bottom edge.
///
/// The rule is painted rather than set as a `Border`, which would draw a
/// straight chord and stop short of each rounded corner (user report, 0.0.741).
Widget _fieldBox({required Widget child}) => Container(
  decoration: BoxDecoration(
    color: AppColors.surfaceContainerLow,
    borderRadius: BorderRadius.circular(AppDialogMetrics.corner),
  ),
  child: CustomPaint(
    foregroundPainter: _BottomRulePainter(
      color: _bottomRuleColor,
      radius: AppDialogMetrics.corner,
    ),
    child: child,
  ),
);

/// The statute field: a dropdown that reads as the form's other boxes.
///
/// It is not a `DropdownButton`, because the picker is the app's own grouped
/// window (seven headings and an Add row) rather than a one-column menu. The
/// box keeps [AppDialogMetrics.corner] and the same bottom rule as its
/// neighbours, so the row looks unchanged until it is tapped.
class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    required this.verticalPadding,
    super.key,
  });

  final String label;

  /// The chosen law's name, or null when nothing is chosen yet.
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.trim().isNotEmpty;
    return Padding(
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
          _fieldBox(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppDialogMetrics.corner),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: verticalPadding,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasValue ? value!.trim() : placeholder,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyLg.copyWith(
                          color: hasValue
                              ? AppColors.onBackground
                              : AppColors.outline.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the field's gray bottom rule along the box's own bottom edge.
///
/// A `Border(bottom: ...)` on a rounded box paints a straight chord between the
/// two corner arcs, leaving a visible break where the box curves away; this path
/// follows the curve instead, so the rule rises into both corners and meets the
/// sides (user report).
class _BottomRulePainter extends CustomPainter {
  const _BottomRulePainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    // A box shorter than two radii has no straight bottom left to draw, so the
    // curve shrinks with it rather than running off the box.
    final r = math.min(radius, size.height / 2);
    final w = size.width;
    final h = size.height;
    final corner = Radius.circular(r);
    // `clockwise: false` is load-bearing. Walking left to right along the
    // bottom edge, the corner arcs turn anticlockwise; the default
    // (clockwise) makes `arcToPoint` pick the centre at the box's outer
    // corner instead, which scoops a quarter circle *into* the box and reads
    // as a bite out of each bottom corner (user report).
    final path = Path()
      ..moveTo(0, h - r)
      ..arcToPoint(Offset(r, h), radius: corner, clockwise: false)
      ..lineTo(w - r, h)
      ..arcToPoint(Offset(w, h - r), radius: corner, clockwise: false);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        // One crisp device-independent pixel: at the phones' 2x-3x pixel
        // density this is a hairline, and a fractional width would only blur it.
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_BottomRulePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
