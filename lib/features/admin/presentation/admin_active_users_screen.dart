/// The Admin Panel's **Active Users** sub-page: every account that confirmed its
/// e-mail and still exists, oldest account first.
///
/// The list arrives from the admin-gated `admin_list_verified_accounts()` — the
/// auth row is the anchor, so a deleted account cannot appear and an unconfirmed
/// one has no place here. There is no activity window: confirming an address is
/// enough. Each card carries the profile identity, the chamber and role, the
/// later of sign-in and device heartbeat, the current plan and its 48-hour grace,
/// the account's own work counts, its active-device summary and the newest five
/// subscription entries.
///
/// The page filters in memory over **every value the card displays**, including
/// formatted dates, localized plan/status/platform labels, counts and each
/// history line. Clearing the search restores the server's oldest-first order.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/utils/date_utils.dart';
import '../../../sync/sync_service.dart';
import '../../payments/data/payment_plans.dart';
import '../../payments/presentation/payment_plan_labels.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';
import '../data/admin_repository.dart';
import 'admin_shared.dart';
import 'admin_viewmodel.dart';

/// Every confirmed account, oldest first.
class AdminActiveUsersScreen extends ConsumerStatefulWidget {
  const AdminActiveUsersScreen({super.key});

  @override
  ConsumerState<AdminActiveUsersScreen> createState() =>
      _AdminActiveUsersScreenState();
}

