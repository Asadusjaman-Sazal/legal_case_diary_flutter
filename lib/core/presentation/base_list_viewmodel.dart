/// Base [AsyncNotifier] for simple list-based ViewModels.
///
/// Subclasses supply a repository provider and the load/watch functions. The
/// state is a [ListState<T>] so UI can use `.select()` to listen only to the
/// fields it needs.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/error_log.dart';
import '../errors/error_log_provider.dart';

/// Immutable state for a list of items.
class ListState<T> {
  /// The current list of items.
  final List<T> items;

  /// Creates a state with the given [items].
  const ListState({this.items = const []});

  /// Returns a copy with the given fields replaced.
  ListState<T> copyWith({List<T>? items}) {
    return ListState<T>(items: items ?? this.items);
  }
}

/// Base AsyncNotifier for ViewModels whose primary state is a list.
abstract class BaseListViewModel<T, R> extends AsyncNotifier<ListState<T>> {
  /// The repository provider this ViewModel uses.
  FutureProvider<R> get repositoryProvider;

  /// Loads the full list of items from [repo].
  Future<List<T>> loadItems(R repo);

  /// Watches the reactive list of items from [repo].
  Stream<List<T>> watchItems(R repo);

  /// Where a failure from this ViewModel is recorded, as `feature`.
  ///
  /// The log's whole value is that a report names the screen, so every
  /// subclass states its own rather than letting eight different lists share
  /// one indistinguishable `list` entry.
  String get diagnosticArea;

  /// Runs [action] under [operation], recording anything it lets out.
  ///
  /// A list that fails to load does not crash: the state becomes an error the
  /// screen renders, so nothing escapes to the global capture and the failure
  /// would otherwise leave no trace at all.
  Future<V> _guard<V>(String operation, Future<V> Function() action) async {
    try {
      return await action();
    } on Object catch (error) {
      recordFailure(
        ref.read(errorLogProvider),
        '$diagnosticArea.$operation',
        error,
      );
      rethrow;
    }
  }

  @override
  FutureOr<ListState<T>> build() => _guard('load', () async {
    final repo = await ref.watch(repositoryProvider.future);
    final items = await loadItems(repo);
    return ListState<T>(items: items);
  });

  /// Reloads the list and updates state.
  Future<void> refresh() => _guard('load', () async {
    state = AsyncValue<ListState<T>>.loading();
    try {
      final repo = await ref.read(repositoryProvider.future);
      final items = await loadItems(repo);
      state = AsyncValue.data(ListState<T>(items: items));
    } catch (error, stackTrace) {
      state = AsyncValue<ListState<T>>.error(error, stackTrace);
    }
  });

  /// Executes [action] with the repository and refreshes the list afterwards.
  /// If [action] throws, the AsyncNotifier state is set to error and the
  /// error is re-thrown so callers can also react.
  Future<void> withRepo(FutureOr<void> Function(R repo) action) =>
      _guard('action', () async {
        final repo = await ref.read(repositoryProvider.future);
        try {
          await action(repo);
          await refresh();
        } catch (error, stackTrace) {
          state = AsyncValue<ListState<T>>.error(error, stackTrace);
          rethrow;
        }
      });
}
