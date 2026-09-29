/// Account mode: the one place the app decides whether it is running as an
/// individual or as a firm member, and what that member may do.
///
/// Task 17 Phase 3 requires **one** provider for firm-conditional UI. It is
/// [firmModeProvider], derived from the cached `profiles.firm_id` — never from
/// the presence of a firm row, never from a second copy of the state, and never
/// re-derived at a call site. [accountRoleProvider], [canDeleteDirectlyProvider]
/// and [canManageFirmProvider] all read the same cached rows, so a permissions
/// refresh cannot leave the drawer, the Profile header and the delete path
/// disagreeing with each other.
///
/// Nothing here is invented when the cache is empty: an account with no cached
/// profile is an individual with full rights over their own diary, which is
/// exactly what a Part A install was.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/local_identity_service.dart';
import '../../../database/app_database.dart';
import '../../../shared/providers/database_provider.dart';
import '../../auth/presentation/auth_viewmodel.dart';
import '../../settings/data/premium_access.dart';
import 'local/firm_members_dao.dart';
import 'local/profiles_dao.dart';
import 'profile_name_store.dart';
import 'profile_repository.dart';

/// The id the account's pull-only caches are keyed by.
///
/// The signed-in account when there is one, and the Part A placeholder before
/// that. Every reader of the `profiles`/`firms`/`firm_members` caches — this file
/// and the task-13 permission and entitlement checks — goes through this, so a
/// signed-in account never reads a row left behind by the local-only install.
final accountCacheUserIdProvider = Provider<String>(
  (ref) =>
      ref.watch(authIdentityProvider)?.userId ??
      ref.watch(localIdentityServiceProvider).getId(),
);

/// The signed-in account's cached profile row, live from the pull-only cache.
///
/// Null while nobody is signed in, while the row has not been pulled yet, or on
/// a build with no backend — the three cases the app treats identically.
final accountProfileProvider = StreamProvider<Profile?>((ref) async* {
  final identity = ref.watch(authIdentityProvider);
  if (identity == null) {
    yield null;
    return;
  }
  final db = await ref.watch(databaseProvider.future);
  yield* ProfilesDao(db).watchById(identity.userId);
});

/// The cached firm row for a firm-mode account, or null.
///
/// Its subscription expiry is the source of truth for every member, which is
/// why the firm row is cached beside the profile rather than looked up by name.
final accountFirmProvider = StreamProvider<Firm?>((ref) async* {
  final firmId = ref.watch(accountProfileProvider).value?.firmId;
  if (firmId == null) {
    yield null;
    return;
  }
  final db = await ref.watch(databaseProvider.future);
  yield* (db.select(db.firms)..where((row) => row.id.equals(firmId)))
      .watchSingleOrNull();
});

/// Whether this account is premium right now.
///
/// The same single derivation every gate uses — `subscription_expiry + 48h grace`,
/// never the display-only status flag — read against the cached profile (or, for
/// a firm member, the firm's expiry) under the account's own id.
final premiumAccessProvider = FutureProvider<bool>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return resolvePremiumAccess(db, ref.watch(accountCacheUserIdProvider));
});

/// This account's cached firm membership, with its permission flags.
///
/// Pull-only: the row is advisory and `push_changes` stays authoritative, which
/// is why [permissionsSyncedAtProvider] is exposed beside it.
final firmMembershipProvider = StreamProvider<FirmMember?>((ref) async* {
  final identity = ref.watch(authIdentityProvider);
  final firmId = ref.watch(accountProfileProvider).value?.firmId;
  if (identity == null || firmId == null) {
    yield null;
    return;
  }
  final db = await ref.watch(databaseProvider.future);
  yield* FirmMembersDao(db).watchByUserId(identity.userId);
});

/// The account's role: what the server wrote, or `individual` before it lands.
final accountRoleProvider = Provider<String>((ref) {
  final profile = ref.watch(accountProfileProvider).value;
  return profile?.role ?? AccountRole.individual;
});

