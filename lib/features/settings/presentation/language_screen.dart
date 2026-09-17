/// Language settings sub-page: pick between English and বাংলা.
///
/// Replaces the inline toggle that previously lived on the main Settings list
/// (Task 12 Phase 1 redesign). Selection updates the persisted app locale.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../shared/providers/locale_provider.dart';
import 'settings_sub_page_modal.dart';

/// A single selectable language option row.
class _LanguageOption {
  final Locale locale;
  final String label;

  const _LanguageOption({required this.locale, required this.label});
}

/// Language picker screen reached from the Settings main list.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final active = ref.watch(localeProvider);
    final activeCode = active.languageCode;

    final options = [
      _LanguageOption(
        locale: const Locale('en'),
        label: l.settingsScreen_languageEnglish,
      ),
      _LanguageOption(
        locale: const Locale('bn'),
        label: l.settingsScreen_languageBengali,
      ),
    ];

    return SettingsSubPageModal(
      title: l.settingsScreen_language,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: options.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final option = options[index];
          final selected = option.locale.languageCode == activeCode;
          return ListTile(
            title: Text(
              option.label,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            trailing: selected
                ? const Icon(Icons.check, color: Colors.blue)
                : null,
            onTap: () {
              ref.read(localeProvider.notifier).setLocale(option.locale);
            },
          );
        },
      ),
    );
  }
}
