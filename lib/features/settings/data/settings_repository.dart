/// Settings repository: manages per-user preferences.
/// Local implementation in Task 05 Phase 3; remote/sync-aware in Part B.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/services/local_identity_service.dart';
import '../../../database/app_database.dart';
import 'local/user_preferences_dao.dart';

/// Aggregated view of a user's settings.
class UserSettings {
  /// Whether the user currently has premium access.
  /// Part A placeholder: always false.
  final bool isPremium;

  /// Number of days ahead to show upcoming cases.
  final int upcomingCasesPeriod;

  /// Case list display mode, e.g. `compact` or `expanded`.
  final String caseListDisplayMode;

  /// Ordered list of bottom navigation tabs.
  final List<String> bottomNavTabs;

  /// Whether each side navigation option is enabled.
  final Map<String, dynamic> sideNavOptions;

  /// Default landing page route name.
  final String defaultLandingPage;

  /// Preferred notification time of day in minutes since midnight.
  final int? notificationTime;

  /// Default notification day offset before a hearing.
  final int notificationDayOffset;

  /// Available notification offsets selected in per-user settings.
  final List<int> notificationDefaultOffsets;

  /// Selected UI language code.
  final String language;

  /// Backup-nudge and other per-user metadata.
  final Map<String, dynamic> backupNudge;

  /// Last Add Case court hierarchy selections used as the next form defaults.
  final String? lastAddCaseHigherLowerCourt;
  final String? lastAddCaseDivision;
  final String? lastAddCaseDistrict;

  /// Creates a settings value with the given fields.
  const UserSettings({
    this.isPremium = false,
    this.upcomingCasesPeriod = 7,
    this.caseListDisplayMode = 'compact',
    this.bottomNavTabs = const [
      'overdue',
      'daily_cause_list',
      'active',
      'upcoming',
    ],
    this.sideNavOptions = const {},
    this.defaultLandingPage = 'all_cases',
    this.notificationTime,
    this.notificationDayOffset = 1,
    this.notificationDefaultOffsets = const [1],
    this.language = 'en',
    this.backupNudge = const {},
    this.lastAddCaseHigherLowerCourt,
    this.lastAddCaseDivision,
    this.lastAddCaseDistrict,
  });

  /// Creates a copy with the latest Add Case court hierarchy selection.
  UserSettings copyWithLastAddCaseSelection({
    required String? higherLowerCourt,
    required String? division,
    required String? district,
  }) => UserSettings(
    isPremium: isPremium,
    upcomingCasesPeriod: upcomingCasesPeriod,
    caseListDisplayMode: caseListDisplayMode,
    bottomNavTabs: bottomNavTabs,
    sideNavOptions: sideNavOptions,
    defaultLandingPage: defaultLandingPage,
    notificationTime: notificationTime,
    notificationDayOffset: notificationDayOffset,
    notificationDefaultOffsets: notificationDefaultOffsets,
    language: language,
    backupNudge: backupNudge,
    lastAddCaseHigherLowerCourt: higherLowerCourt,
    lastAddCaseDivision: division,
    lastAddCaseDistrict: district,
  );

