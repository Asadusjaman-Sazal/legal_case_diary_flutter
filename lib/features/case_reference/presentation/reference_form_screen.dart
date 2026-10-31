/// The Add/Edit Case Reference form, shared by the user's own library and the
/// Admin Panel's official library.
///
/// One body for both windows (user request, 0.0.755): the same five fields
/// with their labels above the boxes, the same law picker with **Add a Law
/// Name…**, the same black title band and the same pinned Save. A window keeps
/// only what belongs to its side — the title it shows and the save that stores
/// its rows (the user's locally and queued, the admin's on the server) — so a
/// change made here reaches both windows and cannot drift.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../database/app_database.dart';
import '../../settings/presentation/edit_court_steps/next_order_index.dart';
import 'law_name_dialog.dart';
import 'law_picker.dart';
import 'reference_library.dart';

/// The seven values the form hands to its window's own save.
///
/// Optional fields are null when their box is blank, which is how both tables
/// already store an empty reference field. Tags arrive canonicalized.
class ReferenceFormValues {
  /// Creates the values from the form's boxes.
  const ReferenceFormValues({
    required this.referenceAndPageNo,
    this.statute,
    this.sectionOrArticle,
    this.caseNote,
    this.titleAndDescription,
    this.commentsNotes,
    this.tags,
  });

  final String referenceAndPageNo;
  final String? statute;
  final String? sectionOrArticle;
  final String? caseNote;
  final String? titleAndDescription;
  final String? commentsNotes;
  final String? tags;
}

/// Stores the form's values; true closes the window.
///
/// The window's own save also owns its messages, so the admin's offline
/// refusal and the user's lapse messages read exactly as they did before the
/// two windows shared a body.
typedef ReferenceFormSave =
    Future<bool> Function(ReferenceFormValues values, BuildContext formContext);

/// A question asked before the form is used (the user's edit-of-a-deletion
/// warning); false closes the window without saving.
typedef ReferenceFormConfirmOpen =
    Future<bool> Function(BuildContext formContext, WidgetRef ref);

/// The shared Add/Edit form: title band, seven labelled fields, Save.
class ReferenceFormScreen extends ConsumerStatefulWidget {
  /// Creates the form with the window's title, its starting values and the
  /// save that stores them.
  const ReferenceFormScreen({
    required this.title,
    required this.onSave,
    this.referenceAndPageNo = '',
    this.statute,
    this.sectionOrArticle = '',
    this.caseNote = '',
    this.titleAndDescription = '',
    this.commentsNotes = '',
    this.tags = '',
    this.tagOptions = const <String>[],
    this.confirmOpen,
    super.key,
  });

  /// The window's band title, e.g. **Add Case Reference** or **Edit Official
  /// Reference**; each window keeps its own.
  final String title;

  /// Stores the values and returns whether the window should close.
  final ReferenceFormSave onSave;

  /// The starting values of the boxes.
  final String referenceAndPageNo;
  final String? statute;
  final String sectionOrArticle;
  final String caseNote;
  final String titleAndDescription;
  final String commentsNotes;
  final String tags;

  /// Every tag the window's library already uses, alphabetical; the Tags box
  /// lists them in a dropdown so a tag can be reused instead of retyped.
  final List<String> tagOptions;

  /// Asked once after the first frame, when the window has one.
  final ReferenceFormConfirmOpen? confirmOpen;

  @override
  ConsumerState<ReferenceFormScreen> createState() =>
      _ReferenceFormScreenState();
}

class _ReferenceFormScreenState extends ConsumerState<ReferenceFormScreen> {
  late final TextEditingController _refNo;
  late final TextEditingController _section;
  late final TextEditingController _caseNote;
  late final TextEditingController _title;
  late final TextEditingController _comments;
  late final TextEditingController _tags;

  /// Opens the Tags box's list of already-used tags.
  final MenuController _tagsMenu = MenuController();

  /// The cited law's name, chosen from the law list rather than typed.
  ///
  /// It stays a plain name rather than an id because `case_references.statute`
  /// has always held text: an existing reference keeps whatever it was saved
  /// with, including a name the list has never heard of, and the window keeps
  /// showing it until the user picks a different one.
  String? _statute;

