/// Full-screen note detail / editor (Google Keep style).
///
/// Task 11. Mirrors the mandatory mockup `mockup_html_screens/notes/code.html`
/// "View/Edit Note Modal": a sticky top bar with Back / Pin / Delete / Check, a
/// centered scrollable Title + Note field, and a bottom "Modified: date time"
/// bar. Opens full-screen (no nav panel / bottom nav) via a pushed route.
///
/// Two kinds of note share this screen, and only the body differs: a text note
/// (the mockup's Note field) and a to-do, whose body is Keep's checklist — a
/// tick, an editable item and a remove button per row, ticked items dropping
/// below the unticked ones. The kind is fixed when the note is created: the FAB
/// on the Notes screen asks which, and an existing note reads its own stored
/// checklist rather than a flag.
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
import '../../settings/presentation/delete_request_flow.dart';
import '../data/note_items.dart';
import 'notes_viewmodel.dart';

/// Note title size: 2 px above the note body, which the editor sets to
/// `bodyLg` (16). That pairing is what the user asked for — a 12 px body would
/// take a 14 px title — and it deliberately replaces the mockup's
/// `headline-lg` (30 px), which dominated the note instead of heading it.
/// Manrope semi-bold is kept, so the title still reads as a title.
const double _noteTitleSize = 18;

/// Full-screen note editor. [note] is null when creating a new note, and
/// [isTodo] then says which kind the FAB asked for; an existing note's kind
/// comes from its own stored checklist.
class NoteDetailScreen extends ConsumerStatefulWidget {
  const NoteDetailScreen({this.note, this.isTodo = false, super.key});

  final Note? note;

  /// Kind of a **new** note (ignored when [note] is given).
  final bool isTodo;

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

/// One editable to-do row: its text, its tick, and the focus node that lets
/// Enter open the next row.
class _TodoRow {
  _TodoRow({required String text, required this.done, required this.order})
    : controller = TextEditingController(text: text);

  final TextEditingController controller;
  final FocusNode focusNode = FocusNode();
  bool done;

  /// The row's place among the unticked rows, fixed when it was created.
  ///
  /// Ticking and unticking only move a row aside in the list; this is what puts
  /// it back where it was, instead of at the end, when it is unticked.
  final int order;

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final bool _isTodo;
  late bool _isPinned;

  /// The checklist, in display order: every unticked row, then every ticked one.
  final List<_TodoRow> _todoRows = [];

  /// Next [order] handed out, so a row added later sorts after the rows it
  /// was added to.
  int _nextItemOrder = 0;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _bodyController = TextEditingController(text: widget.note?.body ?? '');
    _isPinned = widget.note?.isPinned ?? false;
    // A stored checklist is what makes an existing note a to-do; a new one
    // takes the kind the FAB asked for.
    final storedItems = decodeNoteItems(widget.note?.items);
    _isTodo = widget.note == null ? widget.isTodo : storedItems != null;
    if (_isTodo) {
      final stored = storedItems ?? const <NoteItem>[];
      for (final item in stored) {
        _todoRows.add(
          _TodoRow(
            text: item.text,
            done: item.done,
            order: _nextItemOrder++,
          ),
        );
      }
      // A brand-new to-do opens ready to type, like Keep's own empty list.
      if (_todoRows.isEmpty) _todoRows.add(_newRow(text: ''));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    for (final row in _todoRows) {
      row.dispose();
    }
    super.dispose();
  }

  bool get _isNew => widget.note == null;

  String get _modifiedLabel {
    final l = AppLocalizations.of(context);
    if (_isNew) return l.notesScreen_drafting;
    final date = AppDateUtils.formatNoteCardDate(
      widget.note!.updatedAt,
      locale: Localizations.localeOf(context).toLanguageTag(),
    );
    return '${l.notesScreen_modified}: $date';
  }

  /// The checklist as it will be stored: blank rows are dropped, so a stray
  /// empty field never becomes an item.
  List<NoteItem> get _items => <NoteItem>[
    for (final row in _todoRows)
      if (row.controller.text.trim().isNotEmpty)
        NoteItem(text: row.controller.text.trim(), done: row.done),
  ];

