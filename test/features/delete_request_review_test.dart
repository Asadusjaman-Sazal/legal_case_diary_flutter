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
///  * the requester's own writer — a pending row expands on tap to one red
///    **Withdraw Request** button (no chevron, no edit), and the withdrawal is
///    confirmed before it writes;
///  * the reviewer's quick path — a long press expands a pending card to the
///    review screen's **Approve** and **Reject** pair, in one line.
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
import 'package:legal_case_diary/core/constants/app_spacing.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/core/utils/date_utils.dart';
import 'package:legal_case_diary/core/theme/app_theme.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/firm_members_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/profiles_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_repository.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_viewmodel.dart';
import 'package:legal_case_diary/features/notes/data/local/notes_dao.dart';
import 'package:legal_case_diary/features/settings/presentation/delete_request_flow.dart';
import 'package:legal_case_diary/features/settings/presentation/delete_request_review_screen.dart';
import 'package:legal_case_diary/features/settings/presentation/delete_requests_screen.dart';
import 'package:legal_case_diary/features/settings/presentation/delete_requests_viewmodel.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_menu_card.dart'
    show settingsPrimaryButtonHeight;
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

/// Host for the pre-edit warning: one button that asks the question and hands
/// back the answer.
class _EditWarningHost extends ConsumerWidget {
  const _EditWarningHost({required this.onAnswer});

