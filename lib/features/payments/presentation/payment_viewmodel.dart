/// ViewModel for payment state: demonstrates MVVM + Riverpod async pattern.
/// Per Plan §12.3, always use `.select()` to listen only to required properties.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AsyncNotifier for payment state management.
/// ViewModels should use `.select()` to optimize rendering.
abstract class PaymentViewmodel extends AsyncNotifier<PaymentState> {
  /// Stub: AsyncNotifier implementation in Task 21 (Part B).
  /// Usage pattern: ref.watch(paymentViewmodelProvider.select((state) => state.checkoutState))
  @override
  FutureOr<PaymentState> build() async {
    // Task 21 will implement.
    throw UnimplementedError('PaymentViewmodel in Task 21');
  }
}

/// Payment state model.
class PaymentState {
  /// Stub: Will be defined in Task 21.
}
