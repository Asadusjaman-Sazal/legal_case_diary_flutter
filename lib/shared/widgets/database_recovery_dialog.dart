/// Recovery dialog shown when the encrypted database cannot be opened because
/// the key is missing. Implemented in Task 03 Phase 1.
library;

import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import 'app_dialog.dart';
import 'app_dialog_actions.dart';

/// {@template database_recovery_dialog}
/// A dialog displayed when the encrypted local database exists but its key is
/// missing (for example after an OS update cleared the secure keychain).
///
/// In Part A the only recovery option is to reset the local database, which
/// deletes all unsynced local data. In Part B this dialog can be extended to
/// offer cloud backup restore.
/// {@endtemplate}
class DatabaseRecoveryDialog extends StatelessWidget {
  /// Callback invoked when the user chooses to reset the local database.
  final VoidCallback onReset;

  /// Creates a [DatabaseRecoveryDialog] that calls [onReset] when the reset
  /// button is pressed.
  const DatabaseRecoveryDialog({required this.onReset, super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AppDialogFrame(
      title: Text(l.databaseRecovery_title),
      content: Text(l.databaseRecovery_body),
      actions: (dialogContext) => [
        AppDialogAction(
          label: l.sharedActions_cancel,
          onPressed: () => Navigator.of(dialogContext).maybePop(),
        ),
        AppDialogAction(
          label: l.databaseRecovery_reset,
          kind: AppDialogActionKind.primary,
          background: Colors.black,
          foreground: Colors.white,
          onPressed: onReset,
        ),
      ],
    );
  }
}
