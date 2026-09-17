/// Edit Court Names & Categories screen.
/// Supreme Court → Appellate/High Court division court lists; Lower Courts →
/// division picker. Mirrors `settings_editCourtSteps_editCourtNamesCategory`.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../settings_menu_card.dart';
import '../settings_sub_page_modal.dart';

/// A card row for a top-level court grouping.
class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final Map<String, String>? query;

  const _CategoryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    this.query,
  });

  @override
  Widget build(BuildContext context) {
    final uri = Uri(path: route, queryParameters: query ?? {}).toString();
    // Shared sub-menu card, so this screen matches the Account & Profile card.
    return SettingsMenuCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () => context.push(uri),
    );
  }
}

/// Court Names & Categories entry screen.
class EditCourtNamesCategoryScreen extends StatelessWidget {
  const EditCourtNamesCategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SettingsSubPageModal(
      title: l.settingsEditCourtNames_courtCategory,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _CategoryCard(
            icon: Icons.account_balance_outlined,
            title: l.settingsEditCourtNames_supremeCourt,
            subtitle: l.settingsEditCourtNames_supremeCourtSubtitle,
            route: AppRoutes.settingsCourtList,
            query: const {
              'higherLower': 'higher_courts',
              'category': 'appellate_division',
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          _CategoryCard(
            icon: Icons.gavel_outlined,
            title: l.settingsEditCourtNames_lowerCourts,
            subtitle: l.settingsEditCourtNames_lowerCourtsSubtitle,
            route: AppRoutes.settingsCourtCategory,
          ),
          const _SectionNote(),
        ],
      ),
    );
  }
}

/// "Quick Tip" footer shown below the category cards.
class _SectionNote extends StatelessWidget {
  const _SectionNote();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.settingsEditCourtNames_quickTip, style: AppTypography.bodyLg),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l.settingsEditCourtNames_quickTipBody,
            style: AppTypography.bodySm,
          ),
        ],
      ),
    );
  }
}
