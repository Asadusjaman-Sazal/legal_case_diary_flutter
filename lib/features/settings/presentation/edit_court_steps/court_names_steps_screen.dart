/// Court Names, Steps etc screen: the canonical court categories as collapsible
/// cards. A card normally shows only the category name; tapping it expands the
/// three management buttons (Case Types / Steps / On Behalf) below the name.
/// The per-kind list is also rendered by this route when `?kind=` and
/// `?category=` query params are set. Mirrors `settings_courtNamesSteps`.
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

/// One of the three management kinds under a category.
enum _ItemKind { caseTypes, steps, onBehalf }

/// Height of the three action buttons inside an expanded card.
///
/// Bigger than the pill chips they replaced, but shorter than the 56 px
/// full-width Settings button because three of them share one row.
const double _actionButtonHeight = 44.0;

/// Gap between the three action buttons, and between them and the card's name
/// row.
const double _actionButtonGap = AppSpacing.sm;

/// The categories listed on this screen, in [allCategoryIds] order: the two
/// higher-court divisions followed by the 6 lower-court categories. Both halves
/// come from the seeded hierarchy, so the list cannot drift from the data.
Map<String, String> _courtCategoryLabels(
  AppLocalizations l,
) => <String, String>{
  for (final id in allCategoryIds) id: _categoryLabel(l, id),
};

/// Localized name of a seeded court category; an unknown id is shown as-is.
String _categoryLabel(AppLocalizations l, String id) => switch (id) {
  appellateDivisionId => l.settingsCourtNamesSteps_catAppellateDivision,
  highCourtDivisionId => l.settingsCourtNamesSteps_catHighCourtDivision,
  districtCourtsCivilId => l.settingsCourtNamesSteps_catDistrictCivil,
  districtSessionsCriminalId => l.settingsCourtNamesSteps_catDistrictSessions,
  metropolitanSessionsJudgeCriminalId =>
    l.settingsCourtNamesSteps_catMetropolitanSessions,
  chiefJudicialMagistrateId => l.settingsCourtNamesSteps_catCjm,
  chiefMetropolitanMagistrateId => l.settingsCourtNamesSteps_catCmm,
  executiveMagistrateId => l.settingsCourtNamesSteps_catExecutive,
  _ => id,
};

/// Court Names, Steps etc entry screen (collapsible category cards).
class CourtNamesStepsScreen extends StatelessWidget {
  const CourtNamesStepsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final labels = _courtCategoryLabels(AppLocalizations.of(context));
    return SettingsSubPageModal(
      title: AppLocalizations.of(context).settingsCourtNamesSteps_title,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: labels.length,
        itemBuilder: (context, index) {
          final entry = labels.entries.elementAt(index);
          return _CategoryCard(categoryId: entry.key, label: entry.value);
        },
      ),
    );
  }
}

/// A collapsible court-category card.
///
/// Collapsed (the default) it is a single name row; tapping the card toggles it
/// open, which reveals the three management buttons and makes the card taller.
class _CategoryCard extends StatefulWidget {
  final String categoryId;
  final String label;

  const _CategoryCard({required this.categoryId, required this.label});

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _expanded = false;

  String _route(_ItemKind kind) {
    final kindParam = switch (kind) {
      _ItemKind.caseTypes => 'case_types',
      _ItemKind.steps => 'steps',
      _ItemKind.onBehalf => 'on_behalf',
    };
    return '${AppRoutes.settingsCourtNamesSteps}'
        '?kind=$kindParam&category=${widget.categoryId}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      elevation: 0,
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(settingsMenuCardRadius),
        side: BorderSide(color: AppColors.surfaceContainer),
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                // Floor keeps the collapsed card the same height as the other
                // Settings sub-menu cards.
                constraints: const BoxConstraints(
                  minHeight: settingsMenuCardRowHeight,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(widget.label, style: AppTypography.bodyLg),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.tertiary,
                    ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _expanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: _actionButtonGap),
                        child: Row(
                          children: [
                            Expanded(
                              child: _ActionButton(
                                label: l.settingsEditItems_caseTypes,
                                onTap: () =>
                                    context.push(_route(_ItemKind.caseTypes)),
                              ),
                            ),
                            const SizedBox(width: _actionButtonGap),
                            Expanded(
                              child: _ActionButton(
                                label: l.settingsEditItems_steps,
                                onTap: () =>
                                    context.push(_route(_ItemKind.steps)),
                              ),
                            ),
                            const SizedBox(width: _actionButtonGap),
                            Expanded(
                              child: _ActionButton(
                                label: l.settingsEditItems_onBehalf,
                                onTap: () =>
                                    context.push(_route(_ItemKind.onBehalf)),
                              ),
                            ),
                          ],
                        ),
                      )
                    // Full width even while collapsed, so the buttons only grow
                    // downwards when the card opens.
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the three management buttons inside an expanded category card.
///
/// Same shape as the card it sits in (rounded rectangle, not a pill) and
/// stretched to an equal share of the row, so the three fill the card's width
/// evenly.
class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _actionButtonHeight,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(settingsMenuCardRadius),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(settingsMenuCardRadius),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelLg.copyWith(color: AppColors.onPrimary),
        ),
      ),
    ),
  );
}
