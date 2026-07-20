/// ViewModel for daily cause list: demonstrates MVVM + Riverpod async pattern.
/// Per Plan §12.3, always use `.select()` to listen only to required properties.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AsyncNotifier for daily cause list state management.
/// ViewModels should use `.select()` to optimize rendering.
abstract class DailyCauseListViewmodel extends AsyncNotifier<DailyCauseListState> {
  /// Stub: AsyncNotifier implementation in Task 09.
  /// Usage pattern: ref.watch(dailyCauseListViewmodelProvider.select((state) => state.cases))
  @override
  FutureOr<DailyCauseListState> build() async {
    // Task 09 will implement.
    throw UnimplementedError('DailyCauseListViewmodel in Task 09');
  }
}

/// Daily cause list state model.
class DailyCauseListState {
  /// Stub: Will be defined in Task 09.
}
