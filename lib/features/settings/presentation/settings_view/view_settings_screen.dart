/// View settings screen: display and navigation configuration.
///
/// There is no mockup for this screen, so the body follows plan §10.1
/// (`upcoming_cases_period`, `case_list_display_mode`, `bottom_nav_tabs`,
/// `side_nav_options`, `default_landing_page`) in the same card, section and
/// 48 px control language as the Notifications screen: every dropdown carries
/// its own title directly above the control, and both the title and the
/// collapsed value are Title Case.
///
/// Font Size is the screen's own addition to that list: a − / + stepper whose
/// step (`font_size_step`) is added to every text size in the app by
/// [FontSizeScope] at the app root. The app deliberately ignores the phone's
/// own font-size setting, so this is the only control that can change the app's
/// text — and it changes the screen you are standing on as you use it.
///
/// The two list settings render as dropdowns too — their items live inside the
/// picker instead of inline on the page, no item shows a per-screen icon, and
/// the Bottom Navigation list is reorderable by drag & drop. Default Landing
/// Page sits in its own card; Display and Navigation each keep theirs.
///
/// Both list dropdowns offer the same screens — both derive them from
/// [bottomNavTabDefs], the app's single source of screen identity, so the two
/// can never disagree. The Bottom Navigation rows are shown in the order the
/// user saved (`bottom_nav_order`), which is canonical until they rearrange a
/// row; Side Navigation Options stays in the canonical order. Side Navigation
/// Options omits Settings because Settings is not removable; the drawer always
/// shows it, whatever `side_nav_options` holds.
///
/// All values are durable per-user preferences in the local
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
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/bottom_nav_bar.dart';
import '../../../admin/presentation/admin_viewmodel.dart';
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

/// Row order of the Bottom Navigation dropdown: the saved serial for the
/// screens it names, then any screen it does not name in canonical order — a
/// screen added in a later release, or every screen on an install that has
/// never rearranged a row, since an empty serial means canonical.
///
/// [available] is the canonical list this screen may offer, which is
/// [bottomNavTabDefs] minus any `adminOnly` entry the signed-in account is not
/// entitled to (Task 22). A stored key outside it is dropped rather than shown,
/// so an admin session that ended cannot leave a row behind.
List<String> _bottomTabSerial(
  UserSettings settings,
  List<BottomNavTabDef> available,
) {
  final canonical = <String>[for (final def in available) def.key];
  final known = canonical.toSet();
  final stored = <String>[
    for (final key in settings.bottomNavOrder)
      if (known.contains(key)) key,
  ];
  return <String>[
    ...stored,
    for (final key in canonical)
      if (!stored.contains(key)) key,
  ];
}

