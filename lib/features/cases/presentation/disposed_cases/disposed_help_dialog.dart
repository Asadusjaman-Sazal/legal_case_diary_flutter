/// Help dialog for the Disposed Cases screen.
///
/// Mirrors the mockup's "How to set a case as disposed?" window, but replaces
/// the static Bengali keyword list with the disposed steps grouped by court
/// category, sourced live from [disposedStepsByCategory] in
/// [pre_seeded_data.dart] so edits there are reflected here.
library;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/pre_seeded_data.dart';
import '../../../../core/l10n/generated/app_localizations.dart';

/// Shows the "How to set a case as disposed?" help dialog.
Future<void> showDisposedHelpDialog(BuildContext context) => showDialog<void>(
      context: context,
      builder: (context) => const _DisposedHelpDialog(),
    );

class _DisposedHelpDialog extends StatelessWidget {
  const _DisposedHelpDialog();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius * 2),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 384,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.disposedCasesScreen_helpTitle,
                style: AppTypography.titleLg,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l.disposedCasesScreen_helpBody,
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.justify,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        l.disposedCasesScreen_disposedSteps,
                        style: AppTypography.titleMd,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...disposedStepsByCategory.map(
                        (category) => _CategorySteps(
                          label: _categoryLabel(l, category.categoryId),
                          steps: category.steps,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _CategorySteps(
                        label: l.disposedCasesScreen_appellateHighCourtDivision,
                        steps: disposedResultTermLabels,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                ),
                child: Text(l.disposedCasesScreen_gotIt),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySteps extends StatelessWidget {
  const _CategorySteps({required this.label, required this.steps});

  final String label;
  final List<DisposedStepLabels> steps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: steps
                .map(
                  (step) => Chip(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.surfaceContainerLow,
                    label: Text(
                      step.bn.isNotEmpty ? '${step.en} (${step.bn})' : step.en,
                      style: AppTypography.labelMd,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// Resolves a court-category stable ID to its localized display label.
String _categoryLabel(AppLocalizations l, String categoryId) =>
    switch (categoryId) {
      appellateDivisionId => l.courtCategory_appellateDivision,
      highCourtDivisionId => l.courtCategory_highCourtDivision,
      districtCourtsCivilId => l.lowerCourtCategory_districtCourtsCivil,
      districtSessionsCriminalId =>
        l.lowerCourtCategory_districtSessionsCriminal,
      metropolitanSessionsJudgeCriminalId =>
        l.lowerCourtCategory_metropolitanSessionsJudgeCriminal,
      chiefJudicialMagistrateId =>
        l.lowerCourtCategory_chiefJudicialMagistrate,
      chiefMetropolitanMagistrateId =>
        l.lowerCourtCategory_chiefMetropolitanMagistrate,
      executiveMagistrateId => l.lowerCourtCategory_executiveMagistrate,
      _ => categoryId,
    };
