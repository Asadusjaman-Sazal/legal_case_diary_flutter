/// Per-user preference sync: the one path the two preference tables take to the
/// account.
///
/// **Table classes (AGENTS.md rule 4).** `user_preferences` and
/// `case_notification_preferences` are **per-user preferences**: one lawyer's
/// own settings, never firm-shared, and they never travel through the generic
/// domain queue. This service is the only thing that moves them, it addresses
/// only the caller's own rows, and it writes them straight into the self-only
/// server rows under RLS rather than queueing a domain mutation — which is why
/// it maintains no `version`/`is_deleted`/`synced_at` columns or `sync_queue`
/// entries and must never be given generic sync behaviour.
///
/// **Push and pull, newest wins.** Every attempt compares the two sides'
/// `updated_at` row by row: the strictly newer side wins and an equal pair is
/// left alone. Nothing is remembered — a save that could not reach the server
/// simply leaves the local row newer than the account's, so the next attempt
/// (the next save, launch, resume or reconnect) compares again and sends it.
/// That comparison *is* the retry.
///
/// **Premium only.** A free account's preferences stay on the device (plan §6).
/// The gate lives at the single entry point, `pushPreferencesProvider`.
library;

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../database/app_database.dart';
import 'local/case_notification_preferences_dao.dart';
import 'local/user_preferences_dao.dart';

/// The epoch-ms `updated_at` out of a server row, or null when it cannot be read.
///
/// Anything unreadable is null rather than a guess: a guessed stamp would let a
/// wrong side win the comparison, which is the one thing that must not happen.
int? preferenceUpdatedAt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

/// The `user_preferences` upsert body for [row].
///
/// The only place the local row's names meet the server's snake_case columns
/// (AGENTS.md rule 5), so a renamed column is a one-line change here rather than
/// a search across the app. `theme` is deliberately absent: nothing in the app
/// writes it, and sending the stored null would only be able to erase a value
/// set elsewhere.
Map<String, Object?> userPreferencesPayload(UserPreference row) =>
    <String, Object?>{
      'user_id': row.userId,
      'language': row.language,
      'view_settings_json': row.viewSettingsJson,
      'notification_enabled': row.notificationEnabled,
      'notification_time': row.notificationTime,
      'notification_default_offsets': row.notificationDefaultOffsets,
      'updated_at': row.updatedAt,
    };

/// The local `user_preferences` row for the caller's own server [row].
UserPreferencesCompanion userPreferencesCompanion(
  Map<String, Object?> row, {
  required String userId,
}) => UserPreferencesCompanion(
  userId: Value(userId),
  language: Value(row['language'] as String?),
  viewSettingsJson: Value(row['view_settings_json'] as String?),
  notificationEnabled: Value(row['notification_enabled'] as bool? ?? false),
  notificationTime: Value((row['notification_time'] as num?)?.toInt()),
  notificationDefaultOffsets: Value(
    row['notification_default_offsets'] as String?,
  ),
  updatedAt: Value(preferenceUpdatedAt(row['updated_at']) ?? 0),
);

/// The `case_notification_preferences` upsert body for [row].
Map<String, Object?> casePreferencesPayload(CaseNotificationPreference row) =>
    <String, Object?>{
      'user_id': row.userId,
      'case_id': row.caseId,
      'enabled': row.enabled,
      'offsets': row.offsets,
      'time_minutes': row.timeMinutes,
      'updated_at': row.updatedAt,
    };

/// The local `case_notification_preferences` row for one server [row].
CaseNotificationPreferencesCompanion casePreferencesCompanion(
  Map<String, Object?> row, {
  required String userId,
  required String caseId,
}) => CaseNotificationPreferencesCompanion(
  userId: Value(userId),
  caseId: Value(caseId),
  enabled: Value(row['enabled'] as bool? ?? true),
  offsets: Value(row['offsets'] as String?),
  timeMinutes: Value((row['time_minutes'] as num?)?.toInt()),
  updatedAt: Value(preferenceUpdatedAt(row['updated_at']) ?? 0),
);

/// The server side of the two preference tables.
///
/// Kept behind an interface so the reconcile — the half with the rules in it —
/// is testable against a real database without a live client, and so a build
/// with no backend has an inert answer instead of a null check at every call
/// site.
abstract class PreferenceRemote {
  /// The signed-in account's id, or null when nobody is signed in.
  String? get currentUserId;

  /// The caller's own `user_preferences` row, or null when the account has none.
  Future<Map<String, Object?>?> fetchUserPreferences();

  /// Writes the caller's own `user_preferences` row.
  Future<void> saveUserPreferences(Map<String, Object?> row);

  /// The caller's own `case_notification_preferences` rows.
  Future<List<Map<String, Object?>>> fetchCasePreferences();

  /// Writes [rows], upserted by `(user_id, case_id)`.
  Future<void> saveCasePreferences(List<Map<String, Object?>> rows);

  /// Which of [caseIds] the account actually holds.
  ///
  /// The server's `case_notification_preferences.case_id` is a foreign key to
  /// `cases`, so the answer is what keeps a preference written here for a case
  /// the account has not received yet from failing the whole batch.
  Future<Set<String>> fetchKnownCaseIds(List<String> caseIds);
}

/// The remote a build with no backend gets: nothing to send, nothing to fetch.
class OfflinePreferenceRemote implements PreferenceRemote {
  /// Creates the inert remote.
  const OfflinePreferenceRemote();

  @override
  String? get currentUserId => null;

  @override
  Future<Map<String, Object?>?> fetchUserPreferences() async => null;

  @override
  Future<void> saveUserPreferences(Map<String, Object?> row) async {}

