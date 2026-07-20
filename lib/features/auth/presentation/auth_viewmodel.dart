/// ViewModel for auth state: demonstrates MVVM + Riverpod async pattern.
/// Per Plan §12.3, always use `.select()` to listen only to required properties.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AsyncNotifier for auth state management.
/// ViewModels should use `.select()` to optimize rendering.
abstract class AuthViewModel extends AsyncNotifier<AuthState> {
  /// Stub: AsyncNotifier implementation in Task 17 (Part B).
  /// Usage pattern: ref.watch(authViewModelProvider.select((state) => state.isLoggedIn))
  @override
  FutureOr<AuthState> build() async {
    // Task 17 will implement.
    throw UnimplementedError('AuthViewModel in Task 17');
  }
}

/// Auth state model.
class AuthState {
  /// Stub: Will be defined in Task 17.
}
