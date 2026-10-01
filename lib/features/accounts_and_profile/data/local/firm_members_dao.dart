/// Firm members DAO: local read-only cache for firm membership records.
/// Implemented in Task 05 Phase 1.
library;

import 'package:drift/drift.dart';

import '../../../../database/app_database.dart';

/// Data Access Object for [FirmMembers] pull-only cache operations.
class FirmMembersDao {
  /// Creates a DAO backed by [db].
  FirmMembersDao(this.db);

  /// The Drift database instance.
  final AppDatabase db;

  /// Returns all cached firm members.
  Future<List<FirmMember>> getAll({int? limit, int? offset}) async {
    final query = db.select(db.firmMembers)
      ..orderBy([(row) => OrderingTerm(expression: row.role)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Reactive stream of all cached firm members.
  Stream<List<FirmMember>> watchAll({int? limit, int? offset}) {
    final query = db.select(db.firmMembers)
      ..orderBy([(row) => OrderingTerm(expression: row.role)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.watch();
  }

  /// Returns cached members for a specific firm.
  Future<List<FirmMember>> getByFirmId(String firmId, {int? limit, int? offset}) async {
    final query = db.select(db.firmMembers)
      ..where((row) => row.firmId.equals(firmId))
      ..orderBy([(row) => OrderingTerm(expression: row.role)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Returns cached memberships for a specific user.
  Future<List<FirmMember>> getByUserId(String userId, {int? limit, int? offset}) async {
    final query = db.select(db.firmMembers)
      ..where((row) => row.userId.equals(userId))
      ..orderBy([(row) => OrderingTerm(expression: row.role)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Reactive stream of one user's membership, or null while it is not cached.
  ///
  /// A user belongs to one firm, so the first row is the membership the
  /// permission providers read.
  Stream<FirmMember?> watchByUserId(String userId) => (db.select(db.firmMembers)
        ..where((row) => row.userId.equals(userId)))
      .watchSingleOrNull();

  /// Whether a membership row for [userId] is cached at all.
  ///
  /// The evidence Task 20 Phase 2's revocation check reads: `profiles.firm_id`
  /// is the server's current answer about firm mode, while a cached
  /// `firm_members` row is what this device last knew. The two disagreeing —
  /// no firm on the profile, a membership row still here — is exactly the
  /// transition a removal produces, and it survives the restart that a
  /// remove-while-offline causes.
  Stream<bool> watchHasMembership(String userId) =>
      watchByUserId(userId).map((row) => row != null);

  /// Returns a firm member by id, or null if not found.
  Future<FirmMember?> getById(String id) async => (db.select(db.firmMembers)
      ..where((row) => row.id.equals(id)))
      .getSingleOrNull();

  /// Inserts or replaces a cached firm member.
  Future<int> upsert(FirmMembersCompanion member) async => db.into(db.firmMembers).insert(
        member,
        onConflict: DoUpdate((_) => member),
      );

  /// Deletes a cached firm member by id.
  Future<int> delete(String id) async => (db.delete(db.firmMembers)
      ..where((row) => row.id.equals(id)))
      .go();
}
