/// View settings screen: display and navigation configuration.
///
/// There is no mockup for this screen, so the body follows plan §10.1
/// (`upcoming_cases_period`, `case_list_display_mode`, `bottom_nav_tabs`,
/// `side_nav_options`, `default_landing_page`) using the same card, section and
/// 48 px control language as the Notifications screen.
///
/// All five values are durable per-user preferences in the local
/// `user_preferences` row and are never firm-shared. The screens that consume
/// them (Upcoming Cases, the bottom bar, the drawer, the router's landing-page
/// resolution) already read them from settings, so saving here is enough —
/// except `case_list_display_mode`, whose case-list consumer arrives with its
/// own task (persisted here, not yet rendered).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/bottom_nav_bar.dart';
import '../settings_controls.dart';
import '../settings_sub_page_modal.dart';
import '../settings_viewmodel.dart';
import '../../data/settings_repository.dart';

/// Periods the Upcoming Cases screen can look ahead, in days.
const List<int> _upcomingPeriods = <int>[3, 7, 14, 30];

/// Drawer sections whose visibility the user can toggle, in drawer order.
/// The settings key is the route path, which is exactly what
/// `app_navigation_drawer.dart` looks up in `side_nav_options`.
const List<_NavOption> _sideNavOptions = <_NavOption>[
  _NavOption(AppRoutes.upcomingCases, 'upcoming'),
  _NavOption(AppRoutes.dailyCauseList, 'daily_cause_list'),
  _NavOption(AppRoutes.allCases, 'all_cases'),
  _NavOption(AppRoutes.disposedCases, 'disposed'),
  _NavOption(AppRoutes.caseReference, AppRoutes.caseReference),
  _NavOption(AppRoutes.notes, AppRoutes.notes),
  _NavOption(AppRoutes.settings, AppRoutes.settings),
];

/// Screens offered as the default landing page, in `AppRoutes` order.
const List<String> _landingPages = <String>[
  'daily_cause_list',
  'overdue',
  'active',
  'upcoming',
  'all_cases',
  'disposed',
];

/// One side-navigation toggle: the settings key plus a localized label.
class _NavOption {
  /// Key looked up in `UserSettings.sideNavOptions` (a route path).
  final String settingsKey;

  /// Key `_screenLabel` resolves to the shared `nav_*` label.
  final String labelKey;

  const _NavOption(this.settingsKey, this.labelKey);
}

/// Localized label for a bottom-tab / landing-page / side-nav key.
String _screenLabel(AppLocalizations l, String key) => switch (key) {
  'overdue' => l.nav_overdueDates,
  'daily_cause_list' => l.nav_dailyCauseList,
  'active' => l.nav_activeCases,
  'upcoming' => l.nav_upcomingCases,
  'all_cases' => l.nav_allCases,
  'disposed' => l.nav_disposedCases,
  AppRoutes.caseReference => l.nav_caseReference,
  AppRoutes.notes => l.nav_notes,
  AppRoutes.settings => l.nav_settings,
  _ => key,
};

/// View settings screen.
class ViewSettingsScreen extends ConsumerStatefulWidget {
  const ViewSettingsScreen({super.key});

  @override
  ConsumerState<ViewSettingsScreen> createState() => _ViewSettingsScreenState();
}

class _ViewSettingsScreenState extends ConsumerState<ViewSettingsScreen> {
  /// Display order of *every* candidate tab (chosen ones first). Held locally
  /// so unselected rows keep their place while the user drags, and seeded once
  /// from the saved selection.
  List<String>? _tabOrder;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settingsAsync = ref.watch(settingsViewModelProvider);
    final settings = settingsAsync.value ?? const UserSettings();
    // Seed the display order from the *loaded* selection, not from the loading
    // frame's defaults, so the saved tabs appear first once settings arrive.
    if (_tabOrder == null && settingsAsync.hasValue) {
      _tabOrder = _seedTabOrder(settings.bottomNavTabs);
    }
    final order = _tabOrder ?? _seedTabOrder(settings.bottomNavTabs);
    final chosen = settings.bottomNavTabs;

