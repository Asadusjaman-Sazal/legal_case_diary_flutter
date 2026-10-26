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
///    badge that announced it clears once the screen has been opened;
///  * the requester's own writers (Phase 3 item 3) — a pending row offers edit
///    and withdraw and a decided one offers neither, an edit re-takes the
///    snapshot from the record as it stands on this device, and a withdrawal is
///    confirmed before it writes.
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

import 'package:legal_case_diary/core/constants/app_colors.dart';
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
import 'package:legal_case_diary/features/notes/data/local/notes_dao.dart';
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
    Map<String, dynamic>? snapshot,
  }) async {
    await DeleteRequestsDao(db).insert(
      DeleteRequestsCompanion(
        id: Value(id),
        firmId: const Value('firm-1'),
        entityType: Value(entityType),
        entityId: Value(entityId),
        entitySnapshot: Value(
          jsonEncode(snapshot ?? {'id': entityId, 'title': title}),
        ),
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

  group('The record a review shows', () {
    /// The snapshot a real case request carries.
    const caseSnapshot = <String, dynamic>{
      'case_type': 'Civil Appeal-',
      'case_number': '345/25',
      'petitioner': 'Alice',
      'respondent': 'Bob',
    };

    /// A case request, raised by the colleague whose name the screen prints.
    Future<void> seedCaseRequest() async {
      // The requester's own cached profile: the name on the screen comes from
      // it, never from the network.
      await ProfilesDao(db).upsert(
        ProfilesCompanion(
          id: const Value('user-2'),
          fullName: const Value('Jannatul Ferdousi Rekha'),
          role: const Value('associate'),
          firmId: const Value('firm-1'),
          subscriptionStatus: const Value('premium'),
          createdAt: const Value(1),
        ),
      );
      await seedRequest(
        id: 'r1',
        entityType: 'case',
        entityId: 'case-1',
        requestedBy: 'user-2',
        snapshot: caseSnapshot,
      );
    }

    testWidgets('a case reads as its type and number, with who asked and when', (
      tester,
    ) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.owner);
      await seedCaseRequest();

      await pumpAuthScreen(
        tester,
        const DeleteRequestReviewScreen(requestId: 'r1'),
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      // The type and the number are one reading under **Case Number**, the way
      // the app writes a case everywhere else, instead of a separate row.
      expect(find.text('Civil Appeal- 345/25'), findsOneWidget);
      expect(find.text(l.deleteRequests_fieldCaseType), findsNothing);
      // The parties keep their own rows in the same card.
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);

      // The card that headed this screen is gone: the entity chip it carried
      // is nowhere on the screen now.
      expect(find.text(l.deleteRequests_entityCase), findsNothing);
      expect(
        find.text(l.deleteRequests_requestedBy('Jannatul Ferdousi Rekha')),
        findsOneWidget,
      );

      // The other line carries the date **and** the clock, in the app's
      // `DD/MM/YYYY, hh:mm AM/PM` form rather than a bare date.
      final on = tester.widget<Text>(
        find.byKey(const ValueKey('delete-review-requested-on')),
      );
      expect(
        on.data,
        matches(
          RegExp(r'^Requested on: \d{2}/\d{2}/\d{4}, \d{2}:\d{2} (AM|PM)$'),
        ),
      );

      await unmountApp(tester);
    });

    testWidgets("the Reject button matches Approve's size, in white ink", (
      tester,
    ) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.owner);
      await seedCaseRequest();

      await pumpAuthScreen(
        tester,
        const DeleteRequestReviewScreen(requestId: 'r1'),
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      final approve = find.byKey(const ValueKey('delete-review-approve'));
      final reject = find.byKey(const ValueKey('delete-review-reject'));
      expect(tester.getSize(reject), tester.getSize(approve));
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(of: reject, matching: find.byType(FilledButton)),
            )
            .style
            ?.foregroundColor
            ?.resolve(<WidgetState>{}),
        AppColors.onPrimary,
      );

      await unmountApp(tester);
    });

    testWidgets('a case in the queue reads as its type and number', (
      tester,
    ) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.owner);
      await seedCaseRequest();

      await pumpAuthScreen(
        tester,
        const DeleteRequestsScreen(),
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      // The list row is read before the request is opened, so it carries the
      // same reading the record does.
      expect(find.text('Civil Appeal- 345/25'), findsOneWidget);

      await unmountApp(tester);
    });

    testWidgets('the note box offers a cross that closes the keyboard', (
      tester,
    ) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.owner);
      await seedCaseRequest();

      await pumpAuthScreen(
        tester,
        const DeleteRequestReviewScreen(requestId: 'r1'),
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      final note = find.byKey(const ValueKey('delete-review-note'));
      final cross = find.byKey(const ValueKey('delete-review-note-close'));
      // Nothing to close while the box is resting.
      expect(cross, findsNothing);

      await tester.tap(note);
      await tester.pumpAndSettle();
      expect(cross, findsOneWidget);

      await tester.enterText(note, 'Still needed for the appeal.');
      await tester.pumpAndSettle();
      await tester.tap(cross);
      await tester.pumpAndSettle();

      // The cross takes the keyboard away and leaves the note alone: the words
      // the reviewer typed are the review's own content, not a query string.
      expect(cross, findsNothing);
      expect(tester.widget<TextField>(note).focusNode!.hasFocus, isFalse);
      expect(
        tester.widget<TextField>(note).controller!.text,
        'Still needed for the appeal.',
      );

      await unmountApp(tester);
    });
  });

  group("The requester's list", () {
    testWidgets('a pending request offers edit and withdraw', (tester) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.associate);
      await seedMembership(canDelete: false);
      await seedRequest(
        id: 'r1',
        requestedBy: 'user-1',
        title: 'Land Dispute Note',
      );

      await pumpAuthScreen(
        tester,
        const DeleteRequestsScreen(),
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.byKey(const ValueKey('delete-request-row-r1')));
      await tester.pumpAndSettle();

      expect(find.text(l.deleteRequests_edit), findsOneWidget);
      expect(find.text(l.deleteRequests_withdraw), findsOneWidget);

      await unmountApp(tester);
    });

    testWidgets('a decided request offers neither action', (tester) async {
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
        reviewedBy: 'user-3',
      );

      await pumpAuthScreen(
        tester,
        const DeleteRequestsScreen(),
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      // Nothing to tap into: the row is audit history, so it is not even a
      // gesture target (the row's key belongs to the tappable form).
      expect(find.byKey(const ValueKey('delete-request-row-r1')), findsNothing);
      await tester.tap(find.text('Land Dispute Note'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('delete-request-action-edit')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('delete-request-action-withdraw')),
        findsNothing,
      );

      await unmountApp(tester);
    });

    testWidgets('editing re-takes the snapshot from the record', (tester) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.associate);
      await seedMembership(canDelete: false);
      // The record as it stands now: renamed and one version further on than the
      // snapshot the request was raised with.
      await NotesDao(db).insert(
        NotesCompanion(
          id: const Value('note-1'),
          userId: const Value('user-1'),
          firmId: const Value('firm-1'),
          title: const Value('Renamed Note'),
          body: const Value('Body'),
          createdAt: const Value(1000),
          updatedAt: const Value(1500),
          version: const Value(7),
          lastModifiedBy: const Value('user-1'),
        ),
      );
      await seedRequest(
        id: 'r1',
        requestedBy: 'user-1',
        entityType: 'note',
        entityId: 'note-1',
        title: 'Old Title',
      );

      await pumpAuthScreen(
        tester,
        const DeleteRequestsScreen(),
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('delete-request-row-r1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-request-action-edit')));
      await tester.pumpAndSettle();

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l.deleteRequests_updated), findsOneWidget);

      final request = await DeleteRequestsDao(db).getById('r1');
      final snapshot =
          jsonDecode(request!.entitySnapshot) as Map<String, dynamic>;
      expect(snapshot['title'], 'Renamed Note');
      expect(request.targetBaseVersion, 7);
      // Still the requester's own pending request — an edit refreshes it, it
      // does not decide it.
      expect(request.status, 'pending');

      final queue = (await SyncQueueDao(db).getByEntity('delete_request', 'r1'))
          .where((row) => row.state != 'resolved')
          .toList(growable: false);
      expect(queue, hasLength(1));
      expect(queue.single.operation, 'update');
      expect(
        jsonDecode(queue.single.changedFields),
        containsAll(<String>[
          'entity_snapshot',
          'target_base_version',
          'updated_at',
        ]),
      );

      await unmountApp(tester);
    });

    testWidgets('withdrawing cancels the request once confirmed', (tester) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.associate);
      await seedMembership(canDelete: false);
      await seedRequest(id: 'r1', requestedBy: 'user-1');

      await pumpAuthScreen(
        tester,
        const DeleteRequestsScreen(),
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('delete-request-row-r1')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('delete-request-action-withdraw')),
      );
      await tester.pumpAndSettle();

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      // Confirmed before it writes: the sheet's tap only opens the window.
      expect(find.text(l.deleteRequests_withdrawTitle), findsOneWidget);
      expect(await DeleteRequestsDao(db).getById('r1'), isNotNull);

      await tester.tap(
        find.byKey(const ValueKey('delete-request-withdraw-confirm')),
      );
      await tester.pumpAndSettle();

      expect(find.text(l.deleteRequests_withdrawn), findsOneWidget);
      // Soft-deleted, never hard-deleted (the row is audit history), and gone
      // from the requester's own list.
      expect(await DeleteRequestsDao(db).getById('r1'), isNull);
      expect(find.byKey(const ValueKey('delete-request-row-r1')), findsNothing);

      final queue = (await SyncQueueDao(db).getByEntity('delete_request', 'r1'))
          .where((row) => row.state != 'resolved')
          .toList(growable: false);
      expect(queue, hasLength(1));
      expect(queue.single.operation, 'delete');
      final payload = jsonDecode(queue.single.payload) as Map<String, dynamic>;
      expect(payload['is_deleted'], isTrue);

      await unmountApp(tester);
    });

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
