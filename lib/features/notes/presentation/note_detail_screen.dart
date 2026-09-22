/// Full-screen note detail / editor (Google Keep style).
///
/// Task 11. Mirrors the mandatory mockup `mockup_html_screens/notes/code.html`
/// "View/Edit Note Modal": a sticky top bar with Back / Pin / Delete / Check, a
/// centered scrollable Title + Note field, and a bottom "Modified: date time"
/// bar. Opens full-screen (no nav panel / bottom nav) via a pushed route.
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
import '../../../shared/widgets/confirm_dialogs.dart';
import 'notes_viewmodel.dart';

/// Note title size: 2 px above the note body, which the editor sets to
/// `bodyLg` (16). That pairing is what the user asked for — a 12 px body would
/// take a 14 px title — and it deliberately replaces the mockup's
/// `headline-lg` (30 px), which dominated the note instead of heading it.
/// Manrope semi-bold is kept, so the title still reads as a title.
const double _noteTitleSize = 18;

/// Full-screen note editor. [note] is null when creating a new note.
class NoteDetailScreen extends ConsumerStatefulWidget {
  const NoteDetailScreen({this.note, super.key});

  final Note? note;

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late bool _isPinned;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _bodyController = TextEditingController(text: widget.note?.body ?? '');
    _isPinned = widget.note?.isPinned ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
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

  Future<void> _saveAndPop() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    // Don't persist a brand-new, empty note.
    if (_isNew && title.isEmpty && body.isEmpty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final viewModel = ref.read(notesViewModelProvider.notifier);
    final companion = NotesCompanion(
      title: Value(title),
      body: Value(body),
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
    final confirmed = await confirmDeleteDialog(context);
    if (!confirmed || !mounted) return;
    await ref.read(notesViewModelProvider.notifier).deleteNote(widget.note!);
    if (mounted) Navigator.of(context).pop(widget.note);
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
                              color: AppColors.onSurfaceVariant
                                  .withValues(alpha: 0.4),
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
                        TextField(
                          controller: _bodyController,
                          decoration: InputDecoration(
                            filled: false,
                            fillColor: Colors.transparent,
                            hintText: l.notesScreen_noteBodyPlaceholder,
                            hintStyle: AppTypography.bodyLg.copyWith(
                              color: AppColors.onSurfaceVariant
                                  .withValues(alpha: 0.4),
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
                          style: AppTypography.bodyLg
                              .copyWith(color: AppColors.onSurface),
                          maxLines: null,
                          minLines: 8,
                          textInputAction: TextInputAction.newline,
                        ),
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
}
