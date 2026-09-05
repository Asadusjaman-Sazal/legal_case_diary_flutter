/// Court Names, Steps etc screen: all court categories as KanBan cards, each
/// offering Case Types / Steps / On Behalf management. The per-kind list is also
/// rendered by this route when `?kind=` and `?category=` query params are set.
/// Mirrors `settings_courtNamesSteps`.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/app_router.dart';
import '../settings_sub_page_modal.dart';

/// One of the three management kinds under a category.
enum _ItemKind { caseTypes, steps, onBehalf }

/// Local copy of the 8 canonical court categories (id + label).
const Map<String, String> _courtCategoryLabels = <String, String>{
  'appellate_division': 'Appellate Division',
  'high_court_division': 'High Court Division',
  'district_sessions_criminal': 'District & Sessions (Criminal)',
  'district_courts_civil': 'District Courts (Civil)',
  'chief_judicial_magistrate': 'Chief Judicial Magistrate',
  'chief_metropolitan_magistrate': 'Chief Metropolitan Magistrate',
  'executive_magistrate': 'Executive Magistrate',
  'tribunals': 'Tribunals',
};

/// Court Names, Steps etc entry screen (KanBan categories).
class CourtNamesStepsScreen extends StatelessWidget {
  const CourtNamesStepsScreen({super.key});

  @override
  Widget build(BuildContext context) => SettingsSubPageModal(
        title: 'Court Names, Steps etc',
        child: ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: _courtCategoryLabels.length,
          itemBuilder: (context, index) {
            final entry = _courtCategoryLabels.entries.elementAt(index);
            return _CategoryCard(categoryId: entry.key, label: entry.value);
          },
        ),
      );
}

/// A KanBan card showing a court category and its three management buttons.
class _CategoryCard extends StatelessWidget {
  final String categoryId;
  final String label;

  const _CategoryCard({required this.categoryId, required this.label});

  String _route(_ItemKind kind) {
    final kindParam = switch (kind) {
      _ItemKind.caseTypes => 'case_types',
      _ItemKind.steps => 'steps',
      _ItemKind.onBehalf => 'on_behalf',
    };
    return '${AppRoutes.settingsCourtNamesSteps}'
        '?kind=$kindParam&category=$categoryId';
  }

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.surfaceContainer),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.bodyLg),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _ActionChip(
                    label: 'Case Types',
                    onTap: () => context.push(_route(_ItemKind.caseTypes)),
                  ),
                  _ActionChip(
                    label: 'Steps',
                    onTap: () => context.push(_route(_ItemKind.steps)),
                  ),
                  _ActionChip(
                    label: 'On Behalf',
                    onTap: () => context.push(_route(_ItemKind.onBehalf)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

/// Small filled action chip used inside a category card.
class _ActionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ActionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: AppTypography.bodySm.copyWith(color: AppColors.onPrimary),
          ),
        ),
      );
}
