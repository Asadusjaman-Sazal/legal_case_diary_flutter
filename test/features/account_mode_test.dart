/// Task 17 Phase 3 — the profile cache, firm-mode detection and the refresh.
///
/// Three promises are pinned here, all of them from the Revision 2.4 Addendum:
/// the server's `timestamptz` becomes the cache's epoch milliseconds; the cached
/// `full_name`/`role`/`firm_id`/`subscription_expiry` are what firm-conditional
/// UI and every entitlement gate read; and the cache is emptied on the way out,
/// never carried across accounts.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/firms_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/firm_members_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/profiles_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_name_store.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_repository.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/account_refresh_scope.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_viewmodel.dart';

import 'auth_test_support.dart';

/// A [ProfileRepository] whose pull and clear the test decides.
class FakeProfileRepository implements ProfileRepository {
  /// Whether [refresh] reports success.
  bool refreshResult = false;

  /// The profile row [refresh] writes when it succeeds.
  ProfilesCompanion? rowToCache;

  /// The firm row [refresh] writes when it succeeds.
  FirmsCompanion? firmToCache;

  /// The membership row [refresh] writes when it succeeds.
  FirmMembersCompanion? memberToCache;

  /// How many times [refresh] was called.
  int refreshCalls = 0;

  /// How many times [invalidate] was called.
  int invalidateCalls = 0;

  /// The database a successful refresh writes into.
  AppDatabase? database;

  /// The records [savePersonalDetails] was handed.
  final List<ProfileFields> savedDetails = <ProfileFields>[];

  /// What [savePersonalDetails] answers; false stands for an unreachable server.
  bool saveDetailsResult = true;

  /// What [pullPersonalDetails] answers; null stands for an unreachable server.
  ProfileFields? detailsToPull;

  @override
  Future<bool> refresh() async {
    refreshCalls++;
    if (!refreshResult) return false;
    final db = database;
    final row = rowToCache;
    if (db == null || row == null) return true;
    await ProfilesDao(db).upsert(row);
    final firm = firmToCache;
    if (firm != null) await FirmsDao(db).upsert(firm);
    final member = memberToCache;
    if (member != null) await FirmMembersDao(db).upsert(member);
    return true;
  }

  @override
  Future<bool> savePersonalDetails(ProfileFields fields) async {
    savedDetails.add(fields);
    return saveDetailsResult;
  }

  @override
  Future<ProfileFields?> pullPersonalDetails() async => detailsToPull;

  @override
  Future<void> invalidate() async {
    invalidateCalls++;
    final db = database;
    if (db == null) return;
    // Mirrors the real repository: the pull-only caches are emptied, not kept.
    await db.delete(db.profiles).go();
    await db.delete(db.firms).go();
    await db.delete(db.firmMembers).go();
  }
}

/// Seeds one cached profile row.
Future<void> seedProfile(
  AppDatabase db, {
  required String userId,
  String fullName = 'Adv. Rahim',
  String role = AccountRole.individual,
  String? firmId,
  int? subscriptionExpiry,
  String subscriptionStatus = 'free',
}) => ProfilesDao(db).upsert(
  ProfilesCompanion(
    id: Value(userId),
    fullName: Value(fullName),
    role: Value(role),
    firmId: Value(firmId),
    subscriptionStatus: Value(subscriptionStatus),
    subscriptionExpiry: Value(subscriptionExpiry),
    createdAt: const Value(1),
  ),
);

/// Seeds one cached firm row.
Future<void> seedFirm(AppDatabase db, {String firmId = 'firm-1'}) =>
    FirmsDao(db).upsert(
      const FirmsCompanion(
        id: Value('firm-1'),
        name: Value('Rahman & Associates'),
        ownerId: Value('owner-1'),
        subscriptionStatus: Value('active'),
        createdAt: Value(1),
      ),
    );

