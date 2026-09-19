/// Notes screen: notes library with search, add/edit, pinning, and delete.
///
/// Task 11 Phase 1/2. Card layout mirrors the mandatory mockup
/// `mockup_html_screens/notes/code.html`. Tapping a card (or the FAB) opens the
/// full-screen [NoteDetailScreen] (Google Keep style). Uses [CasesScreenModal]
/// for the shared header (nav panel + search) and bottom nav.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/scoped_search.dart';
import '../../../database/app_database.dart';
import '../../cases/presentation/cases_screen_modal.dart';
import '../../../shared/widgets/confirm_dialogs.dart';
import 'note_detail_screen.dart';
import 'notes_viewmodel.dart';

/// Notes library screen.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  /// The screen's live scoped search (Task 14 Phase 5, plan §12.1): the query
  /// runs as a Drift `LIKE` query over the note's title and body, rather than
  /// filtering the notes this screen happened to have loaded.
  late final ScopedSearch<Note> _search = ScopedSearch(fetch: _searchNotes);

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

  /// Runs one query through `NotesDao.search` (title and body).
  Future<List<Note>> _searchNotes(String query) async {
    final repository = await ref.read(notesRepositoryProvider.future);
    return repository.search(query);
  }

  /// Types into the bar: the query goes to SQL, then the library rebuilds.
  Future<void> _onSearchChanged(String query) async {
    await _search.run(query);
    if (mounted) setState(() {});
  }

  /// Opens the full-screen detail editor. [note] is null when creating new.
  /// If the detail screen pops with a deleted [Note], shows the undo snackbar.
  Future<void> _openDetail({Note? note}) async {
    final result = await Navigator.of(context).push<Note?>(
      MaterialPageRoute(builder: (_) => NoteDetailScreen(note: note)),
    );
    if (result is Note && mounted) _showUndoSnackBar(result);
  }

  Future<void> _confirmDelete(Note note) async {
    final confirmed = await confirmDeleteDialog(context);
    if (!confirmed || !mounted) return;
    await ref.read(notesViewModelProvider.notifier).deleteNote(note);
    _showUndoSnackBar(note);
  }

  /// Shows a Google Keep–style undo snackbar after a note is deleted.
  void _showUndoSnackBar(Note note) {
    final l = AppLocalizations.of(context);
    final controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.notesScreen_noteDeleted),
        behavior: SnackBarBehavior.floating,
        width: 400,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: l.notesScreen_undo,
          onPressed: () =>
              ref.read(notesViewModelProvider.notifier).restoreNote(note),
        ),
      ),
    );
    // Enforce the 3s window even when the action button holds pointer focus
    // (desktop hover pauses the SnackBar's built-in auto-dismiss timer).
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) controller.close();
    });
  }

  void _togglePin(Note note) {
    ref
        .read(notesViewModelProvider.notifier)
        .setPinned(note.id, !note.isPinned);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final notesAsync = ref.watch(notesViewModelProvider);

    final notes = notesAsync.value?.items ?? const <Note>[];
    // The query's own rows while one is in force, otherwise the library.
    final visible = _search.rows ?? notes;

    return CasesScreenModal(
      title: l.notesScreen_title,
      onSearch: _toggleSearch,
      // The bar is mounted by the shared modal, exactly as on the case-list
      // screens: it sits under the header, above the scrolling list, and stays
      // there while the library is empty.
      isSearching: _isSearching,
      searchController: _searchController,
      onSearchChanged: _onSearchChanged,
      onAddCase: () => _openDetail(),
      body: _NotesList(
        isSearching: _isSearching,
        notes: visible,
        totalCount: notes.length,
        locale: Localizations.localeOf(context).toLanguageTag(),
        onEdit: (note) => _openDetail(note: note),
        onDelete: _confirmDelete,
        onTogglePin: _togglePin,
      ),
    );
  }
}

/// Scrollable notes list; the search bar lives in the modal above it.
class _NotesList extends StatelessWidget {
  const _NotesList({
    required this.isSearching,
    required this.notes,
    required this.totalCount,
    required this.locale,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePin,
  });

  final bool isSearching;
  final List<Note> notes;
  final int totalCount;
  final String locale;
  final ValueChanged<Note> onEdit;
  final ValueChanged<Note> onDelete;
  final ValueChanged<Note> onTogglePin;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final children = <Widget>[];

    if (notes.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Center(
            child: Text(
              isSearching && totalCount > 0
                  ? l.sharedDialogs_noResults
                  : l.notesScreen_empty,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    for (var i = 0; i < notes.length; i++) {
      if (i > 0) children.add(const SizedBox(height: AppSpacing.md));
      final note = notes[i];
      children.add(
        _NoteCard(
          note: note,
          locale: locale,
          onEdit: () => onEdit(note),
          onDelete: () => onDelete(note),
          onTogglePin: () => onTogglePin(note),
        ),
      );
    }
    children.add(const SizedBox(height: AppSpacing.lg));

    return ListView(padding: const EdgeInsets.all(AppSpacing.md), children: children);
  }
}

/// A single note card matching the mandatory mockup layout.
class _NoteCard extends StatefulWidget {
  const _NoteCard({
    required this.note,
    required this.locale,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePin,
  });

  final Note note;
  final String locale;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final note = widget.note;
    final modified = AppDateUtils.formatNoteCardDate(
      note.updatedAt,
      locale: widget.locale,
    );
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
                // Part 1: modified date + delete/pin actions.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${l.notesScreen_modified}: $modified',
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('note-delete'),
                      icon: const Icon(Icons.delete_outline),
                      color: AppColors.onSurfaceVariant,
                      tooltip: l.notesScreen_delete,
                      onPressed: widget.onDelete,
                    ),
                    IconButton(
                      key: const ValueKey('note-pin'),
                      icon: Icon(
                        note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      ),
                      color: note.isPinned
                          ? AppColors.secondary
                          : AppColors.onSurfaceVariant,
                      tooltip: l.notesScreen_pin,
                      onPressed: widget.onTogglePin,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                // Part 2: bold, slightly larger title.
                Text(
                  note.title,
                  style: AppTypography.titleMd.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Part 3: body text.
                Text(
                  note.body,
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
