import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/generated/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'shared/providers/locale_provider.dart';

/// The root widget of the Legal Case Diary application.
///
/// Uses [MaterialApp.router] with [GoRouter] from [appRouterProvider].
/// Watches the active locale from [localeProvider] and rebuilds whenever
/// the user switches languages.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Legal Case Diary',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(locale),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
    );
  }
}