  Future<void> _saveAndPop() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final items = _items;

    // Don't persist a brand-new, empty note.
    final isEmpty = _isTodo ? items.isEmpty : body.isEmpty;
    if (_isNew && title.isEmpty && isEmpty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final viewModel = ref.read(notesViewModelProvider.notifier);
    final companion = NotesCompanion(
      title: Value(title),
      // `body` mirrors the item texts for the title+body search; the checklist
      // itself is `items`. A text note keeps `items` null, which is what makes
      // it a text note.
      body: Value(
        _isTodo ? noteItemsAsBody(items) : body,
      ),
      items: Value(_isTodo ? encodeNoteItems(items) : null),
    );

    if (_isNew) {
      await viewModel.addNote(companion);
    } else {
      await viewModel.updateNote(
        companion.copyWith(id: Value(widget.note!.id)),
        baseNote: widget.note,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _togglePin() async {
    if (_isNew) return;
    final next = !_isPinned;
    setState(() => _isPinned = next);
    await ref
        .read(notesViewModelProvider.notifier)
        .setPinned(widget.note!.id, next);
  }

  Future<void> _delete() async {
    final note = widget.note!;
    final outcome = await deleteThroughFirmRules(
      context,
      ref,
      entityType: 'note',
      entityId: note.id,
      entitySnapshot: deleteRequestSnapshot(note.toJson()),
      targetBaseVersion: deletionBaseVersion(note.version),
      deleteDirectly: () async =>
          await ref.read(notesViewModelProvider.notifier).deleteNote(note),
    );
    // Closing the screen returns the note to the list for its undo snackbar; a
    // request deletes nothing, so the note stays open and only the toast shows.
    if (mounted && outcome == DeleteOutcome.deleted) {
      Navigator.of(context).pop(note);
    }
  }

  /// Creates a row with the next [order] in line.
  _TodoRow _newRow({required String text, bool done = false}) =>
      _TodoRow(text: text, done: done, order: _nextItemOrder++);

  /// Index of the first ticked row, or the list's length when there is none.
  ///
  /// Everything before it is the unticked block; everything from it on is the
  /// ticked one.
  int get _firstTicked {
    final first = _todoRows.indexWhere((row) => row.done);
    return first == -1 ? _todoRows.length : first;
  }

  /// Ticks or unticks one row and re-lays the list out.
  ///
  /// Unticked rows come first and ticked ones below them. Ticking sends the row
  /// to the **bottom**, below every ticked row before it; unticking puts it back
  /// among the unticked rows **at the place its own [order] gives it**, which is
  /// where it was before it was ever ticked.
  void _setDone(int index, bool done) {
    setState(() {
      final row = _todoRows[index];
      row.done = done;
      _todoRows.removeAt(index);
      if (done) {
        _todoRows.add(row);
        return;
      }
      // Back into the unticked block, before the first row that outranks it.
      final untickedCount = _firstTicked;
      var target = untickedCount;
      for (var i = 0; i < untickedCount; i++) {
        if (_todoRows[i].order > row.order) {
          target = i;
          break;
        }
      }
      _todoRows.insert(target, row);
    });
  }

  /// Adds an empty row at the end of the unticked block and focuses it.
  void _addItem() {
    final row = _newRow(text: '');
    setState(() => _todoRows.insert(_firstTicked, row));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) row.focusNode.requestFocus();
    });
  }

