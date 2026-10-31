/// Shared case references: the local cache of the server-wide citation library.
///
/// Table class (AGENTS.md rule 4): **pull-only cache**. The server's
/// `shared_case_references` table is written only by an app administrator; the
/// phone never queues, pushes or edits one of these rows, which is why the table
/// carries no `user_id`, `firm_id`, `version`, `updated_at`, `synced_at` or
/// `last_modified_by` — there is nothing to reconcile and nothing to send.
///
/// The delta pull fills it, keyed by id, and `is_deleted` hides a citation an
/// admin removed. A user's own pin is not here: it lives in
/// `shared_case_reference_pins`, per device, so it never travels to anyone else.
library;

import 'package:drift/drift.dart';

/// One official precedent/citation published to every install.
@DataClassName('SharedCaseReference')
class SharedCaseReferences extends Table {
  /// UUID primary key, assigned by the admin's device.
  TextColumn get id => text()();

  /// Reference and page number, e.g. `29 DLR (AD) 69`.
  TextColumn get referenceAndPageNo => text()();

  /// The cited Act/statute name, as free text like the user's own references.
  TextColumn get statute => text().nullable()();

  /// Section or article number.
  TextColumn get sectionOrArticle => text().nullable()();

  /// Title and description of the principle.
  TextColumn get titleAndDescription => text().nullable()();

  /// Comments or notes the admin attached.
  TextColumn get commentsNotes => text().nullable()();

  /// Tombstone written by the server; a live query filters these out.
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
