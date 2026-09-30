/// Online Sync screen: sync status and per-entity sync rows.
///
/// Body mirrors `mockup_html_screens/settings_onlineSync/code.html`, rendered as
/// the mockup's mobile single-column stack of the bento grid.
/// Part A renders the offline / not-signed-in placeholder state; the live sync
/// engine is wired in Part B (Tasks 17/18).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../case_reference/presentation/reference_viewmodel.dart';
import '../../cases/presentation/case_viewmodel.dart';
import '../../notes/presentation/notes_viewmodel.dart';
import '../../../sync/sync_status_providers.dart';
import 'settings_menu_card.dart';
import 'settings_sub_page_modal.dart';

/// White bordered card shell shared by the status card and the sync rows.
/// Radius matches the mockup's `rounded-xl` (0.5 rem = 8 px).
BoxDecoration _cardDecoration({
  Color color = AppColors.surfaceContainerLowest,
}) => BoxDecoration(
  color: color,
  borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
  border: Border.all(color: AppColors.outlineVariant),
);

/// Part A: sync is unavailable offline; tell the user it lands in Task 17.
void _offlineNotice(BuildContext context, AppLocalizations l) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(l.sharedMessages_signInRequired)));
}

/// Online Sync screen (Part A offline placeholder) per `settings_onlineSync`.
class OnlineSyncScreen extends ConsumerWidget {
  const OnlineSyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
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
      title: l.settingsOnlineSync_title,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.edgeMargin,
          AppSpacing.md,
          AppSpacing.edgeMargin,
          AppSpacing.xl,
        ),
        children: [
          Text(
            l.settingsOnlineSync_subtitle,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const _AccountStatusCard(),
          const SizedBox(height: AppSpacing.gutter),
          const _SyncStatusCard(),
          const SizedBox(height: AppSpacing.gutter),
          const _SyncStatusEntry(),
          const SizedBox(height: AppSpacing.gutter),
          _SyncRow(
            icon: Icons.work_outline,
            label: l.settingsOnlineSync_cases,
            count: cases,
          ),
          const SizedBox(height: AppSpacing.gutter),
          _SyncRow(
            icon: Icons.sticky_note_2_outlined,
            label: l.settingsOnlineSync_notes,
            count: notes,
          ),
          const SizedBox(height: AppSpacing.gutter),
          _SyncRow(
            icon: Icons.menu_book_outlined,
            label: l.settingsOnlineSync_references,
            count: references,
          ),
        ],
      ),
    );
  }
}

/// Entry card for the Sync Status / Diagnostics screen (Task 19 Phase 4).
///
/// The plan's second route into that screen: the header badge is the shortcut
/// while something is held, and this is where a user looks for it deliberately.
/// It reads the attention count so the card itself carries the same news.
class _SyncStatusEntry extends ConsumerWidget {
  const _SyncStatusEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final attention = ref.watch(syncStatusAttentionProvider).value ?? 0;
    return SettingsMenuCard(
      icon: Icons.fact_check_outlined,
      title: l.syncStatus_title,
      subtitle: attention == 0
          ? l.syncStatus_subtitle
          : l.syncStatus_entryTitle(
              l.syncStatus_filterBlocked,
              l.syncStatus_filterConflicted,
            ),
      onTap: () => context.push(AppRoutes.settingsSyncStatus),
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
    final l = AppLocalizations.of(context);
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
                  l.settingsOnlineSync_notSignedIn,
                  style: AppTypography.bodySm.copyWith(
                    color: onPrimary.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l.settingsOnlineSync_signInPrompt,
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
    final l = AppLocalizations.of(context);
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
                            l.settingsOnlineSync_actionRequired,
                            style: AppTypography.labelMd.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l.settingsOnlineSync_lastSyncNever,
                      style: AppTypography.titleLg,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l.settingsOnlineSync_dataStaysOnDevice,
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
              onPressed: () => _offlineNotice(context, l),
              icon: const Icon(Icons.sync, size: 20),
              label: Text(l.settingsOnlineSync_syncNow),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                textStyle: AppTypography.titleMd,
                // Same height as every other Settings sub-menu CTA.
                minimumSize: const Size.fromHeight(settingsPrimaryButtonHeight),
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
    final l = AppLocalizations.of(context);
    // Local alias so the null check promotes below.
    final itemCount = count;
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.md),
      // Content row matches the Account & Profile sub-menu card (44 px between
      // the two 16 px paddings), so the three entity rows are the same size as
      // those menu cards.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: settingsMenuCardRowHeight),
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
                    style: AppTypography.labelLg.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    itemCount == null
                        ? l.settingsOnlineSync_itemsUnknown
                        : l.settingsOnlineSync_itemsCount(itemCount),
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
              l.settingsOnlineSync_notSynced,
              style: AppTypography.bodySm.copyWith(color: AppColors.tertiary),
            ),
          ],
        ),
      ),
    );
  }
}
