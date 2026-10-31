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
import '../../core/theme/font_size_scope.dart';

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

  /// Whether only an administrator may be offered this screen.
  ///
  /// Task 22. A gated tab is hidden from the bottom bar, the drawer and the
  /// Settings > View Settings pickers for everyone else — but a stored key from
  /// a session that *was* an admin must not leave a dead route behind, so
  /// [BottomNavBar] drops it rather than rendering an entry that cannot open.
  final bool adminOnly;

  const BottomNavTabDef({
    required this.key,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
    this.adminOnly = false,
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
  // Task 22. The last entry, so an admin who enables it appends it to the end
  // of whatever order they already have rather than displacing a case screen.
  BottomNavTabDef(
    key: 'admin_panel',
    icon: Icons.admin_panel_settings_outlined,
    activeIcon: Icons.admin_panel_settings,
    label: _labelAdminPanel,
    route: AppRoutes.adminPanel,
    adminOnly: true,
  ),
];

/// The order the bottom-tab candidates are shown in: the saved serial first,
/// then whatever the user has not placed, canonically.
///
/// This is **the** order for the bar's candidates, and it lives beside
/// [bottomNavTabDefs] because that list is what defines the canonical part. Two
/// surfaces read it — Settings > View Settings' dropdown, which shows the rows
/// in this order and rewrites it on a drag, and the navigation drawer, whose
/// expanded Case Screens list must read in the same serial (user request) — so a
/// second copy would be the thing that drifts.
///
/// A stored key that is no longer a candidate is dropped rather than carried:
/// a screen removed from the list cannot hold a place in the order.
List<String> bottomTabSerial({
  required List<String> storedOrder,
  required List<BottomNavTabDef> available,
}) {
  final canonical = <String>[for (final def in available) def.key];
  final known = canonical.toSet();
  final stored = <String>[
    for (final key in storedOrder)
      if (known.contains(key)) key,
  ];
  return <String>[
    ...stored,
    for (final key in canonical)
      if (!stored.contains(key)) key,
  ];
}

String _labelAllCases(AppLocalizations l) => l.nav_allCases;
String _labelActive(AppLocalizations l) => l.nav_activeCases;
String _labelDailyCauseList(AppLocalizations l) => l.nav_dailyCauseList;
String _labelOverdue(AppLocalizations l) => l.nav_overdueDates;
String _labelUpcoming(AppLocalizations l) => l.nav_upcomingCases;
String _labelDisposed(AppLocalizations l) => l.nav_disposedCases;
String _labelCaseReference(AppLocalizations l) => l.nav_caseReference;
String _labelNotes(AppLocalizations l) => l.nav_notes;
String _labelAdminPanel(AppLocalizations l) => l.nav_adminPanel;

/// The horizontal offset the user last left the bar at.
///
/// Every screen owns its own `CasesScreenModal` and therefore its own
/// [BottomNavBar], so a tab tap mounts a brand-new bar. Without this the new
/// scrollable starts at 0, hiding the button just tapped at the far end; the
/// offset is written as the user scrolls and read when the next screen's bar
/// mounts, so the bar stays where they left it (user report).
double _lastScrollOffset = 0;

/// Forgets the saved position; tests share one isolate.
@visibleForTesting
void resetBottomNavScrollOffset() => _lastScrollOffset = 0;

/// Bottom navigation bar driven by [tabKeys] from [UserSettings.bottomNavTabs].
///
/// [currentRoute] — the active GoRouter location used to highlight the active tab.
/// [tabKeys] — ordered list of tab key strings; every entry is rendered, and
///   the bar scrolls horizontally once more than four are chosen (the plan's
///   default selection is four, which still lays out evenly).
/// [onTabSelected] — called with the route path when a tab is tapped.
/// [isAdmin] — whether the signed-in account is an admin. Defaults to false, so
///   a bar built before that answer arrives shows only ordinary screens, and a
///   tab key stored during an earlier admin session is dropped rather than left
///   as an entry that leads nowhere (see [BottomNavTabDef.adminOnly]).
///
/// The bar opts out of [defaultFontSizeStep], the size the rest of the app
/// ships at (user request): its labels keep their designed 12 px while every
/// other screen grows by that pixel. The user's own step still reaches it — the
/// pixel is subtracted from whatever scale is in effect, not from zero, so at
/// `Default` the bar is exactly as it has always rendered.
class BottomNavBar extends StatefulWidget {
  final String currentRoute;
  final List<String> tabKeys;
  final void Function(String route) onTabSelected;
  final bool isAdmin;

  const BottomNavBar({
    required this.currentRoute,
    required this.tabKeys,
    required this.onTabSelected,
    this.isAdmin = false,
    super.key,
  });

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  /// Starts at the session's saved offset, so a tab tap shows the bar where the
  /// user left it rather than at its first tab.
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: _lastScrollOffset,
  );

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_rememberScrollPosition);
  }

  void _rememberScrollPosition() {
    if (_scroll.hasClients) _lastScrollOffset = _scroll.offset;
  }

  @override
  void dispose() {
    _rememberScrollPosition();
    _scroll
      ..removeListener(_rememberScrollPosition)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final keyMap = {for (final t in bottomNavTabDefs) t.key: t};
    final tabs = widget.tabKeys
        .map((k) => keyMap[k])
        .whereType<BottomNavTabDef>()
        .where((t) => !t.adminOnly || widget.isAdmin)
        .toList();

    // Five or six tabs would squeeze the labels to nothing on a phone, so a
    // larger selection scrolls instead of shrinking.
    final Widget content = tabs.length > 4
        ? SingleChildScrollView(
            controller: _scroll,
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

    // The scale the bar paints under: the app's own, one pixel back down. With
    // no MediaQuery above there is no [FontSizeScope] either, so there is no
    // shipped default to take back out and the base scaler is left alone.
    final media = MediaQuery.maybeOf(context);
    // Android 15 onward draws the app behind the system navigation bar, so the
    // bar takes that inset itself (user report, 0.0.702). `viewPadding`, not
    // `padding`, so the strip does not vanish while the keyboard's own inset is
    // being applied. On phones that still inset the app window this is 0 and
    // the bar is exactly the 64 px it has always been.
    final bottomInset = media?.viewPadding.bottom ?? 0;

    return MediaQuery(
      data: (media ?? const MediaQueryData()).copyWith(
        textScaler: media == null
            ? TextScaler.noScaling
            : SteppedTextScaler(media.textScaler, -defaultFontSizeStep),
      ),
      child: Container(
        // The inset belongs to the bar, so its surface colour fills the strip
        // instead of leaving a gap under it.
        height: 64 + bottomInset,
        padding: EdgeInsets.only(bottom: bottomInset),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.outlineVariant)),
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: content,
      ),
    );
  }

  /// One tab: icon plus label, highlighted while its route is active.
  Widget _tabButton(
    BuildContext context,
    AppLocalizations l,
    BottomNavTabDef tab,
  ) {
    final active = widget.currentRoute == tab.route;
    return InkWell(
      onTap: () => widget.onTabSelected(tab.route),
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
