/// Accounts profile menu screen: main sub-menu for Accounts & Profile.
/// UI shell (Task 12 Phase 2); full account wiring in Part B / Task 17.
///
/// This screen is the size reference for the Settings sub-menus: both entries
/// render through [SettingsMenuCard], the shared card the other sub-menus use.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../settings/presentation/settings_menu_card.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';

/// Accounts & Profile menu: Profile + Manage Account buttons.
class AccountsProfileMenuScreen extends StatelessWidget {
  const AccountsProfileMenuScreen({super.key});

  @override
  Widget build(BuildContext context) => SettingsSubPageModal(
        title: 'Account & Profile',
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            SettingsMenuCard(
              icon: Icons.person_outline,
              title: 'Profile',
              subtitle: 'Your name, bar association, and membership details',
              onTap: () => context.push(AppRoutes.settingsProfile),
            ),
            const SizedBox(height: AppSpacing.sm),
            SettingsMenuCard(
              icon: Icons.manage_accounts_outlined,
              title: 'Manage Account',
              subtitle: 'Password, subscription, and account settings',
              onTap: () => context.push(AppRoutes.settingsManageAccount),
            ),
          ],
        ),
      );
}
