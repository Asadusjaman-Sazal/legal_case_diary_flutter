/// Accounts profile menu screen: main sub-menu for Accounts & Profile.
/// UI shell (Task 12 Phase 2); full account wiring in Part B / Task 17.
///
/// The body is grouped into three labelled sections — **Profile**, **Account**
/// and **Firm** — using the shared [SettingsSectionLabel] the other sectioned
/// Settings screens use, so the menu reads as a set of account-level groups
/// rather than one flat list. Every entry still renders through
/// [SettingsMenuCard], the shared card the other sub-menus use, which is what
/// keeps this screen the size reference for the whole Settings surface.
///
/// **Subscription** moved here from the main Settings list, so an account's
/// billing sits with the account it belongs to. **Security** is new and holds
/// **Change Password**, moved out of Manage Account; Manage Account itself keeps
/// the profile summary, Logout and Delete Account.
///
/// Task 20 Phase 1 adds the final entry, **Manage Associates**, and it is
/// conditional on purpose: a **premium** individual sees it (adding the first
/// associate is what creates the firm, and that transition is premium
/// server-side), a firm owner sees it whatever their plan (the server still lets
/// an owner manage the firm they already have), and an associate or viewer does
/// not — the screen behind it is owner-only server-side. The **Firm** section
/// label is drawn only with the row, so a hidden row never leaves a bare header.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../settings/presentation/settings_controls.dart';
import '../../settings/presentation/settings_menu_card.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';
import '../data/account_mode.dart';

/// Accounts & Profile menu, grouped into Profile, Account and Firm sections.
class AccountsProfileMenuScreen extends ConsumerWidget {
  const AccountsProfileMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    // A free individual is not offered the entry: `ensure_firm` refuses a
    // non-premium caller, so the row could only advertise something the account
    // cannot do. A firm owner keeps it after a lapse, because the firm and its
    // roster are still theirs — only a *new* firm is premium-gated.
    final showManageAssociates =
        ref.watch(canOpenManageAssociatesProvider) &&
        (ref.watch(firmModeProvider) ||
            ref.watch(premiumAccessProvider).value == true);

    return SettingsSubPageModal(
      title: l.settingsScreen_accountAndProfile,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Profile: the user's own details.
          SettingsSectionLabel(l.settingsAccountProfile_sectionProfile),
          const SizedBox(height: AppSpacing.sm),
          SettingsMenuCard(
            icon: Icons.person_outline,
            title: l.settingsScreen_profile,
            subtitle: l.settingsAccountProfile_profileSubtitle,
            onTap: () => context.push(AppRoutes.settingsProfile),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Account: the account-level actions and settings.
          SettingsSectionLabel(l.settingsAccountProfile_sectionAccount),
          const SizedBox(height: AppSpacing.sm),
          SettingsMenuCard(
            icon: Icons.manage_accounts_outlined,
            title: l.settingsScreen_manageAccount,
            subtitle: l.settingsAccountProfile_manageAccountSubtitle,
            onTap: () => context.push(AppRoutes.settingsManageAccount),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Billing, moved here from the main Settings list, so the account and
          // the way to pay for it sit together.
          SettingsMenuCard(
            icon: Icons.workspace_premium_outlined,
            title: l.settingsSubscription_title,
            subtitle: l.settingsAccountProfile_subscriptionSubtitle,
            onTap: () => context.push(AppRoutes.settingsSubscription),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Sign-in security, holding Change Password moved out of Manage
          // Account.
          SettingsMenuCard(
            icon: Icons.shield_outlined,
            title: l.settingsAccountProfile_security,
            subtitle: l.settingsAccountProfile_securitySubtitle,
            onTap: () => context.push(AppRoutes.settingsSecurity),
          ),
          if (showManageAssociates) ...[
            const SizedBox(height: AppSpacing.lg),
            // Firm: only meaningful with the row below it.
            SettingsSectionLabel(l.settingsAccountProfile_sectionFirm),
            const SizedBox(height: AppSpacing.sm),
            SettingsMenuCard(
              icon: Icons.groups_outlined,
              title: l.manageAssociates_title,
              subtitle: l.settingsAccountProfile_manageAssociatesSubtitle,
              onTap: () => context.push(AppRoutes.settingsManageAssociates),
            ),
          ],
        ],
      ),
    );
  }
}
