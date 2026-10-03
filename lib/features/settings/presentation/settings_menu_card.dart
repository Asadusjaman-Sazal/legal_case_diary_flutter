/// Shared size contract and card widget for the Settings sub-menus.
///
/// Every sub-menu card/button renders through the constants here so the whole
/// Settings surface stays one size: 16 px padding, a 44 px minimum content row,
/// and a 56 px primary button. The geometry was taken from the Account &
/// Profile menu card, which is the reference screen for sub-menu sizing.
/// Keeping it in one place is what stops the cards drifting apart again when a
/// single screen is edited.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';

/// Corner radius of a sub-menu card (Account & Profile's `rounded-xl`).
const double settingsMenuCardRadius = 12.0;

/// Minimum height of the content row inside a sub-menu card.
///
/// body-lg title (24 px) + `xs` gap + body-sm subtitle (16 px) = 44 px, so a
/// card is 76 px drawn with its two 16 px paddings; a wrapping subtitle grows
/// it exactly like the Account & Profile menu card does.
const double settingsMenuCardRowHeight = 44.0;

/// Height of a Settings sub-menu primary action button.
///
/// Matches the Profile screen's "Save Profile" button, so Sync Now, the Backup
/// & Restore actions, and Save Profile are all the same height.
const double settingsPrimaryButtonHeight = 56.0;

/// A tappable Settings sub-menu card: leading icon, title, optional subtitle,
/// and a trailing affordance.
class SettingsMenuCard extends StatelessWidget {
  /// Leading icon shown at 28 px in `primary`.
  final IconData icon;

  /// Card title (body-lg).
  final String title;

  /// Optional supporting line (body-sm); omit for a single-line card.
  final String? subtitle;

  /// Tap handler — usually `context.push(route)`.
  final VoidCallback onTap;

  /// Optional trailing affordance; defaults to the shared chevron.
  final Widget? trailing;

  /// Creates a sub-menu card sized by [settingsMenuCardRowHeight].
  const SettingsMenuCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(settingsMenuCardRadius),
          side: BorderSide(color: AppColors.surfaceContainer),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(settingsMenuCardRadius),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ConstrainedBox(
              // Floor keeps single-line cards the same size as two-line ones.
              constraints: const BoxConstraints(
                minHeight: settingsMenuCardRowHeight,
              ),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.primary, size: 28),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppTypography.bodyLg),
                        if (subtitle != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(subtitle!, style: AppTypography.bodySm),
                        ],
                      ],
                    ),
                  ),
                  trailing ??
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.tertiary,
                      ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// A single row in a Settings sub-menu list: leading icon, title, chevron.
///
/// Lived in Manage Account, where it drew that mockup's Account Settings
/// rows, and moved here because the Subscription rows are the same design;
/// it sits with the size contract it obeys so the two cannot drift apart.
class SettingsSubMenuRow extends StatelessWidget {
  /// Leading icon drawn in the rounded circle the mockup specifies.
  final IconData icon;

  /// Row title.
  final String title;

  /// Tap handler.
  final VoidCallback onTap;

  /// Creates a sub-menu row.
  const SettingsSubMenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          // Same 44 px content row as the shared sub-menu cards, so these rows
          // are the same size as the Account & Profile menu cards.
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: settingsMenuCardRowHeight,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceContainer,
                  ),
                  child: Center(child: Icon(icon, color: AppColors.primary)),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.outlineVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
