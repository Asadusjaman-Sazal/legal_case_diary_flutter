/// Delete requests table: local delete-request queue for offline create/approve.
/// Implemented in Task 03 Phase 2.
library;

import 'package:drift/drift.dart';

/// A request to delete an entity, which must be approved by an owner/admin.
@DataClassName('DeleteRequest')
class DeleteRequests extends Table {
  /// UUID primary key.
  TextColumn get id => text()();

  /// Firm this request belongs to; null for individual deletions.
  TextColumn get firmId => text().nullable()();

  /// Entity type (`case`, `case_history`, `note`, `reference`).
  TextColumn get entityType => text()();

  /// UUID of the record to be deleted.
  TextColumn get entityId => text()();

  /// JSON snapshot of the target at request time.
  TextColumn get entitySnapshot => text()();

  /// Target version observed when the request was created.
  IntColumn get targetBaseVersion => integer()();

  /// The associate who requested deletion.
  TextColumn get requestedBy => text()();

  /// The requester's display name, carried inside the request itself.
  ///
  /// A reviewer has to be able to see who asked while offline, and the
  /// `profiles` cache on their device holds the reader's own row rather than a
  /// colleague's — which is why the name travels on the request. Server-derived
  /// (see `20261026140000_delete_requests_requester_name.sql`), nullable because
  /// a request whose requester had no name yet still has to save.
  TextColumn get requesterName => text().nullable()();

  /// `pending`, `approved`, `rejected`, or `stale_review_required`.
  TextColumn get status => text()();

  /// The user with can_delete who acted on it.
  TextColumn get reviewedBy => text().nullable()();

  /// Optional note from the reviewer.
  TextColumn get reviewNote => text().nullable()();

  /// Creation timestamp (epoch ms).
  IntColumn get createdAt => integer()();

  // Global sync columns.
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get lastModifiedBy => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
