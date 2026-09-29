/// Profiles DAO: local read-only cache for the authenticated user's profile.
/// Implemented in Task 05 Phase 1.
library;

import 'package:drift/drift.dart';

import '../../../../database/app_database.dart';

/// Data Access Object for [Profiles] pull-only cache operations.
class ProfilesDao {
  /// Creates a DAO backed by [db].
  ProfilesDao(this.db);

  /// The Drift database instance.
  final AppDatabase db;

  /// Returns all cached profiles ordered by [fullName].
  Future<List<Profile>> getAll({int? limit, int? offset}) async {
    final query = db.select(db.profiles)
      ..orderBy([(row) => OrderingTerm(expression: row.fullName)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Reactive stream of all cached profiles.
  Stream<List<Profile>> watchAll({int? limit, int? offset}) {
    final query = db.select(db.profiles)
      ..orderBy([(row) => OrderingTerm(expression: row.fullName)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.watch();
  }

  /// Returns a profile by id, or null if not found.
  Future<Profile?> getById(String id) async => (db.select(db.profiles)
      ..where((row) => row.id.equals(id)))
      .getSingleOrNull();

  /// Reactive stream of one profile, or null while it is not cached.
  ///
  /// This is what the account/firm-mode providers watch: the cache is the only
  /// source the UI reads, and a refresh that writes the row notifies every
  /// screen at once.
  Stream<Profile?> watchById(String id) => (db.select(db.profiles)
        ..where((row) => row.id.equals(id)))
      .watchSingleOrNull();

  /// Returns cached profiles for a specific firm.
  Future<List<Profile>> getByFirmId(String firmId, {int? limit, int? offset}) async {
    final query = db.select(db.profiles)
      ..where((row) => row.firmId.equals(firmId))
      ..orderBy([(row) => OrderingTerm(expression: row.fullName)]);
    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }
    return query.get();
  }

  /// Inserts or replaces a cached profile.
  Future<int> upsert(ProfilesCompanion profile) async => db.into(db.profiles).insert(
        profile,
        onConflict: DoUpdate((_) => profile),
      );

  /// Deletes a cached profile by id.
  Future<int> delete(String id) async => (db.delete(db.profiles)
      ..where((row) => row.id.equals(id)))
      .go();
}
