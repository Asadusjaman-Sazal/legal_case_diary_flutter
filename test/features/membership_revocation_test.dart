/// Task 20 Phase 2 — the removed device.
///
/// The server half is `remove_firm_member` (pinned by
/// `supabase/tests/rpc_smoke_test.sql`); this suite pins the client half, and the
/// fact it turns on is the one the whole design rests on: **the profile says
/// nothing and the cached membership row says everything**. A device that was in
/// a firm has a `firm_members` row; after a removal `profiles.firm_id` is null;
/// only the two disagreeing means "this account was removed", which is why an
/// individual, a firm member, and a device that merely signed out are all left
/// exactly as they were.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/firm_members_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/profiles_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_repository.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/membership_revoked_scope.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/data/logout_flow.dart';

import 'auth_test_support.dart';

/// Rendered inside the scope: it stands in for the whole diary.
const String revocationDiaryMarker = 'The Diary';

/// Where the scope sends a finished removal.
const String revocationLoginMarker = 'The Login Screen';

void main() {
  late AuthTestHarness harness;
  late AppDatabase db;
  var ended = 0;

  setUp(() {
    ended = 0;
    harness = AuthTestHarness(
      auth: FakeAuthRepository(
        identity: const AuthIdentity(
          userId: 'user-1',
          email: 'advocate.asad@law.com',
        ),
      ),
    );
  });

  tearDown(() async {
    await harness.tearDown();
    await harness.auth.dispose();
  });

  /// Writes the cached profile the server last confirmed.
  Future<void> seedProfile({String? firmId, String role = 'individual'}) =>
      ProfilesDao(db).upsert(
        ProfilesCompanion(
          id: const Value('user-1'),
          fullName: const Value('Adv. Karim'),
          role: Value(role),
          firmId: Value(firmId),
          subscriptionStatus: const Value('free'),
          createdAt: const Value(1),
        ),
      );

  /// Writes the membership row this device cached while it was in the firm.
  Future<void> seedCachedMembership() => FirmMembersDao(db).upsert(
    const FirmMembersCompanion(
      id: Value('firm-1:user-1'),
      firmId: Value('firm-1'),
      userId: Value('user-1'),
      role: Value(AccountRole.associate),
      canAdd: Value(true),
      canEdit: Value(true),
      canDelete: Value(false),
      permissionsSyncedAt: Value(1),
    ),
  );

  /// One local row and one queued mutation, so a wipe that only half happened
  /// fails the test rather than passing it.
  Future<void> seedLocalWork() async {
    await db
        .into(db.notes)
        .insert(
          NotesCompanion.insert(
            id: 'n1',
            userId: 'user-1',
            title: 'Local',
            body: 'Body',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db
        .into(db.syncQueue)
        .insert(
          SyncQueueCompanion.insert(
            entityType: 'notes',
            entityId: 'n1',
            operation: 'insert',
            mutationId: 'mut-1',
            basePayload: '{}',
            changedFields: '["title"]',
            payload: '{"id":"n1"}',
            preMutationPayload: '{}',
            createdAt: 0,
            state: 'pending',
          ),
        );
  }

  /// Pumps the removal scope inside a real router.
  Future<void> pumpRevocationScope(WidgetTester tester) async {
    // The harness opens the database as it builds its overrides, so this is the
    // first moment the flow beneath the scope can be pointed at it.
    final overrides = await harness.setUp(
      extra: <Override>[
        // The real flow over the real database, with only the session end stood
        // in for: the wipe under test is production's own.
        logoutFlowProvider.overrideWith(
          (ref) async => LogoutFlow(
            db: harness.db,
            premium: false,
            online: true,
            runBacklogPush: () async => null,
            endSession: () async => ended++,
            kdfIterations: 1,
          ),
        ),
      ],
    );
    db = harness.db;

    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late final GoRouter router;
    router = GoRouter(
      initialLocation: '/app',
      routes: <RouteBase>[
        GoRoute(
          path: '/app',
          builder: (_, _) => MembershipRevokedScope(
            router: router,
            child: const Scaffold(body: Center(child: Text(revocationDiaryMarker))),
          ),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (_, _) => const Scaffold(
            body: Center(child: Text(revocationLoginMarker)),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a device that was in a firm and is not any more is blocked', (
    tester,
  ) async {
    await pumpRevocationScope(tester);
    await seedCachedMembership();
    await seedProfile();
    await tester.pumpAndSettle();

    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l.membershipRevoked_title), findsOneWidget);
    expect(
      find.text(revocationDiaryMarker),
      findsNothing,
      reason: 'there is no screen to reach and no route past it',
    );

    await unmountApp(tester);
  });

  testWidgets('acting on it discards the queue, wipes and ends the session', (
    tester,
  ) async {
    await pumpRevocationScope(tester);
    await seedCachedMembership();
    await seedProfile();
    await seedLocalWork();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('membership-revoked-logout')));
    await tester.pumpAndSettle();

    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(ended, 1);
    expect(find.text(revocationLoginMarker), findsOneWidget);
    // The wipe is the logout flow's own complete one, so the queue goes with
    // everything else — which is what "discard or roll back the pending local
    // mutations" reduces to when the answer is "nothing of this device's is
    // wanted any more".
    expect(await db.select(db.notes).get(), isEmpty);
    expect(await db.select(db.syncQueue).get(), isEmpty);
    expect(await db.select(db.firmMembers).get(), isEmpty);
    expect(find.text(l.membershipRevoked_title), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('nothing is erased before the user acts', (tester) async {
    await pumpRevocationScope(tester);
    await seedCachedMembership();
    await seedProfile();
    await seedLocalWork();
    await tester.pumpAndSettle();

    // The erasure is the one irreversible step, so it waits for the tap: the
    // diary's rows are all still there while the screen is up.
    expect(await db.select(db.notes).get(), hasLength(1));
    expect(ended, 0);

    await unmountApp(tester);
  });

  testWidgets('an individual account is left exactly as it was', (tester) async {
    await pumpRevocationScope(tester);
    // No cached membership row: this device has never been in a firm, so the
    // null firm id is the server's ordinary answer and not a removal.
    await seedProfile();
    await tester.pumpAndSettle();

    expect(find.text(revocationDiaryMarker), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('a live firm member is left exactly as it was', (tester) async {
    await pumpRevocationScope(tester);
    await seedCachedMembership();
    await seedProfile(firmId: 'firm-1', role: AccountRole.associate);
    await tester.pumpAndSettle();

    expect(find.text(revocationDiaryMarker), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('a profile that has not been pulled yet is not a removal', (
    tester,
  ) async {
    await pumpRevocationScope(tester);
    // A membership row with no profile at all: nothing has been refreshed, so
    // there is nothing that could disagree with it yet.
    await seedCachedMembership();
    await tester.pumpAndSettle();

    expect(find.text(revocationDiaryMarker), findsOneWidget);

    await unmountApp(tester);
  });
}
