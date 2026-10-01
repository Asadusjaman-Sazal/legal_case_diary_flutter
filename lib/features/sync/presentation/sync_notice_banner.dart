/// The app-wide sync notice strip (Task 20 Phase 2).
///
/// `SyncService.notice` has carried two messages since Task 18 — the server
/// refused a queued action because the firm's permissions changed, and the device
/// clock is more than ~2 minutes off from the server — and until now nothing in
/// `lib/` rendered either of them: a refusal that rolled a provisional edit back
/// happened invisibly, and a skewed clock silently mis-stamped everything it
/// wrote. This is the missing consumer, and it is the *only* one, so a notice
/// raised in either place reaches the user wherever they are.
///
/// Unlike the conflict banner it **is** dismissible, and that difference is the
/// point: a conflict is frozen work that still needs a person, so hiding it would
/// hide the work, while a notice is an explanation of something already answered —
/// the action was not applied, or the clock is off. It sits in the same two
/// places the conflict banner does, and both are self-hiding, so no screen shows
/// either one twice.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../sync/sync_providers.dart';
import '../../../sync/sync_service.dart';

/// A dismissible strip carrying the last thing sync had to say.
class SyncNoticeBanner extends ConsumerWidget {
  /// Creates the banner.
  const SyncNoticeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notice = ref.watch(syncNoticeProvider).value;
    if (notice == null) return const SizedBox.shrink();

    final l = AppLocalizations.of(context);
    final text = switch (notice) {
      SyncNotice.permissionsChanged => l.syncNotice_permissionsChanged,
      SyncNotice.clockSkew => l.syncNotice_clockSkew,
    };

    return Material(
      color: AppColors.errorContainer,
      child: InkWell(
        // Acknowledging it is enough: there is nothing to open and nothing left
        // to do — the notice describes something sync already finished with.
        onTap: () => ref.read(syncServiceProvider).notice.value = null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.edgeMargin,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 20,
                color: AppColors.error,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  text,
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.close, size: 18, color: AppColors.error),
            ],
          ),
        ),
      ),
    );
  }
}