/// View settings screen.
class ViewSettingsScreen extends ConsumerWidget {
  const ViewSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings =
        ref.watch(settingsViewModelProvider).value ?? const UserSettings();
    // Task 22: the Admin Panel is offered only to an account the server has
    // confirmed as an admin, and false while that answer is still loading — so
    // the pickers below never list a screen this person cannot open.
    final isAdmin = ref.watch(adminStatusProvider).value ?? false;
    final available = <BottomNavTabDef>[
      for (final def in bottomNavTabDefs)
        if (!def.adminOnly || isAdmin) def,
    ];
    final shownSections = available
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
          // Font size: the section's label is the control's title, and the
          // control names its own value, so there is no second label.
          _SectionCard(
            label: l.settingsViewSettings_sectionFontSize,
            children: [
              _FontSizeStepper(
                step: settings.fontSizeStep,
                onChanged: (next) => _update(
                  ref,
                  (current) => current.copyWith(fontSizeStep: next),
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
                onTap: () =>
                    _pickBottomTabs(context, ref, settings, available),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Side navigation options: which drawer sections stay visible.
              SettingsSectionLabel(l.settingsViewSettings_sideNav),
              const SizedBox(height: AppSpacing.md),
              SettingsPickerRow(
                text: l.settingsViewSettings_sideNavCount(
                  shownSections,
                  available.length,
                ),
                icon: Icons.expand_more,
                onTap: () => _pickSideNav(context, ref, settings, available),
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

  /// Bottom-navigation dropdown: every candidate screen as a check-mark row,
  /// draggable to reorder.
  ///
  /// The rows open in the saved serial (canonical until the user drags one),
  /// so ticking a screen never moves it while a drag is remembered: reopening
  /// the dropdown shows the order the user left it in. A drag also rewrites the
  /// saved tab order, which is the order the bottom bar renders, so dragging
  /// stays the way to set the bar's order.
  Future<void> _pickBottomTabs(
    BuildContext context,
    WidgetRef ref,
    UserSettings settings,
    List<BottomNavTabDef> available,
  ) async {
    final l = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (_) => SettingsMultiSelectDialog<String>(
        title: l.settingsViewSettings_bottomTabs,
        order: _bottomTabSerial(settings, available),
        selected: settings.bottomNavTabs
            .where((k) => available.any((def) => def.key == k))
            .toSet(),
        labelOf: (key) => _screenLabel(l, key),
        reorderable: true,
        minSelected: 1,
        minSelectedMessage: l.settingsViewSettings_keepOneTab,
        // The dragged serial is saved with the selection, so the dropdown and
        // the bar always agree on the order.
        onChanged: (order, chosen) => _update(
          ref,
          (current) =>
              current.copyWith(bottomNavTabs: chosen, bottomNavOrder: order),
        ),
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
    List<BottomNavTabDef> available,
  ) async {
    final l = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (_) => SettingsMultiSelectDialog<String>(
        title: l.settingsViewSettings_sideNav,
        order: <String>[for (final def in available) def.route],
        selected: <String>{
          for (final def in available)
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

/// The Font Size control: two buttons and the current step between them.
///
/// The step is what every text's own size gains or loses, so the middle reads
/// `Default` at 0 and `+2` / `-2` away from it, in the language's own digits.
/// A button at the end of the range is disabled rather than silently doing
/// nothing, and tapping the value resets to `Default` — the fastest way back
/// from an experiment with the largest sizes.
class _FontSizeStepper extends StatelessWidget {
  /// Saved step in logical pixels; 0 is the shipped default.
  final int step;

  /// Called with the new step after a tap.
  final ValueChanged<int> onChanged;

  const _FontSizeStepper({required this.step, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final digits = AppDateUtils.formatDigits(
      step.abs(),
      Localizations.localeOf(context).toLanguageTag(),
      grouping: false,
    );
    final label = switch (step) {
      0 => l.settingsViewSettings_fontSizeDefault,
      > 0 => l.settingsViewSettings_fontSizeMore(digits),
      _ => l.settingsViewSettings_fontSizeLess(digits),
    };

    return Row(
      children: [
        _StepButton(
          icon: Icons.remove,
          tooltip: l.settingsViewSettings_fontSizeDecrease,
          onTap: step <= fontSizeStepMin ? null : () => onChanged(step - 1),
        ),
        Expanded(
          child: Center(
            child: Tooltip(
              message: l.settingsViewSettings_fontSizeReset,
              child: InkWell(
                onTap: step == 0 ? null : () => onChanged(0),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Text(
                    label,
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        _StepButton(
          icon: Icons.add,
          tooltip: l.settingsViewSettings_fontSizeIncrease,
          onTap: step >= fontSizeStepMax ? null : () => onChanged(step + 1),
        ),
      ],
    );
  }
}

/// A 48 px square stepper button, drawn in the picker row's own language.
class _StepButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: AppColors.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        side: BorderSide(color: AppColors.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: onTap == null
                ? AppColors.outlineVariant
                : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    ),
  );
}

/// One Settings card with the Title Case label above its controls.
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