/// Seeds one cached membership row.
Future<void> seedMembership(
  AppDatabase db, {
  required String userId,
  String firmId = 'firm-1',
  String role = AccountRole.associate,
  bool canAdd = false,
  bool canEdit = false,
  bool canDelete = false,
  int permissionsSyncedAt = 1000,
}) => FirmMembersDao(db).upsert(
  FirmMembersCompanion(
    id: Value('$firmId:$userId'),
    firmId: Value(firmId),
    userId: Value(userId),
    role: Value(role),
    canAdd: Value(canAdd),
    canEdit: Value(canEdit),
    canDelete: Value(canDelete),
    syncedAt: Value(permissionsSyncedAt),
    permissionsSyncedAt: Value(permissionsSyncedAt),
  ),
);

/// Sends one lifecycle message to the framework, as the engine would.
Future<void> _sendLifecycle(WidgetTester tester, String state) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/lifecycle',
    const StringCodec().encodeMessage(state),
    (_) {},
  );
  await tester.pumpAndSettle();
}

/// Subscribes to [provider] and returns its first value.
///
/// Riverpod starts a stream provider when something listens to it; asking for
/// `.future` on an unlistened one never resolves, so tests subscribe first.
Future<T> firstStreamValue<T>(
  ProviderContainer container,
  StreamProvider<T> provider,
) {
  container.listen(provider, (_, _) {});
  return container.read(provider.future);
}

