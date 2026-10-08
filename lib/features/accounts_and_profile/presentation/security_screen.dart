/// Security screen: the account's sign-in security settings.
///
/// Change Password moved here from Manage Account so that the Account &
/// Profile menu's **Account** group can hold account-level actions, and the
/// password flow keeps the same row it always had — the same icon, wording and
/// destination — just on a sub-page of its own.
///
/// **Mockup departure.** There is no `settings_security` mockup; the body is
/// the one moved row, rendered through the shared Settings sub-page shell and
/// card contract, exactly like `subscription_screen.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../settings/presentation/settings_menu_card.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';

/// The Security screen: the sign-in security rows.
class SecurityScreen extends ConsumerWidget {
  /// Creates the screen.
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final items = [
      SettingsSubMenuRow(
        icon: Icons.lock_outline,
        title: l.settingsManageAccount_changePassword,
        // One password-reset flow for the whole app — the emailed-code flow the
        // Login screen's "Forgot Password?" already uses — opened in its
        // Settings presentation. It cannot be Login's own `/forgot-password`:
        // that is an auth route, and the router sends a signed-in user away
        // from every auth route.
        onTap: () => context.push(AppRoutes.settingsChangePassword),
      ),
    ];

    return SettingsSubPageModal(
      title: l.settingsAccountProfile_security,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.edgeMargin,
          AppSpacing.md,
          AppSpacing.edgeMargin,
          AppSpacing.xl,
        ),
        child: Column(
          children: [
            for (final item in items)
              Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: item,
              ),
          ],
        ),
      ),
    );
  }
}
