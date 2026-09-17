/// View settings screen: display and navigation configuration.
///
/// There is no mockup for this screen, so the body follows plan §10.1
/// (`upcoming_cases_period`, `case_list_display_mode`, `bottom_nav_tabs`,
/// `side_nav_options`, `default_landing_page`) in the same card, section and
/// 48 px control language as the Notifications screen: every dropdown carries
/// its own title directly above the control, and both the title and the
/// collapsed value are Title Case.
///
/// The two list settings render as dropdowns too — their items live inside the
/// picker instead of inline on the page, no item shows a per-screen icon, and
/// the Bottom Navigation list is reorderable by drag & drop. Default Landing
/// Page sits in its own card; Display and Navigation each keep theirs.
///
/// Both list dropdowns offer the same screens in the same canonical order, and
/// both derive that list from [bottomNavTabDefs] — the app's single source of
/// screen identity — so the two can never disagree. Side Navigation Options
/// omits Settings because Settings is not removable; the drawer always shows
/// it, whatever `side_nav_options` holds.
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
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/bottom_nav_bar.dart';
import '../settings_controls.dart';
import '../settings_sub_page_modal.dart';
import '../settings_viewmodel.dart';
import '../../data/settings_repository.dart';

/// Periods the Upcoming Cases screen can look ahead, in days.
const List<int> _upcomingPeriods = <int>[3, 7, 14, 30];

/// Screens offered as the default landing page, in canonical order. The two
/// drawer-only screens (Case Reference, Notes) are not landing pages.
const List<String> _landingPages = <String>[
  'all_cases',
  'active',
  'daily_cause_list',
  'overdue',
  'upcoming',
  'disposed',
];

/// Screen definitions by both of the keys this screen stores: the tab key
/// (`overdue`) and the route path (`/overdue-dates`).
final Map<String, BottomNavTabDef> _defByKey = <String, BottomNavTabDef>{
  for (final def in bottomNavTabDefs) def.key: def,
  for (final def in bottomNavTabDefs) def.route: def,
};

/// Localized label for a stored screen key (tab key or route path).
String _screenLabel(AppLocalizations l, String key) =>
    _defByKey[key]?.label(l) ?? key;

