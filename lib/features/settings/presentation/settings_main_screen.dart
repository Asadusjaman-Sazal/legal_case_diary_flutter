/// Settings main screen: main settings surface (UI: settings_main/code.html).
///
/// Implements Task 12 Phase 1: sectioned settings list (General / Preferences /
/// App Info) with a live search (Plan §12.1) and an inline Language toggle.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/providers/locale_provider.dart';

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

class _SettingsMainScreenState extends ConsumerState<SettingsMainScreen> {
  /// Live search query used to filter settings items.
  final TextEditingController _searchController = TextEditingController();

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
            route: AppRoutes.settings, // inline toggle; no sub-page
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
    final locale = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Settings'),
        titleSpacing: AppSpacing.sm,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _SearchBar(controller: _searchController, onChanged: (_) => setState(() {})),
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
                        for (final section in visible) ...[
                          _SectionHeader(title: section.header),
                          for (final item in section.items)
                            item.route == AppRoutes.settings
                                ? _LanguageTile(locale: locale)
                                : _SettingsListTile(item: item),
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

/// Search input that filters the settings list (Plan §12.1).
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'Search settings',
            prefixIcon: const Icon(Icons.search, color: AppColors.tertiary),
            filled: true,
            fillColor: AppColors.surfaceContainer,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            isCollapsed: true,
            contentPadding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md,
              horizontal: AppSpacing.sm,
            ),
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

/// Inline Bengali/English language toggle (Plan: per-user preference).
class _LanguageTile extends ConsumerWidget {
  final Locale locale;

  const _LanguageTile({required this.locale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBn = locale.languageCode == 'bn';
    return ListTile(
      leading: const Icon(Icons.language_outlined, color: AppColors.primary),
      title: const Text('Language', style: AppTypography.bodyLg),
      trailing: ToggleButtons(
        isSelected: [!isBn, isBn],
        onPressed: (index) {
          ref
              .read(localeProvider.notifier)
              .setLocale(Locale(index == 0 ? 'en' : 'bn'));
        },
        borderRadius: BorderRadius.circular(8),
        constraints: const BoxConstraints(minWidth: 56, minHeight: 36),
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text('English'),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text('বাংলা'),
          ),
        ],
      ),
    );
  }
}
