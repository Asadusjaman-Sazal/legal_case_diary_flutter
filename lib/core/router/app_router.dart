/// GoRouter configuration for the Legal Case Diary app.
///
/// Shell route wraps all main screens (those with bottom nav / drawer).
/// Non-shell routes (login, signup, paywall, case-detail) are top-level.
/// Landing page is resolved asynchronously from [SettingsRepository.defaultLandingPage].
/// Back/exit confirmation is handled via [AppShellRoot] → [PopScope] on the shell root.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts_and_profile/presentation/accounts_profile_menu_screen.dart';
import '../../features/accounts_and_profile/presentation/manage_account_screen.dart';
import '../../features/accounts_and_profile/presentation/manage_associates_screen.dart';
import '../../features/accounts_and_profile/presentation/profile_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/case_reference/presentation/case_reference_screen.dart';
import '../../features/cases/presentation/active_cases/active_cases_screen.dart';
import '../../features/cases/presentation/all_cases/all_cases_screen.dart';
import '../../features/cases/presentation/case_detail/case_detail_screen.dart';
import '../../features/cases/presentation/daily_cause_list/daily_cause_list_screen.dart';
import '../../features/cases/presentation/disposed_cases/disposed_cases_screen.dart';
import '../../features/cases/presentation/overdue_dates/overdue_dates_screen.dart';
import '../../features/cases/presentation/upcoming_cases/upcoming_cases_screen.dart';
import '../../features/notes/presentation/notes_screen.dart';
import '../../features/payments/presentation/checkout_screen.dart';
import '../../features/payments/presentation/paywall_screen.dart';
import '../../features/settings/presentation/backup_restore_screen.dart';
import '../../features/settings/presentation/edit_court_steps/court_category_screen.dart';
import '../../features/settings/presentation/edit_court_steps/court_list_screen.dart';
import '../../features/settings/presentation/edit_court_steps/court_names_steps_screen.dart';
import '../../features/settings/presentation/edit_court_steps/district_list_screen.dart';
import '../../features/settings/presentation/edit_court_steps/edit_court_names_category_screen.dart';
import '../../features/settings/presentation/edit_court_steps/edit_court_steps_menu.dart';
import '../../features/settings/presentation/online_sync_screen.dart';
import '../../features/settings/presentation/settings_about/guidelines_screen.dart';
import '../../features/settings/presentation/settings_about/more_about_app_screen.dart';
import '../../features/settings/presentation/settings_main_screen.dart';
import '../../features/settings/presentation/settings_notifications/notification_settings_screen.dart';
import '../../features/settings/presentation/settings_view/view_settings_screen.dart';
import '../../shared/widgets/database_guard.dart';
import '../providers/repository_providers.dart';

// ---------------------------------------------------------------------------
// Route path constants
// ---------------------------------------------------------------------------

/// Route path constants used throughout the app for type-safe navigation.
class AppRoutes {
  AppRoutes._();

  static const String dailyCauseList = '/daily-cause-list';
  static const String allCases = '/all-cases';
  static const String activeCases = '/active-cases';
  static const String upcomingCases = '/upcoming-cases';
  static const String overdueDates = '/overdue-dates';
  static const String disposedCases = '/disposed-cases';
  static const String notes = '/notes';
  static const String caseReference = '/case-reference';
  static const String settings = '/settings';
  static const String settingsAccountProfile = '/settings/account-profile';
  static const String settingsProfile = '/settings/profile';
  static const String settingsManageAccount = '/settings/manage-account';
  static const String settingsManageAssociates = '/settings/manage-associates';
  static const String settingsOnlineSync = '/settings/online-sync';
  static const String settingsBackupRestore = '/settings/backup-restore';
  static const String settingsEditCourtSteps = '/settings/edit-court-steps';
  static const String settingsEditCourtNamesCategory =
      '/settings/edit-court-steps/court-names-category';
  static const String settingsCourtCategory =
      '/settings/edit-court-steps/court-category';
  static const String settingsDistrictList =
      '/settings/edit-court-steps/district-list';
  static const String settingsCourtList =
      '/settings/edit-court-steps/court-list';
  static const String settingsCourtNamesSteps =
      '/settings/edit-court-steps/court-names-steps';
  static const String settingsNotifications = '/settings/notifications';
  static const String settingsViewSettings = '/settings/view-settings';
  static const String settingsGuidelines = '/settings/guidelines';
  static const String settingsAbout = '/settings/about';
  static const String caseDetail = '/case-detail/:caseId';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String paywall = '/paywall';
  static const String checkout = '/checkout';

  /// Maps a [defaultLandingPage] preference key to its route path.
  static String landingPageRoute(String key) => switch (key) {
    'all_cases' => allCases,
    'active' => activeCases,
    'upcoming' => upcomingCases,
    'overdue' => overdueDates,
    'disposed' => disposedCases,
    _ => dailyCauseList,
  };
}

// ---------------------------------------------------------------------------
// Router provider
// ---------------------------------------------------------------------------

