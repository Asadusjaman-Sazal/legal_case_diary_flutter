/// ViewModel for the case references feature.
///
/// Exposes a reactive list of references and mutation helpers. UI code should
/// use `.select()` to subscribe only to the fields it needs.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/base_list_viewmodel.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../database/app_database.dart';
import '../data/reference_repository.dart';

/// AsyncNotifier for the case references feature.
class ReferenceViewModel extends BaseListViewModel<CaseReference, ReferenceRepository> {
  /// Riverpod provider for [ReferenceViewModel].
  static final provider =
      AsyncNotifierProvider<ReferenceViewModel, ListState<CaseReference>>(
    () => ReferenceViewModel(),
  );

  @override
  FutureProvider<ReferenceRepository> get repositoryProvider =>
      referenceRepositoryProvider;

  @override
  String get diagnosticArea => 'caseReference';

  @override
  Future<List<CaseReference>> loadItems(ReferenceRepository repo) =>
      repo.listAll();

  @override
  Stream<List<CaseReference>> watchItems(ReferenceRepository repo) =>
      repo.watchAll();

  /// Inserts a new reference and refreshes the list.
  Future<void> addReference(CaseReferencesCompanion companion) async {
    await withRepo((repo) async => await repo.insertReference(companion));
  }

  /// Updates a reference and refreshes the list.
  Future<void> updateReference(
    CaseReferencesCompanion companion, {
    CaseReference? baseReference,
  }) async {
    await withRepo(
      (repo) async => await repo.updateReference(companion, baseReference: baseReference),
    );
  }

  /// Soft-deletes a reference and refreshes the list.
  Future<void> deleteReference(CaseReference reference) async {
    await withRepo((repo) async => await repo.deleteReference(reference));
  }

  /// Restores a soft-deleted reference (undo) and refreshes the list.
  Future<void> restoreReference(CaseReference reference) async {
    await withRepo((repo) async => await repo.restoreReference(reference));
  }

  /// Toggles the pinned state of a reference and refreshes the list.
  Future<void> setPinned(String id, bool isPinned) async {
    await withRepo((repo) async => await repo.setPinned(id, isPinned));
  }
}

/// Global provider alias for the case references ViewModel.
final referenceViewModelProvider = ReferenceViewModel.provider;
