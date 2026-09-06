/// Settings main screen: main settings surface (UI: settings_main/code.html).
///
/// Implements Task 12 Phase 1: sectioned settings list (General / Preferences /
/// App Info) with a live search and a Language sub-menu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_navigation_drawer.dart';
import '../../settings/data/settings_repository.dart';

/// A single navigable settings entry within a section.
class _SettingsItem {
  /// Visible title (used for search matching, lowercased).
  final String title;

  /// Material icon shown on the leading tile.
  final IconData icon;

  /// Route the item navigates to on tap.
  final String route;

  /// Optional subtitle shown under the title.
  final String? subtitle;

  const _SettingsItem({
    required this.title,
    required this.icon,
    required this.route,
    this.subtitle,
  });
}

/// A grouping of settings entries under a section header.
class _SettingsSection {
  final String header;
  final List<_SettingsItem> items;

  const _SettingsSection(this.header, this.items);
}

/// Settings main page with searchable, sectioned navigation.
class SettingsMainScreen extends ConsumerStatefulWidget {
  const SettingsMainScreen({super.key});

  @override
  ConsumerState<SettingsMainScreen> createState() => _SettingsMainScreenState();
}

/// Watches the live [UserSettings] stream so the navigation drawer's
/// [sideNavOptions] stay in sync without re-creating a Future on rebuild.
final _userSettingsProvider = StreamProvider<UserSettings>((ref) async* {
  final repo = await ref.watch(settingsRepositoryProvider.future);
  yield* repo.watchSettings();
});

class _SettingsMainScreenState extends ConsumerState<SettingsMainScreen> {
  /// Live search query used to filter settings items.
  final TextEditingController _searchController = TextEditingController();

  /// Whether the slide-in search field is currently open.
  bool _searchOpen = false;

  /// All settings sections in display order.
  late final List<_SettingsSection> _sections;

