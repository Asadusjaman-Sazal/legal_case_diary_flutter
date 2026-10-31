/// Regression: one device, two accounts, no shared answers.
///
/// A session can end without the Logout button — the server revokes it, or it
/// expires, and the SDK reports that by itself. Everything that belonged to the
/// account then has to go with it, and two of those things are invisible to the
/// database wipe the branched logout runs:
///
/// * **The account-scoped live reads** (payment history, the admin panel's
///   status and its queue, an owner's firm roster and invite codes) are held in
///   memory by providers, so the previous account's rows stayed on screen for
///   whoever signed in next — a non-admin still saw the Admin Panel, and *Payment
///   History* was somebody else's ledger.
/// * **The SharedPreferences profile record** — the details and picture the
///   previous holder typed on this device.
///
/// The bug was reported as: A logs out, B logs in, B sees A's data, and only a
/// re-login clears it. These tests drive the same transition through the app's
/// own auth state machine, so the fix (drop both when the account changes) is
/// asserted through the real entry points rather than by calling it directly.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/firm_repository.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_name_store.dart';
import 'package:legal_case_diary/features/admin/data/admin_repository.dart';
import 'package:legal_case_diary/features/admin/presentation/admin_viewmodel.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_viewmodel.dart';
import 'package:legal_case_diary/features/payments/data/payment_repository.dart';
import 'package:legal_case_diary/sync/sync_providers.dart';
import 'package:legal_case_diary/sync/sync_status_providers.dart';

import 'auth_test_support.dart';

/// The account the fakes answer for; the test moves it as it switches accounts,
/// exactly as a real server would answer for whoever holds the session.
class _Account {
  /// Creates the account the fakes start out answering for.
  _Account(this.userId);

  /// The id every fake answers as.
  String userId;

  /// Whether the server has a session for [userId].
  ///
  /// False is what RLS does with no JWT: no rows, and `is_app_admin()` false.
  /// The fakes honour it so a test can tell `the cached answer was dropped`
  /// from `the cached answer was served again`.
  bool signedIn = true;
}

/// A payments repository whose history belongs to the current account.
class _FakePayments implements PaymentRepository {
  /// Creates the fake over [account].
  _FakePayments(this.account);

  /// Whose history it returns.
  final _Account account;

  /// How many times the history was read, so a test can prove a switch re-read
  /// it rather than serving the cached answer.
  int fetches = 0;

  @override
  Future<List<PaymentSubmission>> fetchMySubmissions() async {
    fetches++;
    if (!account.signedIn) return const <PaymentSubmission>[];
    return <PaymentSubmission>[
      PaymentSubmission(
        id: '${account.userId}-payment',
        planType: 'monthly',
        amount: 100,
        mfsProvider: 'bkash',
        senderNumber: '01700000000',
        transactionId: 'TRX-${account.userId}',
        status: 'approved',
      ),
    ];
  }

  @override
  Future<List<SubscriptionCancellation>> fetchMyCancellations() async =>
      const <SubscriptionCancellation>[];

  @override
  Future<void> cancelSubscription() async =>
      throw const PaymentCancelException(PaymentCancelFailure.network);

  @override
  Future<void> submit({
    required String userId,
    required String planType,
    required int amount,
    required String mfsProvider,
    required String senderNumber,
    required String transactionId,
  }) async {}
}

/// An admin repository where only `user-a` is an admin, and whose queue belongs
/// to the current account.
class _FakeAdmin implements AdminRepository {
  /// Creates the fake over [account].
  _FakeAdmin(this.account);

  /// Who the queue belongs to.
  final _Account account;

  /// How many times the status was asked, so a test can prove a switch asked
  /// again.
  int statusCalls = 0;

  @override
  Future<bool> isAdmin() async {
    statusCalls++;
    return account.signedIn && account.userId == 'user-a';
  }

  @override
  Future<List<AdminPaymentRequest>> listPaymentRequests() async =>
      <AdminPaymentRequest>[
        AdminPaymentRequest(
          id: '${account.userId}-payment',
          userId: account.userId,
          planKey: 'monthly',
          amount: 100,
          mfsProvider: 'bkash',
          senderNumber: '01700000000',
          transactionId: 'TRX-${account.userId}',
          status: 'pending',
          submittedAt: DateTime(2026, 1, 1),
        ),
      ];