/// **The** firm-mode switch.
///
/// True when the cached profile carries a firm id — the plan's rule, verbatim:
/// `firm_id != null` is firm mode, `firm_id == null` is individual mode. Every
/// firm-conditional entry point reads this and nothing else.
final firmModeProvider = Provider<bool>((ref) {
  final profile = ref.watch(accountProfileProvider).value;
  return profile?.firmId != null;
});

/// The role while a firm is in play: owner, associate or viewer.
///
/// Falls back to the individual role when there is no firm, so a caller can
/// always name what it is looking at.
final firmRoleProvider = Provider<String>((ref) =>
    ref.watch(firmModeProvider) ? ref.watch(accountRoleProvider) : AccountRole.individual);

/// Epoch ms of the last successful permission refresh, or null if never.
///
/// The plan uses this stamp to label provisional offline actions; the refresh
/// itself runs on launch, on resume and (from Phase 4) on reconnect.
final permissionsSyncedAtProvider = Provider<int?>(
  (ref) => ref.watch(firmMembershipProvider).value?.permissionsSyncedAt,
);

/// Whether this account deletes rows directly instead of raising a request.
///
/// An individual owns their own diary; a firm owner has every permission; an
/// associate or viewer needs `can_delete`. A cache that has not been refreshed
/// yet is treated as *no* permission for a firm member, which is the safe
/// direction: the worst case is a needless delete request, never a deletion the
/// server would reject.
final canDeleteDirectlyProvider = Provider<bool>((ref) {
  if (!ref.watch(firmModeProvider)) return true;
  if (ref.watch(accountRoleProvider) == AccountRole.owner) return true;
  return ref.watch(firmMembershipProvider).value?.canDelete ?? false;
});

/// Whether this account may add a case without a firm-level check.
///
/// The same rule as [canDeleteDirectlyProvider], for `can_add`.
final canAddDirectlyProvider = Provider<bool>((ref) {
  if (!ref.watch(firmModeProvider)) return true;
  if (ref.watch(accountRoleProvider) == AccountRole.owner) return true;
  return ref.watch(firmMembershipProvider).value?.canAdd ?? false;
});

/// Whether this account may edit a case without a firm-level check.
///
/// The same rule again, for `can_edit`.
final canEditDirectlyProvider = Provider<bool>((ref) {
  if (!ref.watch(firmModeProvider)) return true;
  if (ref.watch(accountRoleProvider) == AccountRole.owner) return true;
  return ref.watch(firmMembershipProvider).value?.canEdit ?? false;
});

/// Whether this account manages the firm — the owner-side entry points.
final canManageFirmProvider = Provider<bool>(
  (ref) =>
      ref.watch(firmModeProvider) &&
      ref.watch(accountRoleProvider) == AccountRole.owner,
);

/// The one entry point that refreshes the profile and firm permissions.
///
/// The launch/resume scope calls it now, and Phase 4's reconnect hook calls the
/// same function, so there is exactly one code path that pulls this data.
final accountRefreshProvider = Provider<Future<bool> Function()>((ref) {
  return () async {
    // The session may still be restoring on the very first frame, so await the
    // state instead of reading an identity that is briefly null — otherwise a
    // cold start would quietly skip the launch refresh.
    final identity = (await ref.read(authViewModelProvider.future)).identity;
    if (identity == null) return false;

    final repository = await ref.read(profileRepositoryProvider.future);
    if (!await repository.refresh()) return false;

    // The server's name fills a blank local record — a device that signed up
    // elsewhere, or an associate whose name came from the firm's invite. A name
    // the user typed here is theirs and is never overwritten by a pull. Read
    // straight from the cache: the streams above have not emitted yet.
    final db = await ref.read(databaseProvider.future);
    final profile = await ProfilesDao(db).getById(identity.userId);
    final local = ref.read(profileFieldsProvider);
    final serverName = profile?.fullName.trim() ?? '';
    if (local.fullName.isEmpty && serverName.isNotEmpty) {
      await ref
          .read(profileFieldsProvider.notifier)
          .save(local.copyWith(fullName: serverName));
    }
    return true;
  };
});
