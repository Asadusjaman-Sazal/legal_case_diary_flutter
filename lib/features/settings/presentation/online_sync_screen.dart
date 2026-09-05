/// Online sync screen: sync status, diagnostics, and recovery.
/// Part A renders an offline/upgrade placeholder (Task 12 Phase 2); the live
/// sync engine is wired in Part B / Task 17.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../case_reference/presentation/reference_viewmodel.dart';
import '../../notes/presentation/notes_viewmodel.dart';
import 'settings_sub_page_modal.dart';

/// A single local-only item-count stat shown on the sync screen.
class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          elevation: 0,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.surfaceContainer),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(height: AppSpacing.xs),
                Text('$count', style: AppTypography.titleMd),
                const SizedBox(height: AppSpacing.xs),
                Text(label, style: AppTypography.bodySm),
              ],
            ),
          ),
        ),
      );
}

/// Online Sync screen (Part A offline placeholder).
class OnlineSyncScreen extends ConsumerWidget {
  const OnlineSyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesViewModelProvider).value?.items.length ?? 0;
    final refs = ref.watch(referenceViewModelProvider).value?.items.length ?? 0;

    return SettingsSubPageModal(
      title: 'Online Sync',
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const _StatusBanner(),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _StatTile(icon: Icons.work_outline, label: 'Cases', count: 0),
              const SizedBox(width: AppSpacing.sm),
              _StatTile(icon: Icons.sticky_note_2_outlined, label: 'Notes', count: notes),
              const SizedBox(width: AppSpacing.sm),
              _StatTile(icon: Icons.menu_book_outlined, label: 'References', count: refs),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.sync),
            label: const Text('Sync Now'),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _UpgradeBanner(),
        ],
      ),
    );
  }
}

/// Offline sync-failure status banner.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.sync_problem_outlined, color: AppColors.tertiary),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Last Sync Failed', style: AppTypography.bodyLg),
                  SizedBox(height: AppSpacing.xs),
                  Text('Never (offline)', style: AppTypography.bodySm),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Premium upgrade call-to-action (Part A: sync not yet available).
class _UpgradeBanner extends StatelessWidget {
  const _UpgradeBanner();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceContainer),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user_outlined, color: AppColors.secondary),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Online Sync', style: AppTypography.bodyLg),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Online Sync is available in the premium version. '
              'Upgrade to sync your data securely across all your devices.',
              style: AppTypography.bodyMd,
            ),
          ],
        ),
      );
}
