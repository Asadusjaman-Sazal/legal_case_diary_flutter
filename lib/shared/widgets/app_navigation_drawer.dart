/// Left navigation drawer for all case screens.
///
/// Displays a profile header, grouped nav items, the account's **current plan**
/// (expanding into Subscription Details and Subscription Plans) and Print/Share
/// actions. Active item is highlighted with a black pill. Item visibility is
/// driven by [sideNavOptions] from [UserSettings].
///
/// **The profile icon is the account's own entry point** (user request): tapping
/// the header avatar opens a sheet naming the signed-in **e-mail** and offering
/// **Profile**, **Manage Account** and **Logout** — the three account actions
/// that otherwise live two levels down under Settings > Account & Profile.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/app_version.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/router/app_router.dart';
import '../../features/admin/presentation/admin_viewmodel.dart';
import '../../features/accounts_and_profile/data/profile_name_store.dart';
import '../../features/accounts_and_profile/data/profile_picture_store.dart';
import '../../features/auth/presentation/auth_viewmodel.dart';
import '../../features/auth/presentation/logout_dialogs.dart';
import '../../features/payments/presentation/current_plan.dart';

/// A nav item descriptor used to build drawer rows.
class _NavItem {
  /// Key used for [sideNavOptions] visibility lookup AND as the route path.
  final String visibilityKey;
  final IconData icon;
  final String Function(AppLocalizations) label;
  final String route;

  /// Whether Settings > View Settings may hide this item. Settings itself is
  /// not removable, so a stale `false` for it in [sideNavOptions] is ignored.
  final bool removable;

  /// Whether only an administrator may be shown this item (Task 22).
  ///
  /// Separate from [removable]: a non-admin cannot hide the Admin Panel, they
  /// simply never see it, and a stale `false` or a leftover `sideNavOptions`
  /// entry cannot conjure it into view either.
  final bool adminOnly;

  const _NavItem({
    required this.visibilityKey,
    required this.icon,
    required this.label,
    required this.route,
    this.removable = true,
    this.adminOnly = false,
  });
}

/// Navigation drawer matching the Daily Cause List mockup.
///
/// [currentRoute] — the active GoRouter location (e.g. `/daily-cause-list`).
/// [sideNavOptions] — map from [UserSettings.sideNavOptions]; keys that map
///   to `false` hide the corresponding item. Unknown keys default to visible,
///   and Settings is never hidden (it is the way back to this screen).
///   Optional keys: All Cases, Active Cases, Daily Cause List, Overdue Dates,
///   Upcoming Cases, Disposed Cases, Case Reference, Notes — the canonical
///   order Settings > View Settings lists them in.
/// [displayName] — optional override for the header name; defaults to the
///   saved Profile Full Name (see [profileNameProvider]).
/// [onPrint] — callback for the Print action (Task 14 implements the service).
/// [onShare] — callback for the Share action (Task 14 implements the service).
///
/// The header avatar shows the saved profile picture ([profilePictureProvider])
/// with the generic person icon as the fallback.
class AppNavigationDrawer extends ConsumerWidget {
  final String currentRoute;
  final Map<String, dynamic> sideNavOptions;
  final String? displayName;
  final VoidCallback? onPrint;
  final VoidCallback? onShare;

  const AppNavigationDrawer({
    required this.currentRoute,
    this.sideNavOptions = const {},
    this.displayName,
    this.onPrint,
    this.onShare,
    super.key,
  });