  @override
  Future<AdminActionFailure?> approve(String submissionId) async => null;

  @override
  Future<AdminActionFailure?> reject(
    String submissionId, {
    String? note,
  }) async => null;

  /// One unconfirmed account per signed-in account, so a leak is visible here
  /// too — the panel's badge counts these alongside the pending payments.
  @override
  Future<List<AdminUnconfirmedAccount>> listUnconfirmedAccounts() async =>
      account.signedIn
      ? <AdminUnconfirmedAccount>[
          AdminUnconfirmedAccount(
            id: '${account.userId}-unconfirmed',
            email: '${account.userId}@example.test',
            fullName: '',
            createdAt: DateTime(2026, 1, 1),
          ),
        ]
      : const <AdminUnconfirmedAccount>[];

  @override
  Future<AdminActionFailure?> deleteUnconfirmedAccount(String userId) async =>
      null;

  @override
  Future<List<AdminSharedReference>> listSharedReferences() async =>
      const <AdminSharedReference>[];

  @override
  Future<AdminActionFailure?> saveSharedReference(
    AdminSharedReference reference,
  ) async => null;

  @override
  Future<AdminActionFailure?> deleteSharedReference(String id) async => null;
}

void main() {
  late AuthTestHarness harness;
  late _Account account;
  late _FakePayments payments;
  late _FakeAdmin admin;

  setUp(() {
    harness = AuthTestHarness();
    account = _Account('user-a');
    payments = _FakePayments(account);
    admin = _FakeAdmin(account);
  });

  tearDown(() async {
    await harness.auth.dispose();
    await harness.tearDown();
  });

  /// A container with the app's own auth state machine and these fakes.
  Future<ProviderContainer> container() async {
    final c = ProviderContainer(
      overrides: <Override>[
        ...await harness.setUp(),
        paymentRepositoryProvider.overrideWithValue(payments),
        adminRepositoryProvider.overrideWithValue(admin),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Signs in as [userId]; the fakes answer for them from then on.
  Future<void> signInAs(ProviderContainer c, String userId) async {
    account.userId = userId;
    account.signedIn = true;
    harness.auth.signInUserId = userId;
    await c
        .read(authViewModelProvider.notifier)
        .signIn(email: '$userId@law.com', password: 'secret');
  }

  /// Ends the session the way a revoked or expired one ends: the server says so
  /// and the SDK reports it, with no Logout button in sight.
  Future<void> sessionLost(ProviderContainer c) async {
    harness.auth.identity = null;
    account.signedIn = false;
    harness.auth.emit(const AuthSessionEvent(sessionExpired: true));
    await pumpEventQueue();
    expect(
      c.read(authViewModelProvider).value?.identity,
      isNull,
      reason: 'the session really ended',
    );
  }

  test(
    'a switch to another account drops the previous one\'s live reads',
    () async {
      harness.firm.members = const <FirmMemberSummary>[
        FirmMemberSummary(
          userId: 'user-a',
          role: 'owner',
          fullName: 'Adv. A',
          canAdd: true,
          canEdit: true,
          canDelete: true,
        ),
      ];
      harness.firm.invites = const <FirmInviteSummary>[
        FirmInviteSummary(id: 'invite-a', createdAt: 1),
      ];

      final c = await container();
      await signInAs(c, 'user-a');

      // What A sees: their own history, their own admin panel, their own roster.
      expect(
        (await c.read(myPaymentSubmissionsProvider.future)).single.id,
        'user-a-payment',
      );
      expect(await c.read(adminStatusProvider.future), isTrue);
      expect(
        (await c.read(adminPaymentRequestsProvider.future)).single.id,
        'user-a-payment',
      );
      expect(
        (await c.read(firmMembersListProvider.future)).single.userId,
        'user-a',
      );
      expect(
        (await c.read(firmInvitesListProvider.future)).single.id,
        'invite-a',
      );

      // A's session ends on its own, and B signs in on the same device.
      await sessionLost(c);
      harness.firm.members = const <FirmMemberSummary>[];
      harness.firm.invites = const <FirmInviteSummary>[];
      await signInAs(c, 'user-b');

      expect(
        (await c.read(myPaymentSubmissionsProvider.future)).single.id,
        'user-b-payment',
        reason: 'B reads B\'s ledger, never A\'s',
      );
      expect(
        await c.read(adminStatusProvider.future),
        isFalse,
        reason: 'B is not an admin, so the panel must not open to them',
      );
      expect(
        await c.read(adminPaymentRequestsProvider.future),
        isEmpty,
        reason: 'a non-admin\'s panel has no queue',
      );
      expect(await c.read(firmMembersListProvider.future), isEmpty);
      expect(await c.read(firmInvitesListProvider.future), isEmpty);

      expect(
        payments.fetches,
        2,
        reason:
            'the switch re-read the history rather than serving A\'s answer',
      );
      expect(admin.statusCalls, 2, reason: 'the switch asked the server again');
    },
  );

  test(
    'a switch to another account drops the previous one\'s device record',
    () async {
      final c = await container();
      await signInAs(c, 'user-a');
      await c
          .read(profileFieldsProvider.notifier)
          .save(const ProfileFields(fullName: 'Adv. A', mobile: '1711111111'));

      await sessionLost(c);

      // The record is the previous holder's and outlives the session; a sign-in as
      // somebody else is where it has to go.
      expect(c.read(profileFieldsProvider).fullName, 'Adv. A');
      await signInAs(c, 'user-b');
      expect(
        c.read(profileFieldsProvider).fullName,
        isEmpty,
        reason:
            'B\'s account must not inherit the details A typed on this device',
      );
    },
  );

  test('a switch to another account wipes the leaving diary with its queue', () async {
    final c = await container();
    await signInAs(c, 'user-a');

    // A's own work on this device: a local record and the queued mutation the
    // header counts. Both survive the session ending on its own — nothing wipes
    // them (by design, so a rejected session never destroys a diary).
    await harness.db
        .into(harness.db.notes)
        .insert(
          NotesCompanion.insert(
            id: 'a-note',
            userId: 'user-a',
            title: 'A only',
            body: 'Body',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await harness.db
        .into(harness.db.syncQueue)
        .insert(
          SyncQueueCompanion.insert(
            entityType: 'cases',
            entityId: 'a-case',
            operation: 'insert',
            mutationId: 'a-mutation',
            basePayload: '{}',
            changedFields: '["id"]',
            payload: '{"id":"a-case"}',
            preMutationPayload: '{}',
            createdAt: 0,
            state: 'pending',
          ),
        );

    // The two live facts the reported screens read — the header's count and Sync
    // Status's entry list — observed from **before** the switch. A wipe that only
    // deletes rows is not enough: the database behind these was empty while the
    // header still showed A's count and Sync Status still listed A's queued
    // mutation, because a raw `DELETE FROM` tells Drift's query streams nothing.
    final countFell = Completer<int>();
    final entriesCleared = Completer<int>();
    final countSubscription = c.listen<AsyncValue<int>>(
      syncQueuePendingCountProvider,
      (previous, next) {
        final value = next.value;
        if (value == 0 && !countFell.isCompleted) countFell.complete(value);
      },
      fireImmediately: true,
    );
    final entriesSubscription = c.listen<AsyncValue<List<SyncQueueRow>>>(
      syncQueueEntriesProvider,
      (previous, next) {
        final value = next.value;
        if (value != null && value.isEmpty && !entriesCleared.isCompleted) {
          entriesCleared.complete(value.length);
        }
      },
      fireImmediately: true,
    );
    addTearDown(countSubscription.close);
    addTearDown(entriesSubscription.close);

    // Both screens really were showing A's work a moment ago.
    await pumpEventQueue();
    expect(c.read(syncQueuePendingCountProvider).value, 1);
    expect(c.read(syncQueueEntriesProvider).value, hasLength(1));

    await sessionLost(c);
    await signInAs(c, 'user-b');

    // Plan §5 / the Revision 2.4 Addendum: the **account switch** follows the
    // same complete wipe scope as the Logout button. Without it B opened the
    // diary onto A's record and A's queue — the reported "B's case in A's
    // pending sync, and a count on the header".
    expect(
      await harness.db.select(harness.db.notes).get(),
      isEmpty,
      reason: 'B must not open A\'s diary',
    );
    expect(
      await harness.db.select(harness.db.syncQueue).get(),
      isEmpty,
      reason: 'nothing of A\'s may stay queued, counted on B\'s header',
    );
    // And the screens are **told**, not merely correct underneath.
    expect(
      await countFell.future.timeout(const Duration(seconds: 10)),
      0,
      reason: 'the header counts B\'s work only',
    );
    expect(
      await entriesCleared.future.timeout(const Duration(seconds: 10)),
      0,
      reason: 'Sync Status must not keep listing A\'s queued case',
    );
    expect(
      c.read(authAdoptionBlockedProvider),
      isFalse,
      reason: 'a wiped device adopts the arriving account cleanly',
    );
    expect(
      await harness.db.select(harness.db.courtCategories).get(),
      isNotEmpty,
      reason: 'and B still finds the baseline an install starts from',
    );
  });

  test('the same account arriving again keeps its own device record', () async {
    final c = await container();
    await signInAs(c, 'user-a');
    await c
        .read(profileFieldsProvider.notifier)
        .save(const ProfileFields(fullName: 'Adv. A'));

    // The SDK reporting the same account again — a token refresh, a restored
    // session — is not an account switch, so nothing of theirs is dropped.
    harness.auth.emit(
      const AuthSessionEvent(identity: AuthIdentity(userId: 'user-a')),
    );
    await pumpEventQueue();

    expect(c.read(profileFieldsProvider).fullName, 'Adv. A');
  });

  test('the same administrator signing back in gets the panel again', () async {
    final c = await container();
    await signInAs(c, 'user-a');
    expect(await c.read(adminStatusProvider.future), isTrue);
    expect(admin.statusCalls, 1);

    // The Logout button ends the session, and a screen still watching the status
    // re-asks at that instant. With no JWT there is nothing to answer, and
    // `isAdmin` turns that into false rather than throwing — the same answer a
    // genuine non-admin gets.
    await c.read(authViewModelProvider.notifier).signOut();
    account.signedIn = false;
    expect(await c.read(adminStatusProvider.future), isFalse);
    // The number of asks made while there was no session, so the assertion below
    // is about the sign-in asking **again** rather than about a total.
    final callsWithNoSession = admin.statusCalls;

    // The same administrator signs back in. The logout forgot the remembered
    // id, so this is *not* an account switch and the switch branch drops
    // nothing — the arriving end of the session is what has to re-ask, or the
    // signed-out false stands and their Admin Panel entry never comes back: no
    // drawer row, no bottom tab, until the app is restarted.
    await signInAs(c, 'user-a');
    expect(
      await c.read(adminStatusProvider.future),
      isTrue,
      reason:
          'signing in must ask the server again rather than serve the '
          'answer from the moment the session ended',
    );
    expect(
      admin.statusCalls,
      callsWithNoSession + 1,
      reason:
          'the sign-in asked the server again rather than serving the '
          'answer the signed-out read left behind',
    );
  });

  test('the Logout button drops the live reads too', () async {
    final c = await container();
    await signInAs(c, 'user-a');
    expect(
      (await c.read(myPaymentSubmissionsProvider.future)).single.id,
      'user-a-payment',
    );
    expect(await c.read(adminStatusProvider.future), isTrue);

    // The Logout button: the session is gone, so the server answers nothing.
    await c.read(authViewModelProvider.notifier).signOut();
    account.signedIn = false;

    expect(
      await c.read(myPaymentSubmissionsProvider.future),
      isEmpty,
      reason: 'the cached ledger was dropped, so it went back to the server',
    );
    expect(
      await c.read(adminStatusProvider.future),
      isFalse,
      reason: 'the cached admin answer was dropped with it',
    );
  });
}
