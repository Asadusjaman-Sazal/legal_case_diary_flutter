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
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/print/print_document.dart';
import '../../../core/print/print_flow.dart';
import '../../../core/providers/print_providers.dart';
import '../../../core/providers/settings_providers.dart';
import '../../../core/services/app_share_service.dart';
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
/// [onSearch] — called when the user taps the search icon, and by the search
///   bar's close (x); the host screen toggles its own search state with it.
/// [isSearching] — when true the shell renders the scoped search bar under the
///   header; the host screen owns the state so it can filter its own dataset.
/// [searchController] — query text of the open search bar.
/// [onSearchChanged] — called on every keystroke so the host can rebuild.
/// [onViewToggle] — called with `true` for compact, `false` for extended; when
///   null the header shows no view toggle at all (libraries without a case
///   list). The host owns the stored mode through `case_list_view_mode.dart`.
/// [isCompactView] — current view mode; drives the toggle icon state.
/// [showFab] — whether to show the Add New Case FAB (false for Disposed Cases).
/// [onAddCase] — called when the FAB is tapped.
/// [showHelpFab] — whether to show the Help FAB (Disposed Cases only).
/// [onHelp] — called when the Help FAB is tapped.
/// [documentBuilder] — builds the printable document from what the host screen
///   is showing (Task 14). When it is absent the shell says so instead of
///   leaving a dead Print tap; Share always works, because it shares the app.
/// [onPrint] — overrides the Print action entirely (used by hosts that own
///   their own print path).
/// [onShare] — overrides the Share action.
class CasesScreenModal extends ConsumerWidget {
  final String title;
  final Widget body;
  final String searchQuery;
  final SyncState syncState;
  final bool isPremium;
  final VoidCallback? onSync;
  final VoidCallback? onSearch;
  final bool isSearching;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final void Function(bool compact)? onViewToggle;
  final bool isCompactView;
  final bool showFab;
  final VoidCallback? onAddCase;
  final bool showHelpFab;
  final VoidCallback? onHelp;
  final VoidCallback? onPrint;
  final VoidCallback? onShare;

  /// Builds the printable document from the host screen's current rows.
  final PrintDocument Function()? documentBuilder;

  const CasesScreenModal({
    required this.title,
    required this.body,
    this.searchQuery = '',
    this.syncState = SyncState.idle,
    this.isPremium = false,
    this.onSync,
    this.onSearch,
    this.isSearching = false,
    this.searchController,
    this.onSearchChanged,
    this.onViewToggle,
    this.isCompactView = true,
    this.showFab = true,
    this.onAddCase,
    this.showHelpFab = false,
    this.onHelp,
    this.onPrint,
    this.onShare,
    this.documentBuilder,
    super.key,
  });

  /// Renders the host screen's document and presents the OS print dialog.
  Future<void> _printDocument(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final outcome = await printDocument(
      context: context,
      document: documentBuilder!(),
      service: ref.read(printServiceProvider),
      renderer: ref.read(printDocumentRendererProvider),
    );
    if (!context.mounted) return;

    // A presented job and a deliberate cancel need no message; a failure and an
    // empty dataset do, and never as a crash.
    switch (outcome) {
      case PrintOutcome.nothingToPrint:
        _say(context, l.print_nothingToPrint);
      case PrintOutcome.failed:
        _say(context, l.print_failed);
      case PrintOutcome.presented:
      case PrintOutcome.cancelled:
        break;
    }
  }

  /// Print is not part of this screen's data, so say that instead of a dead tap.
  void _showPrintUnavailable(BuildContext context, AppLocalizations l) =>
      _say(context, l.print_notAvailable);

  /// Shares the app itself (never the PDF — the two actions stay separate).
  Future<void> _shareApp(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final outcome = await ref
        .read(appShareServiceProvider)
        .shareApp(
          message: l.appShare_invite(appStoreUrl),
          subject: l.appShare_subject,
        );
    if (!context.mounted) return;

    switch (outcome) {
      case AppShareOutcome.copiedToClipboard:
        _say(context, l.appShare_copied);
      case AppShareOutcome.failed:
        _say(context, l.appShare_failed);
      case AppShareOutcome.shared:
      case AppShareOutcome.dismissed:
        break;
    }
  }

  void _say(BuildContext context, String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

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
    final settingsAsync = ref.watch(userSettingsStreamProvider);
    final settings = settingsAsync.value;
    final tabKeys = settings?.bottomNavTabs ?? _defaultTabs;
    final sideNavOptions = settings?.sideNavOptions ?? const {};

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: AppNavigationDrawer(
        currentRoute: currentRoute,
        sideNavOptions: sideNavOptions,
        onPrint: documentBuilder == null
            ? (onPrint ?? () => _showPrintUnavailable(context, l))
            : () => _printDocument(context, ref),
        onShare: onShare ?? () => _shareApp(context, ref),
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
          if (isSearching)
            ScopedSearchBar(
              controller: searchController,
              onChanged: onSearchChanged,
              onClose: onSearch,
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
// Scoped search bar
// ---------------------------------------------------------------------------

/// The prominent search bar the header's search icon opens on every case list,
/// the Notes library and the Case Reference library.
///
/// The host screen owns the query: this only renders the field and reports
/// changes, so the search stays scoped to that screen's own dataset.
class ScopedSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClose;

  const ScopedSearchBar({
    required this.controller,
    this.onChanged,
    this.onClose,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final field = controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: TextField(
        controller: field,
        autofocus: true,
        onChanged: onChanged,
        // A touch anywhere outside the field drops focus, which hides the
        // on-screen keyboard while the search stays open.
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        decoration: InputDecoration(
          hintText: l.sharedActions_search,
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
          isDense: true,
          // Always offered, never only-with-text: the (x) is the way out of
          // the search, so it stays on screen while the query is empty too.
          suffixIcon: IconButton(
            icon: const Icon(Icons.close),
            tooltip: l.sharedActions_close,
            onPressed: () {
              field?.clear();
              onChanged?.call('');
              onClose?.call();
            },
          ),
        ),
      ),
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
          // View toggle: compact ↔ extended. Drawn only when the host screen
          // wires it, so the Notes and Case Reference libraries — which share
          // this shell but have no case list to switch — never show a control
          // that does nothing.
          if (onViewToggle != null)
            IconButton(
              key: const ValueKey('cases-modal-view-toggle'),
              icon: Icon(
                isCompactView
                    ? Icons.grid_view_outlined
                    : Icons.view_agenda_outlined,
                color: AppColors.primary,
              ),
              tooltip: isCompactView
                  ? l.casesModal_viewExpanded
                  : l.casesModal_viewCompact,
              onPressed: () => onViewToggle!(!isCompactView),
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
