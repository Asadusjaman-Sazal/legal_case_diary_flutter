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
import '../../case_reference/presentation/law_picker.dart';
import '../../case_reference/presentation/reference_detail_screen.dart';
import '../../case_reference/presentation/reference_form_screen.dart';
import '../../case_reference/presentation/reference_library.dart';
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

  /// Opens the shared Add/Edit form, titled for the official library.
  ///
  /// Returns true when the form saved and the server rows were re-read, which
  /// the detail uses to refresh.
  Future<bool> _openForm({
    AdminSharedReference? reference,
    String? initialStatute,
  }) async {
    final l = AppLocalizations.of(context);
    final isNew = reference == null;
    // Every tag the official library already uses, for the form's dropdown.
    final rows =
        ref.read(adminSharedReferencesProvider).value ??
        const <AdminSharedReference>[];
    final tagOptions = tagVocabulary(<String?>[
      for (final row in rows) row.tags,
    ]);
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReferenceFormScreen(
          title: isNew
              ? l.adminSharedRefs_addTitle
              : l.adminSharedRefs_editTitle,
          referenceAndPageNo: reference?.referenceAndPageNo ?? '',
          parties: reference?.parties ?? '',
          statute: reference?.statute ?? initialStatute,
          sectionOrArticle: reference?.sectionOrArticle ?? '',
          titleAndDescription: reference?.titleAndDescription ?? '',
          commentsNotes: reference?.commentsNotes ?? '',
          caseNote: reference?.caseNote ?? '',
          tags: reference?.tags ?? '',
          tagOptions: tagOptions,
          onSave: (values, formContext) =>
              _saveReference(reference, values, formContext),
        ),
      ),
    );
    if (saved == true && mounted) await _reload();
    return saved == true;
  }

  /// Opens a card's read-only detail. Every official row is editable and
  /// deletable here.
  void _openDetail(ReferenceRow row) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReferenceDetailScreen(
          row: row,
          onEdit: (current) => _editAndReturn(current.id),
          onDelete: (detailContext) async {
            final reference = _adminReference(row.id);
            if (reference == null) return false;
            return _confirmDelete(reference, ledgerContext: detailContext);
          },
        ),
      ),
    );
  }

  /// The live server row with [id], or null when a reload removed it.
  AdminSharedReference? _adminReference(String id) {
    final rows =
        ref.read(adminSharedReferencesProvider).value ??
        const <AdminSharedReference>[];
    for (final row in rows) {
      if (row.id == id) return row;
    }
    return null;
  }

  /// The detail's Edit: opens the form for the live server row and returns the
  /// reloaded row so the detail shows what was saved; null keeps it as it is.
  Future<ReferenceRow?> _editAndReturn(String id) async {
    final existing = _adminReference(id);
    if (existing == null) return null;
    final saved = await _openForm(reference: existing);
    if (!saved || !mounted) return null;
    final fresh = _adminReference(id);
    if (fresh == null) return null;
    return ReferenceRow.admin(
      id: fresh.id,
      referenceAndPageNo: fresh.referenceAndPageNo,
      parties: fresh.parties,
      statute: fresh.statute,
      sectionOrArticle: fresh.sectionOrArticle,
      titleAndDescription: fresh.titleAndDescription,
      commentsNotes: fresh.commentsNotes,
      caseNote: fresh.caseNote,
      tags: fresh.tags,
    );
  }

  /// Publishes the shared form's values to the server library.
  ///
  /// This window's own rules live here: the citation is required and a save
  /// needs the server. False leaves the form open with the typing intact.
  Future<bool> _saveReference(
    AdminSharedReference? existing,
    ReferenceFormValues values,
    BuildContext formContext,
  ) async {
    final l = AppLocalizations.of(formContext);
    if (values.referenceAndPageNo.isEmpty) {
      ScaffoldMessenger.of(
        formContext,
      ).showSnackBar(SnackBar(content: Text(l.adminSharedRefs_required)));
      return false;
    }
    if (ref.read(isOnlineProvider).value == false) {
      ScaffoldMessenger.of(
        formContext,
      ).showSnackBar(SnackBar(content: Text(l.adminSharedRefs_offline)));
      return false;
    }
    final reference = AdminSharedReference(
      id: existing?.id ?? const Uuid().v4(),
      referenceAndPageNo: values.referenceAndPageNo,
      parties: values.parties,
      statute: values.statute,
      sectionOrArticle: values.sectionOrArticle,
      titleAndDescription: values.titleAndDescription,
      commentsNotes: values.commentsNotes,
      caseNote: values.caseNote,
      tags: values.tags,
    );
    final failure = await ref
        .read(adminRepositoryProvider)
        .saveSharedReference(reference);
    if (!formContext.mounted) return false;
    if (failure != null) {
      final message = switch (failure) {
        AdminActionFailure.notAnAdmin => l.adminPanel_failedNotAdmin,
        _ => l.adminPanel_failedUnexpected,
      };
      ScaffoldMessenger.of(
        formContext,
      ).showSnackBar(SnackBar(content: Text(message)));
      return false;
    }
    ScaffoldMessenger.of(
      formContext,
    ).showSnackBar(SnackBar(content: Text(l.adminSharedRefs_saved)));
    return true;
  }

  /// Confirms and deletes a server row; true only when it was deleted, so the
  /// detail closes on a real deletion and stays on a cancel or a refusal.
  ///
  /// [ledgerContext] is the detail's own context when the delete starts there,
  /// so its dialogs and messages sit above the detail.
  Future<bool> _confirmDelete(
    AdminSharedReference reference, {
    BuildContext? ledgerContext,
  }) async {
    final hostContext = ledgerContext ?? context;
    final l = AppLocalizations.of(hostContext);
    if (_offline) {
      _showMessage(l.adminSharedRefs_offline, messengerContext: hostContext);
      return false;
    }
    final confirmed = await showAppConfirmDialog(
      hostContext,
      title: l.adminSharedRefs_deleteTitle,
      message: l.adminSharedRefs_deleteBody,
      confirmLabel: l.adminSharedRefs_deleteConfirm,
      confirmKey: const ValueKey('admin-shared-delete-confirm'),
    );
    if (!confirmed || !mounted || !hostContext.mounted) return false;

    final failure = await ref
        .read(adminRepositoryProvider)
        .deleteSharedReference(reference.id);
    if (!mounted || !hostContext.mounted) return false;
    if (failure != null) {
      _showMessage(_failureMessage(l, failure), messengerContext: hostContext);
      return false;
    }
    _showMessage(l.adminSharedRefs_deleted, messengerContext: hostContext);
    await _reload();
    return true;
  }

  void _showMessage(String message, {BuildContext? messengerContext}) {
    ScaffoldMessenger.of(
      messengerContext ?? context,
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
                  parties: row.parties,
                  statute: row.statute,
                  sectionOrArticle: row.sectionOrArticle,
                  titleAndDescription: row.titleAndDescription,
                  commentsNotes: row.commentsNotes,
                  caseNote: row.caseNote,
                  tags: row.tags,
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
                          row.parties,
                          row.statute,
                          row.sectionOrArticle,
                          row.titleAndDescription,
                          row.commentsNotes,
                          row.caseNote,
                          row.tags,
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
                onOpen: _openDetail,
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
                      onOpen: _openDetail,
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
