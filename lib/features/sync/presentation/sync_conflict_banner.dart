/// The app-wide conflict banner (Task 19 Phase 3).
///
/// One unresolved conflict is enough to show it, and nothing about it is
/// dismissible: quitting it would leave frozen local work invisible, which is
/// exactly what the plan forbids. It clears only when every conflict's
/// `resolution_state` leaves `unresolved`, which only a real resolution does.
///
/// It is deliberately self-hiding — an empty list renders nothing at all — so it
/// can be dropped into the shell and into the case-screen shell without either
/// one having to ask whether there is a conflict.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../sync/sync_providers.dart';

/// A non-dismissible strip that says how many conflicts need a person.
class SyncConflictBanner extends ConsumerWidget {
  /// Creates the banner.
  const SyncConflictBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflicts =
        ref.watch(unresolvedConflictsProvider).value ?? const [];
    if (conflicts.isEmpty) return const SizedBox.shrink();

    final l = AppLocalizations.of(context);
    // The newest conflict is the one the tap opens; the count covers the rest.
    final newest = conflicts.first;

    return Material(
      color: AppColors.errorContainer,
      child: InkWell(
        // Pushed, not replaced, so the back action returns to the screen the
        // user was on when the conflict interrupted them.
        onTap: () => context.push(AppRoutes.reviewConflictPath(newest.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.edgeMargin,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              const Icon(Icons.sync_problem, size: 20, color: AppColors.error),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l.syncConflict_bannerMessage(conflicts.length),
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l.syncConflict_bannerAction,
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
