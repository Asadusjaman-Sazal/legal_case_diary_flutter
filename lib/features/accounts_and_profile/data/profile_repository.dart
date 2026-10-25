/// Profile repository: pulls the signed-in account's server profile into the
/// device's pull-only cache.
///
/// **Table classes (AGENTS.md rule 4).** `profiles`, `firms` and `firm_members`
/// are **pull-only caches**: the server is their only writer, nothing here is
/// ever queued, and no generic sync behaviour is applied to them. They are
/// *emptied* rather than migrated when the device changes account (adoption does
/// that before a new sign-in; [invalidate] does it on the way out), so one
/// account's cached name can never be shown to another.
///
/// **Three promises** (the Revision 2.4 Addendum spells out the first two):
///
/// * `full_name`, `role`, `firm_id` and `subscription_expiry` are cached, and
///   the server's `timestamptz` becomes the cache's **epoch milliseconds**.
/// * Membership carries the three permission flags plus `permissions_synced_at`,
///   the freshness stamp the plan uses to label provisional offline actions.
/// * A refresh that fails is **never fatal and never destructive**: the cache
///   keeps its last known values, so the diary opens and works offline with
///   whatever permissions it last saw. `permissions_synced_at` is the honest
///   record of how old that is.
///
/// Pushing a locally edited name back to `profiles` rides the same self-service
/// PATCH as the other details — see [profileDetailsUpdate] and
/// [ProfileRepository.savePersonalDetails].
///
/// **The one self-service exception.** `profiles` also holds the account
/// holder's own five details — display name, bar association, membership
/// number, office address and mobile number — the last four of which the
/// migration `20260929130000_profiles_personal_details.sql` made
/// client-writable column-wise for the caller's own row, exactly as
/// `full_name` already was. Those five are the only thing here that ever
/// travels device → server, and they never go through `sync_queue`: they are
/// one small PATCH of the account's own row, not a domain mutation.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../database/app_database.dart';
import '../../../shared/providers/database_provider.dart';
import 'local/firms_dao.dart';
import 'local/firm_members_dao.dart';
import 'local/profiles_dao.dart';
import 'profile_name_store.dart';

/// The roles the server writes into `profiles.role` and `firm_members.role`.
///
/// Plain strings, not an enum: the cache stores what the server sent, and an
/// unrecognized role must not crash a screen that only wants to know whether
/// somebody signs in or owns the firm.
abstract final class AccountRole {
  /// An account with no firm.
  static const String individual = 'individual';

  /// The firm's owner: every permission, plus firm administration.
  static const String owner = 'owner';

  /// A firm member whose permissions come from `firm_members`.
  static const String associate = 'associate';

  /// A firm member with read-only access.
  static const String viewer = 'viewer';
}

/// Converts a server `timestamptz` to the cache's epoch milliseconds.
///
/// PostgREST hands dates back as ISO-8601 strings (`2027-01-12T00:00:00+00:00`),
/// and an already-numeric value passes through unchanged. Anything that cannot
/// be read is null rather than a guess: a wrong expiry would silently grant or
/// deny premium.
int? subscriptionExpiryToEpochMs(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is DateTime) return value.toUtc().millisecondsSinceEpoch;
  if (value is String) {
    if (value.isEmpty) return null;
    final numeric = int.tryParse(value);
    if (numeric != null) return numeric;
    return DateTime.tryParse(value)?.toUtc().millisecondsSinceEpoch;
  }
  return null;
}

/// Reads the account's profile from the server into the pull-only cache.
abstract class ProfileRepository {
  /// Refreshes the cache from the server.
  ///
  /// Returns true when the cache was written. False means the refresh did not
  /// happen — no session, no backend in this build, or no connection — and the
  /// cache is exactly as it was.
  Future<bool> refresh();

  /// Empties the pull-only caches (logout, account switch).
  Future<void> invalidate();

  /// Mirrors the account holder's own details onto their `profiles` row.
  ///
  /// Returns true when the server accepted the write, false when a signed-in
  /// save could not reach it. The caller owns what a false means: the local
  /// record is already saved either way, and a failed push is retried on the
  /// next launch, resume or reconnect.
  Future<bool> savePersonalDetails(ProfileFields fields);

