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
import '../../auth/presentation/auth_viewmodel.dart';
import '../../auth/presentation/logout_dialogs.dart';
import '../../settings/presentation/settings_menu_card.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';
import '../data/account_mode.dart';
import '../data/profile_name_store.dart';
import '../data/profile_picture_store.dart';

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
      SettingsSubMenuRow(
        icon: Icons.lock_outline,
        title: l.settingsManageAccount_changePassword,
        // One password-reset flow for the whole app — the emailed-code flow the
        // Login screen's "Forgot Password?" already uses — opened in its
        // Settings presentation. It cannot be Login's own `/forgot-password`:
        // that is an auth route, and the router sends a signed-in user away
        // from every auth route, which is why this row used to land on the
        // default landing page instead of the screen.
        onTap: () => context.push(AppRoutes.settingsChangePassword),
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

  /// Ends the session on this device, then shows the Login screen.
  ///
  /// The branched flow around it — sync first, auto-export on the way out, then
  /// Log out, through the branch this account and device state call for
  /// (Task 19 Phase 6).
  ///
  /// The branched flow owns everything that happens next: the mandatory sync for
  /// a premium account that is online, the offline block with its explicit way
  /// past, the safety export for a free account or for work that cannot be sent,
  /// and then the complete wipe and the sign-out. This screen only starts it.
  ///
  /// The Login screen is reached **explicitly**, not by the router's gate: that
  /// gate is decided once per launch (a device already signed in is never
  /// re-gated mid-session), so without this a signed-out user would fall back to
  /// the now-empty Settings surface instead of the sign-in screen. It is a `go`,
  /// not a pop — Login is a top-level route, so the shell is left behind rather
  /// than uncovered — the same navigation the expired-session notice uses.
  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    // Leaving for Login only when the logout actually completed; a cancellation
    // leaves the account signed in, so there is nothing to leave behind.
    final completed = await runBranchedLogout(context, ref);
    if (!context.mounted || !completed) return;
    context.go(AppRoutes.login);
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
