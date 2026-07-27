/// Case notification preferences table: per-user, per-case notification
/// settings. The relation is keyed by `(user_id, case_id)` and is never
/// firm-shared.
/// Per-user preference table — no sync columns needed.
/// Implemented in Task 03 Phase 3.
library;

import 'package:drift/drift.dart';

/// Notification preferences for a specific case and user.
@DataClassName('CaseNotificationPreference')
class CaseNotificationPreferences extends Table {
  /// User UUID these preferences belong to.
  TextColumn get userId => text()();

  /// Case UUID.
  TextColumn get caseId => text()();

  /// Whether notifications are enabled for this case.
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  /// JSON array of day offsets for this case; if null, falls back to the
  /// user's default offsets.
  TextColumn get offsets => text().nullable()();

  /// Timestamp when these preferences were last updated (epoch ms).
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {userId, caseId};
}
