/// Account deletion: the one call that removes the caller's account.
///
/// **Task 12's Manage Account actions, finally built (0.0.411, user request).**
/// The Delete Account card warned nothing and did nothing before this — it was
/// the last of the Settings surface's Part A placeholders. What it needs is
/// server work, because an account is made of server rows: `profiles`, the
/// domain rows it authored, its preferences, its payment submissions and the
/// `auth.users` row itself. The client cannot remove any of that (AGENTS.md
/// rule 12 keeps every write behind the server), and the server cannot be
/// reached from a screen directly, so the boundary is this repository — the same
/// shape [AdminRepository] uses for the admin panel's calls.
///
/// **One server call, and the server decides (0.0.630).** The app invokes the
/// **`delete-account` Edge Function**, which runs `delete_my_account()` as the
/// caller — the RPC takes no arguments and can only ever act on `auth.uid()` —
/// and then removes the caller's profile picture from the
/// `individual-avatars` bucket. The
/// storage step has to live in a function: Supabase requires Storage objects to
/// be deleted through the Storage API, and a SQL delete from `storage.objects`
/// leaves the file behind. The function keeps the RPC's `{status, reason?}`
/// envelope, so a firm member or an app admin is still refused by the server
/// and the reason is mapped to one thing a screen can word.
///
/// The function must be deployed with the app; against a project without it,
/// deletion answers [AccountDeletionOutcome.failed] and nothing is removed.
///
/// **No queue, by design.** This is deliberately not a domain mutation: it is
/// never written to `sync_queue` and never retried in the background. A queued
/// account deletion would mean a device that has already given up the account's
/// data while the account still exists, or the reverse — both worse than asking
/// the user to try again with a connection.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// What came of asking the server to delete this account.
enum AccountDeletionOutcome {
  /// The account and every row of it are gone.
  deleted,

  /// Refused: this account belongs to a firm, so some of its rows are the
  /// firm's. The owner must remove it from the firm first.
  refusedFirm,

  /// Refused: an administrator's rows include other people's payment ledger.
  refusedAdministrator,

  /// No backend in this build, or no session to delete.
  unavailable,

  /// The call reached nothing, or the server failed. Nothing was deleted.
  failed,
}

/// The account-deletion boundary.
abstract class AccountDeletionRepository {
  /// Asks the server to remove this account and all of its data.
  ///
  /// Never throws: every outcome is one of [AccountDeletionOutcome], because the
  /// screen's only decision is which sentence to show.
  Future<AccountDeletionOutcome> deleteAccount();
}

/// The repository used when this build has no backend configured.
///
/// Deletion is a server operation with no local half, so a build with no backend
/// reports [AccountDeletionOutcome.unavailable] rather than pretending.
class UnavailableAccountDeletionRepository implements AccountDeletionRepository {
  /// Creates the repository.
  const UnavailableAccountDeletionRepository();

  @override
  Future<AccountDeletionOutcome> deleteAccount() async =>
      AccountDeletionOutcome.unavailable;
}

/// Reads the server's own answer to `delete_my_account()`.
///
/// The envelope is the one `abandon_provisional_account` and the firm calls
/// already use: `{'status': 'removed'}`, `{'status': 'refused', 'reason': …}`, or
/// a status this build does not know — which is a failure rather than a silent
/// success, because the local wipe must never run on a guess.
AccountDeletionOutcome outcomeFromDeleteResponse(Object? response) {
  if (response is! Map) return AccountDeletionOutcome.failed;
  final status = response['status'];
  if (status == 'removed') return AccountDeletionOutcome.deleted;
  if (status == 'refused') {
    return switch (response['reason']) {
      'firm' => AccountDeletionOutcome.refusedFirm,
      'administrator' => AccountDeletionOutcome.refusedAdministrator,
      _ => AccountDeletionOutcome.failed,
    };
  }
  return AccountDeletionOutcome.failed;
}

/// The real repository: the `delete-account` function over the signed-in
/// session.
class SupabaseAccountDeletionRepository implements AccountDeletionRepository {
  /// Creates the repository over an initialized client.
  SupabaseAccountDeletionRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AccountDeletionOutcome> deleteAccount() async {
    // Nothing to delete without a session, and the RPC would only answer
    // `unauthenticated`.
    if (_client.auth.currentUser == null) {
      return AccountDeletionOutcome.unavailable;
    }
    try {
      final response = await _client.functions.invoke('delete-account');
      return outcomeFromDeleteResponse(response.data);
    } on Object {
      // Offline, the function not deployed, or a server error: nothing was
      // deleted, and the user may retry. The screen words this; a typed failure
      // here would only be a second way to say the same sentence.
      return AccountDeletionOutcome.failed;
    }
  }
}
