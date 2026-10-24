/// Case Types, Steps etc screen: the canonical court categories as collapsible
/// cards. A card normally shows only the category name; tapping it expands the
/// management buttons (Case Types / Steps / On Behalf) below the name. The
/// higher-court divisions offer only Case Types and On Behalf: their cases use
/// the plain "Result" text box instead of steps.
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
Map<String, String> _courtCategoryLabels(AppLocalizations l) =>
    <String, String>{
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

/// The higher-court divisions have no procedural steps: their cases record the
/// outcome in the plain "Result" text box instead, so they offer no Steps
/// button.
bool _hasSteps(String categoryId) =>
    categoryId != appellateDivisionId && categoryId != highCourtDivisionId;

/// Case Types, Steps etc entry screen (collapsible category cards).
///
/// At most one card is open at a time, so the screen — not each card — keeps the
/// id of whichever card that is.
class CourtNamesStepsScreen extends StatefulWidget {
  const CourtNamesStepsScreen({super.key});

  @override
  State<CourtNamesStepsScreen> createState() => _CourtNamesStepsScreenState();
}

class _CourtNamesStepsScreenState extends State<CourtNamesStepsScreen> {
  /// The open card, or null when every card is collapsed.
  String? _expandedCategoryId;

  /// Opens [categoryId] and closes whichever card was open, if any; tapping the
  /// already-open card closes it.
  void _toggle(String categoryId) => setState(() {
    _expandedCategoryId = _expandedCategoryId == categoryId ? null : categoryId;
  });

  @override
  Widget build(BuildContext context) {
    final labels = _courtCategoryLabels(AppLocalizations.of(context));
    return SettingsSubPageModal(
      title: AppLocalizations.of(context).settingsCourtNamesSteps_title,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: labels.length,
        // The same 8 px between cards the Edit Court/Steps sub-menu keeps
        // between its SettingsMenuCards (user request, 0.0.612).
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final entry = labels.entries.elementAt(index);
          return _CategoryCard(
            categoryId: entry.key,
            label: entry.value,
            isExpanded: entry.key == _expandedCategoryId,
            onToggle: () => _toggle(entry.key),
          );
        },
      ),
    );
  }
}

/// A collapsible court-category card.
///
/// Collapsed it is a single name row; tapping the card opens it, which reveals
/// the three management buttons and makes the card taller. The open state lives
/// on the screen (see [CourtNamesStepsScreen]) so opening one card closes the
/// others.
class _CategoryCard extends StatelessWidget {
  final String categoryId;
  final String label;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _CategoryCard({
    required this.categoryId,
    required this.label,
    required this.isExpanded,
    required this.onToggle,
  });

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
        onTap: onToggle,
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
                    // No chevron: the user asked the cards to carry no icon
                    // (0.0.612); the whole card is still the tap target.
                    Expanded(child: Text(label, style: AppTypography.bodyLg)),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: isExpanded
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
                            if (_hasSteps(categoryId)) ...[
                              Expanded(
                                child: _ActionButton(
                                  label: l.settingsEditItems_steps,
                                  onTap: () =>
                                      context.push(_route(_ItemKind.steps)),
                                ),
                              ),
                              const SizedBox(width: _actionButtonGap),
                            ],
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
