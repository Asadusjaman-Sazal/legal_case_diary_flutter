/// More About the App screen: version card, description, key features, actions.
///
/// Body mirrors `mockup_html_screens/settings_moreAboutTheApp/code.html`, which
/// the About screen's "More About the App" row opens. It is outside Task 12's
/// original file list but was approved during Phase 4, so it lives beside the
/// About screen it belongs to.
///
/// The mockup's version placeholder is replaced with the bundled app version,
/// its description and feature list are rewritten to match the app as built
/// (the mockup named the app "Justice Ledger" and listed cloud sync), and
/// "Check for updates", "Rate App" and "Share App" only report their Part A
/// state: store links and update checks belong to later tasks.
library;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_version.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../settings_controls.dart';
import '../settings_menu_card.dart';
import '../settings_sub_page_modal.dart';

/// Key features offered in the app. The mockup's fourth row was "Secure Sync",
/// which the offline version does not have, so it is replaced by hearing
/// notifications — a feature that is actually here.
const List<({IconData icon, String Function(AppLocalizations) label})>
_featureRows = <({IconData icon, String Function(AppLocalizations) label})>[
  (icon: Icons.calendar_month_outlined, label: _dailyCauseList),
  (icon: Icons.cloud_download_outlined, label: _offlineBackup),
  (icon: Icons.menu_book_outlined, label: _caseReferences),
  (icon: Icons.notifications_active_outlined, label: _hearingNotifications),
];

String _dailyCauseList(AppLocalizations l) =>
    l.settingsMoreAbout_featureDailyCauseList;
String _offlineBackup(AppLocalizations l) =>
    l.settingsMoreAbout_featureOfflineBackup;
String _caseReferences(AppLocalizations l) =>
    l.settingsMoreAbout_featureCaseReferences;
String _hearingNotifications(AppLocalizations l) =>
    l.settingsMoreAbout_featureHearingNotifications;

/// More About the App screen.
class MoreAboutTheAppScreen extends StatelessWidget {
  const MoreAboutTheAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SettingsSubPageModal(
      title: l.settingsMoreAbout_title,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.edgeMargin,
          AppSpacing.md,
          AppSpacing.edgeMargin,
          AppSpacing.lg,
        ),
        children: [
          // App version card.
          Container(
            decoration: settingsCardDecoration(),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.appTitle,
                        style: AppTypography.titleLg.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l.settingsAbout_version(appVersion),
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _showPending(context, l),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: const BorderSide(color: AppColors.secondary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                  ),
                  child: Text(
                    l.settingsMoreAbout_checkUpdates,
                    style: AppTypography.labelLg.copyWith(
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Description card.
          Container(
            decoration: settingsCardDecoration(),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              l.settingsMoreAbout_description,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Key features.
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.sm,
              bottom: AppSpacing.sm,
            ),
            child: SettingsSectionLabel(l.settingsMoreAbout_keyFeatures),
          ),
          Material(
            color: AppColors.surfaceContainerLowest,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
              side: BorderSide(color: AppColors.outlineVariant),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _featureRows.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, color: AppColors.outlineVariant),
                  _FeatureRow(
                    icon: _featureRows[i].icon,
                    label: _featureRows[i].label(l),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Actions.
          SizedBox(
            height: settingsPrimaryButtonHeight,
            child: FilledButton.icon(
              onPressed: () => _showPending(context, l),
              icon: const Icon(Icons.star_outline, size: 20),
              label: Text(l.settingsMoreAbout_rateApp),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                textStyle: AppTypography.labelLg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: settingsPrimaryButtonHeight,
            child: OutlinedButton.icon(
              onPressed: () => _showPending(context, l),
              icon: const Icon(Icons.share_outlined, size: 20),
              label: Text(l.settingsMoreAbout_shareApp),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.outlineVariant),
                textStyle: AppTypography.labelLg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text.rich(
            TextSpan(
              text: '${l.settingsMoreAbout_footer}\n',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              children: [
                TextSpan(
                  text: 'Adv. Asadusjaman Sazal',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Part A notice for the store/update actions.
  void _showPending(BuildContext context, AppLocalizations l) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l.settingsAbout_actionPending)));
  }
}

/// One key-feature row: round icon chip plus label.
class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceContainer,
          ),
          child: Icon(icon, size: 20, color: AppColors.onSurface),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            label,
            style: AppTypography.titleMd.copyWith(color: AppColors.primary),
          ),
        ),
      ],
    ),
  );
}
