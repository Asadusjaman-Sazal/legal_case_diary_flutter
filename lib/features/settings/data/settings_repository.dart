/// Settings repository: manages per-user preferences.
/// Local implementation in Task 05 Phase 3; remote/sync-aware in Part B.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/services/local_identity_service.dart';
import '../../../database/app_database.dart';
import 'local/user_preferences_dao.dart';

/// Smallest font size step the user can pick, in logical pixels.
const int fontSizeStepMin = -2;

/// Largest font size step: the widest the app is laid out to absorb.
const int fontSizeStepMax = 6;

/// [step] held inside [fontSizeStepMin]..[fontSizeStepMax].
///
/// Applied on read as well as on write, so a value written by an older build, a
/// restored backup or a hand-edited preference can never push every screen's
/// text past what the layouts were measured for.
int clampFontSizeStep(int step) => step.clamp(fontSizeStepMin, fontSizeStepMax);

/// Aggregated view of a user's settings.
class UserSettings {
  /// Whether the user currently has premium access.
  /// Part A placeholder: always false.
  final bool isPremium;

  /// Number of days ahead to show upcoming cases.
  final int upcomingCasesPeriod;

  /// Case list display mode, e.g. `compact` or `expanded`.
  ///
  /// This is the global default used by Settings → View Settings and by every
  /// case-list screen the user has not switched on its own.
  final String caseListDisplayMode;

  /// Per-screen compact ↔ extended choice, keyed by the screen's stable id
  /// (`all_cases`, `active`, `daily_cause_list`, `overdue`, `upcoming`,
  /// `disposed`). An entry overrides the global [caseListDisplayMode] for that
  /// screen alone, so one screen can stay compact while another is extended.
  /// Empty means every screen follows the global mode.
  final Map<String, String> caseListDisplayModes;

  /// Ordered list of bottom navigation tabs.
  final List<String> bottomNavTabs;

  /// Display order of every bottom-navigation screen in the View Settings
  /// dropdown — ticked or not — so the list the user arranged is the list they
  /// see when they open it again. Empty means the canonical order, which is
  /// what an install that has never reordered a row falls back to.
  final List<String> bottomNavOrder;

  /// Whether each side navigation option is enabled.
  final Map<String, dynamic> sideNavOptions;

  /// Per-column widths (logical pixels) the user dragged in the extended
  /// ("table") case view, keyed by the column's stable id. Empty means the
  /// built-in defaults, which is what an install that has never resized a
  /// column gets.
  final Map<String, double> caseTableColumnWidths;

  /// Per-screen court groups the user folded away in the extended ("table")
  /// case view, keyed by the screen's stable id (`overdue`,
  /// `daily_cause_list`, `upcoming`) and holding the folded courts' ids. A
  /// court not listed opens expanded, which is the app default; the choice is
  /// the screen's, so folding a court on Daily Cause List leaves Overdue
  /// Dates' copy of it open.
  final Map<String, List<String>> caseTableCollapsedCourts;

  /// Default landing page route name.
  final String defaultLandingPage;

  /// App-wide font size step in logical pixels, added to every text size.
  ///
  /// 0 means the sizes the app ships with, so every install starts unmodified.
  /// See [fontSizeStepMin] and [fontSizeStepMax] for the bounds.
  final int fontSizeStep;

  /// Whether upcoming-case notifications are enabled for this user.
  final bool notificationEnabled;

  /// Preferred notification time of day in minutes since midnight.
  final int? notificationTime;

  /// Default notification day offset before a hearing.
  final int notificationDayOffset;

  /// Available notification offsets selected in per-user settings.
  final List<int> notificationDefaultOffsets;

  /// Whether the user finished the OEM battery/auto-start setup guide.
  ///
  /// Until this is true the Notifications screen keeps showing the plan's
  /// non-intrusive "notifications may not work reliably" banner.
  final bool notificationSetupDone;