  /// True while the window's save runs, so Save cannot be pressed twice.
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _refNo = TextEditingController(text: widget.referenceAndPageNo);
    _section = TextEditingController(text: widget.sectionOrArticle);
    _caseNote = TextEditingController(text: widget.caseNote);
    _title = TextEditingController(text: widget.titleAndDescription);
    _comments = TextEditingController(text: widget.commentsNotes);
    _tags = TextEditingController(text: widget.tags);
    _statute = _nullable(widget.statute);
    final confirm = widget.confirmOpen;
    if (confirm != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        if (!await confirm(context, ref) && mounted) {
          Navigator.of(context).maybePop();
        }
      });
    }
  }

  @override
  void dispose() {
    _refNo.dispose();
    _section.dispose();
    _caseNote.dispose();
    _title.dispose();
    _comments.dispose();
    _tags.dispose();
    super.dispose();
  }

  /// Opens the same grouped law picker both windows have always used, and its
  /// **Add a Law Name…** row when the citation's law is not listed yet.
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

  /// Hands the values to the window's save and closes only on success, so a
  /// refusal (offline, over the allowance) leaves the window open with the
  /// user's typing intact.
  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final values = ReferenceFormValues(
      referenceAndPageNo: _refNo.text.trim(),
      statute: _nullable(_statute),
      sectionOrArticle: _nullable(_section.text),
      caseNote: _nullable(_caseNote.text),
      titleAndDescription: _nullable(_title.text),
      commentsNotes: _nullable(_comments.text),
      tags: canonicalReferenceTags(_tags.text),
    );
    bool saved;
    try {
      saved = await widget.onSave(values, context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (saved && mounted) Navigator.of(context).pop(true);
  }

  /// A trimmed value, or null when the box is blank.
  static String? _nullable(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasStatute = _statute != null && _statute!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // The app's black band, the same one the Quick Update window wears.
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
                    widget.title,
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
              key: const ValueKey('reference-form-scroll'),
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                _field(
                  label: l.caseReferenceScreen_referenceAndPageNo,
                  controller: _refNo,
                  key: const ValueKey('reference-form-citation'),
                ),
                _statuteField(l, hasStatute),
                _field(
                  label: l.caseReferenceScreen_sectionOrArticle,
                  controller: _section,
                ),
                _field(
                  label: l.caseReferenceScreen_caseNote,
                  controller: _caseNote,
                  maxLines: 3,
                  key: const ValueKey('reference-form-case-note'),
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
                _tagsField(l),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('reference-form-save'),
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
  ///
  /// The label sits above the box (user request), not floating on its border.
  Widget _field({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    Key? key,
  }) => Padding(
    key: key,
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: AppTypography.bodyLg,
          decoration: InputDecoration(
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
      ],
    ),
  );

  /// The label every field on this form wears above its box.
  Widget _fieldLabel(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.sm,
      AppSpacing.xs,
      AppSpacing.sm,
      AppSpacing.xs,
    ),
    child: Text(
      label,
      style: AppTypography.labelLg.copyWith(color: AppColors.onSurfaceVariant),
    ),
  );

  /// The statute field: a tappable box over the shared law list.
  Widget _statuteField(AppLocalizations l, bool hasStatute) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(l.caseReferenceScreen_statute),
        InkWell(
          key: const ValueKey('reference-form-statute'),
          onTap: _pickStatute,
          borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
          child: InputDecorator(
            decoration: InputDecoration(
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
      ],
    ),
  );

  /// The Tags box: free comma-separated text, with a dropdown of every tag the
  /// window's library already uses, alphabetical, so a tag is reused instead of
  /// retyped (user request). Choosing one appends it; typing a new one works
  /// exactly as before.
  Widget _tagsField(AppLocalizations l) {
    final options = <String>[...widget.tagOptions]
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final present = referenceTags(
      _tags.text,
    ).map((tag) => tag.toLowerCase()).toSet();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(l.caseReferenceScreen_tags),
          MenuAnchor(
            controller: _tagsMenu,
            alignmentOffset: const Offset(0, 4),
            menuChildren: [
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 280,
                  maxHeight: 240,
                ),
                child: SingleChildScrollView(
                  // The menu floats above the form; it must not join the form
                  // list's primary controller, or the scrollbar sees two
                  // positions on one controller.
                  primary: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final tag in options)
                        MenuItemButton(
                          key: ValueKey('reference-tag-option-$tag'),
                          leadingIcon: present.contains(tag.toLowerCase())
                              ? const Icon(Icons.check, size: 18)
                              : null,
                          onPressed: () {
                            _tagsMenu.close();
                            _appendTag(tag);
                          },
                          child: Text(tag),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            builder: (context, controller, _) => TextField(
              key: const ValueKey('reference-form-tags'),
              controller: _tags,
              style: AppTypography.bodyLg,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                suffixIcon: options.isEmpty
                    ? null
                    : IconButton(
                        key: const ValueKey('reference-tags-menu'),
                        tooltip: l.caseReferenceScreen_tags,
                        icon: const Icon(Icons.arrow_drop_down),
                        onPressed: () => controller.isOpen
                            ? controller.close()
                            : controller.open(),
                      ),
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
          ),
        ],
      ),
    );
  }

  /// Appends [tag] to the box once, keeping the stored `tag1, tag2` shape.
  void _appendTag(String tag) {
    final current = referenceTags(_tags.text);
    if (current.any((t) => t.toLowerCase() == tag.toLowerCase())) return;
    final next = <String>[...current, tag].join(', ');
    setState(() {
      _tags.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    });
  }
}
