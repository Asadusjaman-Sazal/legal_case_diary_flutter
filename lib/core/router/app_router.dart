/// GoRouter configuration for the Legal Case Diary app.
///
/// Shell route wraps all main screens (those with bottom nav / drawer).
/// Non-shell routes (login, signup, paywall, case-detail) are top-level.
/// Landing page is resolved asynchronously from [SettingsRepository.defaultLandingPage].
/// Back/exit confirmation is handled via [AppShellRoot] → [PopScope] on the shell root.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_panel_screen.dart';
import '../../features/admin/presentation/admin_payment_requests_screen.dart';
import '../../features/admin/presentation/admin_unconfirmed_accounts_screen.dart';
import '../../features/accounts_and_profile/presentation/accounts_profile_menu_screen.dart';
import '../../features/accounts_and_profile/presentation/delete_account_screen.dart';
import '../../features/accounts_and_profile/presentation/manage_account_screen.dart';
import '../../features/accounts_and_profile/presentation/manage_associates_screen.dart';
import '../../features/accounts_and_profile/presentation/profile_screen.dart';
import '../../features/app_lock/presentation/app_lock_screen.dart';
import '../../features/auth/data/local_auth_service.dart';
import '../../features/auth/presentation/auth_gate.dart';
import '../../features/auth/presentation/auth_viewmodel.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
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
import '../../features/payments/presentation/subscription_banner.dart';
import '../../features/settings/presentation/backup_restore_screen.dart';
import '../../features/settings/presentation/delete_request_review_screen.dart';
import '../../features/settings/presentation/delete_requests_screen.dart';
import '../../features/settings/presentation/edit_court_steps/court_category_screen.dart';
import '../../features/settings/presentation/edit_court_steps/court_list_screen.dart';
import '../../features/settings/presentation/edit_court_steps/court_names_steps_screen.dart';
import '../../features/settings/presentation/edit_court_steps/district_court_category_screen.dart';
import '../../features/settings/presentation/edit_court_steps/district_list_screen.dart';
import '../../features/settings/presentation/edit_court_steps/item_list_screen.dart';
import '../../features/settings/presentation/edit_court_steps/edit_court_names_category_screen.dart';
import '../../features/settings/presentation/edit_court_steps/edit_court_steps_menu.dart';
import '../../features/settings/presentation/edit_court_steps/lower_court_category_list_screen.dart';
import '../../features/settings/presentation/language_screen.dart';
import '../../features/settings/presentation/online_sync_screen.dart';
import '../../features/settings/presentation/subscription_screen.dart';
import '../../features/settings/presentation/subscription_details_screen.dart';
import '../../features/sync/presentation/sync_status_screen.dart';
import '../../features/sync/presentation/review_conflict_screen.dart';
import '../../features/sync/presentation/sync_conflict_banner.dart';
import '../../features/sync/presentation/sync_notice_banner.dart';
import '../../features/settings/presentation/legal/legal_document_screen.dart';
import '../../features/settings/presentation/settings_about/guidelines_screen.dart';
import '../../features/settings/presentation/settings_about/more_about_app_screen.dart';
import '../../features/settings/presentation/settings_about/more_about_the_app_screen.dart';
import '../../features/settings/presentation/settings_about/diagnostics_screen.dart';
import '../../features/settings/presentation/settings_about/support_screen.dart';
import '../../features/settings/presentation/update_screen.dart';
import '../../features/settings/presentation/settings_main_screen.dart';
import '../../features/settings/presentation/settings_notifications/battery_setup_guide_screen.dart';
import '../../features/settings/presentation/settings_notifications/notification_settings_screen.dart';
import '../../features/settings/presentation/settings_view/view_settings_screen.dart';
import '../../shared/widgets/database_guard.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/notification_providers.dart';
import '../providers/repository_providers.dart';
import '../push/payment_alert_message.dart';
import '../services/app_exit.dart';

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

  /// The Admin Panel (Task 22).
  ///
  /// A shell route, so an admin can place it in the bottom bar or the drawer
  /// through Settings > View Settings like any other screen. The route itself
  /// is **not** the gate: `adminStatusProvider` is, and the panel renders
  /// nothing to an account the server has not confirmed as an admin.
  static const String adminPanel = '/admin-panel';

  /// The panel's two sub-pages (0.0.459), pushed from its menu.
  static const String adminPaymentRequests = '/admin-panel/payment-requests';
  static const String adminUnverifiedAccounts =
      '/admin-panel/unverified-accounts';
  static const String settings = '/settings';
  static const String settingsLanguage = '/settings/language';
  static const String settingsAccountProfile = '/settings/account-profile';
  static const String settingsProfile = '/settings/profile';
  static const String settingsManageAccount = '/settings/manage-account';

  /// The typed confirmation a deletion must pass through (0.0.412), pushed from
  /// Manage Account's warning. Nothing is deleted until the phrase matches.
  static const String settingsDeleteAccount =
      '/settings/manage-account/delete';

  /// Change Password as a Settings sub-page.
  ///
  /// It is the same reset flow Login's "Forgot Password?" opens
  /// ([forgotPassword]), and deliberately a **separate route**: that one is an
  /// auth route, and the redirect below sends a signed-in user away from every
  /// auth route — so pushing it from Manage Account only ever landed on the
  /// default landing page.
  static const String settingsChangePassword = '/settings/change-password';

  /// App Lock as a Settings sub-page behind Manage Account: the PIN is set,
  /// changed and paired with a fingerprint here; the lock itself is enforced
  /// at the app root by `AppLockScope`.
  static const String settingsAppLock = '/settings/app-lock';

  static const String settingsManageAssociates = '/settings/manage-associates';

  /// The delete-request queue (Task 20 Phase 4): a reviewer's pending list, or
  /// the requester's own requests. Opened by the Settings dashboard entry.
  static const String settingsDeleteRequests = '/settings/delete-requests';

  /// One delete request's review screen, opened from the queue above.
  static const String settingsReviewDeleteRequest =
      '/settings/delete-requests/review/:requestId';
  static const String settingsSubscription = '/settings/subscription';
  static const String settingsSubscriptionDetails =
      '/settings/subscription/details';

  /// The `focus` query parameter on the Subscription Details sub-page.
  ///
  /// Set to [subscriptionFocusHistory] by the checkout after a confirmed submit,
  /// so the page scrolls its Payment History — where the new pending purchase
  /// sits — into view rather than opening at the top.
  static const String subscriptionFocusParam = 'focus';

  /// The [subscriptionFocusParam] value that asks for the Payment History.
  static const String subscriptionFocusHistory = 'history';

  /// The Subscription Details sub-page as the checkout opens it: the Payment
  /// History section scrolled into view.
  static const String subscriptionDetailsFromCheckout =
      '$settingsSubscriptionDetails?$subscriptionFocusParam=$subscriptionFocusHistory';
  static const String settingsOnlineSync = '/settings/online-sync';

  /// The queue, its filters, and the diagnostic-bundle export
  /// (Task 19 Phase 4). Opened by the header badge and by Online Sync.
  static const String settingsSyncStatus = '/settings/online-sync/status';

  /// One conflict, opened by the app-wide banner and by Sync Status.
  static const String settingsReviewConflict =
      '/settings/online-sync/conflict/:conflictId';
  static const String settingsBackupRestore = '/settings/backup-restore';
  static const String settingsEditCourtSteps = '/settings/edit-court-steps';
  static const String settingsEditCourtNamesCategory =
      '/settings/edit-court-steps/court-names-category';
  static const String settingsCourtCategory =
      '/settings/edit-court-steps/court-category';
  static const String settingsDistrictList =
      '/settings/edit-court-steps/district-list';
  static const String settingsDistrictCourtCategories =
      '/settings/edit-court-steps/district-court-categories';
  static const String settingsCourtList =
      '/settings/edit-court-steps/court-list';
  static const String settingsLowerCourtCategoryList =
      '/settings/edit-court-steps/lower-court-category-list';

  /// Marks the Lower Court Categories walkthrough (division → districts →
  /// categories). It is passed as a query parameter so the division and
  /// district pickers can route into that flow's screens.
  static const String lowerCourtCategoryFlow = 'lower_court_categories';

  /// Entry path for the Lower Court Categories flow (the division picker).
  static const String settingsLowerCourtCategories =
      '$settingsCourtCategory?flow=$lowerCourtCategoryFlow';
  static const String settingsCourtNamesSteps =
      '/settings/edit-court-steps/court-names-steps';
  static const String settingsNotifications = '/settings/notifications';
  static const String settingsBatterySetupGuide =
      '/settings/battery-setup-guide';
  static const String settingsViewSettings = '/settings/view-settings';
  static const String settingsGuidelines = '/settings/guidelines';
  static const String settingsAbout = '/settings/about';
  static const String settingsMoreAbout = '/settings/about/more';
  static const String settingsPrivacyPolicy = '/settings/about/privacy';
  static const String settingsTermsOfService = '/settings/about/terms';
  static const String settingsSupport = '/settings/about/support';

  /// The in-app updater's page (0.0.482), pushed from About's Update row.
  static const String settingsAboutUpdate = '/settings/about/update';
  static const String settingsDiagnostics = '/settings/about/diagnostics';
  static const String caseDetail = '/case-detail/:caseId';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String paywall = '/paywall';

  /// The paywall query parameter naming why the screen opened. Only the 50-case
  /// gate sets it, so the "Free Plan Limit Reached" card shows on that entry
  /// alone and every other one (Settings, Manage Associates) hides it.
  static const String paywallReasonParam = 'reason';

  /// The [paywallReasonParam] value the 50-case gate sends.
  static const String paywallReasonLimitReached = 'limit';

  /// The paywall as the 50-case gate opens it — the only entry that shows the
  /// free-limit card.
  static const String paywallFromCaseLimit =
      '$paywall?$paywallReasonParam=$paywallReasonLimitReached';
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

  /// Builds the concrete route path for the case detail screen.
  static String caseDetailPath(String caseId) => '/case-detail/$caseId';

  /// Builds the concrete route path for the Review Conflict screen.
  static String reviewConflictPath(String conflictId) =>
      '/settings/online-sync/conflict/$conflictId';

  /// Builds the concrete route path for the delete-request review screen.
  static String deleteRequestReviewPath(String requestId) =>
      '/settings/delete-requests/review/$requestId';
}

