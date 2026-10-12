import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_colors.dart';
import 'features/accounts_and_profile/presentation/account_refresh_scope.dart';
import 'features/accounts_and_profile/presentation/membership_revoked_scope.dart';
import 'features/auth/presentation/session_state.dart';
import 'sync/sync_trigger_scope.dart';
import 'core/l10n/generated/app_localizations.dart';
import 'core/backup/backup_scheduler_scope.dart';
import 'core/notifications/notification_setup_gate.dart';
import 'core/notifications/notification_tap_listener.dart';
import 'core/push/admin_push_scope.dart';
import 'features/settings/presentation/backup_nudge_banner.dart';
import 'features/sync/presentation/recovery_required_screen.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/font_size_scope.dart';
import 'features/app_lock/presentation/app_lock_scope.dart';
import 'features/settings/presentation/settings_viewmodel.dart';
import 'features/settings/presentation/update_check_scope.dart';
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
          // and overlay. The scope also drops the device's own text scale, so
          // the app always renders at its designed size plus this step.
          FontSizeScope(
            step: fontSizeStep,
            // The app lock sits just inside it — outermost of the app's own
            // content, so the lock covers every route, dialog and gate below
            // (including the recovery screen), and its text still follows the
            // user's font size. It lets everything underneath keep *running*
            // while covered: it paints over, it does not pause.
            child: AppLockScope(
              child: NotificationSetupGate(
                router: router,
                child: NotificationTapListener(
                  router: router,
                  child: BackupSchedulerScope(
                    child: BackupNudgeBanner(
                      router: router,
                      // The session notice: when the server rejected the stored
                      // session while online, it offers the sign-in above whatever
                      // screen the user is on — the local diary stays usable either
                      // way, which is the plan's rule that JWT validity never gates
                      // local data.
                      child: SessionExpiryNotice(
                        router: router,
                        // Innermost so it wraps the screens themselves; it renders
                        // its child untouched and refreshes the profile and firm
                        // permissions on launch, on resume and on reconnect.
                        child: AccountRefreshScope(
                          // Wraps everything below the refresh: a device the firm has
                          // removed replaces the app with the removal screen, and
                          // nothing is erased until the user acts there. It sits
                          // inside the refresh scope because the removal **is** a
                          // refresh result — the profile loses its firm id — and
                          // outside the sync trigger so no edit can be started on a
                          // membership that no longer exists.
                          child: MembershipRevokedScope(
                            router: router,
                            // Drives the push/pull engine on launch, resume,
                            // reconnect and new local writes.
                            child: SyncTriggerScope(
                              // Innermost, so the extended-offline lock covers every
                              // screen and route: while it is set the app has no
                              // editable surface at all, and the blocking screen
                              // returns on every launch until recovery succeeds.
                              child: RecoveryRequiredScope(
                                child: UpdateCheckScope(
                                  // Innermost next to the screens: it renders its
                                  // child untouched and, in the background,
                                  // registers this device for admin payment
                                  // alerts once the server confirms the account
                                  // is an administrator's.
                                  child: AdminPushScope(
                                    child: child ?? const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
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
