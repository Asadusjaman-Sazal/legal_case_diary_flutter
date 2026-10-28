/// Shared confirmation dialogs used across the app.
///
/// `confirmDeleteDialog` is the single delete-confirmation window — reused by
/// Case Detail (case delete), Case History (history delete), and Notes (card /
/// detail delete). It is drawn on the shared pop-over frame
/// (`app_dialog.dart`): the same 8 px corner, elastic width and 112 x 48
/// actions as every other window, with a red Delete.
library;

import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import 'app_dialog.dart';

/// Shows the app-wide delete confirmation dialog.
///
/// Returns `true` when the user confirms, `false` (or `null`) otherwise.
Future<bool> confirmDeleteDialog(BuildContext context) {
  final l = AppLocalizations.of(context);
  return showAppConfirmDialog(
    context,
    title: l.sharedDialogs_confirmDeleteTitle,
    message: l.sharedDialogs_confirmDeleteMessage,
    confirmLabel: l.sharedActions_delete,
  );
}