  @override
  void initState() {
    super.initState();
    _sections = _buildSections();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searchOpen = true);
    // Focus the field once it has animated in.
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) FocusScope.of(context).requestFocus(_searchFocus);
    });
  }

  void _closeSearch() {
    _searchController.clear();
    setState(() => _searchOpen = false);
  }

  /// Focus node for the slide-in search field.
  final FocusNode _searchFocus = FocusNode();

  List<_SettingsSection> _buildSections() => [
        _SettingsSection('General', [
          const _SettingsItem(
            title: 'Account & Profile',
            icon: Icons.person_outline,
            route: AppRoutes.settingsAccountProfile,
            subtitle: 'Profile, manage account',
          ),
          const _SettingsItem(
            title: 'Online Sync',
            icon: Icons.sync_outlined,
            route: AppRoutes.settingsOnlineSync,
          ),
          const _SettingsItem(
            title: 'Backup & Restore',
            icon: Icons.cloud_upload_outlined,
            route: AppRoutes.settingsBackupRestore,
          ),
        ]),
        _SettingsSection('Preferences', [
          const _SettingsItem(
            title: 'Edit Court/Steps',
            icon: Icons.gavel_outlined,
            route: AppRoutes.settingsEditCourtSteps,
          ),
          const _SettingsItem(
            title: 'Notifications',
            icon: Icons.notifications_outlined,
            route: AppRoutes.settingsNotifications,
          ),
          const _SettingsItem(
            title: 'Language',
            icon: Icons.language_outlined,
            route: AppRoutes.settingsLanguage,
          ),
          const _SettingsItem(
            title: 'View settings',
            icon: Icons.visibility_outlined,
            route: AppRoutes.settingsViewSettings,
          ),
        ]),
        _SettingsSection('App Info', [
          const _SettingsItem(
            title: 'Guidelines',
            icon: Icons.info_outline,
            route: AppRoutes.settingsGuidelines,
          ),
          const _SettingsItem(
            title: 'About',
            icon: Icons.info_outline,
            route: AppRoutes.settingsAbout,
          ),
        ]),
      ];

  /// Filters sections to those with at least one title matching [query].
  List<_SettingsSection> _filteredSections(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _sections;
    return _sections
        .map((section) => _SettingsSection(
              section.header,
              section.items
                  .where((item) => item.title.toLowerCase().contains(q))
                  .toList(),
            ))
        .where((section) => section.items.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text;
    final visible = _filteredSections(query);

    final settingsAsync = ref.watch(_userSettingsProvider);
    final sideNavOptions = settingsAsync.value?.sideNavOptions ?? const {};
    final currentRoute = GoRouterState.of(context).uri.path;

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: AppNavigationDrawer(
        currentRoute: currentRoute,
        sideNavOptions: sideNavOptions,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _SettingsHeader(
              searchOpen: _searchOpen,
              searchController: _searchController,
              searchFocus: _searchFocus,
              onBackPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  // No in-router history (e.g. reached via the nav drawer) —
                  // fall back to the exit confirmation like other shell screens.
                  AppShellRoot.requestExit(context);
                }
              },
              onSearchPressed: _openSearch,
              onCloseSearch: _closeSearch,
              onSearchChanged: () => setState(() {}),
            ),
            Expanded(
              child: visible.isEmpty
                  ? const Center(
                      child: Text(
                        'No settings found',
                        style: AppTypography.bodyMd,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      children: [
                        for (var s = 0; s < visible.length; s++) ...[
                          if (s > 0)
                            const SizedBox(height: AppSpacing.lg),
                          _SectionHeader(title: visible[s].header),
                          // Card matching the header background, with a top and
                          // bottom hairline per the settings_main mockup.
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              border: Border(
                                top: BorderSide(color: AppColors.outlineVariant),
                                bottom:
                                    BorderSide(color: AppColors.outlineVariant),
                              ),
                            ),
                            child: Column(
                              children: [
                                for (var i = 0;
                                    i < visible[s].items.length;
                                    i++) ...[
                                  _SettingsListTile(item: visible[s].items[i]),
                                  if (i < visible[s].items.length - 1)
                                    const Divider(
                                      height: 1,
                                      thickness: 1,
                                      indent: AppSpacing.md,
                                      endIndent: AppSpacing.md,
                                      color: AppColors.outlineVariant,
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings header: hamburger menu + stacked back button on the left, and a
/// search affordance on the right. When [searchOpen] is true the right side
/// slides in a search field from right to left; a close icon dismisses it.
class _SettingsHeader extends StatelessWidget {
  final bool searchOpen;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final VoidCallback onBackPressed;
  final VoidCallback onSearchPressed;
  final VoidCallback onCloseSearch;
  final VoidCallback onSearchChanged;

  const _SettingsHeader({
    required this.searchOpen,
    required this.searchController,
    required this.searchFocus,
    required this.onBackPressed,
    required this.onSearchPressed,
    required this.onCloseSearch,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        height: 56,
        color: AppColors.surface,
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: Row(
          children: [
            // Left cluster: menu then a stacked back button (this screen only).
            // Both use a Builder so they open the drawer/pop against the header's
            // own context — the parent build context sits above the Scaffold and
            // cannot see it.
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu, color: AppColors.primary),
                tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: onBackPressed,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text('Settings', style: AppTypography.titleLg),
            const Spacer(),
            // Right cluster: search button that expands into a search field.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
              child: searchOpen
                  ? _SlideInSearchField(
                      key: const ValueKey('search'),
                      controller: searchController,
                      focus: searchFocus,
                      onChanged: onSearchChanged,
                      onClose: onCloseSearch,
                    )
                  : IconButton(
                      key: const ValueKey('search-btn'),
                      icon: const Icon(Icons.search, color: AppColors.primary),
                      tooltip: 'Search settings',
                      onPressed: onSearchPressed,
                    ),
            ),
          ],
        ),
      );
}

/// The expandable search field shown when [ _SettingsHeader.searchOpen] is true.
class _SlideInSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback onChanged;
  final VoidCallback onClose;

  const _SlideInSearchField({
    super.key,
    required this.controller,
    required this.focus,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          height: 40,
          margin: const EdgeInsets.only(left: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.search, color: AppColors.tertiary),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focus,
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(
                    hintText: 'Search settings',
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                      horizontal: AppSpacing.sm,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.tertiary),
                tooltip: 'Close search',
                onPressed: onClose,
              ),
            ],
          ),
        ),
      );
}

/// Section header label above a group of settings items.
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xs,
        ),
        child: Text(
          title.toUpperCase(),
          style: AppTypography.labelMd.copyWith(
            color: AppColors.tertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

/// Standard tappable settings row that navigates to [item.route].
class _SettingsListTile extends StatelessWidget {
  final _SettingsItem item;

  const _SettingsListTile({required this.item});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(item.icon, color: AppColors.primary),
        title: Text(item.title, style: AppTypography.bodyLg),
        subtitle: item.subtitle == null
            ? null
            : Text(item.subtitle!, style: AppTypography.bodySm),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.tertiary,
        ),
        onTap: () => context.push(item.route),
      );
}
