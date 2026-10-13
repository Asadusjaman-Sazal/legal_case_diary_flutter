/// Tests for Task 21 Phase 2: submission, the local draft and the rate limit.
///
/// The rules being pinned are the ones the task states: the draft survives a
/// failed submit and is cleared **only** on a confirmed success; a server
/// refusal is worded by kind (the limit trigger gets the friendly sentence); and
/// the local 5-per-24h check is UX only.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_viewmodel.dart';
import 'package:legal_case_diary/features/payments/data/payment_local_store.dart';
import 'package:legal_case_diary/features/payments/data/payment_plans.dart';
import 'package:legal_case_diary/features/payments/data/payment_repository.dart';
import 'package:legal_case_diary/features/payments/presentation/payment_viewmodel.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';

import '../test_utils.dart';

/// A repository that records calls and can refuse on demand.
class _FakePaymentRepository implements PaymentRepository {
  _FakePaymentRepository({this.failWith});

  /// When set, every submit throws this failure.
  final PaymentSubmitFailure? failWith;

  /// How many submits were attempted.
  int submits = 0;

  /// The last transaction id submitted.
  String? lastTrx;

  @override
  Future<void> submit({
    required String userId,
    required String planType,
    required int amount,
    required String mfsProvider,
    required String senderNumber,
    required String transactionId,
  }) async {
    submits++;
    lastTrx = transactionId;
    if (failWith != null) throw PaymentSubmitException(failWith!);
  }

  @override
  Future<List<PaymentSubmission>> fetchMySubmissions() async =>
      const <PaymentSubmission>[];
}

const _userId = 'user-1';

Future<ProviderContainer> _container(
  _FakePaymentRepository repo, {
  SharedPreferences? prefs,
}) async {
  final store = prefs ?? await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: withErrorLog(<Override>[
      sharedPreferencesProvider.overrideWithValue(store),
      authIdentityProvider.overrideWithValue(
        const AuthIdentity(userId: _userId),
      ),
      paymentRepositoryProvider.overrideWithValue(repo),
    ]),
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('local rate-limit rule', () {
    test('counts only submissions inside the 24h window', () {
      final now = DateTime(2026, 10, 1, 12);
      final stamps = <int>[
        now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
        now.subtract(const Duration(hours: 23)).millisecondsSinceEpoch,
        now.subtract(const Duration(hours: 25)).millisecondsSinceEpoch,
      ];
      expect(localSubmissionsInWindow(stamps, now), 2);
      expect(isLocallyRateLimited(stamps, now), isFalse);
    });

    test('five inside the window is the limit', () {
      final now = DateTime(2026, 10, 1, 12);
      final stamps = <int>[
        for (var i = 0; i < 5; i++)
          now.subtract(Duration(hours: i)).millisecondsSinceEpoch,
      ];
      expect(isLocallyRateLimited(stamps, now), isTrue);
    });
  });

  group('draft', () {
    test('saves, reloads and clears per user', () async {
      final container = await _container(_FakePaymentRepository());
      final notifier = container.read(paymentDraftProvider.notifier);

      await notifier.save(
        const PaymentDraft(
          planKey: paymentPlanAnnual,
          method: 'nagad',
          phone: '01712345678',
          trx: 'TRX123',
        ),
      );

      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getString(paymentDraftKey(_userId)), isNotNull);

      await notifier.clear();
      expect(prefs.getString(paymentDraftKey(_userId)), isNull);
      expect(container.read(paymentDraftProvider).isEmpty, isTrue);
    });
  });

  group('submit', () {
    test('a confirmed success clears the draft and records the stamp',
        () async {
      final repo = _FakePaymentRepository();
      final container = await _container(repo);
      await container.read(paymentDraftProvider.notifier).save(
        const PaymentDraft(
          planKey: paymentPlanMonthly,
          method: 'bkash',
          phone: '01712345678',
          trx: 'TRX1',
        ),
      );

      final ok = await container
          .read(paymentViewModelProvider.notifier)
          .submit(
            planKey: paymentPlanMonthly,
            provider: 'bkash',
            phone: '01712345678',
            trx: 'TRX1',
          );

      expect(ok, isTrue);
      expect(repo.submits, 1);
      expect(repo.lastTrx, 'TRX1');
      expect(container.read(paymentDraftProvider).isEmpty, isTrue);
      expect(container.read(paymentSubmissionLogProvider), hasLength(1));
      expect(
        container.read(paymentViewModelProvider).value?.phase,
        PaymentPhase.success,
      );
    });

    test('a network failure keeps the draft and reports network', () async {
      final repo = _FakePaymentRepository(
        failWith: PaymentSubmitFailure.network,
      );
      final container = await _container(repo);
      await container.read(paymentDraftProvider.notifier).save(
        const PaymentDraft(
          planKey: paymentPlanMonthly,
          method: 'bkash',
          phone: '01712345678',
          trx: 'TRX2',
        ),
      );

      final ok = await container
          .read(paymentViewModelProvider.notifier)
          .submit(
            planKey: paymentPlanMonthly,
            provider: 'bkash',
            phone: '01712345678',
            trx: 'TRX2',
          );

      expect(ok, isFalse);
      // The draft is exactly as it was: nothing was confirmed.
      final draft = container.read(paymentDraftProvider);
      expect(draft.trx, 'TRX2');
      expect(container.read(paymentSubmissionLogProvider), isEmpty);
      final state = container.read(paymentViewModelProvider).value;
      expect(state?.phase, PaymentPhase.failure);
      expect(state?.failure, PaymentSubmitFailure.network);
    });

    test('the server limit trigger surfaces as limitReached', () async {
      final repo = _FakePaymentRepository(
        failWith: PaymentSubmitFailure.limitReached,
      );
      final container = await _container(repo);

      await container.read(paymentViewModelProvider.notifier).submit(
        planKey: paymentPlanMonthly,
        provider: 'bkash',
        phone: '01712345678',
        trx: 'TRX3',
      );

      expect(
        container.read(paymentViewModelProvider).value?.failure,
        PaymentSubmitFailure.limitReached,
      );
    });

    test('an unknown plan is refused without a submit', () async {
      final repo = _FakePaymentRepository();
      final container = await _container(repo);

      final ok = await container
          .read(paymentViewModelProvider.notifier)
          .submit(
            planKey: 'lifetime',
            provider: 'bkash',
            phone: '01712345678',
            trx: 'TRX4',
          );

      expect(ok, isFalse);
      expect(repo.submits, 0);
    });
  });
}
