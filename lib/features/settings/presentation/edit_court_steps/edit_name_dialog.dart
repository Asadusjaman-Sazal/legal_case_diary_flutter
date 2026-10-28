/// Shared add/edit window for the single-name rows of the Edit Court/Steps
/// sub-menus (lower court categories, court names, case types, steps,
/// on-behalf).
///
/// The whole section adds through one window, so its size lives here: a wide
/// dialog with a full-width field and comfortable Cancel/Save buttons instead
/// of the default compact [AlertDialog].
library;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_dialog_actions.dart';

/// Add/edit window for one named row.
///
/// Pops the typed name, or `null` when the user cancels.
class EditNameDialog extends StatefulWidget {
  /// Window title, e.g. "Add Court Name".
  final String title;

  /// Label of the single text field.
  final String fieldLabel;

  /// Pre-filled name when editing; null when adding.
  final String? initialName;

  const EditNameDialog({
    super.key,
    required this.title,
    required this.fieldLabel,
    this.initialName,
  });

  @override
  State<EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<EditNameDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AppDialogFrame(
      // Roomier than the default window: the field spans the dialog and the
      // action buttons stay comfortable tap targets on a phone.
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xl,
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      title: Text(widget.title, style: AppTypography.titleLg),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          style: AppTypography.bodyLg,
          decoration: InputDecoration(
            labelText: widget.fieldLabel,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? l.sharedDialogs_requiredField
              : null,
        ),
      ),
      actions: (dialogContext) => [
        AppDialogAction(
          label: l.sharedActions_cancel,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
        AppDialogAction(
          label: l.sharedActions_save,
          kind: AppDialogActionKind.primary,
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(dialogContext).pop(_controller.text.trim());
          },
        ),
      ],
    );
  }
}
