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

/// Channel chosen for an automated client message.
const String clientNotificationChannelWhatsApp = 'whatsapp';

/// Channel chosen for an automated client message.
const String clientNotificationChannelSms = 'sms';

/// Template length chosen for an automated client message.
const String clientNotificationTemplateLong = 'long';

/// Template length chosen for an automated client message.
const String clientNotificationTemplateShort = 'short';

/// The remembered answer given when the lawyer ticks "Remember my choice".
const String clientNotificationRememberedYes = 'yes';

/// The remembered answer given when the lawyer ticks "Remember my choice".
const String clientNotificationRememberedNo = 'no';

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
  /// Dates' copy of it open. Only the folds made today count — see
  /// [caseTableCollapsedDays].
  final Map<String, List<String>> caseTableCollapsedCourts;

  /// Bangladesh civil day (start-of-day epoch-ms) on which each screen's fold
  /// choice in [caseTableCollapsedCourts] was last made, keyed by the same
  /// screen ids. A fold is one day's choice: a screen whose stamp is not today
  /// reads as fully expanded, so every grouped case list opens a new day with
  /// every court showing. The stamp is dropped together with the screen's fold
  /// list once that list is emptied.
  final Map<String, int> caseTableCollapsedDays;

  /// Default landing page route name, chosen on View Settings.
  ///
  /// A fresh install lands on Daily Cause List: it is the screen the day's work
  /// starts from, and the value plan §10.1 specifies. `all_cases` was only ever
  /// an on-device testing default and is no longer the shipped one.
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

  /// Whether this account wants a push when an admin's payment request is
  /// waiting.
  ///
  /// Per-user, never firm-shared (Rev 2.4 scope contract). The sender reads the
  /// synced column server-side, so switching it off silences a closed app too.
  final bool paymentAlertsEnabled;

  /// The admin's own reject messages: the wording they saved from the Reject the
  /// Payment window, offered beside the app's own pre-fill messages.
  ///
  /// An administrator's own working list, per-user and never firm-shared (Rev
  /// 2.4 scope contract). It travels inside [toJson]'s per-user blob, which the
  /// preference sync already carries to the account, so the wording follows the
  /// admin to another device without a column of its own —
  /// `ponytail: the blob is enough while this is a handful of sentences; a
  /// second reader on the server, or a much longer list, is when it earns a
  /// column of its own.
  final List<String> adminRejectMessages;

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

  /// Whether the user marked the setup guide's **auto-start** step as done.
  ///
  /// The other two steps are read from the phone; Android exposes no API for the
  /// auto-start / startup-manager setting (it is an OEM feature, not a
  /// permission), so the user's own confirmation is the only record of it and is
  /// kept per-user like the rest of the guide's state.
  final bool notificationAutoStartDone;

  /// Selected UI language code.
  final String language;

  /// Whether a hearing-date change offers to notify the client automatically.
  ///
  /// Off by default: the feature opens another app, so it only runs once the
  /// lawyer turns it on in Settings → Notifications.
  final bool automatedNotificationEnabled;

  /// Whether the client message waits for the confirmation dialog.
  ///
  /// When false, a changed date opens the chosen app without asking; a
  /// remembered answer still wins (see [automatedNotificationRememberedAnswer]).
  final bool automatedNotificationAskBeforeSending;

  /// Channel for the automated client message: [clientNotificationChannelWhatsApp]
  /// or [clientNotificationChannelSms].
  final String automatedNotificationChannel;

  /// The answer the lawyer asked the app to remember: empty (ask every time),
  /// [clientNotificationRememberedYes] or [clientNotificationRememberedNo].
  ///
  /// Changing [automatedNotificationAskBeforeSending] clears it, so the new
  /// setting is what applies.
  final String automatedNotificationRememberedAnswer;

  /// Template length for WhatsApp: [clientNotificationTemplateLong] or
  /// [clientNotificationTemplateShort].
  final String automatedNotificationWhatsAppTemplate;

  /// Template length for SMS: [clientNotificationTemplateLong] or
  /// [clientNotificationTemplateShort].
  final String automatedNotificationSmsTemplate;

  /// The call-back number printed in the long client message, digits only.
  ///
  /// Empty falls back to the Profile mobile; when that is empty too, the
  /// Contact line is left out of the message.
  final String notificationContactNumber;

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
    this.caseTableCollapsedDays = const {},
    this.defaultLandingPage = 'daily_cause_list',
    this.fontSizeStep = 0,
    this.notificationEnabled = false,
    this.notificationTime,
    this.notificationDayOffset = 1,
    this.notificationDefaultOffsets = const [1],
    this.paymentAlertsEnabled = true,
    this.adminRejectMessages = const [],
    this.notificationSetupDone = false,
    this.notificationGuideShown = false,
    this.notificationAutoStartDone = false,
    this.language = 'en',
    this.automatedNotificationEnabled = false,
    this.automatedNotificationAskBeforeSending = true,
    this.automatedNotificationChannel = clientNotificationChannelWhatsApp,
    this.automatedNotificationRememberedAnswer = '',
    this.automatedNotificationWhatsAppTemplate = clientNotificationTemplateLong,
    this.automatedNotificationSmsTemplate = clientNotificationTemplateShort,
    this.notificationContactNumber = '',
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
    caseTableCollapsedDays: caseTableCollapsedDays,
    defaultLandingPage: defaultLandingPage,
    fontSizeStep: fontSizeStep,
    notificationEnabled: notificationEnabled,
    notificationTime: notificationTime,
    notificationDayOffset: notificationDayOffset,
    notificationDefaultOffsets: notificationDefaultOffsets,
    paymentAlertsEnabled: paymentAlertsEnabled,
    notificationSetupDone: notificationSetupDone,
    notificationGuideShown: notificationGuideShown,
    notificationAutoStartDone: notificationAutoStartDone,
    language: language,
    automatedNotificationEnabled: automatedNotificationEnabled,
    automatedNotificationAskBeforeSending: automatedNotificationAskBeforeSending,
    automatedNotificationChannel: automatedNotificationChannel,
    automatedNotificationRememberedAnswer:
        automatedNotificationRememberedAnswer,
    automatedNotificationWhatsAppTemplate:
        automatedNotificationWhatsAppTemplate,
    automatedNotificationSmsTemplate: automatedNotificationSmsTemplate,
    notificationContactNumber: notificationContactNumber,
    backupNudge: backupNudge,
    adminRejectMessages: adminRejectMessages,
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
    Map<String, int>? caseTableCollapsedDays,
    String? defaultLandingPage,
    int? fontSizeStep,
    bool? notificationEnabled,
    int? notificationTime,
    int? notificationDayOffset,
    List<int>? notificationDefaultOffsets,
    bool? paymentAlertsEnabled,
    List<String>? adminRejectMessages,
    bool? notificationSetupDone,
    bool? notificationGuideShown,
    bool? notificationAutoStartDone,
    String? language,
    bool? automatedNotificationEnabled,
    bool? automatedNotificationAskBeforeSending,
    String? automatedNotificationChannel,
    String? automatedNotificationRememberedAnswer,
    String? automatedNotificationWhatsAppTemplate,
    String? automatedNotificationSmsTemplate,
    String? notificationContactNumber,
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
    caseTableCollapsedDays:
        caseTableCollapsedDays ?? this.caseTableCollapsedDays,
    defaultLandingPage: defaultLandingPage ?? this.defaultLandingPage,
    fontSizeStep: fontSizeStep ?? this.fontSizeStep,
    notificationEnabled: notificationEnabled ?? this.notificationEnabled,
    notificationTime: notificationTime ?? this.notificationTime,
    notificationDayOffset: notificationDayOffset ?? this.notificationDayOffset,
    notificationDefaultOffsets:
        notificationDefaultOffsets ?? this.notificationDefaultOffsets,
    paymentAlertsEnabled: paymentAlertsEnabled ?? this.paymentAlertsEnabled,
    adminRejectMessages: adminRejectMessages ?? this.adminRejectMessages,
    notificationSetupDone: notificationSetupDone ?? this.notificationSetupDone,
    notificationGuideShown: notificationGuideShown ?? this.notificationGuideShown,
    notificationAutoStartDone:
        notificationAutoStartDone ?? this.notificationAutoStartDone,
    language: language ?? this.language,
    automatedNotificationEnabled:
        automatedNotificationEnabled ?? this.automatedNotificationEnabled,
    automatedNotificationAskBeforeSending:
        automatedNotificationAskBeforeSending ??
        this.automatedNotificationAskBeforeSending,
    automatedNotificationChannel:
        automatedNotificationChannel ?? this.automatedNotificationChannel,
    automatedNotificationRememberedAnswer:
        automatedNotificationRememberedAnswer ??
        this.automatedNotificationRememberedAnswer,
    automatedNotificationWhatsAppTemplate:
        automatedNotificationWhatsAppTemplate ??
        this.automatedNotificationWhatsAppTemplate,
    automatedNotificationSmsTemplate:
        automatedNotificationSmsTemplate ?? this.automatedNotificationSmsTemplate,
    notificationContactNumber:
        notificationContactNumber ?? this.notificationContactNumber,
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
    'case_table_collapsed_days': caseTableCollapsedDays,
    'default_landing_page': defaultLandingPage,
    'font_size_step': fontSizeStep,
    'notification_enabled': notificationEnabled,
    'notification_day_offset': notificationDayOffset,
    'notification_default_offsets': notificationDefaultOffsets,
    'payment_alerts_enabled': paymentAlertsEnabled,
    'admin_reject_messages': adminRejectMessages,
    'notification_setup_done': notificationSetupDone,
    'notification_guide_shown': notificationGuideShown,
    'notification_auto_start_done': notificationAutoStartDone,
    'automated_notification_enabled': automatedNotificationEnabled,
    'automated_notification_ask_before_sending':
        automatedNotificationAskBeforeSending,
    'automated_notification_channel': automatedNotificationChannel,
    'automated_notification_remembered_answer':
        automatedNotificationRememberedAnswer,
    'automated_notification_whatsapp_template':
        automatedNotificationWhatsAppTemplate,
    'automated_notification_sms_template': automatedNotificationSmsTemplate,
    'notification_contact_number': notificationContactNumber,
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
        paymentAlertsEnabled: row.paymentAlertsEnabled,
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
    final rawCollapsedDays = json['case_table_collapsed_days'];

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
      caseTableCollapsedDays: rawCollapsedDays is Map
          ? {
              for (final entry in rawCollapsedDays.entries)
                if (entry.value is num)
                  '${entry.key}': (entry.value as num).toInt(),
            }
          : const {},
      defaultLandingPage:
          json['default_landing_page'] as String? ?? 'daily_cause_list',
      fontSizeStep: clampFontSizeStep(
        (json['font_size_step'] as num?)?.toInt() ?? 0,
      ),
      notificationEnabled:
          json['notification_enabled'] as bool? ?? row.notificationEnabled,
      // Read the same way the toggle above is: the blob first, the column as the
      // fallback, so a row written before this field existed still answers.
      paymentAlertsEnabled:
          json['payment_alerts_enabled'] as bool? ?? row.paymentAlertsEnabled,
      notificationTime: row.notificationTime,
      adminRejectMessages: json['admin_reject_messages'] is List
          ? (json['admin_reject_messages'] as List)
                .whereType<String>()
                .toList(growable: false)
          : const <String>[],
      notificationDayOffset:
          (json['notification_day_offset'] as num?)?.toInt() ?? 1,
      notificationDefaultOffsets: _readOffsets(
        row.notificationDefaultOffsets ?? json['notification_default_offsets'],
        fallback: (json['notification_day_offset'] as num?)?.toInt() ?? 1,
      ),
      notificationSetupDone: json['notification_setup_done'] as bool? ?? false,
      notificationGuideShown:
          json['notification_guide_shown'] as bool? ?? false,
      notificationAutoStartDone:
          json['notification_auto_start_done'] as bool? ?? false,
      automatedNotificationEnabled:
          json['automated_notification_enabled'] as bool? ?? false,
      automatedNotificationAskBeforeSending:
          json['automated_notification_ask_before_sending'] as bool? ?? true,
      automatedNotificationChannel: _readChoice(
        json['automated_notification_channel'],
        <String>{
          clientNotificationChannelWhatsApp,
          clientNotificationChannelSms,
        },
        clientNotificationChannelWhatsApp,
      ),
      automatedNotificationRememberedAnswer: _readChoice(
        json['automated_notification_remembered_answer'],
        <String>{
          clientNotificationRememberedYes,
          clientNotificationRememberedNo,
          '',
        },
        '',
      ),
      automatedNotificationWhatsAppTemplate: _readChoice(
        json['automated_notification_whatsapp_template'],
        <String>{
          clientNotificationTemplateLong,
          clientNotificationTemplateShort,
        },
        clientNotificationTemplateLong,
      ),
      automatedNotificationSmsTemplate: _readChoice(
        json['automated_notification_sms_template'],
        <String>{
          clientNotificationTemplateLong,
          clientNotificationTemplateShort,
        },
        clientNotificationTemplateShort,
      ),
      notificationContactNumber: json['notification_contact_number'] is String
          ? (json['notification_contact_number'] as String).replaceAll(
              RegExp('[^0-9]'),
              '',
            )
          : '',
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

  /// One of [allowed], or [fallback] for a missing, old or hand-edited value.
  ///
  /// The client-notification choices are stored as strings in the synced blob,
  /// so an unknown value must read as the safe default rather than reach a
  /// builder that has no case for it.
  static String _readChoice(
    Object? raw,
    Set<String> allowed,
    String fallback,
  ) => raw is String && allowed.contains(raw) ? raw : fallback;

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
      paymentAlertsEnabled: Value(settings.paymentAlertsEnabled),
      language: Value(settings.language),
      updatedAt: Value(now),
    );
    await _dao.upsert(companion);
  }
}
