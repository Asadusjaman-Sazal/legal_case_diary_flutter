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
  ///
  /// Defaults to true (user request, 0.0.697): an account that has never chosen
  /// hears its hearing reminders, and can silence them here. A row written by
  /// an older build keeps the value it stored.
  BoolColumn get notificationEnabled =>
      boolean().withDefault(const Constant(true))();

  /// Preferred notification time of day (epoch ms or minutes-since-midnight;
  /// interpretation left to the notification task).
  IntColumn get notificationTime => integer().nullable()();

  /// JSON array of default notification day offsets before a hearing.
  TextColumn get notificationDefaultOffsets => text().nullable()();

  /// Whether this account wants a push when an admin's payment request is
  /// waiting (Settings → Notifications).
  ///
  /// Defaults to true: an admin who installs the panel wants to hear about
  /// payments waiting, and can silence it. It is synced per-user to
  /// `user_preferences.payment_alerts_enabled`, which the sender reads — an
  /// account whose toggle is off is skipped server-side, so the switch works
  /// even while the app is closed.
  BoolColumn get paymentAlertsEnabled =>
      boolean().withDefault(const Constant(true))();

  /// Timestamp when these preferences were last updated (epoch ms).
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {userId};
}
