/// Left navigation drawer for all case screens.
///
/// Displays a profile header, grouped nav items, and Print/Share actions.
/// Active item is highlighted with a black pill.
/// Item visibility is driven by [sideNavOptions] from [UserSettings].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/router/app_router.dart';
import '../../features/admin/presentation/admin_viewmodel.dart';
import '../../features/accounts_and_profile/data/profile_name_store.dart';
import '../../features/accounts_and_profile/data/profile_picture_store.dart';

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
                  CircleAvatar(
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

class _DrawerNavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _DrawerNavTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
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
