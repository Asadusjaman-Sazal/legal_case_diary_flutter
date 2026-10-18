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
/// user keep a copy or go without one — never both mandatory. A chamber member is
/// offered no copy at all: the member reads a warning naming what is being
/// discarded and logging out erases the chamber's rows from the device
/// (firm-mode §6).
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
  // Every provider is read **before the first await**. `ref` is a widget ref, and
  // Riverpod forbids touching it once the widget that owns it is unmounted — the
  // flow below awaits real I/O (the database, the sync push, the save dialog), and
  // by the time it resumes the surface that opened this window may be gone. Read
  // the two values up front, while the widget is certainly still mounted.
  final flowFuture = ref.read(logoutFlowProvider.future);
  // Encryption is off by default; the copy is only asked for a passphrase when
  // the user has turned it on in Backup & Restore.
  final encrypt = ref.read(backupMetadataProvider).encryptBackups;
  final flow = await flowFuture;
  final plan = await flow.plan();
  // A free account holding the user's own work. A free account with nothing
  // authored selects `cleanWipe` instead, so it falls through to step 1 below.
  final freeWithData = plan.branch == LogoutBranch.freeBackupChoice;
  // A chamber member keeps no copy (firm-mode §6), so wherever the branches below
  // would offer one, the warning takes its place.
  final backupBarred = plan.backupBarred;

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
    return _backupThenFinish(
      dialog,
      flow,
      messenger,
      l,
      encrypt: encrypt,
      barred: backupBarred,
    );
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
  //    offer a copy, then wipe — or, for a member, name what is discarded.
  if (!dialog.mounted) return false;
  return _backupThenFinish(
    dialog,
    flow,
    messenger,
    l,
    encrypt: encrypt,
    barred: backupBarred,
  );
}

/// What a chamber member reads in place of the *Backup Data to Local Storage?*
/// choice (firm-mode §6).
///
/// **Proceed** wipes and signs out with no copy written; there is nothing to
/// offer, because the chamber holds the records and a member's export would hold
/// the chamber's whole ledger in a file they keep. Cancel, or a dismissal, ends
/// the logout and deletes nothing — the same direction as every other window in
/// this flow.
Future<bool> _confirmMemberWarning(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.logout_memberWarningTitle),
      content: Text(l.logout_memberWarningBody),
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
///
/// [barred] is the chamber member: no copy is offered and none is written, so the
/// passphrase window never appears for them either — the warning above replaces
/// the whole choice (firm-mode §6).
Future<bool> _backupThenFinish(
  BuildContext context,
  LogoutFlow flow,
  ScaffoldMessengerState messenger,
  AppLocalizations l, {
  required bool encrypt,
  bool barred = false,
}) async {
  // A member gets the warning, never the choice: the copy is not theirs to keep
  // and no passphrase window is shown for one that will not be written.
  if (barred) {
    if (!await _confirmMemberWarning(context)) return false;
    await flow.wipeAndComplete();
    _sayLoggedOut(messenger, l);
    return true;
  }

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
