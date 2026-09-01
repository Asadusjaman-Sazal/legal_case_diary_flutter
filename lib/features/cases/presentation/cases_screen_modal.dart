/// Reusable case-screen shell widget.
///
/// Provides for every case list screen:
///   - Hamburger button that opens [AppNavigationDrawer].
///   - Page header: title, search button, view-toggle buttons, manual sync button.
///   - [BottomNavBar] driven by [UserSettings.bottomNavTabs].
///   - FAB (Add New Case) — hidden when [showFab] is false (Disposed Cases).
///   - Print and Share action callbacks (Task 14 owns the platform service).
///
/// The sync button exposes five accessible states via [SyncState].
/// In Part A (no premium entitlement) the button is disabled and shows a
/// localized tooltip explaining that sync requires a premium subscription.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../features/settings/data/settings_repository.dart';
import '../../../shared/widgets/app_navigation_drawer.dart';
import '../../../shared/widgets/bottom_nav_bar.dart';

// ---------------------------------------------------------------------------
// Sync state
// ---------------------------------------------------------------------------

/// The five observable states of the manual sync button.
enum SyncState {
  /// No sync in progress; button is tappable.
  idle,

  /// Sync is actively running; button shows a spinner.
  syncing,

  /// Last sync completed successfully.
  success,

  /// Sync is paused (e.g. offline or subscription lapsed).
  paused,

  /// Last sync ended with an error.
  error,
}

// ---------------------------------------------------------------------------
// Settings stream provider (scoped to this widget)
// ---------------------------------------------------------------------------

/// Watches the live [UserSettings] stream so [CasesScreenModal] reacts to
/// settings changes without re-creating a new Future on every rebuild.
final _userSettingsProvider = StreamProvider<UserSettings>((ref) async* {
  final repo = await ref.watch(settingsRepositoryProvider.future);
  yield* repo.watchSettings();
});

// ---------------------------------------------------------------------------
// CasesScreenModal
// ---------------------------------------------------------------------------

/// Reusable shell for all case list screens.
///
/// [title] — screen title shown in the header.
/// [body] — the scrollable content area (case list, etc.).
/// [searchQuery] — current scoped search query string provided by the host
///   screen; passed through so the shell can reflect it (e.g. clear button).
/// [syncState] — current sync state; defaults to [SyncState.idle].
/// [isPremium] — when false the sync button is disabled with an entitlement
///   tooltip; when true the button is active and calls [onSync].
/// [onSync] — called when the user taps the sync button (premium only).
/// [onSearch] — called when the user taps the search icon.
/// [onViewToggle] — called with `true` for compact, `false` for expanded.
/// [isCompactView] — current view mode; drives the toggle icon state.
/// [showFab] — whether to show the Add New Case FAB (false for Disposed Cases).
/// [onAddCase] — called when the FAB is tapped.
/// [showHelpFab] — whether to show the Help FAB (Disposed Cases only).
/// [onHelp] — called when the Help FAB is tapped.
/// [onPrint] — forwarded to [AppNavigationDrawer].
/// [onShare] — forwarded to [AppNavigationDrawer].
class CasesScreenModal extends ConsumerWidget {
  final String title;
  final Widget body;
  final String searchQuery;
  final SyncState syncState;
  final bool isPremium;
  final VoidCallback? onSync;
  final VoidCallback? onSearch;
  final void Function(bool compact)? onViewToggle;
  final bool isCompactView;
  final bool showFab;
  final VoidCallback? onAddCase;
  final bool showHelpFab;
  final VoidCallback? onHelp;
  final VoidCallback? onPrint;
  final VoidCallback? onShare;

  const CasesScreenModal({
    required this.title,
    required this.body,
    this.searchQuery = '',
    this.syncState = SyncState.idle,
    this.isPremium = false,
    this.onSync,
    this.onSearch,
    this.onViewToggle,
    this.isCompactView = true,
    this.showFab = true,
    this.onAddCase,
    this.showHelpFab = false,
    this.onHelp,
    this.onPrint,
    this.onShare,
    super.key,
  });