  @override
  Future<List<Map<String, Object?>>> fetchCasePreferences() async =>
      const <Map<String, Object?>>[];

  @override
  Future<void> saveCasePreferences(List<Map<String, Object?>> rows) async {}

  @override
  Future<Set<String>> fetchKnownCaseIds(List<String> caseIds) async =>
      const <String>{};
}

/// [PreferenceRemote] on the live Supabase client.
///
/// Every query is the caller's own row: the request carries the session's id and
/// both tables' RLS policies (`user_preferences_select_own` and its siblings)
/// refuse anything else, so there is no second ownership check here to keep in
/// step with the server's.
class SupabasePreferenceRemote implements PreferenceRemote {
  /// Creates the remote over [client].
  SupabasePreferenceRemote(this._client);

  final SupabaseClient _client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<Map<String, Object?>?> fetchUserPreferences() async {
    final userId = currentUserId;
    if (userId == null) return null;
    return await _client
        .from('user_preferences')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
  }

  @override
  Future<void> saveUserPreferences(Map<String, Object?> row) async {
    await _client.from('user_preferences').upsert(row);
  }

  @override
  Future<List<Map<String, Object?>>> fetchCasePreferences() async {
    final userId = currentUserId;
    if (userId == null) return const <Map<String, Object?>>[];
    return await _client
        .from('case_notification_preferences')
        .select()
        .eq('user_id', userId);
  }

  @override
  Future<void> saveCasePreferences(List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return;
    await _client.from('case_notification_preferences').upsert(rows);
  }

  @override
  Future<Set<String>> fetchKnownCaseIds(List<String> caseIds) async {
    if (caseIds.isEmpty) return const <String>{};
    final rows = await _client
        .from('cases')
        .select('id')
        .inFilter('id', caseIds);
    return <String>{
      for (final row in rows)
        if (row['id'] is String) row['id']! as String,
    };
  }
}

/// Reconciles this device's two preference tables with the account's own rows.
class PreferenceSyncService {
  /// Creates a service over [remote] and the preference tables in [db].
  PreferenceSyncService(this._remote, this._db);

  final PreferenceRemote _remote;
  final AppDatabase _db;

  /// Runs one full reconcile: the account's newer rows come down, this device's
  /// newer rows go up.
  ///
  /// Returns true when the attempt completed, false when there was no account or
  /// nothing could reach the server. A false is not an error to surface: the
  /// local rows are untouched and stay newer, which is what makes the next
  /// attempt retry them.
  Future<bool> synchronize() async {
    final userId = _remote.currentUserId;
    if (userId == null) return false;
    try {
      await _syncUserPreferences(userId);
      await _syncCasePreferences(userId);
      return true;
    } on PostgrestException {
      // A refused policy or a transient server error: keep the local rows.
      return false;
    } on AuthException {
      return false;
    } on Exception {
      // No connection — the normal offline outcome, not an error to surface.
      return false;
    }
  }

  /// One table's reconcile: the newer `user_preferences` row wins.
  Future<void> _syncUserPreferences(String userId) async {
    final dao = UserPreferencesDao(_db);
    final local = await dao.getByUserId(userId);
    final server = await _remote.fetchUserPreferences();

    if (local == null) {
      // A device that has never stored a row of its own takes the account's.
      if (server == null) return;
      await dao.upsert(userPreferencesCompanion(server, userId: userId));
      return;
    }
    if (server == null) {
      // An account that has never stored a row takes this device's.
      await _remote.saveUserPreferences(userPreferencesPayload(local));
      return;
    }

    final serverAt = preferenceUpdatedAt(server['updated_at']) ?? 0;
    if (serverAt > local.updatedAt) {
      await dao.upsert(userPreferencesCompanion(server, userId: userId));
    } else if (local.updatedAt > serverAt) {
      await _remote.saveUserPreferences(userPreferencesPayload(local));
    }
  }

  /// The per-case table's reconcile, row by row.
  Future<void> _syncCasePreferences(String userId) async {
    final dao = CaseNotificationPreferencesDao(_db);
    final locals = await dao.getByUserId(userId);
    final serverRows = await _remote.fetchCasePreferences();
    final localById = <String, CaseNotificationPreference>{
      for (final row in locals) row.caseId: row,
    };
    final serverById = <String, Map<String, Object?>>{
      for (final row in serverRows)
        if (row['case_id'] is String) row['case_id']! as String: row,
    };
    final serverStamps = <String, int>{
      for (final entry in serverById.entries)
        entry.key: preferenceUpdatedAt(entry.value['updated_at']) ?? 0,
    };

    // Pull first: a server row with no local twin, or a newer one, wins.
    for (final entry in serverById.entries) {
      final local = localById[entry.key];
      if (local == null || serverStamps[entry.key]! > local.updatedAt) {
        await dao.upsert(
          casePreferencesCompanion(
            entry.value,
            userId: userId,
            caseId: entry.key,
          ),
        );
      }
    }

    // Then push what this device has newer. `localById` was read before the
    // pull, so a row the account has just supplied is never sent straight back.
    final fresh = <CaseNotificationPreference>[
      for (final local in locals)
        if (!serverStamps.containsKey(local.caseId) ||
            local.updatedAt > serverStamps[local.caseId]!)
          local,
    ];
    if (fresh.isEmpty) return;

    final known = await _remote.fetchKnownCaseIds(
      fresh.map((row) => row.caseId).toList(),
    );
    final rows = <Map<String, Object?>>[
      for (final row in fresh)
        if (known.contains(row.caseId)) casePreferencesPayload(row),
    ];
    // Every fresh row named a case the account does not hold yet: there is
    // nothing to send, so nothing is sent.
    if (rows.isEmpty) return;
    await _remote.saveCasePreferences(rows);
  }
}
