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
/// **The panel lines up with the side menu, and is exactly its width** (user
/// requests, 0.0.433 and 0.0.434): its left edge and its width are both the
/// **drawer's own**, measured from the drawer's box at tap time — neither
/// narrower nor wider than the panel it opens over, and never crossing it.
/// **A thin grey edge** (user request,
/// 0.0.433) — `AppColors.outlineVariant`, the drawer's divider grey — outlines
/// the panel, so a white menu over the white drawer can be told from the panel
/// beneath it.
///
/// **The profile icon is the account's own entry point** (user request): tapping
/// the header avatar opens a popover anchored to it, naming the signed-in
/// **e-mail** and offering **Profile**, **Manage Account** and **Logout** — the
/// three account actions that otherwise live two levels down under Settings >
/// Account & Profile.
///
/// **The popover is a rounded window with transparent option rows** (user
/// request, 0.0.435): its corners are rounded well past the 4 px card radius so
/// it reads as a floating menu, the thin grey edge is kept, the address line
/// carries no "Email" caption (the `@` icon says what it is), and its three
/// options are the drawer's own nav rows — the same text size and metrics as
/// the side menu's buttons — on no fill of their own.
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
import '../../core/utils/date_utils.dart';
import 'bottom_nav_bar.dart' show bottomNavTabDefs, bottomTabSerial;
import '../../features/admin/presentation/admin_viewmodel.dart';
import '../../features/accounts_and_profile/data/profile_name_store.dart';
import '../../features/accounts_and_profile/data/profile_picture_store.dart';
import '../../features/auth/presentation/auth_viewmodel.dart';
import '../../features/auth/presentation/logout_dialogs.dart';
import '../../features/payments/presentation/current_plan.dart';
import '../../features/settings/data/update_metadata_store.dart';
import '../../features/settings/presentation/settings_controls.dart';
import '../../features/settings/presentation/update_flow.dart';

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

  /// The bottom bar's current tab keys.
  ///
  /// The drawer hides the case screens that are already one tap away down there
  /// (user request), so it has to know which they are. Empty means "the bar
  /// holds nothing", which hides nothing — the safe default for a caller that
  /// has no settings, and what keeps every existing test unchanged.
  final List<String> bottomNavTabs;

  /// The saved bottom-tab serial.
  ///
  /// The expanded Case Screens list reads in this order, the same one Settings >
  /// View Settings shows, so the two agree.
  final List<String> bottomNavOrder;

  const AppNavigationDrawer({
    required this.currentRoute,
    this.sideNavOptions = const {},
    this.bottomNavTabs = const <String>[],
    this.bottomNavOrder = const <String>[],
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

  /// Whether [item] may appear in a drawer carrying [sideNavOptions].
  ///
  /// Static so the Case Screens group — a widget of its own, holding the
  /// expansion state — can ask the same question the rest of the drawer asks,
  /// rather than keeping a second copy of the rule.
  static bool _isVisible(
    _NavItem item, {
    required bool isAdmin,
    required Map<String, dynamic> sideNavOptions,
  }) {
    // A gated item is never merely hidden by a preference — a non-admin does
    // not get a way to bring it back, and a leftover `sideNavOptions` entry
    // from an earlier admin session cannot reveal it.
    if (item.adminOnly && !isAdmin) return false;
    return !item.removable || sideNavOptions[item.visibilityKey] != false;
  }

  Widget _buildItem(
    BuildContext context,
    AppLocalizations l,
    _NavItem item, {
    required bool isAdmin,
    int badgeCount = 0,
    Widget? trailing,
  }) => _navTile(
    context,
    item: item,
    currentRoute: currentRoute,
    isAdmin: isAdmin,
    sideNavOptions: sideNavOptions,
    badgeCount: badgeCount,
    trailing: trailing,
  );

  /// Opens the account popover **against the profile icon** (user request).
  ///
  /// The panel is positioned from the icon's own rectangle — its top edge just
  /// below the icon — and takes the **drawer's own left edge and width**, so it
  /// lines up with the side menu and is neither narrower nor wider than it
  /// (user request). [iconContext] is the icon's box, which the top edge hangs
  /// from; [drawerContext] is the drawer's, which the left edge and the width
  /// come from. Both are measured in the **root navigator's overlay** because
  /// that is the space the panel is laid out in, and the route goes on that
  /// navigator, above the open panel.
  ///
  /// The panel's own `ref` is deliberately not handed on: it dies with the
  /// drawer, and **Logout** needs a live one for as long as its windows are up.
  /// The panel is therefore a widget with its own, and the two navigators reach
  /// it as state objects rather than as contexts.
  void _openAccountSheet(
    BuildContext iconContext,
    BuildContext drawerContext,
    WidgetRef ref,
  ) {
    final navigator = Navigator.of(iconContext, rootNavigator: true);
    final overlay = navigator.overlay?.context.findRenderObject() as RenderBox?;
    final icon = iconContext.findRenderObject() as RenderBox?;
    // The drawer's own box: its width is the panel's width, by request.
    final drawer = drawerContext.findRenderObject() as RenderBox?;
    // Nothing to anchor to without an overlay — or the drawer it must match — so
    // nothing opens rather than a panel landing in a corner the user did not
    // point at.
    if (overlay == null || icon == null || drawer == null) return;
    // **Everything the panel needs is read now, not inside its builder.** The
    // route's builder closure is re-run on every rebuild of the panel's page, and
    // by then the drawer may be gone — a drawer that is popped while the panel is
    // up (Logout closes the screen the panel was opened from) would leave a
    // deactivated context behind, and reading the drawer's `ref` there throws
    // "Using ref when a widget is about to or has been unmounted". So the address
    // is read as a value while the drawer is certainly mounted, and the navigator
    // and router are taken as state objects, which outlive it.
    final email = ref.read(authIdentityProvider)?.email ?? '';
    final drawerNavigator = Navigator.of(iconContext);
    final router = GoRouter.of(iconContext);
    navigator.push<void>(
      _AccountPopoverRoute(
        anchor: icon.localToGlobal(Offset.zero, ancestor: overlay) & icon.size,
        drawer:
            drawer.localToGlobal(Offset.zero, ancestor: overlay) & drawer.size,
        builder: (_) => _AccountPopover(
          email: email,
          drawerNavigator: drawerNavigator,
          router: router,
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
                    // The drawer's own context goes along with the icon's: the
                    // panel is as wide as the drawer and starts at its left
                    // edge, and only the drawer can say what those are.
                    onPressed: (iconContext) =>
                        _openAccountSheet(iconContext, context, ref),
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
                  _CaseDrawerGroup(
                    currentRoute: currentRoute,
                    isAdmin: isAdmin,
                    sideNavOptions: sideNavOptions,
                    bottomNavTabs: bottomNavTabs,
                    bottomNavOrder: bottomNavOrder,
                  ),
                  const _DrawerDivider(),
                  ..._toolItems.map(
                    (item) => _buildItem(context, l, item, isAdmin: isAdmin),
                  ),
                  if (isAdmin) ...[
                    const _DrawerDivider(),
                    // The count of what is waiting inside the panel, over the
                    // row, the way the Sync Status icon carries its own.
                    _buildItem(
                      context,
                      l,
                      _adminItem,
                      isAdmin: true,
                      badgeCount: ref.watch(adminPendingCountProvider),
                    ),
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
                  // The updater, below Share (user request). It does not close
                  // the drawer when tapped — the whole point is the result it
                  // cascades underneath — so it is the one row here that leaves
                  // the menu open.
                  const _UpdateDrawerTile(),
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

  /// When true, the leading icon is replaced by a small progress spinner and
  /// the row reports itself disabled — the account panel's Logout row uses this
  /// while the logout flow runs, so the tap answers the user at once.
  final bool busy;

  /// Count drawn as a badge over the leading icon; 0 or less draws none.
  ///
  /// The Admin Panel row uses it for the work waiting inside the panel, exactly
  /// as the case screens badge the Sync Status icon.
  final int badgeCount;

  /// A control drawn at the row's end, past the label.
  ///
  /// The Case Screens group's expander is the one user: it must be its own tap
  /// target, because the row itself navigates.
  final Widget? trailing;

  const _DrawerNavTile({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.indent = 0,
    this.busy = false,
    this.badgeCount = 0,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
                if (busy)
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: active ? Colors.white : AppColors.onSurfaceVariant,
                    ),
                  )
                // A `label` rather than `Badge.count`, because the latter paints
                // Latin digits: the count is written in the active language's own
                // digits, like every other count in the app.
                else if (badgeCount > 0)
                  Badge(
                    label: Text(
                      AppDateUtils.formatDigits(
                        badgeCount,
                        l.localeName,
                        grouping: false,
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: active ? Colors.white : AppColors.onSurfaceVariant,
                    ),
                  )
                else
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
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The side menu's **Check for update** row: the updater, one tap away.
///
/// It drives the **same** flow the About > Update card does
/// ([UpdateFlowController]), so it checks the same way, honours the same
/// Wi-Fi-only preference and shows the same sentences (user request). What it
/// adds is the row's own shape:
///
///  * the row **is** the button, so it takes the flow's own label and changes
///    with it — *Check for update*, then *Checking for update*, then *Update
///    now* once a release is offered;
///  * it **does not close the drawer**, because the point is the result it
///    cascades underneath;
///  * it carries the updater's **dot** when a check has found a newer release —
///    the same dot the About row and the Update row show, which is what makes an
///    update discoverable without opening anything.
///
/// The controller is owned by this widget's state, so a download it started
/// survives a drawer rebuild, and is disposed with the drawer — which the
/// controller tolerates by dropping late notifications.
class _UpdateDrawerTile extends ConsumerStatefulWidget {
  const _UpdateDrawerTile();

  @override
  ConsumerState<_UpdateDrawerTile> createState() => _UpdateDrawerTileState();
}

class _UpdateDrawerTileState extends ConsumerState<_UpdateDrawerTile> {
  late final UpdateFlowController _flow = UpdateFlowController(
    ProviderScope.containerOf(context),
  );

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Watched so the dot appears the moment a check — this one or the launch
    // check — finds a release, exactly as it does on the About row.
    final offered = ref.watch(updateAvailableProvider) != null;
    final busy = _flow.phase == UpdatePhase.checking;
    return ListenableBuilder(
      listenable: _flow,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                key: const ValueKey('drawer-update'),
                borderRadius: BorderRadius.circular(24),
                // A second tap while a download runs would start another, so the
                // row goes inert the way the card's button does.
                onTap: _flow.downloading ? null : _flow.check,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      // The row answers the tap at once — the same spinner the
                      // drawer's own busy rows use.
                      if (busy)
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.onSurfaceVariant,
                          ),
                        )
                      else
                        const Icon(
                          Icons.system_update_alt_outlined,
                          size: 22,
                          color: AppColors.onSurfaceVariant,
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          // The flow's label, so the row turns into *Update now*
                          // when there is something to install.
                          _flow.buttonLabel(l),
                          style: AppTypography.labelLg.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (offered && !busy) ...[
                        const UpdateDot(),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // The cascade: the outcome sentence, and the progress line while a
            // download runs. The button is this row itself, so the body draws
            // neither.
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
              child: UpdateFlowBody(
                controller: _flow,
                layout: UpdateFlowLayout.row,
                showButton: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One drawer row for [item], or nothing when the item is hidden.
///
/// A top-level function rather than a method, so the Case Screens group — which
/// is a widget of its own because it holds the expansion state — draws its rows
/// through the same code the rest of the drawer does.
Widget _navTile(
  BuildContext context, {
  required _NavItem item,
  required String currentRoute,
  required bool isAdmin,
  required Map<String, dynamic> sideNavOptions,
  int badgeCount = 0,
  Widget? trailing,
}) {
  if (!AppNavigationDrawer._isVisible(
    item,
    isAdmin: isAdmin,
    sideNavOptions: sideNavOptions,
  )) {
    return const SizedBox.shrink();
  }
  final active = currentRoute == item.route;
  return _DrawerNavTile(
    icon: item.icon,
    label: item.label(AppLocalizations.of(context)),
    active: active,
    badgeCount: badgeCount,
    trailing: trailing,
    onTap: () {
      Navigator.of(context).pop();
      if (!active) context.push(item.route);
    },
  );
}

/// The drawer's Case Screens group, with the rows the bottom bar already has
/// hidden (user request).
///
/// A screen one tap away in the bottom bar does not need a second home in the
/// drawer, so this group lists only the case screens the bar does **not**
/// carry. The last visible row wears a down-arrow which expands the full list —
/// every case screen the drawer would otherwise list, in the **same serial
/// Settings > View Settings shows** — so nothing ends up more than one tap away.
///
/// **The arrow is its own tap target**, not the row's: the row still opens its
/// screen, so an arrow that swallowed that tap would cost the shortcut to
/// whichever screen happens to be last.
///
/// When the bar already holds every case screen the group disappears entirely
/// (the user's choice). They are all in the bar, so there is nothing the drawer
/// can usefully add, and no row left to hang the arrow on.
class _CaseDrawerGroup extends StatefulWidget {
  const _CaseDrawerGroup({
    required this.currentRoute,
    required this.isAdmin,
    required this.sideNavOptions,
    required this.bottomNavTabs,
    required this.bottomNavOrder,
  });

  /// The active route, so a row can mark itself.
  final String currentRoute;

  /// Whether the account is an admin; the case rows are not gated, but the
  /// shared visibility rule asks.
  final bool isAdmin;

  /// The drawer's section preferences.
  final Map<String, dynamic> sideNavOptions;

  /// The bottom bar's current tab keys.
  final List<String> bottomNavTabs;

  /// The saved bottom-tab serial.
  final List<String> bottomNavOrder;

  @override
  State<_CaseDrawerGroup> createState() => _CaseDrawerGroupState();
}

class _CaseDrawerGroupState extends State<_CaseDrawerGroup> {
  /// Whether the group is showing every case screen, including the bar's.
  bool _expanded = false;

  /// The bottom-bar tab key for a drawer row, or null when the row's screen is
  /// not one of the bar's candidates.
  ///
  /// Matched on the **route**, because a drawer row keys its visibility by route
  /// while the bar keys a tab by its own name; [bottomNavTabDefs] holds both, so
  /// it is the one place the two can be tied together.
  static String? _tabKey(_NavItem item) {
    for (final def in bottomNavTabDefs) {
      if (def.route == item.visibilityKey) return def.key;
    }
    return null;
  }

  bool _inBottomBar(_NavItem item) {
    final key = _tabKey(item);
    return key != null && widget.bottomNavTabs.contains(key);
  }

  @override
  Widget build(BuildContext context) {
    final items = AppNavigationDrawer._caseItems;

    // The order the group reads in: the saved serial first, then canonically —
    // the same one View Settings' own dropdown shows.
    final serial = bottomTabSerial(
      storedOrder: widget.bottomNavOrder,
      available: bottomNavTabDefs,
    );
    final position = <String, int>{
      for (var i = 0; i < serial.length; i++) serial[i]: i,
    };
    final ordered = <_NavItem>[...items]..sort((a, b) {
      final left = position[_tabKey(a)] ?? serial.length;
      final right = position[_tabKey(b)] ?? serial.length;
      return left.compareTo(right);
    });

    // What the drawer would list at all, and what is left once the bar's own
    // screens are taken out.
    final showable = <_NavItem>[
      for (final item in ordered)
        if (AppNavigationDrawer._isVisible(
          item,
          isAdmin: widget.isAdmin,
          sideNavOptions: widget.sideNavOptions,
        ))
          item,
    ];
    final visible = <_NavItem>[
      for (final item in showable)
        if (!_inBottomBar(item)) item,
    ];

    // Nothing left to say: every case screen is in the bar (user's choice), or
    // the preferences hid them all.
    if (visible.isEmpty) return const SizedBox.shrink();

    final shown = _expanded ? showable : visible;
    final hasMore = showable.length > visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < shown.length; i++)
          _navTile(
            context,
            item: shown[i],
            currentRoute: widget.currentRoute,
            isAdmin: widget.isAdmin,
            sideNavOptions: widget.sideNavOptions,
            // The arrow rides the last row of whichever list is showing.
            trailing: hasMore && i == shown.length - 1
                ? _CaseExpander(
                    expanded: _expanded,
                    onTap: () => setState(() => _expanded = !_expanded),
                  )
                : null,
          ),
      ],
    );
  }
}

/// The down-arrow that expands the Case Screens group.
///
/// Icon-only, so it is labelled for the screen reader and padded to a
/// comfortable target — a control that only means something to a sighted user
/// is not finished.
class _CaseExpander extends StatelessWidget {
  const _CaseExpander({required this.expanded, required this.onTap});

  /// Whether the full list is showing.
  final bool expanded;

  /// Toggles the full list.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      expanded: expanded,
      child: Tooltip(
        message: expanded
            ? l.drawer_caseScreensHide
            : l.drawer_caseScreensShowAll,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            key: const ValueKey('drawer-case-expander'),
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 22,
                color: AppColors.onSurfaceVariant,
              ),
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

/// Corner radius of the account popover's window (user request, 0.0.435).
///
/// The reference panel the user attached rounds its corners far more than the
/// 4 px card radius, so the panel reads as a floating menu rather than a card.
/// 16 px keeps that rounding on the 8 px spacing grid.
const double _accountPopoverRadius = 16;

/// The account popover (user request): the signed-in e-mail and the three
/// account actions, shown at the drawer's profile icon.
///
/// A [ConsumerWidget] rather than a builder closure for one reason: **Logout
/// has to run while this widget is still mounted.** [runBranchedLogout] reads
/// providers and opens windows, so the `ref` it is given must outlive every
/// surface closed to make room for it — and the drawer's `ref` cannot, because
/// the panel is gone the moment it closes. The popover stays up behind the
/// logout windows and closes itself when they are done.
class _AccountPopover extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<_AccountPopover> createState() => _AccountPopoverState();
}

/// State of the account popover: owns the "logging out" flag so the Logout row
/// can show a spinner for the whole flow, not just the wait after the last
/// dialog.
class _AccountPopoverState extends ConsumerState<_AccountPopover> {
  /// True from the moment Logout is pressed until the flow ends, whatever the
  /// outcome (completed, cancelled or failed) — so the row replies instantly.
  bool _loggingOut = false;

  /// Closes the panel, so the user comes back to the screen it was opened from
  /// — exactly what every other drawer row does.
  void _closeDrawer() {
    if (widget.drawerNavigator.mounted) widget.drawerNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final email = widget.email;
    final router = widget.router;
    // A floating panel, not a sheet: it carries its own elevation and rounding
    // and floats over the open drawer, which is what makes it look attached to
    // the icon. Its width and position come from the route's layout delegate.
    return Material(
      key: const ValueKey('drawer-account-popover'),
      color: AppColors.surfaceContainerLowest,
      elevation: 8,
      // A **rounded window** (user request): [_accountPopoverRadius] corners,
      // far past the 4 px card radius, matching the reference panel's shape.
      // The **thin grey edge** is kept (user request): the panel and the drawer
      // it floats over are both white, so the shadow alone left the user unable
      // to tell where the menu ends and the panel behind it begins. The colour
      // is the drawer's own divider grey, so the edge speaks the drawer's
      // language rather than introducing a new one.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_accountPopoverRadius),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Who this account is: the address it signed in with, marked by the
          // `@` icon alone. The "Email" caption that used to sit under it was
          // dropped (user request): the icon already says what the line is, so
          // the caption only repeated it.
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Row(
              children: [
                const Icon(
                  Icons.alternate_email,
                  size: 22,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    email.isNotEmpty ? email : '—',
                    style: AppTypography.labelLg.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.outlineVariant),
          // The three account actions as a **block of transparent rows** (user
          // request): each is the drawer's own nav row, so the options read at
          // exactly the side menu's text size and metrics — same 22 px icon,
          // same 16 px icon gap, same [AppTypography.labelLg] weight and colour.
          // The rows carry no fill of their own; the window's white shows
          // through and only the tap ink marks a press.
          _DrawerNavTile(
            key: const ValueKey('drawer-account-profile'),
            icon: Icons.person_outline,
            label: l.settingsScreen_profile,
            active: false,
            onTap: () {
              _closeDrawer();
              Navigator.of(context).pop();
              router.push(AppRoutes.settingsProfile);
            },
          ),
          _DrawerNavTile(
            key: const ValueKey('drawer-account-manage'),
            icon: Icons.manage_accounts_outlined,
            label: l.settingsScreen_manageAccount,
            active: false,
            onTap: () {
              _closeDrawer();
              Navigator.of(context).pop();
              router.push(AppRoutes.settingsManageAccount);
            },
          ),
          _DrawerNavTile(
            key: const ValueKey('drawer-account-logout'),
            icon: Icons.logout,
            label: l.settingsManageAccount_logout,
            active: false,
            busy: _loggingOut,
            onTap: () async {
              // The row answers at once so the tap is not mistaken for a dead
              // button: the spinner replaces the icon for however long the
              // flow takes, and the row stops being tappable again.
              if (_loggingOut) return;
              setState(() => _loggingOut = true);
              try {
                // The side menu stays open (user request): the logout windows
                // appear above it, and nothing is dismissed until the flow is
                // done — a cancelled branch leaves the user where they were,
                // still able to pick another action. The account panel and this
                // widget's `ref` also stay mounted for the whole flow, which is
                // what the one branched logout reads its providers through.
                final completed = await runBranchedLogout(context, ref);
                if (!context.mounted) return;
                // The panel is closed once the flow has finished its windows.
                Navigator.of(context).pop();
                // Login is reached explicitly: the router's sign-in gate is
                // decided once per launch, so a signed-out user would otherwise
                // be left on the now-empty shell.
                if (completed) router.go(AppRoutes.login);
              } finally {
                // Clear the spinner whatever the outcome — a throw must never
                // leave the row stuck spinning.
                if (mounted) setState(() => _loggingOut = false);
              }
            },
          ),
          // A little air under the last row, so the window's rounded foot is
          // not touching it.
          const SizedBox(height: 8),
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
  _AccountPopoverRoute({
    required this.anchor,
    required this.drawer,
    required this.builder,
  });

  /// The icon's rectangle, in the overlay's coordinates.
  final Rect anchor;

  /// The drawer's rectangle, in the overlay's coordinates: the panel's left edge
  /// and width are taken from it, so the two line up exactly.
  final Rect drawer;

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
    delegate: _AccountPopoverLayout(anchor: anchor, drawer: drawer),
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

/// Places the account popover over the drawer it belongs to.
///
/// Its **width is the drawer's less a small inset each side** (user request,
/// 0.0.443): the panel is a hair narrower than the side menu and sits that same
/// amount in from each edge, so a strip of the drawer shows on both sides and
/// the panel reads as a window *inside* the menu rather than a wall over it. Its
/// top edge still sits just under the icon's bottom edge, so it reads as growing
/// out of the icon. The width and edges come from the drawer's laid-out
/// rectangle rather than a guessed width, so a drawer of any size is matched.
/// The panel is short (four rows) and the icon is at its top, so there is no
/// bottom-edge case: it cannot reach the overlay's foot.
class _AccountPopoverLayout extends SingleChildLayoutDelegate {
  const _AccountPopoverLayout({required this.anchor, required this.drawer});

  /// The icon's rectangle, in the overlay's coordinates.
  final Rect anchor;

  /// The drawer's rectangle, in the overlay's coordinates.
  final Rect drawer;

  /// Room between the icon's bottom edge and the panel: close enough to read as
  /// attached, far enough not to touch it.
  static const double _gap = 8;

  /// Strip of the drawer left visible beside the panel on each side: half the
  /// page margin, which reads as a window sitting just inside the menu.
  static const double _sideInset = AppSpacing.sm;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: drawer.width - _sideInset * 2,
        maxHeight: constraints.maxHeight,
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    // Inset from the drawer's left edge by the same amount the width gives up on
    // that side, which centres the narrower panel and shows the drawer at both
    // edges; under the icon vertically.
    drawer.left + _sideInset,
    anchor.bottom + _gap,
  );

  @override
  bool shouldRelayout(_AccountPopoverLayout oldDelegate) =>
      anchor != oldDelegate.anchor || drawer != oldDelegate.drawer;
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