  /// Converts settings to a JSON-serializable map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'upcoming_cases_period': upcomingCasesPeriod,
    'case_list_display_mode': caseListDisplayMode,
    'bottom_nav_tabs': bottomNavTabs,
    'side_nav_options': sideNavOptions,
    'default_landing_page': defaultLandingPage,
    'notification_day_offset': notificationDayOffset,
    'notification_default_offsets': notificationDefaultOffsets,
    'backup_nudge': backupNudge,
    'last_add_case_higher_lower_court': lastAddCaseHigherLowerCourt,
    'last_add_case_division': lastAddCaseDivision,
    'last_add_case_district': lastAddCaseDistrict,
  };

  /// Creates settings from a preference row and an optional language.
  factory UserSettings.fromRow(UserPreference? row, {String language = 'en'}) {
    final effectiveLanguage = row?.language ?? language;
    if (row == null) {
      return UserSettings(language: effectiveLanguage);
    }

    final viewSettingsJson = row.viewSettingsJson;
    if (viewSettingsJson == null) {
      return UserSettings(
        notificationTime: row.notificationTime,
        notificationDefaultOffsets: _readOffsets(
          row.notificationDefaultOffsets,
          fallback: 1,
        ),
        language: effectiveLanguage,
      );
    }

    final json = _readSettingsJson(viewSettingsJson);
    final rawTabs = json['bottom_nav_tabs'];
    final tabs = rawTabs is List<dynamic>
        ? rawTabs.cast<String>()
        : const ['overdue', 'daily_cause_list', 'active', 'upcoming'];

    return UserSettings(
      upcomingCasesPeriod:
          (json['upcoming_cases_period'] as num?)?.toInt() ?? 7,
      caseListDisplayMode:
          json['case_list_display_mode'] as String? ?? 'compact',
      bottomNavTabs: tabs,
      sideNavOptions: json['side_nav_options'] is Map<String, dynamic>
          ? json['side_nav_options'] as Map<String, dynamic>
          : const {},
      defaultLandingPage:
          json['default_landing_page'] as String? ?? 'all_cases',
      notificationTime: row.notificationTime,
      notificationDayOffset:
          (json['notification_day_offset'] as num?)?.toInt() ?? 1,
      notificationDefaultOffsets: _readOffsets(
        row.notificationDefaultOffsets ?? json['notification_default_offsets'],
        fallback: (json['notification_day_offset'] as num?)?.toInt() ?? 1,
      ),
      language: effectiveLanguage,
      backupNudge: json['backup_nudge'] is Map<String, dynamic>
          ? json['backup_nudge'] as Map<String, dynamic>
          : const {},
      lastAddCaseHigherLowerCourt:
          json['last_add_case_higher_lower_court'] is String
          ? json['last_add_case_higher_lower_court'] as String
          : null,
      lastAddCaseDivision: json['last_add_case_division'] is String
          ? json['last_add_case_division'] as String
          : null,
      lastAddCaseDistrict: json['last_add_case_district'] is String
          ? json['last_add_case_district'] as String
          : null,
    );
  }

  static List<int> _readOffsets(Object? raw, {required int fallback}) {
    final decoded = raw is String ? _tryDecode(raw) : raw;
    if (decoded is List) {
      final values = decoded
          .whereType<num>()
          .map((value) => value.toInt())
          .toList();
      if (values.isNotEmpty) return values;
    }
    return [fallback];
  }

  static Map<String, dynamic> _readSettingsJson(String raw) {
    final decoded = _tryDecode(raw);
    return decoded is Map<String, dynamic>
        ? decoded
        : const <String, dynamic>{};
  }

  static Object? _tryDecode(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }
}

/// Settings repository interface.
abstract class SettingsRepository {
  /// Returns the current user's settings.
  Future<UserSettings> getSettings();

  /// Updates only the Add Case hierarchy defaults without replacing other
  /// settings fields.
  Future<void> saveLastAddCaseSelection({
    required String? higherLowerCourt,
    required String? division,
    required String? district,
  });

  /// Reactive stream of the current user's settings.
  Stream<UserSettings> watchSettings();

  /// Persists the current user's settings.
  Future<void> upsertSettings(UserSettings settings);
}

/// Local Drift-backed implementation of [SettingsRepository].
class LocalSettingsRepository implements SettingsRepository {
  final UserPreferencesDao _dao;
  final LocalIdentityService _identity;

  /// Creates a repository backed by [dao] and [identity].
  LocalSettingsRepository(this._dao, this._identity);

  String get _userId => _identity.getId();

  @override
  Future<UserSettings> getSettings() async {
    final row = await _dao.getByUserId(_userId);
    return UserSettings.fromRow(row);
  }

  @override
  Stream<UserSettings> watchSettings() =>
      _dao.watchByUserId(_userId).map(UserSettings.fromRow);

  @override
  Future<void> saveLastAddCaseSelection({
    required String? higherLowerCourt,
    required String? division,
    required String? district,
  }) async {
    await _dao.db.transaction(() async {
      final row = await _dao.getByUserId(_userId);
      final current = UserSettings.fromRow(row);
      await upsertSettings(
        current.copyWithLastAddCaseSelection(
          higherLowerCourt: higherLowerCourt,
          division: division,
          district: district,
        ),
      );
    });
  }

  @override
  Future<void> upsertSettings(UserSettings settings) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final companion = UserPreferencesCompanion(
      userId: Value(_userId),
      viewSettingsJson: Value(jsonEncode(settings.toJson())),
      notificationTime: Value(settings.notificationTime),
      notificationDefaultOffsets: Value(
        jsonEncode(settings.notificationDefaultOffsets),
      ),
      language: Value(settings.language),
      updatedAt: Value(now),
    );
    await _dao.upsert(companion);
  }
}