  /// The account's stored copy of those four details, or null when there is no
  /// account, no backend, or no connection.
  Future<ProfileFields?> pullPersonalDetails();
}

/// The `profiles` UPDATE body for the account holder's own details.
///
/// The only place the local record's field names meet the server's snake_case
/// columns (AGENTS.md rule 5), so a renamed column is a one-line change here
/// rather than a search across the app. The display name travels with the other
/// four: `full_name` has been client-writable on the holder's own row since
/// Phase 3, and the plan lists all five Profile fields as the account holder's
/// own record, so an edit to the name must reach `profiles` like the rest.
/// `email` is deliberately absent: the account's address is owned by
/// `auth.users`, and a client that could write it could misrepresent who it is.
Map<String, Object?> profileDetailsUpdate(ProfileFields fields) => <String, Object?>{
  'full_name': fields.fullName,
  'bar_association': fields.barAssociation,
  'membership_no': fields.membershipNo,
  'office_address': fields.officeAddress,
  'mobile_no': fields.mobile,
};

/// The account-held details out of a `profiles` row, for the pull half.
///
/// The name is left blank here on purpose: on the way *down* it travels through
/// the pull-only cache's own hydration, so a reader never has two answers for
/// it. On the way *up* it does travel with the rest — see
/// [profileDetailsUpdate].
ProfileFields profileDetailsFromRow(Map<String, Object?> row) {
  String text(String key) {
    final value = row[key];
    return value is String ? value : '';
  }

  return ProfileFields(
    barAssociation: text('bar_association'),
    membershipNo: text('membership_no'),
    officeAddress: text('office_address'),
    mobile: text('mobile_no'),
  );
}

/// [local] with the details it has left blank taken from [server].
///
/// The rule the user chose: the account fills the gaps a fresh install has, and
/// a detail typed on this device is never overwritten by a pull. The name is
/// untouched — see [profileDetailsFromRow].
ProfileFields fillBlankDetails({
  required ProfileFields local,
  required ProfileFields server,
}) {
  String? fill(String mine, String theirs) =>
      mine.isEmpty && theirs.isNotEmpty ? theirs : null;

  return local.copyWith(
    barAssociation: fill(local.barAssociation, server.barAssociation),
    membershipNo: fill(local.membershipNo, server.membershipNo),
    officeAddress: fill(local.officeAddress, server.officeAddress),
    mobile: fill(local.mobile, server.mobile),
  );
}

/// The four server reads a profile refresh makes, behind one seam.
///
/// `refresh()` owns one decision that is purely local: a dissolve — or a removal
/// applied on another device — deletes the `firms` and `firm_members` rows
/// **outright** on the server, so no pull will ever tombstone the copies on this
/// device, and the refresh is the only moment that notices the account has left
/// its chamber. That decision could not be proven while the method talked to
/// PostgREST and to the auth session directly, so those reads arrive as this
/// dependency: production builds it over the live client, and a test answers
/// with rows and asserts what the local store holds afterwards.
///
/// The shape is the rows themselves rather than a domain model, because the
/// cache stores exactly what the server sent — a mapped model here would be a
/// second definition of a `profiles` row.
abstract class ProfileRefreshSource {
  /// The signed-in account's id, or null when there is no session.
  String? get userId;

  /// The caller's own `profiles` row, or null when the server has none yet.
  Future<Map<String, Object?>?> fetchProfile(String userId);

  /// The firm that row names, or null when it cannot be read.
  Future<Map<String, Object?>?> fetchFirm(String firmId);

  /// The caller's own membership row in [firmId].
  Future<Map<String, Object?>?> fetchMembership({
    required String firmId,
    required String userId,
  });
}

/// [ProfileRefreshSource] over the live client, the only implementation the app
/// ships.
class SupabaseProfileRefreshSource implements ProfileRefreshSource {
  /// Creates the source over [client].
  const SupabaseProfileRefreshSource(this._client);

  final SupabaseClient _client;

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  Future<Map<String, Object?>?> fetchProfile(String userId) =>
      _client.from('profiles').select().eq('id', userId).maybeSingle();

  @override
  Future<Map<String, Object?>?> fetchFirm(String firmId) =>
      _client.from('firms').select().eq('id', firmId).maybeSingle();

