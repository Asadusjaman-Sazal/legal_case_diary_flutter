/// The per-device pin on an official case reference.
///
/// Table class (AGENTS.md rule 4): **local operational**. It is never synced and
/// never pushed: an official reference belongs to no account, so a pin on one is
/// this phone's own arrangement, and another device — or another member of the
/// same chamber — keeps its own. That is exactly why it is a separate table
/// rather than a column on `shared_case_references`, which the phone cannot
/// write at all.
library;

import 'package:drift/drift.dart';

/// One pinned official reference.
@DataClassName('SharedCaseReferencePin')
class SharedCaseReferencePins extends Table {
  /// The official reference's id; one pin per reference per device.
  TextColumn get referenceId => text()();

  /// When the pin was made (epoch ms), so the list can order pins the same way
  /// the user's own pinned references sort.
  IntColumn get pinnedAt => integer()();

  @override
  Set<Column> get primaryKey => {referenceId};
}
