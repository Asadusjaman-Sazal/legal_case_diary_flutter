/// Edit Court Names screen.
///
/// Supreme Court names are split into the two divisions that actually hold
/// them — Appellate Division and High Court Division — and Lower Courts steps
/// into the division → district → court category walkthrough. Mirrors
/// `settings_editCourtSteps_editCourtNamesCategory`.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/pre_seeded_data.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../settings_menu_card.dart';
import '../settings_sub_page_modal.dart';

/// A card row for one court grouping, optionally carrying the labels the next
/// screen needs.
class _CourtGroupCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String route;
  final Map<String, String> query;

  /// Localization key of the court category the card opens; handed to the next
  /// screen through the route so its header can name the category.
  final String? categoryNameKey;

  const _CourtGroupCard({
    required this.icon,
    required this.title,
    required this.route,
    this.subtitle,
    this.query = const {},
    this.categoryNameKey,
  });

  @override
  Widget build(BuildContext context) {
    final uri = query.isEmpty
        ? route
        : Uri(path: route, queryParameters: query).toString();
    // Shared sub-menu card, so this screen matches the Account & Profile card.
    return SettingsMenuCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () => context.push(uri, extra: categoryNameKey),
    );
  }
}

/// Court Names entry screen.
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
          // The Supreme Court's own two divisions, each listing the court names
          // the Add/Edit Case form offers for it.
          _CourtGroupCard(
            icon: Icons.account_balance_outlined,
            title: l.courtCategory_appellateDivision,
            route: AppRoutes.settingsCourtList,
            query: const {
              'higherLower': higherCourtsOption,
              'category': appellateDivisionId,
            },
            categoryNameKey: 'courtCategory_appellateDivision',
          ),
          const SizedBox(height: AppSpacing.sm),
          _CourtGroupCard(
            icon: Icons.gavel_outlined,
            title: l.courtCategory_highCourtDivision,
            route: AppRoutes.settingsCourtList,
            query: const {
              'higherLower': higherCourtsOption,
              'category': highCourtDivisionId,
            },
            categoryNameKey: 'courtCategory_highCourtDivision',
          ),
          const SizedBox(height: AppSpacing.sm),
          _CourtGroupCard(
            icon: Icons.account_tree_outlined,
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
