/// Manage Account screen: account settings per the
/// `settings_manageProfileAccount` mockup.
///
/// **Task 17 Phase 3.** The mockup's body is unchanged — avatar, name, email,
/// Logout, then the Account Settings list — but every value in it is now the
/// real one: the name from the user's profile record (falling back to the name
/// the server holds for this account), the email from the signed-in identity,
/// and a Logout that really ends the session and empties the pull-only account
/// caches. The avatar reuses the locally saved profile picture (see
/// [profilePictureProvider]) so it matches the Profile screen.
///
/// The task also asks for role and subscription state to be *displayed*. Neither
/// mockup has a row for them, and the mockup wins, so they live where the pencil
/// on Profile lives: behind a row. Tapping **Subscription Details** opens a sheet
/// showing the role, the firm, and the subscription state — the same single
/// `subscription_expiry + 48h grace` derivation the premium gates use.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/date_utils.dart';
import '../../auth/presentation/auth_viewmodel.dart';
import '../../auth/presentation/logout_dialogs.dart';
import '../../settings/presentation/settings_menu_card.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';
import '../data/account_mode.dart';
import '../data/profile_name_store.dart';
import '../data/profile_picture_store.dart';
import '../data/profile_repository.dart';

/// Manage Account screen matching `settings_manageProfileAccount\code.html`.
class ManageAccountScreen extends ConsumerWidget {
  const ManageAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    // Same locally saved picture the Profile screen manages.
    final avatarFile = ref.watch(profilePictureProvider);
    // The user's own profile record first, the server's name for this account
    // second, and a dash when neither exists — never the mockup's sample name.
    final localName = ref.watch(profileFieldsProvider).fullName.trim();
    final cachedName =
        ref.watch(accountProfileProvider).value?.fullName.trim() ?? '';
    final name = localName.isNotEmpty ? localName : cachedName;
    final email = ref.watch(authIdentityProvider)?.email ?? '';

    final accountItems = [
      _AccountItem(
        icon: Icons.lock_outline,
        title: l.settingsManageAccount_changePassword,
        // One password-reset path for the whole app: the emailed-code flow the
        // Login screen's "Forgot Password?" already uses.
        onTap: () => context.push(AppRoutes.forgotPassword),
      ),
      _AccountItem(
        icon: Icons.star_outline,
        title: l.settingsManageAccount_subscriptionDetails,
        onTap: () => _showSubscriptionDetails(context),
      ),
      _AccountItem(
        icon: Icons.add_shopping_cart_outlined,
        title: l.settingsManageAccount_purchaseNewSubscription,
        onTap: () => context.push(AppRoutes.paywall),
      ),
    ];

    return SettingsSubPageModal(
      title: l.settingsManageAccount_title,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.edgeMargin,
          AppSpacing.md,
          AppSpacing.edgeMargin,
          AppSpacing.xl,
        ),
        child: Column(
          children: [
            // Profile summary card.
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppSpacing.md),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceVariant,
                      border: Border.all(color: AppColors.primary, width: 2),
                      image: avatarFile != null
                          ? DecorationImage(
                              image: FileImage(avatarFile),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: avatarFile != null
                        ? null
                        : Center(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              // Initials of the real name; '?' until there is one.
                              style: AppTypography.headlineMd.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                  ),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    name.isNotEmpty ? name : '—',
                    style: AppTypography.titleLg.copyWith(
                      color: AppColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    email.isNotEmpty ? email : '—',
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: () => _signOut(context, ref),
                    icon: const Icon(Icons.logout, size: 20),
                    label: Text(l.settingsManageAccount_logout),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.onSurfaceVariant,
                      backgroundColor: AppColors.surfaceContainer,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                        side: BorderSide(color: AppColors.outlineVariant),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.xl),
            // Account settings list.
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.sm,
                  bottom: AppSpacing.xs,
                ),
                child: Text(
                  l.settingsManageAccount_accountSettings,
                  style: AppTypography.labelLg.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            ...accountItems.map(
              (item) => Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: item,
              ),
            ),
            SizedBox(height: AppSpacing.xl),
            // Destructive action.
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(AppSpacing.md),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.2),
                ),
              ),
              child: InkWell(
                onTap: () => _offlineNotice(context),
                borderRadius: BorderRadius.circular(AppSpacing.md),
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  // Same 44 px content row as the shared sub-menu cards.
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: settingsMenuCardRowHeight,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surfaceContainerLowest,
                          ),
                          child: Center(
                            child: Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.settingsManageAccount_deleteAccount,
                                style: AppTypography.titleMd.copyWith(
                                  color: AppColors.onErrorContainer,
                                ),
                              ),
                              SizedBox(height: AppSpacing.xs),
                              Text(
                                l.settingsManageAccount_deleteCannotBeUndone,
                                style: AppTypography.bodySm.copyWith(
                                  color: AppColors.error.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ends the session on this device, then returns to Settings.
  ///
  /// The branched flow around it — sync first, auto-export on the way out, then
  /// Log out, through the branch this account and device state call for
  /// (Task 19 Phase 6).
  ///
  /// The branched flow owns everything that happens next: the mandatory sync for
  /// a premium account that is online, the offline block with its explicit way
  /// past, the safety export for a free account or for work that cannot be sent,
  /// and then the complete wipe and the sign-out. This screen only starts it and
  /// closes when it is done.
  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    // The screen closes only when the logout actually completed; a cancellation
    // leaves the account signed in, so there is nothing to pop away from.
    final completed = await runBranchedLogout(context, ref);
    if (!context.mounted || !completed) return;
    Navigator.of(context).maybePop();
  }

  /// Shows the role, firm and subscription state behind the row the mockup draws.
  void _showSubscriptionDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _SubscriptionDetailsSheet(),
    );
  }

  /// Kept for the actions this task does not own (Delete Account).
  void _offlineNotice(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).sharedMessages_signInRequired,
        ),
      ),
    );
  }
}

