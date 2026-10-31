/// The Admin Panel's **Server-wide Case Reference** page: the citation library
/// every account reads.
///
/// A replica of the user's own Case Reference screen — the same law list, the
/// same cards, the same two levels — over a different data source: the live
/// server table rather than the user's rows and the pulled cache. That is why
/// the body comes from `reference_library.dart` instead of a second design.
///
/// Two differences, both deliberate: an admin's rows are editable and
/// deletable (the RLS admin policy is theirs, not the phone's), and a save
/// **needs the server**. Nothing here is queued, so an offline save says so in
/// plain words rather than pretending to work.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../database/app_database.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../sync/connectivity_monitor.dart';
import '../../case_reference/presentation/law_name_dialog.dart';
import '../../case_reference/presentation/law_picker.dart';
import '../../case_reference/presentation/reference_library.dart';
import '../../settings/presentation/edit_court_steps/next_order_index.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';
import '../data/admin_repository.dart';
import 'admin_shared.dart';
import 'admin_viewmodel.dart';

/// The Server-wide Case Reference page: law list first, then a law's citations.
class AdminSharedReferencesScreen extends ConsumerStatefulWidget {
  /// Creates the page.
  const AdminSharedReferencesScreen({super.key});

  @override
  ConsumerState<AdminSharedReferencesScreen> createState() =>
      _AdminSharedReferencesScreenState();
}

