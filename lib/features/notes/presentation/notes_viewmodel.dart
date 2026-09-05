/// ViewModel for the notes feature.
///
/// Exposes a reactive list of notes and mutation helpers. UI code should use
/// `.select()` to subscribe only to the fields it needs.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/base_list_viewmodel.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../database/app_database.dart';
import '../data/notes_repository.dart';

/// AsyncNotifier for the notes feature.
class NotesViewModel extends BaseListViewModel<Note, NotesRepository> {
  /// Riverpod provider for [NotesViewModel].
  static final provider =
      AsyncNotifierProvider<NotesViewModel, ListState<Note>>(
    () => NotesViewModel(),
  );

  @override
  FutureProvider<NotesRepository> get repositoryProvider =>
      notesRepositoryProvider;

  @override
  Future<List<Note>> loadItems(NotesRepository repo) => repo.listAll();

  @override
  Stream<List<Note>> watchItems(NotesRepository repo) => repo.watchAll();

  /// Inserts a new note and refreshes the list.
  Future<void> addNote(NotesCompanion companion) async {
    await withRepo((repo) async => await repo.insertNote(companion));
  }

  /// Updates a note and refreshes the list.
  Future<void> updateNote(
    NotesCompanion companion, {
    Note? baseNote,
  }) async {
    await withRepo((repo) async => await repo.updateNote(companion, baseNote: baseNote));
  }

  /// Soft-deletes a note and refreshes the list.
  Future<void> deleteNote(Note note) async {
    await withRepo((repo) async => await repo.deleteNote(note));
  }

  /// Restores a soft-deleted note (undo) and refreshes the list.
  Future<void> restoreNote(Note note) async {
    await withRepo((repo) async => await repo.restoreNote(note));
  }

  /// Toggles the pinned state of a note and refreshes the list.
  Future<void> setPinned(String id, bool isPinned) async {
    await withRepo((repo) async => await repo.setPinned(id, isPinned));
  }
}

/// Global provider alias for the notes ViewModel.
final notesViewModelProvider = NotesViewModel.provider;
