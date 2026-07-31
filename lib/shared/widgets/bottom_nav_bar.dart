/// Bottom navigation bar with 4 configurable tabs.
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
class _TabDef {
  final String key;
  final IconData icon;
  final IconData activeIcon;
  final String Function(AppLocalizations) label;
  final String route;

  const _TabDef({
    required this.key,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}

const List<_TabDef> _allTabs = [
  _TabDef(
    key: 'overdue',
    icon: Icons.error_outline,
    activeIcon: Icons.error,
    label: _labelOverdue,
    route: AppRoutes.overdueDates,
  ),
  _TabDef(
    key: 'daily_cause_list',
    icon: Icons.calendar_today_outlined,
    activeIcon: Icons.calendar_today,
    label: _labelDailyCauseList,
    route: AppRoutes.dailyCauseList,
  ),
  _TabDef(
    key: 'active',
    icon: Icons.work_outline,
    activeIcon: Icons.work,
    label: _labelActive,
    route: AppRoutes.activeCases,
  ),
  _TabDef(
    key: 'upcoming',
    icon: Icons.event_outlined,
    activeIcon: Icons.event,
    label: _labelUpcoming,
    route: AppRoutes.upcomingCases,
  ),
  _TabDef(
    key: 'all_cases',
    icon: Icons.list_alt_outlined,
    activeIcon: Icons.list_alt,
    label: _labelAllCases,
    route: AppRoutes.allCases,
  ),
  _TabDef(
    key: 'disposed',
    icon: Icons.gavel_outlined,
    activeIcon: Icons.gavel,
    label: _labelDisposed,
    route: AppRoutes.disposedCases,
  ),
];

String _labelOverdue(AppLocalizations l) => l.nav_overdueDates;
String _labelDailyCauseList(AppLocalizations l) => l.nav_dailyCauseList;
String _labelActive(AppLocalizations l) => l.nav_activeCases;
String _labelUpcoming(AppLocalizations l) => l.nav_upcomingCases;
String _labelAllCases(AppLocalizations l) => l.nav_allCases;
String _labelDisposed(AppLocalizations l) => l.nav_disposedCases;

/// Bottom navigation bar driven by [tabKeys] from [UserSettings.bottomNavTabs].
///
/// [currentRoute] — the active GoRouter location used to highlight the active tab.
/// [tabKeys] — ordered list of tab key strings (max 4 rendered; extras ignored).
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
    final keyMap = {for (final t in _allTabs) t.key: t};
    final tabs = tabKeys
        .take(4)
        .map((k) => keyMap[k])
        .whereType<_TabDef>()
        .toList();

    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: tabs.map((tab) {
          final active = currentRoute == tab.route;
          return Expanded(
            child: InkWell(
              onTap: () => onTabSelected(tab.route),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    active ? tab.activeIcon : tab.icon,
                    size: 24,
                    color: active
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tab.label(l),
                    style: AppTypography.labelMd.copyWith(
                      color: active
                          ? AppColors.primary
                          : AppColors.onSurfaceVariant,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
