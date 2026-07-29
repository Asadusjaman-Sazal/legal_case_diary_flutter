/// ViewModels for the reference-data configuration features.
///
/// Each AsyncNotifier exposes a reactive list of its entity and CRUD helpers.
/// UI code should use `.select()` to subscribe only to the fields it needs.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/base_list_viewmodel.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../database/app_database.dart';
import '../data/case_types_repository.dart';
import '../data/court_categories_repository.dart';
import '../data/courts_repository.dart';
import '../data/on_behalfs_repository.dart';
import '../data/steps_repository.dart';

// ---------------------------------------------------------------------------
// Court categories
// ---------------------------------------------------------------------------

/// AsyncNotifier for the court categories feature.
class CourtCategoriesViewModel
    extends BaseListViewModel<CourtCategory, CourtCategoriesRepository> {
  /// Riverpod provider for [CourtCategoriesViewModel].
  static final provider =
      AsyncNotifierProvider<CourtCategoriesViewModel, ListState<CourtCategory>>(
    () => CourtCategoriesViewModel(),
  );

  @override
  FutureProvider<CourtCategoriesRepository> get repositoryProvider =>
      courtCategoriesRepositoryProvider;

  @override
  Future<List<CourtCategory>> loadItems(CourtCategoriesRepository repo) =>
      repo.listAll();

  @override
  Stream<List<CourtCategory>> watchItems(CourtCategoriesRepository repo) =>
      repo.watchAll();

  /// Inserts a court category and refreshes the list.
  Future<void> addCategory(CourtCategoriesCompanion companion) async {
    await withRepo((repo) async => await repo.insert(companion));
  }

  /// Updates a court category and refreshes the list.
  Future<void> updateCategory(
    CourtCategoriesCompanion companion, {
    CourtCategory? base,
  }) async {
    await withRepo((repo) async => await repo.update(companion, base: base));
  }

  /// Soft-deletes a court category and refreshes the list.
  Future<void> deleteCategory(CourtCategory category) async {
    await withRepo((repo) async => await repo.delete(category));
  }
}

/// Global provider alias for the court categories ViewModel.
final courtCategoriesViewModelProvider = CourtCategoriesViewModel.provider;

// ---------------------------------------------------------------------------
// Courts
// ---------------------------------------------------------------------------

/// AsyncNotifier for the courts feature.
class CourtsViewModel extends BaseListViewModel<Court, CourtsRepository> {
  /// Riverpod provider for [CourtsViewModel].
  static final provider =
      AsyncNotifierProvider<CourtsViewModel, ListState<Court>>(
    () => CourtsViewModel(),
  );

  @override
  FutureProvider<CourtsRepository> get repositoryProvider =>
      courtsRepositoryProvider;

  @override
  Future<List<Court>> loadItems(CourtsRepository repo) => repo.listAll();

  @override
  Stream<List<Court>> watchItems(CourtsRepository repo) => repo.watchAll();

  /// Inserts a court and refreshes the list.
  Future<void> addCourt(CourtsCompanion companion) async {
    await withRepo((repo) async => await repo.insert(companion));
  }

  /// Updates a court and refreshes the list.
  Future<void> updateCourt(
    CourtsCompanion companion, {
    Court? base,
  }) async {
    await withRepo((repo) async => await repo.update(companion, base: base));
  }

  /// Soft-deletes a court and refreshes the list.
  Future<void> deleteCourt(Court court) async {
    await withRepo((repo) async => await repo.delete(court));
  }
}

/// Global provider alias for the courts ViewModel.
final courtsViewModelProvider = CourtsViewModel.provider;

// ---------------------------------------------------------------------------
// Steps
// ---------------------------------------------------------------------------

/// AsyncNotifier for the steps feature.
class StepsViewModel extends BaseListViewModel<Step, StepsRepository> {
  /// Riverpod provider for [StepsViewModel].
  static final provider =
      AsyncNotifierProvider<StepsViewModel, ListState<Step>>(
    () => StepsViewModel(),
  );

  @override
  FutureProvider<StepsRepository> get repositoryProvider =>
      stepsRepositoryProvider;

