import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/app_translations.dart';
import '../../shared/providers/locale_provider.dart';

/// Scratch screen used in Task 02 Phase 3 to verify localization and font
/// switching between English and Bengali.
///
/// The screen exposes a toggle that switches the active locale via
/// [localeProvider]. When the locale is Bengali, the app-wide theme applies the
/// `TiroBangla` font family.
class LocaleScratchScreen extends ConsumerWidget {
  const LocaleScratchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isBengali = locale.languageCode == 'bn';
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.grouped[AppStrings.localeScratchGroup]![AppStrings.localeScratchTitle]!),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.edgeMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TODO(localization): move section labels to ARB once the
              // scratch screen graduates into a real settings screen.
              _Section(
                title: 'Current language',
                child: Text(
                  l10n.raw.localeScratch_currentLanguage(locale.languageCode.toUpperCase()),
                  style: AppTypography.bodyLg,
                ),
              ),
              _Section(
                title: 'Language toggle',
                child: Row(
                  children: [
                    Expanded(
                      child: _LanguageButton(
                        label: 'English',
                        selected: !isBengali,
                        onTap: () => ref.read(localeProvider.notifier).setLocale(const Locale('en')),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _LanguageButton(
                        label: 'বাংলা',
                        selected: isBengali,
                        onTap: () => ref.read(localeProvider.notifier).setLocale(const Locale('bn')),
                      ),
                    ),
                  ],
                ),
              ),
              _Section(
                title: 'Greeting',
                child: Text(
                  l10n.grouped[AppStrings.localeScratchGroup]![AppStrings.localeScratchGreeting]!,
                  style: AppTypography.headlineMd,
                ),
              ),
              _Section(
                title: 'English sample',
                child: Text(
                  l10n.grouped[AppStrings.localeScratchGroup]![AppStrings.localeScratchEnglishsample]!,
                  style: AppTypography.bodyMd,
                ),
              ),
              _Section(
                title: 'Bengali sample',
                child: Text(
                  l10n.grouped[AppStrings.localeScratchGroup]![AppStrings.localeScratchBengalisample]!,
                  style: AppTypography.bengaliBodyMd,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: Text(
                  'Font family for current locale: ${isBengali ? 'TiroBangla' : 'Inter/Manrope/IBM Plex Sans'}',
                  style: AppTypography.labelMd,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.labelLg.copyWith(color: AppColors.tertiary)),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: selected ? AppColors.primary : AppColors.surfaceContainer,
        foregroundColor: selected ? AppColors.onPrimary : AppColors.onSurface,
      ),
      child: Text(label),
    );
  }
}