// ---------------------------------------------------------------------------
// Router provider
// ---------------------------------------------------------------------------

/// The route the app opens on, resolved from the user's configured default
/// landing page.
///
/// Shared by the router (which starts there) and by the auth screens (which
/// return there after a successful sign-in), so the preference is honoured in
/// both directions. Falls back to Daily Cause List when settings are
/// unavailable.
final defaultLandingRouteProvider = FutureProvider<String>((ref) async {
  try {
    final repo = await ref.watch(settingsRepositoryProvider.future);
    final s = await repo.getSettings();
    return AppRoutes.landingPageRoute(s.defaultLandingPage);
  } catch (_) {
    // Settings unavailable — keep the built-in default.
    return AppRoutes.dailyCauseList;
  }
});

/// Whether [location] is one of the auth screens.
bool _isAuthRoute(String location) =>
    location == AppRoutes.login ||
    location == AppRoutes.signup ||
    location == AppRoutes.forgotPassword;

/// Whether [location] is a legal document that needs no account to read.
///
/// The sign-up card links to both before the user has an account, and both
/// stores require the Terms of Service and the Privacy Policy to be reachable
/// before sign-up, so these two routes are exempt from the sign-in gate. They
/// render the very screens Settings > About opens — the same routes and the
/// same [LegalDocumentScreen] — so sign-up sees nothing different.
bool _isPublicLegalDocument(String location) =>
    location == AppRoutes.settingsPrivacyPolicy ||
    location == AppRoutes.settingsTermsOfService;

