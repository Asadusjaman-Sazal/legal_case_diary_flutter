/// The windows and the single entry point for a branched logout
/// (Task 19 Phase 6).
///
/// One orchestrator, [runBranchedLogout], so every place that ends a session
/// takes the same path: Manage Account's Log out and the forced re-login notice
/// both call it and nothing else decides what happens to the local data.
///
/// The dialogs follow the app's established window style, and the two of them
/// exist for the two moments the plan names: the **offline block**, which says
/// the changes must sync first and offers an explicit way past, and the
/// **unsynced warning**, which names exactly what logging out now costs.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../settings/data/backup_metadata_store.dart';
import '../../settings/presentation/backup_dialogs.dart';
import '../data/logout_flow.dart';

/// Logs out through the branch this account and this device state call for.
///
/// [cannotSync] is set by the forced re-login path, where the session the server
/// rejected cannot authenticate a push: the premium-and-online branch then
/// behaves exactly as if its mandatory sync had failed, which is the honest
/// route rather than one that is certain to fail.
///
/// [dialogContext] exists for that same caller. The forced re-login notice sits
/// **above** the app's navigator (it wraps the whole app), so a dialog opened
/// from its own context would have no navigator to open on; it passes the
/// overlay's context instead. Every other caller leaves it null.
///
/// Returns **true only when the session was actually ended** (the wipe ran and
/// `signOut` completed). Every cancellation — a declined offline block, a closed
/// warning, a dismissed passphrase or Save-to window — returns false and changes
/// nothing, so a caller that means to force a re-login (the expired-session
/// notice) must not navigate away unless this is true.
Future<bool> runBranchedLogout(
  BuildContext context,
  WidgetRef ref, {
  bool cannotSync = false,
  BuildContext? dialogContext,
}) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final dialog = dialogContext ?? context;
  final flow = await ref.read(logoutFlowProvider.future);
  final plan = await flow.plan();
  final freeAccount = plan.branch == LogoutBranch.freeExportThenWipe;
  // Encryption is off by default; the copy is only asked for a passphrase when
  // the user has turned it on in Backup & Restore.
  final encrypt = ref.read(backupMetadataProvider).encryptBackups;

  // 1. Nothing on this device exists nowhere else, so the wipe needs no copy,
  //    no sync and no warning. (A free account never takes this path: every row
  //    it holds is unique to this device.)
  if (!freeAccount && plan.unsyncedCount == 0) {
    await flow.wipeAndComplete();
    _sayLoggedOut(messenger, l);
    return true;
  }

  // 2. (a) Premium + online: send the queue first, and wipe only once it is
  //    clear. A row the server permanently refused, or one frozen on a conflict,
  //    can never sync — so rather than trapping the account on the device, that
  //    failure falls through to the warning and the export.
  if (!freeAccount &&
      plan.branch == LogoutBranch.syncedThenWiped &&
      !cannotSync) {
    if (await flow.syncThenComplete() == LogoutResult.completed) {
      _sayLoggedOut(messenger, l);
      return true;
    }
    if (!dialog.mounted) return false;
    if (!await _confirmUnsyncedWarning(dialog)) return false;
    if (!dialog.mounted) return false;
    return _exportThenFinish(dialog, flow, messenger, l, encrypt: encrypt);
  }

  // 3. Premium, with unsynced work and no way to send it: (b) offline blocks
  //    first and offers an explicit way past; an unusable session cannot sync
  //    either, so it warns for the same reason. Both then export.
  if (!freeAccount) {
    if (!dialog.mounted) return false;
    if (plan.branch == LogoutBranch.blockedOffline) {
      if (!await _confirmLogOutAnyway(dialog)) return false;
      if (!dialog.mounted) return false;
    }
    if (!await _confirmUnsyncedWarning(dialog)) return false;
    if (!dialog.mounted) return false;
  }

  // 4. (c) Free, and the way past the offline block: always export, then wipe.
  if (!dialog.mounted) return false;
  return _exportThenFinish(dialog, flow, messenger, l, encrypt: encrypt);
}

/// The success message, shared by the branches that need no copy.
void _sayLoggedOut(ScaffoldMessengerState messenger, AppLocalizations l) {
  messenger.showSnackBar(
    SnackBar(content: Text(l.settingsManageAccount_loggedOut)),
  );
}

/// The offline block: the changes must sync first, with an explicit way past.
Future<bool> _confirmLogOutAnyway(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.logout_connectToSync),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.sharedActions_cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.logout_logOutAnyway),
        ),
      ],
    ),
  );
  return answer ?? false;
}

/// The warning that names what is about to be discarded.
Future<bool> _confirmUnsyncedWarning(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.logout_unsyncedWarningTitle),
      content: Text(l.logout_unsyncedWarningBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.sharedActions_cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.logout_proceed),
        ),
      ],
    ),
  );
  return answer ?? false;
}

/// Asks for the passphrase (only when encryption is on), writes the copy, then
/// wipes and signs out.
///
/// Cancelling a passphrase window cancels the **logout**, not just the export:
/// the wipe's precondition is a copy, so without one nothing is deleted. With
/// [encrypt] false (the default) no window appears at all — the copy is written
/// unencrypted and the logout continues. Returns whether the logout actually
/// completed.
Future<bool> _exportThenFinish(
  BuildContext context,
  LogoutFlow flow,
  ScaffoldMessengerState messenger,
  AppLocalizations l, {
  required bool encrypt,
}) async {
  String? secret;
  if (encrypt) {
    secret = await showBackupPassphraseDialog(context);
    if (secret == null || secret.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l.logout_exportCancelled)));
      return false;
    }
  }

  final result = await flow.exportThenComplete(passphrase: secret);
  final message = switch (result) {
    LogoutResult.completed => l.logout_backedUpTo(flow.lastArchivePath ?? ''),
    LogoutResult.exportCancelled => l.logout_exportCancelled,
    LogoutResult.exportFailed => l.logout_exportFailed,
    LogoutResult.syncFailed => l.logout_syncFailed,
  };
  messenger.showSnackBar(SnackBar(content: Text(message)));
  return result == LogoutResult.completed;
}