    return SettingsSubPageModal(
      title: l.settingsViewSettings_title,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.edgeMargin,
          AppSpacing.md,
          AppSpacing.edgeMargin,
          AppSpacing.xl,
        ),
        children: [
          _SectionCard(
            label: l.settingsViewSettings_sectionDisplay,
            children: [
              // Upcoming cases period.
              SettingsPickerRow(
                text: l.settingsViewSettings_days(settings.upcomingCasesPeriod),
                icon: Icons.expand_more,
                onTap: () => _pickUpcomingPeriod(settings.upcomingCasesPeriod),
              ),
              const SizedBox(height: AppSpacing.md),
              // Case list display mode.
              SettingsPickerRow(
                text: _caseListModeLabel(l, settings.caseListDisplayMode),
                icon: Icons.expand_more,
                onTap: () => _pickCaseListMode(settings.caseListDisplayMode),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionCard(
            label: l.settingsViewSettings_sectionNavigation,
            children: [
              // Bottom navigation tabs: choose and order in one list.
              Text(
                l.settingsViewSettings_bottomTabs,
                style: AppTypography.bodyLg,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l.settingsViewSettings_bottomTabsHint,
                style: AppTypography.bodySm,
              ),
              const SizedBox(height: AppSpacing.sm),
              _TabChooser(
                order: order,
                chosen: chosen,
                onReorder: _reorderTabs,
                onToggle: _toggleTab,
              ),
              const SizedBox(height: AppSpacing.xl),
              SettingsSectionLabel(l.settingsViewSettings_sideNav),
              const SizedBox(height: AppSpacing.sm),
              for (final option in _sideNavOptions)
                _SideNavSwitch(
                  label: _screenLabel(l, option.labelKey),
                  value: settings.sideNavOptions[option.settingsKey] != false,
                  onChanged: (value) =>
                      _setSideNavOption(option.settingsKey, value),
                ),
              const SizedBox(height: AppSpacing.xl),
              SettingsSectionLabel(l.settingsViewSettings_landingPage),
              const SizedBox(height: AppSpacing.md),
              SettingsPickerRow(
                text: _screenLabel(l, settings.defaultLandingPage),
                icon: Icons.expand_more,
                onTap: () => _pickLandingPage(settings.defaultLandingPage),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Bottom navigation tabs
  // -------------------------------------------------------------------------

  /// Chosen tabs first, then the rest, both in `bottomNavTabDefs` order.
  static List<String> _seedTabOrder(List<String> chosen) => <String>[
    ...bottomNavTabDefs.map((tab) => tab.key).where(chosen.contains),
    ...bottomNavTabDefs
        .map((tab) => tab.key)
        .where((key) => !chosen.contains(key)),
  ];

  /// Adds or removes a tab, keeping at least one in the bar.
  Future<void> _toggleTab(String key, bool selected) async {
    final current = ref.read(settingsViewModelProvider).value;
    final chosen = current?.bottomNavTabs ?? const <String>[];
    if (!selected && chosen.length <= 1 && chosen.contains(key)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).settingsViewSettings_keepOneTab,
          ),
        ),
      );
      return;
    }
    final order = _tabOrder ??= _seedTabOrder(chosen);
    final next = selected
        ? <String>[...chosen, key]
        : chosen.where((k) => k != key).toList();
    await _saveTabs(_ordered(next, order));
  }

  /// Moves a tab within the full candidate list and re-saves the selection.
  Future<void> _reorderTabs(int oldIndex, int newIndex) async {
    final order = _tabOrder ??= _seedTabOrder(const <String>[]);
    final moved = List<String>.of(order);
    final key = moved.removeAt(oldIndex);
    moved.insert(newIndex, key);
    setState(() => _tabOrder = moved);
    final chosen =
        ref.read(settingsViewModelProvider).value?.bottomNavTabs ??
        const <String>[];
    await _saveTabs(_ordered(chosen, moved));
  }

  /// Writes the chosen tabs to settings, ordered by the display order.
  Future<void> _saveTabs(List<String> chosen) => ref
      .read(settingsViewModelProvider.notifier)
      .updateSettings((settings) => settings.copyWith(bottomNavTabs: chosen));

  /// [keys] in [order], dropping anything no longer offered.
  static List<String> _ordered(List<String> keys, List<String> order) =>
      <String>[
        for (final key in order)
          if (keys.contains(key)) key,
      ];

  // -------------------------------------------------------------------------
  // Simple pickers
  // -------------------------------------------------------------------------

  Future<void> _pickUpcomingPeriod(int current) async {
    final l = AppLocalizations.of(context);
    final selected = await _pickOption<int>(
      title: l.settingsViewSettings_upcomingPeriod,
      options: _upcomingPeriods,
      selected: current,
      labelOf: (days) => l.settingsViewSettings_days(days),
    );
    if (selected == null) return;
    await _update(
      (settings) => settings.copyWith(upcomingCasesPeriod: selected),
    );
  }

  Future<void> _pickCaseListMode(String current) async {
    final l = AppLocalizations.of(context);
    final selected = await _pickOption<String>(
      title: l.settingsViewSettings_caseListMode,
      options: const <String>['compact', 'expanded'],
      selected: current,
      labelOf: (mode) => _caseListModeLabel(l, mode),
    );
    if (selected == null) return;
    await _update(
      (settings) => settings.copyWith(caseListDisplayMode: selected),
    );
  }

  Future<void> _pickLandingPage(String current) async {
    final l = AppLocalizations.of(context);
    final selected = await _pickOption<String>(
      title: l.settingsViewSettings_landingPage,
      options: _landingPages,
      selected: current,
      labelOf: (page) => _screenLabel(l, page),
    );
    if (selected == null) return;
    await _update(
      (settings) => settings.copyWith(defaultLandingPage: selected),
    );
  }

  /// Shows a single-select dialog for [options] and returns the choice.
  Future<T?> _pickOption<T>({
    required String title,
    required List<T> options,
    required T selected,
    required String Function(T) labelOf,
  }) => showDialog<T>(
    context: context,
    builder: (_) => _OptionDialog<T>(
      title: title,
      options: options,
      selected: selected,
      labelOf: labelOf,
    ),
  );

  /// Persists one drawer-section visibility toggle.
  Future<void> _setSideNavOption(String key, bool value) => _update(
    (current) => current.copyWith(
      sideNavOptions: <String, dynamic>{...current.sideNavOptions, key: value},
    ),
  );

  Future<void> _update(UserSettings Function(UserSettings current) transform) =>
      ref.read(settingsViewModelProvider.notifier).updateSettings(transform);

  /// Localized label of a case-list density mode.
  static String _caseListModeLabel(AppLocalizations l, String mode) =>
      switch (mode) {
        'expanded' => l.settingsViewSettings_caseListExpanded,
        _ => l.settingsViewSettings_caseListCompact,
      };
}

/// One Settings card with the uppercase label above its controls.
class _SectionCard extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _SectionCard({required this.label, required this.children});

  @override
  // A shaped Material rather than a decorated Container: the card holds
  // ListTiles (the side-nav switches), which must paint on a Material.
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceContainerLowest,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
      side: BorderSide(color: AppColors.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionLabel(label),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    ),
  );
}

/// The six candidate tabs: checkbox to include, drag handle to order.
class _TabChooser extends StatelessWidget {
  /// Every candidate key, in display order.
  final List<String> order;