/// View settings screen.
class ViewSettingsScreen extends ConsumerWidget {
  const ViewSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings =
        ref.watch(settingsViewModelProvider).value ?? const UserSettings();
    final shownSections = bottomNavTabDefs
        .where((def) => _isSideNavVisible(settings, def))
        .length;

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
              SettingsSectionLabel(l.settingsViewSettings_upcomingPeriod),
              const SizedBox(height: AppSpacing.md),
              SettingsPickerRow(
                text: l.settingsViewSettings_days(settings.upcomingCasesPeriod),
                icon: Icons.expand_more,
                onTap: () => _pickUpcomingPeriod(
                  context,
                  ref,
                  settings.upcomingCasesPeriod,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Case list display mode.
              SettingsSectionLabel(l.settingsViewSettings_caseListMode),
              const SizedBox(height: AppSpacing.md),
              SettingsPickerRow(
                text: _caseListModeLabel(l, settings.caseListDisplayMode),
                icon: Icons.expand_more,
                onTap: () => _pickCaseListMode(
                  context,
                  ref,
                  settings.caseListDisplayMode,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionCard(
            label: l.settingsViewSettings_sectionNavigation,
            children: [
              // Bottom navigation tabs: which screens, in which order.
              SettingsSectionLabel(l.settingsViewSettings_bottomTabs),
              const SizedBox(height: AppSpacing.md),
              SettingsPickerRow(
                text: l.settingsViewSettings_bottomTabsCount(
                  settings.bottomNavTabs.length,
                ),
                icon: Icons.expand_more,
                onTap: () => _pickBottomTabs(context, ref, settings),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Side navigation options: which drawer sections stay visible.
              SettingsSectionLabel(l.settingsViewSettings_sideNav),
              const SizedBox(height: AppSpacing.md),
              SettingsPickerRow(
                text: l.settingsViewSettings_sideNavCount(
                  shownSections,
                  bottomNavTabDefs.length,
                ),
                icon: Icons.expand_more,
                onTap: () => _pickSideNav(context, ref, settings),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // The landing page is a single choice of its own, so it gets its own
          // card; its label doubles as the dropdown's title.
          _SectionCard(
            label: l.settingsViewSettings_landingPage,
            children: [
              SettingsPickerRow(
                text: _screenLabel(l, settings.defaultLandingPage),
                icon: Icons.expand_more,
                onTap: () =>
                    _pickLandingPage(context, ref, settings.defaultLandingPage),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Bottom navigation tabs and side navigation options
  // -------------------------------------------------------------------------

  /// Bottom-navigation dropdown: every candidate screen as a check-mark row in
  /// the canonical serial, draggable to reorder.
  ///
  /// The rows hold the canonical serial whatever the selection is — ticking a
  /// screen must never move it — so only a drag, the user's own change,
  /// rearranges them. A drag also rewrites the saved tab order, which is the
  /// order the bottom bar renders, so dragging stays the way to set the bar's
  /// order.
  Future<void> _pickBottomTabs(
    BuildContext context,
    WidgetRef ref,
    UserSettings settings,
  ) async {
    final l = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (_) => _MultiSelectDropDown(
        title: l.settingsViewSettings_bottomTabs,
        order: <String>[for (final def in bottomNavTabDefs) def.key],
        selected: settings.bottomNavTabs.toSet(),
        labelOf: (key) => _screenLabel(l, key),
        reorderable: true,
        minSelected: 1,
        minSelectedMessage: l.settingsViewSettings_keepOneTab,
        onChanged: (order, chosen) =>
            _update(ref, (current) => current.copyWith(bottomNavTabs: chosen)),
      ),
    );
  }

  /// Side-navigation dropdown: one check-mark row per drawer section, ticked
  /// while the section is visible. The stored key is the route path, which is
  /// exactly what `app_navigation_drawer.dart` looks up in `side_nav_options`;
  /// Settings is absent because the drawer always shows it.
  Future<void> _pickSideNav(
    BuildContext context,
    WidgetRef ref,
    UserSettings settings,
  ) async {
    final l = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (_) => _MultiSelectDropDown(
        title: l.settingsViewSettings_sideNav,
        order: <String>[for (final def in bottomNavTabDefs) def.route],
        selected: <String>{
          for (final def in bottomNavTabDefs)
            if (_isSideNavVisible(settings, def)) def.route,
        },
        labelOf: (route) => _screenLabel(l, route),
        reorderable: false,
        onChanged: (order, visible) => _update(
          ref,
          (current) => current.copyWith(
            sideNavOptions: <String, dynamic>{
              for (final key in order) key: visible.contains(key),
            },
          ),
        ),
      ),
    );
  }

  /// Whether one drawer section is currently shown (absent key means shown).
  static bool _isSideNavVisible(UserSettings settings, BottomNavTabDef def) =>
      settings.sideNavOptions[def.route] != false;

  // -------------------------------------------------------------------------
  // Simple pickers
  // -------------------------------------------------------------------------

  Future<void> _pickUpcomingPeriod(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    final l = AppLocalizations.of(context);
    final selected = await _pickOption<int>(
      context,
      title: l.settingsViewSettings_upcomingPeriod,
      options: _upcomingPeriods,
      selected: current,
      labelOf: (days) => l.settingsViewSettings_days(days),
    );
    if (selected == null) return;
    await _update(
      ref,
      (settings) => settings.copyWith(upcomingCasesPeriod: selected),
    );
  }

  Future<void> _pickCaseListMode(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final l = AppLocalizations.of(context);
    final selected = await _pickOption<String>(
      context,
      title: l.settingsViewSettings_caseListMode,
      options: const <String>['compact', 'expanded'],
      selected: current,
      labelOf: (mode) => _caseListModeLabel(l, mode),
    );
    if (selected == null) return;
    await _update(
      ref,
      (settings) => settings.copyWith(caseListDisplayMode: selected),
    );
  }

  Future<void> _pickLandingPage(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final l = AppLocalizations.of(context);
    final selected = await _pickOption<String>(
      context,
      title: l.settingsViewSettings_landingPage,
      options: _landingPages,
      selected: current,
      labelOf: (page) => _screenLabel(l, page),
    );
    if (selected == null) return;
    await _update(
      ref,
      (settings) => settings.copyWith(defaultLandingPage: selected),
    );
  }

  /// Shows a single-select dialog for [options] and returns the choice.
  Future<T?> _pickOption<T>(
    BuildContext context, {
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

  Future<void> _update(
    WidgetRef ref,
    UserSettings Function(UserSettings current) transform,
  ) => ref.read(settingsViewModelProvider.notifier).updateSettings(transform);

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
  // A shaped Material rather than a decorated Container so further list rows
  // can be added here and still paint on a Material.
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

/// Multi-select dropdown: the shared dark picker header over one check-mark
/// row per item, so a dropdown item carries no icon of its own.
///
/// It keeps its own copy of the order and the selection so a tap or a drag
/// renders immediately, and reports every change through [onChanged]. The
/// dialog stays open while the user works through the list — every row is an
/// independent choice — and the header's close button dismisses it. With
/// [reorderable] each row also gets a drag handle; the saved selection follows
/// the display order, which is the order the bottom bar renders.
class _MultiSelectDropDown extends StatefulWidget {
  /// Dropdown title, shown in the picker header.
  final String title;

  /// Every candidate key, in display order.
  final List<String> order;

  /// Keys that start out selected.
  final Set<String> selected;

  /// Localized label of one key.
  final String Function(String key) labelOf;

  /// Called with the (display order, selection in that order) after a change.
  final void Function(List<String> order, List<String> selected) onChanged;

  /// Whether rows can be dragged into a new order.
  final bool reorderable;

  /// How many rows must stay selected.
  final int minSelected;

  /// Shown when the user tries to go below [minSelected].
  final String? minSelectedMessage;

  const _MultiSelectDropDown({
    required this.title,
    required this.order,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.reorderable = false,
    this.minSelected = 0,
    this.minSelectedMessage,
  });

  @override
  State<_MultiSelectDropDown> createState() => _MultiSelectDropDownState();
}

class _MultiSelectDropDownState extends State<_MultiSelectDropDown> {
  /// Display order of every candidate, as it stands in this dialog.
  late final List<String> _order = List<String>.of(widget.order);

  /// Currently ticked keys.
  late final Set<String> _selected = Set<String>.of(widget.selected);

  /// The selection in display order — the order the bottom bar renders.
  List<String> get _orderedSelection => <String>[
    for (final key in _order)
      if (_selected.contains(key)) key,
  ];

  /// Ticks or unticks [key], refusing to drop below [minSelected].
  void _toggle(String key) {
    final removing = _selected.contains(key);
    if (removing && _selected.length <= widget.minSelected) {
      final message = widget.minSelectedMessage;
      if (message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }
    setState(() {
      if (removing) {
        _selected.remove(key);
      } else {
        _selected.add(key);
      }
    });
    widget.onChanged(_order, _orderedSelection);
  }

  /// Moves one row and re-reports the selection in its new order.
  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final moved = _order.removeAt(oldIndex);
      _order.insert(newIndex, moved);
    });
    widget.onChanged(_order, _orderedSelection);
  }

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
        SettingsPickerDialogHeader(title: widget.title),
        Flexible(child: widget.reorderable ? _draggableRows() : _rows()),
      ],
    ),
  );

  /// Rows the user can drag into a new order (bottom navigation).
  Widget _draggableRows() => ReorderableListView.builder(
    shrinkWrap: true,
    buildDefaultDragHandles: false,
    itemCount: _order.length,
    onReorderItem: _reorder,
    itemBuilder: (context, index) => Row(
      key: ValueKey(_order[index]),
      children: [
        Expanded(child: _row(index)),
        // The drag handle is what makes the item reorderable; the item itself
        // still shows no screen icon.
        ReorderableDragStartListener(
          index: index,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Icon(Icons.drag_indicator, color: AppColors.tertiary),
          ),
        ),
      ],
    ),
  );

  /// Rows in fixed order (side navigation options).
  Widget _rows() => ListView.builder(
    shrinkWrap: true,
    itemCount: _order.length,
    itemBuilder: (context, index) => _row(index),
  );

  /// One check-mark row, with the divider the picker lists use between rows.
  Widget _row(int index) {
    final key = _order[index];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (index > 0)
          const Divider(height: 1, color: AppColors.outlineVariant),
        SettingsOptionRow(
          label: widget.labelOf(key),
          selected: _selected.contains(key),
          onTap: () => _toggle(key),
        ),
      ],
    );
  }
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
