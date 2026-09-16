/// Edit Court/Steps menu: entry screen with the two editing surfaces.
///
/// Both rows are [SettingsMenuCard]s, so this sub-menu matches the Account &
/// Profile menu card size.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/router/app_router.dart';
import '../settings_menu_card.dart';
import '../settings_sub_page_modal.dart';

/// Edit Court/Steps main menu.
class EditCourtStepsMenu extends StatelessWidget {
  const EditCourtStepsMenu({super.key});

  @override
  Widget build(BuildContext context) => SettingsSubPageModal(
        title: 'Edit Court/Steps',
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            SettingsMenuCard(
              icon: Icons.category_outlined,
              title: 'Edit Case Types, Step etc',
              subtitle:
                  'Manage case types, procedural steps, and on-behalf roles',
              onTap: () => context.push(AppRoutes.settingsCourtNamesSteps),
            ),
            const SizedBox(height: AppSpacing.sm),
            SettingsMenuCard(
              icon: Icons.gavel_outlined,
              title: 'Edit Court Names & Categories',
              subtitle: 'Supreme Court divisions and district lower courts',
              onTap: () =>
                  context.push(AppRoutes.settingsEditCourtNamesCategory),
            ),
          ],
        ),
      );
}