/// Provides the configured [GoRouter] instance.
///
/// Awaits [settingsRepositoryProvider] to resolve the correct initial landing
/// page before constructing the router, so the preference is always honoured.
/// Falls back to Daily Cause List if settings are unavailable.
final appRouterProvider = FutureProvider<GoRouter>((ref) async {
  String initialLocation = AppRoutes.dailyCauseList;
  try {
    final repo = await ref.watch(settingsRepositoryProvider.future);
    final s = await repo.getSettings();
    initialLocation = AppRoutes.landingPageRoute(s.defaultLandingPage);
  } catch (_) {
    // Settings unavailable — keep default.
  }

  return GoRouter(
    initialLocation: initialLocation,
    debugLogDiagnostics: false,
    routes: [
      // ------------------------------------------------------------------
      // Shell route — wraps all main screens with AppShellRoot + DatabaseGuard.
      // AppShellRoot owns the PopScope exit-confirmation (Dev Workflow §6).
      // ------------------------------------------------------------------
      ShellRoute(
        builder: (context, state, child) =>
            AppShellRoot(child: DatabaseGuard(child: child)),
        routes: _shellRoutes,
      ),

      // ------------------------------------------------------------------
      // Top-level routes (no shell / bottom nav)
      // ------------------------------------------------------------------
      GoRoute(
        path: AppRoutes.caseDetail,
        builder: (context, state) =>
            CaseDetailScreen(caseId: state.pathParameters['caseId'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.paywall,
        builder: (context, state) => const PaywallScreen(),
      ),
      GoRoute(
        path: AppRoutes.checkout,
        builder: (context, state) => const CheckoutScreen(),
      ),
    ],
  );
});

/// Shell-level routes (all screens that share the bottom nav / drawer shell).
final List<RouteBase> _shellRoutes = [
  GoRoute(
    path: AppRoutes.dailyCauseList,
    builder: (context, state) => const DailyCauseListScreen(),
  ),
  GoRoute(
    path: AppRoutes.allCases,
    builder: (context, state) => const AllCasesScreen(),
  ),
  GoRoute(
    path: AppRoutes.activeCases,
    builder: (context, state) => const ActiveCasesScreen(),
  ),
  GoRoute(
    path: AppRoutes.upcomingCases,
    builder: (context, state) => const UpcomingCasesScreen(),
  ),
  GoRoute(
    path: AppRoutes.overdueDates,
    builder: (context, state) => const OverdueDatesScreen(),
  ),
  GoRoute(
    path: AppRoutes.disposedCases,
    builder: (context, state) => const DisposedCasesScreen(),
  ),
  GoRoute(
    path: AppRoutes.notes,
    builder: (context, state) => const NotesScreen(),
  ),
  GoRoute(
    path: AppRoutes.caseReference,
    builder: (context, state) => const CaseReferenceScreen(),
  ),
  // Settings tree
  GoRoute(
    path: AppRoutes.settings,
    builder: (context, state) => const SettingsMainScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsAccountProfile,
    builder: (context, state) => const AccountsProfileMenuScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsProfile,
    builder: (context, state) => const ProfileScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsManageAccount,
    builder: (context, state) => const ManageAccountScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsManageAssociates,
    builder: (context, state) => const ManageAssociatesScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsOnlineSync,
    builder: (context, state) => const OnlineSyncScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsBackupRestore,
    builder: (context, state) => const BackupRestoreScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsEditCourtSteps,
    builder: (context, state) => const EditCourtStepsMenu(),
  ),
  GoRoute(
    path: AppRoutes.settingsEditCourtNamesCategory,
    builder: (context, state) => const EditCourtNamesCategoryScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsCourtCategory,
    builder: (context, state) => const CourtCategoryScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsDistrictList,
    builder: (context, state) => const DistrictListScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsCourtList,
    builder: (context, state) => const CourtListScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsCourtNamesSteps,
    builder: (context, state) => const CourtNamesStepsScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsNotifications,
    builder: (context, state) => const NotificationSettingsScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsViewSettings,
    builder: (context, state) => const ViewSettingsScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsGuidelines,
    builder: (context, state) => const GuidelinesScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsAbout,
    builder: (context, state) => const MoreAboutAppScreen(),
  ),
];

// ---------------------------------------------------------------------------
// Shell root with back/exit confirmation (Dev Workflow §6)
// ---------------------------------------------------------------------------

/// Wraps the shell child with exit-confirmation on system back at the root.
///
/// Shows an [AlertDialog] asking the user to confirm exit. Prevents black
/// screens by never allowing an accidental pop of the root navigator.
class AppShellRoot extends StatelessWidget {
  final Widget child;
  const AppShellRoot({required this.child, super.key});

  Future<bool> _confirmExit(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit App?'),
        content: const Text('Do you want to exit Legal Case Diary?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final router = GoRouter.of(context);
        // If there is a route to pop within the shell, pop it normally.
        if (router.canPop()) {
          router.pop();
          return;
        }
        // At root — show exit confirmation.
        final shouldExit = await _confirmExit(context);
        if (shouldExit && context.mounted) {
          SystemNavigator.pop();
        }
      },
      // Shell screens own the app's status-bar inset. Keep this outside the
      // modal navigator so full-height sheets can use their own safe area.
      child: SafeArea(top: true, bottom: false, child: child),
    );
  }
}
