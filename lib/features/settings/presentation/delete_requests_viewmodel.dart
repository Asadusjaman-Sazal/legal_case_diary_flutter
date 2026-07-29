/// ViewModel for the delete requests feature.
///
/// Exposes a reactive list of delete requests and a creation helper. In
/// Part A the local user always has delete rights, so requests are only
/// created when the UI explicitly opts in. UI code should use `.select()`
/// to subscribe only to the fields it needs.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/base_list_viewmodel.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../database/app_database.dart';
import '../data/delete_requests_repository.dart';

/// AsyncNotifier for the delete requests feature.
class DeleteRequestsViewModel
    extends BaseListViewModel<DeleteRequest, DeleteRequestsRepository> {
  /// Riverpod provider for [DeleteRequestsViewModel].
  static final provider =
      AsyncNotifierProvider<DeleteRequestsViewModel, ListState<DeleteRequest>>(
    () => DeleteRequestsViewModel(),
  );

  @override
  FutureProvider<DeleteRequestsRepository> get repositoryProvider =>
      deleteRequestsRepositoryProvider;

  @override
  Future<List<DeleteRequest>> loadItems(DeleteRequestsRepository repo) =>
      repo.listAll();

  @override
  Stream<List<DeleteRequest>> watchItems(DeleteRequestsRepository repo) =>
      repo.watchAll();

  /// Creates a delete request for the given entity and refreshes the list.
  Future<void> createRequest({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> entitySnapshot,
    required int targetBaseVersion,
  }) async {
    await withRepo(
      (repo) async => await repo.createRequest(
        entityType: entityType,
        entityId: entityId,
        entitySnapshot: entitySnapshot,
        targetBaseVersion: targetBaseVersion,
      ),
    );
  }
}

/// Global provider alias for the delete requests ViewModel.
final deleteRequestsViewModelProvider = DeleteRequestsViewModel.provider;