  final void Function(bool) onAnswer;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: ElevatedButton(
        key: const ValueKey('run-edit'),
        onPressed: () async {
          final answer = await confirmEditOfRequestedRecord(
            context,
            ref,
            entityType: 'note',
            entityId: 'note-1',
          );
          onAnswer(answer);
        },
        child: const Text('Run Edit'),
      ),
    ),
  );
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
  Future<void> seedProfile({String? firmId, String role = 'individual'}) =>
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
    String? requesterName,
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
        requesterName: Value(requesterName),
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
      // Answered by someone else deleting the record: also decided, not work.
      await seedRequest(id: 'r4', status: 'already_deleted');

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

    testWidgets(
      'the owner sees finished requests under Previous Delete Requests',
      (tester) async {
        final overrides = await openScope();
        db = harness.db;
        await seedProfile(firmId: 'firm-1', role: AccountRole.owner);
        await seedRequest(id: 'r1', title: 'Land Dispute Note');
        // Decided, newest first by the decision time.
        await seedRequest(
          id: 'r2',
          title: 'Old Approved Note',
          status: 'approved',
          updatedAt: 5000,
          reviewedBy: 'user-1',
        );
        await seedRequest(
          id: 'r3',
          title: 'Old Rejected Note',
          status: 'rejected',
          updatedAt: 4000,
          reviewedBy: 'user-1',
        );

        await pumpWithRouter(tester, const DeleteRequestsScreen(), overrides);

        final l = await AppLocalizations.delegate.load(const Locale('en'));
        // The queue still holds only the request awaiting review.
        expect(find.text(l.deleteRequests_toReview), findsOneWidget);
        expect(find.text('Land Dispute Note'), findsOneWidget);
        // The finished ones sit under their own heading, newest decision first,
        // with their outcome and no way to act on them.
        expect(find.text(l.deleteRequests_previous), findsOneWidget);
        expect(find.text('Old Approved Note'), findsOneWidget);
        expect(find.text('Old Rejected Note'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Old Approved Note')).dy,
          lessThan(tester.getTopLeft(find.text('Old Rejected Note')).dy),
        );
        expect(find.text(l.deleteRequests_statusApproved), findsOneWidget);
        expect(find.text(l.deleteRequests_statusRejected), findsOneWidget);
        // The owner's awaiting-review card carries the same date-and-time line
        // as the finished cards (user request, 0.0.721): three cards here.
        expect(
          find.text(AppDateUtils.formatDateTimeDDMMYYYY(1000, locale: 'en')),
          findsNWidgets(3),
        );
        expect(
          find.byKey(const ValueKey('delete-request-approve-r2')),
          findsNothing,
        );

        await unmountApp(tester);
      },
    );

    testWidgets('a member with delete permission keeps the queue alone', (
      tester,
    ) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.associate);
      await seedMembership(canDelete: true);
      await seedRequest(id: 'r1', title: 'Land Dispute Note');
      await seedRequest(
        id: 'r2',
        title: 'Old Approved Note',
        status: 'approved',
        reviewedBy: 'user-1',
      );

      await pumpWithRouter(tester, const DeleteRequestsScreen(), overrides);

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l.deleteRequests_toReview), findsOneWidget);
      expect(find.text('Land Dispute Note'), findsOneWidget);
      // The history section and its date line are the owner's (user request).
      expect(find.text(l.deleteRequests_previous), findsNothing);
      expect(find.text('Old Approved Note'), findsNothing);
      expect(
        find.text(AppDateUtils.formatDateTimeDDMMYYYY(1000, locale: 'en')),
        findsNothing,
      );

      await unmountApp(tester);
    });

    testWidgets('a previous card dates the request and clears on screen only', (
      tester,
    ) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.owner);
      await seedRequest(
        id: 'r2',
        title: 'Old Approved Note',
        status: 'approved',
        reviewedBy: 'user-1',
      );

      await pumpWithRouter(tester, const DeleteRequestsScreen(), overrides);

      // The request's date and time is the card's third line, without a label
      // (user request, 0.0.718).
      expect(
        find.text(AppDateUtils.formatDateTimeDDMMYYYY(1000, locale: 'en')),
        findsOneWidget,
      );

      // A tap shows one Clear, shaped like the Withdraw Request button.
      await tester.tap(find.byKey(const ValueKey('delete-request-row-r2')));
      await tester.pumpAndSettle();
      final clear = tester.widget<FilledButton>(
        find.byKey(const ValueKey('delete-request-clear-r2')),
      );
      expect(
        clear.style?.backgroundColor?.resolve(<WidgetState>{}),
        AppColors.error,
      );
      expect(
        clear.style?.foregroundColor?.resolve(<WidgetState>{}),
        AppColors.onError,
      );
      await tester.tap(find.byKey(const ValueKey('delete-request-clear-r2')));
      await tester.pumpAndSettle();

      // Hidden from this screen only: the request itself is untouched.
      expect(find.text('Old Approved Note'), findsNothing);
      expect(await DeleteRequestsDao(db).getById('r2'), isNotNull);
      expect((await DeleteRequestsDao(db).getById('r2'))!.status, 'approved');

      await unmountApp(tester);
    });

    testWidgets('a long press clears several previous cards, only on screen', (
      tester,
    ) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.owner);
      await seedRequest(
        id: 'r2',
        title: 'Old Approved Note',
        status: 'approved',
        reviewedBy: 'user-1',
      );
      await seedRequest(
        id: 'r3',
        title: 'Old Rejected Note',
        status: 'rejected',
        reviewedBy: 'user-1',
      );

      await pumpWithRouter(tester, const DeleteRequestsScreen(), overrides);

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.longPress(
        find.byKey(const ValueKey('delete-request-row-r2')),
      );
      await tester.pumpAndSettle();
      // The long press starts the section's selection; the other card is ticked
      // by tapping it. The two actions sit side by side under the list, Cancel
      // on the left (user request, 0.0.719).
      final cancel = find.byKey(const ValueKey('delete-request-clear-cancel'));
      final clearSelected = find.byKey(
        const ValueKey('delete-request-clear-selected'),
      );
      expect(clearSelected, findsOneWidget);
      expect(cancel, findsOneWidget);
      expect(
        tester.getCenter(cancel).dy,
        closeTo(tester.getCenter(clearSelected).dy, 0.5),
      );
      expect(
        tester.getCenter(cancel).dx,
        lessThan(tester.getCenter(clearSelected).dx),
      );
      expect(
        find.descendant(of: find.byType(ListView), matching: cancel),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('delete-request-row-r3')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('delete-request-clear-selected')),
      );
      await tester.pumpAndSettle();

      // Both left the screen, and the section with them; the requests and the
      // records are untouched.
      expect(find.text('Old Approved Note'), findsNothing);
      expect(find.text('Old Rejected Note'), findsNothing);
      expect(find.text(l.deleteRequests_previous), findsNothing);
      expect((await DeleteRequestsDao(db).getById('r2'))!.status, 'approved');
      expect((await DeleteRequestsDao(db).getById('r3'))!.status, 'rejected');

      await unmountApp(tester);
    });

    testWidgets('the bulk actions stay pinned while the list scrolls', (
      tester,
    ) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.owner);
      // Enough finished requests for the list to scroll.
      for (var i = 2; i <= 11; i++) {
        await seedRequest(
          id: 'r$i',
          title: 'Old Note $i',
          status: 'approved',
          updatedAt: 1000 + i,
          reviewedBy: 'user-1',
        );
      }

      await pumpWithRouter(tester, const DeleteRequestsScreen(), overrides);

      // The newest decision (r11) is the first card, so it is on screen.
      await tester.longPress(
        find.byKey(const ValueKey('delete-request-row-r11')),
      );
      await tester.pumpAndSettle();
      final cancel = find.byKey(const ValueKey('delete-request-clear-cancel'));
      final clearSelected = find.byKey(
        const ValueKey('delete-request-clear-selected'),
      );
      final barTop = tester.getTopLeft(cancel).dy;

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(cancel).dy, closeTo(barTop, 0.5));
      expect(clearSelected, findsOneWidget);

      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('delete-request-clear-selected')),
        findsNothing,
      );

      await unmountApp(tester);
    });

    testWidgets('un-ticking the last card ends the bulk clear', (tester) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.owner);
      await seedRequest(
        id: 'r2',
        title: 'Old Approved Note',
        status: 'approved',
        reviewedBy: 'user-1',
      );
      await seedRequest(
        id: 'r3',
        title: 'Old Rejected Note',
        status: 'rejected',
        reviewedBy: 'user-1',
      );

      await pumpWithRouter(tester, const DeleteRequestsScreen(), overrides);

      final bar = find.byKey(const ValueKey('delete-request-clear-selected'));
      await tester.longPress(
        find.byKey(const ValueKey('delete-request-row-r2')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-request-row-r3')));
      await tester.pumpAndSettle();

      // One un-tick leaves the other selected: the bar stays.
      await tester.tap(find.byKey(const ValueKey('delete-request-row-r3')));
      await tester.pumpAndSettle();
      expect(bar, findsOneWidget);

      // Un-ticking the last selected card leaves multi-select by itself.
      await tester.tap(find.byKey(const ValueKey('delete-request-row-r2')));
      await tester.pumpAndSettle();
      expect(bar, findsNothing);
      expect(
        find.byKey(const ValueKey('delete-request-clear-cancel')),
        findsNothing,
      );
      // Nothing was hidden.
      expect(find.text('Old Approved Note'), findsOneWidget);
      expect(find.text('Old Rejected Note'), findsOneWidget);

      await unmountApp(tester);
    });

    testWidgets('cancelling the bulk clear hides nothing', (tester) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.owner);
      await seedRequest(
        id: 'r2',
        title: 'Old Approved Note',
        status: 'approved',
        reviewedBy: 'user-1',
      );

      await pumpWithRouter(tester, const DeleteRequestsScreen(), overrides);

      await tester.longPress(
        find.byKey(const ValueKey('delete-request-row-r2')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('delete-request-clear-cancel')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Old Approved Note'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('delete-request-clear-selected')),
        findsNothing,
      );

      await unmountApp(tester);
    });
    testWidgets('long pressing a queued row offers quick Approve and Reject', (
      tester,
    ) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.owner);
      await seedRequest(id: 'r1', title: 'Land Dispute Note');

      await pumpWithRouter(tester, const DeleteRequestsScreen(), overrides);
      final l = await AppLocalizations.delegate.load(const Locale('en'));

      expect(
        find.byKey(const ValueKey('delete-request-approve-r1')),
        findsNothing,
      );
      await tester.longPress(
        find.byKey(const ValueKey('delete-request-row-r1')),
      );
      await tester.pumpAndSettle();

      final approve = find.byKey(const ValueKey('delete-request-approve-r1'));
      final reject = find.byKey(const ValueKey('delete-request-reject-r1'));
      expect(approve, findsOneWidget);
      expect(reject, findsOneWidget);
      expect(find.text(l.deleteRequests_approve), findsOneWidget);
      expect(find.text(l.deleteRequests_reject), findsOneWidget);
      // One line: the pair shares a row, Approve first.
      expect(
        tester.getCenter(approve).dy,
        closeTo(tester.getCenter(reject).dy, 1),
      );
      expect(
        tester.getCenter(approve).dx,
        lessThan(tester.getCenter(reject).dx),
      );

      await unmountApp(tester);
    });

    testWidgets('a quick approval decides the request from the list', (
      tester,
    ) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.owner);
      await seedRequest(id: 'r1', title: 'Land Dispute Note');

      await pumpWithRouter(tester, const DeleteRequestsScreen(), overrides);
      final l = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.longPress(
        find.byKey(const ValueKey('delete-request-row-r1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-request-approve-r1')));
      await tester.pumpAndSettle();
      // The review screen's own confirmation, because approving deletes.
      expect(find.text(l.deleteRequests_approveTitle), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('delete-request-quick-confirm')),
      );
      await tester.pumpAndSettle();

      final request = await DeleteRequestsDao(db).getById('r1');
      expect(request!.status, 'approved');
      expect(request.reviewedBy, 'user-1');
      // Decided in place: the review screen was never opened, the row left the
      // queue and moved into the owner's history with its outcome.
      expect(find.text(l.deleteRequests_reviewTitle), findsNothing);
      // The row is no longer a queue row: it moved into the history without a
      // quick action of its own.
      expect(
        find.byKey(const ValueKey('delete-request-approve-r1')),
        findsNothing,
      );
      expect(find.text(l.deleteRequests_previous), findsOneWidget);
      expect(find.text('Land Dispute Note'), findsOneWidget);
      expect(find.text(l.deleteRequests_statusApproved), findsOneWidget);
      expect(find.text(l.deleteRequests_approved), findsOneWidget);

      await unmountApp(tester);
    });

    testWidgets('a quick rejection keeps the record, in the Exit App window', (
      tester,
    ) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.owner);
      await seedRequest(id: 'r1', title: 'Land Dispute Note');

      await pumpWithRouter(tester, const DeleteRequestsScreen(), overrides);
      final l = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.longPress(
        find.byKey(const ValueKey('delete-request-row-r1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-request-reject-r1')));
      await tester.pumpAndSettle();

      // The same Exit App corner and action size the review screen's Reject
      // window takes (user request).
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      final corner = (dialog.shape! as RoundedRectangleBorder).borderRadius;
      expect((corner as BorderRadius).topLeft.x, AppSpacing.cardRadius * 2);
      const actionSize = Size(112, 48);
      final cancel = tester.widget<TextButton>(
        find.widgetWithText(TextButton, l.sharedActions_cancel),
      );
      expect(cancel.style?.minimumSize?.resolve(<WidgetState>{}), actionSize);
      final confirm = tester.widget<FilledButton>(
        find.byKey(const ValueKey('delete-request-quick-confirm')),
      );
      expect(confirm.style?.minimumSize?.resolve(<WidgetState>{}), actionSize);
      expect(confirm.style?.textStyle?.resolve(<WidgetState>{})?.fontSize, 16);

      await tester.tap(
        find.byKey(const ValueKey('delete-request-quick-confirm')),
      );
      await tester.pumpAndSettle();

      final request = await DeleteRequestsDao(db).getById('r1');
      expect(request!.status, 'rejected');
      expect(find.text(l.deleteRequests_reviewTitle), findsNothing);
      expect(find.text(l.deleteRequests_rejected), findsOneWidget);

      await unmountApp(tester);
    });

    testWidgets('a stale row keeps the review screen, with no quick actions', (
      tester,
    ) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.owner);
      await seedRequest(id: 'r1', status: 'stale_review_required');

      await pumpWithRouter(tester, const DeleteRequestsScreen(), overrides);

      await tester.longPress(
        find.byKey(const ValueKey('delete-request-row-r1')),
      );
      await tester.pumpAndSettle();

      // Its record moved, so approving it blindly would judge a version nobody
      // has seen; the trip to the review screen stays.
      expect(
        find.byKey(const ValueKey('delete-request-approve-r1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('delete-request-reject-r1')),
        findsNothing,
      );

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

      final queue = (await SyncQueueDao(db).getByEntity(
        'delete_request',
        'r1',
      )).where((row) => row.state != 'resolved').toList(growable: false);
      expect(queue, hasLength(1));
      expect(queue.single.operation, 'update');
      expect(queue.single.baseVersion, 4);
      final payload = jsonDecode(queue.single.payload) as Map<String, dynamic>;
      expect(payload['status'], 'approved');

      await unmountApp(tester);
    });

    testWidgets('a stale review is approved in one tap, not re-created', (
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
      // The screen says what changed and offers the one approval it now
      // performs against the record as it is (user request, 0.0.727).
      expect(find.text(l.deleteRequests_approve), findsOneWidget);
      expect(find.text('Reconfirm'), findsNothing);

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

      // The Reject window takes the Exit App window's corner and action size
      // (user request); Approve keeps its own.
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      final corner = (dialog.shape! as RoundedRectangleBorder).borderRadius;
      expect((corner as BorderRadius).topLeft.x, AppSpacing.cardRadius * 2);
      const actionSize = Size(112, 48);
      final cancel = tester.widget<TextButton>(
        find.widgetWithText(TextButton, l.sharedActions_cancel),
      );
      expect(cancel.style?.minimumSize?.resolve(<WidgetState>{}), actionSize);
      expect(cancel.style?.textStyle?.resolve(<WidgetState>{})?.fontSize, 16);
      final confirm = tester.widget<FilledButton>(
        find.byKey(const ValueKey('delete-review-confirm')),
      );
      expect(confirm.style?.minimumSize?.resolve(<WidgetState>{}), actionSize);
      expect(confirm.style?.textStyle?.resolve(<WidgetState>{})?.fontSize, 16);
      expect(
        confirm.style?.backgroundColor?.resolve(<WidgetState>{}),
        AppColors.error,
      );

      await tester.tap(find.byKey(const ValueKey('delete-review-confirm')));
      await tester.pumpAndSettle();

      final request = await DeleteRequestsDao(db).getById('r1');
      expect(request!.status, 'rejected');
      expect(request.reviewNote, 'Still needed for the appeal.');
      expect(request.reviewedBy, 'user-1');

      final queue = (await SyncQueueDao(db).getByEntity(
        'delete_request',
        'r1',
      )).where((row) => row.state != 'resolved').toList(growable: false);
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
    ///
    /// [requesterName] is the name the request itself carries; the profile row
    /// below is the **fallback** the screen used before the column existed, so
    /// leaving the argument null is how the fallback stays pinned.
    Future<void> seedCaseRequest({String? requesterName}) async {
      // The requester's cached profile, when the device happens to hold one:
      // read locally, never fetched.
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
        requesterName: requesterName,
        snapshot: caseSnapshot,
      );
    }

    testWidgets('a changed record shows what exists now above what was seen', (
      tester,
    ) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.owner);
      // The record as it exists now: renamed and a version further on.
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
          lastModifiedBy: const Value('user-2'),
        ),
      );
      await seedRequest(
        id: 'r1',
        requestedBy: 'user-2',
        requesterName: 'Jannatul Ferdousi Rekha',
        entityType: 'note',
        entityId: 'note-1',
        title: 'Old Title',
        status: 'stale_review_required',
      );

      await pumpAuthScreen(
        tester,
        const DeleteRequestReviewScreen(requestId: 'r1'),
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      // Two cards, in that order: what is there now, then the copy the
      // requester saw — so Reconfirm is a decision about the current record.
      expect(find.text(l.deleteRequests_current), findsOneWidget);
      expect(find.text(l.deleteRequests_original), findsOneWidget);
      expect(find.text('Renamed Note'), findsOneWidget);
      expect(find.text('Old Title'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(l.deleteRequests_current)).dy,
        lessThan(tester.getTopLeft(find.text(l.deleteRequests_original)).dy),
      );

      await unmountApp(tester);
    });

    testWidgets('a record changed before review shows at the first open', (
      tester,
    ) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.owner);
      // The record moved on after the request: version 7 against the version 2
      // the request recorded, still pending (no approval attempted yet).
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
          lastModifiedBy: const Value('user-2'),
        ),
      );
      await seedRequest(
        id: 'r1',
        requestedBy: 'user-2',
        requesterName: 'Jannatul Ferdousi Rekha',
        entityType: 'note',
        entityId: 'note-1',
        title: 'Old Title',
      );

      await pumpAuthScreen(
        tester,
        const DeleteRequestReviewScreen(requestId: 'r1'),
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      // The warning and the current record are on screen before any approval
      // (user request, 0.0.726), and the action already reads Reconfirm.
      expect(
        find.text(
          '${l.deleteRequests_staleTitle}. ${l.deleteRequests_staleBody}',
        ),
        findsOneWidget,
      );
      expect(find.text(l.deleteRequests_current), findsOneWidget);
      expect(find.text('Renamed Note'), findsOneWidget);
      expect(find.text(l.deleteRequests_approve), findsOneWidget);
      expect(find.text('Reconfirm'), findsNothing);

      // The approval is honest in one tap: the request adopts the record's
      // current version before the approval is written, so the server does not
      // have to park it (user request, 0.0.726). The two cards push the action
      // below the fold on the test surface, so it is scrolled into view.
      await tester.ensureVisible(
        find.byKey(const ValueKey('delete-review-approve')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-review-approve')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-review-confirm')));
      await tester.pumpAndSettle();

      final row = await DeleteRequestsDao(db).getById('r1');
      expect(row!.status, 'approved');
      expect(row.targetBaseVersion, 7);

      await unmountApp(tester);
    });

    testWidgets('a record unchanged at review keeps the plain approval', (
      tester,
    ) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.owner);
      // The record is at the version the request recorded.
      await NotesDao(db).insert(
        NotesCompanion(
          id: const Value('note-1'),
          userId: const Value('user-1'),
          firmId: const Value('firm-1'),
          title: const Value('Land Dispute Note'),
          body: const Value('Body'),
          createdAt: const Value(1000),
          updatedAt: const Value(1500),
          version: const Value(2),
          lastModifiedBy: const Value('user-2'),
        ),
      );
      await seedRequest(
        id: 'r1',
        requestedBy: 'user-2',
        entityType: 'note',
        entityId: 'note-1',
        title: 'Land Dispute Note',
      );

      await pumpAuthScreen(
        tester,
        const DeleteRequestReviewScreen(requestId: 'r1'),
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l.deleteRequests_staleTitle), findsNothing);
      expect(find.text(l.deleteRequests_current), findsNothing);
      expect(find.text(l.deleteRequests_approve), findsOneWidget);
      expect(find.text('Reconfirm'), findsNothing);

      await unmountApp(tester);
    });

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

    testWidgets('a case card lists the phone, record details, step and note', (
      tester,
    ) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.owner);
      final nextDate = AppDateUtils.bangladeshTodayStartOfDay() + 5 * 86400000;
      await seedRequest(
        id: 'r1',
        entityType: 'case',
        entityId: 'case-1',
        requestedBy: 'user-2',
        requesterName: 'Jannatul Ferdousi Rekha',
        snapshot: <String, dynamic>{
          'case_type': 'Civil Appeal-',
          'case_number': '345/25',
          'petitioner': 'Alice',
          'respondent': 'Bob',
          'on_behalf_id': 'onbehalf-test-respondent',
          'party_phone': '+8801711000000',
          'case_title_and_section': 'Partition Suit (Section 4)',
          'case_remarks': 'Dispute over ancestral property.',
          'next_date': nextDate,
          'last_step': 'Filing',
          'notes_results': 'Need to call the client.',
        },
      );

      await pumpAuthScreen(
        tester,
        const DeleteRequestReviewScreen(requestId: 'r1'),
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      // The client's number sits under the party the case is pleaded for
      // (user request, 0.0.729).
      expect(find.text(l.deleteRequests_fieldRespondentPhone), findsOneWidget);
      expect(find.text('+8801711000000'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(l.deleteRequests_fieldRespondentPhone)).dy,
        greaterThan(
          tester.getTopLeft(find.text(l.deleteRequests_fieldRespondent)).dy,
        ),
      );
      expect(find.text(l.deleteRequests_fieldPetitionerPhone), findsNothing);
      // The rest of the case record.
      expect(find.text(l.addEditCaseSheet_caseTitleAndSection), findsOneWidget);
      expect(find.text('Partition Suit (Section 4)'), findsOneWidget);
      expect(find.text(l.addEditCaseSheet_caseRemarks), findsOneWidget);
      expect(find.text('Dispute over ancestral property.'), findsOneWidget);
      expect(find.text(l.addEditCaseSheet_nextDate), findsOneWidget);
      expect(
        find.text(
          AppDateUtils.formatDisplayDate(
            nextDate,
            todayLabel: l.dailyCauseListScreen_today,
            tomorrowLabel: l.dailyCauseListScreen_tomorrow,
            locale: l.localeName,
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(l.addEditCaseSheet_step), findsOneWidget);
      expect(find.text('Filing'), findsOneWidget);
      expect(find.text(l.addEditCaseSheet_note), findsOneWidget);
      expect(find.text('Need to call the client.'), findsOneWidget);

      await unmountApp(tester);
    });

    testWidgets(
      'the name on the request reads right with no profile cached here',
      (tester) async {
        final overrides = await openScope();
        db = harness.db;
        await seedProfile(firmId: 'firm-1', role: AccountRole.owner);
        // Deliberately **no** profile row for the requester: this is a reviewer
        // whose device has never held the colleague's profile, which is exactly
        // the case the old lookup turned into a neutral label.
        await seedCaseRequest(requesterName: 'Jannatul Ferdousi Rekha');

        await pumpAuthScreen(
          tester,
          const DeleteRequestReviewScreen(requestId: 'r1'),
          overrides: overrides,
        );
        await tester.pumpAndSettle();

        final l = await AppLocalizations.delegate.load(const Locale('en'));
        expect(
          find.text(l.deleteRequests_requestedBy('Jannatul Ferdousi Rekha')),
          findsOneWidget,
        );
        expect(
          find.text(
            l.deleteRequests_requestedBy(l.deleteRequests_unknownRequester),
          ),
          findsNothing,
          reason: 'the request carries who asked, so nothing is guessed',
        );

        await unmountApp(tester);
      },
    );

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
      // The request carries the name and **no** colleague profile is seeded, so
      // only the request's own name can fill the row — the cache lookup this
      // screen used before cannot satisfy it.
      await seedRequest(
        id: 'r1',
        entityType: 'case',
        entityId: 'case-1',
        requestedBy: 'user-2',
        requesterName: 'Jannatul Ferdousi Rekha',
        snapshot: caseSnapshot,
      );

      await pumpAuthScreen(
        tester,
        const DeleteRequestsScreen(),
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      // The list row is read before the request is opened, so it carries the
      // same reading the record does.
      expect(find.text('Civil Appeal- 345/25'), findsOneWidget);
      // Its second line names who asked rather than dating the request (user
      // request): the reviewer's question is who wants this gone; the moment
      // it was raised is the third line below the name.
      expect(
        find.text(
          '${l.deleteRequests_entityCase} \u00b7 Jannatul Ferdousi Rekha',
        ),
        findsOneWidget,
      );
      // The owner also reads when it was raised, as a third line (0.0.721).
      expect(
        find.text(AppDateUtils.formatDateTimeDDMMYYYY(1000, locale: 'en')),
        findsOneWidget,
      );

      await unmountApp(tester);
    });

    testWidgets(
      'the note box offers a cross that clears it and closes the keyboard',
      (tester) async {
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

        // Its accessible name says what the tap does, and it is the wording the
        // user asked for.
        expect(find.byTooltip('Clear texts'), findsOneWidget);

        await tester.enterText(note, 'Still needed for the appeal.');
        await tester.pumpAndSettle();
        await tester.tap(cross);
        await tester.pumpAndSettle();

        // The cross empties the note and takes the keyboard away with it.
        expect(cross, findsNothing);
        expect(tester.widget<TextField>(note).focusNode!.hasFocus, isFalse);
        expect(tester.widget<TextField>(note).controller!.text, isEmpty);

        await unmountApp(tester);
      },
    );
  });

  group("The requester's list", () {
    testWidgets('a pending row expands to one red withdraw action', (
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
      );

      await pumpAuthScreen(
        tester,
        const DeleteRequestsScreen(),
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      // This list still dates its rows: the requester's own name would tell
      // them nothing, and the date is what orders the list (user request — the
      // name replaced the date in the reviewer's queue only).
      expect(
        find.textContaining(
          AppDateUtils.formatDateDDMMYYYY(1000, locale: 'en'),
        ),
        findsOneWidget,
      );
      // The card expands, so no chevron promises a screen (user request).
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      // Nothing shows until the card is opened.
      expect(
        find.byKey(const ValueKey('delete-request-withdraw-r1')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('delete-request-row-r1')));
      await tester.pumpAndSettle();

      // One action, right-aligned, in the app's red: Edit Request is gone.
      expect(find.text(l.deleteRequests_withdraw), findsOneWidget);
      expect(
        find.byKey(const ValueKey('delete-request-action-edit')),
        findsNothing,
      );
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('delete-request-withdraw-r1')),
      );
      expect(
        button.style?.backgroundColor?.resolve(<WidgetState>{}),
        AppColors.error,
      );
      expect(
        button.style?.foregroundColor?.resolve(<WidgetState>{}),
        AppColors.onError,
      );
      // Full length, at the reviewer's Approve height (user request): the same
      // minimum size `_QuickButton` sets, so the theme's compact density trims
      // both to the same box.
      expect(
        button.style?.minimumSize?.resolve(<WidgetState>{}),
        const Size.fromHeight(settingsPrimaryButtonHeight),
      );
      final size = tester.getSize(
        find.byKey(const ValueKey('delete-request-withdraw-r1')),
      );
      final cardWidth = tester
          .getSize(find.byKey(const ValueKey('delete-request-row-r1')))
          .width;
      expect(size.width, closeTo(cardWidth - AppSpacing.md * 2, 0.5));

      // A second tap closes it again.
      await tester.tap(find.byKey(const ValueKey('delete-request-row-r1')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('delete-request-withdraw-r1')),
        findsNothing,
      );

      await unmountApp(tester);
    });

    testWidgets('a decided request offers neither action nor a gesture', (
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
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(
        find.byKey(const ValueKey('delete-request-withdraw-r1')),
        findsNothing,
      );

      await unmountApp(tester);
    });

    testWidgets('a request answered by a deletion reads as already deleted', (
      tester,
    ) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.associate);
      await seedMembership(canDelete: false);
      await seedRequest(
        id: 'r1',
        requestedBy: 'user-1',
        status: 'already_deleted',
        updatedAt: 5000,
      );

      await pumpAuthScreen(
        tester,
        const DeleteRequestsScreen(),
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      // The requester does not keep waiting for a decision nobody can make: the
      // record is gone, so the request is closed and says why.
      expect(find.text(l.deleteRequests_statusAlreadyDeleted), findsOneWidget);
      expect(find.text(l.deleteRequests_statusPending), findsNothing);
      // A closed request has nothing to act on.
      expect(find.byKey(const ValueKey('delete-request-row-r1')), findsNothing);

      await unmountApp(tester);
    });

    testWidgets('the withdrawal buttons stack full length on a narrow screen', (
      tester,
    ) async {
      // A phone too narrow for both Exit App-sized buttons on one line: the
      // pair stacks, each filling the window (user request).
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
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
        find.byKey(const ValueKey('delete-request-withdraw-r1')),
      );
      await tester.pumpAndSettle();

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      final cancel = find.widgetWithText(TextButton, l.sharedActions_cancel);
      final confirm = find.byKey(
        const ValueKey('delete-request-withdraw-confirm'),
      );
      // One under the other...
      expect(
        tester.getTopLeft(confirm).dy,
        greaterThan(tester.getTopLeft(cancel).dy),
      );
      // ...and each at the full length of the window.
      expect(
        tester.getSize(confirm).width,
        closeTo(tester.getSize(cancel).width, 0.5),
      );
      expect(tester.getSize(confirm).width, greaterThan(150));

      await unmountApp(tester);
    });

    testWidgets('the requester is told when the record changed', (
      tester,
    ) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.associate);
      await seedMembership(canDelete: false);
      // The record moved on after the request was raised: version 7 against the
      // version 2 the request recorded.
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

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        find.byKey(const ValueKey('delete-request-changed')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('delete-request-row-r1')));
      await tester.pumpAndSettle();
      // The card opens on its one action; the changed label above already says
      // what the reviewer will see if it goes through.
      expect(find.text(l.deleteRequests_withdraw), findsOneWidget);

      await unmountApp(tester);
    });

    testWidgets('withdrawing cancels the request once confirmed', (
      tester,
    ) async {
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
        find.byKey(const ValueKey('delete-request-withdraw-r1')),
      );
      await tester.pumpAndSettle();

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      // Confirmed before it writes: the card's tap only opens the window.
      expect(find.text(l.deleteRequests_withdrawTitle), findsOneWidget);
      expect(await DeleteRequestsDao(db).getById('r1'), isNotNull);

      // The Exit App window's corner, title alignment and action size (user
      // request), with a justified body.
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      final corner = (dialog.shape! as RoundedRectangleBorder).borderRadius;
      expect((corner as BorderRadius).topLeft.x, AppSpacing.cardRadius * 2);
      // 5% wider: the default 40 px inset gives way to 32 (user request).
      expect(
        dialog.insetPadding,
        const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      );
      expect(
        tester
            .widget<Text>(find.text(l.deleteRequests_withdrawTitle))
            .textAlign,
        TextAlign.center,
      );
      expect(
        tester.widget<Text>(find.text(l.deleteRequests_withdrawBody)).textAlign,
        TextAlign.justify,
      );
      const actionSize = Size(112, 48);
      final cancel = tester.widget<TextButton>(
        find.widgetWithText(TextButton, l.sharedActions_cancel),
      );
      expect(cancel.style?.minimumSize?.resolve(<WidgetState>{}), actionSize);
      expect(cancel.style?.textStyle?.resolve(<WidgetState>{})?.fontSize, 16);
      final confirm = tester.widget<FilledButton>(
        find.byKey(const ValueKey('delete-request-withdraw-confirm')),
      );
      expect(confirm.style?.minimumSize?.resolve(<WidgetState>{}), actionSize);
      expect(confirm.style?.textStyle?.resolve(<WidgetState>{})?.fontSize, 16);
      // Red, as the destructive half of the pair.
      expect(
        confirm.style?.backgroundColor?.resolve(<WidgetState>{}),
        AppColors.error,
      );

      await tester.tap(
        find.byKey(const ValueKey('delete-request-withdraw-confirm')),
      );
      await tester.pumpAndSettle();

      expect(find.text(l.deleteRequests_withdrawn), findsOneWidget);
      // Soft-deleted, never hard-deleted (the row is audit history), and gone
      // from the requester's own list.
      expect(await DeleteRequestsDao(db).getById('r1'), isNull);
      expect(find.byKey(const ValueKey('delete-request-row-r1')), findsNothing);

      final queue = (await SyncQueueDao(db).getByEntity(
        'delete_request',
        'r1',
      )).where((row) => row.state != 'resolved').toList(growable: false);
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

  group('Editing a requested record', () {
    testWidgets('warns that someone else asked to delete it', (tester) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.associate);
      await seedMembership(canDelete: false);
      await seedRequest(
        id: 'r1',
        requestedBy: 'user-2',
        entityType: 'note',
        entityId: 'note-1',
        requesterName: 'Jannatul Ferdousi Rekha',
      );
      bool? answer;

      await pumpAuthScreen(
        tester,
        _EditWarningHost(onAnswer: (value) => answer = value),
        overrides: overrides,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('run-edit')));
      await tester.pumpAndSettle();

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l.deleteRequests_editWarnTitle), findsOneWidget);
      expect(find.textContaining('Jannatul Ferdousi Rekha'), findsOneWidget);

      await tester.tap(find.text(l.deleteRequests_editWarnContinue));
      await tester.pumpAndSettle();

      expect(answer, isTrue, reason: 'the edit continues once acknowledged');

      await unmountApp(tester);
    });

    testWidgets('backs out of the edit when the warning is declined', (
      tester,
    ) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.associate);
      await seedMembership(canDelete: false);
      await seedRequest(id: 'r1', requestedBy: 'user-2');
      bool? answer;

      await pumpAuthScreen(
        tester,
        _EditWarningHost(onAnswer: (value) => answer = value),
        overrides: overrides,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('run-edit')));
      await tester.pumpAndSettle();

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l.sharedActions_cancel));
      await tester.pumpAndSettle();

      expect(answer, isFalse);

      await unmountApp(tester);
    });

    testWidgets('warns the requester in their own words', (tester) async {
      final overrides = await openScope();
      db = harness.db;
      await seedProfile(firmId: 'firm-1', role: AccountRole.associate);
      await seedMembership(canDelete: false);
      await seedRequest(id: 'r1', requestedBy: 'user-1');
      bool? answer;

      await pumpAuthScreen(
        tester,
        _EditWarningHost(onAnswer: (value) => answer = value),
        overrides: overrides,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('run-edit')));
      await tester.pumpAndSettle();

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      // The requester is warned too, with the first-person sentence instead of
      // their own name (user request, 0.0.728).
      expect(find.text(l.deleteRequests_editWarnTitle), findsOneWidget);
      expect(
        find.textContaining('You asked to delete this record'),
        findsOneWidget,
      );

      await tester.tap(find.text(l.deleteRequests_editWarnContinue));
      await tester.pumpAndSettle();

      expect(answer, isTrue, reason: 'the edit continues once acknowledged');

      await unmountApp(tester);
    });
  });
}