/// Where a tapped notification's payload should take the app.
///
/// One function because there are two readers and they have to agree: the tap
/// listener while the app is running, and this router itself when the tap is what
/// launched the app. A hearing alert's payload **is** the case id, so it opens
/// that case's detail view; the admin payment alert carries its own marker
/// (`paymentAlertPayload`) and opens the page that count is about — Payment
/// Requests, where it can actually be acted on.
///
/// A legal-looking payload that is neither is treated as a case id, which is what
/// it has always been, so no existing alert changes destination.
String notificationPayloadRoute(String payload) => payload == paymentAlertPayload
    ? AppRoutes.adminPaymentRequests
    : AppRoutes.caseDetailPath(payload);

/// Resolves where a navigation to [location] should be sent, from the session
/// facts the router already holds; null means "stay where the user asked".
///
/// Pure, so `app_router_redirect_test.dart` can pin every rule without building
/// the router. [resolveRouteRedirect]'s only caller is `appRouterProvider`.
String? resolveRouteRedirect({
  required bool requiresSignIn,
  required bool signedIn,
  required bool passwordRecoveryPending,
  required String landingRoute,
  required String location,
}) {
  final atAuthRoute = _isAuthRoute(location);

  // A device that must sign in cannot reach the diary without an account — but
  // the legal documents stay readable, because sign-up links to them first.
  if (requiresSignIn &&
      !signedIn &&
      !atAuthRoute &&
      !_isPublicLegalDocument(location)) {
    return AppRoutes.login;
  }

  // A recovery link signs the user in as a side effect of being verified, but
  // that session exists only to change the password. Hold them on the reset
  // screen until they have, and send them there from anywhere else — the flag
  // clears the moment the new password is set.
  if (passwordRecoveryPending) {
    return atAuthRoute ? null : AppRoutes.forgotPassword;
  }

  // Somebody who is signed in has no business on the auth screens.
  if (signedIn && atAuthRoute) return landingRoute;

  return null;
}

