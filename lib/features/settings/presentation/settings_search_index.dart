/// Every Settings label and action that lives below the main Settings list.
///
/// The main search used to match only the eleven top-level rows, so a setting
/// three or four taps deep ("Cancel Subscription", "Backup to Google Drive",
/// "Font Size", "Dissolve Firm") could not be found at all. This index carries
/// those labels with the path that leads to them and the screen that holds
/// them; the main screen matches the label and the path, shows the breadcrumb
/// and pushes the route. Entries the account cannot see are not built, so the
/// results never offer an action the screens hide.
library;

import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';

/// One searchable Settings label, its breadcrumb and the screen to open.
class SettingsSearchEntry {
  /// Creates one entry.
  const SettingsSearchEntry({
    required this.label,
    required this.icon,
    required this.route,
    required this.path,
    this.keywords = const <String>[],
  });

  /// The visible label or button text.
  final String label;

  /// The leading icon in a result row.
  final IconData icon;

  /// The screen that contains the label.
  final String route;

  /// The breadcrumb, starting at Settings and ending at the containing screen.
  final List<String> path;

  /// Extra English search terms for a label whose wording does not cover them
  /// (for example "sign out" for Logout). Never shown.
  final List<String> keywords;

  /// How well this entry matches [query], or null when it does not.
  ///
  /// A direct label match outranks a keyword, and a parent's name ranks last, so
  /// a search for "plan" puts Manage Plan above every entry merely filed under
  /// a subscription screen.
  int? scoreFor(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;
    final label = this.label.toLowerCase();
    if (label == q) return 0;
    if (label.startsWith(q)) return 1;
    if (label.contains(q)) return 2;
    if (keywords.any((keyword) => keyword.toLowerCase().contains(q))) return 2;
    final parents = path.skip(1).join(' ').toLowerCase();
    if (parents.contains(q)) return 3;
    return null;
  }
}

