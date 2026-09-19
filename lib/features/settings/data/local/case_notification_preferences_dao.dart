/// Case notification preferences DAO: local data access for per-user, per-case
/// notification settings.
/// Implemented in Task 05 Phase 1.
library;

import 'package:drift/drift.dart';

import '../../../../database/app_database.dart';

/// Data Access Object for [CaseNotificationPreferences] table operations.
class CaseNotificationPreferencesDao {
  /// Creates a DAO backed by [db].
  CaseNotificationPreferencesDao(this.db);

  /// The Drift database instance.
  final AppDatabase db;

  /// Returns the preference for [userId] and [caseId], or null if none exist.
  Future<CaseNotificationPreference?> get(String userId, String caseId) async =>
      (db.select(db.caseNotificationPreferences)
          ..where((row) => row.userId.equals(userId) & row.caseId.equals(caseId)))
          .getSingleOrNull();

  /// Reactive stream of preferences for [userId].
  Stream<List<CaseNotificationPreference>> watchByUserId(String userId) => (db.select(db.caseNotificationPreferences)
      ..where((row) => row.userId.equals(userId)))
      .watch();

  /// Returns every per-case preference of [userId].
  ///
  /// Used by the daily notification job, which runs in a background isolate
  /// without a Riverpod scope and therefore cannot watch a stream.
  Future<List<CaseNotificationPreference>> getByUserId(String userId) async =>
      (db.select(db.caseNotificationPreferences)
            ..where((row) => row.userId.equals(userId)))
          .get();

  /// Inserts or updates a per-case notification preference.
  Future<int> upsert(CaseNotificationPreferencesCompanion preference) async =>
      db.into(db.caseNotificationPreferences).insert(
        preference,
        onConflict: DoUpdate((_) => preference),
      );

  /// Deletes the preference for [userId] and [caseId].
  Future<int> delete(String userId, String caseId) async => (db.delete(db.caseNotificationPreferences)
      ..where((row) => row.userId.equals(userId) & row.caseId.equals(caseId)))
      .go();
}
