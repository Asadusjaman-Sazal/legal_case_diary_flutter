/// Manage Account screen: account settings per the
/// `settings_manageProfileAccount` mockup.
///
/// Task 12 Phase 2 (Part A): UI shell with offline placeholder data; actions
/// show an offline notice. Real account/auth wiring lands in Part B (Task 17).
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';

/// Manage Account screen matching `settings_manageProfileAccount\code.html`.
class ManageAccountScreen extends StatelessWidget {
  const ManageAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const name = 'Asadusjaman';
    const email = 'advocate.asad@law.com';

    final accountItems = [
      _AccountItem(
        icon: Icons.lock_outline,
        title: 'Change Password',
        onTap: () => _offlineNotice(context),
      ),
      _AccountItem(
        icon: Icons.star_outline,
        title: 'Subscription Details',
        onTap: () => _offlineNotice(context),
      ),
      _AccountItem(
        icon: Icons.add_shopping_cart_outlined,
        title: 'Purchase New Subscription',
        onTap: () => _offlineNotice(context),
      ),
    ];

    return SettingsSubPageModal(
      title: 'Manage Account',
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.edgeMargin,
          AppSpacing.md,
          AppSpacing.edgeMargin,
          AppSpacing.xl,
        ),
        child: Column(
          children: [
            // Profile summary card.
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppSpacing.md),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceVariant,
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: AppTypography.headlineMd
                            .copyWith(color: AppColors.primary),
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    name,
                    style: AppTypography.titleLg
                        .copyWith(color: AppColors.primary),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    email,
                    style: AppTypography.bodyMd
                        .copyWith(color: AppColors.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: () => _offlineNotice(context),
                    icon: const Icon(Icons.logout, size: 20),
                    label: const Text('Logout'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.onSurfaceVariant,
                      backgroundColor: AppColors.surfaceContainer,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                        side: BorderSide(color: AppColors.outlineVariant),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.xl),
            // Account settings list.
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.sm,
                  bottom: AppSpacing.xs,
                ),
                child: Text(
                  'Account Settings',
                  style: AppTypography.labelLg
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ),
            ),
            ...accountItems.map((item) => Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.sm),
                  child: item,
                )),
            SizedBox(height: AppSpacing.xl),
            // Destructive action.
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(AppSpacing.md),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.2),
                ),
              ),
              child: InkWell(
                onTap: () => _offlineNotice(context),
                borderRadius: BorderRadius.circular(AppSpacing.md),
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceContainerLowest,
                        ),
                        child: Center(
                          child: Icon(Icons.delete_outline,
                              color: AppColors.error),
                        ),
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delete Account',
                              style: AppTypography.titleMd.copyWith(
                                  color: AppColors.onErrorContainer),
                            ),
                            SizedBox(height: AppSpacing.xs),
                            Text(
                              'This action cannot be undone',
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.error.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _offlineNotice(BuildContext context) {
    // Part A: offline placeholder. Task 17 wires real auth actions.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Available after sign-in (Task 17)')),
    );
  }
}

/// A single row in the "Account Settings" list.
class _AccountItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _AccountItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainer,
                ),
                child: Center(
                  child: Icon(icon, color: AppColors.primary),
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.titleMd
                      .copyWith(color: AppColors.onSurface),
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.outlineVariant),
            ],
          ),
        ),
      ),
    );
  }
}
