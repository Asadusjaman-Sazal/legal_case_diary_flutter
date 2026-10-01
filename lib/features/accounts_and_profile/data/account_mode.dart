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
import '../../../shared/providers/shared_preferences_provider.dart';
import '../../../sync/connectivity_monitor.dart';
import '../../auth/data/auth_repository.dart';
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
///
/// The cached profile is **watched** so the answer is recomputed when the row
/// behind it changes: a renewal or a lapse arrives by pull, and a one-shot read
/// would keep answering with the first value it saw — which is precisely how a
/// premium account would be wrongly sent to the Paywall, or a lapsed one wrongly
/// allowed to sync. The firm's expiry can move without the profile moving (the
/// server mirrors the owner's subscription onto `firms`), so
/// [accountRefreshProvider] invalidates this provider after every successful
/// refresh as well.
final premiumAccessProvider = FutureProvider<bool>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  ref.watch(accountProfileProvider);
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

/// Whether Manage Associates is reachable for this account at all.
///
/// Deliberately wider than [canManageFirmProvider]: an **individual** has to be
/// able to open the screen, because adding the first associate is what creates
/// the firm (plan §1, Account Mode Detection). The one account that cannot is a
/// firm member who is not the owner — the roster, the invites and the permission
/// toggles are owner-only server-side, so the entry would only produce a refused
/// request.
///
/// A profile that has not been pulled yet counts as an individual, which is the
/// same rule [accountRoleProvider] already follows; the server's own guards in
/// `ensure_firm` are what make that safe rather than merely convenient.
final canOpenManageAssociatesProvider = Provider<bool>((ref) {
  if (ref.watch(authIdentityProvider) == null) return false;
  if (!ref.watch(firmModeProvider)) return true;
  return ref.watch(accountRoleProvider) == AccountRole.owner;
});

/// Whether the cached membership row still says this account belongs to a firm
/// while the server says it does not.
///
/// The two halves are read from different places on purpose:
///
/// * `profiles.firm_id == null` is the **server's** current answer, refreshed
///   with every pull;
/// * a cached `firm_members` row is what this device last knew.
///
/// They can only disagree one way, and by one cause: the account was in a firm
/// and is not any more. The check is durable rather than in-memory, so a device
/// that was offline when it was removed still sees it on the next successful
/// refresh, on the next launch, and after a restart — which is what makes the
/// forced logout below reliable. (A voluntary exit from a firm does not exist in
/// this task; if one is ever added it must clear the cache the same way a
/// sign-out does, and then this reading stays correct.)
final membershipRevokedProvider = Provider<bool>((ref) {
  final profile = ref.watch(accountProfileProvider).value;
  if (profile == null || profile.firmId != null) return false;
  return ref.watch(_cachedMembershipExistsProvider).value ?? false;
});

/// Whether any `firm_members` row for the signed-in account is cached.
final _cachedMembershipExistsProvider = StreamProvider<bool>((ref) async* {
  final identity = ref.watch(authIdentityProvider);
  if (identity == null) {
    yield false;
    return;
  }
  final db = await ref.watch(databaseProvider.future);
  yield* FirmMembersDao(db).watchHasMembership(identity.userId);
});

/// Refreshes this account's cached permissions before a permission-sensitive
/// action, when there is a link.
///
/// The plan's freshness rule has two halves. The scheduled half is already
/// wired — launch, resume and reconnect all run [accountRefreshProvider] — and
/// this is the third moment it names: *before every online permission-sensitive
/// action*. It runs through the same single entry point, so there is still one
/// code path that pulls this data.
///
/// Offline it does nothing at all, deliberately: there is nothing to refresh, and
/// the cached flags are advisory by design — `push_changes` is authoritative and
/// rolls a refused action back from its `pre_mutation_payload`. Blocking the
/// action instead would take away the provisional offline workflow the plan
/// requires.
final permissionFreshnessProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    // Only a firm member's flags can move under them; an individual owns their
    // own diary, so this is free for the Part A shape it grew out of.
    if (!ref.read(firmModeProvider)) return;
    if (ref.read(isOnlineProvider).value == false) return;
    try {
      await ref.read(accountRefreshProvider)();
    } on Object {
      // A refresh that cannot run leaves the last known flags in place, and
      // `permissions_synced_at` records how old they are.
    }
  };
});