/// Bridges Riverpod's auth state into a [Listenable] GoRouter can refresh on.
///
/// The router re-evaluates its redirect whenever the identity changes — signing
/// in, signing out, or the server rejecting a session — and never for a token
/// refresh, because the auth state only changes when the identity does.
class AuthRouterRefresh extends ChangeNotifier {
  /// Subscribes to the auth state for as long as the router lives.
  AuthRouterRefresh(Ref ref) {
    _subscription = ref.listen<AsyncValue<AuthState>>(
      authViewModelProvider,
      (_, _) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AsyncValue<AuthState>> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

/// Provides the configured [GoRouter] instance.
///
/// Awaits the configured landing page and the sign-in gate before constructing
/// the router, so the first frame is already the right screen: a device with
/// nothing on it opens Login, and a device that already holds the user's own
/// diary opens its usual landing page and is asked to sign in rather than
/// forced to (see `auth_gate.dart`).
final appRouterProvider = FutureProvider<GoRouter>((ref) async {
  var initialLocation = await ref.watch(defaultLandingRouteProvider.future);

  // A tap that launched the app opens that notification's own screen directly,
  // overriding the configured landing page for this one launch (Task 13 Phase 1,
  // item 5 for a hearing alert; the admin payment alert joined it in 0.0.500).
  try {
    final payload = await ref
        .read(notificationSchedulerProvider)
        .launchPayload();
    if (payload != null && payload.isNotEmpty) {
      initialLocation = notificationPayloadRoute(payload);
    }
  } catch (_) {
    // No notification launched the app (or the platform has no plugin).
  }

  // Decided once per launch from facts already on the device. A later sign-out
  // clears the gate flag, which the logout flow (Task 19) handles by navigating
  // explicitly; nothing here re-gates a running app.
  final requiresSignIn = await ref.watch(authGateRequiredProvider.future);
  if (requiresSignIn) initialLocation = AppRoutes.login;

  // A sign-up still waiting for its confirmation mail owns the first frame: the
  // user left the app to read that mail, and the screen that says so — with Open
  // Mail, Resend Email and Change Email Address on it — is where they have to
  // come back to, not an empty form. It is read *after* the gate above, which
  // would otherwise send them to Login; Sign Up is an auth route, so the gate
  // stays satisfied while they are there.
  if (ref.read(localAuthServiceProvider).pendingConfirmationEmail != null) {
    initialLocation = AppRoutes.signup;
  }

  final refresh = AuthRouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: initialLocation,
    debugLogDiagnostics: false,
    refreshListenable: refresh,
    // Every rule lives in [resolveRouteRedirect], which is pure so the guard
    // can be unit-tested without building the router.
    redirect: (context, state) => resolveRouteRedirect(
      requiresSignIn: requiresSignIn,
      signedIn: ref.read(authIdentityProvider) != null,
      passwordRecoveryPending: ref.read(passwordRecoveryPendingProvider),
      landingRoute:
          ref.read(defaultLandingRouteProvider).value ??
          AppRoutes.dailyCauseList,
      location: state.matchedLocation,
    ),
    routes: [
      // ------------------------------------------------------------------
      // Shell route — wraps all main screens with AppShellRoot + DatabaseGuard.
      // AppShellRoot owns the PopScope exit-confirmation (Dev Workflow §6).
      // ------------------------------------------------------------------
      ShellRoute(
        builder: (context, state, child) => AppShellRoot(
          // A bottom-nav screen renders its own banner directly above its nav
          // bar; every other shell screen gets the one the shell owns, so no
          // screen shows it twice and none shows none.
          showConflictBanner: !_bottomNavRoutes.contains(state.matchedLocation),
          child: DatabaseGuard(child: child),
        ),
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
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      // The legal documents are full-page screens, not Settings sub-pages: they
      // sit on the root navigator like the paywall and checkout, so their back
      // button pops GoRouter's history from either entry point. Inside the shell
      // they lived on the shell's nested navigator, where a document opened
      // from Sign Up had nothing beneath it and its back button did nothing.
      GoRoute(
        path: AppRoutes.settingsPrivacyPolicy,
        builder: (context, state) =>
            const LegalDocumentScreen(document: LegalDocument.privacyPolicy),
      ),
      GoRoute(
        path: AppRoutes.settingsTermsOfService,
        builder: (context, state) =>
            const LegalDocumentScreen(document: LegalDocument.termsOfService),
      ),
      GoRoute(
        path: AppRoutes.paywall,
        // Only the 50-case gate names its reason (`?reason=limit`); every other
        // entry opens the bare route and hides the "Free Plan Limit Reached"
        // card, which belongs to that gate alone.
        builder: (context, state) =>
            PaywallScreen(showLimit: PaywallScreen.showLimitFor(state)),
      ),
      GoRoute(
        path: AppRoutes.checkout,
        // The plan travels as a query parameter (`?plan=monthly|annual`) so the
        // paywall's plan tap needs no second route and a restored deep link
        // still names the plan it was opened for.
        builder: (context, state) => CheckoutScreen(
          planKey: state.uri.queryParameters['plan'],
        ),
      ),
    ],
  );
});

/// Shell-level routes (all screens that share the bottom nav / drawer shell).
///
/// The screens a bottom nav tab opens are built as [NoTransitionPage]s, so
/// switching between them is instant rather than animated. The default
/// transition is a zoom-and-fade, and that motion is what was making some users
/// feel unwell; a plain switch has no motion at all. Only the bottom nav's own
/// screens are declared this way — every other route keeps the app's normal
/// transition. Note that GoRouter picks the transition from the route, not from
/// what was tapped, so a route declared here is also instant when the drawer (or
/// a case-list summary card) opens the same screen.
/// The shell routes whose screen draws the bottom navigation bar itself.
///
/// Exactly the screens built on `CasesScreenModal`, which is where the nav bar
/// lives. They render the conflict banner inside that shell, above the nav bar;
/// `AppShellRoot` renders it for every other shell screen instead.
const Set<String> _bottomNavRoutes = <String>{
  AppRoutes.dailyCauseList,
  AppRoutes.allCases,
  AppRoutes.activeCases,
  AppRoutes.upcomingCases,
  AppRoutes.overdueDates,
  AppRoutes.disposedCases,
  AppRoutes.notes,
  AppRoutes.caseReference,
};

final List<RouteBase> _shellRoutes = [
  GoRoute(
    path: AppRoutes.dailyCauseList,
    pageBuilder: (context, state) =>
        const NoTransitionPage(child: DailyCauseListScreen()),
  ),
  GoRoute(
    path: AppRoutes.allCases,
    pageBuilder: (context, state) =>
        const NoTransitionPage(child: AllCasesScreen()),
  ),
  GoRoute(
    path: AppRoutes.activeCases,
    pageBuilder: (context, state) =>
        const NoTransitionPage(child: ActiveCasesScreen()),
  ),
  GoRoute(
    path: AppRoutes.upcomingCases,
    pageBuilder: (context, state) =>
        const NoTransitionPage(child: UpcomingCasesScreen()),
  ),
  GoRoute(
    path: AppRoutes.overdueDates,
    pageBuilder: (context, state) =>
        const NoTransitionPage(child: OverdueDatesScreen()),
  ),
  GoRoute(
    path: AppRoutes.disposedCases,
    pageBuilder: (context, state) =>
        const NoTransitionPage(child: DisposedCasesScreen()),
  ),
  GoRoute(
    path: AppRoutes.notes,
    pageBuilder: (context, state) =>
        const NoTransitionPage(child: NotesScreen()),
  ),
  GoRoute(
    path: AppRoutes.caseReference,
    pageBuilder: (context, state) =>
        const NoTransitionPage(child: CaseReferenceScreen()),
  ),
  GoRoute(
    path: AppRoutes.adminPanel,
    // A NoTransitionPage like every other bottom-nav screen: an admin can place
    // the panel in the bar, and the no-motion rule that guards the bar is about
    // how it feels to switch, not about which screen it is.
    pageBuilder: (context, state) =>
        const NoTransitionPage(child: AdminPanelScreen()),
  ),
  // The panel's own sub-pages, pushed from its menu. Plain `builder:` routes,
  // so they arrive with the platform transition and a back arrow, exactly like
  // the Settings sub-pages they are modelled on.
  GoRoute(
    path: AppRoutes.adminPaymentRequests,
    builder: (context, state) => const AdminPaymentRequestsScreen(),
  ),
  GoRoute(
    path: AppRoutes.adminUnverifiedAccounts,
    builder: (context, state) => const AdminUnconfirmedAccountsScreen(),
  ),
  // Settings tree
  GoRoute(
    path: AppRoutes.settings,
    builder: (context, state) => const SettingsMainScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsLanguage,
    builder: (context, state) => const LanguageScreen(),
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
    path: AppRoutes.settingsDeleteAccount,
    builder: (context, state) => const DeleteAccountScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsChangePassword,
    // The same screen Login opens, in its Settings presentation: the standard
    // sub-page header with a back button, no line out to Login, and a return to
    // Manage Account once the password is set.
    builder: (context, state) =>
        const ForgotPasswordScreen(asSettingsSubPage: true),
  ),
  GoRoute(
    path: AppRoutes.settingsAppLock,
    builder: (context, state) => const AppLockScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsManageAssociates,
    builder: (context, state) => const ManageAssociatesScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsDeleteRequests,
    builder: (context, state) => const DeleteRequestsScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsReviewDeleteRequest,
    builder: (context, state) => DeleteRequestReviewScreen(
      requestId: state.pathParameters['requestId'] ?? '',
    ),
  ),
  GoRoute(
    path: AppRoutes.settingsSubscription,
    builder: (context, state) => const SubscriptionScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsSubscriptionDetails,
    // The checkout names the section it wants in view (`?focus=history`); every
    // other entry (Settings > Subscription) opens the bare route at the top.
    builder: (context, state) => SubscriptionDetailsScreen(
      focusHistory:
          state.uri.queryParameters[AppRoutes.subscriptionFocusParam] ==
          AppRoutes.subscriptionFocusHistory,
    ),
  ),
  GoRoute(
    path: AppRoutes.settingsOnlineSync,
    builder: (context, state) => const OnlineSyncScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsSyncStatus,
    builder: (context, state) => const SyncStatusScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsReviewConflict,
    builder: (context, state) => ReviewConflictScreen(
      conflictId: state.pathParameters['conflictId'] ?? '',
    ),
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
    builder: (context, state) =>
        CourtCategoryScreen(flow: state.uri.queryParameters['flow']),
  ),
  GoRoute(
    path: AppRoutes.settingsDistrictList,
    builder: (context, state) => DistrictListScreen(
      division: state.uri.queryParameters['division'] ?? 'dhaka',
      flow: state.uri.queryParameters['flow'],
    ),
  ),
  GoRoute(
    path: AppRoutes.settingsLowerCourtCategoryList,
    builder: (context, state) => LowerCourtCategoryListScreen(
      division: state.uri.queryParameters['division'] ?? 'dhaka',
      district: state.uri.queryParameters['district'] ?? 'dhaka',
    ),
  ),
  GoRoute(
    path: AppRoutes.settingsDistrictCourtCategories,
    builder: (context, state) => DistrictCourtCategoryScreen(
      division: state.uri.queryParameters['division'] ?? 'dhaka',
      district: state.uri.queryParameters['district'] ?? 'dhaka',
    ),
  ),
  GoRoute(
    path: AppRoutes.settingsCourtList,
    builder: (context, state) => CourtListScreen(
      category: state.uri.queryParameters['category'],
      higherLower: state.uri.queryParameters['higherLower'],
      division: state.uri.queryParameters['division'],
      district: state.uri.queryParameters['district'],
      // Set by the screen that opened this one; data, not URL state, so it is
      // simply absent on a restored route.
      categoryNameKey: state.extra is String ? state.extra! as String : null,
    ),
  ),
  GoRoute(
    path: AppRoutes.settingsCourtNamesSteps,
    builder: (context, state) {
      final kindParam = state.uri.queryParameters['kind'];
      final category = state.uri.queryParameters['category'];
      if (kindParam != null && category != null) {
        return ItemListScreen(
          kind: itemKindFromParam(kindParam),
          categoryId: category,
        );
      }
      return const CourtNamesStepsScreen();
    },
  ),
  GoRoute(
    path: AppRoutes.settingsNotifications,
    builder: (context, state) => const NotificationSettingsScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsBatterySetupGuide,
    builder: (context, state) => const BatterySetupGuideScreen(),
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
  GoRoute(
    path: AppRoutes.settingsMoreAbout,
    builder: (context, state) => const MoreAboutTheAppScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsSupport,
    builder: (context, state) => const SupportScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsAboutUpdate,
    builder: (context, state) => const UpdateScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsDiagnostics,
    builder: (context, state) => const DiagnosticsScreen(),
  ),
];

// ---------------------------------------------------------------------------
// Shell root with back/exit confirmation (Dev Workflow §6)
// ---------------------------------------------------------------------------

/// Larger, legible button style used by the exit-confirmation actions.
final ButtonStyle _exitButtonStyle = TextButton.styleFrom(
  minimumSize: const Size(112, 48),
  textStyle: const TextStyle(fontSize: 16),
);

/// Wraps the shell child with exit-confirmation on system back at the root.
///
/// Shows an [AlertDialog] asking the user to confirm exit. Prevents black
/// screens by never allowing an accidental pop of the root navigator.
class AppShellRoot extends StatelessWidget {
  final Widget child;

  /// Whether this shell draws the app-wide conflict banner itself.
  ///
  /// False for the bottom-nav screens, which put it above their own nav bar.
  final bool showConflictBanner;

  const AppShellRoot({
    required this.child,
    this.showConflictBanner = true,
    super.key,
  });

  /// Shows the exit-confirmation dialog and, on confirm, closes the app.
  /// Used by screens that have no in-router history to fall back to the same
  /// behaviour as the shell's system-back gesture. The close itself goes
  /// through [closeApp], because `SystemNavigator.pop()` only dispatches an
  /// Android back press on this Flutter and leaves the app running.
  static Future<void> requestExit(BuildContext context) async {
    final shouldExit = await _confirmExit(context);
    if (shouldExit && context.mounted) {
      await closeApp();
    }
  }

  static Future<bool> _confirmExit(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.appShell_exitTitle),
        content: Text(l.appShell_exitMessage),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            style: _exitButtonStyle,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.sharedActions_cancel),
          ),
          TextButton(
            style: _exitButtonStyle,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.appShell_exit),
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
          await closeApp();
        }
      },
      // Shell screens own the app's status-bar inset. Keep this outside the
      // modal navigator so full-height sheets can use their own safe area.
      child: SafeArea(
        top: true,
        bottom: false,
        child: showConflictBanner
            ? Column(
                children: [
                  Expanded(child: child),
                  // All sit at the foot of the shell, so none covers content.
                  // The subscription bar is first because it explains why sync
                  // is about to stop; the notice is the dismissible one; the
                  // conflict banner is frozen work and never hidden.
                  const SubscriptionBanner(),
                  const SyncNoticeBanner(),
                  const SyncConflictBanner(),
                ],
              )
            : child,
      ),
    );
  }
}
