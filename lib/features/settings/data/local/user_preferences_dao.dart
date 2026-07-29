/// User preferences DAO: local data access for per-user settings.
/// Implemented in Task 05 Phase 1.
library;

import 'package:drift/drift.dart';

import '../../../../database/app_database.dart';

/// Data Access Object for [UserPreferences] table operations.
class UserPreferencesDao {
  /// Creates a DAO backed by [db].
  UserPreferencesDao(this.db);

  /// The Drift database instance.
  final AppDatabase db;

  /// Returns preferences for [userId], or null if none exist.
  Future<UserPreference?> getByUserId(String userId) async => (db.select(db.userPreferences)
      ..where((row) => row.userId.equals(userId)))
      .getSingleOrNull();

  /// Reactive stream of preferences for [userId].
  Stream<UserPreference?> watchByUserId(String userId) => (db.select(db.userPreferences)
      ..where((row) => row.userId.equals(userId)))
      .watchSingleOrNull();

  /// Inserts or updates preferences for a user.
  Future<int> upsert(UserPreferencesCompanion preference) async => db.into(db.userPreferences).insert(
        preference,
        onConflict: DoUpdate((_) => preference),
      );

  /// Deletes preferences for a user.
  Future<int> delete(String userId) async => (db.delete(db.userPreferences)
      ..where((row) => row.userId.equals(userId)))
      .go();
}
