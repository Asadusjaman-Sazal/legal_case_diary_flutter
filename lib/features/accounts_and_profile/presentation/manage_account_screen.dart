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
/// **Delete Account starts here.** It warns first — what the deletion takes
/// with it, worded for a free account (whose diary only ever lived on this
/// device) or a premium one (whose diary is also in the cloud) — and says the
/// result is permanent. Confirmed, the warning opens the **typed confirmation
/// screen** (`DeleteAccountScreen`, 0.0.412), where the user has to type
/// `delete my account` before anything is destroyed; that screen then asks the
/// server, returns the device to a fresh install and signs out. Offline it
/// refuses rather than half-deleting: the account row lives on the server, so
/// there is no local-only version of this action.
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
class ManageAccountScreen extends ConsumerStatefulWidget {
  const ManageAccountScreen({super.key});

  @override
  ConsumerState<ManageAccountScreen> createState() =>
      _ManageAccountScreenState();
}

class _ManageAccountScreenState extends ConsumerState<ManageAccountScreen> {
  /// True from the moment Logout is pressed until the flow ends, whatever the
  /// outcome — so the Logout card answers the tap at once with a spinner.
  bool _loggingOut = false;

  @override
  Widget build(BuildContext context) {
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
    // Watched from the first frame, not read when the delete card is tapped: the
    // warning is worded for this account's plan, so the answer may not be the
    // "unknown" a lazy first read gives. (The connection is the confirmation
    // screen's business now — it is where the deletion actually runs.)
    final premium = ref.watch(premiumAccessProvider).value;

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
              busy: _loggingOut,
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
            SizedBox(height: AppSpacing.sm),
            // The app's own lock, set and changed on its own sub-page; it sits
            // with the account's security actions, above the Danger Zone.
            SettingsSubMenuRow(
              key: const ValueKey('manage-account-app-lock'),
              icon: Icons.key_outlined,
              title: l.settingsAppLock_title,
              onTap: () => context.push(AppRoutes.settingsAppLock),
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
              // Unknown counts as premium, the safer direction for a warning:
              // telling a premium user their cloud copy is untouched would be
              // the worse mistake.
              onTap: () => _warnAndContinue(context, premium: premium != false),
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
    // The card answers the tap at once with a spinner, and ignores re-taps,
    // so a logout that takes a few seconds (wipe + reseed + sign-out) never
    // reads as a dead button.
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      // Leaving for Login only when the logout actually completed; a
      // cancellation leaves the account signed in, so there is nothing to
      // leave behind.
      final completed = await runBranchedLogout(context, ref);
      if (!context.mounted || !completed) return;
      context.go(AppRoutes.login);
    } finally {
      // Clear the spinner whatever the outcome — a throw must never leave the
      // card stuck spinning.
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  /// Warns, then opens the typed confirmation that actually deletes.
  ///
  /// Two things happen here, and the order is the point: **the warning**, with
  /// no other way in (a dismissed window is a cancellation, so nothing is
  /// deleted by a stray tap), and then **the confirmation screen** — a page of
  /// its own since 0.0.412, because typing the phrase is the point of no return
  /// and deserves the whole screen rather than a second dialog stacked on the
  /// first.
  Future<void> _warnAndContinue(
    BuildContext context, {
    required bool premium,
  }) async {
    final l = AppLocalizations.of(context);
    final confirmed = await _confirmDeleteAccount(l, context, premium: premium);
    if (confirmed != true || !context.mounted) return;
    context.push(AppRoutes.settingsDeleteAccount);
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

}

