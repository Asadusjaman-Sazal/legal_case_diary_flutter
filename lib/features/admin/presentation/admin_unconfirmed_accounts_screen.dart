/// The Admin Panel's **Non-verified Accounts** sub-page: the sign-ups that were
/// created and never confirmed, so abandoned ones can be cleaned up.
///
/// The list arrives only from the admin-gated `admin_list_unconfirmed_accounts()`
/// — an unconfirmed account is invisible to every client, since `email_confirmed_at`
/// lives in `auth.users` and the `profiles` row carries no confirmation flag.
/// Each row reports `can_delete`, the server's own "has this account done
/// anything?" test, so the Delete button is disabled rather than offered and
/// then refused; the server re-runs that test before removing anything.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/utils/date_utils.dart';
import '../../../sync/sync_service.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';
import '../data/admin_repository.dart';
import 'admin_shared.dart';
import 'admin_viewmodel.dart';

/// The accounts that never confirmed their address.
class AdminUnconfirmedAccountsScreen extends ConsumerStatefulWidget {
  const AdminUnconfirmedAccountsScreen({super.key});

  @override
  ConsumerState<AdminUnconfirmedAccountsScreen> createState() =>
      _AdminUnconfirmedAccountsScreenState();
}

class _AdminUnconfirmedAccountsScreenState
    extends ConsumerState<AdminUnconfirmedAccountsScreen> {
  /// Whether the header's search box is showing, and what is typed in it.
  bool _isSearching = false;
  final TextEditingController _search = TextEditingController();
  String _query = '';

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
    final accounts = ref.watch(adminUnconfirmedAccountsProvider);
    final action = ref.watch(AdminDeleteAccountViewModel.provider);

    return SettingsSubPageModal(
      title: l.adminPanel_unverifiedTitle,
      actions: [
        const AdminSyncButton(),
        IconButton(
          key: const ValueKey('admin-accounts-search'),
          icon: const Icon(Icons.search),
          tooltip: l.adminPanel_search,
          onPressed: _toggleSearch,
        ),
      ],
      child: accounts.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (_, _) => AdminLoadFailed(
          message: l.adminPanel_unverifiedLoadFailed,
          retryLabel: l.adminPanel_retry,
          onRetry: () => ref.invalidate(adminUnconfirmedAccountsProvider),
        ),
        data: (all) {
          final shown = all
              .where(
                (account) =>
                    adminTextMatches(_query, [account.fullName, account.email]),
              )
              .toList(growable: false);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isSearching) _searchField(l),
              if (_query.trim().isNotEmpty && shown.isEmpty)
                AdminNoResults(message: l.adminPanel_noResults)
              else
                Expanded(
                  // Pull down to sync (user request): the same forced drain
                  // with the delta pull the header button runs, then a re-read
                  // of the list, so a sign-up that landed while the page was
                  // open appears without a trip to Settings.
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await ref.read(syncServiceProvider).retryNow();
                      ref.invalidate(adminUnconfirmedAccountsProvider);
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
                        if (action.phase != AdminActionPhase.idle)
                          _DeleteBanner(
                            action: action,
                            onDismiss: () => ref
                                .read(
                                  AdminDeleteAccountViewModel.provider.notifier,
                                )
                                .clear(),
                          ),
                        if (shown.isEmpty)
                          Text(
                            l.adminPanel_unverifiedEmpty,
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          )
                        else
                          _AccountList(
                            accounts: shown,
                            action: action,
                            onDelete: (account) =>
                                _confirmDelete(context, ref, account),
                          ),
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

  /// Asks before removing: deleting an account is permanent, so it is confirmed
  /// rather than fired from one tap.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AdminUnconfirmedAccount account,
  ) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.adminPanel_deleteTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(account.email, style: AppTypography.titleMd, maxLines: 2),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.adminPanel_deleteBody,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.sharedActions_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
            ),
            child: Text(l.adminPanel_deleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(AdminDeleteAccountViewModel.provider.notifier)
        .delete(account.id);
  }
}

