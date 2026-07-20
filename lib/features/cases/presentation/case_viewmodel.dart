/// ViewModel for cases: demonstrates MVVM + Riverpod async pattern using AsyncNotifier.
/// Per Plan §12.3, always use `.select()` to listen only to required properties.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AsyncNotifier for cases state management.
/// ViewModels should use `.select()` to optimize rendering.
abstract class CaseViewModel extends AsyncNotifier<CaseState> {
  /// Stub: AsyncNotifier implementation in Task 05.
  /// Usage pattern: ref.watch(caseViewModelProvider.select((state) => state.cases))
  @override
  FutureOr<CaseState> build() async {
    // Task 05 will implement.
    throw UnimplementedError('CaseViewModel in Task 05');
  }
}

/// Case state model.
class CaseState {
  /// Stub: Will be defined in Task 05.
}
