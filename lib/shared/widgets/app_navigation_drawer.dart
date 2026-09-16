/// Left navigation drawer for all case screens.
///
/// Displays a profile header, grouped nav items, and Print/Share actions.
/// Active item is highlighted with a [AppColors.secondaryContainer] pill.
/// Item visibility is driven by [sideNavOptions] from [UserSettings].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/router/app_router.dart';
import '../../features/accounts_and_profile/data/profile_name_store.dart';
import '../../features/accounts_and_profile/data/profile_picture_store.dart';

/// A nav item descriptor used to build drawer rows.
class _NavItem {
  /// Key used for [sideNavOptions] visibility lookup AND as the route path.
  final String visibilityKey;
  final IconData icon;
  final String Function(AppLocalizations) label;
  final String route;

  const _NavItem({
    required this.visibilityKey,
    required this.icon,
    required this.label,
    required this.route,
  });
}

/// Navigation drawer matching the Daily Cause List mockup.
///
/// [currentRoute] — the active GoRouter location (e.g. `/daily-cause-list`).
/// [sideNavOptions] — map from [UserSettings.sideNavOptions]; keys that map
///   to `false` hide the corresponding item. Unknown keys default to visible.
/// [displayName] — optional override for the header name; defaults to the
///   saved Profile Full Name (see [profileNameProvider]).
/// [roleLabel] — user's role (e.g. "Advocate"); shown as a stub when null.
/// [onPrint] — callback for the Print action (Task 14 implements the service).
/// [onShare] — callback for the Share action (Task 14 implements the service).
///
/// The header avatar shows the saved profile picture ([profilePictureProvider])
/// with the generic person icon as the fallback.
class AppNavigationDrawer extends ConsumerWidget {
  final String currentRoute;
  final Map<String, dynamic> sideNavOptions;
  final String? displayName;
  final String? roleLabel;
  final VoidCallback? onPrint;
  final VoidCallback? onShare;

  const AppNavigationDrawer({
    required this.currentRoute,
    this.sideNavOptions = const {},
    this.displayName,
    this.roleLabel,
    this.onPrint,
    this.onShare,
    super.key,
  });

  static const List<_NavItem> _caseItems = [
    _NavItem(
      visibilityKey: AppRoutes.upcomingCases,
      icon: Icons.event_outlined,
      label: _labelUpcoming,
      route: AppRoutes.upcomingCases,
    ),
    _NavItem(
      visibilityKey: AppRoutes.dailyCauseList,
      icon: Icons.calendar_today_outlined,
      label: _labelDailyCauseList,
      route: AppRoutes.dailyCauseList,
    ),
    _NavItem(
      visibilityKey: AppRoutes.allCases,
      icon: Icons.list_alt_outlined,
      label: _labelAllCases,
      route: AppRoutes.allCases,
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
    ),
  ];

  static String _labelUpcoming(AppLocalizations l) => l.nav_upcomingCases;
  static String _labelDailyCauseList(AppLocalizations l) => l.nav_dailyCauseList;
  static String _labelAllCases(AppLocalizations l) => l.nav_allCases;
  static String _labelDisposedCases(AppLocalizations l) => l.nav_disposedCases;
  static String _labelCaseReference(AppLocalizations l) => l.nav_caseReference;
  static String _labelNotes(AppLocalizations l) => l.nav_notes;
  static String _labelSettings(AppLocalizations l) => l.nav_settings;

  bool _isVisible(String key) => sideNavOptions[key] != false;

  bool _isActive(String route) => currentRoute == route;

  Widget _buildItem(BuildContext context, AppLocalizations l, _NavItem item) {
    if (!_isVisible(item.visibilityKey)) return const SizedBox.shrink();
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
    return Drawer(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ----------------------------------------------------------------
            // Profile header — matches mockup: avatar, name, role, app subtitle
            // ----------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primaryContainer,
                    backgroundImage:
                        avatarFile != null ? FileImage(avatarFile) : null,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headerName.isNotEmpty ? headerName : '—',
                          style: AppTypography.titleLg.copyWith(
                            color: AppColors.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (roleLabel != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            roleLabel!,
                            style: AppTypography.labelLg,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          l.appName,
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.primary,
                            letterSpacing: 0.8,
                          ),
                        ),
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
                  ..._caseItems.map((item) => _buildItem(context, l, item)),
                  const _DrawerDivider(),
                  ..._toolItems.map((item) => _buildItem(context, l, item)),
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
        color: active ? AppColors.secondaryContainer : Colors.transparent,
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
                  color: active
                      ? AppColors.onSecondaryContainer
                      : AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.labelLg.copyWith(
                      color: active
                          ? AppColors.onSecondaryContainer
                          : AppColors.onSurfaceVariant,
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
