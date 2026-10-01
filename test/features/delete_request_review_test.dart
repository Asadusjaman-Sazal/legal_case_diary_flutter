/// Task 20 Phase 4 — the reviewer side of the delete-request workflow.
///
/// These tests drive the real repository, the real DAO and the real providers
/// over an in-memory Drift database; nothing about the decision is faked. What
/// they pin:
///
///  * who sees what — a member with delete permission reads the **queue**, a
///    member without it reads **their own requests**, and the Settings badge
///    counts the half that is actually waiting for that account;
///  * the writer — an approval writes the request row and queues exactly one
///    `update` on `entity_type = 'delete_request'` whose payload says
///    `status = 'approved'`, which is the one field the server's review branch
///    reads to know a decision was made;
///  * reconfirm — a request the server parked as `stale_review_required` is
///    re-decided rather than recreated, and says so on the button;
///  * the requester's notification — the decision reads off their list, and the
///    badge that announced it clears once the screen has been opened.
///
/// The network boundary is absent on purpose: every write here is the local,
/// queued half that makes reviews offline-capable, and the server half is pinned
/// by `push_changes_smoke_test.sql`.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/core/theme/app_theme.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/firm_members_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/profiles_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_repository.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_viewmodel.dart';
import 'package:legal_case_diary/features/settings/presentation/delete_request_review_screen.dart';
import 'package:legal_case_diary/features/settings/presentation/delete_requests_screen.dart';
import 'package:legal_case_diary/features/settings/presentation/delete_requests_viewmodel.dart';
import 'package:legal_case_diary/sync/delete_requests_dao.dart';
import 'package:legal_case_diary/sync/sync_queue_dao.dart';