/// Builds the deep index for the account's current state.
///
/// [firmMode] is a chamber account, [firmMember] an associate/viewer,
/// [premium] a live entitlement, [canOpenManageAssociates] the account menu's
/// own gate for that row, [canManageFirm] ownership of a chamber, and
/// [showDevices] the tier's multi-device gate.
List<SettingsSearchEntry> buildSettingsSearchIndex({
  required AppLocalizations l,
  required bool firmMode,
  required bool firmMember,
  required bool premium,
  required bool canOpenManageAssociates,
  required bool canManageFirm,
  required bool showDevices,
  required bool isAdmin,
}) {
  final settings = l.settingsScreen_title;
  final account = l.settingsScreen_accountAndProfile;
  final accountSection = l.settingsAccountProfile_sectionAccount;
  final profile = l.settingsScreen_profile;
  final manageAccount = l.settingsScreen_manageAccount;
  final appLock = l.settingsAppLock_title;
  final devices = l.devices_title;
  final subscription = l.settingsSubscription_title;
  final managePlan = l.settingsSubscription_managePlanTitle;
  final firm = l.settingsFirm_title;
  final associates = l.manageAssociates_title;
  final notifications = l.settingsScreen_notifications;
  final language = l.settingsScreen_language;
  final viewSettings = l.settingsScreen_viewSettings;
  final editCourt = l.settingsScreen_editCourtSteps;
  final itemTypes = l.settingsEditCourtSteps_editItemTypes;
  final onlineSync = l.settingsScreen_onlineSync;
  final backup = l.settingsScreen_backupAndRestore;
  final about = l.settingsScreen_about;
  final support = l.settingsAbout_support;

  SettingsSearchEntry e(
    String label,
    IconData icon,
    String route,
    List<String> path, {
    List<String> keywords = const <String>[],
  }) => SettingsSearchEntry(
    label: label,
    icon: icon,
    route: route,
    path: path,
    keywords: keywords,
  );

  return <SettingsSearchEntry>[
    // -----------------------------------------------------------------------
    // Account & Profile
    // -----------------------------------------------------------------------
    e(l.settingsScreen_profile, Icons.person_outline, AppRoutes.settingsProfile, [
      settings,
      account,
    ]),
    e(l.settingsProfile_editTitle, Icons.edit_outlined, AppRoutes.settingsProfile, [
      settings,
      account,
      profile,
    ]),
    e(
      l.settingsScreen_manageAccount,
      Icons.manage_accounts_outlined,
      AppRoutes.settingsManageAccount,
      [settings, account],
    ),
    e(l.settingsAppLock_title, Icons.lock_outline, AppRoutes.settingsAppLock, [
      settings,
      account,
    ], keywords: const ['pin', 'fingerprint', 'biometric']),
    if (showDevices)
      e(l.devices_title, Icons.devices_outlined, AppRoutes.settingsDevices, [
        settings,
        account,
      ], keywords: const ['phone']),

    // Subscription — its own Settings entry, directly under Firm (0.0.701).
    e(
      l.settingsSubscription_title,
      Icons.workspace_premium_outlined,
      AppRoutes.settingsSubscription,
      [settings],
    ),
    e(
      l.settingsSubscription_managePlanTitle,
      Icons.star_outline,
      AppRoutes.settingsSubscriptionDetails,
      [settings, subscription],
      keywords: const ['billing'],
    ),
    e(
      l.settingsManageAccount_purchaseNewSubscription,
      Icons.add_shopping_cart_outlined,
      AppRoutes.paywall,
      [settings, subscription],
      keywords: const ['buy plan', 'upgrade'],
    ),
    if (!firmMember)
      e(l.payments_historyTitle, Icons.history, AppRoutes.settingsSubscriptionHistory, [
        settings,
        subscription,
      ]),
    // Firm is its own Settings entry, offered to every account.
    e(l.settingsFirm_title, Icons.apartment_outlined, AppRoutes.settingsFirm, [
      settings,
    ]),
    if (canOpenManageAssociates)
      e(l.manageAssociates_title, Icons.groups_outlined, AppRoutes.settingsManageAssociates, [
        settings,
        firm,
      ]),

    // Manage Plan actions
    if (premium && !firmMember) ...[
      e(l.settingsSubscription_renewSubscription, Icons.autorenew, AppRoutes.paywall, [
        settings,
        subscription,
        managePlan,
      ]),
      e(
        l.settingsSubscription_cancelSubscription,
        Icons.cancel_outlined,
        AppRoutes.settingsSubscriptionDetails,
        [settings, subscription, managePlan],
        keywords: const ['cancel plan'],
      ),
    ],

    // Manage Account actions
    e(
      l.settingsManageAccount_changePassword,
      Icons.password,
      AppRoutes.settingsChangePassword,
      [settings, account, accountSection, manageAccount],
      keywords: const ['password'],
    ),
    e(
      l.settingsManageAccount_logout,
      Icons.logout,
      AppRoutes.settingsManageAccount,
      [settings, account, accountSection, manageAccount],
      keywords: const ['sign out'],
    ),
    e(
      l.settingsManageAccount_deleteAccount,
      Icons.delete_forever_outlined,
      AppRoutes.settingsDeleteAccount,
      [settings, account, accountSection, manageAccount],
      keywords: const ['remove account'],
    ),
    if (!firmMode)
      e(
        premium
            ? l.settingsManageAccount_deleteLocalAndCloudData
            : l.settingsManageAccount_deleteLocalData,
        Icons.delete_sweep_outlined,
        AppRoutes.settingsManageAccount,
        [settings, account, accountSection, manageAccount],
        keywords: const ['erase data'],
      ),

    // App Lock actions
    e(
      l.settingsAppLock_setup,
      Icons.lock_open_outlined,
      AppRoutes.settingsAppLock,
      [settings, account, accountSection, appLock],
      keywords: const ['pin', 'fingerprint'],
    ),
    e(
      l.settingsAppLock_changePin,
      Icons.password,
      AppRoutes.settingsAppLock,
      [settings, account, accountSection, appLock],
      keywords: const ['pin'],
    ),
    e(
      l.settingsAppLock_turnOff,
      Icons.lock_outline,
      AppRoutes.settingsAppLock,
      [settings, account, accountSection, appLock],
    ),
    e(
      l.settingsAppLock_whenToAsk,
      Icons.schedule_outlined,
      AppRoutes.settingsAppLock,
      [settings, account, accountSection, appLock],
    ),
    e(
      l.settingsAppLock_enableFingerprint,
      Icons.fingerprint,
      AppRoutes.settingsAppLock,
      [settings, account, accountSection, appLock],
    ),

    if (showDevices)
      e(
        l.devices_remove,
        Icons.phonelink_erase_outlined,
        AppRoutes.settingsDevices,
        [settings, account, accountSection, devices],
      ),

    // Manage Associates
    if (canManageFirm) ...[
      e(
        l.manageAssociates_addAssociate,
        Icons.person_add_alt_1_outlined,
        AppRoutes.settingsManageAssociates,
        [settings, firm, associates],
        keywords: const ['invite'],
      ),
      e(
        l.manageAssociates_changeLogo,
        Icons.image_outlined,
        AppRoutes.settingsManageAssociates,
        [settings, firm, associates],
      ),
      e(
        l.manageAssociates_removeLogo,
        Icons.hide_image_outlined,
        AppRoutes.settingsManageAssociates,
        [settings, firm, associates],
      ),
      e(
        l.manageAssociates_dissolveFirm,
        Icons.group_off_outlined,
        AppRoutes.settingsManageAssociates,
        [settings, firm, associates],
      ),
      e(
        l.manageAssociates_permissionsTitle,
        Icons.admin_panel_settings_outlined,
        AppRoutes.settingsManageAssociates,
        [settings, firm, associates],
      ),
      e(
        l.manageAssociates_capacitySignOut,
        Icons.logout_outlined,
        AppRoutes.settingsManageAssociates,
        [settings, firm, associates],
      ),
      e(
        l.manageAssociates_capacityAdmit,
        Icons.login_outlined,
        AppRoutes.settingsManageAssociates,
        [settings, firm, associates],
      ),
      e(
        l.manageAssociates_removeAssociate,
        Icons.person_remove_alt_1_outlined,
        AppRoutes.settingsManageAssociates,
        [settings, firm, associates],
      ),
      e(
        l.manageAssociates_revokeInvite,
        Icons.link_off,
        AppRoutes.settingsManageAssociates,
        [settings, firm, associates],
      ),
    ],

    // -----------------------------------------------------------------------
    // Notifications
    // -----------------------------------------------------------------------
    e(
      l.settingsNotifications_statusLabel,
      Icons.notifications_active_outlined,
      AppRoutes.settingsNotifications,
      [settings, notifications],
    ),
    e(
      l.settingsNotifications_dayOffsetLabel,
      Icons.event_repeat_outlined,
      AppRoutes.settingsNotifications,
      [settings, notifications],
    ),
    e(
      l.settingsNotifications_timeLabel,
      Icons.schedule_outlined,
      AppRoutes.settingsNotifications,
      [settings, notifications],
      keywords: const ['reminder time'],
    ),
    if (isAdmin)
      e(
        l.settingsNotifications_paymentAlertsLabel,
        Icons.admin_panel_settings_outlined,
        AppRoutes.settingsNotifications,
        [settings, notifications],
        keywords: const ['admin'],
      ),
    e(
      l.clientNotification_settingsTitle,
      Icons.message_outlined,
      AppRoutes.settingsNotifications,
      [settings, notifications],
    ),
    e(
      l.clientNotification_automatedLabel,
      Icons.auto_awesome_outlined,
      AppRoutes.settingsNotifications,
      [settings, notifications],
    ),
    e(
      l.clientNotification_askLabel,
      Icons.help_outline,
      AppRoutes.settingsNotifications,
      [settings, notifications],
    ),
    e(
      l.clientNotification_channelLabel,
      Icons.send_outlined,
      AppRoutes.settingsNotifications,
      [settings, notifications],
    ),
    e(
      l.clientNotification_templateLabel,
      Icons.description_outlined,
      AppRoutes.settingsNotifications,
      [settings, notifications],
    ),
    e(
      l.clientNotification_contactLabel,
      Icons.phone_outlined,
      AppRoutes.settingsNotifications,
      [settings, notifications],
      keywords: const ['phone number'],
    ),
    e(
      l.settingsNotifications_sendTest,
      Icons.notification_add_outlined,
      AppRoutes.settingsNotifications,
      [settings, notifications],
      keywords: const ['test alert'],
    ),
    e(
      l.settingsNotifications_setupGuide,
      Icons.battery_charging_full_outlined,
      AppRoutes.settingsBatterySetupGuide,
      [settings, notifications],
      keywords: const ['battery', 'auto-start'],
    ),

    // -----------------------------------------------------------------------
    // Language
    // -----------------------------------------------------------------------
    e(
      l.settingsScreen_languageEnglish,
      Icons.language,
      AppRoutes.settingsLanguage,
      [settings, language],
    ),
    e(
      l.settingsScreen_languageBengali,
      Icons.language,
      AppRoutes.settingsLanguage,
      [settings, language],
    ),

    // -----------------------------------------------------------------------
    // View Settings
    // -----------------------------------------------------------------------
    e(
      l.settingsViewSettings_upcomingPeriod,
      Icons.date_range_outlined,
      AppRoutes.settingsViewSettings,
      [settings, viewSettings],
    ),
    e(
      l.settingsViewSettings_caseListMode,
      Icons.view_list_outlined,
      AppRoutes.settingsViewSettings,
      [settings, viewSettings],
    ),
    e(
      l.settingsViewSettings_sectionFontSize,
      Icons.format_size,
      AppRoutes.settingsViewSettings,
      [settings, viewSettings],
      keywords: const ['text size'],
    ),
    e(
      l.settingsViewSettings_bottomTabs,
      Icons.view_agenda_outlined,
      AppRoutes.settingsViewSettings,
      [settings, viewSettings],
    ),
    e(
      l.settingsViewSettings_sideNav,
      Icons.view_sidebar_outlined,
      AppRoutes.settingsViewSettings,
      [settings, viewSettings],
    ),
    e(
      l.settingsViewSettings_landingPage,
      Icons.home_outlined,
      AppRoutes.settingsViewSettings,
      [settings, viewSettings],
      keywords: const ['start screen'],
    ),

    // -----------------------------------------------------------------------
    // Edit Court/Steps
    // -----------------------------------------------------------------------
    e(
      l.settingsEditCourtSteps_lowerCourtCategories,
      Icons.account_balance_outlined,
      AppRoutes.settingsEditCourtSteps,
      [settings, editCourt],
    ),
    e(
      l.settingsEditCourtSteps_courtNamesCategories,
      Icons.gavel_outlined,
      AppRoutes.settingsEditCourtSteps,
      [settings, editCourt],
    ),
    e(
      l.settingsEditCourtSteps_editItemTypes,
      Icons.category_outlined,
      AppRoutes.settingsEditCourtSteps,
      [settings, editCourt],
    ),
    e(
      l.settingsEditItems_caseTypes,
      Icons.category_outlined,
      AppRoutes.settingsCourtNamesSteps,
      [settings, editCourt, itemTypes],
    ),
    e(
      l.settingsEditItems_steps,
      Icons.format_list_numbered,
      AppRoutes.settingsCourtNamesSteps,
      [settings, editCourt, itemTypes],
    ),
    e(
      l.settingsEditItems_onBehalf,
      Icons.people_outline,
      AppRoutes.settingsCourtNamesSteps,
      [settings, editCourt, itemTypes],
    ),

    // -----------------------------------------------------------------------
    // Online Sync
    // -----------------------------------------------------------------------
    e(
      l.settingsOnlineSync_syncNow,
      Icons.sync,
      AppRoutes.settingsOnlineSync,
      [settings, onlineSync],
    ),
    e(
      l.settingsOnlineSync_enableSync,
      Icons.sync_outlined,
      AppRoutes.settingsOnlineSync,
      [settings, onlineSync],
    ),
    e(
      l.settingsOnlineSync_disableSync,
      Icons.sync_disabled,
      AppRoutes.settingsOnlineSync,
      [settings, onlineSync],
    ),
    e(
      l.settingsOnlineSync_pendingSyncTitle,
      Icons.cloud_off_outlined,
      AppRoutes.settingsSyncStatus,
      [settings, onlineSync],
    ),

    // -----------------------------------------------------------------------
    // Backup & Restore
    // -----------------------------------------------------------------------
    if (!firmMember) ...[
      e(
        l.settingsBackupRestore_backupLocal,
        Icons.phone_android_outlined,
        AppRoutes.settingsBackupRestore,
        [settings, backup],
      ),
      e(
        l.settingsBackupRestore_backupExcel,
        Icons.table_chart_outlined,
        AppRoutes.settingsBackupRestore,
        [settings, backup],
      ),
      e(
        l.settingsBackupRestore_backupDrive,
        Icons.cloud_upload_outlined,
        AppRoutes.settingsBackupRestore,
        [settings, backup],
      ),
      e(
        l.settingsBackupRestore_restore,
        Icons.restore,
        AppRoutes.settingsBackupRestore,
        [settings, backup],
        keywords: const ['import'],
      ),
      e(
        l.settingsBackupRestore_sectionEncryption,
        Icons.enhanced_encryption_outlined,
        AppRoutes.settingsBackupRestore,
        [settings, backup],
        keywords: const ['passphrase', 'password'],
      ),
      e(
        l.settingsBackupRestore_sectionAutomaticBackup,
        Icons.schedule_outlined,
        AppRoutes.settingsBackupRestore,
        [settings, backup],
      ),
      e(
        l.settingsBackupRestore_excelTemplate,
        Icons.download_outlined,
        AppRoutes.settingsBackupRestore,
        [settings, backup],
      ),
      e(
        l.settingsBackupRestore_lastSuccessfulBackup,
        Icons.history_toggle_off,
        AppRoutes.settingsBackupRestore,
        [settings, backup],
      ),
    ],

    // -----------------------------------------------------------------------
    // About, Support
    // -----------------------------------------------------------------------
    e(
      l.settingsAbout_moreAboutApp,
      Icons.info_outline,
      AppRoutes.settingsMoreAbout,
      [settings, about],
    ),
    e(
      l.settingsAbout_privacyPolicy,
      Icons.privacy_tip_outlined,
      AppRoutes.settingsPrivacyPolicy,
      [settings, about],
    ),
    e(
      l.settingsAbout_termsOfService,
      Icons.description_outlined,
      AppRoutes.settingsTermsOfService,
      [settings, about],
    ),
    e(
      l.settingsUpdate_entry,
      Icons.system_update_outlined,
      AppRoutes.settingsAboutUpdate,
      [settings, about],
    ),
    e(
      l.settingsDiagnostics_title,
      Icons.bug_report_outlined,
      AppRoutes.settingsDiagnostics,
      [settings, support],
    ),
  ];
}
