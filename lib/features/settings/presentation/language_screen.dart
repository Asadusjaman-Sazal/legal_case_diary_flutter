/// Language settings sub-page: pick between English and বাংলা.
///
/// The two choices are a single-line button pair: the active language is filled
/// black with white text, the inactive one is white with black text and an
/// outline. Each label is pinned to its own script's font — the English label to
/// the app's English family, the Bengali label to the Bengali family — so
/// switching the locale never re-renders one of the two words in the other
/// script's typeface. Selection updates the persisted app locale.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../shared/providers/locale_provider.dart';
import 'settings_sub_page_modal.dart';

/// Height of each language button, matching the Settings ON/OFF pair.
const double _buttonHeight = 48;

/// Language picker screen reached from the Settings main list.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final active = ref.watch(localeProvider);
    final englishSelected = active.languageCode != 'bn';

    /// Applies [locale] as the active language.
    void select(Locale locale) =>
        ref.read(localeProvider.notifier).setLocale(locale);

    return SettingsSubPageModal(
      title: l.settingsScreen_language,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.edgeMargin),
        child: Row(
          children: [
            Expanded(
              child: _LanguageButton(
                label: l.settingsScreen_languageEnglish,
                // The app's English text style: its family is the English one
                // even while the Bengali locale has re-themed everything else.
                textStyle: AppTypography.bodyLg,
                selected: englishSelected,
                onTap: () => select(const Locale('en')),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _LanguageButton(
                label: l.settingsScreen_languageBengali,
                // Tiro Bangla, the Bengali body font, regardless of locale.
                textStyle: AppTypography.bengaliBodyLg,
                selected: !englishSelected,
                onTap: () => select(const Locale('bn')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One language button: filled black while selected, outlined white otherwise.
class _LanguageButton extends StatelessWidget {
  /// Button label, already in its own script.
  final String label;

  /// Script-specific base style; only the colour and weight are adjusted here,
  /// so the family stays with the script rather than with the active locale.
  final TextStyle textStyle;

  /// Whether this is the active language.
  final bool selected;

  /// Applies this language.
  final VoidCallback onTap;

  const _LanguageButton({
    required this.label,
    required this.textStyle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: SizedBox(
      height: _buttonHeight,
      child: Material(
        color: selected ? Colors.black : AppColors.surfaceContainerLowest,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          side: BorderSide(color: selected ? Colors.black : AppColors.outline),
        ),
        child: InkWell(
          onTap: onTap,
          child: Center(
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
        ),
      ),
    ),
  );
}
