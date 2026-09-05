/// Shared confirmation dialogs used across the app.
///
/// `confirmDeleteDialog` is the single delete-confirmation window — reused by
/// Case Detail (case delete), Case History (history delete), and Notes (card /
/// detail delete). It matches the mandatory design: a titled [AlertDialog] with
/// a Cancel button and a red Delete button.
library;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/l10n/generated/app_localizations.dart';

/// Shows the app-wide delete confirmation dialog.
///
/// Returns `true` when the user confirms, `false` (or `null`) otherwise.
Future<bool> confirmDeleteDialog(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.sharedDialogs_confirmDeleteTitle),
      content: Text(l.sharedDialogs_confirmDeleteMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.sharedActions_cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.sharedActions_delete),
        ),
      ],
    ),
  );
  return confirmed == true;
}
