/// The Admin Panel: a menu of the two things an administrator manages.
///
/// Task 22, reshaped. It used to render the payment queue itself; now it is a
/// sub-menu — the same [SettingsMenuCard] rows the Account & Profile menu uses —
/// and each row opens a page of its own: **Payment Requests** (the queue, with
/// its Pending and Resolved sections) and **Non-verified Accounts** (the
/// sign-ups that never confirmed their address, so abandoned ones can be
/// cleaned up).
///
/// The panel keeps the case screens' header — a hamburger that opens the side
/// menu, the Sync Status badge and the Sync button — rather than the back arrow
/// a Settings sub-page wears, because this is a **top-level destination**: it is
/// in the side menu and a bottom-navigation tab. The two sub-pages are pushed on
/// top of it and do carry a back arrow.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/app_share_flow.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/app_navigation_drawer.dart';
import '../../../shared/widgets/sync_button.dart';
import '../../../sync/connectivity_monitor.dart';
import '../../../sync/sync_providers.dart';
import '../../../sync/sync_health.dart';
import '../../../sync/sync_service.dart';
import '../../../sync/sync_status_providers.dart';
import '../../accounts_and_profile/data/account_mode.dart';
import '../../cases/presentation/cases_screen_modal.dart' show SyncState;
import '../../settings/presentation/settings_menu_card.dart';
import '../../settings/presentation/settings_viewmodel.dart';
import 'admin_viewmodel.dart';

/// The administrator's menu: the two sets of work the panel holds.
class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen> {
  @override
  void initState() {
    super.initState();
    // Fresh counts on every open (user request): both lists are cached server
    // reads, so without this the panel could show what it saw at the last pull.
    // After the first frame, so the providers are not touched mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(adminPaymentRequestsProvider);
      ref.invalidate(adminUnconfirmedAccountsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    /// A row's waiting count, in the language's own digits.
    ///
    /// Always drawn, including as `0`: a row that hid its number would leave
    /// the admin unable to tell "nothing waiting" from "not loaded yet".
    Widget countTrailing(int count) => Text(
      AppDateUtils.formatDigits(count, l.localeName),
      style: AppTypography.titleMd.copyWith(color: AppColors.onSurfaceVariant),
    );

    // A shell route, so `AppShellRoot`'s SafeArea already insets the status bar
    // above this screen — unlike the paywall, which sits outside the shell. A
    // second SafeArea here would double the inset.
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: AppNavigationDrawer(
        currentRoute: AppRoutes.adminPanel,
        sideNavOptions:
            ref.watch(settingsViewModelProvider).value?.sideNavOptions ??
            const {},
        // The case screens the bottom bar already carries are hidden from the
        // drawer, so it needs the bar's own selection and order.
        bottomNavTabs:
            ref.watch(settingsViewModelProvider).value?.bottomNavTabs ??
            const <String>[],
        bottomNavOrder:
            ref.watch(settingsViewModelProvider).value?.bottomNavOrder ??
            const <String>[],
        // Print is left unbound: there is nothing here to print, and the
        // drawer hides the action rather than offering one that only reports
        // that it cannot help.
        onShare: () => shareAppInvite(context, ref),
      ),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: _AdminHeader(title: l.adminPanel_title),
      ),
      // Pull down to sync (user request): the same forced drain with the delta
      // pull the header button runs, and then a re-read of both lists, so a
      // payment or a sign-up that landed while the panel was open appears
      // without a trip to Settings.
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(syncServiceProvider).retryNow();
          ref.invalidate(adminPaymentRequestsProvider);
          ref.invalidate(adminUnconfirmedAccountsProvider);
          await ref.read(adminPaymentRequestsProvider.future);
          await ref.read(adminUnconfirmedAccountsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.edgeMargin,
            AppSpacing.md,
            AppSpacing.edgeMargin,
            AppSpacing.xl,
          ),
          children: [
            SettingsMenuCard(
              icon: Icons.receipt_long_outlined,
              title: l.adminPanel_paymentRequests,
              subtitle: l.adminPanel_paymentRequestsSubtitle,
              // The count sits where the chevron would, beside the text (user
              // request) — the same shape the two payment sections use.
              trailing: countTrailing(
                ref.watch(adminPendingPaymentsProvider),
              ),
              onTap: () => context.push(AppRoutes.adminPaymentRequests),
            ),
            const SizedBox(height: AppSpacing.gutter),
            SettingsMenuCard(
              icon: Icons.person_off_outlined,
              title: l.adminPanel_unverifiedAccounts,
              subtitle: l.adminPanel_unverifiedAccountsSubtitle,
              trailing: countTrailing(
                ref.watch(adminUnconfirmedCountProvider),
              ),
              onTap: () => context.push(AppRoutes.adminUnverifiedAccounts),
            ),
          ],
        ),
      ),
    );
  }
}

/// The case screens' header, minus the controls that have nothing to act on.
///
/// A hamburger that opens the drawer and the Sync Status badge, exactly as
/// `CasesScreenModal` draws them — no back arrow (the drawer and the system back
/// gesture are already two ways out, and a third button answering the same
/// question is noise), no search and no view toggle (both belong to a case
/// list, and an admin panel has none to search or restyle).
class _AdminHeader extends ConsumerWidget {
  final String title;

  const _AdminHeader({required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    // Read from the same provider the case screens read, so the badge appears
    // on exactly the same condition here as on a case screen.
    final attention = ref.watch(syncStatusAttentionProvider).value ?? 0;
    final pending = ref.watch(syncQueuePendingCountProvider).value ?? 0;
    final online = ref.watch(isOnlineProvider).value ?? true;
    final health = ref.watch(syncHealthProvider).value;
    final syncState = switch (health?.status) {
      SyncHealthStatus.syncing => SyncState.syncing,
      SyncHealthStatus.healthy => SyncState.success,
      SyncHealthStatus.paused => SyncState.paused,
      _ => SyncState.idle,
    };
    final premium = ref.watch(premiumAccessProvider).value == true;

    return Container(
      height: 56,
      color: AppColors.surface,
      child: Row(
        children: [
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
          // The same Sync Status badge the case screens carry, count and all —
          // including its digits: `Badge.count` would paint Latin ones, so the
          // label is formatted in the active language like every other count.
          if (attention > 0)
            IconButton(
              key: const ValueKey('admin-panel-sync-status'),
              icon: Badge(
                label: Text(
                  AppDateUtils.formatDigits(
                    attention,
                    l.localeName,
                    grouping: false,
                  ),
                ),
                child: const Icon(Icons.sync_problem, color: AppColors.error),
              ),
              tooltip: l.syncStatus_title,
              onPressed: () => context.push(AppRoutes.settingsSyncStatus),
            ),
          // The same shared sync button the case screens carry, so an admin
          // pulls a sync from wherever they are. It reads the same providers
          // and does the same work — `retryNow`, which clears the backoff and
          // runs a forced drain with the delta pull.
          SyncButton(
            syncState: syncState,
            isPremium: premium,
            onSync: () => ref.read(syncServiceProvider).retryNow(),
            l: l,
            pending: pending,
            isOnline: online,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