class _AdminSharedReferencesScreenState
    extends ConsumerState<AdminSharedReferencesScreen> {
  /// The law whose citations are open, or null while the law list shows.
  String? _openLaw;

  /// Whether the search field is showing, and what is typed in it.
  bool _isSearching = false;
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Fresh rows on every open, after the first frame so the provider is not
    // touched mid-build: the pull may not have run since the last visit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(adminSharedReferencesProvider);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _search.clear();
        _query = '';
      }
    });
  }

  void _showLaw(String law) {
    setState(() {
      _openLaw = law;
      _isSearching = false;
      _search.clear();
      _query = '';
    });
  }

  void _closeLaw() {
    setState(() {
      _openLaw = null;
      _isSearching = false;
      _search.clear();
      _query = '';
    });
  }

  /// Re-reads the server rows, so the page shows what the server holds rather
  /// than a local guess about what a save just did.
  Future<void> _reload() async {
    ref.invalidate(adminSharedReferencesProvider);
    await ref.read(adminSharedReferencesProvider.future);
  }

  /// True when the device cannot reach the server, which a save requires.
  bool get _offline => ref.read(isOnlineProvider).value == false;

  Future<void> _openForm({
    AdminSharedReference? reference,
    String? initialStatute,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AdminReferenceForm(
          reference: reference,
          initialStatute: initialStatute,
        ),
      ),
    );
    if (saved == true && mounted) await _reload();
  }

  Future<void> _confirmDelete(AdminSharedReference reference) async {
    final l = AppLocalizations.of(context);
    if (_offline) {
      _showMessage(l.adminSharedRefs_offline);
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context,
      title: l.adminSharedRefs_deleteTitle,
      message: l.adminSharedRefs_deleteBody,
      confirmLabel: l.adminSharedRefs_deleteConfirm,
      confirmKey: const ValueKey('admin-shared-delete-confirm'),
    );
    if (!confirmed || !mounted) return;

    final failure = await ref
        .read(adminRepositoryProvider)
        .deleteSharedReference(reference.id);
    if (!mounted) return;
    if (failure != null) {
      _showMessage(_failureMessage(l, failure));
      return;
    }
    _showMessage(l.adminSharedRefs_deleted);
    await _reload();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// The plain-words sentence for a refusal.
  String _failureMessage(AppLocalizations l, AdminActionFailure failure) =>
      switch (failure) {
        AdminActionFailure.notAnAdmin => l.adminPanel_failedNotAdmin,
        AdminActionFailure.notFound => l.adminSharedRefs_loadFailed,
        AdminActionFailure.alreadyResolved =>
          l.adminPanel_failedAlreadyResolved,
        AdminActionFailure.tooRecent => l.adminPanel_failedUnexpected,
        AdminActionFailure.unexpected => l.adminPanel_failedUnexpected,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // A non-admin never sees this page, even by a stale route: the server has
    // to have confirmed the account before the body is built at all.
    final isAdmin = ref.watch(adminStatusProvider);
    if (isAdmin.value != true) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: isAdmin.isLoading
              ? const CircularProgressIndicator()
              : Text(l.adminSharedRefs_empty),
        ),
      );
    }

    final references = ref.watch(adminSharedReferencesProvider);
    final laws = ref.watch(lawListProvider).value ?? const <Law>[];

    return PopScope(
      // The page can be the stack's only route, so back must land on the
      // Admin Panel rather than leaving it stranded.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_openLaw != null) {
          _closeLaw();
          return;
        }
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
        } else {
          GoRouter.of(context).go(AppRoutes.adminPanel);
        }
      },
      child: SettingsSubPageModal(
        title: l.adminPanel_sharedReferences,
        // The page owns a pull that re-reads the server rows.
        pullToSync: false,
        onBack: () {
          if (_openLaw != null) {
            _closeLaw();
            return;
          }
          Navigator.of(context).maybePop();
        },
        actions: [
          const AdminSyncButton(),
          IconButton(
            key: const ValueKey('admin-shared-search'),
            icon: const Icon(Icons.search),
            tooltip: l.adminPanel_search,
            onPressed: _toggleSearch,
          ),
        ],
        floatingActionButton: FloatingActionButton(
          key: const ValueKey('admin-shared-add'),
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.onPrimary,
          onPressed: () => _openForm(initialStatute: _openLaw),
          child: const Icon(Icons.add),
        ),
        child: references.when(
          loading: () => Center(
            child: Text(
              l.adminSharedRefs_loading,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          error: (_, _) => AdminLoadFailed(
            message: l.adminSharedRefs_loadFailed,
            onRetry: () => ref.invalidate(adminSharedReferencesProvider),
          ),
          data: (rows) {
            final all = <ReferenceRow>[
              for (final row in rows)
                ReferenceRow.admin(
                  id: row.id,
                  referenceAndPageNo: row.referenceAndPageNo,
                  statute: row.statute,
                  sectionOrArticle: row.sectionOrArticle,
                  titleAndDescription: row.titleAndDescription,
                  commentsNotes: row.commentsNotes,
                ),
            ];
            final byId = {for (final row in rows) row.id: row};
            final law = _openLaw;
            // A query reads the whole library, whichever level is showing, as
            // on the user's own Case Reference screen (user request).
            final searching = _isSearching && _query.trim().isNotEmpty;
            final matches = searching
                ? all
                      .where(
                        (row) => adminTextMatches(_query, <String?>[
                          row.referenceAndPageNo,
                          row.statute,
                          row.sectionOrArticle,
                          row.titleAndDescription,
                          row.commentsNotes,
                        ]),
                      )
                      .toList(growable: false)
                : const <ReferenceRow>[];

            final Widget body;
            if (searching) {
              body = ReferenceList(
                isSearching: true,
                references: matches,
                totalCount: all.length,
                emptyMessage: l.adminSharedRefs_empty,
                onEdit: (row) => _openForm(reference: byId[row.id]),
                onDelete: (row) => _confirmDelete(byId[row.id]!),
                // No pin here: a pin is one device's own arrangement, and this
                // page publishes to every device.
                onTogglePin: null,
                onRefresh: _reload,
              );
            } else if (law == null) {
              body = ReferenceLawList(
                sections: lawSectionsFor(laws, all),
                emptyMessage: l.adminSharedRefs_empty,
                onOpen: _showLaw,
                onRefresh: _reload,
              );
            } else {
              final lawRows = all
                  .where((row) => referenceStatuteKey(row.statute) == law)
                  .toList(growable: false);
              body = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ReferenceLawHeader(
                    label: law.isEmpty ? l.caseReferenceScreen_noStatute : law,
                    count: lawRows.length,
                    onBack: () async => _closeLaw(),
                  ),
                  Expanded(
                    child: ReferenceList(
                      isSearching: false,
                      references: lawRows,
                      totalCount: lawRows.length,
                      emptyMessage: l.adminSharedRefs_noLawReferences,
                      onEdit: (row) => _openForm(reference: byId[row.id]),
                      onDelete: (row) => _confirmDelete(byId[row.id]!),
                      onTogglePin: null,
                      onRefresh: _reload,
                    ),
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isSearching)
                  AdminSearchField(
                    controller: _search,
                    onChanged: (value) => setState(() => _query = value),
                    hint: l.adminPanel_searchHint,
                    onClose: _toggleSearch,
                  ),
                Expanded(child: body),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The add/edit form: the five fields the user's own form has, saved to the
/// server when Save is pressed.
class _AdminReferenceForm extends ConsumerStatefulWidget {
  const _AdminReferenceForm({this.reference, this.initialStatute});

  /// The row being edited, or null when publishing a new citation.
  final AdminSharedReference? reference;

  /// The law a new citation starts under, when the form was opened from that
  /// law's own list.
  final String? initialStatute;

  @override
  ConsumerState<_AdminReferenceForm> createState() =>
      _AdminReferenceFormState();
}

class _AdminReferenceFormState extends ConsumerState<_AdminReferenceForm> {
  late final TextEditingController _refNo;
  late final TextEditingController _section;
  late final TextEditingController _title;
  late final TextEditingController _comments;
  String? _statute;

  /// True while the upsert is in flight, so Save cannot be pressed twice.
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.reference;
    _refNo = TextEditingController(text: r?.referenceAndPageNo ?? '');
    _section = TextEditingController(text: r?.sectionOrArticle ?? '');
    _title = TextEditingController(text: r?.titleAndDescription ?? '');
    _comments = TextEditingController(text: r?.commentsNotes ?? '');
    _statute = r?.statute ?? widget.initialStatute;
  }

  @override
  void dispose() {
    _refNo.dispose();
    _section.dispose();
    _title.dispose();
    _comments.dispose();
    super.dispose();
  }

  /// Opens the same grouped law picker the user's form uses.
  ///
  /// Its **Add a Law Name…** row works here exactly as it does on the user's
  /// own form: the shared add window collects a name and a category, the row is
  /// saved through `LawsRepository` (a custom row appended to its category) and
  /// the new name is selected. A visible row that did nothing would leave the
  /// admin unsure whether the tap registered.
  Future<void> _pickStatute() async {
    final repo = await ref.read(lawsRepositoryProvider.future);
    final laws = await repo.listAll();
    if (!mounted) return;
    Law? selected;
    for (final entry in laws) {
      if (entry.name == _statute) selected = entry;
    }
    final pick = await showLawPicker(context, laws: laws, selected: selected);
    if (pick == null || !mounted) return;

    if (pick.addNew) {
      // The new name lands in the cited law's own category when there is one,
      // so adding a neighbouring Act does not require re-choosing it.
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
      return;
    }

    final law = pick.law;
    if (law != null) setState(() => _statute = law.name);
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final citation = _refNo.text.trim();
    if (citation.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.adminSharedRefs_required)));
      return;
    }
    if (ref.read(isOnlineProvider).value == false) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.adminSharedRefs_offline)));
      return;
    }

    setState(() => _saving = true);
    final reference = AdminSharedReference(
      id: widget.reference?.id ?? const Uuid().v4(),
      referenceAndPageNo: citation,
      statute: _statute?.trim().isEmpty ?? true ? null : _statute!.trim(),
      sectionOrArticle: _section.text.trim().isEmpty
          ? null
          : _section.text.trim(),
      titleAndDescription: _title.text.trim().isEmpty
          ? null
          : _title.text.trim(),
      commentsNotes: _comments.text.trim().isEmpty
          ? null
          : _comments.text.trim(),
    );
    final failure = await ref
        .read(adminRepositoryProvider)
        .saveSharedReference(reference);
    if (!mounted) return;
    setState(() => _saving = false);
    if (failure != null) {
      final message = switch (failure) {
        AdminActionFailure.notAnAdmin => l.adminPanel_failedNotAdmin,
        _ => l.adminPanel_failedUnexpected,
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l.adminSharedRefs_saved)));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isNew = widget.reference == null;
    final hasStatute = _statute != null && _statute!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // The same black band the user's own form wears.
          Container(
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
                    isNew
                        ? l.adminSharedRefs_addTitle
                        : l.adminSharedRefs_editTitle,
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                _field(
                  label: l.caseReferenceScreen_referenceAndPageNo,
                  controller: _refNo,
                  key: const ValueKey('admin-shared-citation'),
                ),
                _statuteField(l, hasStatute),
                _field(
                  label: l.caseReferenceScreen_sectionOrArticle,
                  controller: _section,
                ),
                _field(
                  label: l.caseReferenceScreen_titleAndDescription,
                  controller: _title,
                  maxLines: 4,
                ),
                _field(
                  label: l.caseReferenceScreen_commentsNotes,
                  controller: _comments,
                  maxLines: 3,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('admin-shared-save'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : Text(l.sharedActions_save),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One labelled text field, in the app's own field colours.
  Widget _field({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    Key? key,
  }) => Padding(
    key: key,
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      style: AppTypography.bodyLg,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.labelLg.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
      ),
    ),
  );

  /// The statute field: a tappable box over the shared law list, exactly as the
  /// user's own form draws it.
  Widget _statuteField(AppLocalizations l, bool hasStatute) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: InkWell(
      key: const ValueKey('admin-shared-statute'),
      onTap: _pickStatute,
      borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l.caseReferenceScreen_statute,
          labelStyle: AppTypography.labelLg.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
          filled: true,
          fillColor: AppColors.surfaceContainerLow,
          suffixIcon: const Icon(Icons.arrow_drop_down),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
            borderSide: const BorderSide(color: AppColors.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
            borderSide: const BorderSide(color: AppColors.outlineVariant),
          ),
        ),
        child: Text(
          hasStatute ? _statute!.trim() : l.caseReferenceScreen_chooseLaw,
          style: AppTypography.bodyLg.copyWith(
            color: hasStatute
                ? AppColors.onBackground
                : AppColors.outline.withValues(alpha: 0.6),
          ),
        ),
      ),
    ),
  );
}

/// The page's failed-load panel, with its retry.
class AdminLoadFailed extends StatelessWidget {
  /// Creates the panel.
  const AdminLoadFailed({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(onPressed: onRetry, child: Text(l.adminPanel_retry)),
        ],
      ),
    );
  }
}
