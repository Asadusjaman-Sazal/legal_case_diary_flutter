/// A refresh that finds no chamber clears the one the device still caches.
///
/// The branch this file exists for is easy to get wrong and impossible to see:
/// a dissolve (or a removal applied on another device) deletes the `firms` and
/// `firm_members` rows **outright** on the server, so no pull will ever tombstone
/// the copies here — and the account is still signed in, so nothing empties the
/// caches either. The one moment that notices is the profile refresh, and it
/// must leave the device holding no chamber at all.
///
/// These tests drive `SupabaseProfileRepository.refresh()` itself: the server
/// reads arrive through [ProfileRefreshSource], the local store is a real
/// in-memory database, and every assertion is about what the device holds once
/// the refresh returns.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/firm_members_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/firms_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/profiles_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// The device mid-chamber: a cached profile, its chamber, and the membership
  /// row beside them.
  Future<void> seedChamber() async {
    await ProfilesDao(db).upsert(
      ProfilesCompanion(
        id: const Value('user-1'),
        fullName: const Value('Adv. Rahim Uddin'),
        firmId: const Value('firm-1'),
        role: const Value(AccountRole.owner),
        subscriptionStatus: const Value('active'),
        createdAt: const Value(1),
      ),
    );
    await FirmsDao(db).upsert(
      FirmsCompanion.insert(
        id: 'firm-1',
        name: 'Rahman & Associates',
        ownerId: 'user-1',
        subscriptionStatus: 'active',
        createdAt: 1,
      ),
    );
    await FirmMembersDao(db).upsert(
      FirmMembersCompanion.insert(
        id: 'member-1',
        firmId: 'firm-1',
        userId: 'user-1',
        role: AccountRole.owner,
      ),
    );
  }

  /// A `profiles` row as PostgREST answers one.
  Map<String, Object?> profileRow({String? firmId}) => <String, Object?>{
    'id': 'user-1',
    'full_name': 'Adv. Rahim Uddin',
    'firm_id': firmId,
    'role': firmId == null ? AccountRole.individual : AccountRole.owner,
    'subscription_status': 'active',
    'subscription_expiry': '2027-01-12T00:00:00+00:00',
    // The plan is untouched by a dissolve, so the stored tier must survive the
    // same write that drops the chamber.
    'tier': 'firm',
    'tier_pending': null,
    'tier_pending_from': null,
    'created_at': '2026-09-01T00:00:00+00:00',
  };

  /// The real repository over a source that answers with rows.
  ///
  /// The client is pointed at a dead address on purpose: `refresh()` reaches the
  /// server only through the source, so a test that ever touches the network
  /// fails loudly here instead of passing on a request nobody meant to make.
  SupabaseProfileRepository repositoryFor(ProfileRefreshSource source) =>
      SupabaseProfileRepository(
        SupabaseClient('http://127.0.0.1:1', 'test-anon-key'),
        db,
        source: source,
      );

  test('a refresh that finds no chamber clears the cached one', () async {
    await seedChamber();
    final source = _FakeRefreshSource(profile: profileRow());

    expect(await repositoryFor(source).refresh(), isTrue);
    expect(source.profileReads, 1, reason: 'the refresh must read the profile');

    expect(
      await db.select(db.firms).get(),
      isEmpty,
      reason: 'the dissolved chamber is still cached on the device',
    );
    expect(
      await db.select(db.firmMembers).get(),
      isEmpty,
      reason: 'the membership row of a chamber that is gone is still cached',
    );

    final profile = await ProfilesDao(db).getById('user-1');
    expect(profile?.firmId, isNull);
    expect(profile?.role, AccountRole.individual);
    expect(profile?.fullName, 'Adv. Rahim Uddin');
    // A dissolve is not a cancellation: the plan keeps its tier and expiry.
    expect(profile?.tier, 'firm');
    expect(profile?.subscriptionExpiry, isNotNull);
  });

  test('a refresh that still names the chamber keeps it and caches it', () async {
    // The seeded membership carries the table's default flags (all false), so
    // the asserts below show the source's row was written over it — a refresh
    // that merely left the seed alone fails.
    await seedChamber();

    final source = _FakeRefreshSource(
      profile: profileRow(firmId: 'firm-1'),
      firm: <String, Object?>{
        'id': 'firm-1',
        'name': 'Rahman & Associates',
        'owner_id': 'user-1',
        'subscription_status': 'active',
        'subscription_expiry': '2027-01-12T00:00:00+00:00',
        'tier': 'firm',
        'created_at': '2026-09-01T00:00:00+00:00',
      },
      membership: <String, Object?>{
        'id': 'member-1',
        'firm_id': 'firm-1',
        'user_id': 'user-1',
        'role': AccountRole.owner,
        'can_add': true,
        'can_edit': true,
        'can_delete': true,
      },
    );

    expect(await repositoryFor(source).refresh(), isTrue);

    final firms = await db.select(db.firms).get();
    expect(firms, hasLength(1));
    expect(firms.single.name, 'Rahman & Associates');
    expect(firms.single.tier, 'firm');
    final membership = (await db.select(db.firmMembers).get()).single;
    expect(membership.canAdd, isTrue);
    expect(membership.canDelete, isTrue);
    expect(membership.permissionsSyncedAt, isNotNull);
    expect((await ProfilesDao(db).getById('user-1'))?.firmId, 'firm-1');
  });

  test('a refresh with no session reads nothing and changes nothing', () async {
    await seedChamber();
    final source = _FakeRefreshSource(userId: null, profile: profileRow());

    expect(await repositoryFor(source).refresh(), isFalse);
    expect(source.profileReads, 0);
    expect(await db.select(db.firms).get(), hasLength(1));
    expect((await ProfilesDao(db).getById('user-1'))?.firmId, 'firm-1');
  });

  test('a refresh with no profile row leaves the cache untouched', () async {
    await seedChamber();
    final source = _FakeRefreshSource(profile: null);

    expect(await repositoryFor(source).refresh(), isFalse);

    expect(await db.select(db.firms).get(), hasLength(1));
    expect(await db.select(db.firmMembers).get(), hasLength(1));
    expect((await ProfilesDao(db).getById('user-1'))?.firmId, 'firm-1');
  });
}

/// A [ProfileRefreshSource] whose rows the test decides.
class _FakeRefreshSource implements ProfileRefreshSource {
  _FakeRefreshSource({
    this.userId = 'user-1',
    this.profile,
    this.firm,
    this.membership,
  });

  @override
  final String? userId;

  /// The `profiles` row the server would answer, or null for "none yet".
  Map<String, Object?>? profile;

  /// The `firms` row the profile's firm id names, when one is read.
  Map<String, Object?>? firm;

  /// The caller's `firm_members` row, when one is read.
  Map<String, Object?>? membership;

  /// How many times the profile was read, so a refresh that skipped it is visible.
  int profileReads = 0;

  @override
  Future<Map<String, Object?>?> fetchProfile(String userId) async {
    profileReads++;
    return profile;
  }

  @override
  Future<Map<String, Object?>?> fetchFirm(String firmId) async => firm;

  @override
  Future<Map<String, Object?>?> fetchMembership({
    required String firmId,
    required String userId,
  }) async => membership;
}