  /// Case screens, in the canonical app screen order used by
  /// [bottomNavTabDefs] and by Settings > View Settings.
  static const List<_NavItem> _caseItems = [
    _NavItem(
      visibilityKey: AppRoutes.allCases,
      icon: Icons.list_alt_outlined,
      label: _labelAllCases,
      route: AppRoutes.allCases,
    ),
    _NavItem(
      visibilityKey: AppRoutes.activeCases,
      icon: Icons.work_outline,
      label: _labelActiveCases,
      route: AppRoutes.activeCases,
    ),
    _NavItem(
      visibilityKey: AppRoutes.dailyCauseList,
      icon: Icons.calendar_today_outlined,
      label: _labelDailyCauseList,
      route: AppRoutes.dailyCauseList,
    ),
    _NavItem(
      visibilityKey: AppRoutes.overdueDates,
      icon: Icons.error_outline,
      label: _labelOverdueDates,
      route: AppRoutes.overdueDates,
    ),
    _NavItem(
      visibilityKey: AppRoutes.upcomingCases,
      icon: Icons.event_outlined,
      label: _labelUpcoming,
      route: AppRoutes.upcomingCases,
    ),
    _NavItem(
      visibilityKey: AppRoutes.disposedCases,
      icon: Icons.gavel_outlined,
      label: _labelDisposedCases,
      route: AppRoutes.disposedCases,
    ),
  ];

  static const List<_NavItem> _toolItems = [
    _NavItem(
      visibilityKey: AppRoutes.caseReference,
      icon: Icons.menu_book_outlined,
      label: _labelCaseReference,
      route: AppRoutes.caseReference,
    ),
    _NavItem(
      visibilityKey: AppRoutes.notes,
      icon: Icons.sticky_note_2_outlined,
      label: _labelNotes,
      route: AppRoutes.notes,
    ),
    _NavItem(
      visibilityKey: AppRoutes.settings,
      icon: Icons.settings_outlined,
      label: _labelSettings,
      route: AppRoutes.settings,
      removable: false,
    ),
  ];

  /// Task 22: shown only to an admin, and after Settings so it never
  /// displaces an ordinary entry in a drawer an admin already arranged.
  static const _NavItem _adminItem = _NavItem(
    visibilityKey: AppRoutes.adminPanel,
    icon: Icons.admin_panel_settings_outlined,
    label: _labelAdminPanel,
    route: AppRoutes.adminPanel,
    adminOnly: true,
  );

  static String _labelUpcoming(AppLocalizations l) => l.nav_upcomingCases;
  static String _labelDailyCauseList(AppLocalizations l) =>
      l.nav_dailyCauseList;
  static String _labelAllCases(AppLocalizations l) => l.nav_allCases;
  static String _labelActiveCases(AppLocalizations l) => l.nav_activeCases;
  static String _labelOverdueDates(AppLocalizations l) => l.nav_overdueDates;
  static String _labelDisposedCases(AppLocalizations l) => l.nav_disposedCases;
  static String _labelCaseReference(AppLocalizations l) => l.nav_caseReference;
  static String _labelNotes(AppLocalizations l) => l.nav_notes;
  static String _labelSettings(AppLocalizations l) => l.nav_settings;
  static String _labelAdminPanel(AppLocalizations l) => l.nav_adminPanel;

  bool _isVisible(_NavItem item, {required bool isAdmin}) {
    // A gated item is never merely hidden by a preference — a non-admin does
    // not get a way to bring it back, and a leftover `sideNavOptions` entry
    // from an earlier admin session cannot reveal it.
    if (item.adminOnly && !isAdmin) return false;
    return !item.removable || sideNavOptions[item.visibilityKey] != false;
  }

  bool _isActive(String route) => currentRoute == route;

  Widget _buildItem(
    BuildContext context,
    AppLocalizations l,
    _NavItem item, {
    required bool isAdmin,
  }) {
    if (!_isVisible(item, isAdmin: isAdmin)) return const SizedBox.shrink();
    final active = _isActive(item.route);
    return _DrawerNavTile(
      icon: item.icon,
      label: item.label(l),
      active: active,
      onTap: () {
        Navigator.of(context).pop();
        if (!active) context.push(item.route);
      },
    );
  }