class _AdminActiveUsersScreenState
    extends ConsumerState<AdminActiveUsersScreen> {
  bool _isSearching = false;
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // A fresh server read on every open, the same freshness the pull gesture
    // gives, so an account confirmed while the panel was open appears here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(adminActiveUsersProvider);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggleSearch() => setState(() {
    _isSearching = !_isSearching;
    if (!_isSearching) {
      _search.clear();
      _query = '';
    }
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final users = ref.watch(adminActiveUsersProvider);

    return SettingsSubPageModal(
      title: l.adminPanel_activeUsersTitle,
      // The page has its own pull that syncs and reloads the server list.
      pullToSync: false,
      actions: [
        const AdminSyncButton(),
        IconButton(
          key: const ValueKey('admin-active-users-search'),
          icon: const Icon(Icons.search),
          tooltip: l.adminPanel_search,
          onPressed: _toggleSearch,
        ),
      ],
      child: users.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (_, _) => AdminLoadFailed(
          message: l.adminPanel_activeUsersLoadFailed,
          retryLabel: l.adminPanel_retry,
          onRetry: () => ref.invalidate(adminActiveUsersProvider),
        ),
        data: (all) {
          final shown = all
              .where((user) => _matches(l, user, _query))
              .toList(growable: false);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isSearching) _searchField(l),
              if (_query.trim().isNotEmpty && shown.isEmpty)
                AdminNoResults(message: l.adminPanel_noResults)
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await ref.read(syncServiceProvider).retryNow();
                      ref.invalidate(adminActiveUsersProvider);
                      await ref.read(adminActiveUsersProvider.future);
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.edgeMargin,
                        AppSpacing.md,
                        AppSpacing.edgeMargin,
                        AppSpacing.xl,
                      ),
                      children: [
                        if (shown.isEmpty)
                          Text(
                            l.adminPanel_activeUsersEmpty,
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          )
                        else
                          _UserList(users: shown, l: l),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _searchField(AppLocalizations l) => AdminSearchField(
    controller: _search,
    hint: l.adminPanel_searchHint,
    onChanged: (value) => setState(() => _query = value),
    onClose: _toggleSearch,
  );
}

/// Whether [query] matches any value on the account's card.
///
/// Every field is the displayed form — localized dates, labels, digits and
/// ledger lines — so the admin searches what they can see.
bool _matches(AppLocalizations l, AdminActiveUser user, String query) {
  final plan = _planName(l, user);
  final planState = _planState(l, user);
  final role = _roleLabel(l, user.role);
  final firm = user.isIndividual ? l.adminPanel_individual : user.firmName;
  final platforms = user.platforms
      .map((platform) => _platformLabel(l, platform))
      .join(', ');

  return adminTextMatches(query, <String?>[
    user.fullName,
    user.barAssociation,
    user.email,
    user.mobileNo,
    firm,
    user.isIndividual ? null : role,
    adminPanelDateTime(l, user.joinedAt),
    adminPanelDateTime(l, user.lastActiveAt),
    plan,
    planState,
    adminPanelDate(l, user.planExpiry),
    _count(l, user.caseCount),
    _count(l, user.noteCount),
    _count(l, user.referenceCount),
    _count(l, user.deviceCount),
    platforms,
    for (final entry in user.subscriptionHistory) ...[
      _historyPlan(l, entry),
      _historyAmount(l, entry),
      _historyStatus(l, entry.status),
      adminPanelDateTime(l, entry.at),
    ],
  ]);
}

String _count(AppLocalizations l, int value) =>
    AppDateUtils.formatDigits(value, l.localeName);

/// The plan in force: its purchased name where one is known, otherwise the
/// effective tier's own name. A queued other-tier purchase is not named.
String _planName(AppLocalizations l, AdminActiveUser user) {
  final key = user.currentPlanKey;
  if (key != null && key.trim().isNotEmpty) {
    return paymentPlanLabel(l, key);
  }
  final tier = SubscriptionTier.fromKey(user.currentTier);
  if (tier == SubscriptionTier.free) {
    return l.settingsManageAccount_planFree;
  }
  return subscriptionTierLabel(l, tier);
}

/// Active on the entitlement, lapsed on a paid tier, or no plan at all.
String _planState(AppLocalizations l, AdminActiveUser user) {
  if (user.planActive) return l.adminPanel_planActive;
  if (SubscriptionTier.fromKey(user.currentTier) == SubscriptionTier.free) {
    return l.adminPanel_planNone;
  }
  return l.adminPanel_planLapsed;
}

String _roleLabel(AppLocalizations l, String role) => switch (role) {
  'owner' => l.settingsManageAccount_roleOwner,
  'associate' => l.settingsManageAccount_roleAssociate,
  'viewer' => l.settingsManageAccount_roleViewer,
  _ => l.adminPanel_individual,
};

String _platformLabel(AppLocalizations l, String platform) =>
    switch (platform.toLowerCase()) {
      'android' => l.adminPanel_platformAndroid,
      'ios' => l.adminPanel_platformIos,
      'windows' => l.adminPanel_platformWindows,
      _ => l.adminPanel_platformUnknown,
    };

String _historyPlan(AppLocalizations l, AdminSubscriptionEntry entry) =>
    entry.planKey.isEmpty
    ? l.adminPanel_noValue
    : paymentPlanLabel(l, entry.planKey);

String? _historyAmount(AppLocalizations l, AdminSubscriptionEntry entry) {
  final amount = entry.amount;
  if (amount == null) return null;
  return l.payments_amountValue(
    AppDateUtils.formatDigits(amount, l.localeName),
  );
}

String _historyStatus(AppLocalizations l, String status) => switch (status) {
  'approved' => l.payments_statusApproved,
  'rejected' => l.payments_statusRejected,
  'cancelled' => l.payments_statusCancelled,
  _ => l.payments_statusPending,
};

Color _historyStatusColor(String status) => switch (status) {
  'approved' => AppColors.success,
  'rejected' || 'cancelled' => AppColors.error,
  _ => AppColors.tertiary,
};

/// The numbered cards in one bordered surface, with the app's hairline between
/// rows.
class _UserList extends StatelessWidget {
  final List<AdminActiveUser> users;
  final AppLocalizations l;

  const _UserList({required this.users, required this.l});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
      border: Border.all(color: AppColors.outlineVariant),
    ),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    child: Column(
      children: [
        for (var i = 0; i < users.length; i++) ...[
          if (i > 0)
            const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.outlineVariant,
            ),
          _UserCard(
            key: ValueKey('admin-active-user-${users[i].id}'),
            user: users[i],
            serial: i + 1,
            l: l,
          ),
        ],
      ],
    ),
  );
}

