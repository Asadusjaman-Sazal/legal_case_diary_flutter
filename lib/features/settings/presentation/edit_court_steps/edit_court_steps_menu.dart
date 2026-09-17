/// Edit Court/Steps menu: entry screen with the two editing surfaces.
///
/// Both rows are [SettingsMenuCard]s, so this sub-menu matches the Account &
/// Profile menu card size.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../settings_menu_card.dart';
import '../settings_sub_page_modal.dart';

/// Edit Court/Steps main menu.
class EditCourtStepsMenu extends StatelessWidget {
  const EditCourtStepsMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SettingsSubPageModal(
      title: l.settingsScreen_editCourtSteps,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          SettingsMenuCard(
            icon: Icons.account_tree_outlined,
            title: l.settingsEditCourtSteps_lowerCourtCategories,
            subtitle: l.settingsEditCourtSteps_lowerCourtCategoriesSubtitle,
            onTap: () => context.push(AppRoutes.settingsLowerCourtCategories),
          ),
          const SizedBox(height: AppSpacing.sm),
          SettingsMenuCard(
            icon: Icons.gavel_outlined,
            title: l.settingsEditCourtSteps_courtNamesCategories,
            subtitle: l.settingsEditCourtSteps_courtNamesCategoriesSubtitle,
            onTap: () => context.push(AppRoutes.settingsEditCourtNamesCategory),
          ),
          const SizedBox(height: AppSpacing.sm),
          SettingsMenuCard(
            icon: Icons.category_outlined,
            title: l.settingsEditCourtSteps_editItemTypes,
            subtitle: l.settingsEditCourtSteps_editItemTypesSubtitle,
            onTap: () => context.push(AppRoutes.settingsCourtNamesSteps),
          ),
        ],
      ),
    );
  }
}