  @override
  Future<Map<String, Object?>?> fetchMembership({
    required String firmId,
    required String userId,
  }) => _client
      .from('firm_members')
      .select()
      .eq('firm_id', firmId)
      .eq('user_id', userId)
      .maybeSingle();
}

/// The repository used when this build has no backend configured.
///
/// It still clears the cache: a build with no backend can have signed out of a
/// build that had one, and a stale name is worse than no name.
class UnavailableProfileRepository implements ProfileRepository {
  /// Creates the repository over the local caches.
  UnavailableProfileRepository(this._db);

  final AppDatabase _db;

  @override
  Future<bool> refresh() async => false;

  @override
  Future<bool> savePersonalDetails(ProfileFields fields) async => false;

  @override
  Future<ProfileFields?> pullPersonalDetails() async => null;

  @override
  Future<void> invalidate() async {
    await _db.delete(_db.profiles).go();
    await _db.delete(_db.firms).go();
    await _db.delete(_db.firmMembers).go();
  }
}

/// [ProfileRepository] implemented on `profiles`, `firms` and `firm_members`.
class SupabaseProfileRepository implements ProfileRepository {
  /// Creates a repository over [client] and the local cache in [db].
  ///
  /// [source] is the test seam for the server reads; production leaves it null
  /// and the repository reads through [client].
  SupabaseProfileRepository(
    SupabaseClient client,
    this._db, {
    ProfileRefreshSource? source,
  }) : _client = client,
       _source = source ?? SupabaseProfileRefreshSource(client);

  final SupabaseClient _client;
  final AppDatabase _db;
  final ProfileRefreshSource _source;

  @override
  Future<bool> refresh() async {
    final userId = _source.userId;
    if (userId == null) return false;

    try {
      final row = await _source.fetchProfile(userId);
      if (row == null) {
        // The sign-up trigger creates the row; until it lands there is nothing
        // to cache and nothing to invent.
        return false;
      }

      final firmId = row['firm_id'] as String?;
      await ProfilesDao(_db).upsert(
        ProfilesCompanion(
          id: Value(userId),
          fullName: Value(row['full_name'] as String? ?? ''),
          // The profile picture's server-stamped state (0.0.630). A row that
          // has never had a picture reads "no path, version 0".
          avatarPath: Value(row['avatar_path'] as String?),
          avatarVersion: Value((row['avatar_version'] as num?)?.toInt() ?? 0),
          firmId: Value(firmId),
          role: Value(row['role'] as String? ?? AccountRole.individual),
          subscriptionStatus: Value(
            row['subscription_status'] as String? ?? 'free',
          ),
          subscriptionExpiry: Value(
            subscriptionExpiryToEpochMs(row['subscription_expiry']),
          ),
          // The stored tier (Task 21's ladder). The server writes it at approval
          // and never clears it on expiry, so an absent value on an older row
          // reads as `free` — the safe answer for a plan this app must not sell
          // a higher tier from.
          tier: Value(row['tier'] as String? ?? 'free'),
          tierPending: Value(row['tier_pending'] as String?),
          tierPendingFrom: Value(
            subscriptionExpiryToEpochMs(row['tier_pending_from']),
          ),
          createdAt: Value(
            subscriptionExpiryToEpochMs(row['created_at']) ??
                DateTime.now().toUtc().millisecondsSinceEpoch,
          ),
        ),
      );

      if (firmId == null) {
        // No firm on the profile means this account is not in one any more — a
        // dissolve, or a removal applied on another device. Both delete rows
        // outright on the server, so no pull will ever tombstone them here:
        // the cached chamber and membership are cleared at the moment the
        // profile stops naming a firm, or they would sit on the device for good.
        await _db.delete(_db.firms).go();
        await _db.delete(_db.firmMembers).go();
        return true;
      }

      await _cacheFirm(firmId);
      await _cacheMembership(userId: userId, firmId: firmId);
      return true;
    } on PostgrestException {
      // A policy or a transient server error: keep the last known values.
      return false;
    } on AuthException {
      return false;
    } on Exception {
      // No connection. The diary is fully usable offline, so this is a normal
      // outcome, not an error to surface: `permissions_synced_at` records it.
      return false;
    }
  }

  @override
  Future<void> invalidate() =>
      UnavailableProfileRepository(_db).invalidate();

