/// ViewModel for payment state: demonstrates MVVM + Riverpod async pattern.
/// Per Plan §12.3, always use `.select()` to listen only to required properties.
/// Full implementation is deferred to Task 21 (Part B).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Payment state placeholder.
class PaymentState {
  /// Stub: Will be defined in Task 21.
}

/// AsyncNotifier for payment state management.
class PaymentViewModel extends AsyncNotifier<PaymentState> {
  /// Riverpod provider for [PaymentViewModel].
  static final provider = AsyncNotifierProvider<PaymentViewModel, PaymentState>(
    () => PaymentViewModel(),
  );

  /// Stub: AsyncNotifier implementation in Task 21 (Part B).
  @override
  FutureOr<PaymentState> build() async {
    // Task 21 will implement.
    throw UnimplementedError('PaymentViewModel in Task 21');
  }
}

/// Global provider alias for the payment ViewModel.
final paymentViewModelProvider = PaymentViewModel.provider;
