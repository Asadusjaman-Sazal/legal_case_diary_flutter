/// Online Sync screen: sync status and per-entity sync rows.
///
/// Body mirrors `mockup_html_screens/settings_onlineSync/code.html`, rendered as
/// the mockup's mobile single-column stack of the bento grid.
/// Part A renders the offline / not-signed-in placeholder state; the live sync
/// engine is wired in Part B (Tasks 17/18).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../case_reference/presentation/reference_viewmodel.dart';
import '../../cases/presentation/case_viewmodel.dart';
import '../../notes/presentation/notes_viewmodel.dart';
import 'settings_sub_page_modal.dart';

/// White bordered card shell shared by the status card and the sync rows.
/// Radius matches the mockup's `rounded-xl` (0.5 rem = 8 px).
BoxDecoration _cardDecoration({
  Color color = AppColors.surfaceContainerLowest,
}) =>
    BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
      border: Border.all(color: AppColors.outlineVariant),
    );

/// Part A: sync is unavailable offline; tell the user it lands in Task 17.
void _offlineNotice(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Available after sign-in (Task 17)')),
  );
}

/// Online Sync screen (Part A offline placeholder) per `settings_onlineSync`.
class OnlineSyncScreen extends ConsumerWidget {
  const OnlineSyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Live local counts; null while the list is still loading.
    final cases = ref.watch(
      caseViewModelProvider.select((s) => s.value?.nonDeletedCount),
    );
    final notes = ref.watch(
      notesViewModelProvider.select((s) => s.value?.items.length),
    );
    final references = ref.watch(
      referenceViewModelProvider.select((s) => s.value?.items.length),
    );

    return SettingsSubPageModal(
      title: 'Online Sync',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.edgeMargin,
          AppSpacing.md,
          AppSpacing.edgeMargin,
          AppSpacing.xl,
        ),
        children: [
          Text(
            'Manage your real-time data sync across all your devices.',
            style: AppTypography.bodyMd
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          const _AccountStatusCard(),
          const SizedBox(height: AppSpacing.gutter),
          const _SyncStatusCard(),
          const SizedBox(height: AppSpacing.gutter),
          _SyncRow(
            icon: Icons.work_outline,
            label: 'Cases',
            count: cases,
          ),
          const SizedBox(height: AppSpacing.gutter),
          _SyncRow(
            icon: Icons.sticky_note_2_outlined,
            label: 'Notes',
            count: notes,
          ),
          const SizedBox(height: AppSpacing.gutter),
          _SyncRow(
            icon: Icons.menu_book_outlined,
            label: 'References',
            count: references,
          ),
        ],
      ),
    );
  }
}

/// Dark account/subscription card at the top of the mockup's bento grid.
/// Part A has no account yet, so it carries the sign-in state instead of the
/// mockup's "Subscription active until ..." line.
class _AccountStatusCard extends StatelessWidget {
  const _AccountStatusCard();

  @override
  Widget build(BuildContext context) {
    final onPrimary = AppColors.onPrimary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
      child: Container(
        width: double.infinity,
        color: AppColors.primary,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Stack(
          children: [
            // Faded brand watermark bleeding out of the bottom-right corner.
            Positioned(
              right: -AppSpacing.md,
              bottom: -AppSpacing.md,
              child: Icon(
                Icons.verified_user,
                size: 160,
                color: onPrimary.withValues(alpha: 0.05),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Not signed in',
                  style: AppTypography.bodySm
                      .copyWith(color: onPrimary.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Sign in to sync your data across all your devices',
                  style: AppTypography.titleMd.copyWith(color: onPrimary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Sync status card: "Action Required" pill, last-sync state, and the CTA.
class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Error pill from the mockup's status header.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.errorContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 16,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Action Required',
                            style: AppTypography.labelMd
                                .copyWith(color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Last Sync: Never', style: AppTypography.titleLg),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Your data stays on this device until you sign in.',
                      style: AppTypography.bodySm,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                ),
                child: const Icon(
                  Icons.sync_problem,
                  size: 24,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Full-width primary CTA; Part A only surfaces the offline notice.
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _offlineNotice(context),
              icon: const Icon(Icons.sync, size: 20),
              label: const Text('Sync Now'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                textStyle: AppTypography.titleMd,
                // Slightly taller than the default 40 px CTA.
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.sm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One entity row (Cases / Notes / References) with its local item count.
class _SyncRow extends StatelessWidget {
  final IconData icon;
  final String label;

  /// Local item count; null while the source list is still loading.
  final int? count;

  const _SyncRow({
    required this.icon,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.md),
      // Content row matches the Account & Profile sub-menu cards (44 px between
      // the two 16 px paddings → ~78 px drawn card with the 1 px border), so the
      // three entity rows are the same size as those menu cards.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.labelLg
                        .copyWith(color: AppColors.primary),
                  ),
                  Text(
                    count == null ? '— Items' : '$count Items',
                    style: AppTypography.bodySm,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Part A never syncs: every row carries the neutral, muted marker
            // instead of the mockup's success/failure icons.
            const Icon(
              Icons.cloud_off_outlined,
              size: 18,
              color: AppColors.tertiary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Not synced',
              style: AppTypography.bodySm.copyWith(color: AppColors.tertiary),
            ),
          ],
        ),
      ),
    );
  }
}
