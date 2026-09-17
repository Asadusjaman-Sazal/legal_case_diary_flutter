/// Recovery dialog shown when the encrypted database cannot be opened because
/// the key is missing. Implemented in Task 03 Phase 1.
library;

import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';

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
    return AlertDialog(
      title: Text(l.databaseRecovery_title),
      content: Text(l.databaseRecovery_body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(l.sharedActions_cancel),
        ),
        TextButton(
          onPressed: onReset,
          style: TextButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          child: Text(l.databaseRecovery_reset),
        ),
      ],
    );
  }
}
