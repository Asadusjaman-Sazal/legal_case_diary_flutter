import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_colors.dart';
import 'core/l10n/generated/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'shared/providers/locale_provider.dart';

/// The root widget of the Legal Case Diary application.
///
/// Uses [MaterialApp.router] with [GoRouter] from [appRouterProvider].
/// Watches the active locale from [localeProvider] and rebuilds whenever
/// the user switches languages. Shows a minimal loading screen while the
/// router resolves the initial landing page from [SettingsRepository].
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final routerAsync = ref.watch(appRouterProvider);

    return routerAsync.when(
      data: (router) => MaterialApp.router(
        title: 'Legal Case Diary',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(locale),
        locale: locale,
        builder: (context, child) => _buildSystemUiLayer(child),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
      ),
      // Show a blank themed screen while the router initialises.
      loading: () => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(locale),
        builder: (context, child) => _buildSystemUiLayer(child),
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      // On error fall back to the same loading screen; router will retry.
      error: (err, stack) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(locale),
        builder: (context, child) => _buildSystemUiLayer(child),
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
    );
  }

  // Keep system icons readable on the light app surfaces. Content insets are
  // applied by the shell or individual top-level screens so modal overlays
  // retain their full available height.
  static Widget _buildSystemUiLayer(Widget? child) =>
      AnnotatedRegion<SystemUiOverlayStyle>(
        value: _systemUiOverlayStyle,
        child: child ?? const SizedBox.shrink(),
      );

  static const SystemUiOverlayStyle _systemUiOverlayStyle =
      SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: AppColors.outlineVariant,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
      );
}