/// The one entry point that refreshes the profile and firm permissions.
///
/// The launch/resume scope calls it now, and Phase 4's reconnect hook calls the
/// same function, so there is exactly one code path that pulls this data.
/// Mirrors the account holder's own profile details onto their `profiles` row.
///
/// Best-effort by design. With no account signed in there is nothing to mirror
/// to and nothing is owed — a Part A install keeps its record locally, and the
/// four columns did not exist before the account did. When a signed-in save
/// cannot reach the server the record stays on the device and the push is
/// **owed**, which is what makes [accountRefreshProvider] retry it on the next
/// launch, resume or reconnect: a profile edited in airplane mode is never
/// silently left behind on the device that typed it.
///
/// Returns true only when the server accepted the write.
final pushProfileDetailsProvider =
    Provider<Future<bool> Function(ProfileFields)>((ref) {
      return (fields) async {
        // Awaited, not the synchronous selector: the session is restored
        // asynchronously at startup, and a read taken while that is still in
        // flight would answer "nobody signed in" for a device that has an
        // account — dropping the push and leaving the record on the device.
        AuthIdentity? identity;
        try {
          identity = (await ref.read(authViewModelProvider.future)).identity;
        } on Object {
          return false;
        }
        if (identity == null) return false;

        final store = ProfileStore(ref.read(sharedPreferencesProvider));
        final repository = await ref.read(profileRepositoryProvider.future);
        final saved = await repository.savePersonalDetails(fields);
        await store.setDetailsPushPending(!saved);
        return saved;
      };
    });

/// Refreshes the account's cached profile, firm and permissions.
///
/// It also settles the account holder's own four details: a push an earlier save
/// could not land is retried first, and otherwise the account's copy fills the
/// fields this device has left blank. It never overwrites a detail the user
/// typed here, and it hands the account a record this device already held when
/// the account has none of its own — the two halves of "so the user does not
/// have to fill them in again".
final accountRefreshProvider = Provider<Future<bool> Function()>((ref) {
  return () async {
    // The session may still be restoring on the very first frame, so await the
    // state instead of reading an identity that is briefly null — otherwise a
    // cold start would quietly skip the launch refresh.
    final identity = (await ref.read(authViewModelProvider.future)).identity;
    if (identity == null) return false;

    final repository = await ref.read(profileRepositoryProvider.future);
    if (!await repository.refresh()) return false;

    // Entitlement is derived from the rows this refresh just replaced, and the
    // firm's expiry can change without the profile's (the server mirrors the
    // owner's subscription onto `firms`), so the derivation is recomputed here
    // rather than left on the value it saw before the pull.
    ref.invalidate(premiumAccessProvider);

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

    // The account's copy of the four details, and then one of two writes.
    //
    // The pull comes first on purpose, and the merge fills **blanks only**, so
    // it can neither overwrite what the user typed here nor throw away a value
    // the account holds — which matters because a push sends the whole record:
    // merging first is what stops a blank field on this device from clearing a
    // filled one on the account.
    final details = await repository.pullPersonalDetails();
    if (details == null) return true;

    final mine = ref.read(profileFieldsProvider);
    final merged = fillBlankDetails(local: mine, server: details);
    if (merged != mine) {
      await ref.read(profileFieldsProvider.notifier).save(merged);
    }

    final store = ProfileStore(ref.read(sharedPreferencesProvider));
    if (merged.hasDetails && (store.detailsPushPending || !details.hasDetails)) {
      // Either a save the account never saw (it is newer, and it is owed) or a
      // record this device holds and the account has never had. The account's
      // own values are already merged in, so nothing is lost by sending it.
      await ref.read(pushProfileDetailsProvider)(merged);
    }
    return true;
  };
});