/// The Subscription Details sheet: role, firm and the derived plan state.
class _SubscriptionDetailsSheet extends ConsumerWidget {
  const _SubscriptionDetailsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final profile = ref.watch(accountProfileProvider).value;
    final firm = ref.watch(accountFirmProvider).value;
    final premium = ref.watch(premiumAccessProvider);

    // The firm's expiry is the source of truth for a member; an individual's is
    // their own. Exactly the split `resolvePremiumAccess` uses.
    final expiry = profile?.firmId == null
        ? profile?.subscriptionExpiry
        : firm?.subscriptionExpiry;

    final String subscription;
    if (premium.isLoading) {
      subscription = '—';
    } else if (premium.value ?? false) {
      subscription = expiry == null
          ? l.settingsManageAccount_planPremium
          : l.settingsManageAccount_premiumUntil(
              AppDateUtils.formatDateDDMMYYYY(
                expiry,
                locale: Localizations.localeOf(context).languageCode,
              ),
            );
    } else {
      subscription = l.settingsManageAccount_planFree;
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.settingsManageAccount_subscriptionDetails,
            style: AppTypography.titleLg,
          ),
          SizedBox(height: AppSpacing.lg),
          _DetailRow(
            label: l.settingsManageAccount_role,
            value: _roleLabel(
              l,
              ref.watch(accountRoleProvider),
            ),
          ),
          if (ref.watch(firmModeProvider)) ...[
            SizedBox(height: AppSpacing.md),
            _DetailRow(
              label: l.settingsManageAccount_firm,
              value: (firm?.name ?? '').isNotEmpty ? firm!.name : '—',
            ),
          ],
          SizedBox(height: AppSpacing.md),
          _DetailRow(
            label: l.settingsManageAccount_subscription,
            value: subscription,
          ),
        ],
      ),
    );
  }
}

/// The localized name of a role; an unknown server role is shown as it came.
String _roleLabel(AppLocalizations l, String role) => switch (role) {
  AccountRole.individual => l.settingsManageAccount_roleIndividual,
  AccountRole.owner => l.settingsManageAccount_roleOwner,
  AccountRole.associate => l.settingsManageAccount_roleAssociate,
  AccountRole.viewer => l.settingsManageAccount_roleViewer,
  _ => role,
};

/// A labelled value row in the subscription sheet.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          label,
          style: AppTypography.labelMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
      SizedBox(width: AppSpacing.md),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
        ),
      ),
    ],
  );
}

/// A single row in the "Account Settings" list.
class _AccountItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _AccountItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          // Same 44 px content row as the shared sub-menu cards, so these rows
          // are the same size as the Account & Profile menu cards.
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: settingsMenuCardRowHeight,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceContainer,
                  ),
                  child: Center(child: Icon(icon, color: AppColors.primary)),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.outlineVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
