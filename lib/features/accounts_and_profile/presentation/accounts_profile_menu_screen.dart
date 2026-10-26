/// Accounts profile menu screen: main sub-menu for Accounts & Profile.
/// UI shell (Task 12 Phase 2); full account wiring in Part B / Task 17.
///
/// The body is grouped into three labelled sections — **Profile**, **Account**
/// and **Subscription** — using the shared [SettingsSectionLabel] the other
/// sectioned Settings screens use, so the menu reads as a set of account-level
/// groups rather than one flat list. Every entry still renders through
/// [SettingsMenuCard], the shared card the other sub-menus use, which is what
/// keeps this screen the size reference for the whole Settings surface.
///
/// **Subscription** moved here from the main Settings list, so an account's
/// billing sits with the account it belongs to. Manage Account holds the
/// account's own actions — Logout, **Change Password** and Delete Account — and
/// is where Change Password came back to (0.0.411): the Security sub-page that
/// briefly held it is gone, because a whole screen for one row earned nothing.
///
/// **Firm** moved out to its own Settings entry at 0.0.663 (user request): the
/// Settings list now offers **Firm** to every account, and its page
/// (`firm_menu_screen.dart`) keeps the rows' old visibility — Manage Firm /
/// Create a Firm for an individual or owner, Delete Requests in firm mode.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../payments/data/payment_plans.dart';
import '../../settings/presentation/settings_controls.dart';
import '../../settings/presentation/settings_menu_card.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';
import '../data/account_mode.dart';

/// Accounts & Profile menu, grouped into Profile, Account and Subscription.
class AccountsProfileMenuScreen extends ConsumerWidget {
  const AccountsProfileMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    // App Lock and Devices live here with the account they belong to (0.0.611,
    // user request). Devices is only worth a row where the plan holds more than
    // one device: Free has no sync and Starter holds one, so it starts at Pro.
    final showDevices =
        ref.watch(currentTierProvider).rank > SubscriptionTier.starter.rank;
    // A chamber member may read the plans but cannot buy (0.0.626, user
    // request), and the ledger is the account's own, so History is the one
    // Subscription row a member is not offered.
    final isMember = ref.watch(firmMemberProvider);

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
          // The app's own lock, and the plan's device slots. Both moved here from
          // Manage Account (0.0.611, user request).
          SettingsMenuCard(
            icon: Icons.key_outlined,
            title: l.settingsAppLock_title,
            subtitle: l.settingsAccountProfile_appLockSubtitle,
            onTap: () => context.push(AppRoutes.settingsAppLock),
          ),
          if (showDevices) ...[
            const SizedBox(height: AppSpacing.sm),
            SettingsMenuCard(
              icon: Icons.devices_outlined,
              title: l.devices_title,
              subtitle: l.devices_subtitle,
              onTap: () => context.push(AppRoutes.settingsDevices),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          // Subscription: the plan, the store and the ledger, together
          // (0.0.624, user request).
          SettingsSectionLabel(l.settingsSubscription_title),
          const SizedBox(height: AppSpacing.sm),
          SettingsMenuCard(
            icon: Icons.star_outline,
            title: l.settingsSubscription_managePlanTitle,
            subtitle: l.settingsAccountProfile_managePlanSubtitle,
            onTap: () => context.push(AppRoutes.settingsSubscriptionDetails),
          ),
          const SizedBox(height: AppSpacing.sm),
          SettingsMenuCard(
            icon: Icons.add_shopping_cart_outlined,
            title: l.settingsManageAccount_purchaseNewSubscription,
            subtitle: l.settingsAccountProfile_subscriptionPlansSubtitle,
            onTap: () => context.push(AppRoutes.paywall),
          ),
          if (!isMember) ...[
            const SizedBox(height: AppSpacing.sm),
            SettingsMenuCard(
              icon: Icons.history,
              title: l.payments_historyTitle,
              subtitle: l.settingsAccountProfile_subscriptionHistorySubtitle,
              onTap: () => context.push(AppRoutes.settingsSubscriptionHistory),
            ),
          ],
        ],
      ),
    );
  }
}
