import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_colors.dart';
import 'core/l10n/generated/app_localizations.dart';
import 'core/notifications/notification_setup_gate.dart';
import 'core/notifications/notification_tap_listener.dart';
import 'features/settings/presentation/backup_nudge_banner.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/font_size_scope.dart';
import 'features/settings/presentation/settings_viewmodel.dart';
import 'shared/providers/locale_provider.dart';

/// The root widget of the Legal Case Diary application.
///
/// Uses [MaterialApp.router] with [GoRouter] from [appRouterProvider].
/// Watches the active locale from [localeProvider] and rebuilds whenever
/// the user switches languages, and the saved font size step from
/// [settingsViewModelProvider]. Shows a minimal loading screen while the
/// router resolves the initial landing page from [SettingsRepository].
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final routerAsync = ref.watch(appRouterProvider);
    // The step only exists once settings have loaded, so the first frame after
    // a cold start is the shipped size; the saved step lands with the settings
    // the router already had to read before it could resolve a landing page.
    final fontSizeStep = ref.watch(
      settingsViewModelProvider.select(
        (settings) => settings.value?.fontSizeStep ?? 0,
      ),
    );

    return routerAsync.when(
      data: (router) => MaterialApp.router(
        // Localized so the OS task switcher follows the active language.
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(locale),
        locale: locale,
        // All three sit outside the app's navigator: the gate so it can offer
        // the OEM setup guide over whatever screen the app opens on, the
        // listener so a notification tap can route in from anywhere, and the
        // monthly backup nudge so a free user sees it wherever they land.
        builder: (context, child) => _buildSystemUiLayer(
          // The font size step wraps the whole app — every route, dialog, sheet
          // and overlay — and is added on top of the device's own text scale.
          FontSizeScope(
            step: fontSizeStep,
            child: NotificationSetupGate(
              router: router,
              child: NotificationTapListener(
                router: router,
                child: BackupNudgeBanner(
                  router: router,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
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