  /// Opens the account sheet the profile icon leads to (user request).
  ///
  /// The sheet goes on the **root navigator**, above the panel: it is shown
  /// while the drawer is still open, and the drawer is closed by whichever row
  /// the user picks — so a dismissed sheet returns the user to the panel they
  /// opened, and a chosen row returns them to the screen behind it.
  ///
  /// The panel's own `ref` is deliberately not handed on: it dies with the
  /// drawer, and **Logout** needs a live one for as long as its windows are up.
  /// The sheet is therefore a widget with its own, and the two navigators are
  /// passed as state objects rather than as contexts.
  Future<void> _openAccountSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (_) => _AccountSheet(
        // Read here, so the sheet is never the reason the drawer must still
        // exist: the address is a value, not a live lookup.
        email: ref.read(authIdentityProvider)?.email ?? '',
        // The navigator the panel is closed through, and the router the rows
        // navigate with. Both are objects: safe once the drawer is gone.
        drawerNavigator: Navigator.of(context),
        router: GoRouter.of(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    // Shared profile state: the locally saved picture and the Full Name from
    // Settings > Account & Profile > Profile.
    final avatarFile = ref.watch(profilePictureProvider);
    final savedName = ref.watch(profileNameProvider);
    final headerName = (displayName ?? savedName).trim();
    // The header reads as a possessive phrase, so the app name and the lawyer's
    // name swap places between the two languages ("Legal Case Diary of <name>"
    // vs "<name> এর লিগ্যাল কেস ডায়েরি").
    final isBengali = l.localeName.startsWith('bn');
    final nameLine = headerName.isNotEmpty ? headerName : '—';
    // Task 22: the Admin Panel row exists only for an account the server has
    // confirmed as an admin, and false while that answer is still loading.
    final isAdmin = ref.watch(adminStatusProvider).value ?? false;
    return Drawer(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ----------------------------------------------------------------
            // Profile header — avatar with three centre-aligned lines: the app
            // name, the "of" / "এর" connector, and the lawyer's name.
            // ----------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // The avatar opens the account sheet — its 48 px circle is
                  // the whole tap target, and it carries a label because an
                  // icon-only button has no text for a screen reader.
                  Semantics(
                    button: true,
                    label: l.settingsScreen_accountAndProfile,
                    child: InkWell(
                      key: const ValueKey('drawer-profile-icon'),
                      customBorder: const CircleBorder(),
                      onTap: () => _openAccountSheet(context, ref),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primaryContainer,
                        backgroundImage: avatarFile != null
                            ? FileImage(avatarFile)
                            : null,
                        child: avatarFile != null
                            ? null
                            : const Icon(
                                Icons.person_outline,
                                color: AppColors.onPrimaryContainer,
                                size: 26,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (isBengali) ...[
                          _headerLine(
                            nameLine,
                            AppTypography.titleLg.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                          _headerLine(l.drawerOf, _connectorStyle),
                          _headerLine(l.appName, _appNameStyle),
                        ] else ...[
                          _headerLine(l.appName, _appNameStyle),
                          _headerLine(l.drawerOf, _connectorStyle),
                          _headerLine(
                            nameLine,
                            AppTypography.titleLg.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.outlineVariant),
            const SizedBox(height: 4),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  ..._caseItems.map(
                    (item) => _buildItem(context, l, item, isAdmin: isAdmin),
                  ),
                  const _DrawerDivider(),
                  ..._toolItems.map(
                    (item) => _buildItem(context, l, item, isAdmin: isAdmin),
                  ),
                  if (isAdmin) ...[
                    const _DrawerDivider(),
                    _buildItem(context, l, _adminItem, isAdmin: true),
                  ],
                  const _DrawerDivider(),
                  // The account's plan, above Print/Share (user request): the
                  // bottom group is where a user looks for what the account is
                  // and what it can do with it, and it names the plan rather
                  // than hiding it behind a tap.
                  _PlanDrawerTile(currentRoute: currentRoute),
                  _DrawerNavTile(
                    icon: Icons.print_outlined,
                    label: l.nav_print,
                    active: false,
                    onTap: () {
                      Navigator.of(context).pop();
                      onPrint?.call();
                    },
                  ),
                  _DrawerNavTile(
                    icon: Icons.share_outlined,
                    label: l.nav_share,
                    active: false,
                    onTap: () {
                      Navigator.of(context).pop();
                      onShare?.call();
                    },
                  ),
                ],
              ),
            ),
            // The bundled app version pinned to the very bottom of the drawer,
            // below all nav items and Print/Share. Read from [appVersion] so it
            // can never drift from the build.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Text(
                l.drawer_version(appVersion),
                textAlign: TextAlign.left,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Centred single-line header text with an ellipsis guard.
Widget _headerLine(String text, TextStyle style) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 1),
  child: Text(
    text,
    style: style,
    textAlign: TextAlign.center,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  ),
);

/// Style for the app-name line in the profile header.
final TextStyle _appNameStyle = AppTypography.labelMd.copyWith(
  color: AppColors.primary,
  letterSpacing: 0.8,
);

/// Style for the "of" / "এর" connector line in the profile header.
final TextStyle _connectorStyle = AppTypography.labelMd.copyWith(
  color: AppColors.onSurfaceVariant,
);

/// Left padding that puts a child row under its group's icon column.
const double _planSubIndent = 24;

class _DrawerNavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  /// Extra left padding, so a sub-row reads as belonging to the row above it.
  final double indent;

  const _DrawerNavTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.indent = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        // Black fill for the selected screen, matching the app's black action
        // buttons (Update, Call, Message, Add Case, ...).
        color: active ? Colors.black : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                if (indent > 0) SizedBox(width: indent),
                Icon(
                  icon,
                  size: 22,
                  color: active ? Colors.white : AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.labelLg.copyWith(
                      color: active ? Colors.white : AppColors.onSurfaceVariant,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The current plan, and the two subscription pages it opens (user request).
///
/// The header **shows the plan** — [currentPlanProvider], the same derivation
/// Subscription Details prints — and expands in place instead of navigating:
/// once a user has read which plan is running, the two things they want are
/// the page about it (**Subscription Details**) and the page that sells the
/// next one (**Subscription Plans**). Each child row opens its screen and
/// closes the drawer, exactly like every other drawer item.
///
/// It arrives expanded when the app is already on one of those two screens, so
/// the active row is never hidden inside a collapsed header.
class _PlanDrawerTile extends ConsumerStatefulWidget {
  /// Creates the plan row for the active [currentRoute].
  const _PlanDrawerTile({required this.currentRoute});

  /// The active GoRouter location, so the opened sub-page is the one filled.
  final String currentRoute;

  @override
  ConsumerState<_PlanDrawerTile> createState() => _PlanDrawerTileState();
}

class _PlanDrawerTileState extends ConsumerState<_PlanDrawerTile> {
  late bool _expanded;

  /// Whether [route] is one of the two screens this row opens.
  static bool _opens(String route) =>
      route == AppRoutes.settingsSubscriptionDetails ||
      route == AppRoutes.paywall;

  @override
  void initState() {
    super.initState();
    _expanded = _opens(widget.currentRoute);
  }

  /// Closes the drawer and opens [route], unless it is already the screen.
  void _open(String route) {
    Navigator.of(context).pop();
    if (widget.currentRoute != route) context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final plan = currentPlanLabel(l, ref.watch(currentPlanProvider));
    return Column(
      children: [
        // The header keeps the drawer's own row metrics; only the children
        // below it are indented, so the plan reads as their group title.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          child: Semantics(
            button: true,
            expanded: _expanded,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.workspace_premium_outlined,
                        size: 22,
                        color: AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          // Two lines: the plan, and the caption saying what that
                          // word is — a bare "Free" beside a chevron would read
                          // as the name of a screen.
                          children: [
                            Text(
                              plan,
                              style: AppTypography.labelLg.copyWith(
                                color: AppColors.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              l.settingsSubscription_currentPlan,
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 22,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_expanded) ...[
          _DrawerNavTile(
            icon: Icons.star_outline,
            label: l.settingsManageAccount_subscriptionDetails,
            active: widget.currentRoute == AppRoutes.settingsSubscriptionDetails,
            indent: _planSubIndent,
            onTap: () => _open(AppRoutes.settingsSubscriptionDetails),
          ),
          _DrawerNavTile(
            icon: Icons.add_shopping_cart_outlined,
            label: l.paywall_title,
            active: widget.currentRoute == AppRoutes.paywall,
            indent: _planSubIndent,
            onTap: () => _open(AppRoutes.paywall),
          ),
        ],
      ],
    );
  }
}

/// The account sheet (user request): the signed-in e-mail and the three account
/// actions, opened from the drawer's profile icon.
///
/// A [ConsumerWidget] rather than a builder closure for one reason: **Logout
/// has to run while this widget is still mounted.** [runBranchedLogout] reads
/// providers and opens windows, so the `ref` it is given must outlive every
/// surface closed to make room for it — and the drawer's `ref` cannot, because
/// the panel is gone the moment it closes. The sheet stays up behind the logout
/// windows, and closes itself when they are done.
class _AccountSheet extends ConsumerWidget {
  const _AccountSheet({
    required this.email,
    required this.drawerNavigator,
    required this.router,
  });

  /// The address the account signed in with; a dash when there is none.
  final String email;

  /// The navigator the panel is closed through — a state, so it is still safe
  /// to use after this widget's neighbours are gone.
  final NavigatorState drawerNavigator;

  /// The app's router, for the two destinations and for Login.
  final GoRouter router;

  /// Closes the panel, so the user comes back to the screen it was opened from
  /// — exactly what every other drawer row does.
  void _closeDrawer() {
    if (drawerNavigator.mounted) drawerNavigator.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Who this account is: the address it signed in with. The value
          // carries the caption under it, like the plan row's — the address is
          // the fact, and the caption says which fact it is.
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              children: [
                const Icon(
                  Icons.alternate_email,
                  size: 22,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        email.isNotEmpty ? email : '—',
                        style: AppTypography.labelLg.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        l.auth_emailLabel,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.outlineVariant),
          ListTile(
            key: const ValueKey('drawer-account-profile'),
            leading: const Icon(Icons.person_outline),
            title: Text(l.settingsScreen_profile),
            onTap: () {
              _closeDrawer();
              Navigator.of(context).pop();
              router.push(AppRoutes.settingsProfile);
            },
          ),
          ListTile(
            key: const ValueKey('drawer-account-manage'),
            leading: const Icon(Icons.manage_accounts_outlined),
            title: Text(l.settingsScreen_manageAccount),
            onTap: () {
              _closeDrawer();
              Navigator.of(context).pop();
              router.push(AppRoutes.settingsManageAccount);
            },
          ),
          ListTile(
            key: const ValueKey('drawer-account-logout'),
            leading: const Icon(Icons.logout),
            title: Text(l.settingsManageAccount_logout),
            onTap: () async {
              _closeDrawer();
              // The sheet stays up while the logout windows run: this widget's
              // `ref` is what the one branched logout reads its providers
              // through, and it must be alive for the whole flow.
              final completed = await runBranchedLogout(context, ref);
              if (!context.mounted) return;
              Navigator.of(context).pop();
              // Login is reached explicitly: the router's sign-in gate is
              // decided once per launch, so a signed-out user would otherwise
              // be left on the now-empty shell.
              if (completed) router.go(AppRoutes.login);
            },
          ),
        ],
      ),
    );
  }
}

class _DrawerDivider extends StatelessWidget {
  const _DrawerDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Divider(height: 1, color: AppColors.outlineVariant),
    );
  }
}