  /// Removes one row; its controllers are released once the rebuild has taken
  /// the old field off the tree.
  void _removeItem(int index) {
    final removed = _todoRows[index];
    setState(() => _todoRows.removeAt(index));
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLowest,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Sticky top bar.
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.outlineVariant),
                ),
                color: AppColors.surfaceContainerLowest,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    color: AppColors.onSurface,
                    tooltip: l.sharedActions_close,
                    onPressed: _saveAndPop,
                  ),
                  if (_isNew)
                    Expanded(
                      child: Text(
                        l.notesScreen_drafting,
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    ),
                    color: _isPinned
                        ? AppColors.secondary
                        : AppColors.onSurfaceVariant,
                    tooltip: l.notesScreen_pin,
                    onPressed: _isNew ? null : _togglePin,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: AppColors.onSurfaceVariant,
                    tooltip: l.notesScreen_delete,
                    onPressed: _isNew ? null : _delete,
                  ),
                  IconButton(
                    icon: const Icon(Icons.check),
                    color: AppColors.onSurfaceVariant,
                    tooltip: l.sharedActions_save,
                    onPressed: _saveAndPop,
                  ),
                ],
              ),
            ),
            // Scrollable content.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xl,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 768),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            filled: false,
                            fillColor: Colors.transparent,
                            hintText: l.notesScreen_noteTitle,
                            hintStyle: AppTypography.titleLg.copyWith(
                              fontSize: _noteTitleSize,
                              color: AppColors.onSurfaceVariant.withValues(
                                alpha: 0.4,
                              ),
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isCollapsed: true,
                          ),
                          style: AppTypography.titleLg.copyWith(
                            fontSize: _noteTitleSize,
                            color: AppColors.primary,
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.next,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: AppColors.outlineVariant,
                          ),
                        ),
                        if (_isTodo)
                          _todoChecklist(context)
                        else
                          _bodyField(context, l),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Bottom toolbar.
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.outlineVariant),
                ),
                color: AppColors.surfaceContainerLowest,
              ),
              child: Row(
                children: [
                  Text(
                    _modifiedLabel,
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The mockup's Note field: a plain multi-line body with no input chrome.
  Widget _bodyField(BuildContext context, AppLocalizations l) => TextField(
    controller: _bodyController,
    decoration: InputDecoration(
      filled: false,
      fillColor: Colors.transparent,
      hintText: l.notesScreen_noteBodyPlaceholder,
      hintStyle: AppTypography.bodyLg.copyWith(
        color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
      ),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
      isCollapsed: true,
    ),
    style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
    maxLines: null,
    minLines: 8,
    textInputAction: TextInputAction.newline,
  );

  /// Google Keep's list body: a tick, an editable item and a remove button per
  /// row, with an Add Item row beneath them.
  Widget _todoChecklist(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < _todoRows.length; index++)
          _todoRow(context, l, index),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('todo-add-item'),
            onPressed: _addItem,
            // The app's TextButtons are filled black, so the label and its
            // icon read white on it.
            icon: const Icon(Icons.add, color: AppColors.onPrimary),
            label: Text(
              l.notesScreen_addItem,
              style: AppTypography.bodyLg.copyWith(
                color: AppColors.onPrimary,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.sm,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _todoRow(BuildContext context, AppLocalizations l, int index) {
    final row = _todoRows[index];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // A compact tick: Keep's own checkbox, without the 48 px tap target it
        // would otherwise take from a one-line list.
        SizedBox(
          width: 32,
          child: Checkbox(
            key: ValueKey('todo-checkbox-$index'),
            value: row.done,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeColor: AppColors.secondary,
            onChanged: (done) => _setDone(index, done ?? false),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: TextField(
            key: ValueKey('todo-item-$index'),
            controller: row.controller,
            focusNode: row.focusNode,
            decoration: InputDecoration(
              filled: false,
              fillColor: Colors.transparent,
              hintText: l.notesScreen_listItemHint,
              hintStyle: AppTypography.bodyLg.copyWith(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isCollapsed: true,
            ),
            style: AppTypography.bodyLg.copyWith(
              color: row.done
                  ? AppColors.onSurfaceVariant
                  : AppColors.onSurface,
              decoration: row.done ? TextDecoration.lineThrough : null,
            ),
            maxLines: null,
            textInputAction: TextInputAction.next,
            // Enter on a row opens the next one, the way Keep's list behaves.
            onSubmitted: (_) => _addItem(),
          ),
        ),
        IconButton(
          key: ValueKey('todo-remove-$index'),
          icon: const Icon(Icons.close, size: 18),
          color: AppColors.onSurfaceVariant,
          tooltip: l.notesScreen_removeItem,
          onPressed: () => _removeItem(index),
        ),
      ],
    );
  }
}
