/// Firm menu screen: the firm entries, moved out of Accounts & Profile.
///
/// The Settings row that opens this page is offered to every account (user
/// request, 0.0.663), while the rows below keep the visibility they had:
/// **Manage Firm** / **Create a Firm** is drawn only when the account may open
/// that screen — every individual, whatever their plan, and a firm owner — and
/// **Delete Requests** is drawn in firm mode only, with the count of what is
/// waiting on this account. The label follows the account: *Create a Firm*
/// until a firm exists, *Manage Firm* after. **Join a Firm** (0.0.664, user
/// request) sits directly under the create entry for the one account
/// `join_firm` accepts — an individual whose own diary is still empty — and
/// opens the invitation-code window the create page used to carry. A **member**
/// of somebody else's chamber gets a row named after that chamber instead
/// (0.0.666, user request), which opens the same page as a read-only view of
/// it.
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
import 'join_firm_flow.dart';
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
    // An associate (or viewer) of somebody else's chamber reads it instead of
    // managing it, and the row is named after the chamber itself (0.0.666, user
    // request). The name falls back to the plain *Firm* while the row has not
    // been pulled yet, so the entry is never blank.
    final member = firmExists && !showManageAssociates;
    final firmName = ref.watch(accountFirmProvider).value?.name ?? '';
    final deleteRequestsCount = ref.watch(deleteRequestsBadgeCountProvider);
    // The other way into a chamber (0.0.664, user request): an individual can
    // still join a colleague's firm by redeeming an owner's code, while their
    // own diary is empty. `join_firm` refuses an account that already holds its
    // own rows, so a non-empty — or not yet counted — diary offers nothing.
    final ownCaseCount = ref.watch(ownCaseCountProvider).value;
    final canJoinFirm =
        showManageAssociates && !firmExists && ownCaseCount == 0;

    return SettingsSubPageModal(
      title: l.settingsFirm_title,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (showManageAssociates)
            SettingsMenuCard(
              key: const ValueKey('firm-manage'),
              icon: Icons.groups_outlined,
              title: firmExists
                  ? l.manageAssociates_title
                  : l.manageAssociates_createFirmTitle,
              subtitle: firmExists
                  ? l.settingsAccountProfile_manageAssociatesSubtitle
                  : l.settingsAccountProfile_createFirmSubtitle,
              onTap: () => context.push(AppRoutes.settingsManageAssociates),
            ),
          if (member)
            SettingsMenuCard(
              key: const ValueKey('firm-view'),
              icon: Icons.apartment_outlined,
              title: firmName.isEmpty ? l.settingsFirm_title : firmName,
              subtitle: l.settingsFirm_viewFirmSubtitle,
              onTap: () => context.push(AppRoutes.settingsManageAssociates),
            ),
          if (canJoinFirm) ...[
            const SizedBox(height: AppSpacing.sm),
            SettingsMenuCard(
              key: const ValueKey('firm-join'),
              icon: Icons.group_add_outlined,
              title: l.manageAssociates_joinFirm,
              subtitle: l.settingsFirm_joinFirmSubtitle,
              onTap: () => startJoinFirm(context, ref),
            ),
          ],
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
