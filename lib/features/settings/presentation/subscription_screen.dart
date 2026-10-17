/// Subscription screen: what this account's subscription is, and where to buy
/// another.
///
/// Both rows were Manage Account's **Subscription Details** and **Purchase New
/// Subscription**, moved here unchanged -- the same icons, the same wording, the
/// same destinations -- because an account's billing does not belong under its
/// profile, and the Settings list has a place for it after Online Sync.
/// **Subscription Details** is now a sub-page of its own
/// ([SubscriptionDetailsScreen]); **Purchase New Subscription** still opens the
/// paywall directly.
///
/// **A chamber member sees Subscription Details alone (Phase 9).** The chamber's
/// plan is the one running, the plans are the owner's to buy, and the server
/// refuses a member's submission whether or not this row is drawn. The owner
/// keeps both rows — this is where a chamber is renewed.
///
/// **Mockup departure (approved).** There is no `settings_subscription` mockup,
/// so this body is the two rows above moved verbatim; correspondingly Manage
/// Account keeps only Change Password, where its own binding mockup still draws
/// all three rows. Recorded in `docs/implementation_plan.md` and the task files.
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

/// The Subscription screen: the two rows moved out of Manage Account.
class SubscriptionScreen extends ConsumerWidget {
  /// Creates the screen.
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    // A member has no plan of their own to buy (Phase 9); the owner still does.
    final isMember = ref.watch(firmMemberProvider);
    final items = [
      SettingsSubMenuRow(
        icon: Icons.star_outline,
        title: l.settingsManageAccount_subscriptionDetails,
        // A sub-page, not a sheet: what this screen shows is a plan, an expiry
        // and a purchase history, which is reference material rather than a
        // choice, and it now has room for the ledger table.
        onTap: () => context.push(AppRoutes.settingsSubscriptionDetails),
      ),
      if (!isMember)
        SettingsSubMenuRow(
          icon: Icons.add_shopping_cart_outlined,
          title: l.settingsManageAccount_purchaseNewSubscription,
          onTap: () => context.push(AppRoutes.paywall),
        ),
    ];

    return SettingsSubPageModal(
      title: l.settingsSubscription_title,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.edgeMargin,
          AppSpacing.md,
          AppSpacing.edgeMargin,
          AppSpacing.xl,
        ),
        child: Column(
          children: [
            for (final item in items)
              Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: item,
              ),
          ],
        ),
      ),
    );
  }
}
