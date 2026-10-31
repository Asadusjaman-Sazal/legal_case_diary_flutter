/// Case reference screen: precedents and citations library with navigation
/// panel, search, add/edit, pinning, and delete.
///
/// Task 11 Phase 2. Card layout mirrors the mandatory mockup
/// `mockup_html_screens/caseReference/code.html`. Uses [CasesScreenModal] for the
/// shared header (nav panel + search) and bottom nav; adding and editing use the
/// shared `ReferenceFormScreen`, the same window the Admin Panel's official
/// library opens.
library;

import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/repository_providers.dart';
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
import '../data/local/shared_case_references_dao.dart';
import 'law_picker.dart';
import 'reference_form_screen.dart';
import 'reference_library.dart';
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
  /// because the library lists the user's own citations and the official
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
  /// and the official cache's own search, across the **whole** library.
  ///
  /// The user's own rows keep the SQL query every library uses; the official
  /// cache is searched in memory by its own DAO, because it is a small
  /// pull-only set with no sync columns to query by. The query is not narrowed
  /// to the open law: a lawyer matching a citation should find it whichever
  /// law holds it (user request).
  Future<List<ReferenceRow>> _searchReferences(String query) async {
    final ownRepository = await ref.read(referenceRepositoryProvider.future);
    final officialRepository = await ref.read(
      sharedReferenceRepositoryProvider.future,
    );
    final own = await ownRepository.search(query);
    final official = await officialRepository.search(query);
    return <ReferenceRow>[
      for (final reference in own) ReferenceRow.own(reference),
      for (final entry in official) ReferenceRow.official(entry),
    ];
  }

  /// Types into the bar; every query reads the whole library, whichever level
  /// the screen happened to be showing.
  Future<void> _onSearchChanged(String query) async {
    await _search.run(query);
    if (mounted) setState(() {});
  }

  /// Opens one law's references; the search bar closes with the level change,
  /// so the new level shows whole.
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

  /// Opens the shared Add/Edit form; [reference] is null when creating new.
  ///
  /// [initialStatute] preselects the law when the form is opened from that
  /// law's page, so a citation added there lands in the list being read.
  Future<void> _openSheet({
    CaseReference? reference,
    String? initialStatute,
  }) async {
    final l = AppLocalizations.of(context);
    final isNew = reference == null;
    // Every tag this screen already shows, so the form can offer them again.
    final own =
        ref.read(referenceViewModelProvider).value?.items ??
        const <CaseReference>[];
    final official =
        ref.read(officialReferencesProvider).value ??
        const <OfficialReference>[];
    final tagOptions = tagVocabulary(<String?>[
      for (final row in own) row.tags,
      for (final entry in official) entry.row.tags,
    ]);
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReferenceFormScreen(
          title: isNew
              ? l.caseReferenceScreen_addTitle
              : l.caseReferenceScreen_editTitle,
          referenceAndPageNo: reference?.referenceAndPageNo ?? '',
          parties: reference?.parties ?? '',
          statute: reference?.statute ?? initialStatute,
          sectionOrArticle: reference?.sectionOrArticle ?? '',
          caseNote: reference?.caseNote ?? '',
          titleAndDescription: reference?.titleAndDescription ?? '',
          commentsNotes: reference?.commentsNotes ?? '',
          tags: reference?.tags ?? '',
          tagOptions: tagOptions,
          // Editing a reference someone asked to delete asks first; declining
          // closes the window without changing anything.
          confirmOpen: isNew
              ? null
              : (formContext, formRef) => confirmEditOfRequestedRecord(
                  formContext,
                  formRef,
                  entityType: 'reference',
                  entityId: reference.id,
                ),
          onSave: (values, formContext) =>
              _saveReference(reference, values, formContext),
        ),
      ),
    );
  }

  /// Saves the shared form's values into the user's own library.
  ///
  /// The allowance check and its messages live here because they are this
  /// window's rules; the admin's window publishes to the server instead. A
  /// refused save returns false, so the form stays open with the typing intact.
  Future<bool> _saveReference(
    CaseReference? existing,
    ReferenceFormValues values,
    BuildContext formContext,
  ) async {
    final l = AppLocalizations.of(formContext);
    final notifier = ref.read(referenceViewModelProvider.notifier);

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
    final isNew = existing == null;
    if (isNew && !allowance.canAddReference()) {
      if (formContext.mounted) {
        showReadOnlyWriteMessage(formContext, l.lapse_referenceLimit);
      }
      return false;
    }
    if (existing != null && !allowance.isReferenceWritable(existing.id)) {
      if (formContext.mounted) {
        showReadOnlyWriteMessage(formContext, l.lapse_readOnlyReference);
      }
      return false;
    }

    final companion = CaseReferencesCompanion(
      referenceAndPageNo: Value(values.referenceAndPageNo),
      parties: Value(values.parties),
      statute: Value(values.statute),
      sectionOrArticle: Value(values.sectionOrArticle),
      caseNote: Value(values.caseNote),
      titleAndDescription: Value(values.titleAndDescription),
      commentsNotes: Value(values.commentsNotes),
      tags: Value(values.tags),
      // The form has no pin control; an edit keeps the card's own pin.
      isPinned: Value(existing?.isPinned ?? false),
    );
    if (existing == null) {
      await notifier.addReference(companion);
    } else {
      await notifier.updateReference(
        companion.copyWith(id: Value(existing.id)),
        baseReference: existing,
      );
    }
    if (formContext.mounted) {
      ScaffoldMessenger.of(
        formContext,
      ).showSnackBar(SnackBar(content: Text(l.caseReferenceScreen_saved)));
    }
    return true;
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
    // A query reads the whole library, whichever level was being shown; closing
    // the bar or clearing the query brings the level back.
    final searching = _isSearching && _searchController.text.trim().isNotEmpty;
    final lawRows = law == null
        ? const <ReferenceRow>[]
        : rows
              .where((row) => referenceStatuteKey(row.statute) == law)
              .toList(growable: false);

    // A short library must still be pullable, and the pull must not drag the
    // cards under the finger while the indicator spins.
    final behavior = ScrollConfiguration(
      behavior: pullScrollBehavior(context),
      child: searching
          ? ReferenceList(
              isSearching: true,
              // Before the first answer arrives the whole library shows, as on
              // the Notes library, rather than a premature "No results".
              references: _search.rows ?? rows,
              totalCount: rows.length,
              writableReferenceIds: allowance?.writableReferenceIds,
              onEdit: _editIfWritable,
              onDelete: _confirmDelete,
              onTogglePin: _togglePin,
              onRefresh: _onRefresh,
            )
          : law == null
          ? ReferenceLawList(
              sections: lawSectionsFor(
                ref.watch(lawListProvider).value ?? const <Law>[],
                rows,
              ),
              onOpen: _openLawReferences,
              onRefresh: _onRefresh,
            )
          : Column(
              children: [
                ReferenceLawHeader(
                  label: law.isEmpty ? l.caseReferenceScreen_noStatute : law,
                  count: lawRows.length,
                  onBack: _closeLaw,
                ),
                Expanded(
                  child: ReferenceList(
                    isSearching: false,
                    references: lawRows,
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
