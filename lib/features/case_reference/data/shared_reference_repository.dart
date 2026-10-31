/// Read access to the server-wide citation library, plus this device's pins.
///
/// Separate from [ReferenceRepository] because the two are different table
/// classes: a user's own references are push/pull domain and may be added,
/// edited and deleted, while an official reference is a pull-only cache the
/// phone may not write at all. Keeping them apart is what leaves the 50-case
/// wall, the lapse allowance and every firm rule counting only the user's own
/// rows.
library;

import 'local/shared_case_references_dao.dart';

/// The app's read side of the admin-curated reference library.
abstract class SharedReferenceRepository {
  /// Every live official reference with this device's pin state.
  Stream<List<OfficialReference>> watchAll();

  /// The live official references matching [query] across the five text fields.
  Future<List<OfficialReference>> search(String query);

  /// Pins or unpins one official reference on this device only.
  Future<void> setPinned(String referenceId, bool isPinned);
}

/// Drift-backed implementation over the pull-only cache.
class LocalSharedReferenceRepository implements SharedReferenceRepository {
  /// Creates the repository over [dao].
  LocalSharedReferenceRepository(this._dao);

  final SharedCaseReferencesDao _dao;

  @override
  Stream<List<OfficialReference>> watchAll() => _dao.watchAll();

  @override
  Future<List<OfficialReference>> search(String query) async {
    // The pin state is read alongside the match so a searched list keeps the
    // same pin marks the full list has — one read, not a second subscription.
    final pinned = await _dao.pinnedIds();
    final rows = await _dao.search(query);
    return [
      for (final row in rows)
        OfficialReference(row: row, isPinned: pinned.contains(row.id)),
    ];
  }

  @override
  Future<void> setPinned(String referenceId, bool isPinned) => _dao.setPinned(
    referenceId,
    isPinned,
    DateTime.now().millisecondsSinceEpoch,
  );
}
