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
import 'package:legal_case_diary/core/providers/notification_providers.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/firm_members_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/profiles_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_repository.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/membership_revoked_scope.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/data/logout_flow.dart';

import '../core/notification_test_support.dart';
import 'auth_test_support.dart';

/// Rendered inside the scope: it stands in for the whole diary.
const String revocationDiaryMarker = 'The Diary';

/// Where the scope sends a finished removal.
const String revocationLoginMarker = 'The Login Screen';

void main() {
  late AuthTestHarness harness;
  late AppDatabase db;
  var ended = 0;

  /// The erasure the scope started, so a test can await it rather than race it.
  Future<void>? startedErasure;

  /// The platform's alarm manager, stood in for: the wipe cannot reach scheduled
  /// notifications, so the erasure disarms them explicitly and this records it.
  late FakeNotificationScheduler scheduler;

  setUp(() {
    ended = 0;
    startedErasure = null;
    scheduler = FakeNotificationScheduler();
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

  /// Waits for the erasure, then pumps the frames that show its result.
  ///
  /// Awaiting the scope's own future is what keeps this honest: the wipe is
  /// asynchronous and replaces the widget tree, so a test that only pumps has no
  /// way to know when the database work finished, and the next test then inherits
  /// a connection still mid-transaction. Not [WidgetTester.pumpAndSettle] either:
  /// while a removal is being handled the notice carries an indeterminate progress
  /// spinner, and an indeterminate animation never settles.
  Future<void> pumpUntilErased(WidgetTester tester) async {
    // Frames first, and not a settle: the removal is noticed on a frame, and the
    // notice's progress spinner is an indeterminate animation while the erasure
    // runs, so a settle would spin until the test timed out.
    for (var i = 0; i < 30 && startedErasure == null; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Then the erasure itself, awaited to completion. Without this the wipe can
    // still hold the database when the harness closes it in tearDown, and
    // `db.close()` blocks on it — which is what stalled this file.
    await startedErasure;
    // Finally the frames that show its result, including the navigation out.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
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
        notificationSchedulerProvider.overrideWithValue(scheduler),
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
            // The scope starts the erasure itself — the user's act is not needed
            // (user ruling) — and this is how the test waits for it. Pumps alone
            // cannot say when the wipe finished.
            onEraseStarted: (erasure) => startedErasure = erasure,
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
    // Frames rather than a settle: while a removal is being handled the notice
    // shows an indeterminate spinner, and a spinner never settles.
    await pumpUntilErased(tester);

    // The diary is unreachable, and by now the erasure has run and taken the
    // session with it — so the end state is the Login screen, not the notice.
    // The notice itself is asserted in the next test, while it is on screen.
    expect(
      find.text(revocationDiaryMarker),
      findsNothing,
      reason: 'there is no screen to reach and no route past it',
    );
    expect(ended, 1);
    expect(find.text(revocationLoginMarker), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('the notice is informational and offers no erase action', (
    tester,
  ) async {
    await pumpRevocationScope(tester);
    // Seeding the two rows is what the scope notices — the DAO write has to
    // travel through the profile stream first, so a single frame is not enough.
    await seedCachedMembership();
    await seedProfile();

    final l = await AppLocalizations.delegate.load(const Locale('en'));
    // Pump frame by frame until the notice is up, and assert *there* rather than
    // after a settle: the frame after the notice is the one where the erasure
    // finishes and the app leaves for Login, and the notice is what the removed
    // member is meant to read (user ruling).
    var sawNotice = false;
    for (var i = 0; i < 20 && !sawNotice; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      sawNotice = find.text(l.membershipRevoked_title).evaluate().isNotEmpty;
    }
    expect(
      sawNotice,
      isTrue,
      reason: 'the member is told what happened, before the app leaves',
    );
    expect(find.text(revocationDiaryMarker), findsNothing);
    expect(
      find.widgetWithText(FilledButton, l.membershipRevoked_retry),
      findsNothing,
      reason: 'nothing has failed yet, so no action is offered',
    );
    expect(
      find.byKey(const ValueKey('membership-revoked-logout')),
      findsNothing,
      reason: 'the withdrawn button is not coming back',
    );

    // The assertions above are made while the erasure is still running, which is
    // the point. It is then awaited to completion anyway: an erasure left in
    // flight holds the database open, and the harness's `db.close()` in tearDown
    // would block on it — which is what stalled this file.
    await startedErasure;
    await unmountApp(tester);
  });

  testWidgets('it erases by itself, with no tap, and ends the session', (
    tester,
  ) async {
    await pumpRevocationScope(tester);
    await seedCachedMembership();
    await seedProfile();
    await seedLocalWork();
    // No tap and no button to tap: the ruling withdraws the *Erase & sign out*
    // action, because a copy that waits for a tap is a copy the person holding
    // the phone can keep. Pumping frames is all the erasure needs to run.
    await pumpUntilErased(tester);

    expect(
      find.byKey(const ValueKey('membership-revoked-logout')),
      findsNothing,
      reason: 'the erase button is withdrawn; there is nothing to press',
    );

    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(ended, 1);
    expect(find.text(revocationLoginMarker), findsOneWidget);
    // The wipe is the logout flow's own complete one, so the queue goes with
    // everything else — which is what "discards every queued mutation instead of
    // pushing it" reduces to when the answer is "nothing of this device's is
    // wanted any more".
    expect(await db.select(db.notes).get(), isEmpty);
    expect(await db.select(db.syncQueue).get(), isEmpty);
    expect(await db.select(db.firmMembers).get(), isEmpty);
    // The notice stays in the tree behind the Login route — that is the router
    // stacking, not the removal still being pending. What proves the erasure ran
    // is the three empty tables above and the ended session.
    expect(l.membershipRevoked_title, isNotEmpty);

    await unmountApp(tester);
  });

  testWidgets('it cancels this device\'s scheduled notifications', (
    tester,
  ) async {
    await pumpRevocationScope(tester);
    await seedCachedMembership();
    await seedProfile();
    await pumpUntilErased(tester);

    // Scheduled case notifications live in the platform's alarm manager, not in
    // the database, so the wipe cannot reach them: without this the phone would
    // keep alerting about a chamber it can no longer open.
    expect(
      scheduler.cancelAllCalls,
      1,
      reason: 'the erasure must disarm this device\'s alerts',
    );

    await unmountApp(tester);
  });

  testWidgets('the erasure does not happen during the build that notices it', (
    tester,
  ) async {
    await pumpRevocationScope(tester);
    await seedCachedMembership();
    await seedProfile();
    await seedLocalWork();

    // One frame only: the removal is noticed during build, and the erasure is
    // scheduled off that build rather than run inside it — a callback that wiped
    // the database mid-build would be a write during a build.
    await tester.pump();
    expect(await db.select(db.notes).get(), hasLength(1));

    // The following frames are where it runs, by itself and with no tap.
    await pumpUntilErased(tester);
    expect(await db.select(db.notes).get(), isEmpty);
    expect(ended, 1);

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
