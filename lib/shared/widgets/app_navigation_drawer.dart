/// Left navigation drawer for all case screens.
///
/// Displays a profile header, grouped nav items, the account's **current plan**
/// (expanding into Subscription Details and Subscription Plans) and Print/Share
/// actions. Active item is highlighted with a black pill. Item visibility is
/// driven by [sideNavOptions] from [UserSettings].
///
/// **The profile icon carries a small chevron badge** (user request, 0.0.433):
/// a 16 px disc in the avatar's bottom-right corner, filled with the panel's own
/// background and ringed in the divider grey, holding the `expand_more` the plan
/// row uses — an affordance that marks the avatar as a menu without covering it.
/// **The panel lines up with the side menu** (user request, 0.0.433): its left
/// edge is the drawer's left edge, and its 300 px width stays inside the drawer's
/// 304 px, so it never crosses the panel. **A thin grey edge** (user request,
/// 0.0.433) — `AppColors.outlineVariant`, the drawer's divider grey — outlines
/// the panel, so a white menu over the white drawer can be told from the panel
/// beneath it.
///
/// **The profile icon is the account's own entry point** (user request): tapping
/// the header avatar opens a popover anchored to it, naming the signed-in
/// **e-mail** and offering **Profile**, **Manage Account** and **Logout** — the
/// three account actions that otherwise live two levels down under Settings >
/// Account & Profile.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
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

  /// Opens the account popover **against the profile icon** (user request).
  ///
  /// The panel is positioned from the icon's own rectangle — its top edge just
  /// below the icon, its left edge on the drawer's — so it reads as growing out
  /// of the icon rather than sliding up from the screen's bottom, the way the
  /// account switcher does in Google's apps. [iconContext] is the icon's own
  /// context, which is what makes that measurement possible; the route goes on
  /// the **root navigator**, above the open panel, and the icon is measured in
  /// that navigator's overlay because that is the space the panel is laid out
  /// in.
  ///
  /// The panel's own `ref` is deliberately not handed on: it dies with the
  /// drawer, and **Logout** needs a live one for as long as its windows are up.
  /// The panel is therefore a widget with its own, and the two navigators reach
  /// it as state objects rather than as contexts.
  void _openAccountSheet(BuildContext iconContext, WidgetRef ref) {
    final navigator = Navigator.of(iconContext, rootNavigator: true);
    final overlay = navigator.overlay?.context.findRenderObject() as RenderBox?;
    final icon = iconContext.findRenderObject() as RenderBox?;
    // Nothing to anchor to without an overlay, so nothing opens rather than a
    // panel landing in a corner the user did not point at.
    if (overlay == null || icon == null) return;
    navigator.push<void>(
      _AccountPopoverRoute(
        anchor: icon.localToGlobal(Offset.zero, ancestor: overlay) & icon.size,
        builder: (_) => _AccountPopover(
          // Read here, so the panel is never the reason the drawer must still
          // exist: the address is a value, not a live lookup.
          email: ref.read(authIdentityProvider)?.email ?? '',
          // The navigator the panel is closed through, and the router the rows
          // navigate with. Both are objects: safe once the drawer is gone.
          drawerNavigator: Navigator.of(iconContext),
          router: GoRouter.of(iconContext),
        ),
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
                  // The avatar is the account's entry point: its 48 px circle
                  // is the whole tap target, and the popover is measured from
                  // this box, so the panel grows out of the icon.
                  _ProfileIconButton(
                    onPressed: (iconContext) =>
                        _openAccountSheet(iconContext, ref),
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

/// The profile icon, as the button the account popover grows from.
///
/// A widget of its own so the tap can measure **this** rectangle: the popover is
/// positioned against the icon it belongs to, and that is what makes the two
/// read as connected. A composite widget's `findRenderObject` descends to the
/// first render object *below* it, so this element's box is the avatar's own
/// 48 px circle. It also carries the semantics label an icon-only button needs.
///
/// The icon carries a **small chevron badge** in its bottom-right corner (user
/// request): an avatar reads as a picture, so nothing said it could be tapped.
/// The badge is deliberately tiny — a 16 px disc, filled with the panel's own
/// background and ringed in the drawer's divider grey, holding the same
/// `expand_more` the plan row uses — so it marks the icon as a menu without
/// covering the face of the avatar or the name beside it. It sits inside the
/// avatar's 48 px box, so it neither grows the tap target nor moves the
/// rectangle the popover is measured from.
class _ProfileIconButton extends StatelessWidget {
  const _ProfileIconButton({required this.child, required this.onPressed});

  /// The avatar to draw.
  final Widget child;

  /// Called with this widget's own context, so the caller can measure it.
  final void Function(BuildContext iconContext) onPressed;

  /// Diameter of the affordance badge — big enough to read at a glance,
  /// small enough to leave the avatar's own shape intact.
  static const double _badgeSize = 16;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: AppLocalizations.of(context).settingsScreen_accountAndProfile,
    child: InkWell(
      key: const ValueKey('drawer-profile-icon'),
      customBorder: const CircleBorder(),
      onTap: () => onPressed(context),
      child: Stack(
        children: [
          child,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              key: const ValueKey('drawer-profile-icon-indicator'),
              width: _badgeSize,
              height: _badgeSize,
              decoration: BoxDecoration(
                // The panel's own fill, so the badge reads as a cut-out marker
                // on the avatar rather than a second coloured dot.
                color: AppColors.surfaceContainerLowest,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: const Icon(
                Icons.expand_more,
                size: 12,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The account popover (user request): the signed-in e-mail and the three
/// account actions, shown at the drawer's profile icon.
///
/// A [ConsumerWidget] rather than a builder closure for one reason: **Logout
/// has to run while this widget is still mounted.** [runBranchedLogout] reads
/// providers and opens windows, so the `ref` it is given must outlive every
/// surface closed to make room for it — and the drawer's `ref` cannot, because
/// the panel is gone the moment it closes. The popover stays up behind the
/// logout windows and closes itself when they are done.
class _AccountPopover extends ConsumerWidget {
  const _AccountPopover({
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
    // A floating panel, not a sheet: it carries its own elevation and rounding
    // and floats over the open drawer, which is what makes it look attached to
    // the icon. Its width and position come from the route's layout delegate.
    return Material(
      key: const ValueKey('drawer-account-popover'),
      color: AppColors.surfaceContainerLowest,
      elevation: 8,
      // The app's card radius, which is also the radius Material's own menus
      // use — a menu-like panel, not a sheet. The one-thing-more is a **thin
      // grey edge** (user request): the panel and the drawer it floats over are
      // both white, so the shadow alone left the user unable to tell where the
      // menu ends and the panel behind it begins. The colour is the drawer's own
      // divider grey, so the edge speaks the drawer's language rather than
      // introducing a new one.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
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

/// The account popover's route: the panel, anchored to the drawer's profile
/// icon.
///
/// A [PopupRoute] rather than a bottom sheet, so the panel appears at the icon
/// instead of at the screen's bottom edge, and a tap anywhere outside dismisses
/// it. The barrier is transparent — the panel simply floats over the open drawer,
/// the look Material's own anchored menus have — and this route lives exactly as
/// long as the panel does, which is what keeps the panel's `ref` alive for the
/// logout windows that open above it.
class _AccountPopoverRoute extends PopupRoute<void> {
  _AccountPopoverRoute({required this.anchor, required this.builder});

  /// The icon's rectangle, in the overlay's coordinates.
  final Rect anchor;

  /// Builds the panel.
  final WidgetBuilder builder;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  // No label: the barrier is transparent, so it is never announced as a
  // dismissible surface of its own — the panel's own rows are the content.
  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => CustomSingleChildLayout(
    delegate: _AccountPopoverLayout(anchor: anchor),
    child: builder(context),
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(
    opacity: animation,
    child: ScaleTransition(
      // It grows out of its own top-left, the corner nearest the icon: a scale
      // from anywhere else would look like the panel had fallen open.
      alignment: Alignment.topLeft,
      scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
      child: child,
    ),
  );
}

/// Places the account popover against the drawer it opens over.
///
/// Its top edge sits just under the icon's bottom edge, so the panel still reads
/// as growing out of the icon; its **left edge is the drawer's own left edge**
/// (user request), so the panel lines up with the side menu instead of leaving a
/// strip of the drawer showing beside it. Its width is a menu's — 300 px, inside
/// the 304 px Material gives a drawer — so it never crosses the drawer's
/// trailing edge, and it shrinks rather than overflowing when the screen is
/// narrower than that. The panel is short (four rows) and the icon is at the
/// panel's top, so there is no bottom-edge case to handle: it cannot reach the
/// overlay's foot.
class _AccountPopoverLayout extends SingleChildLayoutDelegate {
  const _AccountPopoverLayout({required this.anchor});

  /// The icon's rectangle, in the overlay's coordinates.
  final Rect anchor;

  /// Room between the icon's bottom edge and the panel: close enough to read as
  /// attached, far enough not to touch it.
  static const double _gap = 8;

  /// Room kept at the panel's trailing edge, so a narrow screen shrinks the
  /// panel before it reaches the screen's own right edge.
  static const double _edgeInset = 8;

  /// The panel's width. A narrower overlay shrinks it rather than overflowing.
  static const double _preferredWidth = 300;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final double width = constraints.maxWidth.isFinite
        ? (constraints.maxWidth - _edgeInset)
              .clamp(0.0, _preferredWidth)
              .toDouble()
        : _preferredWidth;
    return BoxConstraints(maxWidth: width, maxHeight: constraints.maxHeight);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      // Left flush with the drawer, below the icon. `ponytail:` the drawer is
      // the leading surface of the scaffold, which Material lays at the
      // overlay's own left edge, so that edge is the drawer's; the drawer's
      // measured rectangle is asserted in the drawer's test, so an edge that
      // ever stops coinciding fails there rather than drifting silently.
      Offset(0, anchor.bottom + _gap);

  @override
  bool shouldRelayout(_AccountPopoverLayout oldDelegate) =>
      anchor != oldDelegate.anchor;
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
