/// The windows and the single entry point for a branched logout
/// (Task 19 Phase 6).
///
/// One orchestrator, [runBranchedLogout], so every place that ends a session
/// takes the same path: Manage Account's Log out and the forced re-login notice
/// both call it and nothing else decides what happens to the local data.
///
/// The dialogs follow the app's established window style, and the three of them
/// exist for the three moments the plan names: the **offline block**, which says
/// the changes must sync first and offers an explicit way past; the **unsynced
/// warning**, which names exactly what logging out now costs; and the **backup
/// choice**, *Backup Data to Local Storage?* with **Yes**/**No**, which lets the
/// user keep a copy or go without one — never both mandatory.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../settings/data/backup_metadata_store.dart';
import '../../settings/presentation/backup_dialogs.dart';
import '../data/logout_flow.dart';

/// Action size shared with the Exit App window (112x48 at 16 pt); repeated here
/// rather than exported because that style is private to the router.
const Size _actionSize = Size(112, 48);
const TextStyle _actionTextStyle = TextStyle(fontSize: 16);

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
  // A free account holding the user's own work. A free account with nothing
  // authored selects `cleanWipe` instead, so it falls through to step 1 below.
  final freeWithData = plan.branch == LogoutBranch.freeBackupChoice;
  // Encryption is off by default; the copy is only asked for a passphrase when
  // the user has turned it on in Backup & Restore.
  final encrypt = ref.read(backupMetadataProvider).encryptBackups;

  // 1. Nothing on this device exists nowhere else, so the wipe needs no copy,
  //    no sync and no warning: a premium account whose work is all on the server,
  //    or a free account that holds nothing the user authored.
  if (!freeWithData && plan.unsyncedCount == 0) {
    await flow.wipeAndComplete();
    _sayLoggedOut(messenger, l);
    return true;
  }

  // 2. (a) Premium + online: send the queue first, and wipe only once it is
  //    clear. A row the server permanently refused, or one frozen on a conflict,
  //    can never sync — so rather than trapping the account on the device, that
  //    failure falls through to the warning and the backup choice.
  if (!freeWithData &&
      plan.branch == LogoutBranch.syncedThenWiped &&
      !cannotSync) {
    if (await flow.syncThenComplete() == LogoutResult.completed) {
      _sayLoggedOut(messenger, l);
      return true;
    }
    if (!dialog.mounted) return false;
    if (!await _confirmUnsyncedWarning(dialog)) return false;
    if (!dialog.mounted) return false;
    return _backupThenFinish(dialog, flow, messenger, l, encrypt: encrypt);
  }

  // 3. Premium, with unsynced work and no way to send it: (b) offline blocks
  //    first and offers an explicit way past; an unusable session cannot sync
  //    either, so it warns for the same reason. Both then offer the copy.
  if (!freeWithData) {
    if (!dialog.mounted) return false;
    if (plan.branch == LogoutBranch.blockedOffline) {
      if (!await _confirmLogOutAnyway(dialog)) return false;
      if (!dialog.mounted) return false;
    }
    if (!await _confirmUnsyncedWarning(dialog)) return false;
    if (!dialog.mounted) return false;
  }

  // 4. (c) Free with the user's own work, and the way past the offline block:
  //    offer a copy, then wipe.
  if (!dialog.mounted) return false;
  return _backupThenFinish(dialog, flow, messenger, l, encrypt: encrypt);
}

/// The backup choice: *Backup Data to Local Storage?* with **Yes** and **No**.
///
/// The same window as the Exit App confirmation — no body text, the two actions
/// centred and at the shared 112x48/16 pt size. Returns true for **Yes**, false
/// for **No**, and null when the window was dismissed (the barrier or system
/// back), which the caller treats as a cancellation so a tap outside never wipes
/// anything — exactly as the app's other confirmations do.
Future<bool?> _confirmBackupChoice(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.logout_backupPromptTitle),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: _actionSize,
            textStyle: _actionTextStyle,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.sharedActions_yes),
        ),
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: _actionSize,
            textStyle: _actionTextStyle,
          ),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.sharedActions_no),
        ),
      ],
    ),
  );
  return answer;
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

/// Asks whether to keep a copy, then — for **Yes** — asks for the passphrase
/// (only when encryption is on), writes the copy, and wipes and signs out.
///
/// **No** is a legitimate answer, not a cancellation: the wipe runs with no copy
/// and the logout completes. A dismissed passphrase window still cancels the
/// **logout**, not just the export — the user asked for a copy, so nothing is
/// deleted without one. With [encrypt] false (the default) that window never
/// appears — the copy is written unencrypted and the logout continues. Returns
/// whether the logout actually completed.
Future<bool> _backupThenFinish(
  BuildContext context,
  LogoutFlow flow,
  ScaffoldMessengerState messenger,
  AppLocalizations l, {
  required bool encrypt,
}) async {
  final choice = await _confirmBackupChoice(context);
  // Dismissed: cancel the logout, delete nothing.
  if (choice == null) return false;
  // No: go without a copy. This is the branch the old "always export" rule
  // forbade, and the user's request is exactly that it is allowed.
  if (!choice) {
    await flow.wipeAndComplete();
    _sayLoggedOut(messenger, l);
    return true;
  }

  String? secret;
  if (encrypt) {
    if (!context.mounted) return false;
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
