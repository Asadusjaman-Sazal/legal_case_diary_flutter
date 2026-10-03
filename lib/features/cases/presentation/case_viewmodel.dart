/// ViewModel for the cases feature.
///
/// Exposes the full non-deleted case list plus KPI counts. UI code should use
/// `.select()` to subscribe only to the fields it needs, e.g.
/// `ref.watch(caseViewModelProvider.select((s) => s.valueOrNull?.cases))`.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_log.dart';
import '../../../core/errors/error_log_provider.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../database/app_database.dart';

/// State for [CaseViewModel].
class CaseState {
  /// All non-deleted cases.
  final List<Case> cases;

  /// Count of active (non-disposed) cases.
  final int activeCount;

  /// Count of all non-deleted cases.
  final int nonDeletedCount;

  /// Creates the state with the given values.
  const CaseState({
    this.cases = const [],
    this.activeCount = 0,
    this.nonDeletedCount = 0,
  });

  /// Returns a copy with the given fields replaced.
  CaseState copyWith({
    List<Case>? cases,
    int? activeCount,
    int? nonDeletedCount,
  }) {
    return CaseState(
      cases: cases ?? this.cases,
      activeCount: activeCount ?? this.activeCount,
      nonDeletedCount: nonDeletedCount ?? this.nonDeletedCount,
    );
  }
}

/// AsyncNotifier for the cases feature.
class CaseViewModel extends AsyncNotifier<CaseState> {
  /// Riverpod provider for [CaseViewModel].
  static final provider = AsyncNotifierProvider<CaseViewModel, CaseState>(() => CaseViewModel());

  @override
  FutureOr<CaseState> build() async {
    final repo = await ref.watch(caseRepositoryProvider.future);
    final cases = await repo.listAll();
    final active = await repo.activeCount();
    final nonDeleted = await repo.nonDeletedCount();
    return CaseState(
      cases: cases,
      activeCount: active,
      nonDeletedCount: nonDeleted,
    );
  }

  /// Reloads the case list and counts.
  ///
  /// Recorded, not just re-rendered: a case list that fails to load is the
  /// single most reported symptom there is, and it becomes an error state a
  /// screen draws rather than an exception that escapes to the global capture.
  Future<void> refresh() async {
    state = const AsyncValue<CaseState>.loading();
    try {
      final repo = await ref.read(caseRepositoryProvider.future);
      final cases = await repo.listAll();
      final active = await repo.activeCount();
      final nonDeleted = await repo.nonDeletedCount();
      state = AsyncValue.data(CaseState(
        cases: cases,
        activeCount: active,
        nonDeletedCount: nonDeleted,
      ));
    } catch (error, stackTrace) {
      recordFailure(ref.read(errorLogProvider), 'cases.refresh', error);
      state = AsyncValue<CaseState>.error(error, stackTrace);
    }
  }

  /// Inserts a new case and refreshes the list.
  Future<void> addCase(CasesCompanion companion) async {
    final repo = await ref.read(caseRepositoryProvider.future);
    await repo.insertCase(companion);
    await refresh();
  }

  /// Updates a case and refreshes the list.
  Future<void> updateCase(
    CasesCompanion companion, {
    Case? baseCase,
    bool isQuickUpdate = false,
  }) async {
    final repo = await ref.read(caseRepositoryProvider.future);
    await repo.updateCase(companion, baseCase: baseCase, isQuickUpdate: isQuickUpdate);
    await refresh();
  }

  /// Soft-deletes a case and refreshes the list.
  Future<void> deleteCase(Case currentCase) async {
    final repo = await ref.read(caseRepositoryProvider.future);
    await repo.deleteCase(currentCase);
    await refresh();
  }

  /// Searches cases and returns matching results.
  Future<List<Case>> search(String query) async {
    final repo = await ref.read(caseRepositoryProvider.future);
    return repo.search(query);
  }

  /// Returns cases whose next date falls in the given inclusive range.
  Future<List<Case>> listByNextDateRange(int start, int end) async {
    final repo = await ref.read(caseRepositoryProvider.future);
    return repo.listByNextDateRange(start, end);
  }
}

/// Global provider alias for the cases ViewModel.
final caseViewModelProvider = CaseViewModel.provider;
