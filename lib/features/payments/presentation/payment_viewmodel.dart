/// View model for the checkout: submission state, the local draft and the log.
///
/// Task 21 Phase 2, MVVM + Riverpod. The view model owns the one write path:
/// validate nothing (the screen already validated), submit through
/// [PaymentRepository], and on a **confirmed** success record the local
/// submission stamp and clear the draft — never before, so a failure keeps the
/// form exactly as the user typed it. On any refusal it maps the typed failure to
/// the screen's message and leaves the draft alone.
///
/// The 3-per-24h local check is UX only (Addendum/§7): it is read from
/// [paymentSubmissionLogProvider] before a submit and the server's trigger stays
/// authoritative, which is why a server `limitReached` is handled here too.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_log.dart';
import '../../../core/errors/error_log_provider.dart';
import '../../../core/providers/repository_providers.dart';
import '../../auth/presentation/auth_viewmodel.dart';
import '../data/payment_plans.dart';
import '../data/payment_local_store.dart';
import '../data/payment_repository.dart';

/// Where one checkout attempt stands.
enum PaymentPhase {
  /// Nothing attempted yet.
  idle,

  /// A submit is in flight.
  submitting,

  /// The submission was accepted by the server.
  success,

  /// The submission was refused; [PaymentState.failure] says how.
  failure,
}

/// The checkout's observable state.
class PaymentState {
  /// Creates a state.
  const PaymentState({
    this.phase = PaymentPhase.idle,
    this.failure,
    this.signInRequired = false,
  });

  /// The current phase.
  final PaymentPhase phase;

  /// The refusal category when [phase] is [PaymentPhase.failure].
  final PaymentSubmitFailure? failure;

  /// True when the failure was simply that nobody is signed in.
  final bool signInRequired;

  /// True while a submit is in flight.
  bool get isSubmitting => phase == PaymentPhase.submitting;
}

/// AsyncNotifier for payment submission state.
class PaymentViewModel extends AsyncNotifier<PaymentState> {
  /// Riverpod provider for [PaymentViewModel].
  static final provider = AsyncNotifierProvider<PaymentViewModel, PaymentState>(
    () => PaymentViewModel(),
  );

  @override
  FutureOr<PaymentState> build() async => const PaymentState();

  /// Submits one payment. Returns true only on a confirmed success.
  ///
  /// The draft is cleared and the local stamp recorded **only** here, after the
  /// server accepted the row.
  Future<bool> submit({
    required String planKey,
    required String provider,
    required String phone,
    required String trx,
  }) async {
    final identity = ref.read(authIdentityProvider);
    if (identity == null) {
      state = AsyncData(
        const PaymentState(phase: PaymentPhase.failure, signInRequired: true),
      );
      return false;
    }
    final amount = paymentPlanAmount(planKey);
    if (amount == null) {
      state = AsyncData(
        const PaymentState(
          phase: PaymentPhase.failure,
          failure: PaymentSubmitFailure.other,
        ),
      );
      return false;
    }

    state = AsyncData(const PaymentState(phase: PaymentPhase.submitting));
    try {
      await ref
          .read(paymentRepositoryProvider)
          .submit(
            userId: identity.userId,
            planType: planKey,
            amount: amount,
            mfsProvider: provider,
            senderNumber: phone,
            transactionId: trx,
          );
    } on PaymentSubmitException catch (error) {
      // A refused payment is the one failure where the user's money and the
      // developer's copy of the attempt have to agree, so it is recorded the
      // moment it is refused rather than only when it reaches the global
      // capture — which it never would, being shown as a form message.
      recordFailure(ref.read(errorLogProvider), 'payments.submit', error);
      state = AsyncData(
        PaymentState(phase: PaymentPhase.failure, failure: error.kind),
      );
      return false;
    }

    // Confirmed success: the draft has served its purpose, and the stamp feeds
    // the best-effort local limit.
    await ref.read(paymentDraftProvider.notifier).clear();
    await ref.read(paymentSubmissionLogProvider.notifier).record(DateTime.now());
    ref.invalidate(myPaymentSubmissionsProvider);
    state = AsyncData(const PaymentState(phase: PaymentPhase.success));
    return true;
  }
}

/// Global provider alias for the payment view model.
final paymentViewModelProvider = PaymentViewModel.provider;