  /// Writes the caller's five own details onto their own profile row.
  ///
  /// The Phase 4 policy (`profiles_update_self`) already restricts the UPDATE to
  /// `id = auth.uid()`, and the Phase 3 column privileges let a client move only
  /// its own display fields — so this is a plain PATCH and needs no function.
  @override
  Future<bool> savePersonalDetails(ProfileFields fields) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      await _client
          .from('profiles')
          .update(profileDetailsUpdate(fields))
          .eq('id', userId);
      return true;
    } on PostgrestException {
      // A rejected policy or a transient server error: the local record stands
      // and the caller keeps the push owed.
      return false;
    } on AuthException {
      return false;
    } on Exception {
      // No connection — the normal offline case, not an error to surface.
      return false;
    }
  }

  /// Reads the caller's four own details from the server.
  @override
  Future<ProfileFields?> pullPersonalDetails() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final row = await _client
          .from('profiles')
          .select('bar_association, membership_no, office_address, mobile_no')
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return null;
      return profileDetailsFromRow(row);
    } on PostgrestException {
      return null;
    } on AuthException {
      return null;
    } on Exception {
      return null;
    }
  }

  /// Caches the firm row, whose expiry is the source of truth for a member.
  Future<void> _cacheFirm(String firmId) async {
    final firm = await _source.fetchFirm(firmId);
    if (firm == null) return;

    await FirmsDao(_db).upsert(
      FirmsCompanion(
        id: Value(firmId),
        name: Value(firm['name'] as String? ?? ''),
        ownerId: Value(firm['owner_id'] as String? ?? ''),
        subscriptionStatus: Value(
          firm['subscription_status'] as String? ?? 'free',
        ),
        subscriptionExpiry: Value(
          subscriptionExpiryToEpochMs(firm['subscription_expiry']),
        ),
        // The chamber's tier, mirrored from its owner's plan by the server.
        // This row is the seat cap's source, so it is cached rather than
        // re-derived from the owner's expiry.
        tier: Value(firm['tier'] as String? ?? 'free'),
        tierPending: Value(firm['tier_pending'] as String?),
        tierPendingFrom: Value(
          subscriptionExpiryToEpochMs(firm['tier_pending_from']),
        ),
        // The chamber logo's server-stamped state (0.0.629). A row that has
        // never had a logo reads "no path, version 0".
        logoPath: Value(firm['logo_path'] as String?),
        logoVersion: Value((firm['logo_version'] as num?)?.toInt() ?? 0),
        createdAt: Value(
          subscriptionExpiryToEpochMs(firm['created_at']) ??
              DateTime.now().toUtc().millisecondsSinceEpoch,
        ),
      ),
    );
  }

  /// Caches this user's membership row, stamping the permission freshness.
  ///
  /// `permissions_synced_at` is written on every successful refresh — that stamp
  /// is what lets an offline action be labelled provisional and what tells the
  /// next reader how old these flags are.
  Future<void> _cacheMembership({
    required String userId,
    required String firmId,
  }) async {
    final member = await _source.fetchMembership(
      firmId: firmId,
      userId: userId,
    );
    if (member == null) return;

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await FirmMembersDao(_db).upsert(
      FirmMembersCompanion(
        id: Value(member['id'] as String? ?? '$firmId:$userId'),
        firmId: Value(firmId),
        userId: Value(userId),
        role: Value(member['role'] as String? ?? AccountRole.associate),
        canAdd: Value(member['can_add'] as bool? ?? false),
        canEdit: Value(member['can_edit'] as bool? ?? false),
        canDelete: Value(member['can_delete'] as bool? ?? false),
        syncedAt: Value(now),
        permissionsSyncedAt: Value(now),
      ),
    );
  }
}

/// Provider for the profile cache repository.
///
/// A future provider because the caches live in the encrypted database, which is
/// opened asynchronously — the same shape every other database-backed repository
/// in the app uses.
final profileRepositoryProvider = FutureProvider<ProfileRepository>((ref) async {
  final database = await ref.watch(databaseProvider.future);
  final client = ref.watch(activeSupabaseClientProvider);
  return client == null
      ? UnavailableProfileRepository(database)
      : SupabaseProfileRepository(client, database);
});
