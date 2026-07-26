/// Recovery dialog shown when the encrypted database cannot be opened because
/// the key is missing. Implemented in Task 03 Phase 1.
library;

import 'package:flutter/material.dart';

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
  const DatabaseRecoveryDialog({
    required this.onReset,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Database Locked'),
      content: const Text(
        'The encryption key for your local case diary is missing. '
        'This can happen after an operating system update or if app data '
        'was cleared.\n\n'
        'To continue using the app offline, you must reset the local '
        'database. All unsynced local data will be lost.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: onReset,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Reset Local Database'),
        ),
      ],
    );
  }
}
