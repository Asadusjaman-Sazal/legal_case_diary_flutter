/// Notes screen: notes library with search, add/edit, pinning, and delete.
///
/// Task 11 Phase 1. Card layout mirrors the mandatory mockup
/// `mockup_html_screens/notes/code.html`. Uses [CasesScreenModal] for the shared
/// header (nav panel + search) and bottom nav.
library;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/utils/date_utils.dart';
import '../../../database/app_database.dart';
import '../../cases/presentation/cases_screen_modal.dart';
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

  Future<void> _confirmDelete(Note note) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.sharedDialogs_confirmDeleteTitle),
        content: Text(l.sharedDialogs_confirmDeleteMessage),
        actions: [
          TextButton(
            key: const ValueKey('notes-delete-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.sharedActions_cancel),
          ),
          TextButton(
            key: const ValueKey('notes-delete-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.sharedActions_delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(notesViewModelProvider.notifier).deleteNote(note);
  }

  void _togglePin(Note note) {
    ref
        .read(notesViewModelProvider.notifier)
        .setPinned(note.id, !note.isPinned);
  }

  Future<void> _openEditor({Note? note}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _NoteEditorSheet(note: note),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final notesAsync = ref.watch(notesViewModelProvider);

    final notes = notesAsync.value?.items ?? const <Note>[];
    final query = _searchController.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? notes
        : notes.where((n) {
            final hay = '${n.title} ${n.body}'.toLowerCase();
            return hay.contains(query);
          }).toList();

    return CasesScreenModal(
      title: l.notesScreen_title,
      onSearch: _toggleSearch,
      onAddCase: () => _openEditor(),
      body: _NotesList(
        isSearching: _isSearching,
        searchController: _searchController,
        onSearchChanged: (_) => setState(() {}),
        notes: visible,
        totalCount: notes.length,
        locale: Localizations.localeOf(context).toLanguageTag(),
        onEdit: (note) => _openEditor(note: note),
        onDelete: _confirmDelete,
        onTogglePin: _togglePin,
      ),
    );
  }
}

/// Scrollable notes list with optional inline search field.
class _NotesList extends StatelessWidget {
  const _NotesList({
    required this.isSearching,
    required this.searchController,
    required this.onSearchChanged,
    required this.notes,
    required this.totalCount,
    required this.locale,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePin,
  });

  final bool isSearching;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
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

    if (isSearching) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: TextField(
            controller: searchController,
            autofocus: true,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: l.sharedActions_search,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
      );
    }

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

/// Add/Edit note bottom sheet.
class _NoteEditorSheet extends ConsumerStatefulWidget {
  const _NoteEditorSheet({this.note});

  final Note? note;

  @override
  ConsumerState<_NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends ConsumerState<_NoteEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.note?.title ?? '';
    _bodyController.text = widget.note?.body ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final viewModel = ref.read(notesViewModelProvider.notifier);
    final companion = NotesCompanion(
      title: Value(_titleController.text.trim()),
      body: Value(_bodyController.text.trim()),
    );
    if (widget.note == null) {
      await viewModel.addNote(companion);
    } else {
      await viewModel.updateNote(
        companion.copyWith(id: Value(widget.note!.id)),
        baseNote: widget.note,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.note == null ? l.sharedActions_add : l.sharedActions_edit,
              style: AppTypography.titleMd.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: l.notesScreen_noteTitle,
                border: const OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? l.sharedDialogs_requiredField
                      : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _bodyController,
              decoration: InputDecoration(
                labelText: l.notesScreen_noteBody,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 6,
              minLines: 3,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l.sharedActions_cancel),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: Text(l.sharedActions_save),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
