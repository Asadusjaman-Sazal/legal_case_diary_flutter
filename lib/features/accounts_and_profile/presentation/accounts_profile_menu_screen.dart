/// Accounts profile menu screen: main sub-menu for Accounts & Profile.
/// UI shell (Task 12 Phase 2); full account wiring in Part B / Task 17.
///
/// The body is grouped into four labelled sections — **Profile**, **Account**,
/// **Subscription** and **Firm** — using the shared [SettingsSectionLabel] the other sectioned
/// Settings screens use, so the menu reads as a set of account-level groups
/// rather than one flat list. Every entry still renders through
/// [SettingsMenuCard], the shared card the other sub-menus use, which is what
/// keeps this screen the size reference for the whole Settings surface.
///
/// **Subscription** moved here from the main Settings list, so an account's
/// billing sits with the account it belongs to. Manage Account holds the
/// account's own actions — Logout, **Change Password** and Delete Account — and
/// is where Change Password came back to (0.0.411): the Security sub-page that
/// briefly held it is gone, because a whole screen for one row earned nothing.
///
/// Task 20 Phase 1 adds the final entry, **Manage Associates**, and it is
/// conditional on purpose: a **premium** individual sees it (adding the first
/// associate is what creates the firm, and that transition is premium
/// server-side), a firm owner sees it whatever their plan (the server still lets
/// an owner manage the firm they already have), and an associate or viewer does
/// not — the screen behind it is owner-only server-side. The **Firm** section
/// label is drawn only with its rows, so a hidden row never leaves a bare header.
///
/// **Delete Requests** moved here from the main Settings list (0.0.649, user
/// request), directly after Manage Associates: the queue belongs to the firm it
/// is raised in, not among the app's own preferences. It keeps the rule it had —
/// offered in firm mode only, because an individual owns their own diary and has
/// nobody to ask — and it keeps its badge, which counts what is waiting on this
/// account: the reviewer's queue, or the requester's unread decisions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../payments/data/payment_plans.dart';
import '../../settings/presentation/delete_requests_viewmodel.dart';
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
    // App Lock and Devices live here with the account they belong to (0.0.611,
    // user request). Devices is only worth a row where the plan holds more than
    // one device: Free has no sync and Starter holds one, so it starts at Pro.
    final showDevices =
        ref.watch(currentTierProvider).rank > SubscriptionTier.starter.rank;
    // A chamber member may read the plans but cannot buy (0.0.626, user
    // request), and the ledger is the account's own, so History is the one
    // Subscription row a member is not offered.
    final isMember = ref.watch(firmMemberProvider);
    // Delete Requests belongs to the firm and is offered to every member of one
    // (0.0.649): a reviewer opens the queue in front of them, a member without
    // delete permission opens their own requests and the decisions on them.
    final showDeleteRequests = ref.watch(firmModeProvider);
    final deleteRequestsCount = ref.watch(deleteRequestsBadgeCountProvider);

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
          if (showManageAssociates || showDeleteRequests) ...[
            const SizedBox(height: AppSpacing.lg),
            // Firm: only meaningful with a row below it.
            SettingsSectionLabel(l.settingsAccountProfile_sectionFirm),
            const SizedBox(height: AppSpacing.sm),
            if (showManageAssociates)
              SettingsMenuCard(
                icon: Icons.groups_outlined,
                title: l.manageAssociates_title,
                subtitle: l.settingsAccountProfile_manageAssociatesSubtitle,
                onTap: () => context.push(AppRoutes.settingsManageAssociates),
              ),
            // Directly after Manage Associates (user request, 0.0.649).
            if (showDeleteRequests) ...[
              if (showManageAssociates) const SizedBox(height: AppSpacing.sm),
              SettingsMenuCard(
                icon: Icons.delete_outline,
                title: l.deleteRequests_title,
                // Every card on this page carries a line saying what it holds,
                // so this one does too (user request).
                subtitle: l.settingsAccountProfile_deleteRequestsSubtitle,
                // The badge travels with the row: it is the count of what is
                // waiting on this account, and the screen it opens is where it
                // is cleared. Passed as the trailing widget so the chevron it
                // replaces is drawn back beside it.
                trailing: deleteRequestsCount > 0
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _CountPill(count: deleteRequestsCount),
                          const SizedBox(width: AppSpacing.sm),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.tertiary,
                          ),
                        ],
                      )
                    : null,
                onTap: () => context.push(AppRoutes.settingsDeleteRequests),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// The count pill on a menu card that is waiting for the user.
///
/// Moved here with the Delete Requests row from the main Settings list, where it
/// was the only badge in that list.
class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  /// How many things are waiting.
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: AppColors.error,
      borderRadius: BorderRadius.circular(AppSpacing.md),
    ),
    child: Text(
      '$count',
      style: AppTypography.labelMd.copyWith(color: AppColors.onError),
    ),
  );
}
