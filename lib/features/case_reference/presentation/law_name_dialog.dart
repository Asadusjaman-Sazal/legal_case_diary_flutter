/// Add/edit window for one law name.
///
/// The statute list is editable in two places — the picker's **Add a Law Name…**
/// row and Settings → Edit Court/Steps → Law Names — and both open this one
/// window, so a name is typed, categorised and saved once in one shape. It is a
/// centred pop-over on the shared frame (rule 17): the corner, width, height cap
/// and action layout come from `app_dialog.dart` / `app_dialog_metrics.dart`,
/// and nothing here restates them.
///
/// The window only collects a name and a category. The write itself happens in
/// the caller, which owns a `WidgetRef` and the repository, so an add can return
/// the new row (and select it) while an edit keeps the existing row's identity.
library;

import 'package:flutter/material.dart';

import '../../../core/l10n/app_translations.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/pre_seeded_data.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_dialog_actions.dart';

/// What the window collected: the typed name and the chosen category.
class LawNameDraft {
  /// Creates a draft from the window's two fields.
  const LawNameDraft({required this.name, required this.categoryId});

  /// The trimmed name, never empty (the form validates it).
  final String name;

  /// One of the seven stable category IDs.
  final String categoryId;
}

/// Shows the add/edit window and returns the draft, or null when cancelled.
///
/// [initialCategoryId] is the group the user was looking at, so a name added
/// from inside a category lands in that category unless they choose another.
Future<LawNameDraft?> showLawNameDialog(
  BuildContext context, {
  bool editing = false,
  String initialName = '',
  String? initialCategoryId,
}) {
  // The window's actions live in the dialog's action area, which is a sibling
  // of the content rather than its parent, so the form is addressed by key and
  // not by walking the tree.
  final formKey = GlobalKey<_LawNameFormState>();
  return showAppDialog<LawNameDraft>(
    context,
    title: Text(
      editing
          ? AppLocalizations.of(context).lawNamesScreen_editTitle
          : AppLocalizations.of(context).lawNamesScreen_addTitle,
      textAlign: TextAlign.center,
    ),
    content: _LawNameForm(
      key: formKey,
      editing: editing,
      initialName: initialName,
      initialCategoryId: initialCategoryId ?? seedLawCategories.first.id,
    ),
    actions: (dialogContext) {
      final l = AppLocalizations.of(dialogContext);
      return [
        AppDialogAction(
          label: l.sharedActions_cancel,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
        AppDialogAction(
          label: editing ? l.sharedActions_save : l.sharedActions_add,
          kind: AppDialogActionKind.primary,
          onPressed: () {
            final draft = formKey.currentState?.submit();
            if (draft != null) Navigator.of(dialogContext).pop(draft);
          },
        ),
      ];
    },
  );
}

class _LawNameForm extends StatefulWidget {
  const _LawNameForm({
    super.key,
    required this.editing,
    required this.initialName,
    required this.initialCategoryId,
  });

  final bool editing;
  final String initialName;
  final String initialCategoryId;

  @override
  State<_LawNameForm> createState() => _LawNameFormState();
}

class _LawNameFormState extends State<_LawNameForm> {
  late final TextEditingController _nameController;
  late String _categoryId;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _categoryId = widget.initialCategoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Validates and returns the draft, or null when the name is empty.
  LawNameDraft? submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return null;
    return LawNameDraft(
      name: _nameController.text.trim(),
      categoryId: _categoryId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const ValueKey('law-name-field'),
            controller: _nameController,
            autofocus: true,
            style: AppTypography.bodyLg,
            decoration: InputDecoration(
              labelText: l.lawNamesScreen_nameLabel,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? l.sharedDialogs_requiredField
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            key: const ValueKey('law-category-field'),
            initialValue: _categoryId,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius * 2),
            decoration: InputDecoration(
              labelText: l.lawNamesScreen_categoryLabel,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
            ),
            items: [
              for (final category in seedLawCategories)
                DropdownMenuItem<String>(
                  value: category.id,
                  child: Text(
                    context.l10n.lawCategoryName(category.id),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _categoryId = value);
            },
          ),
        ],
      ),
    );
  }
}
