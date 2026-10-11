/// The Delete Data flow every entry point shares.
///
/// Manage Account's two Danger Zone cards and the Backup & Restore
/// restore-guard all run this one function, so "works exactly like Manage
/// Account > Delete Local & Cloud Data" is a property of the code rather than
/// two flows kept in step by hand: the firm/offline refusals, the tick list,
/// the typed screen, the service run and the result toast.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../data/data_deletion_service.dart';
import 'data_deletion_dialog.dart';
import 'delete_data_confirm_screen.dart';

/// Runs the Delete Data flow: refusals, tick list, typed screen, deletion.
///
/// [cloud] picks the wording and the reach (the cloud card also clears the
/// account's copies); [online] and [firmMode] are the live answers the caller
/// watched, handed in rather than re-read, because a lazily-taken first
/// snapshot answers "unknown". [onWorking] brackets the service run only, so a
/// caller can answer the tap with a spinner the way Logout does.
///
/// Returns the result, or null when nothing was deleted — a refusal or a
/// cancellation, each already reported where the user can see it.
Future<DataDeletionResult?> runDataDeletionFlow(
  BuildContext context,
  WidgetRef ref, {
  required bool cloud,
  required bool online,
  required bool firmMode,
  void Function(bool working)? onWorking,
}) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  if (firmMode) {
    messenger.showSnackBar(
      SnackBar(content: Text(l.settingsManageAccount_deleteDataFirmRefused)),
    );
    return null;
  }
  if (cloud && !online) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(l.settingsManageAccount_deleteDataNeedsConnection),
      ),
    );
    return null;
  }

  // A dismissed window is a cancellation: the tick list returns nothing and
  // this returns without touching the database.
  if (!context.mounted) return null;
  final scope = await showDataDeletionDialog(context, cloud: cloud);
  if (!context.mounted || scope == null || scope.isEmpty) return null;

  // The typed gate: the tick list says what goes and this screen is the point
  // of no return. Back is a cancellation.
  final confirmed = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => const DeleteDataConfirmScreen()),
  );
  if (!context.mounted || confirmed != true) return null;

  onWorking?.call(true);
  DataDeletionResult result;
  try {
    final service = await ref.read(dataDeletionServiceProvider.future);
    result = await service.delete(scope: scope, cloud: cloud);
  } on Object {
    // The service reports its own failures, so this is the provider itself
    // being unreadable — the same sentence either way, and nothing deleted.
    result = const DataDeletionResult(
      counts: <DataDeletionCategory, int>{},
      failed: true,
    );
  } finally {
    // Clear the spinner whatever the outcome, so a failure never leaves the
    // card stuck spinning — the same rule the Logout card follows.
    onWorking?.call(false);
  }
  if (!context.mounted) return null;

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        result.failed
            ? l.settingsManageAccount_deleteDataFailed
            : cloud && !result.cloudSent
            // The local deletes are done; the account's copies are queued and
            // the worker sends them on the next successful sync.
            ? l.settingsManageAccount_deleteDataCloudPending
            : l.settingsManageAccount_deleteDataDone,
      ),
    ),
  );
  return result;
}