/// The numbered cards, in one bordered surface with the app's hairline between
/// rows — the same shape the payment sections use.
class _AccountList extends StatelessWidget {
  final List<AdminUnconfirmedAccount> accounts;
  final AdminActionState action;
  final ValueChanged<AdminUnconfirmedAccount> onDelete;

  const _AccountList({
    required this.accounts,
    required this.action,
    required this.onDelete,
  });

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
        for (var i = 0; i < accounts.length; i++) ...[
          if (i > 0)
            const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.outlineVariant,
            ),
          _AccountCard(
            key: ValueKey('admin-account-${accounts[i].id}'),
            account: accounts[i],
            serial: i + 1,
            busy: action.isRunning && action.actedOn == accounts[i].id,
            onDelete: () => onDelete(accounts[i]),
          ),
        ],
      ],
    ),
  );
}

/// One abandoned sign-up: a number, who it is, when it was created, and the
/// Delete that removes it — or why that is not allowed.
class _AccountCard extends StatelessWidget {
  final AdminUnconfirmedAccount account;

  /// The card's position in the list, counting from 1.
  final int serial;

  /// Whether this very account's removal is in flight.
  final bool busy;
  final VoidCallback onDelete;

  const _AccountCard({
    required this.account,
    required this.serial,
    required this.busy,
    required this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
                  account.fullName.isEmpty
                      ? l.adminPanel_noValue
                      : account.fullName,
                  style: AppTypography.titleMd,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            account.email.isEmpty ? l.adminPanel_noValue : account.email,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Line(label: l.adminPanel_detailLabelEmail, value: account.email),
          _Line(
            label: l.adminPanel_created,
            value: adminPanelDateTime(l, account.createdAt),
          ),
          // Only when there is one: an unconfirmed account normally has never
          // signed in, so the line would be a dash on every card.
          if (account.lastSignInAt != null)
            _Line(
              label: l.adminPanel_lastSignIn,
              value: adminPanelDateTime(l, account.lastSignInAt),
            ),
          const SizedBox(height: AppSpacing.md),
          if (account.canDelete)
            SizedBox(
              width: double.infinity,
              // A solid red button with white text (user request): the one
              // destructive action on the page reads as one.
              child: FilledButton(
                onPressed: busy ? null : onDelete,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.onError,
                  disabledBackgroundColor: AppColors.surfaceContainerHigh,
                  disabledForegroundColor: AppColors.onSurfaceVariant,
                  textStyle: AppTypography.labelLg,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
                  ),
                ),
                child: Text(l.adminPanel_delete),
              ),
            )
          else
            // Not offered, and the reason is named: an account with data, or a
            // confirmed one, is not this page's to remove.
            Text(
              l.adminPanel_deleteBlocked,
              style: AppTypography.bodySm.copyWith(color: AppColors.tertiary),
            ),
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

/// The one-line outcome of the last removal, or why it was refused.
class _DeleteBanner extends StatelessWidget {
  final AdminActionState action;
  final VoidCallback onDismiss;

  const _DeleteBanner({required this.action, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isFailure = action.phase == AdminActionPhase.failure;
    final message = switch (action.phase) {
      AdminActionPhase.success => l.adminPanel_deleted,
      AdminActionPhase.failure => switch (action.failure) {
        AdminActionFailure.notAnAdmin => l.adminPanel_failedNotAdmin,
        AdminActionFailure.notFound => l.adminPanel_failedNotFound,
        AdminActionFailure.alreadyResolved => l.adminPanel_deleteBlocked,
        AdminActionFailure.tooRecent => l.adminPanel_deleteTooRecent,
        AdminActionFailure.unexpected => l.adminPanel_failedUnexpected,
        null => l.adminPanel_failedUnexpected,
      },
      _ => '',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: isFailure
            ? AppColors.errorContainer
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Row(
            children: [
              Icon(
                isFailure ? Icons.error_outline : Icons.check_circle,
                size: 18,
                color: isFailure
                    ? AppColors.onErrorContainer
                    : AppColors.success,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.bodySm.copyWith(
                    color: isFailure
                        ? AppColors.onErrorContainer
                        : AppColors.onSurface,
                  ),
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
