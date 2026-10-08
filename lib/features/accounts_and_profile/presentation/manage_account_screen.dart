/// Manage Account screen: the account's own actions per the
/// `settings_manageProfileAccount` mockup.
///
/// **Task 17 Phase 3.** The name comes from the user's profile record (falling
/// back to the name the server holds for this account), the email from the
/// signed-in identity, and the avatar from the locally saved profile picture
/// (see [profilePictureProvider]) so it matches the Profile screen.
///
/// **The body, as the user asked for it (0.0.411).** The profile summary keeps
/// only the avatar, name and email — the small inline **Logout** under the name
/// is gone. What follows is a short column of account actions:
///
/// * a **full-size Logout** card, the same card as **Delete Account** below it
///   (one [SettingsActionCard], two colour tones), so the request's "the same
///   size as the Delete Account button" is a property of the widget rather than
///   a measurement anyone has to keep re-taking;
/// * **Change Password**, moved back from the **Security** sub-page and placed
///   straight after Logout;
/// * a red, bold **Danger Zone** label, then the **Delete Account** card.
///
/// **Delete Account is wired here.** It warns first — what the deletion takes
/// with it, worded for a free account (whose diary only ever lived on this
/// device) or a premium one (whose diary is also in the cloud) — and says the
/// result is permanent. Confirmed, it asks the server to remove the account and
/// every row of it, then returns the device to a fresh install and signs out.
/// Offline it refuses rather than half-deleting: the account row lives on the
/// server, so there is no local-only version of this action.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../sync/connectivity_monitor.dart';
import '../../auth/data/logout_flow.dart';
import '../../auth/presentation/auth_viewmodel.dart';
import '../../auth/presentation/logout_dialogs.dart';
import '../../settings/presentation/settings_menu_card.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';
import '../data/account_deletion_repository.dart';
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
    // Both are watched from the first frame, not read when the delete card is
    // tapped: the warning is worded for this account's plan, and the connection
    // decides whether the action is possible at all, so neither may be the
    // "unknown" a lazy first read answers with.
    final premium = ref.watch(premiumAccessProvider).value;
    final online = ref.watch(isOnlineProvider).value;

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile summary card: who this account is, and nothing else — the
            // Logout that used to sit under the address is a full-size card now.
            Container(
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
                ],
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            // Logout: the same card as Delete Account, in the neutral tone.
            SettingsActionCard(
              icon: Icons.logout,
              title: l.settingsManageAccount_logout,
              tone: SettingsActionTone.neutral,
              onTap: () => _signOut(context, ref),
            ),
            SizedBox(height: AppSpacing.sm),
            // Change Password came back from the Security sub-page, directly
            // under Logout, as its own row.
            SettingsSubMenuRow(
              icon: Icons.lock_outline,
              title: l.settingsManageAccount_changePassword,
              // One password-reset flow for the whole app — the emailed-code
              // flow the Login screen's "Forgot Password?" already uses, opened
              // in its Settings presentation. It cannot be Login's own
              // `/forgot-password`: that is an auth route, and the router sends
              // a signed-in user away from every auth route.
              onTap: () => context.push(AppRoutes.settingsChangePassword),
            ),
            SizedBox(height: AppSpacing.lg),
            // The section heading the user asked for: red and bold, drawing the
            // eye to the one irreversible action on this screen.
            Text(
              l.settingsManageAccount_dangerZone,
              style: AppTypography.labelMd.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            // The destructive action, warned and wired.
            SettingsActionCard(
              icon: Icons.delete_outline,
              title: l.settingsManageAccount_deleteAccount,
              subtitle: l.settingsManageAccount_deleteCannotBeUndone,
              tone: SettingsActionTone.destructive,
              onTap: () => _confirmDelete(
                context,
                ref,
                // Unknown counts as premium, and as online. Both are the safe
                // direction: the stronger warning, and a call that words its own
                // failure — and either is unresolved only on the first frame.
                premium: premium != false,
                online: online != false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ends the session on this device, then shows the Login screen.
  ///
  /// The branched flow around it — sync first, the offered safety copy, then
  /// Log out, through the branch this account and device state call for
  /// (Task 19 Phase 6).
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

  /// Warns, then deletes this account and everything that belongs to it.
  ///
  /// Four things happen in this order, and the order is the point:
  ///
  /// 1. **The warning**, with no other way in. A dismissed window (the barrier
  ///    or system back) is a cancellation, so nothing is deleted by a stray tap.
  /// 2. **The connection check.** The account row lives on the server, so there
  ///    is no offline deletion to fall back on; rather than half-delete, the tap
  ///    is refused with the reason. Nothing local is touched either — the diary
  ///    stays until the account is really gone, which is the retryable direction.
  /// 3. **The server's own removal** — `delete_my_account()` clears every row of
  ///    this account, cloud data included, and then the account itself. A refusal
  ///    (a firm member, an app admin) or a failure stops here, with the reason.
  /// 4. **The device** — the same complete wipe-with-baseline the logout runs,
  ///    then the sign-out, then Login.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref, {
    required bool premium,
    required bool online,
  }) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // The warning first, worded for this account's plan: a free account's diary
    // has never left the device, while a premium account's is in the cloud too —
    // and that is the part a user must not be surprised by.
    final confirmed = await _confirmDeleteAccount(l, context, premium: premium);
    if (confirmed != true || !context.mounted) return;

    // The account is on the server; without a link there is nothing to delete,
    // and no queue would be honest about it.
    if (!online) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.settingsManageAccount_deleteNeedsConnection)),
      );
      return;
    }

    final outcome = await ref
        .read(accountDeletionRepositoryProvider)
        .deleteAccount();
    if (!context.mounted) return;
    if (outcome != AccountDeletionOutcome.deleted) {
      messenger.showSnackBar(
        SnackBar(content: Text(_deletionFailureText(l, outcome))),
      );
      return;
    }

    // Gone server-side, so this device goes back to what an install starts from
    // and the session ends: the logout flow's own wipe + sign-out, so the two
    // ways off an account cannot diverge.
    final flow = await ref.read(logoutFlowProvider.future);
    if (!context.mounted) return;
    await flow.wipeAndComplete();
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(l.settingsManageAccount_deleted)),
    );
    context.go(AppRoutes.login);
  }

  /// The one warning before an account is destroyed.
  ///
  /// Cancel and Delete Account, centred and at the shared action size, exactly
  /// like the logout windows. The destructive action is the red one, so the
  /// button the user must not press by accident is not the app's black primary.
  Future<bool?> _confirmDeleteAccount(
    AppLocalizations l,
    BuildContext context, {
    required bool premium,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.settingsManageAccount_deleteDialogTitle),
        content: Text(
          premium
              ? l.settingsManageAccount_deleteWarningPremium
              : l.settingsManageAccount_deleteWarningFree,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(112, 48),
              textStyle: const TextStyle(fontSize: 16),
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.sharedActions_cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(112, 48),
              textStyle: const TextStyle(
                fontSize: 16,
                color: AppColors.error,
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.settingsManageAccount_deleteAccount),
          ),
        ],
      ),
    );
  }

  /// One sentence for anything that did not delete the account.
  ///
  /// A refusal is the server's own answer — this account holds data that is not
  /// only its own — and says what has to happen first. Everything else is a
  /// failure the user can retry.
  String _deletionFailureText(
    AppLocalizations l,
    AccountDeletionOutcome outcome,
  ) => switch (outcome) {
    AccountDeletionOutcome.refusedFirm => l.settingsManageAccount_deleteFirmRefused,
    AccountDeletionOutcome.refusedAdministrator =>
      l.settingsManageAccount_deleteAdminRefused,
    // Deleted is handled before this is asked for; a label keeps it total.
    AccountDeletionOutcome.deleted ||
    AccountDeletionOutcome.unavailable ||
    AccountDeletionOutcome.failed => l.settingsManageAccount_deleteFailed,
  };
}

