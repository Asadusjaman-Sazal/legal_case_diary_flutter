/// User preferences table: durable per-user settings.
/// Language, theme/view config, navigation config, notification defaults,
/// backup-nudge metadata, and related settings are never firm-shared.
/// Per-user preference table — no sync columns needed.
/// Implemented in Task 03 Phase 3.
library;

import 'package:drift/drift.dart';

/// Preferences for a single user identity.
@DataClassName('UserPreference')
class UserPreferences extends Table {
  /// User UUID these preferences belong to.
  TextColumn get userId => text()();

  /// Selected UI language code (e.g. `en`, `bn`).
  TextColumn get language => text().nullable()();

  /// Selected theme mode (e.g. `light`, `dark`, `system`).
  TextColumn get theme => text().nullable()();

  /// JSON blob for view settings, navigation tab order, backup-nudge
  /// metadata, and any other per-user view/navigation configuration.
  TextColumn get viewSettingsJson => text().nullable()();

  /// Master toggle for notifications.
  BoolColumn get notificationEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Preferred notification time of day (epoch ms or minutes-since-midnight;
  /// interpretation left to the notification task).
  IntColumn get notificationTime => integer().nullable()();

  /// JSON array of default notification day offsets before a hearing.
  TextColumn get notificationDefaultOffsets => text().nullable()();

  /// Timestamp when these preferences were last updated (epoch ms).
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {userId};
}