  /// Whether the guide has already opened by itself on this device.
  ///
  /// Keeps the first-launch offer to exactly one showing, whatever the user did
  /// with it (a skip still leaves [notificationSetupDone] false, so the banner
  /// keeps nudging without the screen ever reappearing unbidden).
  final bool notificationGuideShown;

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
    this.caseListDisplayModes = const {},
    this.bottomNavTabs = const [
      'overdue',
      'daily_cause_list',
      'active',
      'upcoming',
    ],
    this.bottomNavOrder = const [],
    this.sideNavOptions = const {},
    this.caseTableColumnWidths = const {},
    this.caseTableCollapsedCourts = const {},
    this.defaultLandingPage = 'all_cases',
    this.fontSizeStep = 0,
    this.notificationEnabled = false,
    this.notificationTime,
    this.notificationDayOffset = 1,
    this.notificationDefaultOffsets = const [1],
    this.notificationSetupDone = false,
    this.notificationGuideShown = false,
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
    caseListDisplayModes: caseListDisplayModes,
    bottomNavTabs: bottomNavTabs,
    bottomNavOrder: bottomNavOrder,
    sideNavOptions: sideNavOptions,
    caseTableColumnWidths: caseTableColumnWidths,
    caseTableCollapsedCourts: caseTableCollapsedCourts,
    defaultLandingPage: defaultLandingPage,
    fontSizeStep: fontSizeStep,
    notificationEnabled: notificationEnabled,
    notificationTime: notificationTime,
    notificationDayOffset: notificationDayOffset,
    notificationDefaultOffsets: notificationDefaultOffsets,
    notificationSetupDone: notificationSetupDone,
    notificationGuideShown: notificationGuideShown,
    language: language,
    backupNudge: backupNudge,
    lastAddCaseHigherLowerCourt: higherLowerCourt,
    lastAddCaseDivision: division,
    lastAddCaseDistrict: district,
  );

  /// Creates a copy with the given fields replaced.
  UserSettings copyWith({
    bool? isPremium,
    int? upcomingCasesPeriod,
    String? caseListDisplayMode,
    Map<String, String>? caseListDisplayModes,
    List<String>? bottomNavTabs,
    List<String>? bottomNavOrder,
    Map<String, dynamic>? sideNavOptions,
    Map<String, double>? caseTableColumnWidths,
    Map<String, List<String>>? caseTableCollapsedCourts,
    String? defaultLandingPage,
    int? fontSizeStep,
    bool? notificationEnabled,
    int? notificationTime,
    int? notificationDayOffset,
    List<int>? notificationDefaultOffsets,
    bool? notificationSetupDone,
    bool? notificationGuideShown,
    String? language,
    Map<String, dynamic>? backupNudge,
  }) => UserSettings(
    isPremium: isPremium ?? this.isPremium,
    upcomingCasesPeriod: upcomingCasesPeriod ?? this.upcomingCasesPeriod,
    caseListDisplayMode: caseListDisplayMode ?? this.caseListDisplayMode,
    caseListDisplayModes: caseListDisplayModes ?? this.caseListDisplayModes,
    bottomNavTabs: bottomNavTabs ?? this.bottomNavTabs,
    bottomNavOrder: bottomNavOrder ?? this.bottomNavOrder,
    sideNavOptions: sideNavOptions ?? this.sideNavOptions,
    caseTableColumnWidths: caseTableColumnWidths ?? this.caseTableColumnWidths,
    caseTableCollapsedCourts:
        caseTableCollapsedCourts ?? this.caseTableCollapsedCourts,
    defaultLandingPage: defaultLandingPage ?? this.defaultLandingPage,
    fontSizeStep: fontSizeStep ?? this.fontSizeStep,
    notificationEnabled: notificationEnabled ?? this.notificationEnabled,
    notificationTime: notificationTime ?? this.notificationTime,
    notificationDayOffset: notificationDayOffset ?? this.notificationDayOffset,
    notificationDefaultOffsets:
        notificationDefaultOffsets ?? this.notificationDefaultOffsets,
    notificationSetupDone: notificationSetupDone ?? this.notificationSetupDone,
    notificationGuideShown: notificationGuideShown ?? this.notificationGuideShown,
    language: language ?? this.language,
    backupNudge: backupNudge ?? this.backupNudge,
    lastAddCaseHigherLowerCourt: lastAddCaseHigherLowerCourt,
    lastAddCaseDivision: lastAddCaseDivision,
    lastAddCaseDistrict: lastAddCaseDistrict,
  );

  /// Converts settings to a JSON-serializable map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'upcoming_cases_period': upcomingCasesPeriod,
    'case_list_display_mode': caseListDisplayMode,
    'case_list_display_modes': caseListDisplayModes,
    'bottom_nav_tabs': bottomNavTabs,
    'bottom_nav_order': bottomNavOrder,
    'side_nav_options': sideNavOptions,
    'case_table_column_widths': caseTableColumnWidths,
    'case_table_collapsed_courts': caseTableCollapsedCourts,
    'default_landing_page': defaultLandingPage,
    'font_size_step': fontSizeStep,
    'notification_enabled': notificationEnabled,
    'notification_day_offset': notificationDayOffset,
    'notification_default_offsets': notificationDefaultOffsets,
    'notification_setup_done': notificationSetupDone,
    'notification_guide_shown': notificationGuideShown,
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
        notificationEnabled: row.notificationEnabled,
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
    final rawOrder = json['bottom_nav_order'];
    final rawModes = json['case_list_display_modes'];
    final rawWidths = json['case_table_column_widths'];
    final rawCollapsed = json['case_table_collapsed_courts'];

    return UserSettings(
      upcomingCasesPeriod:
          (json['upcoming_cases_period'] as num?)?.toInt() ?? 7,
      caseListDisplayMode:
          json['case_list_display_mode'] as String? ?? 'compact',
      caseListDisplayModes: rawModes is Map
          ? {
              for (final entry in rawModes.entries)
                if (entry.value is String)
                  '${entry.key}': entry.value as String,
            }
          : const {},
      bottomNavTabs: tabs,
      bottomNavOrder: rawOrder is List<dynamic>
          ? rawOrder.cast<String>()
          : const [],
      sideNavOptions: json['side_nav_options'] is Map<String, dynamic>
          ? json['side_nav_options'] as Map<String, dynamic>
          : const {},
      caseTableColumnWidths: rawWidths is Map
          ? {
              for (final entry in rawWidths.entries)
                if (entry.value is num)
                  '${entry.key}': (entry.value as num).toDouble(),
            }
          : const {},
      caseTableCollapsedCourts: rawCollapsed is Map
          ? {
              for (final entry in rawCollapsed.entries)
                if (entry.value is List)
                  '${entry.key}': (entry.value as List)
                      .whereType<String>()
                      .toList(),
            }
          : const {},
      defaultLandingPage:
          json['default_landing_page'] as String? ?? 'all_cases',
      fontSizeStep: clampFontSizeStep(
        (json['font_size_step'] as num?)?.toInt() ?? 0,
      ),
      notificationEnabled:
          json['notification_enabled'] as bool? ?? row.notificationEnabled,
      notificationTime: row.notificationTime,
      notificationDayOffset:
          (json['notification_day_offset'] as num?)?.toInt() ?? 1,
      notificationDefaultOffsets: _readOffsets(
        row.notificationDefaultOffsets ?? json['notification_default_offsets'],
        fallback: (json['notification_day_offset'] as num?)?.toInt() ?? 1,
      ),
      notificationSetupDone: json['notification_setup_done'] as bool? ?? false,
      notificationGuideShown:
          json['notification_guide_shown'] as bool? ?? false,
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
      notificationEnabled: Value(settings.notificationEnabled),
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