  @override
  Future<List<Step>> loadItems(StepsRepository repo) => repo.listAll();

  @override
  Stream<List<Step>> watchItems(StepsRepository repo) => repo.watchAll();

  /// Inserts a step and refreshes the list.
  Future<void> addStep(StepsCompanion companion) async {
    await withRepo((repo) async => await repo.insert(companion));
  }

  /// Updates a step and refreshes the list.
  Future<void> updateStep(
    StepsCompanion companion, {
    Step? base,
  }) async {
    await withRepo((repo) async => await repo.update(companion, base: base));
  }

  /// Soft-deletes a step and refreshes the list.
  Future<void> deleteStep(Step step) async {
    await withRepo((repo) async => await repo.delete(step));
  }
}

/// Global provider alias for the steps ViewModel.
final stepsViewModelProvider = StepsViewModel.provider;

// ---------------------------------------------------------------------------
// Case types
// ---------------------------------------------------------------------------

/// AsyncNotifier for the case types feature.
class CaseTypesViewModel
    extends BaseListViewModel<CaseType, CaseTypesRepository> {
  /// Riverpod provider for [CaseTypesViewModel].
  static final provider =
      AsyncNotifierProvider<CaseTypesViewModel, ListState<CaseType>>(
    () => CaseTypesViewModel(),
  );

  @override
  FutureProvider<CaseTypesRepository> get repositoryProvider =>
      caseTypesRepositoryProvider;

  @override
  Future<List<CaseType>> loadItems(CaseTypesRepository repo) => repo.listAll();

  @override
  Stream<List<CaseType>> watchItems(CaseTypesRepository repo) =>
      repo.watchAll();

  /// Inserts a case type and refreshes the list.
  Future<void> addCaseType(CaseTypesCompanion companion) async {
    await withRepo((repo) async => await repo.insert(companion));
  }

  /// Updates a case type and refreshes the list.
  Future<void> updateCaseType(
    CaseTypesCompanion companion, {
    CaseType? base,
  }) async {
    await withRepo((repo) async => await repo.update(companion, base: base));
  }

  /// Soft-deletes a case type and refreshes the list.
  Future<void> deleteCaseType(CaseType caseType) async {
    await withRepo((repo) async => await repo.delete(caseType));
  }
}

/// Global provider alias for the case types ViewModel.
final caseTypesViewModelProvider = CaseTypesViewModel.provider;

// ---------------------------------------------------------------------------
// On-behalfs
// ---------------------------------------------------------------------------

/// AsyncNotifier for the on-behalfs feature.
class OnBehalfsViewModel
    extends BaseListViewModel<OnBehalf, OnBehalfsRepository> {
  /// Riverpod provider for [OnBehalfsViewModel].
  static final provider =
      AsyncNotifierProvider<OnBehalfsViewModel, ListState<OnBehalf>>(
    () => OnBehalfsViewModel(),
  );

  @override
  FutureProvider<OnBehalfsRepository> get repositoryProvider =>
      onBehalfsRepositoryProvider;

  @override
  Future<List<OnBehalf>> loadItems(OnBehalfsRepository repo) => repo.listAll();

  @override
  Stream<List<OnBehalf>> watchItems(OnBehalfsRepository repo) =>
      repo.watchAll();

  /// Inserts an on-behalf option and refreshes the list.
  Future<void> addOnBehalf(OnBehalfsCompanion companion) async {
    await withRepo((repo) async => await repo.insert(companion));
  }

  /// Updates an on-behalf option and refreshes the list.
  Future<void> updateOnBehalf(
    OnBehalfsCompanion companion, {
    OnBehalf? base,
  }) async {
    await withRepo((repo) async => await repo.update(companion, base: base));
  }

  /// Soft-deletes an on-behalf option and refreshes the list.
  Future<void> deleteOnBehalf(OnBehalf onBehalf) async {
    await withRepo((repo) async => await repo.delete(onBehalf));
  }
}

/// Global provider alias for the on-behalfs ViewModel.
final onBehalfsViewModelProvider = OnBehalfsViewModel.provider;
