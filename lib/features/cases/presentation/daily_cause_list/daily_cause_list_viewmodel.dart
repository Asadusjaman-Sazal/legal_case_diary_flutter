/// ViewModel for the daily cause list screen.
///
/// Loads cases scheduled for the selected Bangladesh civil date (default
/// today) and exposes a reactive stream for the list.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../database/app_database.dart';
import '../../data/case_repository.dart';

/// State for [DailyCauseListViewModel].
class DailyCauseListState {
  /// Cases scheduled for the selected date.
  final List<Case> cases;

  /// The currently selected Bangladesh civil date (epoch ms at start of day).
  final int selectedDate;

  /// Creates the state.
  const DailyCauseListState({
    this.cases = const [],
    required this.selectedDate,
  });

  /// Returns a copy with the given fields replaced.
  DailyCauseListState copyWith({
    List<Case>? cases,
    int? selectedDate,
  }) {
    return DailyCauseListState(
      cases: cases ?? this.cases,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }
}

/// AsyncNotifier for the daily cause list feature.
class DailyCauseListViewModel extends AsyncNotifier<DailyCauseListState> {
  /// Riverpod provider for [DailyCauseListViewModel].
  static final provider = AsyncNotifierProvider<DailyCauseListViewModel, DailyCauseListState>(() => DailyCauseListViewModel());

  @override
  FutureOr<DailyCauseListState> build() async {
    final today = AppDateUtils.bangladeshTodayStartOfDay();
    final repo = await ref.watch(caseRepositoryProvider.future);
    final cases = await _loadForDate(repo, today);
    return DailyCauseListState(cases: cases, selectedDate: today);
  }

  Future<List<Case>> _loadForDate(CaseRepository repo, int start) async {
    final end = start + const Duration(days: 1).inMilliseconds - 1;
    return repo.listByNextDateRange(start, end);
  }

  /// Selects a new date and reloads the list.
  Future<void> selectDate(int startOfDay) async {
    state = const AsyncValue<DailyCauseListState>.loading();
    try {
      final repo = await ref.read(caseRepositoryProvider.future);
      final cases = await _loadForDate(repo, startOfDay);
      state = AsyncValue.data(DailyCauseListState(cases: cases, selectedDate: startOfDay));
    } catch (error, stackTrace) {
      state = AsyncValue<DailyCauseListState>.error(error, stackTrace);
    }
  }

}

/// Global provider alias for the daily cause list ViewModel.
final dailyCauseListViewModelProvider = DailyCauseListViewModel.provider;
