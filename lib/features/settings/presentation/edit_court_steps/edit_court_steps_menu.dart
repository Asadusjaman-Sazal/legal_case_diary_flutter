/// Edit Court/Steps menu: entry screen with the two editing surfaces.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/app_router.dart';
import '../settings_sub_page_modal.dart';

/// A single tappable row in the Edit Court/Steps menu.
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  const _MenuRow({
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
        child: ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(title, style: AppTypography.bodyLg),
          subtitle: Text(subtitle, style: AppTypography.bodySm),
          trailing: const Icon(Icons.chevron_right, color: AppColors.tertiary),
          onTap: () => context.push(route),
        ),
      );
}

/// Edit Court/Steps main menu.
class EditCourtStepsMenu extends StatelessWidget {
  const EditCourtStepsMenu({super.key});

  @override
  Widget build(BuildContext context) => SettingsSubPageModal(
        title: 'Edit Court/Steps',
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: const [
            _MenuRow(
              icon: Icons.category_outlined,
              title: 'Edit Case Types, Step etc',
              subtitle: 'Manage case types, procedural steps, and on-behalf roles',
              route: AppRoutes.settingsCourtNamesSteps,
            ),
            SizedBox(height: AppSpacing.sm),
            _MenuRow(
              icon: Icons.gavel_outlined,
              title: 'Edit Court Names & Categories',
              subtitle: 'Supreme Court divisions and district lower courts',
              route: AppRoutes.settingsEditCourtNamesCategory,
            ),
          ],
        ),
      );
}
