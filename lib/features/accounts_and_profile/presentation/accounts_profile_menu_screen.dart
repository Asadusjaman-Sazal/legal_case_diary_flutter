/// Accounts profile menu screen: main sub-menu for Accounts & Profile.
/// UI shell (Task 12 Phase 2); full account wiring in Part B / Task 17.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';

/// A large tappable card inside the Accounts & Profile menu.
class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  const _MenuButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.surfaceContainer),
        ),
        child: InkWell(
          onTap: () => context.push(route),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 28),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.bodyLg),
                      const SizedBox(height: AppSpacing.xs),
                      Text(subtitle, style: AppTypography.bodySm),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.tertiary),
              ],
            ),
          ),
        ),
      );
}

/// Accounts & Profile menu: Profile + Manage Account buttons.
class AccountsProfileMenuScreen extends StatelessWidget {
  const AccountsProfileMenuScreen({super.key});

  @override
  Widget build(BuildContext context) => SettingsSubPageModal(
        title: 'Account & Profile',
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: const [
            _MenuButton(
              icon: Icons.person_outline,
              title: 'Profile',
              subtitle: 'Your name, bar association, and membership details',
              route: AppRoutes.settingsProfile,
            ),
            SizedBox(height: AppSpacing.sm),
            _MenuButton(
              icon: Icons.manage_accounts_outlined,
              title: 'Manage Account',
              subtitle: 'Password, subscription, and account settings',
              route: AppRoutes.settingsManageAccount,
            ),
          ],
        ),
      );
}
