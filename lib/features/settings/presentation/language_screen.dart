/// Language settings sub-page: pick between English and বাংলা.
///
/// The body is a single group — a language badge, a heading and a one-line
/// explanation, the two choice cards, a preview of today's date written in the
/// active language, and a note — so the page reads as finished content rather
/// than two buttons stranded in an empty canvas. The group starts directly
/// under the app bar (nothing pushes it down) and scrolls on a short viewport
/// (or at a large text scale) instead of overflowing.
///
/// Each label is pinned to its own script's font — the English label to the
/// app's English family, the Bengali label to the Bengali family — so switching
/// the locale never re-renders one of the two words in the other script's
/// typeface, and the preview line proves the switch. Selection updates the
/// persisted app locale.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/providers/locale_provider.dart';
import 'settings_sub_page_modal.dart';

/// Height of each language option card: roomier than the 48 px Settings rows,
/// yet shorter than the two cards below it so those read as the fuller cards.
const double _optionHeight = 64;

/// Diameter of the round language badge above the heading.
const double _badgeSize = 72;

/// Widest the centred group grows; a phone always uses its full width.
const double _maxContentWidth = 480;

/// Language picker screen reached from the Settings main list.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final active = ref.watch(localeProvider);
    final englishSelected = active.languageCode != 'bn';

    /// Today's date, written in the language that is active right now.
    final todayLabel = AppDateUtils.formatFullDate(
      DateTime.now().millisecondsSinceEpoch,
      locale: l.localeName,
    );

    /// Applies [locale] as the active language.
    void select(Locale locale) =>
        ref.read(localeProvider.notifier).setLocale(locale);

    return SettingsSubPageModal(
      title: l.settingsScreen_language,
      // Top-aligned, so no empty space is reserved above the badge; the body
      // scrolls when the group is taller than the viewport.
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.edgeMargin),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Badge.
                Container(
                  width: _badgeSize,
                  height: _badgeSize,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.language,
                    size: 32,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Heading + one-line explanation.
                Text(
                  l.settingsLanguage_selectHeading,
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineMd,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l.settingsLanguage_intro,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                // The two choices.
                _LanguageOption(
                  label: l.settingsScreen_languageEnglish,
                  // The app's English text style: its family is the English
                  // one even while the Bengali locale has re-themed
                  // everything else.
                  textStyle: AppTypography.titleMd,
                  selected: englishSelected,
                  selectedLabel: l.settingsLanguage_selected,
                  onTap: () => select(const Locale('en')),
                ),
                const SizedBox(height: AppSpacing.gutter),
                _LanguageOption(
                  label: l.settingsScreen_languageBengali,
                  // Tiro Bangla, the Bengali body font, regardless of
                  // locale.
                  textStyle: AppTypography.bengaliTitleMd,
                  selected: !englishSelected,
                  selectedLabel: l.settingsLanguage_selected,
                  onTap: () => select(const Locale('bn')),
                ),
                const SizedBox(height: AppSpacing.xl),
                // Proof of the switch: today's date in the active language.
                _PreviewCard(
                  title: l.settingsLanguage_previewTitle,
                  date: todayLabel,
                  dateStyle: englishSelected
                      ? AppTypography.titleMd
                      : AppTypography.bengaliTitleMd,
                ),
                const SizedBox(height: AppSpacing.md),
                _NoteCard(text: l.settingsLanguage_note),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One language choice: filled black with a check while selected, outlined
/// white otherwise.
class _LanguageOption extends StatelessWidget {
  /// Card label, already in its own script.
  final String label;

  /// Script-specific base style; only the colour is adjusted here, so the
  /// family stays with the script rather than with the active locale.
  final TextStyle textStyle;

  /// Whether this is the active language.
  final bool selected;

  /// Localized label announced by screen readers with the check mark.
  final String selectedLabel;

  /// Applies this language.
  final VoidCallback onTap;

  const _LanguageOption({
    required this.label,
    required this.textStyle,
    required this.selected,
    required this.selectedLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: SizedBox(
      height: _optionHeight,
      width: double.infinity,
      child: Material(
        color: selected ? Colors.black : AppColors.surfaceContainerLowest,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: BorderSide(color: selected ? Colors.black : AppColors.outline),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle.copyWith(
                      color: selected ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.check,
                  size: 20,
                  color: selected ? Colors.white : Colors.transparent,
                  semanticLabel: selected ? selectedLabel : null,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Read-only card showing today's date in the active language, so the effect of
/// the choice is visible before leaving the screen.
class _PreviewCard extends StatelessWidget {
  /// Card heading, e.g. "Today's Date in This Language".
  final String title;

  /// The formatted date, already localized.
  final String date;

  /// The date's style — the active script's title role.
  final TextStyle dateStyle;

  const _PreviewCard({
    required this.title,
    required this.date,
    required this.dateStyle,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      border: Border.all(color: AppColors.outlineVariant),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.calendar_today_outlined,
          size: 20,
          color: AppColors.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.gutter),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(date, style: dateStyle),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Quiet note explaining what the setting does and does not affect.
class _NoteCard extends StatelessWidget {
  /// Localized note body.
  final String text;

  const _NoteCard({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      border: Border.all(color: AppColors.outlineVariant),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline,
          size: 20,
          color: AppColors.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.gutter),
        Expanded(child: Text(text, style: AppTypography.bodyMd)),
      ],
    ),
  );
}
