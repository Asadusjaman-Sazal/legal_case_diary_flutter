/// Backup restore screen: backup/restore functionality.
/// Part A renders the offline UI shell (Task 12 Phase 2); backup engine wiring
/// continues in Task 15.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import 'settings_sub_page_modal.dart';

/// A selectable schedule chip for automatic backups.
class _ScheduleChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;

  const _ScheduleChip({
    required this.icon,
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: AppSpacing.xs),
            Text(label),
          ],
        ),
        selected: selected,
        onSelected: (_) {},
      );
}

/// A full-width action card for a backup/restore action.
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;

  const _ActionTile({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.surfaceContainer),
        ),
        child: ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(title, style: AppTypography.bodyLg),
          trailing: const Icon(Icons.chevron_right, color: AppColors.tertiary),
        ),
      );
}

/// Backup & Restore screen (Part A offline shell).
class BackupRestoreScreen extends StatelessWidget {
  const BackupRestoreScreen({super.key});

  @override
  Widget build(BuildContext context) => SettingsSubPageModal(
        title: 'Backup & Restore',
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const _SectionLabel('Backup & Restore'),
            const _ActionTile(
              icon: Icons.cloud_upload_outlined,
              title: 'Backup to Local Storage',
            ),
            const _ActionTile(
              icon: Icons.add_to_drive_outlined,
              title: 'Backup to Google Drive',
            ),
            const _ActionTile(
              icon: Icons.settings_backup_restore_outlined,
              title: 'Restore from backup',
            ),
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.sm),
              child: Text(
                'Note: Restoration is available for offline accounts only.',
                style: AppTypography.bodySm,
              ),
            ),
            const _SectionLabel('Automatic Backup'),
            const _ScheduleRow(),
            const _SectionLabel('Backup Status'),
            const _StatusCard(),
          ],
        ),
      );
}

/// Small uppercase section heading.
class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.xs,
        ),
        child: Text(
          text.toUpperCase(),
          style: AppTypography.labelMd.copyWith(
            color: AppColors.tertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

/// Automatic-backup schedule selector row.
class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow();

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: const [
          _ScheduleChip(icon: Icons.block, label: 'Off', selected: true),
          _ScheduleChip(icon: Icons.today, label: 'Everyday', selected: false),
          _ScheduleChip(icon: Icons.calendar_view_week, label: 'Every 3 days', selected: false),
          _ScheduleChip(icon: Icons.event_repeat, label: 'Every 7 days', selected: false),
          _ScheduleChip(icon: Icons.calendar_month, label: 'Every month', selected: false),
        ],
      );
}

/// Last successful backup status card.
class _StatusCard extends StatelessWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.surfaceContainer),
        ),
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.verified_outlined, color: AppColors.success),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Last successful backup', style: AppTypography.bodyMd),
                    SizedBox(height: AppSpacing.xs),
                    Text('Oct 20, 2023 at 10:45 AM', style: AppTypography.bodySm),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
