/// Subscription menu screen: the plan, the plans and the ledger.
///
/// Moved out of Account & Profile into its own Settings entry directly under
/// **Firm** (user request, 0.0.701), so the account's billing is one tap from
/// the Settings list. The rows keep the rules they had there: **Manage Plan**
/// for an account that owns its plan and **Firm Plan** for a chamber member —
/// with the chamber's subtitle — **Subscription Plans** for every account
/// (read-only for a member), and **Subscription History** only for an account
/// whose own ledger it is.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../accounts_and_profile/data/account_mode.dart';
import 'settings_menu_card.dart';
import 'settings_sub_page_modal.dart';

/// The Subscription page behind the Settings row.
class SubscriptionMenuScreen extends ConsumerWidget {
  const SubscriptionMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    // A chamber member reads the chamber's plan, and the ledger is not theirs.
    final isMember = ref.watch(firmMemberProvider);

    return SettingsSubPageModal(
      title: l.settingsSubscription_title,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          SettingsMenuCard(
            icon: Icons.star_outline,
            title: isMember
                ? l.settingsSubscription_firmPlanTitle
                : l.settingsSubscription_managePlanTitle,
            subtitle: isMember
                ? l.settingsAccountProfile_firmPlanSubtitle
                : l.settingsAccountProfile_managePlanSubtitle,
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
