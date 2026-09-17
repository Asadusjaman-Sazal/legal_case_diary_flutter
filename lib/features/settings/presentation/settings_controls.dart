/// Shared controls for the Settings sub-page bodies.
///
/// Notifications, View Settings and About all render the same three pieces: a
/// white bordered section card, an uppercase section label, and a full-width
/// 48 px control row. They live here so those screens cannot drift apart the
/// way the mockups' repeated markup would otherwise allow.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';

/// White bordered card used by every Settings sub-page section.
BoxDecoration settingsCardDecoration({
  Color color = AppColors.surfaceContainerLowest,
}) => BoxDecoration(
  color: color,
  // Radius matches the mockups' `rounded-xl`.
  borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
  border: Border.all(color: AppColors.outlineVariant),
);

/// Uppercase section heading (mockup `label-md` + tracking).
class SettingsSectionLabel extends StatelessWidget {
  /// Label text; stored in sentence case because it is upper-cased here.
  final String text;

  const SettingsSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: AppTypography.labelMd.copyWith(
      color: AppColors.onSurfaceVariant,
      letterSpacing: 0.6, // tracking-wider at 12 px.
    ),
  );
}

/// Full-width 48 px control row: label on the left, an affordance on the right.
///
/// Used by the Notifications and View Settings pickers, whose mockup markup is
/// a borderless-looking button pretending to be a select.
class SettingsPickerRow extends StatelessWidget {
  /// Currently selected value, already localized.
  final String text;

  /// Trailing icon (`expand_more`, `schedule`, …).
  final IconData icon;

  /// Opens the picker.
  final VoidCallback onTap;

  const SettingsPickerRow({
    super.key,
    required this.text,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceContainerLowest,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      side: BorderSide(color: AppColors.outlineVariant),
    ),
    child: InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Expanded(child: Text(text, style: AppTypography.bodyLg)),
              Icon(icon, color: AppColors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    ),
  );
}

/// One half of a two-option segmented control (mockup ON/OFF pair).
class SettingsChoiceButton extends StatelessWidget {
  /// Button label, e.g. "On" / "Off".
  final String label;

  /// Optional leading icon.
  final IconData? icon;

  /// Whether this option is the active one.
  final bool selected;

  /// Selects this option.
  final VoidCallback onTap;

  const SettingsChoiceButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: SizedBox(
      height: 48,
      child: Material(
        // The active half is the dark, filled control from the mockup.
        color: selected
            ? AppColors.onPrimaryFixed
            : AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          side: BorderSide(
            color: selected
                ? AppColors.onPrimaryFixed
                : AppColors.outlineVariant,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? AppColors.onPrimary
                      : AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                label,
                style: AppTypography.labelLg.copyWith(
                  color: selected
                      ? AppColors.onPrimary
                      : AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Single-select list shown inside a picker dialog (mockup's day-offset /
/// landing-page modals): selected row in `secondary` with a filled check.
class SettingsOptionRow extends StatelessWidget {
  /// Localized option label.
  final String label;

  /// Whether this option is the active one.
  final bool selected;

  /// Selects this option.
  final VoidCallback onTap;

  const SettingsOptionRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyLg.copyWith(
                color: selected ? AppColors.secondary : AppColors.onSurface,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle, color: AppColors.secondary),
        ],
      ),
    ),
  );
}

/// Header of a picker dialog, matching the mockup's dark header bar.
class SettingsPickerDialogHeader extends StatelessWidget {
  /// Dialog title.
  final String title;

  const SettingsPickerDialogHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.primaryContainer,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    child: Row(
      children: [
        const SizedBox(width: 48),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.titleLg.copyWith(color: AppColors.onPrimary),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: AppColors.onPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}
