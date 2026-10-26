/// Firm menu screen: the firm entries, moved out of Accounts & Profile.
///
/// The Settings row that opens this page is offered to every account (user
/// request, 0.0.663), while the rows below keep the visibility they had:
/// **Manage Firm** / **Create a Firm** is drawn only when the account may open
/// that screen — every individual, whatever their plan, and a firm owner — and
/// **Delete Requests** is drawn in firm mode only, with the count of what is
/// waiting on this account. The label follows the account: *Create a Firm*
/// until a firm exists, *Manage Firm* after.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../settings/presentation/delete_requests_viewmodel.dart';
import '../../settings/presentation/settings_menu_card.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';
import '../data/account_mode.dart';

/// The Firm page behind the Settings row.
class FirmMenuScreen extends ConsumerWidget {
  const FirmMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    // A free or premium individual may create a firm, and an owner may manage
    // the one they have; an associate or viewer may not open that screen at all.
    final showManageAssociates = ref.watch(canOpenManageAssociatesProvider);
    // The firm exists, so the row offers management, and the queue belongs to it.
    final firmExists = ref.watch(firmModeProvider);
    final deleteRequestsCount = ref.watch(deleteRequestsBadgeCountProvider);

    return SettingsSubPageModal(
      title: l.settingsFirm_title,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (showManageAssociates)
            SettingsMenuCard(
              icon: Icons.groups_outlined,
              title: firmExists
                  ? l.manageAssociates_title
                  : l.manageAssociates_createFirmTitle,
              subtitle: firmExists
                  ? l.settingsAccountProfile_manageAssociatesSubtitle
                  : l.settingsAccountProfile_createFirmSubtitle,
              onTap: () => context.push(AppRoutes.settingsManageAssociates),
            ),
          // The queue is every firm member's, directly after Manage Firm.
          if (firmExists) ...[
            if (showManageAssociates) const SizedBox(height: AppSpacing.sm),
            SettingsMenuCard(
              icon: Icons.delete_outline,
              title: l.deleteRequests_title,
              subtitle: l.settingsAccountProfile_deleteRequestsSubtitle,
              // The badge counts what is waiting on this account, and the screen
              // it opens is where it is cleared.
              trailing: deleteRequestsCount > 0
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CountPill(count: deleteRequestsCount),
                        const SizedBox(width: AppSpacing.sm),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.tertiary,
                        ),
                      ],
                    )
                  : null,
              onTap: () => context.push(AppRoutes.settingsDeleteRequests),
            ),
          ],
        ],
      ),
    );
  }
}

/// The count pill on a menu card that is waiting for the user.
class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  /// How many things are waiting.
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: AppColors.error,
      borderRadius: BorderRadius.circular(AppSpacing.md),
    ),
    child: Text(
      '$count',
      style: AppTypography.labelMd.copyWith(color: AppColors.onError),
    ),
  );
}
