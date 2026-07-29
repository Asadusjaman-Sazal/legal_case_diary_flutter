/// ViewModel for auth state: demonstrates MVVM + Riverpod async pattern.
/// Per Plan §12.3, always use `.select()` to listen only to required properties.
/// Full implementation is deferred to Task 17 (Part B).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Auth state placeholder.
class AuthState {
  /// Stub: Will be defined in Task 17.
}

/// AsyncNotifier for auth state management.
class AuthViewModel extends AsyncNotifier<AuthState> {
  /// Riverpod provider for [AuthViewModel].
  static final provider = AsyncNotifierProvider<AuthViewModel, AuthState>(
    () => AuthViewModel(),
  );

  /// Stub: AsyncNotifier implementation in Task 17 (Part B).
  @override
  FutureOr<AuthState> build() async {
    // Task 17 will implement.
    throw UnimplementedError('AuthViewModel in Task 17');
  }
}

/// Global provider alias for the auth ViewModel.
final authViewModelProvider = AuthViewModel.provider;