  /// Keys currently in the bottom bar.
  final List<String> chosen;

  /// Called with the new (from, to) indexes after a drag.
  final void Function(int, int) onReorder;

  /// Called when a row's checkbox changes.
  final void Function(String key, bool selected) onToggle;

  const _TabChooser({
    required this.order,
    required this.chosen,
    required this.onReorder,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final defs = {for (final tab in bottomNavTabDefs) tab.key: tab};
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: order.length,
      onReorderItem: onReorder,
      itemBuilder: (context, index) {
        final key = order[index];
        final def = defs[key];
        if (def == null) return const SizedBox.shrink();
        final selected = chosen.contains(key);
        return Padding(
          key: ValueKey(key),
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                activeColor: AppColors.secondary,
                onChanged: (value) => onToggle(key, value ?? false),
              ),
              Icon(def.icon, size: 20, color: AppColors.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(def.label(l), style: AppTypography.bodyMd)),
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  child: Icon(Icons.drag_indicator, color: AppColors.tertiary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One drawer-section visibility row.
class _SideNavSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SideNavSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SwitchListTile(
    value: value,
    onChanged: onChanged,
    activeThumbColor: AppColors.secondary,
    contentPadding: EdgeInsets.zero,
    title: Text(label, style: AppTypography.bodyMd),
  );
}

/// Single-select dialog used by the period, density and landing-page pickers.
class _OptionDialog<T> extends StatelessWidget {
  final String title;
  final List<T> options;
  final T selected;
  final String Function(T) labelOf;

  const _OptionDialog({
    required this.title,
    required this.options,
    required this.selected,
    required this.labelOf,
  });

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(AppSpacing.md),
    backgroundColor: AppColors.surfaceContainerLowest,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsPickerDialogHeader(title: title),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final option in options) ...[
                if (option != options.first)
                  const Divider(height: 1, color: AppColors.outlineVariant),
                SettingsOptionRow(
                  label: labelOf(option),
                  selected: option == selected,
                  onTap: () => Navigator.of(context).pop(option),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
