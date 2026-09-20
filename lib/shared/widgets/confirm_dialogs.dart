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

/// The Exit App window's action size, repeated here so the two delete buttons
/// are the same size as that window's `Exit` and `Cancel` (112x48, 16 pt).
const Size _confirmActionSize = Size(112, 48);
const TextStyle _confirmActionTextStyle = TextStyle(fontSize: 16);

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
      // Centre-aligned like the Exit App window, not the AlertDialog default.
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: _confirmActionSize,
            textStyle: _confirmActionTextStyle,
          ),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.sharedActions_cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            minimumSize: _confirmActionSize,
            textStyle: _confirmActionTextStyle,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.sharedActions_delete),
        ),
      ],
    ),
  );
  return confirmed == true;
}
