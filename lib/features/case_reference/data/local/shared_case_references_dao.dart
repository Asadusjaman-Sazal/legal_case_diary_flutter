/// Local reads and per-device pins for the server-wide citation library.
///
/// The cache itself is filled only by the delta pull ([SharedCaseReferences] is
/// a pull-only cache), so this DAO has no insert or update of a reference — the
/// only thing the user can write here is their own pin, which is a separate
/// local-only table.
library;

import 'package:drift/drift.dart';

import '../../../../database/app_database.dart';

/// One official reference as this device shows it: the cached row plus whether
/// this phone pinned it.
class OfficialReference {
  /// Creates an entry for [row].
  const OfficialReference({required this.row, required this.isPinned});

  /// The cached server row.
  final SharedCaseReference row;

  /// Whether this device pinned it (never synced, never shared).
  final bool isPinned;
}

/// Data access for the official case references and their local pins.
class SharedCaseReferencesDao {
  /// Creates a DAO backed by [db].
  SharedCaseReferencesDao(this.db);

  /// The Drift database instance.
  final AppDatabase db;

  /// Every live official reference with this device's pin state, newest pin
  /// first then by citation.
  ///
  /// One query with a left join rather than two streams zipped: a pin change and
  /// a pulled row both re-run it, so the screen can never show a row and its pin
  /// out of step.
  Stream<List<OfficialReference>> watchAll() {
    final query = db.select(db.sharedCaseReferences).join([
      leftOuterJoin(
        db.sharedCaseReferencePins,
        db.sharedCaseReferencePins.referenceId.equalsExp(
          db.sharedCaseReferences.id,
        ),
      ),
    ])..where(db.sharedCaseReferences.isDeleted.equals(false));

    return query.watch().map((rows) {
      final entries = [
        for (final row in rows)
          OfficialReference(
            row: row.readTable(db.sharedCaseReferences),
            isPinned: row.readTableOrNull(db.sharedCaseReferencePins) != null,
          ),
      ];
      entries.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return a.row.referenceAndPageNo.toLowerCase().compareTo(
          b.row.referenceAndPageNo.toLowerCase(),
        );
      });
      return entries;
    });
  }

  /// The live official references matching [query] across the eight text fields.
  ///
  /// The cache is small (an admin's library, not every case on the phone), so
  /// the same case-insensitive substring rule the local DAO's `LIKE` applies is
  /// run in memory here rather than in a second SQL statement with its own pin
  /// join. The needle must stay a plain string: the SQL wildcards belong to the
  /// query, never to a `contains` (a `%…%` pattern matches no text).
  Future<List<SharedCaseReference>> search(String query) async {
    final needle = query.trim().toLowerCase();
    final rows = await (db.select(
      db.sharedCaseReferences,
    )..where((row) => row.isDeleted.equals(false))).get();
    bool matches(String? value) =>
        value != null && value.toLowerCase().contains(needle);
    return rows
        .where(
          (row) =>
              matches(row.referenceAndPageNo) ||
              matches(row.parties) ||
              matches(row.statute) ||
              matches(row.sectionOrArticle) ||
              matches(row.titleAndDescription) ||
              matches(row.commentsNotes) ||
              matches(row.caseNote) ||
              matches(row.tags),
        )
        .toList(growable: false);
  }

  /// The ids this device has pinned, read once rather than watched.
  Future<Set<String>> pinnedIds() async {
    final rows = await db.select(db.sharedCaseReferencePins).get();
    return {for (final row in rows) row.referenceId};
  }

  /// Pins or unpins [referenceId] on this device only.
  Future<void> setPinned(String referenceId, bool pinned, int nowMs) async {
    if (pinned) {
      await db
          .into(db.sharedCaseReferencePins)
          .insertOnConflictUpdate(
            SharedCaseReferencePinsCompanion.insert(
              referenceId: referenceId,
              pinnedAt: nowMs,
            ),
          );
      return;
    }
    await (db.delete(
      db.sharedCaseReferencePins,
    )..where((row) => row.referenceId.equals(referenceId))).go();
  }
}