/// One confirmed account, in the order the user asked for: identity, chamber,
/// activity, plan, usage, and the ledger at the very end.
class _UserCard extends StatelessWidget {
  final AdminActiveUser user;
  final int serial;
  final AppLocalizations l;

  const _UserCard({
    required this.user,
    required this.serial,
    required this.l,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final plan = _planName(l, user);
    final planState = _planState(l, user);
    final platforms = user.platforms
        .map((platform) => _platformLabel(l, platform))
        .join(', ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  AppDateUtils.formatDigits(
                    serial,
                    l.localeName,
                    grouping: false,
                  ),
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  user.fullName.isEmpty ? l.adminPanel_noValue : user.fullName,
                  style: AppTypography.titleMd,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _Line(label: l.adminPanel_barAssociation, value: user.barAssociation),
          _Line(label: l.adminPanel_email, value: user.email),
          _Line(label: l.adminPanel_mobileNumber, value: user.mobileNo),
          if (user.isIndividual)
            _Line(
              label: l.adminPanel_accountType,
              value: l.adminPanel_individual,
            )
          else ...[
            _Line(label: l.adminPanel_firmName, value: user.firmName),
            _Line(label: l.adminPanel_role, value: _roleLabel(l, user.role)),
          ],
          _Line(
            label: l.adminPanel_joined,
            value: adminPanelDateTime(l, user.joinedAt),
          ),
          _Line(
            label: l.adminPanel_lastActive,
            value: adminPanelDateTime(l, user.lastActiveAt),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l.adminPanel_currentPlan, style: AppTypography.titleMd),
          const SizedBox(height: AppSpacing.xs),
          Text(plan, style: AppTypography.bodyLg),
          _Line(label: l.adminPanel_planStatus, value: planState),
          _Line(
            label: l.adminPanel_planExpiry,
            value: adminPanelDate(l, user.planExpiry),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l.adminPanel_usage, style: AppTypography.titleMd),
          const SizedBox(height: AppSpacing.xs),
          _Line(label: l.adminPanel_cases, value: _count(l, user.caseCount)),
          _Line(label: l.adminPanel_notes, value: _count(l, user.noteCount)),
          _Line(
            label: l.adminPanel_references,
            value: _count(l, user.referenceCount),
          ),
          _Line(
            label: l.adminPanel_activeDevices,
            value: _count(l, user.deviceCount),
          ),
          _Line(label: l.adminPanel_platforms, value: platforms),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.outlineVariant),
          const SizedBox(height: AppSpacing.sm),
          Text(l.adminPanel_lastFiveHistory, style: AppTypography.titleMd),
          const SizedBox(height: AppSpacing.xs),
          if (user.subscriptionHistory.isEmpty)
            Text(
              l.payments_noSubmissions,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            )
          else
            for (final entry in user.subscriptionHistory)
              _HistoryLine(entry: entry, l: l),
        ],
      ),
    );
  }
}

/// One label/value line, in the panel's own wording.
class _Line extends StatelessWidget {
  final String label;
  final String value;

  const _Line({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final shown = value.isEmpty ? l.adminPanel_noValue : value;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        l.adminPanel_detailLabel(label, shown),
        style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
      ),
    );
  }
}

/// One subscription-ledger entry: plan, amount, status and its timestamp.
class _HistoryLine extends StatelessWidget {
  final AdminSubscriptionEntry entry;
  final AppLocalizations l;

  const _HistoryLine({required this.entry, required this.l});

  @override
  Widget build(BuildContext context) {
    final amount = _historyAmount(l, entry);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _historyPlan(l, entry),
                  style: AppTypography.bodyMd,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (amount != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(amount, style: AppTypography.bodySm),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${_historyStatus(l, entry.status)} · '
            '${adminPanelDateTime(l, entry.at)}',
            style: AppTypography.bodySm.copyWith(
              color: _historyStatusColor(entry.status),
            ),
          ),
        ],
      ),
    );
  }
}
