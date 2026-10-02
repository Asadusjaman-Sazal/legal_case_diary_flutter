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
import '../../../core/router/app_router.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/services/app_share_flow.dart';
import '../../../shared/widgets/app_navigation_drawer.dart';
import '../../../shared/widgets/bottom_nav_bar.dart';
import '../../accounts_and_profile/data/account_mode.dart';
import '../../admin/presentation/admin_viewmodel.dart';
import '../../payments/presentation/subscription_banner.dart';
import '../../sync/presentation/sync_conflict_banner.dart';
import '../../sync/presentation/sync_notice_banner.dart';
import '../../../sync/sync_health.dart';
import '../../../sync/sync_providers.dart';
import '../../../sync/sync_service.dart';
import '../../../sync/sync_status_providers.dart';

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
        // Shares the app itself, never the PDF — the two actions stay separate.
        // The action is shared with every other drawer (Settings included),
        // so it lives in `core/services/app_share_flow.dart`.
        onShare: onShare ?? () => shareAppInvite(context, ref),
      ),
      body: Column(
        children: [
          _CasesHeader(
            title: title,
            syncState: _liveSyncState(ref),
            isPremium: _livePremium(ref),
            onSync: () => _onSyncTap(ref),
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
      // The app-wide conflict banner sits directly above the nav bar on every
      // case-list screen, so an unresolved conflict is never out of sight.
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The persistent subscription bar, then the dismissible notice, then
          // the non-dismissible conflict strip.
          const SubscriptionBanner(),
          const SyncNoticeBanner(),
          const SyncConflictBanner(),
          BottomNavBar(
            currentRoute: currentRoute,
            tabKeys: tabKeys,
            onTabSelected: (route) => context.go(route),
            // Task 22: the Admin Panel tab is only ever offered to an account
            // the server has confirmed as an admin. False while that answer is
            // still loading, so the tab appears once the answer arrives and
            // never before.
            isAdmin: ref.watch(adminStatusProvider).value ?? false,
          ),
        ],
      ),
      floatingActionButton: _buildFabStack(l),
    );
  }

  /// The sync button's state: the live sync health, or a host's override.
  ///
  /// A host screen that passes its own [syncState] keeps it — the parameter is
  /// the seam a future screen with a different sync story can use — but every
  /// case-list screen today passes nothing, so the header reports the real engine
  /// through the same three states the shell always had: running, done, and the
  /// "Sync paused" indicator the plan asks for after three consecutive failures.
  SyncState _liveSyncState(WidgetRef ref) {
    if (syncState != SyncState.idle) return syncState;
    final health = ref.watch(syncHealthProvider).value;
    return switch (health?.status) {
      SyncHealthStatus.syncing => SyncState.syncing,
      SyncHealthStatus.healthy => SyncState.success,
      SyncHealthStatus.paused => SyncState.paused,
      _ => SyncState.idle,
    };
  }

  /// Whether sync is available: the single entitlement derivation, or a host's
  /// explicit answer. A free account sees the disabled button and its tooltip.
  bool _livePremium(WidgetRef ref) =>
      isPremium || ref.watch(premiumAccessProvider).value == true;

  /// Tapping the sync button.
  ///
  /// A paused indicator must actually do something: it resets the backoff and
  /// retries both the channel and the queue immediately, rather than waiting for
  /// the next window. The same entry point serves the plain manual sync.
  Future<void> _onSyncTap(WidgetRef ref) async {
    final override = onSync;
    if (override != null) {
      override();
      return;
    }
    await ref.read(syncServiceProvider).retryNow();
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

class _CasesHeader extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    // The blocked/conflicted badge: entries the user must act on, and nothing
    // else. Ordinary pending work is not news for *that* badge, but it is news
    // for the sync button's count — the two read different providers on purpose.
    final attention = ref.watch(syncStatusAttentionProvider).value ?? 0;
    final pending = ref.watch(syncQueuePendingCountProvider).value ?? 0;
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
          // Sync Status badge — shown only when something is held for a
          // person, and it opens the screen that explains it (Phase 4.4).
          if (attention > 0)
            IconButton(
              key: const ValueKey('cases-modal-sync-status'),
              icon: Badge.count(
                count: attention,
                child: const Icon(Icons.sync_problem, color: AppColors.error),
              ),
              tooltip: l.syncStatus_title,
              onPressed: () => context.push(AppRoutes.settingsSyncStatus),
            ),
          // Sync button — top-right per Addendum 2.4
          _SyncButton(
            syncState: syncState,
            isPremium: isPremium,
            onSync: onSync,
            l: l,
            pending: pending,
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

  /// Changes still waiting to be sent, shown as a red count on the button.
  ///
  /// The existing `sync_problem` badge beside this button only fires for
  /// *blocked* or conflicted work — the things nothing will move on its own.
  /// Ordinary pending work is normal and silent there, which is right for a
  /// badge but wrong for the sync button: a user who has two unsent edits and
  /// taps sync has no way to see that from the header.
  final int pending;

  const _SyncButton({
    required this.syncState,
    required this.isPremium,
    required this.onSync,
    required this.l,
    this.pending = 0,
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
    if (pending > 0) return l.sync_pendingBadge(pending);
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

    // A red count on the sync icon: the ordinary pending work the separate
    // `sync_problem` badge deliberately does not show, because here it answers
    // "why did my edit not appear on the other device yet?".
    //
    // While a sync is actually running the spinner is left bare — a count
    // beside a spinner would suggest work is stuck when it is draining.
    final Widget child =
        pending > 0 && syncState != SyncState.syncing
        ? Badge(
            // Localized digits like every other count in the app: a Latin "2"
            // beside Bengali text is the exact defect this guards against.
            label: Text(
              AppDateUtils.formatDigits(pending, l.localeName, grouping: false),
            ),
            backgroundColor: AppColors.error,
            textColor: AppColors.onError,
            child: icon,
          )
        : icon;

    return Tooltip(
      message: _tooltip(),
      child: IconButton(
        key: const ValueKey('cases-modal-sync-button'),
        icon: child,
        // Tapping still syncs, exactly as before: one control must do one
        // thing. The count is information, and where it can be acted on is the
        // separate Pending Sync entry on the Online Sync screen — which is
        // already reachable, and already where held work is explained.
        onPressed: canTap ? onSync : null,
        tooltip: _tooltip(),
      ),
    );
  }
}
