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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/firm_repository.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_name_store.dart';
import 'package:legal_case_diary/features/admin/data/admin_repository.dart';
import 'package:legal_case_diary/features/admin/presentation/admin_viewmodel.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_viewmodel.dart';
import 'package:legal_case_diary/features/payments/data/payment_repository.dart';

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
  Future<AdminActionFailure?> reject(String submissionId, {String? note}) async =>
      null;
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

  test('a switch to another account drops the previous one\'s live reads', () async {
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
    expect((await c.read(firmInvitesListProvider.future)).single.id, 'invite-a');

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
      reason: 'the switch re-read the history rather than serving A\'s answer',
    );
    expect(admin.statusCalls, 2, reason: 'the switch asked the server again');
  });

  test('a switch to another account drops the previous one\'s device record', () async {
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
      reason: 'B\'s account must not inherit the details A typed on this device',
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
