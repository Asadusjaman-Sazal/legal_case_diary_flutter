/// Bottom navigation bar with a configurable tab set.
///
/// Tab order and identity are driven by [UserSettings.bottomNavTabs].
/// Defaults: overdue / daily_cause_list / active / upcoming.
library;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/router/app_router.dart';

/// Descriptor for a single bottom nav tab.
///
/// [bottomNavTabDefs] is the single source of tab identity: the bar renders
/// from it and View Settings offers the same list, so a tab can never exist in
/// one place only.
class BottomNavTabDef {
  /// Stable key persisted in `UserSettings.bottomNavTabs`.
  final String key;

  /// Icon shown when the tab is inactive.
  final IconData icon;

  /// Icon shown while the tab's route is active.
  final IconData activeIcon;

  /// Localized label resolver.
  final String Function(AppLocalizations) label;

  /// Route the tab navigates to.
  final String route;

  const BottomNavTabDef({
    required this.key,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}

/// Every screen that can be placed in the bottom bar, in the app's canonical
/// screen order — the same order Settings > View Settings offers, so the two
/// lists can never drift apart.
const List<BottomNavTabDef> bottomNavTabDefs = [
  BottomNavTabDef(
    key: 'all_cases',
    icon: Icons.list_alt_outlined,
    activeIcon: Icons.list_alt,
    label: _labelAllCases,
    route: AppRoutes.allCases,
  ),
  BottomNavTabDef(
    key: 'active',
    icon: Icons.work_outline,
    activeIcon: Icons.work,
    label: _labelActive,
    route: AppRoutes.activeCases,
  ),
  BottomNavTabDef(
    key: 'daily_cause_list',
    icon: Icons.calendar_today_outlined,
    activeIcon: Icons.calendar_today,
    label: _labelDailyCauseList,
    route: AppRoutes.dailyCauseList,
  ),
  BottomNavTabDef(
    key: 'overdue',
    icon: Icons.error_outline,
    activeIcon: Icons.error,
    label: _labelOverdue,
    route: AppRoutes.overdueDates,
  ),
  BottomNavTabDef(
    key: 'upcoming',
    icon: Icons.event_outlined,
    activeIcon: Icons.event,
    label: _labelUpcoming,
    route: AppRoutes.upcomingCases,
  ),
  BottomNavTabDef(
    key: 'disposed',
    icon: Icons.gavel_outlined,
    activeIcon: Icons.gavel,
    label: _labelDisposed,
    route: AppRoutes.disposedCases,
  ),
  BottomNavTabDef(
    key: 'case_reference',
    icon: Icons.menu_book_outlined,
    activeIcon: Icons.menu_book,
    label: _labelCaseReference,
    route: AppRoutes.caseReference,
  ),
  BottomNavTabDef(
    key: 'notes',
    icon: Icons.sticky_note_2_outlined,
    activeIcon: Icons.sticky_note_2,
    label: _labelNotes,
    route: AppRoutes.notes,
  ),
];

String _labelAllCases(AppLocalizations l) => l.nav_allCases;
String _labelActive(AppLocalizations l) => l.nav_activeCases;
String _labelDailyCauseList(AppLocalizations l) => l.nav_dailyCauseList;
String _labelOverdue(AppLocalizations l) => l.nav_overdueDates;
String _labelUpcoming(AppLocalizations l) => l.nav_upcomingCases;
String _labelDisposed(AppLocalizations l) => l.nav_disposedCases;
String _labelCaseReference(AppLocalizations l) => l.nav_caseReference;
String _labelNotes(AppLocalizations l) => l.nav_notes;

/// Bottom navigation bar driven by [tabKeys] from [UserSettings.bottomNavTabs].
///
/// [currentRoute] — the active GoRouter location used to highlight the active tab.
/// [tabKeys] — ordered list of tab key strings; every entry is rendered, and
///   the bar scrolls horizontally once more than four are chosen (the plan's
///   default selection is four, which still lays out evenly).
/// [onTabSelected] — called with the route path when a tab is tapped.
class BottomNavBar extends StatelessWidget {
  final String currentRoute;
  final List<String> tabKeys;
  final void Function(String route) onTabSelected;

  const BottomNavBar({
    required this.currentRoute,
    required this.tabKeys,
    required this.onTabSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final keyMap = {for (final t in bottomNavTabDefs) t.key: t};
    final tabs = tabKeys
        .map((k) => keyMap[k])
        .whereType<BottomNavTabDef>()
        .toList();

    // Five or six tabs would squeeze the labels to nothing on a phone, so a
    // larger selection scrolls instead of shrinking.
    final Widget content = tabs.length > 4
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final tab in tabs)
                  SizedBox(width: 88, child: _tabButton(context, l, tab)),
              ],
            ),
          )
        : Row(
            children: [
              for (final tab in tabs)
                Expanded(child: _tabButton(context, l, tab)),
            ],
          );

    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: content,
    );
  }

  /// One tab: icon plus label, highlighted while its route is active.
  Widget _tabButton(
    BuildContext context,
    AppLocalizations l,
    BottomNavTabDef tab,
  ) {
    final active = currentRoute == tab.route;
    return InkWell(
      onTap: () => onTabSelected(tab.route),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            active ? tab.activeIcon : tab.icon,
            size: 24,
            color: active ? Colors.black : AppColors.onSurfaceVariant,
          ),
          const SizedBox(height: 2),
          Text(
            tab.label(l),
            style: AppTypography.labelMd.copyWith(
              color: active ? Colors.black : AppColors.onSurfaceVariant,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