  static const List<String> _defaultTabs = [
    'overdue',
    'daily_cause_list',
    'active',
    'upcoming',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final currentRoute = GoRouterState.of(context).uri.path;

    // Watch the live settings stream — stable across rebuilds, no per-rebuild
    // Future creation. Falls back to defaults while the stream is loading.
    final settingsAsync = ref.watch(_userSettingsProvider);
    final settings = settingsAsync.value;
    final tabKeys = settings?.bottomNavTabs ?? _defaultTabs;
    final sideNavOptions = settings?.sideNavOptions ?? const {};

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: AppNavigationDrawer(
        currentRoute: currentRoute,
        sideNavOptions: sideNavOptions,
        onPrint: onPrint,
        onShare: onShare,
      ),
      body: Column(
        children: [
          _CasesHeader(
            title: title,
            syncState: syncState,
            isPremium: isPremium,
            onSync: onSync,
            onSearch: onSearch,
            onViewToggle: onViewToggle,
            isCompactView: isCompactView,
            l: l,
          ),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentRoute: currentRoute,
        tabKeys: tabKeys,
        onTabSelected: (route) => context.go(route),
      ),
      floatingActionButton: _buildFabStack(l),
    );
  }

  /// Stacks the Add Case FAB and (optionally) the Help FAB at the same
  /// bottom-right location used by the other case-list screens.
  Widget _buildFabStack(AppLocalizations l) {
    final buttons = <Widget>[];

    if (showFab) {
      buttons.add(
        FloatingActionButton(
          onPressed: onAddCase,
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          tooltip: l.casesModal_addCase,
          child: const Icon(Icons.add, size: 28),
        ),
      );
    }

    if (showHelpFab) {
      buttons.add(
        FloatingActionButton(
          heroTag: 'help',
          onPressed: onHelp,
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          tooltip: l.casesModal_help,
          child: const Icon(Icons.help_outline, size: 28),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    // Reverse so the Add Case FAB stays on top (first in the column is lowest).
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: buttons.reversed.toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _CasesHeader extends StatelessWidget {
  final String title;
  final SyncState syncState;
  final bool isPremium;
  final VoidCallback? onSync;
  final VoidCallback? onSearch;
  final void Function(bool compact)? onViewToggle;
  final bool isCompactView;
  final AppLocalizations l;

  const _CasesHeader({
    required this.title,
    required this.syncState,
    required this.isPremium,
    required this.onSync,
    required this.onSearch,
    required this.onViewToggle,
    required this.isCompactView,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: AppColors.surface,
      child: Row(
        children: [
          // Hamburger — opens the drawer.
          IconButton(
            icon: const Icon(Icons.menu, color: AppColors.primary),
            tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
          Expanded(
            child: Text(
              title,
              style: AppTypography.titleLg,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Search
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.primary),
            tooltip: l.casesModal_search,
            onPressed: onSearch,
          ),
          // View toggle: compact ↔ expanded
          IconButton(
            icon: Icon(
              isCompactView
                  ? Icons.grid_view_outlined
                  : Icons.view_agenda_outlined,
              color: AppColors.primary,
            ),
            tooltip: isCompactView
                ? l.casesModal_viewExpanded
                : l.casesModal_viewCompact,
            onPressed: () => onViewToggle?.call(!isCompactView),
          ),
          // Sync button — top-right per Addendum 2.4
          _SyncButton(
            syncState: syncState,
            isPremium: isPremium,
            onSync: onSync,
            l: l,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sync button
// ---------------------------------------------------------------------------

class _SyncButton extends StatelessWidget {
  final SyncState syncState;
  final bool isPremium;
  final VoidCallback? onSync;
  final AppLocalizations l;

  const _SyncButton({
    required this.syncState,
    required this.isPremium,
    required this.onSync,
    required this.l,
  });

  Color get _iconColor {
    if (!isPremium) return AppColors.onSurfaceVariant;
    return switch (syncState) {
      SyncState.idle => AppColors.primary,
      SyncState.syncing => AppColors.secondary,
      SyncState.success => AppColors.success,
      SyncState.paused => AppColors.onSurfaceVariant,
      SyncState.error => AppColors.error,
    };
  }

  String _tooltip() {
    if (!isPremium) return l.sync_unavailable;
    return switch (syncState) {
      SyncState.idle => l.sync_idle,
      SyncState.syncing => l.sync_syncing,
      SyncState.success => l.sync_success,
      SyncState.paused => l.sync_paused,
      SyncState.error => l.sync_error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final canTap = isPremium && syncState != SyncState.syncing;

    final Widget icon;
    if (syncState == SyncState.syncing && isPremium) {
      icon = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.secondary,
        ),
      );
    } else {
      icon = Icon(
        switch (syncState) {
          SyncState.success => Icons.cloud_done_outlined,
          SyncState.paused => Icons.cloud_off_outlined,
          SyncState.error => Icons.sync_problem_outlined,
          _ => Icons.sync,
        },
        color: _iconColor,
        size: 22,
      );
    }

    return Tooltip(
      message: _tooltip(),
      child: IconButton(
        icon: icon,
        onPressed: canTap ? onSync : null,
        tooltip: _tooltip(),
      ),
    );
  }
}
