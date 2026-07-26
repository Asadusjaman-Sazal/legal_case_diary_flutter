import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/generated/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/scratch/locale_scratch_screen.dart';
import 'shared/providers/locale_provider.dart';
import 'shared/widgets/database_guard.dart';

/// The root widget of the Legal Case Diary application.
///
/// Watches the active locale from [localeProvider] and rebuilds the
/// [MaterialApp] whenever the user switches languages. Localizations delegates
/// and supported locales are supplied by the generated [AppLocalizations].
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'Legal Case Diary',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(locale),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const DatabaseGuard(child: LocaleScratchScreen()),
    );
  }
}