import 'auth_test_support.dart';

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
  late AuthTestHarness harness;
  late AppDatabase db;

  const identity = AuthIdentity(
    userId: 'user-1',
    email: 'advocate.asad@law.com',
  );

  setUp(() {
    harness = AuthTestHarness(auth: FakeAuthRepository(identity: identity));
  });

  tearDown(() async {
    await harness.tearDown();
    await harness.auth.dispose();
  });

  /// Creates the harness's one provider scope.
  ///
  /// Two things are stated rather than derived. The **identity** is injected so
  /// the real `AuthViewModel` — which also runs identity adoption on its first
  /// read, and empties the pull-only caches while doing it — never builds. The
  /// **local identity** is bound to the same account, because in production a
  /// sign-in does that: without it every write here would be stamped with a
  /// fresh per-install placeholder instead of the account the server sees.
  Future<List<Override>> openScope() async {
    final overrides = await harness.setUp();
    final service = LocalIdentityService(harness.prefs);
    await service.bindAccount('user-1');
    return <Override>[
      ...overrides,
      authIdentityProvider.overrideWithValue(identity),
      localIdentityServiceProvider.overrideWithValue(service),
    ];
  }

  /// Writes the cached profile the permission providers read.
  Future<void> seedProfile({
    String? firmId,
    String role = 'individual',
  }) =>
      ProfilesDao(db).upsert(
        ProfilesCompanion(
          id: const Value('user-1'),
          fullName: const Value('Adv. Karim'),
          role: Value(role),
          firmId: Value(firmId),
          subscriptionStatus: const Value('premium'),
          createdAt: const Value(1),
        ),
      );

  /// Writes this account's cached membership row.
  Future<void> seedMembership({bool canDelete = false}) =>
      FirmMembersDao(db).upsert(
        FirmMembersCompanion(
          id: const Value('firm-1:user-1'),
          firmId: const Value('firm-1'),
          userId: const Value('user-1'),
          role: const Value('associate'),
          canAdd: const Value(true),
          canEdit: const Value(true),
          canDelete: Value(canDelete),
          permissionsSyncedAt: const Value(1),
        ),
      );

  /// Writes one delete request and returns its id.
  Future<String> seedRequest({
    required String id,
    String entityType = 'note',
    String entityId = 'note-1',
    String title = 'My Note',
    String requestedBy = 'user-2',
    String status = 'pending',
    int updatedAt = 2000,
    int version = 4,
    String? reviewedBy,
  }) async {
    await DeleteRequestsDao(db).insert(
      DeleteRequestsCompanion(
        id: Value(id),
        firmId: const Value('firm-1'),
        entityType: Value(entityType),
        entityId: Value(entityId),
        entitySnapshot: Value(jsonEncode({'id': entityId, 'title': title})),
        targetBaseVersion: const Value(2),
        requestedBy: Value(requestedBy),
        status: Value(status),
        reviewedBy: Value(reviewedBy),
        createdAt: const Value(1000),
        updatedAt: Value(updatedAt),
        version: Value(version),
        lastModifiedBy: const Value('user-2'),
        isDeleted: const Value(false),
      ),
    );
    return id;
  }

  /// Awaits the permission chain the screens read, so a seeded cache is the
  /// answer the very next `read` gets.
  Future<void> primePermissions(ProviderContainer container) async {
    await firstStreamValue(container, accountProfileProvider);
    await firstStreamValue(container, firmMembershipProvider);
    await firstStreamValue(container, deleteRequestsStreamProvider);
    await firstStreamValue(container, myDeleteRequestsStreamProvider);
  }

  /// Pumps [screen] inside a router that can reach the review route.
  ///
  /// The overrides are passed in rather than built here: the database has to be
  /// seeded *before* the widget reads it, so the caller opens the scope once and
  /// hands it over.
  Future<void> pumpWithRouter(
    WidgetTester tester,
    Widget screen,
    List<Override> overrides,
  ) async {
    final router = GoRouter(
      initialLocation: '/under-test',
      routes: <RouteBase>[
        GoRoute(path: '/under-test', builder: (_, _) => screen),
        GoRoute(
          path: AppRoutes.settingsReviewDeleteRequest,
          builder: (_, state) => DeleteRequestReviewScreen(
            requestId: state.pathParameters['requestId'] ?? '',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(
          theme: AppTheme.lightTheme(const Locale('en')),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('The reviewer badge and queue', () {
    test('a member with delete permission counts the pending queue', () async {
      final container = ProviderContainer(overrides: await openScope());
      addTearDown(container.dispose);
      db = harness.db;

      await seedProfile(firmId: 'firm-1', role: AccountRole.owner);
      await seedRequest(id: 'r1');
      await seedRequest(id: 'r2', status: 'stale_review_required');
      // Already decided: audit history, not work.
      await seedRequest(id: 'r3', status: 'approved', reviewedBy: 'user-1');

      await primePermissions(container);

      expect(container.read(canDeleteDirectlyProvider), isTrue);
      expect(container.read(deleteReviewQueueProvider), hasLength(2));
      expect(container.read(deleteRequestsBadgeCountProvider), 2);
    });

    test('a requester counts only decisions they have not read', () async {
      final container = ProviderContainer(overrides: await openScope());
      addTearDown(container.dispose);
      db = harness.db;

      await seedProfile(firmId: 'firm-1', role: AccountRole.associate);
      await seedMembership(canDelete: false);
      // Their own request, still pending: not news.
      await seedRequest(id: 'r1', requestedBy: 'user-1');
      // Their own request, decided: news.
      await seedRequest(
        id: 'r2',
        requestedBy: 'user-1',
        status: 'rejected',
        updatedAt: 5000,
        reviewedBy: 'user-1',
      );
      // Somebody else's request: not theirs to count either way.
      await seedRequest(id: 'r3', status: 'approved', reviewedBy: 'user-1');

      await primePermissions(container);

      expect(container.read(canDeleteDirectlyProvider), isFalse);
      // The requester's list and badge read `watchMine`, so another member's
      // request is not merely filtered out of the count — it is never fetched.
      expect(container.read(myDeleteRequestsProvider), hasLength(2));
      expect(
        container
            .read(myDeleteRequestsProvider)
            .every((request) => request.requestedBy == 'user-1'),
        isTrue,
      );
      expect(container.read(deleteRequestsUnseenProvider), hasLength(1));
      expect(container.read(deleteRequestsBadgeCountProvider), 1);

      // Opening the screen is what "reading" a decision means.
      await container.read(deleteRequestsSeenProvider.notifier).markSeen(5000);
      expect(container.read(deleteRequestsBadgeCountProvider), 0);
    });

    testWidgets('an individual is told the queue is a firm feature', (
      tester,
    ) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile();

      await pumpAuthScreen(
        tester,
        const DeleteRequestsScreen(),
        overrides: overrides,
      );

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l.deleteRequests_firmOnly), findsOneWidget);

      await unmountApp(tester);
    });

    testWidgets('a reviewer sees the queue and taps into a review', (
      tester,
    ) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.owner);
      await seedRequest(id: 'r1', title: 'Land Dispute Note');
      await seedRequest(id: 'r2', status: 'approved', reviewedBy: 'user-1');

      await pumpWithRouter(tester, const DeleteRequestsScreen(), overrides);

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      // The pending one is in the queue; the decided one is audit history.
      expect(find.text('Land Dispute Note'), findsOneWidget);
      expect(find.text(l.deleteRequests_toReview), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('delete-request-row-r1')));
      await tester.pumpAndSettle();

      expect(find.text(l.deleteRequests_reviewTitle), findsOneWidget);

      await unmountApp(tester);
    });
  });

  group('The review writer', () {
    testWidgets('approving records the decision and queues it', (tester) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.owner);
      await seedRequest(id: 'r1', title: 'Land Dispute Note');

      await pumpAuthScreen(
        tester,
        const DeleteRequestReviewScreen(requestId: 'r1'),
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('delete-review-approve')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-review-confirm')));
      await tester.pumpAndSettle();

      final request = await DeleteRequestsDao(db).getById('r1');
      expect(request!.status, 'approved');
      expect(request.reviewedBy, 'user-1');

      final queue = (await SyncQueueDao(db).getByEntity('delete_request', 'r1'))
          .where((row) => row.state != 'resolved')
          .toList(growable: false);
      expect(queue, hasLength(1));
      expect(queue.single.operation, 'update');
      expect(queue.single.baseVersion, 4);
      final payload = jsonDecode(queue.single.payload) as Map<String, dynamic>;
      expect(payload['status'], 'approved');

      await unmountApp(tester);
    });

    testWidgets('a stale review is reconfirmed, not re-created', (
      tester,
    ) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.owner);
      await seedRequest(id: 'r1', status: 'stale_review_required');

      await pumpAuthScreen(
        tester,
        const DeleteRequestReviewScreen(requestId: 'r1'),
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      // The screen says what changed and asks for a reconfirm rather than an
      // approval it cannot honestly offer.
      expect(find.text(l.deleteRequests_reconfirm), findsOneWidget);
      expect(find.text(l.deleteRequests_approve), findsNothing);

      await tester.tap(find.byKey(const ValueKey('delete-review-approve')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-review-confirm')));
      await tester.pumpAndSettle();

      final request = await DeleteRequestsDao(db).getById('r1');
      expect(request!.status, 'approved');

      await unmountApp(tester);
    });

    testWidgets('rejecting keeps the record and records the note', (
      tester,
    ) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.owner);
      await seedRequest(id: 'r1');

      await pumpAuthScreen(
        tester,
        const DeleteRequestReviewScreen(requestId: 'r1'),
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('delete-review-note')),
        'Still needed for the appeal.',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('delete-review-reject')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-review-confirm')));
      await tester.pumpAndSettle();

      final request = await DeleteRequestsDao(db).getById('r1');
      expect(request!.status, 'rejected');
      expect(request.reviewNote, 'Still needed for the appeal.');
      expect(request.reviewedBy, 'user-1');

      final queue = (await SyncQueueDao(db).getByEntity('delete_request', 'r1'))
          .where((row) => row.state != 'resolved')
          .toList(growable: false);
      final payload = jsonDecode(queue.single.payload) as Map<String, dynamic>;
      expect(payload['status'], 'rejected');
      expect(payload['review_note'], 'Still needed for the appeal.');

      await unmountApp(tester);
    });
  });

  group("The requester's list", () {
    testWidgets('reads the decision, and opening it clears the badge', (
      tester,
    ) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.associate);
      await seedMembership(canDelete: false);
      await seedRequest(
        id: 'r1',
        requestedBy: 'user-1',
        title: 'Land Dispute Note',
        status: 'approved',
        updatedAt: 5000,
        reviewedBy: 'user-1',
      );

      await pumpAuthScreen(
        tester,
        const DeleteRequestsScreen(),
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text('Land Dispute Note'), findsOneWidget);
      expect(find.text(l.deleteRequests_statusApproved), findsOneWidget);

      // The post-frame callback has run, so the decision is now read.
      await tester.pumpAndSettle();
      expect(harness.prefs.getInt(deleteRequestsSeenKey('user-1')), 5000);

      await unmountApp(tester);
    });
  });
}