void main() {
  group('Server timestamps become epoch milliseconds', () {
    test('an ISO-8601 string from PostgREST is converted', () {
      expect(
        subscriptionExpiryToEpochMs('2027-01-12T00:00:00+00:00'),
        DateTime.utc(2027, 1, 12).millisecondsSinceEpoch,
      );
      // The `Z` form and an explicit offset describe the same instant.
      expect(
        subscriptionExpiryToEpochMs('2027-01-12T06:00:00+06:00'),
        DateTime.utc(2027, 1, 12).millisecondsSinceEpoch,
      );
    });

    test('an already-numeric value passes through', () {
      expect(subscriptionExpiryToEpochMs(1735689600000), 1735689600000);
      expect(subscriptionExpiryToEpochMs('1735689600000'), 1735689600000);
      expect(
        subscriptionExpiryToEpochMs(DateTime.utc(2027, 1, 12)),
        DateTime.utc(2027, 1, 12).millisecondsSinceEpoch,
      );
    });

    test('an unreadable value is null rather than a guess', () {
      expect(subscriptionExpiryToEpochMs(null), isNull);
      expect(subscriptionExpiryToEpochMs(''), isNull);
      expect(subscriptionExpiryToEpochMs('soon'), isNull);
      expect(subscriptionExpiryToEpochMs(<String, dynamic>{}), isNull);
    });
  });

  group('Firm mode comes from the cached firm id', () {
    late AuthTestHarness harness;
    late ProviderContainer container;

    /// Builds a container, then seeds [seed] into the cache.
    ///
    /// The seed lands after `authViewModelProvider` has built, because adoption
    /// runs on that first read and empties the pull-only caches by design.
    Future<void> setUpContainer({
      Future<void> Function(AppDatabase db)? seed,
    }) async {
      container = ProviderContainer(overrides: await harness.setUp());
      addTearDown(container.dispose);
      await container.read(authViewModelProvider.future);
      if (seed != null) await seed(harness.db);
      await firstStreamValue(container, accountProfileProvider);
    }

    setUp(() {
      harness = AuthTestHarness(
        auth: FakeAuthRepository(identity: const AuthIdentity(userId: 'user-1')),
      );
    });
    tearDown(() async {
      await harness.tearDown();
      await harness.auth.dispose();
    });

    test('no cached profile is an individual with full rights', () async {
      await setUpContainer();

      expect(container.read(firmModeProvider), isFalse);
      expect(container.read(accountRoleProvider), AccountRole.individual);
      expect(container.read(canManageFirmProvider), isFalse);
      expect(container.read(canDeleteDirectlyProvider), isTrue);
      expect(container.read(canAddDirectlyProvider), isTrue);
      expect(container.read(canEditDirectlyProvider), isTrue);
    });

    test('a firm owner has every permission and manages the firm', () async {
      await setUpContainer(
        seed: (db) => seedProfile(
          db,
          userId: 'user-1',
          role: AccountRole.owner,
          firmId: 'firm-1',
        ),
      );

      expect(container.read(firmModeProvider), isTrue);
      expect(container.read(accountRoleProvider), AccountRole.owner);
      expect(container.read(firmRoleProvider), AccountRole.owner);
      expect(container.read(canManageFirmProvider), isTrue);
      expect(container.read(canDeleteDirectlyProvider), isTrue);
      expect(container.read(canAddDirectlyProvider), isTrue);
      expect(container.read(canEditDirectlyProvider), isTrue);
    });

    test('a chamber owner is not a member, so the plans entry stays his', () async {
      await setUpContainer(
        seed: (db) => seedProfile(
          db,
          userId: 'user-1',
          role: AccountRole.owner,
          firmId: 'firm-1',
        ),
      );

      // Phase 9's split: the owner's purchase is the chamber's renewal, so only
      // the non-owner holds the no-plan rule.
      expect(container.read(firmModeProvider), isTrue);
      expect(container.read(firmMemberProvider), isFalse);
    });

    test('an associate or viewer is a member', () async {
      await setUpContainer(
        seed: (db) => seedProfile(
          db,
          userId: 'user-1',
          role: AccountRole.associate,
          firmId: 'firm-1',
        ),
      );
      expect(container.read(firmMemberProvider), isTrue);
    });

    test('an individual is not a member', () async {
      await setUpContainer(
        seed: (db) => seedProfile(db, userId: 'user-1'),
      );
      expect(container.read(firmModeProvider), isFalse);
      expect(container.read(firmMemberProvider), isFalse);
    });

    test('an associate is limited by the cached permission flags', () async {
      await setUpContainer(
        seed: (db) async {
          await seedProfile(
            db,
            userId: 'user-1',
            role: AccountRole.associate,
            firmId: 'firm-1',
          );
          await seedMembership(
            db,
            userId: 'user-1',
            canAdd: true,
            canEdit: true,
          );
        },
      );
      await firstStreamValue(container, firmMembershipProvider);

      expect(container.read(firmModeProvider), isTrue);
      expect(container.read(canManageFirmProvider), isFalse);
      expect(container.read(canAddDirectlyProvider), isTrue);
      expect(container.read(canEditDirectlyProvider), isTrue);
      // No `can_delete`: a removal becomes a request instead of a deletion.
      expect(container.read(canDeleteDirectlyProvider), isFalse);
    });

    test('a firm member with no cached membership fails closed', () async {
      await setUpContainer(
        seed: (db) => seedProfile(
          db,
          userId: 'user-1',
          role: AccountRole.viewer,
          firmId: 'firm-1',
        ),
      );

      expect(container.read(firmModeProvider), isTrue);
      expect(container.read(canAddDirectlyProvider), isFalse);
      expect(container.read(canEditDirectlyProvider), isFalse);
      expect(container.read(canDeleteDirectlyProvider), isFalse);
      expect(container.read(permissionsSyncedAtProvider), isNull);
    });

    test('the permission freshness stamp is the cached one', () async {
      await setUpContainer(
        seed: (db) async {
          await seedProfile(
            db,
            userId: 'user-1',
            role: AccountRole.associate,
            firmId: 'firm-1',
          );
          await seedMembership(db, userId: 'user-1', permissionsSyncedAt: 4242);
        },
      );
      await firstStreamValue(container, firmMembershipProvider);

      expect(container.read(permissionsSyncedAtProvider), 4242);
    });

    test('the firm row is cached beside the profile', () async {
      await setUpContainer(
        seed: (db) async {
          await seedProfile(
            db,
            userId: 'user-1',
            role: AccountRole.associate,
            firmId: 'firm-1',
          );
          await seedFirm(db);
        },
      );

      await firstStreamValue(container, accountFirmProvider);

      expect(
        container.read(accountFirmProvider).value?.name,
        'Rahman & Associates',
      );
    });

    test('premium is derived from the expiry, not the status flag', () async {
      final future = DateTime.now().toUtc().add(const Duration(days: 30));
      await setUpContainer(
        seed: (db) => seedProfile(
          db,
          userId: 'user-1',
          subscriptionStatus: 'free',
          subscriptionExpiry: future.millisecondsSinceEpoch,
        ),
      );

      expect(await container.read(premiumAccessProvider.future), isTrue);
    });

    test(
      'an expired subscription is free even while the flag says active',
      () async {
        final past = DateTime.now().toUtc().subtract(const Duration(days: 30));
        await setUpContainer(
          seed: (db) => seedProfile(
            db,
            userId: 'user-1',
            subscriptionStatus: 'active',
            subscriptionExpiry: past.millisecondsSinceEpoch,
          ),
        );

        expect(await container.read(premiumAccessProvider.future), isFalse);
      },
    );
  });

  testWidgets('the refresh scope pulls on launch and again on resume', (
    tester,
  ) async {
    final harness = AuthTestHarness(
      auth: FakeAuthRepository(identity: const AuthIdentity(userId: 'user-1')),
    );
    addTearDown(() async {
      await harness.tearDown();
      await harness.auth.dispose();
    });
    final repository = FakeProfileRepository()..refreshResult = true;
    final overrides = await harness.setUp();
    repository.database = harness.db;
    repository.rowToCache = const ProfilesCompanion(
      id: Value('user-1'),
      fullName: Value('Adv. Rahim'),
      role: Value(AccountRole.individual),
      subscriptionStatus: Value('free'),
      createdAt: Value(1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          profileRepositoryProvider.overrideWith((_) async => repository),
        ],
        child: const AccountRefreshScope(child: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.refreshCalls, 1, reason: 'once on launch');

    // Leave the app and come back: permissions may have changed while away.
    await _sendLifecycle(tester, 'AppLifecycleState.inactive');
    await _sendLifecycle(tester, 'AppLifecycleState.resumed');

    expect(repository.refreshCalls, 2, reason: 'again on resume');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('a session that arrives after launch is pulled at once', (
    tester,
  ) async {
    // Regression: this scope sits above the router and mounts once per process,
    // so signing in on a running app re-ran neither the launch nor the resume
    // hook and nothing pulled the account row. Every entitlement gate reads that
    // row, which is how a premium account was told "Subscription: Free" beside
    // "Plan: 1 Month" and refused with "premium is required to sync" until the
    // next resume.
    final harness = AuthTestHarness();
    addTearDown(() async {
      await harness.tearDown();
      await harness.auth.dispose();
    });
    final repository = FakeProfileRepository()..refreshResult = true;
    final overrides = await harness.setUp();
    repository.database = harness.db;
    repository.rowToCache = const ProfilesCompanion(
      id: Value('user-1'),
      fullName: Value('Adv. Rahim'),
      role: Value(AccountRole.individual),
      subscriptionStatus: Value('free'),
      createdAt: Value(1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          profileRepositoryProvider.overrideWith((_) async => repository),
        ],
        child: const AccountRefreshScope(child: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.refreshCalls, 0, reason: 'nobody is signed in yet');

    // The SDK reports a sign-in on the already-running app.
    harness.auth.emit(
      const AuthSessionEvent(
        identity: AuthIdentity(userId: 'user-1', email: 'advocate.asad@law.com'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.refreshCalls, 1, reason: 'the new session is pulled');
    expect(
      (await ProfilesDao(harness.db).getById('user-1'))?.fullName,
      'Adv. Rahim',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  group('Refresh and invalidation', () {
    late AuthTestHarness harness;
    late FakeProfileRepository repository;

    setUp(() {
      repository = FakeProfileRepository();
      harness = AuthTestHarness(
        auth: FakeAuthRepository(identity: const AuthIdentity(userId: 'user-1')),
      );
    });

    tearDown(() async {
      await harness.tearDown();
      await harness.auth.dispose();
    });

    /// Builds a container with the fake repository, seeding [seed] afterwards.
    Future<ProviderContainer> container({
      Future<void> Function(AppDatabase db)? seed,
      List<Override> overrides = const [],
    }) async {
      final container = ProviderContainer(
        overrides: [
          ...await harness.setUp(),
          profileRepositoryProvider.overrideWith((_) async => repository),
          ...overrides,
        ],
      );
      addTearDown(container.dispose);
      repository.database ??= harness.db;
      await container.read(authViewModelProvider.future);
      if (seed != null) await seed(harness.db);
      return container;
    }

    test('a signed-out device refreshes nothing', () async {
      harness = AuthTestHarness();
      final c = await container();

      expect(await c.read(accountRefreshProvider)(), isFalse);
      expect(repository.refreshCalls, 0);
    });

    test('a successful refresh fills the cache and hydrates a blank name', () async {
      repository
        ..refreshResult = true
        ..rowToCache = const ProfilesCompanion(
          id: Value('user-1'),
          fullName: Value('Adv. Rahim'),
          role: Value(AccountRole.individual),
          subscriptionStatus: Value('free'),
          createdAt: Value(1),
        );
      final c = await container();

      expect(await c.read(accountRefreshProvider)(), isTrue);

      expect(repository.refreshCalls, 1);
      expect(
        (await ProfilesDao(harness.db).getById('user-1'))?.fullName,
        'Adv. Rahim',
      );
      // The drawer header and the Profile screen read the local record.
      expect(c.read(profileFieldsProvider).fullName, 'Adv. Rahim');
    });

    test('a name the user typed is never overwritten by a pull', () async {
      final c = await container();
      await c
          .read(profileFieldsProvider.notifier)
          .save(const ProfileFields(fullName: 'My Own Name'));
      repository
        ..refreshResult = true
        ..rowToCache = const ProfilesCompanion(
          id: Value('user-1'),
          fullName: Value('Server Name'),
          role: Value(AccountRole.individual),
          subscriptionStatus: Value('free'),
          createdAt: Value(1),
        );

      await c.read(accountRefreshProvider)();

      expect(c.read(profileFieldsProvider).fullName, 'My Own Name');
      expect(
        (await ProfilesDao(harness.db).getById('user-1'))?.fullName,
        'Server Name',
      );
    });

    test('a failed refresh leaves the cache exactly as it was', () async {
      repository.refreshResult = false;
      final c = await container(
        seed: (db) => seedProfile(db, userId: 'user-1', fullName: 'Cached Name'),
      );

      expect(await c.read(accountRefreshProvider)(), isFalse);

      expect(
        (await ProfilesDao(harness.db).getById('user-1'))?.fullName,
        'Cached Name',
      );
      expect(c.read(profileFieldsProvider).fullName, isEmpty);
    });

    test('signing out empties the pull-only caches', () async {
      final c = await container(
        seed: (db) async {
          await seedProfile(
            db,
            userId: 'user-1',
            role: AccountRole.associate,
            firmId: 'firm-1',
          );
          await seedMembership(db, userId: 'user-1');
          await seedFirm(db);
        },
      );

      await c.read(authViewModelProvider.notifier).signOut();

      expect(await ProfilesDao(harness.db).getAll(), isEmpty);
      expect(await FirmsDao(harness.db).getAll(), isEmpty);
      expect(await FirmMembersDao(harness.db).getAll(), isEmpty);
      expect(c.read(profileFieldsProvider).fullName, isEmpty);
    });

    test('redeeming an invite pulls the new permissions', () async {
      repository.refreshResult = true;
      final c = await container();
      await c
          .read(authViewModelProvider.notifier)
          .rememberInviteCode('abcde12345');

      await c.read(authViewModelProvider.notifier).redeemPendingInvite();

      expect(harness.firm.redeemedCodes, ['abcde12345']);
      expect(repository.refreshCalls, 1);
    });

    test('the unavailable repository clears the cache on demand', () async {
      await harness.setUp();
      await seedProfile(harness.db, userId: 'user-1');

      final unavailable = UnavailableProfileRepository(harness.db);

      expect(await unavailable.refresh(), isFalse);
      await unavailable.invalidate();

      expect(await ProfilesDao(harness.db).getAll(), isEmpty);
    });
  });
}
