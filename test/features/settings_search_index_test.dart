/// The deep Settings search index: deep labels, their paths, ranking and the
/// visibility rules that keep hidden settings out of the results.
library;

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_search_index.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('en'));

  List<SettingsSearchEntry> index({
    bool firmMode = true,
    bool firmMember = false,
    bool premium = true,
    bool canOpenManageAssociates = true,
    bool canManageFirm = true,
    bool showDevices = true,
    bool isAdmin = false,
  }) => buildSettingsSearchIndex(
    l: l,
    firmMode: firmMode,
    firmMember: firmMember,
    premium: premium,
    canOpenManageAssociates: canOpenManageAssociates,
    canManageFirm: canManageFirm,
    showDevices: showDevices,
    isAdmin: isAdmin,
  );

  SettingsSearchEntry entry(List<SettingsSearchEntry> entries, String label) =>
      entries.firstWhere((candidate) => candidate.label == label);

  test('finds labels three and four levels deep, with their path and route', () {
    final entries = index();

    final cancel = entry(entries, l.settingsSubscription_cancelSubscription);
    expect(cancel.route, AppRoutes.settingsSubscriptionDetails);
    // Subscription is its own Settings entry now (0.0.701), not Account &
    // Profile's subject.
    expect(cancel.path, <String>[
      l.settingsScreen_title,
      l.settingsSubscription_title,
      l.settingsSubscription_managePlanTitle,
    ]);
    expect(
      entry(entries, l.settingsSubscription_title).route,
      AppRoutes.settingsSubscription,
    );
    expect(
      entry(entries, l.settingsSubscription_title).path,
      <String>[l.settingsScreen_title],
    );

    final password = entry(
      entries,
      l.settingsManageAccount_changePassword,
    );
    expect(password.route, AppRoutes.settingsChangePassword);
    expect(password.path.last, l.settingsScreen_manageAccount);
    expect(password.path, contains(l.settingsAccountProfile_sectionAccount));

    expect(
      entry(entries, l.settingsBackupRestore_backupDrive).route,
      AppRoutes.settingsBackupRestore,
    );
    expect(
      entry(entries, l.settingsViewSettings_sectionFontSize).route,
      AppRoutes.settingsViewSettings,
    );
    expect(
      entry(entries, l.manageAssociates_dissolveFirm).route,
      AppRoutes.settingsManageAssociates,
    );
    // Firm is its own Settings entry, and its deep actions carry that path.
    final firm = entry(entries, l.settingsFirm_title);
    expect(firm.route, AppRoutes.settingsFirm);
    expect(firm.path, <String>[l.settingsScreen_title]);
    expect(
      entry(entries, l.manageAssociates_dissolveFirm).path,
      <String>[
        l.settingsScreen_title,
        l.settingsFirm_title,
        l.manageAssociates_title,
      ],
    );
  });

  test('a direct label outranks a parent path', () {
    final entries = index();
    final managePlan = entry(
      entries,
      l.settingsSubscription_managePlanTitle,
    );

    expect(managePlan.scoreFor('plan'), 2);
    expect(managePlan.scoreFor('subscription'), 3);
    expect(
      managePlan.scoreFor('plan'),
      lessThan(managePlan.scoreFor('subscription')!),
    );
    expect(managePlan.scoreFor('nothing-matches-this'), isNull);
  });

  test('a keyword finds a label whose wording differs', () {
    final entries = index();

    expect(
      entry(entries, l.settingsManageAccount_logout).scoreFor('sign out'),
      isNotNull,
    );
    expect(
      entry(entries, l.settingsViewSettings_sectionFontSize).scoreFor(
        'text size',
      ),
      isNotNull,
    );
    expect(
      entry(entries, l.settingsAppLock_title).scoreFor('fingerprint'),
      isNotNull,
    );
  });

  test('the admin-only notification setting is indexed only for an admin', () {
    final adminLabel = l.settingsNotifications_paymentAlertsLabel;
    expect(index().any((e) => e.label == adminLabel), isFalse);
    expect(index(isAdmin: true).any((e) => e.label == adminLabel), isTrue);
  });

  test('labels are unique so a result row can key on them', () {
    final labels = index().map((e) => e.label).toList();
    expect(labels.toSet().length, labels.length);
  });

  test('a member is not offered history, backup, plan actions or the roster',
      () {
    final member = index(
      firmMember: true,
      premium: false,
      canOpenManageAssociates: false,
      canManageFirm: false,
      showDevices: false,
    );

    expect(member.any((e) => e.label == l.payments_historyTitle), isFalse);
    expect(
      member.any((e) => e.label == l.settingsBackupRestore_backupDrive),
      isFalse,
    );
    expect(
      member.any((e) => e.label == l.settingsSubscription_cancelSubscription),
      isFalse,
    );
    expect(
      member.any((e) => e.label == l.manageAssociates_dissolveFirm),
      isFalse,
    );
    expect(member.any((e) => e.label == l.devices_title), isFalse);

    // The screens a member may still open remain searchable.
    expect(
      member.any((e) => e.label == l.settingsSubscription_managePlanTitle),
      isTrue,
    );
    expect(
      member.any((e) => e.label == l.settingsManageAccount_changePassword),
      isTrue,
    );
    // The Firm entry itself is offered to every account (0.0.663).
    expect(
      member.any((e) => e.label == l.settingsFirm_title),
      isTrue,
    );
  });

  test('a premium individual sees the firm setup but not the roster actions',
      () {
    final individual = index(
      firmMode: false,
      canOpenManageAssociates: true,
      canManageFirm: false,
    );

    expect(
      individual.any((e) => e.label == l.manageAssociates_title),
      isTrue,
    );
    expect(
      individual.any((e) => e.label == l.manageAssociates_addAssociate),
      isFalse,
    );
    expect(
      individual.any((e) => e.label == l.settingsSubscription_cancelSubscription),
      isTrue,
    );
    expect(
      individual.any(
        (e) => e.label == l.settingsManageAccount_deleteLocalAndCloudData,
      ),
      isTrue,
    );
  });

  test('a free individual has the local-only delete label and no plan actions',
      () {
    final free = index(
      firmMode: false,
      premium: false,
      canOpenManageAssociates: false,
      canManageFirm: false,
      showDevices: false,
    );

    expect(
      free.any((e) => e.label == l.settingsSubscription_cancelSubscription),
      isFalse,
    );
    expect(
      free.any(
        (e) => e.label == l.settingsManageAccount_deleteLocalAndCloudData,
      ),
      isFalse,
    );
    expect(
      free.any((e) => e.label == l.settingsManageAccount_deleteLocalData),
      isTrue,
    );
  });
}
